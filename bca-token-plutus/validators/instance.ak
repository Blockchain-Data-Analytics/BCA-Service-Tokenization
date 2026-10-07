//// The contract a client funds — Plutus counterpart of
//// BCA_ServiceInstance.sol, plus BCA_Service.newInstance() as its minting
//// policy. One script per BCA1-token class and seller_factory; instances are
//// told apart by their state token, not by address.
////
//// mint OpenInstance(user): consumes a service state UTxO from
//// seller_factory (which bumps its `instance_count`, capped at
//// `max_instances`), mints one instance token named
//// `unique_asset_name(<that UTxO>)` and locks it at this script's address
//// with a zero-deposit datum whose price/provider/service come from the
//// service. mint BurnInstance: burns one instance token; only reachable via
//// the Close spend, since the token never leaves this address otherwise.
////
//// spend: the input must hold its instance token (rejects datums locked here
//// by anyone else) and be the only input from this script. All redeemers
//// except Close need exactly one continuing output at the same address
//// holding exactly the instance token plus `deposit - retracted` BCA1, with
//// no less lovelace, and a validity window of at most `max_validity_ms`;
//// `now` is the bound picked by `clock_for` (see lib/bca/instance.ak).
//// The business logic itself lives in lib/bca/instance.ak.

use aiken/builtin
use aiken/collection/dict
use aiken/interval
use bca/instance.{can_close, clock_for, day_ms, is_authorized, next_datum}
use bca/tx.{
  continues_with, inputs_at, max_validity_ms, outputs_at, single_token,
  validity_window,
}
use bca/types.{
  BurnInstance, Close, InstanceMintRedeemer, InstanceRedeemer, MakeDeposit,
  OpenInstance, ServiceDatum, ServiceInstanceDatum, Stop, WithdrawProvider,
  WithdrawUser, unique_asset_name,
}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
}

validator service_instance(
  token_policy_id: PolicyId,
  token_asset_name: AssetName,
  seller_factory_policy_id: PolicyId,
) {
  mint(redeemer: InstanceMintRedeemer, policy_id: PolicyId, self: Transaction) {
    let minted = dict.to_pairs(assets.tokens(self.mint, policy_id))
    when redeemer is {
      OpenInstance { user } -> {
        expect [service_input] = inputs_at(
          self.inputs,
          seller_factory_policy_id,
        )
        expect InlineDatum(raw_service) = service_input.output.datum
        expect service: ServiceDatum = raw_service
        expect Some(service_name) = single_token(
          service_input.output.value,
          seller_factory_policy_id,
        )

        let instance_name = unique_asset_name(service_input.output_reference)
        expect [instance_output] = outputs_at(self.outputs, policy_id)
        expect InlineDatum(raw_instance) = instance_output.datum
        expect instance: ServiceInstanceDatum = raw_instance

        and {
          builtin.length_of_bytearray(user) == 28,
          minted == [Pair(instance_name, 1)],
          assets.without_lovelace(instance_output.value) == assets.from_asset(
            policy_id,
            instance_name,
            1,
          ),
          instance == ServiceInstanceDatum {
            day_price: service.day_price,
            deposit: 0,
            retracted: 0,
            start_time: 0,
            end_time: 0,
            user,
            provider: service.seller,
            service: service_name,
          },
        }
      }

      BurnInstance ->
        when minted is {
          [Pair(_, -1)] -> True
          _ -> False
        }
    }
  }

  spend(
    datum: Option<ServiceInstanceDatum>,
    redeemer: InstanceRedeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(current) = datum
    expect Some(own_input) = find_input(self.inputs, own_ref)
    expect Script(own_hash) = own_input.output.address.payment_credential
    expect Some(instance_name) = single_token(own_input.output.value, own_hash)
    expect [_] = inputs_at(self.inputs, own_hash)
    let own_outputs = outputs_at(self.outputs, own_hash)
    let signers = self.extra_signatories

    when redeemer is {
      Close -> and {
          can_close(current),
          is_authorized(current, redeemer, signers),
          own_outputs == [],
          dict.to_pairs(assets.tokens(self.mint, own_hash)) == [
            Pair(instance_name, -1),
          ],
        }

      _ -> {
        expect Some((lower, upper)) = validity_window(self.validity_range)
        let now = clock_for(current, redeemer, lower, upper, signers)
        expect Some(expected_next) = next_datum(current, redeemer, now)

        expect [continuing] = own_outputs
        expect InlineDatum(raw_next) = continuing.datum
        expect actual_next: ServiceInstanceDatum = raw_next

        let expected_tokens = assets.from_asset(own_hash, instance_name, 1)
          |> assets.add(
              token_policy_id,
              token_asset_name,
              expected_next.deposit - expected_next.retracted,
            )

        and {
          actual_next == expected_next,
          continues_with(own_input.output, continuing, expected_tokens),
          is_authorized(current, redeemer, signers),
        }
      }
    }
  }

  else(_) {
    fail
  }
}

// ## Tests

const bca1_policy = #"b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1"

const bca1_name = "BCA1"

const seller_factory_hash =
  #"5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f"

const own_hash = #"1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a"

const user_pkh = #"01010101010101010101010101010101010101010101010101010101"

const provider_pkh = #"02020202020202020202020202020202020202020202020202020202"

const instance_token =
  #"77777777777777777777777777777777777777777777777777777777"

const own_ref =
  OutputReference(
    #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    0,
  )

const price = 86_400_000

const t0 = 1_000

const min_ada = 2_000_000

fn instance_address() -> Address {
  Address { payment_credential: Script(own_hash), stake_credential: None }
}

fn instance_datum(
  deposit: Int,
  retracted: Int,
  end_time: Int,
) -> ServiceInstanceDatum {
  ServiceInstanceDatum {
    day_price: price,
    deposit,
    retracted,
    start_time: t0,
    end_time,
    user: user_pkh,
    provider: provider_pkh,
    service: "service",
  }
}

fn instance_value(lovelace: Int, bca1: Int) -> Value {
  assets.from_lovelace(lovelace)
    |> assets.add(own_hash, instance_token, 1)
    |> assets.add(bca1_policy, bca1_name, bca1)
}

fn instance_output(datum: ServiceInstanceDatum, lovelace: Int) -> Output {
  Output {
    address: instance_address(),
    value: instance_value(lovelace, datum.deposit - datum.retracted),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn spend_tx(
  input: Output,
  outputs: List<Output>,
  lower: Int,
  upper: Int,
  signers: List<ByteArray>,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: [Input(own_ref, input)],
    outputs,
    validity_range: interval.between(lower, upper),
    extra_signatories: signers,
  }
}

fn spend(
  datum: ServiceInstanceDatum,
  redeemer: InstanceRedeemer,
  tx: Transaction,
) -> Bool {
  service_instance.spend(
    bca1_policy,
    bca1_name,
    seller_factory_hash,
    Some(datum),
    redeemer,
    own_ref,
    tx,
  )
}

// One day after t0 the provider has earned exactly `price`.
const one_day = t0 + day_ms

fn provider_withdrawal(
  amount: Int,
  lower: Int,
  upper: Int,
  next_output: fn(ServiceInstanceDatum) -> Output,
) -> Bool {
  let current = instance_datum(1_000_000_000, 0, 0)
  let next = instance_datum(1_000_000_000, amount, 0)
  spend(
    current,
    WithdrawProvider(amount),
    spend_tx(
      instance_output(current, min_ada),
      [next_output(next)],
      lower,
      upper,
      [provider_pkh],
    ),
  )
}

fn same_ada(datum: ServiceInstanceDatum) -> Output {
  instance_output(datum, min_ada)
}

test withdraw_provider_succeeds() {
  provider_withdrawal(price, one_day, one_day + 60_000, same_ada)
}

test withdraw_provider_cannot_claim_upper_bound_time() fail {
  // earned at upper = price + 60s worth; only lower bound counts
  provider_withdrawal(price + 60_000, one_day, one_day + 60_000, same_ada)
}

test withdraw_provider_rejects_wide_validity_range() fail {
  provider_withdrawal(price, one_day, one_day + max_validity_ms + 1, same_ada)
}

test withdraw_provider_rejects_lovelace_siphon() fail {
  provider_withdrawal(
    price,
    one_day,
    one_day + 60_000,
    fn(datum) { instance_output(datum, min_ada - 1) },
  )
}

test withdraw_provider_rejects_foreign_token_in_output() fail {
  provider_withdrawal(
    price,
    one_day,
    one_day + 60_000,
    fn(datum) {
      let output = instance_output(datum, min_ada)
      Output { ..output, value: assets.add(output.value, #"cc", "junk", 1) }
    },
  )
}

test withdraw_provider_rejects_moved_stake_credential() fail {
  provider_withdrawal(
    price,
    one_day,
    one_day + 60_000,
    fn(datum) {
      Output {
        ..instance_output(datum, min_ada),
        address: Address {
          payment_credential: Script(own_hash),
          stake_credential: Some(address.Inline(VerificationKey(provider_pkh))),
        },
      }
    },
  )
}

fn user_withdrawal(amount: Int) -> Bool {
  let current = instance_datum(1_000_000_000, 0, 0)
  let next = instance_datum(1_000_000_000 - amount, 0, 0)
  spend(
    current,
    WithdrawUser(amount),
    spend_tx(
      instance_output(current, min_ada),
      [instance_output(next, min_ada)],
      one_day,
      one_day + 60_000,
      [user_pkh],
    ),
  )
}

// price == day_ms, so the user has paid exactly (now - t0) by `now`.
test withdraw_user_reads_upper_bound() {
  user_withdrawal(1_000_000_000 - ( one_day + 60_000 - t0 ) - 10_000)
}

test withdraw_user_cannot_claim_lower_bound_time() fail {
  user_withdrawal(1_000_000_000 - ( one_day - t0 ) - 10_000)
}

test spend_rejects_input_without_instance_token() fail {
  // a datum someone locked at the script address without the state token
  let current = instance_datum(1_000_000_000, 0, 0)
  let forged = Output {
    ..instance_output(current, min_ada),
    value: assets.from_lovelace(min_ada)
      |> assets.add(bca1_policy, bca1_name, 1_000_000_000),
  }
  let next = instance_datum(1_000_000_000, price, 0)
  spend(
    current,
    WithdrawProvider(price),
    spend_tx(
      forged,
      [instance_output(next, min_ada)],
      one_day,
      one_day + 60_000,
      [provider_pkh],
    ),
  )
}

test spend_rejects_second_own_input() fail {
  let current = instance_datum(1_000_000_000, 0, 0)
  let next = instance_datum(1_000_000_000, price, 0)
  let tx = spend_tx(
    instance_output(current, min_ada),
    [instance_output(next, min_ada)],
    one_day,
    one_day + 60_000,
    [provider_pkh],
  )
  let other_ref = OutputReference(own_ref.transaction_id, 1)
  spend(
    current,
    WithdrawProvider(price),
    Transaction {
      ..tx,
      inputs: [
        Input(own_ref, instance_output(current, min_ada)),
        Input(other_ref, instance_output(current, min_ada)),
      ],
    },
  )
}

test make_deposit_starts_clock_at_lower_bound() {
  let current = ServiceInstanceDatum {
    ..instance_datum(0, 0, 0),
    start_time: 0,
  }
  let next = ServiceInstanceDatum {
    ..current,
    deposit: 1_000_000_000,
    start_time: one_day,
  }
  spend(
    current,
    MakeDeposit(1_000_000_000),
    spend_tx(
      instance_output(current, min_ada),
      [instance_output(next, min_ada)],
      one_day,
      one_day + 60_000,
      [],
    ),
  )
}

fn stop_by(signer: ByteArray, end_time: Int) -> Bool {
  let current = instance_datum(1_000_000_000, 0, 0)
  spend(
    current,
    Stop,
    spend_tx(
      instance_output(current, min_ada),
      [instance_output(ServiceInstanceDatum { ..current, end_time }, min_ada)],
      one_day,
      one_day + 60_000,
      [signer],
    ),
  )
}

test stop_by_user_reads_upper_bound() {
  stop_by(user_pkh, one_day + 60_000)
}

test stop_by_provider_reads_lower_bound() {
  stop_by(provider_pkh, one_day)
}

test stop_by_provider_cannot_use_upper_bound() fail {
  stop_by(provider_pkh, one_day + 60_000)
}

fn close_tx(
  current: ServiceInstanceDatum,
  signers: List<ByteArray>,
  burned: Value,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: [Input(own_ref, instance_output(current, min_ada))],
    mint: burned,
    extra_signatories: signers,
  }
}

test close_drained_instance_burns_token() {
  let current = instance_datum(10, 10, 5_000)
  spend(
    current,
    Close,
    close_tx(
      current,
      [user_pkh],
      assets.from_asset(own_hash, instance_token, -1),
    ),
  )
}

test close_rejects_without_burn() fail {
  let current = instance_datum(10, 10, 5_000)
  spend(current, Close, close_tx(current, [user_pkh], assets.zero))
}

test close_rejects_running_instance() fail {
  let current = instance_datum(10, 10, 0)
  spend(
    current,
    Close,
    close_tx(
      current,
      [user_pkh],
      assets.from_asset(own_hash, instance_token, -1),
    ),
  )
}

test burn_instance_mint_succeeds() {
  service_instance.mint(
    bca1_policy,
    bca1_name,
    seller_factory_hash,
    BurnInstance,
    own_hash,
    Transaction {
      ..transaction.placeholder,
      mint: assets.from_asset(own_hash, instance_token, -1),
    },
  )
}

test burn_instance_rejects_minting() fail {
  service_instance.mint(
    bca1_policy,
    bca1_name,
    seller_factory_hash,
    BurnInstance,
    own_hash,
    Transaction {
      ..transaction.placeholder,
      mint: assets.from_asset(own_hash, instance_token, 1),
    },
  )
}

// ### OpenInstance

const service_ref =
  OutputReference(
    #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    3,
  )

const service_token =
  #"5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e"

fn service_input() -> Input {
  Input(
    service_ref,
    Output {
      address: Address {
        payment_credential: Script(seller_factory_hash),
        stake_credential: None,
      },
      value: assets.from_lovelace(min_ada)
        |> assets.add(seller_factory_hash, service_token, 1),
      datum: InlineDatum(
        ServiceDatum {
          seller: provider_pkh,
          service_index: 0,
          max_instances: 3,
          day_price: price,
          instance_count: 0,
        },
      ),
      reference_script: None,
    },
  )
}

fn opened_datum() -> ServiceInstanceDatum {
  ServiceInstanceDatum {
    day_price: price,
    deposit: 0,
    retracted: 0,
    start_time: 0,
    end_time: 0,
    user: user_pkh,
    provider: provider_pkh,
    service: service_token,
  }
}

fn open_tx(inputs: List<Input>, datum: ServiceInstanceDatum) -> Transaction {
  let name = unique_asset_name(service_ref)
  Transaction {
    ..transaction.placeholder,
    inputs,
    mint: assets.from_asset(own_hash, name, 1),
    outputs: [
      Output {
        address: instance_address(),
        value: assets.from_lovelace(min_ada)
          |> assets.add(own_hash, name, 1),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    ],
  }
}

fn open(tx: Transaction) -> Bool {
  service_instance.mint(
    bca1_policy,
    bca1_name,
    seller_factory_hash,
    OpenInstance { user: user_pkh },
    own_hash,
    tx,
  )
}

test open_instance_succeeds() {
  open(open_tx([service_input()], opened_datum()))
}

test open_instance_rejects_without_service_state() fail {
  open(open_tx([], opened_datum()))
}

test open_instance_rejects_price_not_from_service() fail {
  open(
    open_tx(
      [service_input()],
      ServiceInstanceDatum { ..opened_datum(), day_price: 1 },
    ),
  )
}

test open_instance_rejects_provider_not_seller() fail {
  open(
    open_tx(
      [service_input()],
      ServiceInstanceDatum { ..opened_datum(), provider: user_pkh },
    ),
  )
}

test open_instance_rejects_prefunded_datum() fail {
  open(
    open_tx(
      [service_input()],
      ServiceInstanceDatum { ..opened_datum(), deposit: 5 },
    ),
  )
}
