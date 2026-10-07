#!/usr/bin/env bash
# Checks (and, if needed, enables) the REST-incoming service on each of the
# 3 cloud brokers' Message VPN, via each broker's OWN SEMP v2 Config API --
# same pattern as configure-remote-bridge-users.sh (mission-control-manager
# SEMP-admin credentials from local-broker/.env, NOT the Mission Control
# API/token).
#
# WHY THIS SCRIPT EXISTS (diagnosis, 28/09/2026): local-broker/semp/
# diagnose-rdp.sh showed each REST consumer's underlying TLS+http-basic
# connection is genuinely healthy (monitor "up": true,
# remoteOutgoingConnectionUpCount == outgoingConnectionCount for all 3),
# but the queue-binding itself fails with monitor
# "lastFailureReason": "Service Unavailable" (HTTP 503) -- the connection
# succeeds, but the cloud broker rejects the actual POST. The leading
# theory (see local-broker/.env.example's long-standing warning that REST
# is "not always enabled by default like SMF/Web-messaging"): the target
# Message VPN's REST-incoming service is simply switched off.
#
# RESULT (Emil, 28/09/2026): on Azure, serviceRestIncomingTlsEnabled was
# already "true" BEFORE this script's PATCH ran -- so this was NOT the
# cause there, and is unlikely to be the cause on AWS/STACKIT either
# (provisioned the same way). A direct curl POST to all 3 cloud brokers
# (see test-rest-direct.sh) got HTTP 200 OK from all 3 -- REST-incoming,
# auth and topic/path construction all check out independently of the
# RDP. The 503 is therefore NOT explained by this script; see PLAN.md
# section 13, item 18 for the current theory (the RDP's queue-binding
# counters show zero real POST attempts ever, so "Service Unavailable"
# is most likely from some RDP-internal readiness/probe step, not a
# failed real-message delivery -- next step is an actual end-to-end
# publish test, see demo-apps/stm-public/publish-public.sh).
#
# This script is still useful to keep around (idempotent, harmless to
# re-run) -- run it again any time REST-incoming state needs rechecking.
#
# This script must be run by Emil, not the assistant: this session's
# network cannot reach any *_SEMP_HOST (mr-connection-*.messaging.
# solace.cloud:943) -- confirmed blocked earlier, see PLAN.md section 13.
#
# Usage: ./enable-rest-on-cloud-vpns.sh
# Requires: curl, and a populated ../../local-broker/.env
#
# Output goes to <repo-root>/output/enable-rest-on-cloud-vpns.txt
# (gitignored, same convention as local-broker/semp/diagnose-rdp.sh --
# SEMP responses can echo back hostnames/usernames from .env), AND is
# still printed to the console as before.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../local-broker/.env"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_FILE="${OUT_DIR}/enable-rest-on-cloud-vpns.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${OUT_DIR}"

pp() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool 2>/dev/null || cat
  else
    cat
  fi
}

check_and_enable() {
  local label="$1" semp_host="$2" admin_user="$3" admin_pass="$4" vpn="$5"
  local host_clean="${semp_host#https://}"
  host_clean="${host_clean#http://}"
  local semp="https://${host_clean}/SEMP/v2/config"
  local auth=(-u "${admin_user}:${admin_pass}")

  echo "== ${label} (VPN '${vpn}') =="
  echo "-- current state --"
  curl -sS "${auth[@]}" \
    "${semp}/msgVpns/${vpn}?select=serviceRestIncomingPlainTextEnabled,serviceRestIncomingTlsEnabled" \
    | pp

  echo "-- enabling serviceRestIncomingTlsEnabled (the RDP uses TLS on 9443) --"
  curl -sS -X PATCH "${auth[@]}" -H "content-type: application/json" \
    -d '{"serviceRestIncomingTlsEnabled":true}' \
    "${semp}/msgVpns/${vpn}" | pp
  echo
}

{
  check_and_enable "AWS US East"          "${AWS_SEMP_HOST}"     "${AWS_SEMP_ADMIN_USER}"     "${AWS_SEMP_ADMIN_PASSWORD}"     "${AWS_REMOTE_VPN}"
  check_and_enable "Azure West Europe"    "${AZURE_SEMP_HOST}"   "${AZURE_SEMP_ADMIN_USER}"   "${AZURE_SEMP_ADMIN_PASSWORD}"   "${AZURE_REMOTE_VPN}"
  check_and_enable "STACKIT eu01"         "${STACKIT_SEMP_HOST}" "${STACKIT_SEMP_ADMIN_USER}" "${STACKIT_SEMP_ADMIN_PASSWORD}" "${STACKIT_REMOTE_VPN}"
} | tee "${OUT_FILE}"

cat <<INFO

Klaar. Output ook geschreven naar: ${OUT_FILE}
INFO
