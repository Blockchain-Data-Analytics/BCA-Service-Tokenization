// Chain-neutral extension point for new contract backends.
// Any new chain (EVM, Cardano, ...) implements ChainAdapter once; apps/services
// depend only on this interface, selected at runtime by `chainId`.
// See plan-reorg.md §4.

// Opaque, chain-specific identifiers wrapped in branded types so app code never
// string-concatenates a chain-specific address/script-ref format.
export type Address = string & { readonly __brand: "Address" };
export type ContractRef = string & { readonly __brand: "ContractRef" };
export type TokenRef = string & { readonly __brand: "TokenRef" };

export function asAddress(v: string): Address {
  return v as Address;
}
export function asContractRef(v: string): ContractRef {
  return v as ContractRef;
}
export function asTokenRef(v: string): TokenRef {
  return v as TokenRef;
}

export interface WalletHandle {
  address: Address;
  chainId: string;
  networkName?: string;
}

export interface TxHandle {
  txHash: string;
}

export interface ServiceParams {
  maxInstances: number;
  dayPrice: bigint;
}

// Mirrors BCA_ServiceInstance's datum fields today (deposit/retracted/startTime/
// endTime/dayPrice) — same shape ports to the Plutus instance validator's datum,
// see plan-reorg.md §6.1.
export interface InstanceState {
  dayPrice: bigint;
  deposit: bigint;
  retracted: bigint;
  startTime: number;
  endTime: number;
  userAddress: Address;
  providerAddress: Address;
  tokenAddress: TokenRef;
}

export interface ChainEvent {
  kind: string;
  contractAddress: string;
  blockRef: string | number;
  txHash?: string;
  returnValues: Record<string, unknown>;
}

export interface EventFilter {
  address?: ContractRef;
  fromBlock?: number | string;
  toBlock?: number | string;
}

export type Unsubscribe = () => void;

export interface ChainAdapter {
  readonly chainId: string; // "evm:polygon-amoy" | "cardano:preprod"

  connectWallet(): Promise<WalletHandle>;
  getBalance(addr: Address, token: TokenRef): Promise<bigint>;

  // factory hierarchy, generic across chains
  deploySellerFactory(rootFactory: ContractRef, seller: Address): Promise<ContractRef>;
  defineService(sellerFactory: ContractRef, params: ServiceParams): Promise<ContractRef>;
  openInstance(service: ContractRef, client: Address): Promise<ContractRef>;

  deposit(instance: ContractRef, amount: bigint): Promise<TxHandle>;
  withdraw(instance: ContractRef, amount: bigint, as: "client" | "seller"): Promise<TxHandle>;
  stop(instance: ContractRef): Promise<TxHandle>;

  getInstanceState(instance: ContractRef): Promise<InstanceState>;

  // monitoring
  subscribeEvents(filter: EventFilter, cb: (e: ChainEvent) => void): Unsubscribe;
}

// Pure balance-calc helpers, chain-neutral port of what today lives in
// bca-token-market/src/lib/contracts.ts (calculate_user_balance /
// calculate_provider_balance). Every ChainAdapter implementation evaluates the
// same arithmetic against its own notion of "now" (block time for EVM, slot
// time for Cardano) so this logic only needs to exist once.
export function calculateUserBalance(
  deposit: bigint,
  startTime: number,
  dayPrice: bigint,
  nowMs: number = Date.now(),
): bigint {
  if (startTime <= 0) return deposit;
  const deltaMs = BigInt(Math.max(0, nowMs - startTime * 1000));
  const elapsed = (dayPrice * deltaMs) / 86_400_000n;
  return deposit > elapsed ? deposit - elapsed : 0n;
}

export function calculateProviderBalance(
  deposit: bigint,
  retracted: bigint,
  startTime: number,
  dayPrice: bigint,
  nowMs: number = Date.now(),
): bigint {
  if (startTime <= 0) return deposit > retracted ? deposit - retracted : 0n;
  const deltaMs = BigInt(Math.max(0, nowMs - startTime * 1000));
  const elapsed = (dayPrice * deltaMs) / 86_400_000n;
  const earned = elapsed < deposit ? elapsed : deposit;
  return earned > retracted ? earned - retracted : 0n;
}
