#!/usr/bin/env bash
# Aiken CI: format, tests (unit + property), execution budgets, blueprint drift.
# Run from anywhere; used by .forgejo/workflows and .github/workflows.
set -euo pipefail
cd "$(dirname "$0")/../bca-token-plutus"

aiken --version

echo "== aiken fmt --check"
aiken fmt --check

echo "== aiken check"
results=$(mktemp)
aiken check --max-success "${AIKEN_MAX_SUCCESS:-1000}" > "$results"
jq -r '.modules[] | .name as $m | .tests[] | "\(.status)\t\($m).\(.title)"' "$results"
jq -c '.summary' "$results"
jq -e '.summary.failed == 0' "$results" > /dev/null

echo "== execution-unit budgets"
scripts/check-budgets.sh "$results"

# plutus.json is committed; rebuild and fail if it no longer matches the
# sources. preamble.compiler is excluded because its build suffix
# (v1.1.23+unknown from `cargo install` vs +<commit> from release binaries)
# differs between otherwise identical compilers.
echo "== aiken build + blueprint drift"
committed=$(mktemp)
cp plutus.json "$committed"
aiken build
if ! diff -u <(jq -S 'del(.preamble.compiler)' "$committed") <(jq -S 'del(.preamble.compiler)' plutus.json); then
  echo "::error::bca-token-plutus/plutus.json is out of date — run 'aiken build' and commit the result"
  exit 1
fi
