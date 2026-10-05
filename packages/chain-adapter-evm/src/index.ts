// ChainAdapter implementation for the EVM/Solidity contract hierarchy
// (BCA_ServiceManager -> BCA_ServiceController -> BCA_Service -> BCA_ServiceInstance,
// see contracts/evm). Extracted from bca-token-market/src/lib/contracts.ts and
// wallet.ts — same web3.js calls the live routes make today, just behind the
// chain-neutral interface. Not yet wired into any app (plan-reorg.md §8 step 2):
// this package proves the abstraction against the live EVM code with zero
// behavior change to bca-token-market.
import { Web3 } from "web3";
import type {
  Address,
  ChainAdapter,
  ChainEvent,
  ContractRef,
  EventFilter,
  InstanceState,
  ServiceParams,
  TokenRef,
  TxHandle,
  Unsubscribe,
  WalletHandle,
} from "@bca/chain-adapter";
import { asAddress, asContractRef, asTokenRef } from "@bca/chain-adapter";

// AbiItem type from web3 is not exported at the top level in all v4 minor
// versions; `any[]` keeps this package decoupled from that churn. Callers pass
// in the same ABI JSON files bca-token-market/update-abi.sh already copies out
// of the Hardhat build (contracts/evm/artifacts, contracts/evm/ignition/...).
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type AbiItem = any;

// web3's Contract<Abi> return types only resolve correctly when the ABI is a
// literal tuple known at compile time; since abis here are loaded at runtime
// from JSON, method calls are typed loosely (any) and this adapter narrows
// each result to the ChainAdapter interface's declared types explicitly.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type EvmContract = any;

export interface EvmContractAbis {
  token: AbiItem[];
  serviceManager: AbiItem[];
  serviceController: AbiItem[];
  service: AbiItem[];
  serviceInstance: AbiItem[];
}

export interface EvmAdapterConfig {
  chainId: string; // e.g. "evm:polygon-amoy"
  networkHex?: string; // e.g. "0x13882", used only to pick a gas-estimation strategy below
  provider: unknown; // EIP-1193 provider, e.g. window.ethereum
  contracts: EvmContractAbis;
}

// same network name lookup as wallet.ts's get_wallet_chainid, kept here so
// connectWallet() can populate WalletHandle.networkName without a second table
const NETWORK_NAMES: Record<string, string> = {
  "0x1": "ethereum",
  "0x89": "polygon",
  "0xa4b1": "arbitrum",
  "0xa86a": "avalanche",
  "0x7a69": "local",
  "0x13882": "polygon amoy testnet",
};

export class EvmAdapter implements ChainAdapter {
  readonly chainId: string;
  private web3: Web3;
  private abis: EvmContractAbis;

  constructor(config: EvmAdapterConfig) {
    this.chainId = config.chainId;
    this.web3 = new Web3(config.provider as never);
    this.abis = config.contracts;
  }

  private serviceManager(addr: string): EvmContract {
    return new this.web3.eth.Contract(this.abis.serviceManager, addr);
  }
  private serviceController(addr: string): EvmContract {
    return new this.web3.eth.Contract(this.abis.serviceController, addr);
  }
  private service(addr: string): EvmContract {
    return new this.web3.eth.Contract(this.abis.service, addr);
  }
  private serviceInstance(addr: string): EvmContract {
    return new this.web3.eth.Contract(this.abis.serviceInstance, addr);
  }
  private token(addr: string): EvmContract {
    return new this.web3.eth.Contract(this.abis.token, addr);
  }

  async connectWallet(): Promise<WalletHandle> {
    // mirrors wallet.ts's get_wallet_chainid + get_wallet_addr, minus the DOM
    // event-target disable/enable side effect (that's a UI concern, not the
    // adapter's)
    const networkHex: string = await (
      this.web3.currentProvider as unknown as { request: (a: unknown) => Promise<string> }
    ).request({ method: "eth_chainId" });
    const accounts = await this.web3.eth.requestAccounts();
    const address = accounts[0];
    if (!address) throw new Error("Please select an account in your wallet");
    return {
      address: asAddress(address),
      chainId: this.chainId,
      networkName: NETWORK_NAMES[networkHex],
    };
  }

  async getBalance(addr: Address, token: TokenRef): Promise<bigint> {
    const balance = await this.token(token).methods.balanceOf(addr).call();
    return BigInt(balance as bigint);
  }

  // BCA_ServiceManager.newController() is void; the new controller's address
  // is recovered via the getControllerAddress(seller) view getter, same as
  // the array/mapping lookup pattern documented in plan-reorg.md §6.1.
  async deploySellerFactory(rootFactory: ContractRef, seller: Address): Promise<ContractRef> {
    const manager = this.serviceManager(rootFactory);
    const from = await this.requireFrom();
    await manager.methods.newController(seller).send({ from });
    const controllerAddr: string = await manager.methods.getControllerAddress(seller).call();
    return asContractRef(controllerAddr);
  }

  // BCA_ServiceController.newService() does return the new address, but that
  // return value isn't retrievable from a .send() receipt; read it off the
  // ServiceDeployed event instead (falls back to the deployedServices array).
  async defineService(sellerFactory: ContractRef, params: ServiceParams): Promise<ContractRef> {
    const controller = this.serviceController(sellerFactory);
    const from = await this.requireFrom();
    const receipt = await controller.methods
      .newService(params.maxInstances, params.dayPrice)
      .send({ from });
    const deployed = receipt.events?.ServiceDeployed?.returnValues?.contractAddress as
      | string
      | undefined;
    if (deployed) return asContractRef(deployed);
    const count: bigint = await controller.methods.countServiceContracts().call();
    const addr: string = await controller.methods.deployedServices(count - 1n).call();
    return asContractRef(addr);
  }

  async openInstance(service: ContractRef, client: Address): Promise<ContractRef> {
    const svc = this.service(service);
    const from = await this.requireFrom();
    const receipt = await svc.methods.newInstance(client).send({ from });
    const deployed = receipt.events?.InstanceDeployed?.returnValues?.contractAddress as
      | string
      | undefined;
    if (deployed) return asContractRef(deployed);
    const count: bigint = await svc.methods.countServiceInstances().call();
    const addr: string = await svc.methods.deployedInstances(count - 1n).call();
    return asContractRef(addr);
  }

  // mirrors deposit_user() in serviceinstance/[addr]/+page.svelte: approve the
  // instance to pull `amount` of the instance's token, then makeDeposit()
  async deposit(instance: ContractRef, amount: bigint): Promise<TxHandle> {
    const from = await this.requireFrom();
    const instanceContract = this.serviceInstance(instance);
    const tokenAddr: string = await instanceContract.methods.tokToken().call();
    const tokenContract = this.token(tokenAddr);
    await tokenContract.methods.approve(instance, amount).send({ from });
    const receipt = await instanceContract.methods.makeDeposit(amount).send({ from });
    return { txHash: receipt.transactionHash as string };
  }

  async withdraw(instance: ContractRef, amount: bigint, as: "client" | "seller"): Promise<TxHandle> {
    const from = await this.requireFrom();
    const contract = this.serviceInstance(instance);
    const method = as === "client" ? contract.methods.withdrawUser : contract.methods.withdrawProvider;
    const receipt = await method(amount).send({ from });
    return { txHash: receipt.transactionHash as string };
  }

  async stop(instance: ContractRef): Promise<TxHandle> {
    const from = await this.requireFrom();
    const receipt = await this.serviceInstance(instance).methods.stop().send({ from });
    return { txHash: receipt.transactionHash as string };
  }

  async getInstanceState(instance: ContractRef): Promise<InstanceState> {
    const contract = this.serviceInstance(instance);
    const [dayPrice, deposit, retracted, startTime, endTime, userAddress, providerAddress, tokenAddress] =
      await Promise.all([
        contract.methods.dayPrice().call(),
        contract.methods.deposit().call(),
        contract.methods.retracted().call(),
        contract.methods.startTime().call(),
        contract.methods.endTime().call(),
        contract.methods.userAddress().call(),
        contract.methods.providerAddress().call(),
        contract.methods.tokToken().call(),
      ]);
    return {
      dayPrice: BigInt(dayPrice as bigint),
      deposit: BigInt(deposit as bigint),
      retracted: BigInt(retracted as bigint),
      startTime: Number(startTime),
      endTime: Number(endTime),
      userAddress: asAddress(userAddress as string),
      providerAddress: asAddress(providerAddress as string),
      tokenAddress: asTokenRef(tokenAddress as string),
    };
  }

  // EVM has native event logs but the wallet-injected HTTP provider used
  // today (window.ethereum) doesn't support log subscriptions the way a
  // websocket provider would — the live app polls via getPastEvents() on a
  // manual refresh button (see list_events() in
  // serviceinstance/[addr]/+page.svelte). Port that same polling strategy
  // here so subscribeEvents() behaves the same regardless of adapter.
  subscribeEvents(filter: EventFilter, cb: (e: ChainEvent) => void): Unsubscribe {
    if (!filter.address) throw new Error("subscribeEvents requires filter.address for the EVM adapter");
    const contract = this.serviceInstance(filter.address);
    let lastBlock = filter.fromBlock ?? 0;
    const poll = async () => {
      const events = await contract.getPastEvents("allEvents", {
        fromBlock: lastBlock,
        toBlock: filter.toBlock ?? "latest",
      });
      for (const ev of events) {
        if (typeof ev === "string") continue;
        cb({
          kind: ev.event ?? "unknown",
          contractAddress: ev.address,
          blockRef: ev.blockNumber ?? 0,
          txHash: ev.transactionHash,
          returnValues: ev.returnValues as Record<string, unknown>,
        });
      }
      if (events.length) {
        lastBlock =
          Math.max(...events.map((e: EvmContract) => (typeof e === "string" ? 0 : Number(e.blockNumber ?? 0)))) + 1;
      }
    };
    const interval = setInterval(poll, 15_000);
    void poll();
    return () => clearInterval(interval);
  }

  private async requireFrom(): Promise<string> {
    const accounts = await this.web3.eth.getAccounts();
    const from = accounts[0];
    if (!from) throw new Error("no connected account — call connectWallet() first");
    return from;
  }
}

// re-exported so callers building a ChainAdapter selector don't also need to
// import @bca/chain-adapter directly just for the type
export type { ChainAdapter } from "@bca/chain-adapter";
