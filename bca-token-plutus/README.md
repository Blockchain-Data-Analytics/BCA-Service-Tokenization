# bca-token-plutus

Cardano/Plutus contract backend for BCA Market for Tokenized Services — mirrors the
EVM factory hierarchy (`bca-token-solidity/`) as Aiken validators. See
[plan-reorg.md](../plan-reorg.md) §6 for the design, [../CLAUDE.md](../CLAUDE.md) for
repo orientation.

Status: `aiken build` and `aiken check` both pass (0 errors, 0 warnings, 23/23 tests)
against `compiler = "v1.1.23"` / `aiken-lang/stdlib v2.1.0`. Still an early scaffold
though — `root_factory`/`seller_factory`/`instance` exist, `service.ak`/`funder.ak`
don't yet, and none of it has been exercised against a real transaction (emulator or
testnet), only type-checked and unit-tested.

Will move to `contracts/cardano/` as part of the plan's mechanical reorg
(plan-reorg.md §8 step 3); kept as `bca-token-plutus/` for now so that rename doesn't
happen ahead of the rest of that step.

## Layout

```
bca-token-plutus/
├── aiken.toml            # project manifest + stdlib dependency
├── validators/
│   ├── root_factory.ak   # BCA mints one "seller factory" auth token per seller
│   ├── seller_factory.ak # seller mints one "service" auth token per newService()
│   └── instance.ak       # `service_instance` validator — the contract a client
│                         #   funds; thin glue around lib/bca/instance.ak
└── lib/bca/
    ├── types.ak          # shared datum/redeemer types, asset-name encoding + tests
    └── instance.ak       # pure port of BCA_ServiceInstance.sol's business logic
                          #   (balance math, state transitions, auth) + its tests
```

Aiken only compiles `lib/` and `validators/` — there's no separate top-level `test/`
directory convention like Cargo's. Tests are `test name() { ... }` blocks written
inline, right next to the function they cover (see the bottom of `lib/bca/types.ak`
and `lib/bca/instance.ak`). A `test/` dir at the project root is silently ignored,
not an error.

`service.ak` (the `newInstance()`/service-definition equivalent that *creates* an
instance UTxO) and `funder.ak` are not scaffolded yet — planned for plan-reorg.md §6.3
step 4. `validators/instance.ak` currently assumes its datum already exists at the
script address; it only covers funding/withdrawing/stopping an instance that's already
open, same as BCA_ServiceInstance.sol only covering what happens after
BCA_Service.newInstance() deploys it.

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

Runs every `test name() { ... }` block found in `lib/` and `validators/`: 21 in
`lib/bca/instance.ak` covering `balance_user`/`balance_provider`/`next_datum`/
`is_authorized`, plus 2 in `lib/bca/types.ak` for `index_to_asset_name` — 23 total,
0 failed.

Note the actual validators (`root_factory`, `seller_factory`, `service_instance`)
aren't directly exercised by `aiken check` — their business logic is pulled out into
plain functions in `lib/bca/instance.ak` specifically so it's unit-testable without
constructing a mock `Transaction`; the validators themselves are thin glue (decode
datum/redeemer, find the continuing output, delegate). Testing a validator end-to-end
(with real inputs/outputs/mint fields) needs an off-chain emulator — not set up yet,
tracked alongside `packages/chain-adapter-cardano`.

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

## Format & lint

```sh
aiken fmt            # format in place
aiken fmt --check    # CI mode: fail if anything is unformatted
```

## Next steps

With `root_factory.ak`/`seller_factory.ak`/`instance.ak` type-checking, building, and
unit-testing clean, the plan (plan-reorg.md §6.3) continues with:

- `service.ak` — the `newInstance()` equivalent that actually creates an instance
  UTxO (mints its state token, locks its initial zero-deposit datum); `instance.ak`
  currently assumes that UTxO already exists.
- `funder.ak`, mirroring `BCA_Funding24`'s at-most-once-per-24h auto-funding.
- `packages/chain-adapter-cardano` (already scaffolded) wired against the real
  compiled blueprint from `aiken build` instead of placeholder config, and extended
  past `deploySellerFactory` to cover `deposit`/`withdraw`/`stop`/`getInstanceState`
  against `service_instance` once an emulator/testnet round-trip validates it.
- Deployment to Cardano Preprod testnet via Blockfrost, surfaced first as an opt-in
  chain in `bca-console`.
