// ChainAdapter implementation for the Cardano/Aiken contract backend in
// bca-token-plutus/, built on the BCA Evolution SDK fork
// (`@bca/evolution-sdk`, imported under the alias `evolution-sdk-bca`; see
// this package's README).
//
// On-chain model (bca-token-plutus/lib/bca/types.ak): each level's state is a
// UTxO holding exactly one state token, and every ContractRef returned here is
// that token's unit (policy id hex + asset name hex):
//   seller   root_factory   token = seller key hash             SellerFactoryDatum
//   service  seller_factory token = name derived from seller UTxO ServiceDatum
//   instance service_instance token = name derived from service UTxO ServiceInstanceDatum
import {
  Address as CardanoAddress,
  Assets as CardanoAssets,
  Client,
  Data,
  InlineDatum,
  KeyHash,
  PlutusV3,
  Script as ScriptNS,
  TransactionHash,
  UTxO as UTxONS,
  type Chain,
} from "evolution-sdk-bca";
type Script = ScriptNS.Script;
type UTxO = UTxONS.UTxO;

// Our own wallet is always a plain payment-key address — `addSigner()` needs
// a precise `KeyHash`, not the general credential union.
function expectKeyHash(cred: { _tag: string; hash: Uint8Array }): InstanceType<typeof KeyHash.KeyHash> {
  if (cred._tag !== "KeyHash") {
    throw new Error(`expected a KeyHash credential, got ${cred._tag}`);
  }
  return KeyHash.fromBytes(cred.hash);
}
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
import { asAddress, asContractRef } from "@bca/chain-adapter";
import {
  Redeemer,
  anyRedeemer,
  decodeInstanceDatum,
  decodeSellerState,
  decodeServiceState,
  encodeInstanceDatum,
  encodeSellerState,
  encodeServiceState,
  fromHex,
  hex,
  nextAfterProviderWithdrawal,
  nextAfterUserWithdrawal,
  uniqueAssetName,
  validityWindow,
  type InstanceDatumFields,
  type ServiceState,
} from "./codec.ts";

type ReadClient = ReturnType<ReturnType<typeof Client.make>["withBlockchainApplied"]>;
type SigningClient = ReturnType<ReadClient["withCip30"]>;
type TxBuilder = ReturnType<SigningClient["newTx"]>;

// Each script is the output of `aiken blueprint apply` against
// bca-token-plutus/plutus.json; its policy id is the script hash, read from
// the payment credential of `scriptAddress`.
export interface AppliedScript {
  compiledCodeHex: string;
  scriptAddress: string; // bech32
}

export interface CardanoAdapterConfig {
  chainId: string; // "cardano:preprod" | "cardano:mainnet" | "cardano:preview"
  chain: Chain; // evolution-sdk-bca's `preprod`/`mainnet`/`preview` chain preset
  api: {
    baseUrl: string; // e.g. "https://staging.blockchain-applied.com/api_preprod/v1"
    token?: string;
  };
  rootFactory: AppliedScript & { bcaAdminPkh: string }; // root_factory(bca_admin)
  sellerFactory: AppliedScript; // seller_factory(root_factory policy id)
  // service_instance(token_policy_id, token_asset_name, seller_factory policy id)
  instance: AppliedScript & { tokenPolicyId: string; tokenAssetNameHex: string };
}

function plutusV3Script(compiledCodeHex: string): Script {
  return new PlutusV3.PlutusV3({ bytes: fromHex(compiledCodeHex) }) as Script;
}

function scriptHashOf(bech32: string): string {
  const details = CardanoAddress.getAddressDetails(bech32);
  const cred = details?.paymentCredential;
  if (!cred || cred._tag !== "ScriptHash") {
    throw new Error(`${bech32} is not a script address`);
  }
  return hex(cred.hash);
}

function keyHashOf(bech32: string): string {
  const hash = CardanoAddress.getAddressDetails(bech32)?.paymentCredential?.hash;
  if (!hash) throw new Error(`could not resolve payment key hash for ${bech32}`);
  return hex(hash);
}

function uniqueAssetNameOf(utxo: UTxO): string {
  return uniqueAssetName(TransactionHash.toBytes(utxo.transactionId), utxo.index);
}

function inlineDatum(utxo: UTxO): Data.Data {
  const option = utxo.datumOption;
  if (!option || option._tag !== "InlineDatum") {
    throw new Error(`UTxO ${hex(TransactionHash.toBytes(utxo.transactionId))}#${utxo.index} has no inline datum`);
  }
  return option.data;
}

export class CardanoAdapter implements ChainAdapter {
  readonly chainId: string;
  private readonly readClient: ReadClient;
  private readonly config: CardanoAdapterConfig;
  private readonly scripts: { root: Script; seller: Script; instance: Script };
  private readonly policy: { root: string; seller: string; instance: string };
  private signingClient?: SigningClient;

  private constructor(readClient: ReadClient, config: CardanoAdapterConfig) {
    this.chainId = config.chainId;
    this.readClient = readClient;
    this.config = config;
    this.scripts = {
      root: plutusV3Script(config.rootFactory.compiledCodeHex),
      seller: plutusV3Script(config.sellerFactory.compiledCodeHex),
      instance: plutusV3Script(config.instance.compiledCodeHex),
    };
    this.policy = {
      root: scriptHashOf(config.rootFactory.scriptAddress),
      seller: scriptHashOf(config.sellerFactory.scriptAddress),
      instance: scriptHashOf(config.instance.scriptAddress),
    };
  }

  static init(config: CardanoAdapterConfig): CardanoAdapter {
    const readClient = Client.make(config.chain).withBlockchainApplied({
      baseUrl: config.api.baseUrl,
      token: config.api.token,
    });
    return new CardanoAdapter(readClient, config);
  }

  private requireWallet(): SigningClient {
    if (!this.signingClient) {
      throw new Error("CardanoAdapter: call connectWallet() before any signing operation");
    }
    return this.signingClient;
  }

  private async walletKeyHash() {
    const address = await this.requireWallet().address();
    return expectKeyHash(address.paymentCredential);
  }

  async connectWallet(): Promise<WalletHandle> {
    // CIP-30 browser wallet (Eternl/Nami/Lace/...), the Cardano equivalent of window.ethereum.
    const api = await (
      window as unknown as { cardano: Record<string, { enable(): Promise<unknown> }> }
    ).cardano.eternl.enable();
    this.signingClient = this.readClient.withCip30(api as never);
    const address = await this.signingClient.address();
    return { address: asAddress(CardanoAddress.toBech32(address)), chainId: this.chainId };
  }

  async getBalance(addr: Address, token: TokenRef): Promise<bigint> {
    const utxos = await this.readClient.getUtxos(CardanoAddress.fromBech32(addr));
    return utxos.reduce((sum, utxo) => sum + CardanoAssets.getByUnit(utxo.assets, token as unknown as string), 0n);
  }

  // The UTxO at `scriptAddress` holding state token `unit`.
  private async findState(scriptAddress: string, unit: string): Promise<UTxO> {
    const utxos = await this.readClient.getUtxos(CardanoAddress.fromBech32(scriptAddress));
    const matches = utxos.filter((u) => CardanoAssets.getByUnit(u.assets, unit) === 1n);
    if (matches.length !== 1) {
      throw new Error(`expected one UTxO holding ${unit} at ${scriptAddress}, found ${matches.length}`);
    }
    return matches[0];
  }

  private requireUnitOf(ref: ContractRef, policyId: string, what: string): string {
    const unit = ref as unknown as string;
    if (!unit.startsWith(policyId) || unit.length <= policyId.length) {
      throw new Error(`${what} ${unit} is not a token of policy ${policyId}`);
    }
    return unit;
  }

  // Re-locks a state UTxO at its own address with the same lovelace (the
  // validators reject less) and exactly `tokens`.
  private payState(builder: TxBuilder, utxo: UTxO, tokens: Record<string, bigint>, datum: Data.Data): TxBuilder {
    return builder.payToAddress({
      address: utxo.address,
      assets: CardanoAssets.fromRecord({ lovelace: CardanoAssets.lovelaceOf(utxo.assets), ...tokens }),
      datum: new InlineDatum.InlineDatum({ data: datum }),
      autoMinUtxo: true,
    });
  }

  private async submit(builder: TxBuilder): Promise<string> {
    const signed = await (await builder.build()).sign();
    const txHash = await signed.submit();
    await this.requireWallet().awaitTx(txHash);
    return String(txHash);
  }

  // root_factory mint: needs bca_admin's signature (wallet must be the admin).
  async deploySellerFactory(rootFactory: ContractRef, seller: Address): Promise<ContractRef> {
    if ((rootFactory as unknown as string) !== this.policy.root) {
      throw new Error(`rootFactory ${rootFactory} is not the configured root_factory policy ${this.policy.root}`);
    }
    const client = this.requireWallet();
    const sellerPkh = keyHashOf(seller);
    const unit = this.policy.root + sellerPkh;

    await this.submit(
      client
        .newTx()
        .attachScript({ script: this.scripts.root })
        .mintAssets({ assets: CardanoAssets.fromRecord({ [unit]: 1n }), redeemer: Redeemer.onboardSeller(sellerPkh) })
        .payToAddress({
          address: CardanoAddress.fromBech32(this.config.rootFactory.scriptAddress),
          assets: CardanoAssets.fromRecord({ lovelace: 2_000_000n, [unit]: 1n }),
          datum: new InlineDatum.InlineDatum({
            data: encodeSellerState({ seller: fromHex(sellerPkh), serviceCount: 0n }),
          }),
          autoMinUtxo: true,
        })
        .addSigner({ keyHash: KeyHash.fromBytes(fromHex(this.config.rootFactory.bcaAdminPkh)) }),
    );
    return asContractRef(unit);
  }

  // seller_factory mint: consumes the seller's root_factory state (wallet must be the seller).
  async defineService(sellerFactory: ContractRef, params: ServiceParams): Promise<ContractRef> {
    const client = this.requireWallet();
    const sellerUnit = this.requireUnitOf(sellerFactory, this.policy.root, "sellerFactory");
    const sellerUtxo = await this.findState(this.config.rootFactory.scriptAddress, sellerUnit);
    const seller = decodeSellerState(inlineDatum(sellerUtxo));
    const serviceUnit = this.policy.seller + uniqueAssetNameOf(sellerUtxo);
    const service: ServiceState = {
      seller: seller.seller,
      serviceIndex: seller.serviceCount,
      maxInstances: BigInt(params.maxInstances),
      dayPrice: params.dayPrice,
      instanceCount: 0n,
    };

    let builder = client
      .newTx()
      .attachScript({ script: this.scripts.root })
      .attachScript({ script: this.scripts.seller })
      .collectFrom({ inputs: [sellerUtxo], redeemer: anyRedeemer })
      .mintAssets({ assets: CardanoAssets.fromRecord({ [serviceUnit]: 1n }), redeemer: Redeemer.defineService(params) });
    builder = this.payState(
      builder,
      sellerUtxo,
      { [sellerUnit]: 1n },
      encodeSellerState({ ...seller, serviceCount: seller.serviceCount + 1n }),
    );
    builder = builder
      .payToAddress({
        address: CardanoAddress.fromBech32(this.config.sellerFactory.scriptAddress),
        assets: CardanoAssets.fromRecord({ lovelace: 2_000_000n, [serviceUnit]: 1n }),
        datum: new InlineDatum.InlineDatum({ data: encodeServiceState(service) }),
        autoMinUtxo: true,
      })
      .addSigner({ keyHash: await this.walletKeyHash() });
    await this.submit(builder);
    return asContractRef(serviceUnit);
  }

  // service_instance mint: consumes the service state; anyone may open (like BCA_Service.newInstance).
  async openInstance(serviceRef: ContractRef, clientAddress: Address): Promise<ContractRef> {
    const client = this.requireWallet();
    const serviceUnit = this.requireUnitOf(serviceRef, this.policy.seller, "service");
    const serviceUtxo = await this.findState(this.config.sellerFactory.scriptAddress, serviceUnit);
    const service = decodeServiceState(inlineDatum(serviceUtxo));
    if (service.instanceCount >= service.maxInstances) {
      throw new Error(`service ${serviceUnit} has no free instance slot (max ${service.maxInstances})`);
    }
    const userPkh = keyHashOf(clientAddress);
    const instanceUnit = this.policy.instance + uniqueAssetNameOf(serviceUtxo);
    const opened: InstanceDatumFields = {
      dayPrice: service.dayPrice,
      deposit: 0n,
      retracted: 0n,
      startTime: 0n,
      endTime: 0n,
      user: fromHex(userPkh),
      provider: service.seller,
      service: fromHex(serviceUnit.slice(this.policy.seller.length)),
    };

    let builder = client
      .newTx()
      .attachScript({ script: this.scripts.seller })
      .attachScript({ script: this.scripts.instance })
      .collectFrom({ inputs: [serviceUtxo], redeemer: anyRedeemer })
      .mintAssets({ assets: CardanoAssets.fromRecord({ [instanceUnit]: 1n }), redeemer: Redeemer.openInstance(userPkh) });
    builder = this.payState(
      builder,
      serviceUtxo,
      { [serviceUnit]: 1n },
      encodeServiceState({ ...service, instanceCount: service.instanceCount + 1n }),
    );
    builder = builder.payToAddress({
      address: CardanoAddress.fromBech32(this.config.instance.scriptAddress),
      assets: CardanoAssets.fromRecord({ lovelace: 2_000_000n, [instanceUnit]: 1n }),
      datum: new InlineDatum.InlineDatum({ data: encodeInstanceDatum(opened) }),
      autoMinUtxo: true,
    });
    await this.submit(builder);
    return asContractRef(instanceUnit);
  }

  private async findInstance(instance: ContractRef) {
    const unit = this.requireUnitOf(instance, this.policy.instance, "instance");
    const utxo = await this.findState(this.config.instance.scriptAddress, unit);
    return { unit, utxo, datum: decodeInstanceDatum(inlineDatum(utxo)) };
  }

  private async spendInstance(
    instance: ContractRef,
    redeemer: Data.Data,
    next: (current: InstanceDatumFields, window: { lower: bigint; upper: bigint }) => InstanceDatumFields,
  ): Promise<TxHandle> {
    const client = this.requireWallet();
    const { unit, utxo, datum } = await this.findInstance(instance);
    const window = validityWindow();
    const nextDatum = next(datum, window);
    const held = nextDatum.deposit - nextDatum.retracted;
    const tokenUnit = this.config.instance.tokenPolicyId + this.config.instance.tokenAssetNameHex;

    let builder = client
      .newTx()
      .attachScript({ script: this.scripts.instance })
      .collectFrom({ inputs: [utxo], redeemer })
      .addSigner({ keyHash: await this.walletKeyHash() })
      .setValidity({ from: window.lower, to: window.upper });
    builder = this.payState(
      builder,
      utxo,
      held > 0n ? { [unit]: 1n, [tokenUnit]: held } : { [unit]: 1n },
      encodeInstanceDatum(nextDatum),
    );
    return { txHash: await this.submit(builder) };
  }

  // MakeDeposit: the clock starts at the validity lower bound (see clock_for).
  deposit(instance: ContractRef, amount: bigint): Promise<TxHandle> {
    return this.spendInstance(instance, Redeemer.makeDeposit(amount), (d, { lower }) => {
      if (amount <= 0n || d.endTime !== 0n) throw new Error("deposit: instance stopped or amount not positive");
      return { ...d, deposit: d.deposit + amount, startTime: d.startTime === 0n ? lower : d.startTime };
    });
  }

  // User side reads the upper bound, provider side the lower one (see clock_for).
  withdraw(instance: ContractRef, amount: bigint, as: "client" | "seller"): Promise<TxHandle> {
    return as === "client"
      ? this.spendInstance(instance, Redeemer.withdrawUser(amount), (d, { upper }) =>
          nextAfterUserWithdrawal(d, amount, upper),
        )
      : this.spendInstance(instance, Redeemer.withdrawProvider(amount), (d, { lower }) =>
          nextAfterProviderWithdrawal(d, amount, lower),
        );
  }

  // Stop reads the upper bound when the user signs, the lower one otherwise.
  async stop(instance: ContractRef): Promise<TxHandle> {
    const signer = hex((await this.walletKeyHash()).hash);
    return this.spendInstance(instance, Redeemer.stop, (d, { lower, upper }) => {
      if (d.endTime !== 0n) throw new Error("stop: instance already stopped");
      return { ...d, endTime: signer === hex(d.user) ? upper : lower };
    });
  }

  // Retires a stopped instance and burns its state token. Either party once no
  // BCA1 is left; with a remaining balance both must sign (add the other
  // party's signature before submitting) and the remainder goes wherever this
  // transaction sends it.
  async close(instance: ContractRef): Promise<TxHandle> {
    const client = this.requireWallet();
    const { unit, utxo, datum } = await this.findInstance(instance);
    if (datum.endTime === 0n) throw new Error("close: stop the instance first");
    const builder = client
      .newTx()
      .attachScript({ script: this.scripts.instance })
      .collectFrom({ inputs: [utxo], redeemer: Redeemer.close })
      .mintAssets({ assets: CardanoAssets.fromRecord({ [unit]: -1n }), redeemer: Redeemer.burnInstance })
      .addSigner({ keyHash: await this.walletKeyHash() });
    return { txHash: await this.submit(builder) };
  }

  async getInstanceState(instance: ContractRef): Promise<InstanceState> {
    const { datum } = await this.findInstance(instance);
    return {
      dayPrice: datum.dayPrice,
      deposit: datum.deposit,
      retracted: datum.retracted,
      startTime: Number(datum.startTime),
      endTime: Number(datum.endTime),
      userAddress: asAddress(hex(datum.user)),
      providerAddress: asAddress(hex(datum.provider)),
      tokenAddress: (this.config.instance.tokenPolicyId + this.config.instance.tokenAssetNameHex) as unknown as TokenRef,
    };
  }

  // No native event log like EVM; needs UTxO polling by policy id. Not implemented yet.
  subscribeEvents(_filter: EventFilter, _cb: (e: ChainEvent) => void): Unsubscribe {
    throw new Error("CardanoAdapter.subscribeEvents() is not implemented yet");
  }
}
