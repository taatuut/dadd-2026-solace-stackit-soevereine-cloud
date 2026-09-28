#!/usr/bin/env bash
# Read-only diagnostic: dumps the local broker's SEMP v2 CONFIG and MONITOR
# views of the 3 bridges, to find WHY they are Down even though
# configure-local-broker.sh now applies with zero WARN lines.
#
# The Broker Manager "Down" badge does not show a reason. The SEMP v2
# MONITOR API objects for a bridge's remoteMsgVpns/remoteSubscriptions
# carry the actual last-connection-failure detail (auth rejected, TLS
# handshake failed, timeout, etc.) -- this script fetches those raw so we
# can read the exact field/value instead of guessing.
#
# Usage: ./diagnose-bridges.sh
# Requires: curl, and a populated ../.env (same file configure-local-broker.sh uses)
# Makes NO changes -- GET requests only.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

CONFIG="${LOCAL_SEMP_HOST}/SEMP/v2/config"
MONITOR="${LOCAL_SEMP_HOST}/SEMP/v2/monitor"
AUTH=(-u "${LOCAL_SEMP_USER}:${LOCAL_SEMP_PASSWORD}")
VPN="${LOCAL_MSG_VPN}"

pp() {
  # Pretty-print JSON if python3 is available, otherwise dump raw.
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

for entry in "bridge-to-aws" "bridge-to-azure" "bridge-to-stackit"; do
  vr="auto"
  echo "======================================================"
  echo "  ${entry}"
  echo "======================================================"
  get "${CONFIG}"  "/msgVpns/${VPN}/bridges/${entry},${vr}"
  get "${CONFIG}"  "/msgVpns/${VPN}/bridges/${entry},${vr}/remoteMsgVpns"
  get "${CONFIG}"  "/msgVpns/${VPN}/bridges/${entry},${vr}/tlsOptions"
  get "${MONITOR}" "/msgVpns/${VPN}/bridges/${entry},${vr}"
  get "${MONITOR}" "/msgVpns/${VPN}/bridges/${entry},${vr}/remoteMsgVpns"
  echo
done

echo "Klaar. Plak de volledige output terug -- met name de MONITOR secties"
echo "bevatten normaal gesproken het echte down-reden veld (bv. authentication"
echo "failure, TLS handshake failure, connect timeout)."
