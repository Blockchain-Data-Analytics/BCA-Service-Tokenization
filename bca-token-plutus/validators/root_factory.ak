//// Root factory: BCA onboards sellers. Mirrors BCA_ServiceManager.
////
//// mint (OnboardSeller): mints one token named after the seller's key hash
//// and locks it at this script's own address with
//// `SellerFactoryDatum { seller, service_count: 0 }` — the seller's state UTxO.
////
//// spend (seller state UTxO): only the seller, and only to bump
//// `service_count` by one while keeping the token, address and lovelace.
//// seller_factory's DefineService consumes it this way and takes the old
//// count as the new service's index, so service indices never repeat.

use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use bca/tx.{continues_with, inputs_at, outputs_at}
use bca/types.{OnboardSeller, SellerFactoryDatum}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_input,
}

validator root_factory(bca_admin: ByteArray) {
  mint(redeemer: OnboardSeller, policy_id: PolicyId, self: Transaction) {
    let OnboardSeller { seller } = redeemer

    expect [Pair(minted_name, 1)] = dict.to_pairs(
      assets.tokens(self.mint, policy_id),
    )
    expect [state_output] = outputs_at(self.outputs, policy_id)
    expect InlineDatum(raw_datum) = state_output.datum
    expect state: SellerFactoryDatum = raw_datum

    and {
      builtin.length_of_bytearray(seller) == 28,
      minted_name == seller,
      assets.without_lovelace(state_output.value) == assets.from_asset(
        policy_id,
        seller,
        1,
      ),
      state == SellerFactoryDatum { seller, service_count: 0 },
      list.has(self.extra_signatories, bca_admin),
    }
  }

  spend(
    datum: Option<SellerFactoryDatum>,
    _redeemer: Data,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(current) = datum
    expect Some(own_input) = find_input(self.inputs, own_ref)
    expect Script(own_hash) = own_input.output.address.payment_credential
    let state_token = assets.from_asset(own_hash, current.seller, 1)

    expect [_] = inputs_at(self.inputs, own_hash)
    expect [continuing] = outputs_at(self.outputs, own_hash)
    expect InlineDatum(raw_next) = continuing.datum
    expect next: SellerFactoryDatum = raw_next

    and {
      assets.without_lovelace(own_input.output.value) == state_token,
      continues_with(own_input.output, continuing, state_token),
      next == SellerFactoryDatum {
        ..current,
        service_count: current.service_count + 1,
      },
      list.has(self.extra_signatories, current.seller),
    }
  }

  else(_) {
    fail
  }
}

// ## Tests

const admin = #"adadadadadadadadadadadadadadadadadadadadadadadadadadadad"

const seller = #"02020202020202020202020202020202020202020202020202020202"

const own_hash = #"0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f"

const own_ref =
  OutputReference(
    #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    1,
  )

fn state_output(datum: SellerFactoryDatum, lovelace: Int) -> Output {
  Output {
    address: Address {
      payment_credential: Script(own_hash),
      stake_credential: None,
    },
    value: assets.from_lovelace(lovelace)
      |> assets.add(own_hash, datum.seller, 1),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn onboard(outputs: List<Output>, signers: List<ByteArray>) -> Bool {
  root_factory.mint(
    admin,
    OnboardSeller { seller },
    own_hash,
    Transaction {
      ..transaction.placeholder,
      mint: assets.from_asset(own_hash, seller, 1),
      outputs,
      extra_signatories: signers,
    },
  )
}

test onboard_seller_locks_state() {
  onboard(
    [state_output(SellerFactoryDatum { seller, service_count: 0 }, 2)],
    [admin],
  )
}

test onboard_seller_requires_admin() fail {
  onboard(
    [state_output(SellerFactoryDatum { seller, service_count: 0 }, 2)],
    [seller],
  )
}

test onboard_seller_rejects_token_not_locked() fail {
  onboard([], [admin])
}

test onboard_seller_rejects_nonzero_counter() fail {
  onboard(
    [state_output(SellerFactoryDatum { seller, service_count: 5 }, 2)],
    [admin],
  )
}

fn bump(next: SellerFactoryDatum, signers: List<ByteArray>) -> Bool {
  let current = SellerFactoryDatum { seller, service_count: 4 }
  root_factory.spend(
    admin,
    Some(current),
    Void,
    own_ref,
    Transaction {
      ..transaction.placeholder,
      inputs: [Input(own_ref, state_output(current, 2))],
      outputs: [state_output(next, 2)],
      extra_signatories: signers,
    },
  )
}

test seller_state_bumps_by_one() {
  bump(SellerFactoryDatum { seller, service_count: 5 }, [seller])
}

test seller_state_rejects_skipped_index() fail {
  bump(SellerFactoryDatum { seller, service_count: 6 }, [seller])
}

test seller_state_rejects_reused_index() fail {
  bump(SellerFactoryDatum { seller, service_count: 4 }, [seller])
}

test seller_state_requires_seller() fail {
  bump(SellerFactoryDatum { seller, service_count: 5 }, [admin])
}
