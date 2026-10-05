//// The contract a client funds — Plutus counterpart of
//// BCA_ServiceInstance.sol. One shared validator script per BCA1-token
//// class (parameterized by that token's policy id + asset name, mirroring
//// the EVM contract's immutable `tokToken`); individual instances are
//// distinguished by the datum locked at each UTxO, not by separate
//// addresses — the idiomatic Plutus equivalent of "one deployed contract
//// per client" (see plan-reorg.md §6.1).
////
//// All the actual business logic (balance math, state transitions, auth
//// rules) lives in lib/bca/instance.ak as pure, unit-tested functions; this
//// validator is just the glue that resolves "own input" / "continuing
//// output" and checks the transaction against what that logic expects.
////
//// Known simplifications, tracked for plan-reorg.md §6.3 step 4 alongside
//// service.ak/funder.ak:
//// - `now` is read from the validity range's upper bound, used uniformly
////   for both user- and provider-side balance math. The two sides have
////   opposing incentives about which bound favors them; off-chain
////   transaction building (packages/chain-adapter-cardano) should keep the
////   validity range tight to bound the resulting discrepancy — not enforced
////   on-chain here yet.
//// - only the BCA1 token quantity is checked against the continuing
////   output's value (`deposit - retracted`), not the full value (e.g. min
////   ADA) or that exactly one continuing output exists at a *lower* index
////   than any unrelated outputs — fine for a single-instance-per-tx
////   scaffold, not yet hardened against multi-instance batched transactions.
//// - does not verify a "service" auth token (minted by seller_factory, per
////   validators/seller_factory.ak) is referenced, i.e. nothing yet ties an
////   instance UTxO back to a specific service/seller_factory on-chain.

use aiken/interval.{Finite}
use bca/instance.{is_authorized, next_datum}
use bca/types.{InstanceRedeemer, ServiceInstanceDatum}
use cardano/address.{Script}
use cardano/assets.{AssetName, PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, OutputReference, Transaction, find_input, find_script_outputs,
}

validator service_instance(
  token_policy_id: PolicyId,
  token_asset_name: AssetName,
) {
  spend(
    datum: Option<ServiceInstanceDatum>,
    redeemer: InstanceRedeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(current) = datum
    expect Some(own_input) = find_input(self.inputs, own_ref)
    expect Script(own_hash) = own_input.output.address.payment_credential

    expect Finite(now) = self.validity_range.upper_bound.bound_type

    expect Some(expected_next) = next_datum(current, redeemer, now)

    expect [continuing_output] = find_script_outputs(self.outputs, own_hash)
    expect InlineDatum(raw_next) = continuing_output.datum
    expect actual_next: ServiceInstanceDatum = raw_next

    let expected_token_qty = expected_next.deposit - expected_next.retracted
    let actual_token_qty = quantity_of(
      continuing_output.value,
      token_policy_id,
      token_asset_name,
    )

    and {
      actual_next == expected_next,
      actual_token_qty == expected_token_qty,
      is_authorized(current, redeemer, self.extra_signatories),
    }
  }

  else(_) {
    fail
  }
}
