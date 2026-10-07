# bca-token-plutus

Cardano/Plutus contract backend for BCA Market for Tokenized Services — mirrors the
EVM factory hierarchy (`bca-token-solidity/`) as Aiken validators. See
[plan-reorg.md](../plan-reorg.md) §6 for the design, [../CLAUDE.md](../CLAUDE.md) for
repo orientation.

Status: early, not audited, must not hold real funds. `aiken check` covers the pure
logic and each validator against mock transactions; nothing beyond the first
`service_instance` version has run on a network yet.

Will move to `contracts/cardano/` as part of the plan's mechanical reorg
(plan-reorg.md §8 step 3); kept as `bca-token-plutus/` for now so that rename doesn't
happen ahead of the rest of that step.

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
- Not audited; no property tests yet.

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

Runs every `test name() { ... }` block in `lib/` and `validators/`: the pure
functions in `lib/bca/` plus each validator handler called directly against mock
transactions (happy path and one rejection per rule above).

Add a `test name() { ... }` next to any new pure function the same way.

Note: `aiken check`/`aiken build` render their diagnostics assuming a TTY. If you run
them with stdout piped or redirected (e.g. through another tool, or captured into a
log file non-interactively) they can exit non-zero with no visible error text at all
— rerun directly in a real terminal (or via `script -q /dev/null aiken check`) to see
the actual message.

Useful flags:

```sh
aiken check -m types_test           # only tests matching this name/module filter
aiken check --trace-level verbose   # full traces on failure (this is already the default)
```

Property-based tests (`test foo(x via fuzzer) { ... }`) run with a fixed number of
random cases by default; increase for CI-grade confidence with:

```sh
aiken check --max-success 1000
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

## Updating Aiken

Dependabot does not cover Aiken, so the compiler and stdlib are updated by hand. Watch
releases of [aiken-lang/aiken](https://github.com/aiken-lang/aiken/releases) and
[aiken-lang/stdlib](https://github.com/aiken-lang/stdlib/releases) (GitHub: Watch →
Custom → Releases) and check at least monthly.

Any compiler or stdlib change can change the compiled code and therefore every script
hash, address and policy id: treat it as a new deployment, not an in-place upgrade.

**Compiler** — the version is pinned in three places that must match:

1. `aiken.toml`: `compiler = "vX.Y.Z"`.
2. `docker/Dockerfile.ci-cardano`: `AIKEN_VERSION` and the two release tarball
   checksums, taken from the release's published digests:

   ```sh
   curl -fsSL https://api.github.com/repos/aiken-lang/aiken/releases/tags/vX.Y.Z \
     | jq -r '.assets[] | select(.name | test("unknown-linux-musl.tar.gz$")) | "\(.name) \(.digest)"'
   ```

3. The CI image tag: bump `VERSION` in `.forgejo/workflows/build-ci-cardano-image.yaml`,
   let that workflow publish the image, then bump `ci-cardano:<version>` in
   `.forgejo/workflows/aiken.yaml` and `typescript.yaml` (and in the Evolution SDK
   fork's `publish-bca-npm.yaml`).

**stdlib** — change `version` under `[[dependencies]]` in `aiken.toml`, then run
`aiken check` (re-fetches it and updates `aiken.lock`).

In both cases finish with `aiken fmt --check`, `aiken check` and `aiken build`, and
commit the regenerated `plutus.json` and `aiken.lock`.

## Next steps

- Property tests for the balance math (`via fuzzer`) and an external audit before
  any mainnet funds.
- `funder.ak`, mirroring `BCA_Funding24`'s at-most-once-per-24h auto-funding.
- Re-deploy to preprod: the datum layout and validator parameters changed, so
  the first preprod deployment of `service_instance` is incompatible.
