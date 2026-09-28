#!/usr/bin/env bash
# Read-only diagnostic: dumps SEMP v2 CONFIG + MONITOR views of the 3 REST
# Delivery Points, their REST consumers, and their bound queues -- to find
# WHY all 3 RDPs show "Down" in Broker Manager even though
# configure-rdp-export.sh now reports 0 WARN.
#
# Broker Manager itself gives no down-reason for an RDP, same situation as
# we hit earlier with the (now removed) bridges -- see PLAN.md section 13,
# item 6/7. The SEMP v2 MONITOR API carries the actual connection-failure
# detail (TLS handshake failure, auth rejected, connect timeout, etc.).
#
# Usage: ./diagnose-rdp.sh
# Requires: curl, and a populated ../.env
# Makes NO changes -- GET requests only.
#
# Output goes to <repo-root>/output/diagnose-rdp.txt (gitignored, same as
# the earlier diagnose-bridges.sh convention -- SEMP responses can echo
# back hostnames/usernames from .env).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_FILE="${OUT_DIR}/diagnose-rdp.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${OUT_DIR}"

CONFIG="${LOCAL_SEMP_HOST}/SEMP/v2/config"
MONITOR="${LOCAL_SEMP_HOST}/SEMP/v2/monitor"
AUTH=(-u "${LOCAL_SEMP_USER}:${LOCAL_SEMP_PASSWORD}")
VPN="${LOCAL_MSG_VPN}"

pp() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool 2>/dev/null || cat
  else
    cat
  fi
}

get() {
  local base="$1" path="$2"
  echo "---- GET ${path} ----"
  curl -sS "${AUTH[@]}" "${base}${path}" | pp
  echo
}

{
  echo "diagnose-rdp.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  for entry in "rdp-aws:consumer-aws:q-export-public" "rdp-azure:consumer-azure:q-export-eu-ops" "rdp-stackit:consumer-stackit:q-export-eu-pii"; do
    IFS=":" read -r rdp consumer queue <<< "${entry}"
    echo "======================================================"
    echo "  ${rdp} / ${consumer} / ${queue}"
    echo "======================================================"
    get "${CONFIG}"  "/msgVpns/${VPN}/restDeliveryPoints/${rdp}"
    get "${CONFIG}"  "/msgVpns/${VPN}/restDeliveryPoints/${rdp}/restConsumers/${consumer}"
    get "${MONITOR}" "/msgVpns/${VPN}/restDeliveryPoints/${rdp}"
    get "${MONITOR}" "/msgVpns/${VPN}/restDeliveryPoints/${rdp}/restConsumers/${consumer}"
    get "${MONITOR}" "/msgVpns/${VPN}/queues/${queue}"
    echo
  done
} > "${OUT_FILE}"

echo "Klaar. Output geschreven naar: ${OUT_FILE}"
echo "Voeg dit bestand toe -- de MONITOR-secties (vooral onder"
echo "restConsumers) bevatten normaal gesproken het echte down-reden-veld."
