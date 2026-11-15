# TLA+ model of the service contract

[Service.tla](Service.tla) models one subscription: the terms set in `BCA_Service`
and the escrow logic of `BCA_ServiceInstance`. It is the test bed for contract
changes: add the feature here, let TLC search for a way to cheat, then implement.

## Run

```bash
./check.sh
```

Runs every config (about one minute) and compares the result with the expected one.
`./check.sh Arrears` runs a single config and prints the full TLC output with the
error trace. Needs Java; TLC is `ext/tla2tools.jar`.

## Model vs. Solidity

| Model | Solidity (`BCA_ServiceInstance`) |
|---|---|
| `deposit`, `retracted`, `startTime`, `endTime` | same state variables |
| `now` | `block.timestamp` (starts at 1, so 0 means "unset" as in Solidity) |
| `Price`, `Period` | `dayPrice`, 86400 s; `Cost(t)` rounds down like `t * dayPrice / 24 / 3600` |
| `Deposit`, `Stop`, `WithdrawUser`, `WithdrawProvider` | `makeDeposit`, `stop`, `withdrawUser`, `withdrawProvider`, including the auto-stop on dust |
| `UserBal`, `ProvBal` | `balanceUser()`, `balanceProvider()` |
| `forgiven`, `stopper` | new state needed by the fixes below |
| `refunded`, `txs` | ghost variables, only for properties |

With `SetupFee = LockPeriod = MinDeposit = 0` and all switches `FALSE` the model is the
contract as implemented today ([AsImplemented.cfg](AsImplemented.cfg)).

New features (constants):

- `SetupFee`: charged once at start, on top of the tariff.
- `LockPeriod`: ticks after start in which the user may not cancel.
- `MinDeposit`: smallest accepted first deposit.

Fix switches (`FALSE` = today's behaviour):

- `NoArrears`: a top-up is not charged for time in which the contract had no funds.
- `LockFunds`: during the lock period the user cannot withdraw the funds reserved for
  it, and `withdrawUser` does not auto-stop.
- `VestSetupFee`: the provider can withdraw the setup fee only after the lock period;
  a provider who stops earlier gives it back.
- `SettleOnStop`: `stop()` pays out both parties in the same transaction.

## Properties

| Property | Meaning |
|---|---|
| `Solvent` | contract holds exactly what both parties are owed; provider never took more than earned |
| `NoOvercharge` | user pays at most setup fee + tariff for elapsed time |
| `Drainable` | after stop both parties can withdraw everything owed |
| `DepositCreditsUser` | a deposit raises the user's balance by the full amount |
| `ProviderSecured` | unless the provider stops: setup fee + lock period are funded, user cannot leave before the lock ends |
| `NoFeeAndRun` | a provider who stops inside the lock period keeps no setup fee |
| `MinCloseCost` | cancel + full payout takes more than `CloseBudget` transactions |

## Findings

| Config | Result | What it shows |
|---|---|---|
| `AsImplemented` | pass | today's contract is solvent, never overcharges per its own rule, no stuck funds |
| `Arrears` | `DepositCreditsUser` violated | **open today.** Anyone calls `makeDeposit(0)`, the clock starts; the user's later deposit is charged for the time since. Same when the deposit runs out, nobody stops, and the user (or `BCA_Funding24`) tops up: the gap is charged. Fix: `NoArrears` |
| `UnderDeposit` | `ProviderSecured` violated | user starts with less than fee + lock cost. Fix: `MinDeposit >= SetupFee + Cost(LockPeriod)` |
| `LockBypass` | `ProviderSecured` violated | blocking only `stop()` is not enough: the user withdraws the reserved funds. Fix: `LockFunds` |
| `FeeAndRun` | `NoFeeAndRun` violated | provider stops right after the first deposit and keeps the setup fee. Fix: `VestSetupFee` |
| `Fixed` | pass | both features with all fixes |
| `Settle` | pass | `Fixed` + `SettleOnStop` |

Each cheat config is `Fixed` with one fix removed (`Arrears` is `AsImplemented` plus
the property).

The auto-stop part of `LockFunds` is needed when one tick costs a whole token
(`Price >= Period`): one tick before the lock ends the remaining reserve counts as
dust and `withdrawUser` stops the contract early. The shipped configs do not reach
this; `Fixed.cfg` with `Price = 1`, `Period = 1`, `MinDeposit = 4` does.

Not preventable on-chain, to be handled by the parties' agents:

- Provider takes the money and does not deliver. The user loses at most
  `SetupFee + Cost(LockPeriod)`, then can stop. With `LockPeriod = 0` a setup fee is
  not protected at all.
- User runs out of funds and nobody stops. The provider must watch the balance and
  stop, or serve for free.

## Transaction cost

`txs` counts transactions per party; cost is count times fee per transaction of the
chain. Cancel with full payout to both parties:

- as implemented: 3 transactions (deposit, `withdrawUser` of everything with auto-stop,
  `withdrawProvider`). `AsImplemented.cfg` proves there is no way in 2;
  `CloseBudget = 3` gives the trace.
- `SettleOnStop`: 2 transactions (deposit, stop), the provider sends none.
  `Settle.cfg` proves there is no way in 1; `CloseBudget = 2` gives the trace.

Not modelled: the ERC20 `approve`, gas of reverted calls, per-call gas differences.

## Trying a new feature

1. Add a constant (value 0 or `FALSE` must mean "as today") and change the actions.
2. State the guarantee as a property; add it to the configs.
3. Add a config that is expected to fail without the protection, and a line in `check.sh`.
4. Vary `Price`/`Period` (rounding, dust) and `Amounts` before trusting a pass.

## Limits

- Bounded: 5 transactions, 6 ticks, deposits of 0, 1, 5 or 8 tokens. A pass is a proof
  only within these bounds.
- One instance. The factory chain (`maxInstances`, controller, manager) is not modelled.
- Token transfers always succeed. `BCA_Funding24` is just another depositor.
- No liveness properties; `Drainable` covers "funds can always be taken out".
