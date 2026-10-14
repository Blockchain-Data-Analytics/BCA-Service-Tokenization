// Pure codecs and state logic mirroring bca-token-plutus, kept free of
// wallet/network access so they can be unit-tested (test/codec.test.ts).
import { blake2b } from "@noble/hashes/blake2.js";
import { Data } from "evolution-sdk-bca";
import type { ServiceParams } from "@bca/chain-adapter";

export const DAY_MS = 86_400_000n;

// Validity window used for every instance spend. Must stay within the
// on-chain `max_validity_ms` (10 min, lib/bca/tx.ak). Bounds are whole
// seconds: validity intervals are slot-granular and a non-aligned
// millisecond value drifts in the ms -> slot -> ms round trip, so the
// on-chain `now` would differ from the one used to build the datum.
const VALIDITY_LEAD_S = 60; // lower bound this far in the past (clock skew)
const VALIDITY_SPAN_S = 300;

export function validityWindow(nowMs: number = Date.now()): { lower: bigint; upper: bigint } {
  const lowerS = Math.floor(nowMs / 1000) - VALIDITY_LEAD_S;
  return { lower: BigInt(lowerS * 1000), upper: BigInt((lowerS + VALIDITY_SPAN_S) * 1000) };
}

export const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex");
export const fromHex = (s: string): Uint8Array => Uint8Array.from(Buffer.from(s, "hex"));

export function constrFields(data: Data.Data, arity: number, what: string): Data.Data[] {
  if (!Data.isConstr(data) || data.fields.length !== arity) {
    throw new Error(`datum is not a ${what}`);
  }
  return data.fields as Data.Data[];
}

// ## Datums (field order mirrors lib/bca/types.ak; all Constr index 0)

export interface SellerState {
  seller: Uint8Array;
  serviceCount: bigint;
}

export const decodeSellerState = (data: Data.Data): SellerState => {
  const [seller, serviceCount] = constrFields(data, 2, "SellerFactoryDatum") as [Uint8Array, bigint];
  return { seller, serviceCount };
};

export const encodeSellerState = (s: SellerState): Data.Data => Data.constr(0n, [s.seller, Data.int(s.serviceCount)]);

export interface ServiceState {
  seller: Uint8Array;
  serviceIndex: bigint;
  maxInstances: bigint;
  dayPrice: bigint;
  instanceCount: bigint;
}

export const decodeServiceState = (data: Data.Data): ServiceState => {
  const [seller, serviceIndex, maxInstances, dayPrice, instanceCount] = constrFields(data, 5, "ServiceDatum") as [
    Uint8Array,
    bigint,
    bigint,
    bigint,
    bigint,
  ];
  return { seller, serviceIndex, maxInstances, dayPrice, instanceCount };
};

export const encodeServiceState = (s: ServiceState): Data.Data =>
  Data.constr(0n, [
    s.seller,
    Data.int(s.serviceIndex),
    Data.int(s.maxInstances),
    Data.int(s.dayPrice),
    Data.int(s.instanceCount),
  ]);

export interface InstanceDatumFields {
  dayPrice: bigint;
  deposit: bigint;
  retracted: bigint;
  startTime: bigint;
  endTime: bigint;
  user: Uint8Array;
  provider: Uint8Array;
  service: Uint8Array;
}

export function decodeInstanceDatum(data: Data.Data): InstanceDatumFields {
  const [dayPrice, deposit, retracted, startTime, endTime, user, provider, service] = constrFields(
    data,
    8,
    "ServiceInstanceDatum",
  ) as [bigint, bigint, bigint, bigint, bigint, Uint8Array, Uint8Array, Uint8Array];
  return { dayPrice, deposit, retracted, startTime, endTime, user, provider, service };
}

export function encodeInstanceDatum(f: InstanceDatumFields): Data.Data {
  return Data.constr(0n, [
    Data.int(f.dayPrice),
    Data.int(f.deposit),
    Data.int(f.retracted),
    Data.int(f.startTime),
    Data.int(f.endTime),
    f.user,
    f.provider,
    f.service,
  ]);
}

// ## Redeemers (constructor indices mirror lib/bca/types.ak)

export const anyRedeemer = Data.constr(0n, []);
export const Redeemer = {
  onboardSeller: (seller: string) => Data.constr(0n, [Data.bytearray(seller)]),
  defineService: (p: ServiceParams) => Data.constr(0n, [Data.int(BigInt(p.maxInstances)), Data.int(p.dayPrice)]),
  openInstance: (user: string) => Data.constr(0n, [Data.bytearray(user)]),
  burnInstance: Data.constr(1n, []),
  makeDeposit: (amount: bigint) => Data.constr(0n, [Data.int(amount)]),
  withdrawUser: (amount: bigint) => Data.constr(1n, [Data.int(amount)]),
  withdrawProvider: (amount: bigint) => Data.constr(2n, [Data.int(amount)]),
  stop: Data.constr(3n, []),
  close: Data.constr(4n, []),
};

// ## Instance state machine, mirrors lib/bca/instance.ak (next_datum)

export function balanceUser(d: InstanceDatumFields, now: bigint): bigint {
  const calcTime = d.endTime !== 0n ? d.endTime : now;
  const paid = ((calcTime - d.startTime) * d.dayPrice) / DAY_MS;
  return paid >= d.deposit ? 0n : d.deposit - paid;
}

export function balanceProvider(d: InstanceDatumFields, now: bigint): bigint {
  const calcTime = d.endTime !== 0n ? d.endTime : now;
  const earned = ((calcTime - d.startTime) * d.dayPrice) / DAY_MS;
  const capped = earned > d.deposit ? d.deposit : earned;
  return capped > d.retracted ? capped - d.retracted : 0n;
}

// is_dust + end_time_after_withdrawal: leaving at most one second's worth stops a running instance.
export function endTimeAfterWithdrawal(d: InstanceDatumFields, remaining: bigint, now: bigint): bigint {
  return d.endTime === 0n && remaining <= d.dayPrice / 86_400n ? now : d.endTime;
}

export function nextAfterUserWithdrawal(d: InstanceDatumFields, amount: bigint, now: bigint): InstanceDatumFields {
  const avail = balanceUser(d, now);
  if (d.startTime === 0n || amount <= 0n || amount > avail) {
    throw new Error(`withdraw: amount ${amount} exceeds user balance ${avail}`);
  }
  return { ...d, deposit: d.deposit - amount, endTime: endTimeAfterWithdrawal(d, avail - amount, now) };
}

export function nextAfterProviderWithdrawal(d: InstanceDatumFields, amount: bigint, now: bigint): InstanceDatumFields {
  const avail = balanceProvider(d, now);
  if (d.startTime === 0n || amount <= 0n || amount > avail) {
    throw new Error(`withdraw: amount ${amount} exceeds provider balance ${avail}`);
  }
  const remaining = d.deposit - d.retracted - amount;
  return { ...d, retracted: d.retracted + amount, endTime: endTimeAfterWithdrawal(d, remaining, now) };
}

// Mirrors types.ak unique_asset_name: blake2b_224(tx_id ++ u16be(index)).
export function uniqueAssetName(transactionId: Uint8Array, index: bigint | number): string {
  const i = Number(index);
  const bytes = new Uint8Array(34);
  bytes.set(transactionId, 0);
  bytes[32] = (i >> 8) & 0xff;
  bytes[33] = i & 0xff;
  return hex(blake2b(bytes, { dkLen: 28 }));
}
