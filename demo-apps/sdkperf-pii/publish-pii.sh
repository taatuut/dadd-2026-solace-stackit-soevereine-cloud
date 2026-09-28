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
  local class="$1" topic="$2" user="$3" pass="$4" file="$5"
  echo "-- ${class}: ${topic} (as ${user}) --"
  "${SDKPERF_BIN}" \
    -cip="${LOCAL_SMF_HOST}" \
    -cu="${user}@${LOCAL_MSG_VPN}" \
    -cp="${pass}" \
    -ptl="${topic}" \
    -pal="${file}" \
    -mt=direct -mn="${COUNT}" -mr=2 -md
}

run_public() {
  local file="${PAYLOAD_DIR}/public.json" type market
  type="$(json_field "${file}" type)"; : "${type:=unknown}"
  market="$(json_field "${file}" market)"; : "${market:=unknown}"
  publish_class "public" "enewable/public/market/price/${type}/${market}" "${PUB_PUBLIC_USER}" "${PUB_PUBLIC_PASSWORD}" "${file}"
}
run_eu_ops() {
  local file="${PAYLOAD_DIR}/eu-ops.json" type postcode_area
  type="$(json_field "${file}" type)"; : "${type:=unknown}"
  postcode_area="$(json_field "${file}" postcodeArea)"; : "${postcode_area:=unknown}"
  publish_class "eu-ops" "enewable/eu/ops/grid/load/${type}/${postcode_area}" "${PUB_EU_OPS_USER}" "${PUB_EU_OPS_PASSWORD}" "${file}"
}
run_eu_pii() {
  local file="${PAYLOAD_DIR}/eu-pii.json" customer_id
  customer_id="$(json_field "${file}" customerId)"; : "${customer_id:=unknown}"
  publish_class "eu-pii" "enewable/eu/pii/meter/reading/${customer_id}" "${PUB_EU_PII_USER}" "${PUB_EU_PII_PASSWORD}" "${file}"
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
