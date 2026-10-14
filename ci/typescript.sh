#!/usr/bin/env bash
# TypeScript CI for the root npm workspace (packages/*): lockfile pinning,
# install, type-check, unit tests, audit. Used by .forgejo and .github workflows.
#
# NPM_TOKEN: Forgejo token with read:package for the @bca registry (see .npmrc).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -n "${NPM_TOKEN:-}" ]]; then
  npm config set "//code.blockchain-applied.com/api/packages/BCA/npm/:_authToken" "$NPM_TOKEN"
fi

# Every non-workspace package must come from a registry tarball with an
# integrity hash: git dependencies fail in CI and pin nothing reproducible.
echo "== lockfile sources"
unpinned=$(jq -r '.packages | to_entries[]
  | select(.key != "" and (.value.link | not) and (.key | startswith("packages/") and (contains("/node_modules/") | not) | not))
  | select((.value.resolved // "" | startswith("https://") | not) or (.value.integrity | not))
  | "\(.key)\t\(.value.resolved // "-")"' package-lock.json)
if [[ -n "$unpinned" ]]; then
  echo "::error::package-lock.json has dependencies without a registry tarball + integrity:"
  echo "$unpinned"
  exit 1
fi

echo "== npm ci"
npm ci --no-fund

echo "== type-check"
npm run check

echo "== unit tests"
npm test

echo "== npm audit"
npm audit --audit-level=moderate
