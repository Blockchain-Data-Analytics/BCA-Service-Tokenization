//// Transaction-shape checks shared by all validators: validity window,
//// locating a script's own inputs/outputs, state-token lookup and the
//// continuing-output rule.

use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Input, NoDatum, Output, OutputReference, ValidityRange}

/// Widest validity range accepted where the contract reads the clock
/// (10 minutes). Bounds how far either party can skew `now`.
pub const max_validity_ms: Int = 600_000

/// Both bounds of `range` when finite, ordered and at most
/// `max_validity_ms` apart.
pub fn validity_window(range: ValidityRange) -> Option<(Int, Int)> {
  when (range.lower_bound.bound_type, range.upper_bound.bound_type) is {
    (Finite(lower), Finite(upper)) ->
      if lower <= upper && upper - lower <= max_validity_ms {
        Some((lower, upper))
      } else {
        None
      }
    _ -> None
  }
}

pub fn inputs_at(inputs: List<Input>, script_hash: ByteArray) -> List<Input> {
  list.filter(
    inputs,
    fn(input) { input.output.address.payment_credential == Script(script_hash) },
  )
}

pub fn outputs_at(outputs: List<Output>, script_hash: ByteArray) -> List<Output> {
  list.filter(
    outputs,
    fn(output) { output.address.payment_credential == Script(script_hash) },
  )
}

/// Name of the one token held under `policy_id`, if `value` holds exactly
/// one token (quantity 1) of that policy.
pub fn single_token(value: Value, policy_id: PolicyId) -> Option<AssetName> {
  when dict.to_pairs(assets.tokens(value, policy_id)) is {
    [Pair(name, 1)] -> Some(name)
    _ -> None
  }
}

/// A continuing state output: same full address (payment and stake
/// credential), exactly `tokens` besides lovelace, and no less lovelace than
/// the input it replaces.
pub fn continues_with(input: Output, output: Output, tokens: Value) -> Bool {
  and {
    output.address == input.address,
    assets.without_lovelace(output.value) == tokens,
    assets.lovelace_of(output.value) >= assets.lovelace_of(input.value),
  }
}

// ## Tests

const script = #"aa"

const policy = #"bb"

fn out(address: Address, value: Value) -> Output {
  Output { address, value, datum: NoDatum, reference_script: None }
}

fn script_address() -> Address {
  Address { payment_credential: Script(script), stake_credential: None }
}

test validity_window_accepts_narrow_finite_range() {
  validity_window(interval.between(1_000, 1_000 + max_validity_ms)) == Some(
    (1_000, 1_000 + max_validity_ms),
  )
}

test validity_window_rejects_wide_range() {
  validity_window(interval.between(1_000, 1_001 + max_validity_ms)) == None
}

test validity_window_rejects_open_upper_bound() {
  validity_window(interval.after(1_000)) == None
}

test validity_window_rejects_open_lower_bound() {
  validity_window(interval.before(1_000)) == None
}

test single_token_requires_exactly_one_unit() {
  let one = assets.from_asset(policy, "a", 1)
  let two = assets.from_asset(policy, "a", 2)
  let pair = assets.add(one, policy, "b", 1)
  and {
    single_token(one, policy) == Some("a"),
    single_token(two, policy) == None,
    single_token(pair, policy) == None,
    single_token(assets.from_lovelace(5), policy) == None,
  }
}

test continues_with_accepts_same_address_and_tokens_more_ada() {
  let tokens = assets.from_asset(policy, "a", 1)
  let input = out(
    script_address(),
    assets.merge(assets.from_lovelace(2), tokens),
  )
  let output = out(
    script_address(),
    assets.merge(assets.from_lovelace(3), tokens),
  )
  continues_with(input, output, tokens)
}

test continues_with_rejects_lovelace_siphon() {
  let tokens = assets.from_asset(policy, "a", 1)
  let input = out(
    script_address(),
    assets.merge(assets.from_lovelace(3), tokens),
  )
  let output = out(
    script_address(),
    assets.merge(assets.from_lovelace(2), tokens),
  )
  !continues_with(input, output, tokens)
}

test continues_with_rejects_foreign_token() {
  let tokens = assets.from_asset(policy, "a", 1)
  let input = out(
    script_address(),
    assets.merge(assets.from_lovelace(2), tokens),
  )
  let output = out(
    script_address(),
    assets.merge(assets.from_lovelace(2), tokens) |> assets.add(#"cc", "x", 1),
  )
  !continues_with(input, output, tokens)
}

test continues_with_rejects_changed_stake_credential() {
  let tokens = assets.from_asset(policy, "a", 1)
  let input = out(
    script_address(),
    assets.merge(assets.from_lovelace(2), tokens),
  )
  let staked = Address {
    payment_credential: Script(script),
    stake_credential: Some(address.Inline(VerificationKey(#"dd"))),
  }
  let output = out(staked, assets.merge(assets.from_lovelace(2), tokens))
  !continues_with(input, output, tokens)
}

test inputs_and_outputs_at_filter_by_payment_script() {
  let mine = out(script_address(), assets.from_lovelace(1))
  let other = out(
    Address {
      payment_credential: VerificationKey(script),
      stake_credential: None,
    },
    assets.from_lovelace(1),
  )
  let ref = OutputReference(#"00", 0)
  and {
    list.length(outputs_at([mine, other, mine], script)) == 2,
    list.length(inputs_at([Input(ref, mine), Input(ref, other)], script)) == 1,
  }
}
