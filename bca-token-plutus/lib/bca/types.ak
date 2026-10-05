//// Shared datum/redeemer types for the BCA factory hierarchy, plus the
//// state-thread-token encoding helpers both minting policies use.
////
//// `aiken build`/`aiken check` pass against this file; it has not been
//// exercised against a real transaction (emulator or testnet) yet (see
//// plan-reorg.md §6.3 step 1).

use aiken/builtin

/// Redeemer for root_factory's minting policy: onboard one seller.
/// Mirrors BCA_ServiceManager.newController(providerAddress).
pub type OnboardSeller {
  seller: ByteArray,
}

/// Redeemer for seller_factory's minting policy: define one service under
/// an already-onboarded seller. Mirrors
/// BCA_ServiceController.newService(maxInstances, dayPrice).
pub type DefineService {
  service_index: Int,
  max_instances: Int,
  day_price: Int,
}

/// Datum for a seller_factory's own UTxO (holds the running service count so
/// the next service_index can be derived on-chain rather than trusted from
/// the redeemer alone). Reserved for wiring up once service.ak lands
/// (plan-reorg.md §6.3 step 4) — root_factory/seller_factory in this slice
/// only prove the minting/state-token pattern.
pub type SellerFactoryDatum {
  seller: ByteArray,
  service_count: Int,
}

/// Datum for a funded seller-client instance, ported field-for-field from
/// BCA_ServiceInstance.sol's storage layout (see validators/instance.ak +
/// lib/bca/instance.ak). `deposit - retracted` must always equal the
/// instance UTxO's held quantity of the BCA1 token — same invariant the EVM
/// contract's token balance keeps implicitly.
pub type ServiceInstanceDatum {
  day_price: Int,
  deposit: Int,
  retracted: Int,
  start_time: Int,
  end_time: Int,
  user: ByteArray,
  provider: ByteArray,
}

/// Redeemer for the instance validator. Mirrors BCA_ServiceInstance.sol's
/// makeDeposit/withdrawUser/withdrawProvider/stop entry points.
pub type InstanceRedeemer {
  MakeDeposit(Int)
  WithdrawUser(Int)
  WithdrawProvider(Int)
  Stop
}

/// Encodes an incrementing index as an asset name, used by seller_factory to
/// name each "service" auth token uniquely (mirrors
/// BCA_ServiceController.deployedServices' array-index addressing).
pub fn index_to_asset_name(index: Int) -> ByteArray {
  builtin.integer_to_bytearray(True, 8, index)
}

test index_to_asset_name_is_distinct_per_index() {
  index_to_asset_name(0) != index_to_asset_name(1)
}

test index_to_asset_name_is_stable() {
  index_to_asset_name(42) == index_to_asset_name(42)
}
