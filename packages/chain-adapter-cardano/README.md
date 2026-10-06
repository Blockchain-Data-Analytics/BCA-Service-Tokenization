# @bca/chain-adapter-cardano

`ChainAdapter` implementation (see `packages/chain-adapter`) for the Cardano/Aiken
contract backend in `bca-token-plutus/`. Covers `deploySellerFactory`
(`root_factory.ak`) and `deposit`/`withdraw`/`stop`/`getInstanceState`
(`instance.ak`'s `service_instance` — proven against a live preprod deployment,
see [plan-plutus-tokenization.md](../../plan-plutus-tokenization.md)).
`defineService`/`openInstance` remain stubs until `service.ak` exists.

## Setup: the Evolution SDK fork

This package depends on `evolution-sdk-bca`, an npm alias for
`@bca/evolution-sdk` — the `add-bca-provider` branch of the Evolution SDK fork
at [code.blockchain-applied.com/BCA/evolution-sdk](https://code.blockchain-applied.com/BCA/evolution-sdk),
which adds `BlockchainAppliedProvider` so transaction building/submission goes
through BCA's own API instead of Blockfrost. It is not a drop-in for the
upstream `@evolution-sdk/evolution` package.

The fork's Forgejo workflow (`.forgejo/workflows/publish-bca-npm.yaml`) builds
`packages/evolution` on every push to `add-bca-provider` and publishes it to the
BCA Forgejo npm registry as `@bca/evolution-sdk@<upstream-version>-bca.<sha7>`.
The repo-root `.npmrc` maps the `@bca` scope to that registry; reading it needs
a Forgejo access token with `read:package` scope in your user `~/.npmrc`:

```sh
npm config set //code.blockchain-applied.com/api/packages/BCA/npm/:_authToken <token>
npm ci   # from the repo root
```

To move to a newer fork commit, bump the exact version in `package.json`
(`npm:@bca/evolution-sdk@<version>`) and run `npm install` to refresh the lockfile.

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
