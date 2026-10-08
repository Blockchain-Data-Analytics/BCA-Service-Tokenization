//// Property tests for the instance business logic (lib/bca/instance.ak) and
//// the shared helpers. Test-only module: nothing here is used by validators.
////
//// The main property drives an instance from its opened state through a
//// random sequence of deposits, withdrawals and stops at random times, using
//// next_datum exactly like the validator does, and checks the invariants
//// after every step. Raise the number of runs with
//// `aiken check --max-success 1000`.

use aiken/builtin
use aiken/collection/list
use aiken/fuzz
use aiken/interval
use bca/instance.{
  balance_provider, balance_user, clock_for, day_ms, is_dust, next_datum,
}
use bca/tx.{max_validity_ms, validity_window}
use bca/types.{
  InstanceRedeemer, MakeDeposit, ServiceInstanceDatum, Stop, WithdrawProvider,
  WithdrawUser, unique_asset_name,
}
use cardano/transaction.{OutputReference}

// ## Random walk over instance states

type Step {
  kind: Int,
  // deposit size, per mille of the available balance to withdraw, or the
  // excess for an over-withdrawal attempt
  seed: Int,
  // time passed before this step, in ms
  dt: Int,
}

type Scenario {
  day_price: Int,
  steps: List<Step>,
}

fn scenario() -> Fuzzer<Scenario> {
  fuzz.map2(
    // from below 86_400/day (dust threshold 0) up to 18-decimal token prices
    fuzz.either(
      fuzz.int_between(1, 100_000),
      fuzz.int_between(1, 1_000_000_000_000_000_000),
    ),
    fuzz.list_between(
      fuzz.map3(
        fuzz.int_between(0, 5),
        fuzz.int_between(0, 1_000),
        fuzz.int_between(0, 3 * day_ms),
        fn(kind, seed, dt) { Step { kind, seed, dt } },
      ),
      1,
      25,
    ),
    fn(day_price, steps) { Scenario { day_price, steps } },
  )
}

type Walk {
  datum: ServiceInstanceDatum,
  now: Int,
  deposited: Int,
  withdrawn: Int,
}

fn opened(day_price: Int) -> ServiceInstanceDatum {
  ServiceInstanceDatum {
    day_price,
    deposit: 0,
    retracted: 0,
    start_time: 0,
    end_time: 0,
    user: "user",
    provider: "provider",
    service: "service",
  }
}

fn user_balance(d: ServiceInstanceDatum, now: Int) -> Int {
  balance_user(d.deposit, d.start_time, d.end_time, d.day_price, now)
}

fn provider_balance(d: ServiceInstanceDatum, now: Int) -> Int {
  balance_provider(
    d.deposit,
    d.retracted,
    d.start_time,
    d.end_time,
    d.day_price,
    now,
  )
}

fn redeemer_for(
  step: Step,
  d: ServiceInstanceDatum,
  now: Int,
) -> InstanceRedeemer {
  when step.kind is {
    0 -> MakeDeposit(step.seed * 1_000_000_000 + 1)
    1 -> WithdrawUser(user_balance(d, now) * step.seed / 1_000)
    2 -> WithdrawProvider(provider_balance(d, now) * step.seed / 1_000)
    3 -> WithdrawUser(user_balance(d, now) + 1 + step.seed)
    4 -> WithdrawProvider(provider_balance(d, now) + 1 + step.seed)
    _ -> Stop
  }
}

/// Invariants of a single state at time `now` (not before its last action).
fn state_ok(d: ServiceInstanceDatum, now: Int) -> Bool {
  if d.start_time == 0 {
    // nothing deposited yet (it may already be stopped: cancelled before funding)
    d.deposit == 0 && d.retracted == 0
  } else {
    let user = user_balance(d, now)
    let provider = provider_balance(d, now)
    let later = now + day_ms
    and {
      d.deposit - d.retracted >= 0,
      user >= 0,
      provider >= 0,
      // solvency: both claims together are exactly what the instance holds
      user + provider == d.deposit - d.retracted,
      // time only consumes the user's balance and grows the provider's
      user_balance(d, later) <= user,
      provider_balance(d, later) >= provider,
      // frozen once stopped
      d.end_time == 0 || user_balance(d, later) == user && provider_balance(
        d,
        later,
      ) == provider,
    }
  }
}

/// Invariants of one transition `before -> after` caused by `redeemer`.
fn transition_ok(
  before: ServiceInstanceDatum,
  redeemer: InstanceRedeemer,
  result: Option<ServiceInstanceDatum>,
  now: Int,
) -> Bool {
  when result is {
    None ->
      // a withdrawal within the available balance must never be refused
      when redeemer is {
        WithdrawUser(amount) ->
          before.start_time == 0 || amount <= 0 || amount > user_balance(
            before,
            now,
          )
        WithdrawProvider(amount) ->
          before.start_time == 0 || amount <= 0 || amount > provider_balance(
            before,
            now,
          )
        MakeDeposit(_) -> before.end_time != 0
        Stop -> before.end_time != 0
        _ -> True
      }
    Some(after) -> and {
        // set once, never moved
        before.start_time == 0 || after.start_time == before.start_time,
        before.end_time == 0 || after.end_time == before.end_time,
        after.day_price == before.day_price,
        after.user == before.user,
        after.provider == before.provider,
        after.service == before.service,
        when redeemer is {
          WithdrawUser(amount) ->
            amount > 0 && amount <= user_balance(before, now)
          WithdrawProvider(amount) ->
            amount > 0 && amount <= provider_balance(before, now)
          MakeDeposit(amount) -> amount > 0 && before.end_time == 0
          Stop -> before.end_time == 0 && after.end_time == now
          _ -> False
        },
      }
  }
}

fn step(walk: Option<Walk>, s: Step) -> Option<Walk> {
  when walk is {
    None -> None
    Some(w) -> {
      let now = w.now + s.dt
      let redeemer = redeemer_for(s, w.datum, now)
      let result = next_datum(w.datum, redeemer, now)
      if !transition_ok(w.datum, redeemer, result, now) {
        None
      } else {
        let after = when result is {
          Some(d) -> d
          None -> w.datum
        }
        let moved = w.datum.deposit - w.datum.retracted - (
          after.deposit - after.retracted
        )
        let next = when redeemer is {
          MakeDeposit(_) ->
            Walk {
              datum: after,
              now,
              deposited: w.deposited + after.deposit - w.datum.deposit,
              withdrawn: w.withdrawn,
            }
          _ ->
            Walk {
              datum: after,
              now,
              deposited: w.deposited,
              withdrawn: w.withdrawn + moved,
            }
        }
        if state_ok(after, now) {
          Some(next)
        } else {
          None
        }
      }
    }
  }
}

test random_instance_lifecycles_keep_invariants(sc via scenario()) {
  let start = Walk {
    datum: opened(sc.day_price),
    now: 1_000,
    deposited: 0,
    withdrawn: 0,
  }
  when list.foldl(sc.steps, Some(start), fn(s, acc) { step(acc, s) }) is {
    None -> False
    // conservation: what went in minus what came out is what is held
    Some(w) -> w.deposited - w.withdrawn == w.datum.deposit - w.datum.retracted
  }
}

// After stopping, both parties can always take everything that is left.
test stopped_instance_drains_completely(sc via scenario()) {
  let start = Walk {
    datum: opened(sc.day_price),
    now: 1_000,
    deposited: 0,
    withdrawn: 0,
  }
  expect Some(w) = list.foldl(
    sc.steps,
    Some(start),
    fn(s, acc) { step(acc, s) },
  )
  let d = w.datum
  if d.start_time == 0 {
    True
  } else {
    let stopped = if d.end_time == 0 {
      expect Some(s) = next_datum(d, Stop, w.now)
      s
    } else {
      d
    }
    let later = w.now + day_ms
    let user = user_balance(stopped, later)
    let after_user = if user > 0 {
      expect Some(s) = next_datum(stopped, WithdrawUser(user), later)
      s
    } else {
      stopped
    }
    let provider = provider_balance(after_user, later)
    let after_provider = if provider > 0 {
      expect Some(s) = next_datum(after_user, WithdrawProvider(provider), later)
      s
    } else {
      after_user
    }
    after_provider.deposit - after_provider.retracted == 0
  }
}

// ## Helpers

fn dust_args() -> Fuzzer<(Int, Int)> {
  fuzz.tuple(
    fuzz.int_between(0, 1_000_000_000),
    fuzz.int_between(1, 1_000_000_000_000),
  )
}

test is_dust_means_at_most_one_second_of_service(args via dust_args()) {
  let (remaining, day_price) = args
  is_dust(remaining, day_price) == ( remaining * 86_400 <= day_price )
}

fn clock_args() -> Fuzzer<(Int, Int, Int, Bool)> {
  fuzz.tuple4(
    fuzz.int_between(0, 4),
    fuzz.int_at_least(0),
    fuzz.int_between(0, max_validity_ms),
    fuzz.bool(),
  )
}

test clock_for_stays_within_validity_window(args via clock_args()) {
  let (kind, lower, width, user_signs) = args
  let d = opened(1_000)
  let redeemer = when kind is {
    0 -> MakeDeposit(1)
    1 -> WithdrawUser(1)
    2 -> WithdrawProvider(1)
    3 -> Stop
    _ -> types.Close
  }
  let signers = if user_signs {
    [d.user]
  } else {
    [d.provider]
  }
  let now = clock_for(d, redeemer, lower, lower + width, signers)
  lower <= now && now <= lower + width
}

fn window_args() -> Fuzzer<(Int, Int)> {
  fuzz.tuple(fuzz.int_at_least(0), fuzz.int_between(-10, 2 * max_validity_ms))
}

test validity_window_accepts_exactly_narrow_finite_ranges(
  args via window_args(),
) {
  let (lower, width) = args
  let accepted = validity_window(interval.between(lower, lower + width)) != None
  accepted == ( width >= 0 && width <= max_validity_ms )
}

fn ref_pair() -> Fuzzer<(ByteArray, Int, ByteArray, Int)> {
  fuzz.tuple4(
    fuzz.bytearray_fixed(32),
    fuzz.int_between(0, 65_535),
    fuzz.bytearray_fixed(32),
    fuzz.int_between(0, 65_535),
  )
}

test unique_asset_names_are_28_bytes_and_distinct(refs via ref_pair()) {
  let (tx_a, ix_a, tx_b, ix_b) = refs
  let a = unique_asset_name(OutputReference(tx_a, ix_a))
  let b = unique_asset_name(OutputReference(tx_b, ix_b))
  and {
    builtin.length_of_bytearray(a) == 28,
    tx_a == tx_b && ix_a == ix_b || a != b,
  }
}
