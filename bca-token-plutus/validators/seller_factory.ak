//// One seller_factory validator instance per seller — parameterized by the
//// root_factory policy ID (proof this seller was actually onboarded by BCA)
//// and the seller's own key hash. Mints one "service" auth token per
//// newService() call, asset name = an incrementing service_index, mirroring
//// BCA_ServiceController's `deployedServices` array.
////
//// `aiken build`/`aiken check` pass against this file; it has not been
//// exercised against a real transaction (emulator or testnet) yet.
//// Does not yet verify the root_factory-minted seller token is present in
//// the spending transaction's inputs (would require a reference-input
//// check against root_factory_policy_id) — tracked for plan-reorg.md §6.3
//// step 4 alongside service.ak/instance.ak.

use aiken/collection/dict
use aiken/collection/list
use bca/types.{DefineService, index_to_asset_name}
use cardano/assets
use cardano/transaction.{Transaction}

validator seller_factory(
  _root_factory_policy_id: ByteArray,
  seller: ByteArray,
) {
  mint(redeemer: DefineService, policy_id: ByteArray, self: Transaction) {
    let DefineService { service_index, max_instances, day_price } = redeemer

    let minted = assets.tokens(self.mint, policy_id)
    let expected_name = index_to_asset_name(service_index)

    let only_one_token_named_after_index = when dict.to_pairs(minted) is {
      [Pair(asset_name, amount)] -> asset_name == expected_name && amount == 1
      _ -> False
    }

    let seller_signed = list.has(self.extra_signatories, seller)
    let sane_pricing = max_instances > 0 && day_price > 0

    only_one_token_named_after_index && seller_signed && sane_pricing
  }

  else(_) {
    fail
  }
}
