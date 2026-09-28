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
  local class="$1" topic="$2" user="$3" pass="$4" file="$5"
  echo "-- ${class}: ${topic} (as ${user}) --"
  stm send \
    --url "${LOCAL_WEB_MESSAGING_URL}" \
    --vpn "${LOCAL_MSG_VPN}" \
    --username "${user}" --password "${pass}" \
    --topic "${topic}" \
    --file "${file}" \
    --delivery-mode DIRECT \
    --count "${COUNT}" --interval 1000
}

run_public() { publish_class "public" "enewable/public/market/price" "${PUB_PUBLIC_USER}" "${PUB_PUBLIC_PASSWORD}" "${PAYLOAD_DIR}/public.json"; }
run_eu_ops() { publish_class "eu-ops" "enewable/eu/ops/grid/load" "${PUB_EU_OPS_USER}" "${PUB_EU_OPS_PASSWORD}" "${PAYLOAD_DIR}/eu-ops.json"; }
run_eu_pii() { publish_class "eu-pii" "enewable/eu/pii/meter/reading" "${PUB_EU_PII_USER}" "${PUB_EU_PII_PASSWORD}" "${PAYLOAD_DIR}/eu-pii.json"; }

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
