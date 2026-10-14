#!/usr/bin/env bash
# Checks validator execution units against budgets.json.
#
#   scripts/check-budgets.sh [aiken-check.json]           check (runs `aiken check` if no file given)
#   scripts/check-budgets.sh --update [aiken-check.json]  rewrite budgets as current usage + 25%
#
# Each handler budget is measured by a happy-path test in validators/*.ak; each
# transaction sums the handlers it runs and must stay within max_tx_ex_units.
set -euo pipefail
cd "$(dirname "$0")/.."

update=false
if [[ "${1:-}" == "--update" ]]; then
  update=true
  shift
fi

results="${1:-}"
if [[ -z "$results" ]]; then
  results=$(mktemp)
  aiken check > "$results"
fi

align() { if command -v column >/dev/null; then column -t -s $'\t'; else cat; fi; }

# "module.test" -> {mem, cpu} for every test that is expected to pass
units=$(jq '[.modules[] | .name as $m | .tests[]
  | select(.on_failure == "fail_immediately")
  | {key: "\($m).\(.title)", value: .execution_units}] | from_entries' "$results")

if $update; then
  jq --argjson units "$units" '
    def headroom: (. * 1.25 | ceil) as $v | (($v + 999) / 1000 | floor) * 1000;
    .handlers |= with_entries(
      .key as $k
      | if $units[$k] == null then error("no passing test \($k)") else . end
      | .value += {mem: ($units[$k].mem | headroom), cpu: ($units[$k].cpu | headroom)})
  ' budgets.json > budgets.json.tmp
  mv budgets.json.tmp budgets.json
  echo "budgets.json updated"
  exit 0
fi

jq -r --argjson units "$units" '
  def pct($a; $b): ($a * 1000 / $b | floor) / 10;
  .max_tx_ex_units as $max
  | ( ["handler", "mem", "budget", "cpu", "budget", "status"] | @tsv ),
    ( .handlers | to_entries[]
      | .key as $k | .value as $b | ($units[$k] // {mem: null, cpu: null}) as $u
      | [ "\($b.label) (\($k))", $u.mem, $b.mem, $u.cpu, $b.cpu,
          (if $u.mem == null then "MISSING"
           elif $u.mem > $b.mem or $u.cpu > $b.cpu then "OVER"
           else "ok" end) ] | @tsv ),
    "",
    ( ["transaction", "mem", "% of tx max", "cpu", "% of tx max", "status"] | @tsv ),
    ( .transactions | to_entries[]
      | .key as $tx
      | ([.value[] | $units[.].mem // 0] | add) as $mem
      | ([.value[] | $units[.].cpu // 0] | add) as $cpu
      | [ $tx, $mem, pct($mem; $max.mem), $cpu, pct($cpu; $max.cpu),
          (if $mem > $max.mem or $cpu > $max.cpu then "OVER" else "ok" end) ] | @tsv )
' budgets.json | align | tee /tmp/budget-report.txt

if grep -qE '(OVER|MISSING)$' /tmp/budget-report.txt; then
  echo "::error::execution units over budget or budget test missing — optimize, or raise deliberately with scripts/check-budgets.sh --update"
  exit 1
fi
