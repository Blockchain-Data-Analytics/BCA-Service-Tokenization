//// Pure, testable port of BCA_ServiceInstance.sol's business logic
//// (balanceUser/balanceProvider/makeDeposit/withdrawUser/withdrawProvider/
//// stop). Kept separate from validators/instance.ak so every branch can be
//// unit-tested with plain values — no mock Transaction/UTxO needed.
////
//// Time is POSIX milliseconds throughout (Cardano's on-chain convention,
//// see cardano/transaction.ValidityRange), vs. EVM's block.timestamp in
//// seconds — same arithmetic, different unit, per plan-reorg.md §6.1.

use aiken/collection/list
use bca/types.{
  Close, InstanceRedeemer, MakeDeposit, ServiceInstanceDatum, Stop,
  WithdrawProvider, WithdrawUser,
}

pub const day_ms: Int = 86_400_000

/// Picks `now` from the transaction's validity window `[lower, upper]`. The
/// real time lies somewhere in it and the transaction builder chooses it,
/// so each action reads the bound that is least favorable to the party it
/// benefits:
/// - MakeDeposit starts the clock at `lower` (earlier start, depositor pays more)
/// - WithdrawUser reads `upper` (more time elapsed, user balance smaller)
/// - WithdrawProvider reads `lower` (less time elapsed, provider earned less)
/// - Stop reads `upper` when the user signs, `lower` otherwise (provider stop)
pub fn clock_for(
  current: ServiceInstanceDatum,
  redeemer: InstanceRedeemer,
  lower: Int,
  upper: Int,
  signers: List<ByteArray>,
) -> Int {
  when redeemer is {
    MakeDeposit(_) -> lower
    WithdrawUser(_) -> upper
    WithdrawProvider(_) -> lower
    Stop ->
      if list.has(signers, current.user) {
        upper
      } else {
        lower
      }
    Close -> upper
  }
}

/// Ports balanceUser(): remaining user principal not yet consumed by
/// elapsed-time * day_price. Frozen at `end_time` once stopped.
pub fn balance_user(
  deposit: Int,
  start_time: Int,
  end_time: Int,
  day_price: Int,
  now: Int,
) -> Int {
  let calc_time = if end_time != 0 {
    end_time
  } else {
    now
  }
  let duration = calc_time - start_time
  let paid = duration * day_price / day_ms
  if paid >= deposit {
    0
  } else {
    deposit - paid
  }
}

/// Ports balanceProvider(): elapsed-time earnings, capped at the deposit,
/// minus what the provider already withdrew. Frozen at `end_time` once
/// stopped. `balance_user + balance_provider == deposit - retracted`, i.e.
/// exactly what the instance holds.
pub fn balance_provider(
  deposit: Int,
  retracted: Int,
  start_time: Int,
  end_time: Int,
  day_price: Int,
  now: Int,
) -> Int {
  let calc_time = if end_time != 0 {
    end_time
  } else {
    now
  }
  let earned = ( calc_time - start_time ) * day_price / day_ms
  let capped = if earned > deposit {
    deposit
  } else {
    earned
  }
  if capped > retracted {
    capped - retracted
  } else {
    0
  }
}

/// Funds worth at most one second (one slot) of service, the same threshold
/// as BCA_ServiceInstance.sol's `dayPrice / 24 / 3600` with time in seconds.
pub fn is_dust(remaining: Int, day_price: Int) -> Bool {
  remaining <= day_price / 86_400
}

/// A withdrawal leaving only dust behind stops a running instance; on an
/// already stopped one it keeps `end_time` unchanged.
fn end_time_after_withdrawal(
  current: ServiceInstanceDatum,
  remaining: Int,
  now: Int,
) -> Int {
  if current.end_time == 0 && is_dust(remaining, current.day_price) {
    now
  } else {
    current.end_time
  }
}

/// Computes the datum a spending transaction must produce at its continuing
/// output, or `None` if the transition is invalid (mirrors a Solidity
/// `revert`).
pub fn next_datum(
  current: ServiceInstanceDatum,
  redeemer: InstanceRedeemer,
  now: Int,
) -> Option<ServiceInstanceDatum> {
  when redeemer is {
    MakeDeposit(amount) ->
      if amount <= 0 || current.end_time != 0 {
        None
      } else {
        let new_start_time = if current.start_time == 0 {
          now
        } else {
          current.start_time
        }
        Some(
          ServiceInstanceDatum {
            ..current,
            deposit: current.deposit + amount,
            start_time: new_start_time,
          },
        )
      }

    WithdrawUser(amount) ->
      if current.start_time == 0 {
        None
      } else {
        let avail = balance_user(
          current.deposit,
          current.start_time,
          current.end_time,
          current.day_price,
          now,
        )
        if amount <= 0 || amount > avail {
          None
        } else {
          Some(
            ServiceInstanceDatum {
              ..current,
              deposit: current.deposit - amount,
              end_time: end_time_after_withdrawal(current, avail - amount, now),
            },
          )
        }
      }

    WithdrawProvider(amount) ->
      if current.start_time == 0 {
        None
      } else {
        let avail = balance_provider(
          current.deposit,
          current.retracted,
          current.start_time,
          current.end_time,
          current.day_price,
          now,
        )
        if amount <= 0 || amount > avail {
          None
        } else {
          Some(
            ServiceInstanceDatum {
              ..current,
              retracted: current.retracted + amount,
              end_time: end_time_after_withdrawal(
                current,
                current.deposit - current.retracted - amount,
                now,
              ),
            },
          )
        }
      }

    Stop ->
      if current.end_time != 0 {
        None
      } else {
        Some(ServiceInstanceDatum { ..current, end_time: now })
      }

    // Close has no continuing datum; see can_close().
    Close -> None
  }
}

/// Close retires an instance (no continuing output, state token burned).
/// Only once stopped.
pub fn can_close(current: ServiceInstanceDatum) -> Bool {
  current.end_time != 0
}

/// Ports each entry point's `msg.sender` check. `MakeDeposit` is
/// unrestricted, same as makeDeposit() today (its AlreadySubscribed check is
/// commented out in BCA_ServiceInstance.sol). `Close` needs either party once
/// no BCA1 is left, otherwise both (they settle the remainder between them).
pub fn is_authorized(
  current: ServiceInstanceDatum,
  redeemer: InstanceRedeemer,
  signers: List<ByteArray>,
) -> Bool {
  let user_signed = list.has(signers, current.user)
  let provider_signed = list.has(signers, current.provider)
  when redeemer is {
    MakeDeposit(_) -> True
    WithdrawUser(_) -> user_signed
    WithdrawProvider(_) -> provider_signed
    Stop -> user_signed || provider_signed
    Close ->
      if current.deposit - current.retracted == 0 {
        user_signed || provider_signed
      } else {
        user_signed && provider_signed
      }
  }
}

// ## Tests
//
// `start_time == 0` is the contract's own "not yet started" sentinel (see
// next_datum's WithdrawUser/WithdrawProvider guards), so every fixture below
// that represents an already-running instance uses START, not a literal 0 —
// using 0 there would silently test the NotStarted guard instead of the
// branch the test name claims to cover.
//
// `day_price` is set equal to `day_ms` (1 unit/ms), so one day costs
// exactly `day_ms` units and the dust threshold (one second's worth) is 1000.

const day_price = 86_400_000

const start = 1

fn fresh(deposit: Int, start_time: Int, end_time: Int) -> ServiceInstanceDatum {
  ServiceInstanceDatum {
    day_price,
    deposit,
    retracted: 0,
    start_time,
    end_time,
    user: "user",
    provider: "provider",
    service: "service",
  }
}

test balance_user_before_stop_reduces_by_elapsed_time() {
  // 1 day elapsed at day_price == day_ms -> exactly one day_price consumed
  balance_user(1_000_000_000, 0, 0, day_price, day_ms) == 1_000_000_000 - day_price
}

test balance_user_freezes_at_end_time() {
  // `now` is way past end_time and must be ignored once stopped
  let now = 10 * day_ms
  balance_user(1_000_000_000, 0, 2 * day_ms, day_price, now) == 1_000_000_000 - 2 * day_price
}

test balance_user_never_negative() {
  balance_user(100, 0, 0, day_price, 10 * day_ms) == 0
}

test balance_provider_caps_at_available() {
  // way more than deposit has elapsed -> capped, not over-earned
  balance_provider(1_000_000, 0, 0, 0, day_price, 100 * day_ms) == 1_000_000
}

test balance_provider_respects_retracted() {
  // available (deposit - retracted) is the binding cap, not deposit itself
  balance_provider(1_000_000_000, 900_000_000, 0, 0, day_price, 100 * day_ms) == 100_000_000
}

test make_deposit_starts_the_clock_on_first_deposit() {
  let d = fresh(0, 0, 0)
  next_datum(d, MakeDeposit(500_000), 1000) == Some(
    ServiceInstanceDatum { ..d, deposit: 500_000, start_time: 1000 },
  )
}

test make_deposit_does_not_reset_start_time() {
  let d = fresh(500_000, start, 0)
  next_datum(d, MakeDeposit(500_000), 999_999) == Some(
    ServiceInstanceDatum { ..d, deposit: 1_000_000, start_time: start },
  )
}

test make_deposit_rejects_amount_after_stop() {
  let d = fresh(500_000, start, 2000)
  next_datum(d, MakeDeposit(1), 3000) == None
}

test withdraw_user_rejects_before_start() {
  let d = fresh(0, 0, 0)
  next_datum(d, WithdrawUser(1), 1000) == None
}

test withdraw_user_rejects_over_balance() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_user(1_000_000_000, start, 0, day_price, now)
  next_datum(d, WithdrawUser(avail + 1), now) == None
}

test withdraw_user_partial_does_not_stop() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  // withdraw a token amount far above the 1-unit dust threshold
  next_datum(d, WithdrawUser(100), now) == Some(
    ServiceInstanceDatum { ..d, deposit: 1_000_000_000 - 100 },
  )
}

test withdraw_user_full_drain_triggers_stop() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_user(1_000_000_000, start, 0, day_price, now)
  next_datum(d, WithdrawUser(avail), now) == Some(
    ServiceInstanceDatum { ..d, deposit: 1_000_000_000 - avail, end_time: now },
  )
}

test withdraw_user_full_drain_after_stop_keeps_end_time() {
  let end_time = start + 2 * day_ms
  let stopped = fresh(1_000_000_000, start, end_time)
  let avail = balance_user(1_000_000_000, start, end_time, day_price, 0)
  next_datum(stopped, WithdrawUser(avail), start + 10 * day_ms) == Some(
    ServiceInstanceDatum { ..stopped, deposit: 1_000_000_000 - avail },
  )
}

test withdraw_provider_full_drain_after_stop_keeps_end_time() {
  // user already took their part: only the provider's 2 days are left, and
  // withdrawing them empties the stopped instance
  let end_time = start + 2 * day_ms
  let stopped = fresh(2 * day_price, start, end_time)
  next_datum(stopped, WithdrawProvider(2 * day_price), start + 10 * day_ms) == Some(
    ServiceInstanceDatum { ..stopped, retracted: 2 * day_price },
  )
}

test withdraw_user_leaving_dust_stops() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_user(1_000_000_000, start, 0, day_price, now)
  // 1000 left = one second's worth
  next_datum(d, WithdrawUser(avail - 1000), now) == Some(
    ServiceInstanceDatum {
      ..d,
      deposit: 1_000_000_000 - avail + 1000,
      end_time: now,
    },
  )
}

test withdraw_user_leaving_more_than_dust_keeps_running() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_user(1_000_000_000, start, 0, day_price, now)
  next_datum(d, WithdrawUser(avail - 1001), now) == Some(
    ServiceInstanceDatum { ..d, deposit: 1_000_000_000 - avail + 1001 },
  )
}

test is_dust_is_one_second_of_service() {
  and {
    is_dust(1000, day_price),
    !is_dust(1001, day_price),
    // below 86_400 units/day one second is worth 0: only an empty balance is dust
    is_dust(0, 10_000),
    !is_dust(1, 10_000),
  }
}

test balance_provider_subtracts_what_was_withdrawn() {
  // one day earned = day_price; after withdrawing it nothing is left to claim
  let now = start + day_ms
  and {
    balance_provider(1_000_000_000, 0, start, 0, day_price, now) == day_price,
    balance_provider(1_000_000_000, day_price, start, 0, day_price, now) == 0,
  }
}

test withdraw_provider_cannot_claim_same_earnings_twice() {
  let now = start + day_ms
  let after_first = fresh(1_000_000_000, start, 0)
  let withdrawn = ServiceInstanceDatum { ..after_first, retracted: day_price }
  next_datum(withdrawn, WithdrawProvider(day_price), now) == None
}

test balances_add_up_to_what_is_held() {
  // user withdrew some, provider withdrew some; both claims together equal
  // exactly the tokens still in the instance
  let deposit = 1_000_000_000 - 200_000_000
  let retracted = 50_000_000
  let now = start + 3 * day_ms
  balance_user(deposit, start, 0, day_price, now) + balance_provider(
    deposit,
    retracted,
    start,
    0,
    day_price,
    now,
  ) == deposit - retracted
}

test withdraw_provider_rejects_over_balance() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_provider(1_000_000_000, 0, start, 0, day_price, now)
  next_datum(d, WithdrawProvider(avail + 1), now) == None
}

test withdraw_provider_earns_over_time_without_stopping() {
  let d = fresh(1_000_000_000, start, 0)
  let now = start + day_ms
  let avail = balance_provider(1_000_000_000, 0, start, 0, day_price, now)
  // avail (one day's earnings) leaves far more than the dust threshold
  // behind out of a 1_000_000_000 deposit, so this must not auto-stop
  next_datum(d, WithdrawProvider(avail), now) == Some(
    ServiceInstanceDatum { ..d, retracted: avail },
  )
}

test withdraw_provider_full_drain_triggers_stop() {
  let d = fresh(1_000_000, start, 0)
  let now = start + 100 * day_ms
  // elapsed earnings far exceed the deposit, so avail is capped at the
  // full remaining deposit - draining it should auto-stop
  let avail = balance_provider(1_000_000, 0, start, 0, day_price, now)
  next_datum(d, WithdrawProvider(avail), now) == Some(
    ServiceInstanceDatum { ..d, retracted: avail, end_time: now },
  )
}

test stop_sets_end_time_once() {
  let d = fresh(1_000_000, start, 0)
  next_datum(d, Stop, 5000) == Some(
    ServiceInstanceDatum { ..d, end_time: 5000 },
  )
}

test stop_rejects_if_already_stopped() {
  let d = fresh(1_000_000, start, 2000)
  next_datum(d, Stop, 5000) == None
}

test is_authorized_makedeposit_is_open() {
  is_authorized(fresh(0, 0, 0), MakeDeposit(1), [])
}

test is_authorized_withdraw_user_requires_user_signature() {
  let d = fresh(0, start, 0)
  !is_authorized(d, WithdrawUser(1), ["provider"]) && is_authorized(
    d,
    WithdrawUser(1),
    ["user"],
  )
}

test is_authorized_stop_accepts_either_party() {
  let d = fresh(0, start, 0)
  is_authorized(d, Stop, ["user"]) && is_authorized(d, Stop, ["provider"])
}

test is_authorized_withdraw_provider_requires_provider_signature() {
  let d = fresh(0, start, 0)
  !is_authorized(d, WithdrawProvider(1), ["user"]) && is_authorized(
    d,
    WithdrawProvider(1),
    ["provider"],
  )
}

test is_authorized_close_drained_accepts_either_party() {
  let d = fresh(0, start, 2000)
  is_authorized(d, Close, ["user"]) && is_authorized(d, Close, ["provider"])
}

test is_authorized_close_with_remaining_balance_needs_both() {
  let d = fresh(10, start, 2000)
  and {
    !is_authorized(d, Close, ["user"]),
    !is_authorized(d, Close, ["provider"]),
    is_authorized(d, Close, ["user", "provider"]),
  }
}

test can_close_only_when_stopped() {
  !can_close(fresh(0, start, 0)) && can_close(fresh(0, start, 2000))
}

test next_datum_close_has_no_continuing_datum() {
  next_datum(fresh(0, start, 2000), Close, 5000) == None
}

test clock_for_picks_bound_against_the_beneficiary() {
  let d = fresh(1_000, start, 0)
  and {
    clock_for(d, MakeDeposit(1), 10, 20, []) == 10,
    clock_for(d, WithdrawUser(1), 10, 20, ["user"]) == 20,
    clock_for(d, WithdrawProvider(1), 10, 20, ["provider"]) == 10,
    clock_for(d, Stop, 10, 20, ["user"]) == 20,
    clock_for(d, Stop, 10, 20, ["provider"]) == 10,
    clock_for(d, Stop, 10, 20, ["user", "provider"]) == 20,
  }
}
