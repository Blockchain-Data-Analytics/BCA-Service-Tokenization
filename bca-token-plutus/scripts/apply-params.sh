#!/usr/bin/env bash
# Applies the validator parameters to plutus.json in dependency order and prints
# the JSON config for CardanoAdapter.init() (packages/chain-adapter-cardano),
# minus `chain` and `api`, which are set in code.
#
#   scripts/apply-params.sh --network preprod \
#     --admin <bca_admin key hash> \
#     --token-policy <BCA1 policy id> --token-name <BCA1 asset name, hex> \
#     [-o config.json]
#
# Requires aiken and jq. Run `aiken build` first if the sources changed.
set -euo pipefail
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$self")/.."

usage() { sed -n '2,11p' "$self" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

network="" admin="" token_policy="" token_name="" out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --network) network="$2"; shift 2 ;;
    --admin) admin="$2"; shift 2 ;;
    --token-policy) token_policy="$2"; shift 2 ;;
    --token-name) token_name="$2"; shift 2 ;;
    -o | --out) out="$2"; shift 2 ;;
    -h | --help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

case "$network" in
  preprod | preview) mainnet_flag=() ;;
  mainnet) mainnet_flag=(--mainnet) ;;
  *) die "--network must be preprod, preview or mainnet" ;;
esac

hex_of_len() { # value, min bytes, max bytes, name
  [[ "$1" =~ ^([0-9a-fA-F]{2})*$ ]] || die "$4 must be hex"
  local n=$((${#1} / 2))
  ((n >= $2 && n <= $3)) || die "$4 must be $2..$3 bytes, got $n"
}
hex_of_len "$admin" 28 28 "--admin"
hex_of_len "$token_policy" 28 28 "--token-policy"
hex_of_len "$token_name" 0 32 "--token-name"
lower() { tr "[:upper:]" "[:lower:]" <<< "$1"; }
admin=$(lower "$admin") token_policy=$(lower "$token_policy") token_name=$(lower "$token_name")

# CBOR-encoded Plutus bytestring parameter (at most 32 bytes here).
cbor_bytes() {
  local n=$((${#1} / 2))
  if ((n < 24)); then printf '%02x%s' $((0x40 + n)) "$1"; else printf '58%02x%s' "$n" "$1"; fi
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

apply() { # in, module, validator, cbor, out
  aiken blueprint apply -i "$1" -m "$2" -v "$3" -o "$5" "$4" > "$work/log" 2>&1 \
    || { cat "$work/log" >&2; die "applying $4 to $2.$3 failed"; }
}
hash_of() { jq -r --arg t "$2.$3.spend" '.validators[] | select(.title == $t) | .hash' "$1"; }
code_of() { jq -r --arg t "$2.$3.spend" '.validators[] | select(.title == $t) | .compiledCode' "$1"; }
address_of() { aiken blueprint address -i "$1" -m "$2" -v "$3" ${mainnet_flag[@]+"${mainnet_flag[@]}"}; }

apply plutus.json root_factory root_factory "$(cbor_bytes "$admin")" "$work/root.json"
root_hash=$(hash_of "$work/root.json" root_factory root_factory)

apply plutus.json seller_factory seller_factory "$(cbor_bytes "$root_hash")" "$work/seller.json"
seller_hash=$(hash_of "$work/seller.json" seller_factory seller_factory)

apply plutus.json instance service_instance "$(cbor_bytes "$token_policy")" "$work/i1.json"
apply "$work/i1.json" instance service_instance "$(cbor_bytes "$token_name")" "$work/i2.json"
apply "$work/i2.json" instance service_instance "$(cbor_bytes "$seller_hash")" "$work/instance.json"

config=$(jq -n \
  --arg chainId "cardano:$network" \
  --arg rootCode "$(code_of "$work/root.json" root_factory root_factory)" \
  --arg rootAddr "$(address_of "$work/root.json" root_factory root_factory)" \
  --arg admin "$admin" \
  --arg sellerCode "$(code_of "$work/seller.json" seller_factory seller_factory)" \
  --arg sellerAddr "$(address_of "$work/seller.json" seller_factory seller_factory)" \
  --arg instanceCode "$(code_of "$work/instance.json" instance service_instance)" \
  --arg instanceAddr "$(address_of "$work/instance.json" instance service_instance)" \
  --arg tokenPolicy "$token_policy" \
  --arg tokenName "$token_name" \
  '{
    chainId: $chainId,
    rootFactory: { compiledCodeHex: $rootCode, scriptAddress: $rootAddr, bcaAdminPkh: $admin },
    sellerFactory: { compiledCodeHex: $sellerCode, scriptAddress: $sellerAddr },
    instance: {
      compiledCodeHex: $instanceCode,
      scriptAddress: $instanceAddr,
      tokenPolicyId: $tokenPolicy,
      tokenAssetNameHex: $tokenName
    }
  }')

if [[ -n "$out" ]]; then
  printf '%s\n' "$config" > "$out"
  echo "wrote $out" >&2
else
  printf '%s\n' "$config"
fi
jq -r '"root_factory     \(.rootFactory.scriptAddress)\nseller_factory   \(.sellerFactory.scriptAddress)\nservice_instance \(.instance.scriptAddress)"' <<< "$config" >&2
