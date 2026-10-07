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

`CardanoAdapter.init(config)` takes the three applied validators — this package does
not run `aiken build`/`aiken blueprint apply` itself. Apply parameters in dependency
order against `bca-token-plutus/plutus.json` (each parameter is CBOR-encoded Plutus
data, so a 28-byte hash is `581c<hash>`):

```sh
cd bca-token-plutus
# 1. root_factory(bca_admin)
aiken blueprint apply -m root_factory -v root_factory -o /tmp/root.json 581c<bca_admin_pkh>
# 2. seller_factory(root_factory policy id = root_factory hash from step 1)
aiken blueprint apply -m seller_factory -v seller_factory -o /tmp/seller.json 581c<root_hash>
# 3. service_instance(token_policy_id, token_asset_name, seller_factory policy id)
aiken blueprint apply -m instance -v service_instance -o /tmp/i1.json 581c<bca1_policy_id>
aiken blueprint apply -i /tmp/i1.json -m instance -v service_instance -o /tmp/i2.json <asset_name_cbor>
aiken blueprint apply -i /tmp/i2.json -m instance -v service_instance -o /tmp/instance.json 581c<seller_factory_hash>
```

Each step's hash is the validator's `hash` in its output file. Pass each script's
`compiledCode` and its bech32 script address (`rootFactory`, `sellerFactory`,
`instance`); policy ids are read from the addresses. `rootFactory.bcaAdminPkh` is the
admin key that must sign onboarding, and `instance.tokenPolicyId`/`tokenAssetNameHex`
identify the BCA1 token.

Transactions follow the on-chain rules: instance spends use a validity window of
5 minutes starting 60 s in the past (on-chain limit 10 minutes), and compute the next
datum with the same bound the validator reads for that action.

## Known limitations

- `deploySellerFactory` needs the connected wallet to be the BCA admin,
  `defineService` the seller; `close()` with a remaining balance needs a second
  signature from the other party, which this adapter does not collect.
- `subscribeEvents` is unimplemented (needs UTxO polling by policy id).
- None of the new flow has run against a network yet.
