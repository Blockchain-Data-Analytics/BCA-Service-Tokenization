------------------------------ MODULE Service ------------------------------
(***************************************************************************)
(* One pay-as-you-go service subscription: the terms of BCA_Service plus   *)
(* the escrow of BCA_ServiceInstance (bca-token-solidity/contracts).       *)
(*                                                                         *)
(* With SetupFee = LockPeriod = MinDeposit = 0 and all switches FALSE the  *)
(* model is the Solidity contract as implemented today.  New features are  *)
(* constants, fixes are switches, so each can be checked alone.            *)
(* See README.md for the mapping, the configs and the findings.            *)
(***************************************************************************)
EXTENDS Integers

CONSTANTS
    Price, Period,  \* tariff: Price tokens per Period ticks (dayPrice per 86400 s)
    SetupFee,       \* NEW feature: one-off fee charged at start (0 = none)
    LockPeriod,     \* NEW feature: ticks after start in which the user may not cancel (0 = none)
    MinDeposit,     \* NEW: smallest accepted first deposit (0 = none)
    \* Fix switches. FALSE = behaviour of the Solidity contract today.
    NoArrears,      \* a top-up is not charged for time the contract was unfunded
    LockFunds,      \* user cannot withdraw (or auto-stop on) funds reserved for the lock period
    VestSetupFee,   \* provider earns the setup fee only when the lock period has passed
    SettleOnStop,   \* stop() pays out both parties in the same transaction
    \* Model bounds
    Amounts,        \* deposit amounts tried
    MaxTime,        \* last tick
    MaxTx,          \* transactions explored (see TxBound)
    CloseBudget     \* see MinCloseCost

ASSUME /\ Price \in Nat /\ Period \in Nat \ {0}
       /\ SetupFee \in Nat /\ LockPeriod \in Nat /\ MinDeposit \in Nat
       /\ {NoArrears, LockFunds, VestSetupFee, SettleOnStop} \subseteq BOOLEAN
       /\ Amounts \subseteq Nat

VARIABLES
    now,        \* block.timestamp; starts at 1, so 0 means "unset" as in Solidity
    deposit,    \* paid in, minus what the user took back
    retracted,  \* taken out by the provider
    startTime,  \* time of first deposit, 0 = not started
    endTime,    \* time of stop, 0 = not stopped
    forgiven,   \* NEW state (NoArrears): charge waived for unfunded time
    stopper,    \* NEW state (VestSetupFee): "none", "user" or "provider"
    refunded,   \* ghost: total taken back by the user
    txs         \* ghost: transactions sent per party; cost = txs * fee per tx

vars == <<now, deposit, retracted, startTime, endTime, forgiven, stopper, refunded, txs>>

\* msg.sender. "provider" also stands for any third party where the contract
\* does not check the sender (makeDeposit).
Callers == {"user", "provider"}

Max(a, b) == IF a > b THEN a ELSE b
Min(a, b) == IF a < b THEN a ELSE b

-----------------------------------------------------------------------------
(* Balances: computed from time, never stored (as in Solidity). *)

started == startTime # 0
stopped == endTime # 0
Elapsed == (IF stopped THEN endTime ELSE now) - startTime
InLock  == started /\ ~stopped /\ Elapsed < LockPeriod

Cost(t)   == (t * Price) \div Period    \* rounds down, in favour of the user
IsDust(r) == r <= Price \div Period     \* worth at most one tick of service

\* Charge to the user if `s` is the stopper and `t` ticks have been served.
\* A provider who stops inside the lock period gives the setup fee back.
PaidIf(s, t) ==
    LET fee == IF VestSetupFee /\ s = "provider" /\ t < LockPeriod THEN 0 ELSE SetupFee
    IN  Max(0, fee + Cost(t) - forgiven)

Paid     == PaidIf(stopper, Elapsed)
Earned   == Min(Paid, deposit)          \* never more than was deposited
UserBal  == Max(0, deposit - Paid)      \* balanceUser()
ProvBal  == Max(0, Earned - retracted)  \* balanceProvider()
Holdings == deposit - retracted         \* tokens held by the contract

\* What each party may withdraw right now.
UserAvail == IF LockFunds /\ InLock
             THEN Max(0, deposit - PaidIf(stopper, LockPeriod))
             ELSE UserBal
ProvAvail == IF VestSetupFee /\ InLock
             THEN Max(0, Min(PaidIf("provider", Elapsed), deposit) - retracted)
             ELSE ProvBal

-----------------------------------------------------------------------------
(* Actions = contract calls.  A reverting call changes nothing: not modelled. *)

Sent(c) == txs' = [txs EXCEPT ![c] = @ + 1]

Init ==
    /\ now = 1
    /\ deposit = 0 /\ retracted = 0 /\ startTime = 0 /\ endTime = 0
    /\ forgiven = 0 /\ stopper = "none" /\ refunded = 0
    /\ txs = [c \in Callers |-> 0]

\* Time only matters between start and stop.
Tick ==
    /\ started /\ ~stopped /\ now < MaxTime
    /\ now' = now + 1
    /\ UNCHANGED <<deposit, retracted, startTime, endTime, forgiven, stopper, refunded, txs>>

\* makeDeposit: anyone may deposit (BCA_Funding24 does); the first one starts the clock.
Deposit(c, amt) ==
    /\ ~stopped
    /\ ~started => amt >= MinDeposit
    /\ deposit' = deposit + amt
    /\ startTime' = IF started THEN startTime ELSE now
    /\ forgiven' = IF NoArrears /\ started /\ Paid > deposit
                   THEN forgiven + Paid - deposit   \* now Paid' = deposit: old funds used up, no debt
                   ELSE forgiven
    /\ Sent(c)
    /\ UNCHANGED <<now, retracted, endTime, stopper, refunded>>

\* stop: either party; the user not inside the lock period.
Stop(c) ==
    /\ ~stopped
    /\ c = "user" => ~InLock
    /\ endTime' = now
    /\ stopper' = c
    /\ IF SettleOnStop /\ started
       THEN LET paid   == PaidIf(c, now - startTime)
                toUser == Max(0, deposit - paid)
            IN  /\ deposit' = deposit - toUser
                /\ refunded' = refunded + toUser
                /\ retracted' = Min(paid, deposit)
       ELSE UNCHANGED <<deposit, refunded, retracted>>
    /\ Sent(c)
    /\ UNCHANGED <<now, startTime, forgiven>>

\* withdrawUser: stops the contract when (almost) nothing is left for the user.
WithdrawUser(amt) ==
    /\ started
    /\ amt \in 0..UserAvail
    /\ deposit' = deposit - amt
    /\ refunded' = refunded + amt
    /\ IF ~stopped /\ IsDust(UserBal - amt) /\ ~(LockFunds /\ InLock)
       THEN endTime' = now /\ stopper' = "user"
       ELSE UNCHANGED <<endTime, stopper>>
    /\ Sent("user")
    /\ UNCHANGED <<now, retracted, startTime, forgiven>>

\* withdrawProvider: stops the contract when it is (almost) drained.
WithdrawProvider(amt) ==
    /\ started
    /\ amt \in 0..ProvAvail
    /\ retracted' = retracted + amt
    /\ IF ~stopped /\ IsDust(Holdings - amt)
       THEN endTime' = now /\ stopper' = "provider"
       ELSE UNCHANGED <<endTime, stopper>>
    /\ Sent("provider")
    /\ UNCHANGED <<now, deposit, startTime, forgiven, refunded>>

Next ==
    \/ Tick
    \/ \E c \in Callers, amt \in Amounts : Deposit(c, amt)
    \/ \E c \in Callers : Stop(c)
    \/ \E amt \in 0..deposit : WithdrawUser(amt) \/ WithdrawProvider(amt)

Spec == Init /\ [][Next]_vars

TotalTx == txs["user"] + txs["provider"]
TxBound == TotalTx <= MaxTx     \* state constraint, keeps the model finite

-----------------------------------------------------------------------------
(* Properties *)

TypeOK ==
    /\ now \in 1..MaxTime
    /\ deposit \in Nat /\ retracted \in Nat /\ forgiven \in Nat /\ refunded \in Nat
    /\ startTime \in 0..MaxTime /\ endTime \in 0..MaxTime
    /\ stopper \in {"none", "user", "provider"}
    /\ txs \in [Callers -> Nat]

\* The contract holds exactly what the two parties are owed, and the
\* provider never took more than was earned.
Solvent ==
    /\ retracted <= Earned
    /\ UserBal + ProvBal = Holdings

\* The user is charged at most the setup fee plus the tariff for elapsed time.
NoOvercharge == started => Earned <= SetupFee + Cost(Elapsed)

\* Once stopped, both parties can take out all they are owed: no stuck funds.
Drainable ==
    started /\ stopped => ENABLED WithdrawUser(UserBal) /\ ENABLED WithdrawProvider(ProvBal)

\* A deposit is credited to the user in full: no charge for the past.
DepositCreditsUser ==
    [][started /\ deposit' > deposit => UserBal' = UserBal + deposit' - deposit]_vars

\* Unless the provider stops, setup fee and lock period are funded and the
\* user cannot get out before the lock period has passed.
ProviderSecured ==
    started /\ stopper # "provider" =>
        /\ deposit >= SetupFee + Cost(LockPeriod)
        /\ stopped => endTime - startTime >= LockPeriod

\* A provider who stops inside the lock period keeps no setup fee.
NoFeeAndRun ==
    started /\ stopper = "provider" /\ endTime - startTime < LockPeriod =>
        Earned <= Cost(Elapsed)

\* Transaction cost: a cancelled subscription, fully paid out to both
\* parties, takes more than CloseBudget transactions.
MinCloseCost ==
    ~(stopped /\ Holdings = 0 /\ refunded > 0 /\ retracted > 0 /\ TotalTx <= CloseBudget)

=============================================================================
