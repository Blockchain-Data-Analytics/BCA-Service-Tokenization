import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Data } from "evolution-sdk-bca";
import {
  DAY_MS,
  Redeemer,
  balanceProvider,
  balanceUser,
  decodeInstanceDatum,
  decodeSellerState,
  decodeServiceState,
  encodeInstanceDatum,
  encodeSellerState,
  encodeServiceState,
  fromHex,
  nextAfterProviderWithdrawal,
  nextAfterUserWithdrawal,
  uniqueAssetName,
  validityWindow,
  type InstanceDatumFields,
} from "../src/codec.ts";

// Pinned on the Aiken side in bca-token-plutus/lib/bca/vectors.ak.
const vectors = {
  sellerState: "d8799f581c0202020202020202020202020202020202020202020202020202020207ff",
  serviceState: "d8799f581c0202020202020202020202020202020202020202020202020202020203051b000000141dd7600002ff",
  instance:
    "d8799f1a009896801a07270e001a0021c8ae1b00000190b397fa0000581c01010101010101010101010101010101010101010101010101010101581c02020202020202020202020202020202020202020202020202020202581c5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5eff",
  onboardSeller: "d8799f581c02020202020202020202020202020202020202020202020202020202ff",
  defineService: "d8799f051b000000141dd76000ff",
  openInstance: "d8799f581c01010101010101010101010101010101010101010101010101010101ff",
  burnInstance: "d87a80",
  makeDeposit: "d8799f1864ff",
  withdrawUser: "d87a9f07ff",
  withdrawProvider: "d87b9f08ff",
  stop: "d87c80",
  close: "d87d80",
};

const user = fromHex("01".repeat(28));
const seller = fromHex("02".repeat(28));
const service = fromHex("5e".repeat(28));

const sellerState = { seller, serviceCount: 7n };
const serviceState = {
  seller,
  serviceIndex: 3n,
  maxInstances: 5n,
  dayPrice: 86_400_000_000n,
  instanceCount: 2n,
};
const instance: InstanceDatumFields = {
  dayPrice: 10_000_000n,
  deposit: 120_000_000n,
  retracted: 2_214_062n,
  startTime: 1_721_000_000_000n,
  endTime: 0n,
  user,
  provider: seller,
  service,
};

describe("datum codec matches the Aiken types", () => {
  it("encodes byte-identically to cbor.serialise", () => {
    assert.equal(Data.toCBORHex(encodeSellerState(sellerState)), vectors.sellerState);
    assert.equal(Data.toCBORHex(encodeServiceState(serviceState)), vectors.serviceState);
    assert.equal(Data.toCBORHex(encodeInstanceDatum(instance)), vectors.instance);
  });

  it("decodes what the validators produce", () => {
    assert.deepEqual(decodeSellerState(Data.fromCBORHex(vectors.sellerState)), sellerState);
    assert.deepEqual(decodeServiceState(Data.fromCBORHex(vectors.serviceState)), serviceState);
    assert.deepEqual(decodeInstanceDatum(Data.fromCBORHex(vectors.instance)), instance);
  });

  it("round-trips large values", () => {
    const big = { ...instance, dayPrice: 10n ** 24n, deposit: 2n ** 70n, startTime: 2n ** 45n };
    assert.deepEqual(decodeInstanceDatum(Data.fromCBORHex(Data.toCBORHex(encodeInstanceDatum(big)))), big);
  });

  it("rejects datums of another shape", () => {
    assert.throws(() => decodeInstanceDatum(Data.fromCBORHex(vectors.serviceState)), /ServiceInstanceDatum/);
    assert.throws(() => decodeServiceState(Data.fromCBORHex(vectors.sellerState)), /ServiceDatum/);
    assert.throws(() => decodeSellerState(Data.int(1n)), /SellerFactoryDatum/);
  });
});

describe("redeemers match the Aiken constructors", () => {
  const cases: Array<[string, Data.Data, string]> = [
    ["OnboardSeller", Redeemer.onboardSeller("02".repeat(28)), vectors.onboardSeller],
    ["DefineService", Redeemer.defineService({ maxInstances: 5, dayPrice: 86_400_000_000n }), vectors.defineService],
    ["OpenInstance", Redeemer.openInstance("01".repeat(28)), vectors.openInstance],
    ["BurnInstance", Redeemer.burnInstance, vectors.burnInstance],
    ["MakeDeposit", Redeemer.makeDeposit(100n), vectors.makeDeposit],
    ["WithdrawUser", Redeemer.withdrawUser(7n), vectors.withdrawUser],
    ["WithdrawProvider", Redeemer.withdrawProvider(8n), vectors.withdrawProvider],
    ["Stop", Redeemer.stop, vectors.stop],
    ["Close", Redeemer.close, vectors.close],
  ];
  for (const [name, redeemer, hex] of cases) {
    it(name, () => assert.equal(Data.toCBORHex(redeemer), hex));
  }
});

describe("uniqueAssetName", () => {
  it("matches the Aiken vector (types.ak)", () => {
    assert.equal(
      uniqueAssetName(fromHex("aa".repeat(32)), 258n),
      "1bd5303e341740b2c794f46f94d77edaa90fd38210413d589d0963ac",
    );
  });

  it("depends on the output index", () => {
    assert.notEqual(uniqueAssetName(fromHex("aa".repeat(32)), 0), uniqueAssetName(fromHex("aa".repeat(32)), 1));
  });
});

describe("validityWindow", () => {
  it("is whole seconds, starts 60 s back and stays within the on-chain 10 minutes", () => {
    const { lower, upper } = validityWindow(1_721_000_000_789);
    assert.equal(lower % 1000n, 0n);
    assert.equal(upper % 1000n, 0n);
    assert.equal(lower, 1_720_999_940_000n);
    assert.ok(upper - lower <= 600_000n);
  });
});

// Same scenarios as lib/bca/instance.ak's unit tests; day_price == day_ms
// makes one day cost DAY_MS units and the dust threshold 1000.
describe("instance state machine mirrors next_datum", () => {
  const running = (deposit: bigint, retracted = 0n, endTime = 0n): InstanceDatumFields => ({
    ...instance,
    dayPrice: DAY_MS,
    deposit,
    retracted,
    startTime: 1n,
    endTime,
  });
  const oneDay = 1n + DAY_MS;

  it("provider cannot claim the same earnings twice", () => {
    const d = running(1_000_000_000n);
    assert.equal(balanceProvider(d, oneDay), DAY_MS);
    const after = nextAfterProviderWithdrawal(d, DAY_MS, oneDay);
    assert.equal(balanceProvider(after, oneDay), 0n);
    assert.throws(() => nextAfterProviderWithdrawal(after, DAY_MS, oneDay), /exceeds provider balance/);
  });

  it("balances always add up to what the instance holds", () => {
    let seed = 42n;
    const rand = (max: bigint) => ((seed = (seed * 6364136223846793005n + 1442695040888963407n) % 2n ** 64n), seed % max);
    for (let i = 0; i < 500; i++) {
      const deposit = rand(10n ** 12n) + 1n;
      const now = 1n + rand(10n * DAY_MS);
      const d = running(deposit, 0n);
      const earned = balanceProvider(d, now);
      const retracted = earned === 0n ? 0n : rand(earned + 1n);
      const s = running(deposit, retracted);
      assert.equal(balanceUser(s, now) + balanceProvider(s, now), s.deposit - s.retracted);
    }
  });

  it("leaving dust behind stops a running instance", () => {
    const d = running(1_000_000_000n);
    const avail = balanceUser(d, oneDay);
    assert.equal(nextAfterUserWithdrawal(d, avail - 1000n, oneDay).endTime, oneDay);
    assert.equal(nextAfterUserWithdrawal(d, avail - 1001n, oneDay).endTime, 0n);
  });

  it("a stopped instance can be drained completely without moving end_time", () => {
    const endTime = 1n + 2n * DAY_MS;
    const stopped = running(1_000_000_000n, 0n, endTime);
    const later = 1n + 10n * DAY_MS;
    const afterUser = nextAfterUserWithdrawal(stopped, balanceUser(stopped, later), later);
    const afterProvider = nextAfterProviderWithdrawal(afterUser, balanceProvider(afterUser, later), later);
    assert.equal(afterProvider.endTime, endTime);
    assert.equal(afterProvider.deposit - afterProvider.retracted, 0n);
  });

  it("refuses withdrawals above the balance or before the first deposit", () => {
    const d = running(1_000_000_000n);
    assert.throws(() => nextAfterUserWithdrawal(d, balanceUser(d, oneDay) + 1n, oneDay), /exceeds user balance/);
    assert.throws(() => nextAfterUserWithdrawal({ ...d, startTime: 0n }, 1n, oneDay), /exceeds user balance/);
  });
});
