# bca-token-plutus

Cardano/Plutus contract backend for BCA Market for Tokenized Services — mirrors the
EVM factory hierarchy (`bca-token-solidity/`, see [doc/Contracts.md](../doc/Contracts.md))
as Aiken validators.

Status: early, not audited, must not hold real funds. `aiken check` covers the pure
logic and each validator against mock transactions; nothing beyond the first
`service_instance` version has run on a network yet.

## Layout

```
bca-token-plutus/
├── aiken.toml              # project manifest + stdlib dependency
├── validators/
│   ├── root_factory.ak     # BCA onboards sellers; holds each seller's state UTxO
│   ├── seller_factory.ak   # sellers define services; holds each service's state UTxO
│   └── instance.ak         # `service_instance`: opens instances (mint) and runs
│                           #   deposit/withdraw/stop/close (spend)
└── lib/bca/
    ├── types.ak            # datums, redeemers, state-token naming
    ├── tx.ak               # validity window, own inputs/outputs, continuing-output rule
    └── instance.ak         # pure port of BCA_ServiceInstance.sol (balance math,
                            #   state transitions, auth, per-side clock)
```

## On-chain model

Every level's state is a UTxO holding exactly one **state token**. Each validator is
both the minting policy of its tokens and the spending validator of the UTxOs that
hold them (one script hash), and is parameterized only by its parent's hash:

| level    | validator (params)                                                   | token name                         | datum                  |
|----------|----------------------------------------------------------------------|------------------------------------|------------------------|
| seller   | `root_factory(bca_admin)`                                            | seller key hash                    | `SellerFactoryDatum`   |
| service  | `seller_factory(root_factory_policy_id)`                             | `unique_asset_name(seller UTxO)`   | `ServiceDatum`         |
| instance | `service_instance(token_policy_id, token_asset_name, seller_factory_policy_id)` | `unique_asset_name(service UTxO)` | `ServiceInstanceDatum` |

Flow, mirroring the EVM contracts:

1. **Onboard seller** (`BCA_ServiceManager.newController`): `root_factory` mints the
   seller token, BCA admin signs, and it is locked at the `root_factory` address with
   `service_count = 0`.
2. **Define service** (`BCA_ServiceController.newService`): the seller spends their
   seller state (`service_count` + 1), and `seller_factory` mints the service token
   into a service state UTxO whose `service_index` is the old count.
3. **Open instance** (`BCA_Service.newInstance`): anyone spends a service state
   (`instance_count` + 1, at most `max_instances`), and `service_instance` mints the
   instance token into an instance UTxO with deposit 0 and price/provider/service
   copied from the service.
4. **Use the instance**: `MakeDeposit`, `WithdrawUser`, `WithdrawProvider`, `Stop`,
   then `Close` (burns the instance token once stopped).

Rules enforced on every state spend:

- the input holds its state token, so datums someone else locks at a script
  address are never accepted as state;
- it is the only input from that script (no batching), and there is exactly one
  output back to the **same address** (payment and stake credential) holding
  **exactly** the state token (plus, for instances, `deposit - retracted` BCA1),
  with no less lovelace than before.

Instance balances follow `BCA_ServiceInstance.sol`: `paid` is elapsed time × `day_price`
(integer division, rounding in the user's favor); the user's balance is `deposit - paid`,
the provider's `min(paid, deposit) - retracted`, so both together equal exactly what the
instance holds. A withdrawal that leaves at most one second's worth of service
(`day_price / 86_400`, same as the EVM threshold) stops a running instance; on an
already stopped one it just withdraws, so both parties can always drain it fully.

Instance time handling: the validity range must be finite on both ends and at
most 10 minutes wide (`max_validity_ms`). The real time lies somewhere in that
window, and the transaction builder picks the window, so each action reads the bound
that works against the party it benefits (`clock_for`): the first deposit
starts the clock at the lower bound, a user withdrawal reads the upper bound, a
provider withdrawal the lower bound, and `Stop` the upper bound if the user signs,
the lower one otherwise. Bounds should be whole seconds (slot-granular).

Known gaps:

- Bumping a service's `instance_count` without opening an instance is possible
  (it only costs fees). That's the same as calling the permissionless
  `BCA_Service.newInstance()` with junk users on EVM. Closing it would need
  `seller_factory` to know the `service_instance` hash, which in turn depends on it.
- Seller onboarding trusts BCA admin not to onboard the same seller twice (EVM checks
  `isDeployed`); token names stay unique regardless.
- `Close` with a remaining balance needs both parties.
- Not audited.

## Setup

1. Install the Aiken toolchain (one-time, machine-wide). Avoid the `curl | bash`
   installer (`install.aiken-lang.org`) if you want to see what's actually
   happening — two more controlled options:

   - **Build from source with `cargo`** (every dependency compile step is visible,
     `--locked` pins to the crate's own lockfile for reproducibility):

     ```sh
     cargo install aiken --locked
     aiken --version
     ```

     Requires a Rust toolchain (`rustup`).

   - **Nix**, since this repo already has `shell.nix`: add `aiken` to
     `nativeBuildInputs` there and enter via `nix-shell` — declarative, pinned to
     whatever nixpkgs revision the shell resolves, no script execution.

   - Or download a prebuilt binary directly from
     https://github.com/aiken-lang/aiken/releases, verify its checksum, and put it
     on `PATH` yourself — no installer at all.

   Editor support (recommended): the "Aiken" VS Code extension, or `aiken lsp` for
   other editors.

2. From this directory, fetch the declared dependencies (`aiken-lang/stdlib`, see
   `aiken.toml`):

   ```sh
   cd bca-token-plutus
   aiken packages install
   ```

## Build

Type-checks and compiles every validator to its `plutus.json` blueprint:

```sh
aiken build
```

Run this after any change to `validators/` or `lib/` — it's the fastest way to catch
whether the scaffold above actually compiles.

## Run tests

```sh
aiken check
```

Runs every `test` block in `lib/` and `validators/`:

- **Validator tests** (`validators/*.ak`): each handler called directly with a mock
  transaction — the happy path of every redeemer and a rejection for every check
  (missing state token, ADA siphon, foreign token, moved address, batching, signer,
  validity window, datum tampering, ...).
- **Unit tests** next to the pure functions in `lib/bca/`.
- **Property tests** (`lib/bca/properties.ak`, fuzzers from `aiken-lang/fuzz`, a
  test-only dependency): random sequences of deposits, withdrawals and stops at random
  times must keep the instance solvent (`balance_user + balance_provider ==
  deposit - retracted`), move balances only in the right direction over time, never
  refuse a withdrawal within the available balance and let a stopped instance be
  drained completely.
- **Encoding vectors** (`lib/bca/vectors.ak`): the CBOR of every datum and redeemer,
  pinned; `packages/chain-adapter-cardano` tests decode and re-encode the same bytes.

CI runs `aiken check --max-success 1000` (1000 random cases per property).

Note: `aiken check`/`aiken build` render their diagnostics assuming a TTY. If you run
them with stdout piped or redirected (e.g. through another tool, or captured into a
log file non-interactively) they can exit non-zero with no visible error text at all
— rerun directly in a real terminal (or via `script -q /dev/null aiken check`) to see
the actual message.

Useful flags:

```sh
aiken check -m bca/properties       # only one module (full module path)
aiken check --max-success 1000      # more random cases per property (default 100)
aiken check --trace-level verbose   # full traces on failure (this is already the default)
```

## Execution budgets

`budgets.json` caps the execution units (mem/cpu) of every validator handler, measured
by its happy-path test in `validators/*.ak`, and lists which handlers each real
transaction runs together (e.g. opening an instance runs `seller_factory.spend` and
`service_instance.mint`), whose sum must stay within the protocol's per-transaction
limit. CI runs:

```sh
scripts/check-budgets.sh            # prints usage vs budget, fails if over
scripts/check-budgets.sh --update   # after a deliberate change: budgets = usage + 25%
```

The measurements include building the mock transaction inside the test, so real
on-chain cost is somewhat lower.

## Format & lint

```sh
aiken fmt            # format in place
aiken fmt --check    # CI mode: fail if anything is unformatted
```

## Preprod walkthrough

What you need:

- `aiken` and `jq`;
- three preprod key pairs, each funded with some tADA from the
  [testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet): BCA admin,
  seller and user (one key works for a smoke test, but two distinct keys also exercise
  the signature checks);
- a native token standing in for BCA1, e.g. minted under a signature-locked native
  script of the admin key: note its policy id and asset name (hex), and send some to
  the user;
- a token for the BCA API (`staging.blockchain-applied.com`).

1. **Apply parameters** (from the repo root; `npm run cardano:config -- …` is the same):

   ```sh
   bca-token-plutus/scripts/apply-params.sh --network preprod \
     --admin <admin key hash> --token-policy <policy id> --token-name <asset name hex> \
     -o cardano-preprod.json
   ```

   It prints the three script addresses. Nothing needs to be deployed separately: the
   validators are attached to the transactions that use them.

2. **Create the adapter** from that file (see `packages/chain-adapter-cardano/README.md`)
   and connect a CIP-30 wallet (`connectWallet()`).

3. **Run the flow**, each step with the wallet named:

   | step | call | wallet |
   |------|------|--------|
   | onboard seller | `deploySellerFactory(rootPolicyId, sellerAddress)` → seller ref | admin |
   | define service | `defineService(sellerRef, { maxInstances, dayPrice })` → service ref | seller |
   | open instance | `openInstance(serviceRef, userAddress)` → instance ref | anyone |
   | fund | `deposit(instanceRef, amount)` | anyone holding BCA1 |
   | withdraw | `withdraw(instanceRef, amount, "client" \| "seller")` | user / seller |
   | stop | `stop(instanceRef)` | user or seller |
   | close | `close(instanceRef)` once both sides withdrew | user or seller |

   `rootPolicyId` is the payment-credential hash of the `root_factory` address. Each
   ref is the unit (policy id + asset name) of a state token.

4. **Check the state** with `getInstanceState(instanceRef)`, or look at the UTxOs at
   the printed script addresses (each holds exactly one state token and an inline
   datum) in a preprod explorer or via the BCA API.

## Updating Aiken

Dependabot does not cover Aiken, so the compiler and stdlib are updated by hand. Watch
releases of [aiken-lang/aiken](https://github.com/aiken-lang/aiken/releases) and
[aiken-lang/stdlib](https://github.com/aiken-lang/stdlib/releases) (GitHub: Watch →
Custom → Releases) and check at least monthly.

Any compiler or stdlib change can change the compiled code and therefore every script
hash, address and policy id: treat it as a new deployment, not an in-place upgrade.

**Compiler** — the version is pinned in three places that must match:

1. `aiken.toml`: `compiler = "vX.Y.Z"`.
2. `ext/` (git LFS) and `docker/Dockerfile.ci-cardano`: download the two
   `aiken-<triple>.tar.gz` (`x86_64` and `aarch64` `-unknown-linux-musl`) release
   tarballs into `ext/` as `aiken-vX.Y.Z-<triple>.tar.gz`, remove the old ones, and
   update `AIKEN_VERSION` and the two checksums in the Dockerfile. Check the files
   against the release's published digests:

   ```sh
   curl -fsSL https://api.github.com/repos/aiken-lang/aiken/releases/tags/vX.Y.Z \
     | jq -r '.assets[] | select(.name | test("unknown-linux-musl.tar.gz$")) | "\(.name) \(.digest)"'
   shasum -a 256 ext/aiken-vX.Y.Z-*-unknown-linux-musl.tar.gz
   ```

3. The CI image tag: bump `docker/ci-cardano.version` in the same change. CI runs in
   `<CI_IMAGE>:<that version>`, so each commit uses the toolchain it declares.
   - GitHub builds and pushes the new tag on the next CI run.
   - On Forgejo, run "Build ci-cardano image" on the branch (workflow_dispatch) before
     its CI, since the new tag doesn't exist yet.
   - The `CI_IMAGE` variable itself never changes (see the top-level README).

**stdlib** — change `version` under `[[dependencies]]` in `aiken.toml`, then run
`aiken check` (re-fetches it and updates `aiken.lock`).

In both cases finish with `aiken fmt --check`, `aiken check` and `aiken build`, and
commit the regenerated `plutus.json` and `aiken.lock`.

## Next steps

- An external audit before any mainnet funds.
- `funder.ak`, mirroring `BCA_Funding24`'s at-most-once-per-24h auto-funding.
- Re-deploy to preprod: the datum layout and validator parameters changed, so
  the first preprod deployment of `service_instance` is incompatible.
