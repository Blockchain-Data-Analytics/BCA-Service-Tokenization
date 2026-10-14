//// Shared datum/redeemer types for the BCA factory hierarchy, plus the
//// state-token naming helper the minting policies share.
////
//// State lives in UTxOs, each authenticated by exactly one state token:
////
//// | level    | script         | token policy   | token name                 | datum                |
//// |----------|----------------|----------------|----------------------------|----------------------|
//// | seller   | root_factory   | root_factory   | seller key hash            | SellerFactoryDatum   |
//// | service  | seller_factory | seller_factory | unique_asset_name(seller)  | ServiceDatum         |
//// | instance | instance       | instance       | unique_asset_name(service) | ServiceInstanceDatum |
////
//// Each script is both the minting policy of its tokens and the spending
//// validator of the UTxOs holding them (same hash), and is parameterized by
//// its parent's hash only, so parameters flow strictly downwards.

use aiken/builtin
use aiken/crypto.{blake2b_224}
use cardano/transaction.{OutputReference}

/// Mint redeemer for root_factory: onboard one seller.
/// Mirrors BCA_ServiceManager.newController(providerAddress).
pub type OnboardSeller {
  seller: ByteArray,
}

/// Mint redeemer for seller_factory: define one service under an onboarded
/// seller. Mirrors BCA_ServiceController.newService(maxInstances, dayPrice).
/// The service index is not taken from here; it is the seller's
/// `SellerFactoryDatum.service_count` at the time of definition.
pub type DefineService {
  max_instances: Int,
  day_price: Int,
}

/// Datum of a seller's state UTxO at the root_factory address, holding the
/// root_factory token named after the seller.
pub type SellerFactoryDatum {
  seller: ByteArray,
  service_count: Int,
}

/// Datum of a service's state UTxO at the seller_factory address. Mirrors
/// BCA_Service.sol's immutable config plus `deployedInstances.length`.
pub type ServiceDatum {
  seller: ByteArray,
  service_index: Int,
  max_instances: Int,
  day_price: Int,
  instance_count: Int,
}

/// Datum for a funded seller-client instance, ported field-for-field from
/// BCA_ServiceInstance.sol's storage layout, plus `service` (the asset name of
/// the seller_factory token of the service it was opened from).
/// `deposit - retracted` always equals the instance UTxO's held quantity of
/// the BCA1 token.
pub type ServiceInstanceDatum {
  day_price: Int,
  deposit: Int,
  retracted: Int,
  start_time: Int,
  end_time: Int,
  user: ByteArray,
  provider: ByteArray,
  service: ByteArray,
}

/// Spend redeemer for the instance validator. Mirrors BCA_ServiceInstance.sol's
/// makeDeposit/withdrawUser/withdrawProvider/stop entry points; `Close` retires
/// a stopped instance and burns its state token.
pub type InstanceRedeemer {
  MakeDeposit(Int)
  WithdrawUser(Int)
  WithdrawProvider(Int)
  Stop
  Close
}

/// Mint redeemer for the instance validator. `OpenInstance` mirrors
/// BCA_Service.newInstance(userAddress).
pub type InstanceMintRedeemer {
  OpenInstance { user: ByteArray }
  BurnInstance
}

/// Asset name for a child state token, derived from the parent state UTxO
/// consumed to create it. Output references are spent at most once, so names
/// never repeat. 28 bytes.
pub fn unique_asset_name(parent: OutputReference) -> ByteArray {
  blake2b_224(
    builtin.append_bytearray(
      parent.transaction_id,
      builtin.integer_to_bytearray(True, 2, parent.output_index),
    ),
  )
}

const tx_a = #"0000000000000000000000000000000000000000000000000000000000000001"

const tx_b = #"0000000000000000000000000000000000000000000000000000000000000002"

test unique_asset_name_differs_by_index() {
  unique_asset_name(OutputReference(tx_a, 0)) != unique_asset_name(
    OutputReference(tx_a, 1),
  )
}

test unique_asset_name_differs_by_tx() {
  unique_asset_name(OutputReference(tx_a, 0)) != unique_asset_name(
    OutputReference(tx_b, 0),
  )
}

// Same vector as uniqueAssetName() in packages/chain-adapter-cardano, which
// must derive identical names off-chain.
test unique_asset_name_matches_offchain_vector() {
  unique_asset_name(
    OutputReference(
      #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      258,
    ),
  ) == #"1bd5303e341740b2c794f46f94d77edaa90fd38210413d589d0963ac"
}

test unique_asset_name_is_28_bytes() {
  builtin.length_of_bytearray(unique_asset_name(OutputReference(tx_a, 7))) == 28
}
