# @bca/chain-adapter-cardano

`ChainAdapter` implementation (see `packages/chain-adapter`) for the Cardano/Aiken
contract backend in `bca-token-plutus/`. Covers `deploySellerFactory`
(`root_factory.ak`) and `deposit`/`withdraw`/`stop`/`getInstanceState`
(`instance.ak`'s `service_instance` — proven against a live preprod deployment,
see [plan-plutus-tokenization.md](../../plan-plutus-tokenization.md)).
`defineService`/`openInstance` remain stubs until `service.ak` exists.

## Setup: building the Evolution SDK fork

This package depends on `evolution-sdk-bca`, an alias for
`github:Blockchain-Data-Analytics/evolution-sdk#add-bca-provider` — a fork of
Cardano's Evolution SDK that adds `BlockchainAppliedProvider`, so transaction
building/submission goes through BCA's own API instead of Blockfrost. It is
**not published to npm** and is not a drop-in for the upstream
`@evolution-sdk/evolution` package (different maintainer, unmerged branch).

`npm install` at the repo root fetches the fork via git, but **does not**
produce a runnable build — two things npm's git-dependency fetch doesn't
handle for this monorepo:

1. It fetches the whole `evolution-sdk` monorepo (this package needs is nested
   at `packages/evolution` inside it), not just the one package.
2. It does not include `pnpm-lock.yaml` (confirmed: present in the fork's own
   git history, but absent from what npm's git fetcher lands in
   `node_modules/evolution-sdk-bca`) and does not run the fork's own
   `pnpm install` + `turbo build` — so `packages/evolution/dist/` doesn't
   exist yet after a plain `npm install`.

One-time manual build step (matches `bca-token-plutus/README.md`'s Aiken setup
in spirit — a non-npm toolchain requirement, documented rather than silently
automated via a heavy `postinstall`):

```sh
# from the repo root, after `npm install`
cd node_modules/evolution-sdk-bca
corepack pnpm@9.0.0 install    # pins the version the fork's package.json expects
corepack pnpm@9.0.0 --filter @evolution-sdk/evolution build
```

This produces `node_modules/evolution-sdk-bca/packages/evolution/dist/`,
which `src/index.ts` imports directly
(`evolution-sdk-bca/packages/evolution/dist/index.js`).

Re-run the build step whenever `npm install` refreshes `node_modules`
(the fetched git dependency is not built automatically), or after pulling a
newer commit of the fork branch.

## Config

`CardanoAdapter.init(config)` takes compiled validator CBOR, not source —
this package does not run `aiken build`/`aiken blueprint apply` itself. Produce
`instance.compiledCodeHex` (and `rootFactory.compiledCodeHex`, if using
`deploySellerFactory`) by applying that validator's parameters against
`bca-token-plutus/plutus.json` first:

```sh
cd bca-token-plutus
aiken blueprint apply -m instance -v service_instance -o /tmp/step1.json <token_policy_id CBOR>
aiken blueprint apply -i /tmp/step1.json -m instance -v service_instance -o applied.json <token_asset_name CBOR>
```

See [plan-plutus-tokenization.md](../../plan-plutus-tokenization.md) for the
exact CBOR-encoding steps and a worked example (policy id, asset name,
resulting script address) from the first live deployment.

## Known limitations

- `deposit`/`withdraw`/`stop`/`getInstanceState` look up the instance's
  current UTxO by scanning `config.instance.scriptAddress` and require
  **exactly one** UTxO there. There is no on-chain way yet to distinguish
  multiple concurrent instances at the same script address — that needs
  `service.ak`'s state-thread-token pattern (plan-reorg.md §6.1), not
  implemented yet. Fine for single-instance testing/demos, not for
  production multi-tenant use.
- `deploySellerFactory` is ported to this SDK generation but **not** yet
  exercised against a live network (unlike the instance methods) — verify
  before relying on it.
- `subscribeEvents` is unimplemented (needs polling semantics that aren't
  well-defined until multiple instances can exist).
