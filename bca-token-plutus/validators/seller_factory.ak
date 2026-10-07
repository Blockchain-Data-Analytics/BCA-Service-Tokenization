//// Seller factory: onboarded sellers define services. Mirrors
//// BCA_ServiceController (newService) plus BCA_Service's instance counter.
//// One script for all sellers; the seller comes from the root_factory state
//// UTxO being consumed, not from a parameter.
////
//// mint (DefineService): consumes the seller's root_factory state UTxO
//// (proof of onboarding, and root_factory bumps its `service_count`), mints
//// one service token named `unique_asset_name(<that UTxO>)` and locks it at
//// this script's address with a ServiceDatum whose `service_index` is the
//// seller's `service_count` before the bump.
////
//// spend (service state UTxO): bumps `instance_count` by one, never past
//// `max_instances`, keeping token, address and lovelace. The instance
//// validator's OpenInstance consumes it this way. Like the permissionless
//// BCA_Service.newInstance(), anyone may do so; a bump without opening an
//// instance only burns the caller's fees.

use aiken/collection/dict
use aiken/collection/list
use bca/tx.{continues_with, inputs_at, outputs_at, single_token}
use bca/types.{
  DefineService, SellerFactoryDatum, ServiceDatum, unique_asset_name,
}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
}

validator seller_factory(root_factory_policy_id: PolicyId) {
  mint(redeemer: DefineService, policy_id: PolicyId, self: Transaction) {
    let DefineService { max_instances, day_price } = redeemer

    expect [seller_input] = inputs_at(self.inputs, root_factory_policy_id)
    expect InlineDatum(raw_seller) = seller_input.output.datum
    expect seller_state: SellerFactoryDatum = raw_seller
    expect Some(seller_token) = single_token(
      seller_input.output.value,
      root_factory_policy_id,
    )

    let service_name = unique_asset_name(seller_input.output_reference)
    expect [Pair(minted_name, 1)] = dict.to_pairs(
      assets.tokens(self.mint, policy_id),
    )
    expect [service_output] = outputs_at(self.outputs, policy_id)
    expect InlineDatum(raw_service) = service_output.datum
    expect service: ServiceDatum = raw_service

    and {
      seller_token == seller_state.seller,
      minted_name == service_name,
      assets.without_lovelace(service_output.value) == assets.from_asset(
        policy_id,
        service_name,
        1,
      ),
      service == ServiceDatum {
        seller: seller_state.seller,
        service_index: seller_state.service_count,
        max_instances,
        day_price,
        instance_count: 0,
      },
      max_instances > 0,
      day_price > 0,
      list.has(self.extra_signatories, seller_state.seller),
    }
  }

  spend(
    datum: Option<ServiceDatum>,
    _redeemer: Data,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(current) = datum
    expect Some(own_input) = find_input(self.inputs, own_ref)
    expect Script(own_hash) = own_input.output.address.payment_credential
    expect Some(service_name) = single_token(own_input.output.value, own_hash)
    let state_token = assets.from_asset(own_hash, service_name, 1)

    expect [_] = inputs_at(self.inputs, own_hash)
    expect [continuing] = outputs_at(self.outputs, own_hash)
    expect InlineDatum(raw_next) = continuing.datum
    expect next: ServiceDatum = raw_next
    let next_count = current.instance_count + 1

    and {
      assets.without_lovelace(own_input.output.value) == state_token,
      continues_with(own_input.output, continuing, state_token),
      next == ServiceDatum { ..current, instance_count: next_count },
      next_count <= current.max_instances,
    }
  }

  else(_) {
    fail
  }
}

// ## Tests

const root_hash = #"0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f"

const own_hash = #"5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f"

const seller = #"02020202020202020202020202020202020202020202020202020202"

const seller_ref =
  OutputReference(
    #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    0,
  )

const own_ref =
  OutputReference(
    #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    2,
  )

fn seller_input(token_name: ByteArray) -> Input {
  Input(
    seller_ref,
    Output {
      address: Address {
        payment_credential: Script(root_hash),
        stake_credential: None,
      },
      value: assets.from_lovelace(2)
        |> assets.add(root_hash, token_name, 1),
      datum: InlineDatum(SellerFactoryDatum { seller, service_count: 7 }),
      reference_script: None,
    },
  )
}

fn service_output(name: ByteArray, datum: ServiceDatum) -> Output {
  Output {
    address: Address {
      payment_credential: Script(own_hash),
      stake_credential: None,
    },
    value: assets.from_lovelace(2) |> assets.add(own_hash, name, 1),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn new_service(index: Int) -> ServiceDatum {
  ServiceDatum {
    seller,
    service_index: index,
    max_instances: 2,
    day_price: 100,
    instance_count: 0,
  }
}

fn define(input: Input, datum: ServiceDatum) -> Bool {
  let name = unique_asset_name(seller_ref)
  seller_factory.mint(
    root_hash,
    DefineService { max_instances: 2, day_price: 100 },
    own_hash,
    Transaction {
      ..transaction.placeholder,
      inputs: [input],
      mint: assets.from_asset(own_hash, name, 1),
      outputs: [service_output(name, datum)],
      extra_signatories: [seller],
    },
  )
}

test define_service_takes_index_from_seller_state() {
  define(seller_input(seller), new_service(7))
}

test define_service_rejects_chosen_index() fail {
  define(seller_input(seller), new_service(3))
}

test define_service_rejects_state_without_root_token() fail {
  // seller state carrying another seller's token
  define(seller_input(#"09"), new_service(7))
}

fn take_instance_slot(count: Int, next_count: Int) -> Bool {
  let name = unique_asset_name(seller_ref)
  let current = ServiceDatum { ..new_service(7), instance_count: count }
  let next = ServiceDatum { ..current, instance_count: next_count }
  seller_factory.spend(
    root_hash,
    Some(current),
    Void,
    own_ref,
    Transaction {
      ..transaction.placeholder,
      inputs: [Input(own_ref, service_output(name, current))],
      outputs: [service_output(name, next)],
    },
  )
}

test service_state_counts_instances() {
  take_instance_slot(1, 2)
}

test service_state_rejects_past_max_instances() fail {
  take_instance_slot(2, 3)
}

test service_state_rejects_counter_reset() fail {
  take_instance_slot(1, 0)
}
