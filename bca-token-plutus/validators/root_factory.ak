//// Root factory: BCA mints one "seller factory" auth token per onboarded
//// seller. Asset name = the seller's verification-key hash — this is the
//// state-thread / unique-token pattern plan-reorg.md §6.1 calls for in
//// place of EVM's `deployedControllers: mapping(address => Controller)`.
//// Off-chain code enumerates onboarded sellers by querying this policy ID
//// (Blockfrost/Ogmios) instead of calling `countServiceControllers()`.
////
//// `aiken build`/`aiken check` pass against this file; it has not been
//// exercised against a real transaction (emulator or testnet) yet.

use aiken/collection/dict
use aiken/collection/list
use bca/types.{OnboardSeller}
use cardano/assets
use cardano/transaction.{Transaction}

validator root_factory(bca_admin: ByteArray) {
  mint(redeemer: OnboardSeller, policy_id: ByteArray, self: Transaction) {
    let OnboardSeller { seller } = redeemer

    let minted = assets.tokens(self.mint, policy_id)

    let only_one_token_named_after_seller = when dict.to_pairs(minted) is {
      [Pair(asset_name, amount)] -> asset_name == seller && amount == 1
      _ -> False
    }

    let bca_signed_off = list.has(self.extra_signatories, bca_admin)

    only_one_token_named_after_seller && bca_signed_off
  }

  else(_) {
    fail
  }
}
