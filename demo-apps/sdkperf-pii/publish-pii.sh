#!/usr/bin/env bash
# Publishes Enewable demo data to the local broker using SDKPerf.
#
# By default this publishes ALL 3 data classes in one run -- public,
# non-personal EU, and sensitive PII -- one after another, each with its
# OWN scoped client-username (pub-public/pub-eu-ops/pub-eu-pii) and its own
# topic. This is deliberate: it demonstrates that the destination
# cloud-broker (AWS/Azure/STACKIT) is decided purely by TOPIC, via the
# RDP-export queues (see local-broker/semp/configure-rdp-export.sh), never
# by which TOOL published the message -- SDKPerf lands a message on
# STACKIT the same way stm/python do, just by switching topic + credential.
# Use --class to restrict to a single class (e.g. for isolated testing).
# See PLAN.md section 13 for the reasoning behind this change (Emil's
# review of the original, one-class-per-app demo).
#
# Message content: sends the class-appropriate JSON from
# ../sample-payloads/<class>.json as the raw binary attachment, via
# SDKPerf's "-pal" (payload-attachment-list) flag -- NOT "-mf", which
# doesn't exist ("Unrecognized option: -mf", confirmed by Emil,
# 28/09/2026, against a real SDKPerf 8.4.17.5 install). "-pal=<file>"
# sends the file's raw UTF-8 content as the message's binary attachment,
# same as "-msa" would auto-generate but with real content instead of
# filler bytes. See PLAN.md section 13 for how "-mf" was found (community
# thread on SDKPerf's "-sdm"/"-pal" flags).
#
# Assumes sdkperf_java.sh is on PATH -- override with SDKPERF_BIN if not.
#
# Topics are built dynamically from the payload file's own fields, not
# hardcoded -- e.g. "enewable/eu/pii/meter/reading/ENW-NL-000482" (the
# last level comes from the JSON's "customerId" field). This still lands
# correctly: the RDP-export queues and the pub-*-usernames' ACL exceptions
# all subscribe/publish on the "enewable/<class>/>" SUBTREE (see
# local-broker/semp/configure-local-broker.sh and configure-rdp-export.sh),
# so extra topic levels below the existing base topic are automatically
# included -- no broker reconfiguration needed. Uses jq if available (see
# README.md, "Vereisten"), else a plain grep/sed fallback for these flat,
# single-level JSON files.
#
# All 3 classes VARY one or more topic fields per message, picked at
# random from a small fixed list each (below): public -> "type"+"market"
# (TYPES_PUBLIC/MARKETS_PUBLIC), eu-ops -> "postcodeArea"
# (POSTCODE_AREAS_EU_OPS), eu-pii -> "customerId" (CUSTOMER_IDS_EU_PII).
# The sample-payloads/*.json files are only the base template;
# render_payload() overrides the relevant field(s) per message before
# publishing. This means EVERY class now publishes COUNT separate
# messages one at a time (COUNT sdkperf_java.sh invocations per class),
# instead of one "-mn=N" batch call -- noticeably slower than a single
# batch (JVM startup each time). Lower COUNT (e.g. "5") for a quicker pass
# if demo time is tight -- see docs/demo-apps.md, "Timing".
#
# Usage: ./publish-pii.sh [--class public|eu-ops|eu-pii] [COUNT]
#   --class   Restrict to a single data class (default: all 3, in order:
#             public, eu-ops, eu-pii).
#   COUNT     Messages per class (default: 20).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SCRIPT_DIR}/../sample-payloads"
# shellcheck disable=SC1090
[[ -f "${SCRIPT_DIR}/../../local-broker/.env" ]] && source "${SCRIPT_DIR}/../../local-broker/.env"

: "${SDKPERF_BIN:=sdkperf_java.sh}"
: "${LOCAL_SMF_HOST:=localhost:55554}"
: "${LOCAL_MSG_VPN:=enewable}"
: "${PUB_PUBLIC_USER:=pub-public}"
: "${PUB_PUBLIC_PASSWORD:?Set PUB_PUBLIC_PASSWORD (see local-broker/.env)}"
: "${PUB_EU_OPS_USER:=pub-eu-ops}"
: "${PUB_EU_OPS_PASSWORD:?Set PUB_EU_OPS_PASSWORD (see local-broker/.env)}"
: "${PUB_EU_PII_USER:=pub-eu-pii}"
: "${PUB_EU_PII_PASSWORD:?Set PUB_EU_PII_PASSWORD (see local-broker/.env)}"

json_field() {
  # json_field FILE KEY -- extract a top-level string field's value.
  # Prefers jq (see README.md, "Vereisten"); falls back to a plain
  # grep/sed pattern that works for these flat, single-level JSON files
  # (no nested objects/arrays) when jq isn't installed.
  local file="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".${key}" "${file}"
  else
    grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "${file}" \
      | sed -E 's/.*:[[:space:]]*"(.*)"/\1/'
  fi
}

# Deliberately small, fixed lists (not exhaustive) so a short demo run
# visibly cycles through more than one value of each. Kept identical to
# publisher.py's PRICE_TYPES/MARKETS/POSTCODE_AREAS/CUSTOMER_IDS so all 3
# tools show the same "known" set of values, whichever tool you run.
TYPES_PUBLIC=(day-ahead-price intraday-price imbalance-price)
MARKETS_PUBLIC=(NL BE LU DE FR)
POSTCODE_AREAS_EU_OPS=(1000-NL 2000-NL 3500-NL 4000-NL 5600-NL 6500-NL 7500-NL 8000-NL 9000-NL 9700-NL)
CUSTOMER_IDS_EU_PII=(
  ENW-NL-000482 ENW-NL-000917 ENW-NL-001188 ENW-NL-001654 ENW-NL-002203
  ENW-NL-002877 ENW-NL-003340 ENW-NL-003912 ENW-NL-004561 ENW-NL-005098
  ENW-NL-005734 ENW-NL-006220 ENW-NL-006803 ENW-NL-007415 ENW-NL-007960
  ENW-NL-008522 ENW-NL-009107 ENW-NL-009684 ENW-NL-010233 ENW-NL-010799
)

render_payload() {
  # render_payload BASE_FILE OUT_FILE KEY1 VAL1 [KEY2 VAL2 ...] -- copies
  # BASE_FILE to OUT_FILE with the given top-level string fields
  # overridden. Uses jq if available; otherwise a plain sed substitution
  # (these payload files are flat, one field per line, no nesting, so
  # this simple approach is safe here).
  local base="$1" out="$2"; shift 2
  if command -v jq >/dev/null 2>&1; then
    local args=() filter=""
    while [[ $# -gt 0 ]]; do
      args+=(--arg "$1" "$2")
      if [[ -z "${filter}" ]]; then filter=".$1 = \$$1"; else filter="${filter} | .$1 = \$$1"; fi
      shift 2
    done
    jq "${args[@]}" "${filter}" "${base}" > "${out}"
  else
    cp "${base}" "${out}"
    while [[ $# -gt 0 ]]; do
      sed -E "s/\"$1\"([[:space:]]*:[[:space:]]*)\"[^\"]*\"/\"$1\"\\1\"$2\"/" "${out}" > "${out}.tmp"
      mv "${out}.tmp" "${out}"
      shift 2
    done
  fi
}

CLASS_FILTER=""
COUNT=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --class)
      CLASS_FILTER="${2:?--class requires a value (public|eu-ops|eu-pii)}"
      shift 2
      ;;
    *)
      COUNT="$1"
      shift
      ;;
  esac
done

publish_class() {
  local class="$1" topic="$2" user="$3" pass="$4" file="$5" count="${6:-${COUNT}}"
  echo "-- ${class}: ${topic} (as ${user}) --"
  "${SDKPERF_BIN}" \
    -cip="${LOCAL_SMF_HOST}" \
    -cu="${user}@${LOCAL_MSG_VPN}" \
    -cp="${pass}" \
    -ptl="${topic}" \
    -pal="${file}" \
    -mt=direct -mn="${count}" -mr=2 -md
}

run_public() {
  local base="${PAYLOAD_DIR}/public.json"
  local tmp_file type market i
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/enewable-public.XXXXXX.json")" || return 1
  for (( i=0; i<COUNT; i++ )); do
    type="${TYPES_PUBLIC[$(( RANDOM % ${#TYPES_PUBLIC[@]} ))]}"
    market="${MARKETS_PUBLIC[$(( RANDOM % ${#MARKETS_PUBLIC[@]} ))]}"
    render_payload "${base}" "${tmp_file}" type "${type}" market "${market}"
    if ! publish_class "public" "enewable/public/market/price/${type}/${market}" "${PUB_PUBLIC_USER}" "${PUB_PUBLIC_PASSWORD}" "${tmp_file}" 1; then
      rm -f "${tmp_file}"
      return 1
    fi
  done
  rm -f "${tmp_file}"
}
run_eu_ops() {
  local base="${PAYLOAD_DIR}/eu-ops.json" type
  type="$(json_field "${base}" type)"; : "${type:=unknown}"
  local tmp_file postcode_area i
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/enewable-eu-ops.XXXXXX.json")" || return 1
  for (( i=0; i<COUNT; i++ )); do
    postcode_area="${POSTCODE_AREAS_EU_OPS[$(( RANDOM % ${#POSTCODE_AREAS_EU_OPS[@]} ))]}"
    render_payload "${base}" "${tmp_file}" postcodeArea "${postcode_area}"
    if ! publish_class "eu-ops" "enewable/eu/ops/grid/load/${type}/${postcode_area}" "${PUB_EU_OPS_USER}" "${PUB_EU_OPS_PASSWORD}" "${tmp_file}" 1; then
      rm -f "${tmp_file}"
      return 1
    fi
  done
  rm -f "${tmp_file}"
}
run_eu_pii() {
  local base="${PAYLOAD_DIR}/eu-pii.json"
  local tmp_file customer_id i
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/enewable-eu-pii.XXXXXX.json")" || return 1
  for (( i=0; i<COUNT; i++ )); do
    customer_id="${CUSTOMER_IDS_EU_PII[$(( RANDOM % ${#CUSTOMER_IDS_EU_PII[@]} ))]}"
    render_payload "${base}" "${tmp_file}" customerId "${customer_id}"
    if ! publish_class "eu-pii" "enewable/eu/pii/meter/reading/${customer_id}" "${PUB_EU_PII_USER}" "${PUB_EU_PII_PASSWORD}" "${tmp_file}" 1; then
      rm -f "${tmp_file}"
      return 1
    fi
  done
  rm -f "${tmp_file}"
}

# Each class is attempted independently -- one class failing (e.g. a wrong
# password for just that credential) does not abort the others, so a
# single run always at least TRIES all 3 destinations. Non-zero exit at
# the end if any class failed.
FAILED=0
try_class() {
  if ! "$1"; then
    echo "  WARN: klasse '$1' mislukt -- ga door met de volgende klasse." >&2
    FAILED=1
  fi
}

case "${CLASS_FILTER}" in
  ""|all)
    try_class run_public
    try_class run_eu_ops
    try_class run_eu_pii
    ;;
  public) try_class run_public ;;
  eu-ops) try_class run_eu_ops ;;
  eu-pii) try_class run_eu_pii ;;
  *)
    echo "Onbekende --class waarde: ${CLASS_FILTER} (verwacht: public, eu-ops of eu-pii)" >&2
    exit 1
    ;;
esac

exit "${FAILED}"
