#!/bin/sh
# Runs TLC on every config and compares the outcome with the expectation.
#   ./check.sh            all configs, one line each
#   ./check.sh Arrears    one config, full TLC output (error trace)
cd "$(dirname "$0")" || exit 1
TLA2TOOLS=${TLA2TOOLS:-ext/tla2tools.jar}

tlc() {
    java -XX:+UseParallelGC -cp ${TLA2TOOLS} tlc2.TLC \
        -metadir "$(mktemp -d)" -config "$1.cfg" Service.tla 2>&1
}
[ $# -gt 0 ] && { tlc "$1"; exit; }

rc=0
expect() {  # expect <config> <text TLC must print>
    if tlc "$1" | grep -q "$2"; then echo "ok    $1: $2"
    else echo "FAIL  $1: expected '$2'"; rc=1; fi
}
expect AsImplemented "No error has been found"
expect Arrears       "DepositCreditsUser is violated"
expect Fixed         "No error has been found"
expect UnderDeposit  "ProviderSecured is violated"
expect LockBypass    "ProviderSecured is violated"
expect FeeAndRun     "NoFeeAndRun is violated"
expect Settle        "No error has been found"
exit $rc
