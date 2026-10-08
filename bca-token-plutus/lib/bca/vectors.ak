//// CBOR encodings of every datum and redeemer, pinned. The same hex strings
//// are decoded by packages/chain-adapter-cardano/test/codec.test.ts, so a
//// change to a type's layout here must be mirrored in the off-chain codec.
//// Test-only module.

use aiken/cbor
use bca/types.{
  BurnInstance, Close, DefineService, MakeDeposit, OnboardSeller, OpenInstance,
  SellerFactoryDatum, ServiceDatum, ServiceInstanceDatum, Stop, WithdrawProvider,
  WithdrawUser,
}

const user = #"01010101010101010101010101010101010101010101010101010101"

const seller = #"02020202020202020202020202020202020202020202020202020202"

const service = #"5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e"

test seller_factory_datum_encoding() {
  cbor.serialise(SellerFactoryDatum { seller, service_count: 7 }) == #"d8799f581c0202020202020202020202020202020202020202020202020202020207ff"
}

test service_datum_encoding() {
  cbor.serialise(
    ServiceDatum {
      seller,
      service_index: 3,
      max_instances: 5,
      day_price: 86_400_000_000,
      instance_count: 2,
    },
  ) == #"d8799f581c0202020202020202020202020202020202020202020202020202020203051b000000141dd7600002ff"
}

test service_instance_datum_encoding() {
  cbor.serialise(
    ServiceInstanceDatum {
      day_price: 10_000_000,
      deposit: 120_000_000,
      retracted: 2_214_062,
      start_time: 1_721_000_000_000,
      end_time: 0,
      user,
      provider: seller,
      service,
    },
  ) == #"d8799f1a009896801a07270e001a0021c8ae1b00000190b397fa0000581c01010101010101010101010101010101010101010101010101010101581c02020202020202020202020202020202020202020202020202020202581c5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5eff"
}

test mint_redeemer_encodings() {
  and {
    cbor.serialise(OnboardSeller { seller }) == #"d8799f581c02020202020202020202020202020202020202020202020202020202ff",
    cbor.serialise(
      DefineService { max_instances: 5, day_price: 86_400_000_000 },
    ) == #"d8799f051b000000141dd76000ff",
    cbor.serialise(OpenInstance { user }) == #"d8799f581c01010101010101010101010101010101010101010101010101010101ff",
    cbor.serialise(BurnInstance) == #"d87a80",
  }
}

test instance_redeemer_encodings() {
  and {
    cbor.serialise(MakeDeposit(100)) == #"d8799f1864ff",
    cbor.serialise(WithdrawUser(7)) == #"d87a9f07ff",
    cbor.serialise(WithdrawProvider(8)) == #"d87b9f08ff",
    cbor.serialise(Stop) == #"d87c80",
    cbor.serialise(Close) == #"d87d80",
  }
}
