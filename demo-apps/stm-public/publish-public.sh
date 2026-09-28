#!/usr/bin/env bash
# Publishes Enewable demo data to the local broker using the Solace Try-Me
# CLI (stm).
#
# By default this publishes ALL 3 data classes in one run -- public,
# non-personal EU, and sensitive PII -- one after another, each with its
# OWN scoped client-username (pub-public/pub-eu-ops/pub-eu-pii) and its own
# topic. This is deliberate: it demonstrates that the destination
# cloud-broker (AWS/Azure/STACKIT) is decided purely by TOPIC, via the
# RDP-export queues (see local-broker/semp/configure-rdp-export.sh), never
# by which TOOL published the message -- the same stm CLI that lands a
# message on AWS one second lands the next message on STACKIT, just by
# switching topic + credential. Use --class to restrict to a single class
# (e.g. for isolated testing). See PLAN.md section 13 for the reasoning
# behind this change (Emil's review of the original, one-class-per-app demo).
#
# NOTE (fixed 28/09/2026): the messaging subcommand in the installed stm
# CLI (v1.0.0) is "send", not "publish" -- "stm publish" fails with
# "error: unknown option '--url'" because there is no "publish" command at
# all in this version (the full command tree is send/receive/request/
# reply/config/manage/feed -- see the SolaceLabs/solace-tryme-cli README).
#
# NOTE (fixed 28/09/2026, 2nd bug): "stm send" defaults to
# --delivery-mode PERSISTENT (guaranteed), NOT direct. The local broker's
# "default" client-profile intentionally has
# allowGuaranteedMsgSendEnabled: false (this demo's whole design relies
# on DIRECT publish + automatic queue promotion, see PLAN.md/docs/
# lokale-broker.md), so every persistent publish attempt failed with
# "Sending guaranteed message is not allowed by router for this client"
# -- even though the connection itself succeeded. Fixed by adding
# --delivery-mode DIRECT explicitly.
#
# Topics are built dynamically from the payload file's own fields, not
# hardcoded -- e.g. "enewable/public/market/price/day-ahead-price/NL" (the
# last 2 levels come from the JSON's "type"/"market" fields). This still
# lands correctly: the RDP-export queues and the pub-*-usernames' ACL
# exceptions all subscribe/publish on the "enewable/<class>/>" SUBTREE
# (see local-broker/semp/configure-local-broker.sh and
# configure-rdp-export.sh), so extra topic levels below the existing base
# topic are automatically included -- no broker reconfiguration needed.
# Uses jq if available (see README.md, "Vereisten"), else a plain
# grep/sed fallback for these flat, single-level JSON files.
#
# The "public" class additionally VARIES "type" and "market" per message
# (TYPES_PUBLIC/MARKETS_PUBLIC below, picked at random per message) --
# public.json is only the base template; render_payload() overrides those
# 2 fields per message before publishing. This means "public" publishes
# COUNT separate messages one at a time (COUNT stm invocations), instead
# of one "stm send --count N" batch call like eu-ops/eu-pii still do --
# noticeably slower per message (Node process startup each time), but
# needed to get real variety per message rather than repeating one fixed
# combination. Lower COUNT (e.g. "5") for a quicker pass if demo time is
# tight; eu-ops/eu-pii are unaffected and stay fast/batched.
#
# Usage: ./publish-public.sh [--class public|eu-ops|eu-pii] [COUNT]
#   --class   Restrict to a single data class (default: all 3, in order:
#             public, eu-ops, eu-pii).
#   COUNT     Messages per class (default: 10).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SCRIPT_DIR}/../sample-payloads"
# shellcheck disable=SC1090
[[ -f "${SCRIPT_DIR}/../../local-broker/.env" ]] && source "${SCRIPT_DIR}/../../local-broker/.env"

: "${LOCAL_WEB_MESSAGING_URL:=ws://localhost:8008}"
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

# 3 realistic electricity-market price types and the 5 markets Emil asked
# for -- deliberately small, fixed lists (not exhaustive) so a short demo
# run visibly cycles through more than one value of each.
TYPES_PUBLIC=(day-ahead-price intraday-price imbalance-price)
MARKETS_PUBLIC=(NL BE LU DE FR)

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
COUNT=10

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
  stm send \
    --url "${LOCAL_WEB_MESSAGING_URL}" \
    --vpn "${LOCAL_MSG_VPN}" \
    --username "${user}" --password "${pass}" \
    --topic "${topic}" \
    --file "${file}" \
    --delivery-mode DIRECT \
    --count "${count}" --interval 1000
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
  local file="${PAYLOAD_DIR}/eu-ops.json" type postcode_area
  type="$(json_field "${file}" type)"; : "${type:=unknown}"
  postcode_area="$(json_field "${file}" postcodeArea)"; : "${postcode_area:=unknown}"
  publish_class "eu-ops" "enewable/eu/ops/grid/load/${type}/${postcode_area}" "${PUB_EU_OPS_USER}" "${PUB_EU_OPS_PASSWORD}" "${file}" "${COUNT}"
}
run_eu_pii() {
  local file="${PAYLOAD_DIR}/eu-pii.json" customer_id
  customer_id="$(json_field "${file}" customerId)"; : "${customer_id:=unknown}"
  publish_class "eu-pii" "enewable/eu/pii/meter/reading/${customer_id}" "${PUB_EU_PII_USER}" "${PUB_EU_PII_PASSWORD}" "${file}" "${COUNT}"
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
