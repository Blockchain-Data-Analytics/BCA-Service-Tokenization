# @bca/chain-adapter-cardano

`ChainAdapter` implementation (see `packages/chain-adapter`) for the Cardano/Aiken
contracts in `bca-token-plutus/` (on-chain model: that directory's README).
Covers the whole hierarchy: `deploySellerFactory` (onboard seller),
`defineService`, `openInstance`, `deposit`/`withdraw`/`stop`/`getInstanceState`,
plus Cardano-only `close()`. Every returned `ContractRef` is the unit
(policy id + asset name, hex) of that level's state token.

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

`CardanoAdapter.init(config)` takes the three validators with their parameters
applied. Generate everything except `chain` and `api` with:

```sh
bca-token-plutus/scripts/apply-params.sh --network preprod \
  --admin <bca_admin key hash> --token-policy <BCA1 policy id> --token-name <BCA1 asset name hex> \
  -o cardano-preprod.json
```

```ts
import { preprod } from "evolution-sdk-bca";
import config from "./cardano-preprod.json";

const adapter = CardanoAdapter.init({
  ...config,
  chain: preprod,
  api: { baseUrl: "https://staging.blockchain-applied.com/api_preprod/v1", token: process.env.BCA_API_TOKEN },
});
```

Policy ids are read from the script addresses. `rootFactory.bcaAdminPkh` is the admin
key that must sign onboarding; `instance.tokenPolicyId`/`tokenAssetNameHex` identify
the BCA1 token. See `bca-token-plutus/README.md` for the full preprod walkthrough.

Transactions follow the on-chain rules: instance spends use a validity window of
5 minutes starting 60 s in the past (on-chain limit 10 minutes), and compute the next
datum with the same bound the validator reads for that action.

## Tests

```sh
npm test   # from the repo root or this package
```

`test/codec.test.ts` (Node's built-in test runner, run on the TypeScript sources
directly) checks that the datum and redeemer encoding in `src/codec.ts` is
byte-identical to the Aiken types (vectors pinned in
`bca-token-plutus/lib/bca/vectors.ak`), that token names are derived like
`unique_asset_name`, and that the off-chain instance state machine matches
`next_datum` on the same scenarios as the Aiken tests.

## Known limitations

- `deploySellerFactory` needs the connected wallet to be the BCA admin,
  `defineService` the seller; `close()` with a remaining balance needs a second
  signature from the other party, which this adapter does not collect.
- `subscribeEvents` is unimplemented (needs UTxO polling by policy id).
- None of the new flow has run against a network yet.
