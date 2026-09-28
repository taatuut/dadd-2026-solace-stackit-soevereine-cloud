#!/usr/bin/env bash
# Configures the local Solace broker for the Enewable DADD 2026 demo via SEMP v2:
#   - Message VPN "enewable" (+ web-messaging / SMF services enabled)
#   - 3 scoped publisher client-usernames (public / eu-ops / eu-pii), each
#     restricted by an ACL profile to its own topic subtree
#
# Run local-broker/semp/configure-rdp-export.sh AFTER this script to set up
# the actual export path (queues + REST Delivery Points) to the 3 cloud
# brokers. An earlier version of this script also created 3 Message VPN
# Bridges for export -- that approach was tried and abandoned (a bridge's
# remoteSubscription can only IMPORT from a remote broker, not export,
# without a reciprocal bridge on a publicly reachable local broker; see
# PLAN.md section 13 and docs/lokale-broker.md for the full investigation).
#
# This is a best-effort skeleton based on the SEMP v2 Config API reference
# (https://docs.solace.com/SEMP/SEMP-API-Ref.htm). Field names are correct as of
# the current software broker release at time of writing, but SEMP is
# versioned per broker release -- validate against your broker's own
# "SEMP API browser" (Broker Manager > About > API Browser) before relying on
# this live at DADD. See docs/lokale-broker.md, section "Bekende risico's".
#
# Usage: ./configure-local-broker.sh
# Requires: curl, jq (for readable error output), and a populated ../.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy local-broker/.env.example to local-broker/.env and fill it in first."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

SEMP="${LOCAL_SEMP_HOST}/SEMP/v2/config"
AUTH=(-u "${LOCAL_SEMP_USER}:${LOCAL_SEMP_PASSWORD}")
VPN="${LOCAL_MSG_VPN}"

semp() {
  # semp METHOD PATH [JSON_BODY]
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "${method}" "${AUTH[@]}" -H "content-type: application/json" "${SEMP}${path}")
  if [[ -n "${body}" ]]; then
    args+=(-d "${body}")
  fi
  local response
  response="$(curl "${args[@]}")"
  if echo "${response}" | grep -q '"code"'; then
    # SEMP returns a "meta.error" object on failure; treat anything with a top-level
    # "code" as a possible error and print it, but don't hard-fail on "already exists" (6001)
    if echo "${response}" | grep -q '"code": *6001' || echo "${response}" | grep -q '"status": *"ALREADY_EXISTS"'; then
      echo "  (already exists, skipping) ${path}"
    else
      echo "  WARN on ${method} ${path}:"
      echo "${response}"
    fi
  fi
}

echo "== 1. Message VPN '${VPN}' =="
semp POST "/msgVpns" "{\"msgVpnName\":\"${VPN}\",\"enabled\":true,\"maxMsgSpoolUsage\":1500}"
# REST is not used anywhere in this demo (stm uses web-messaging, the Python
# script and SDKPerf use SMF) -- only enable SMF + web-messaging. Enabling
# serviceRestIncomingPlainTextEnabled would additionally require a REST
# listen port to be configured first (SEMP error 89), which we'd otherwise
# have to wire up in docker-run.sh for no benefit.
semp PATCH "/msgVpns/${VPN}" '{"serviceSmfPlainTextEnabled":true,"serviceWebPlainTextEnabled":true}'

echo "== 2. Scoped publisher client-usernames + ACL profiles =="
# Deliberately NOT using bash associative arrays (declare -A) here: macOS
# ships bash 3.2 as /bin/bash (Apple has frozen it there for licensing
# reasons since El Capitan), which predates bash 4's associative-array
# support. Without -A, `[pub-public]=...` is parsed as an INDEXED array
# subscript and evaluated arithmetically, which fails hard under `set -u`
# ("pub: unbound variable"). Unrolled into 3 explicit calls instead, same
# style as the create_bridge() calls below.

create_scoped_publisher() {
  local user="$1" topic="$2" pass="$3"
  local acl="acl-${user}"

  semp POST "/msgVpns/${VPN}/aclProfiles" \
    "{\"aclProfileName\":\"${acl}\",\"clientConnectDefaultAction\":\"allow\",\"publishTopicDefaultAction\":\"disallow\",\"subscribeTopicDefaultAction\":\"disallow\"}"
  semp POST "/msgVpns/${VPN}/aclProfiles/${acl}/publishTopicExceptions" \
    "{\"publishTopicExceptionSyntax\":\"smf\",\"publishTopicException\":\"${topic}\"}"
  semp POST "/msgVpns/${VPN}/clientUsernames" \
    "{\"clientUsername\":\"${user}\",\"password\":\"${pass}\",\"enabled\":true,\"aclProfileName\":\"${acl}\",\"clientProfileName\":\"default\"}"
  echo "  ${user} -> may only publish on ${topic}"
}

create_scoped_publisher "pub-public"  "enewable/public/>"  "${PUB_PUBLIC_PASSWORD:-pub-public-pw}"
create_scoped_publisher "pub-eu-ops"  "enewable/eu/ops/>"   "${PUB_EU_OPS_PASSWORD:-pub-eu-ops-pw}"
create_scoped_publisher "pub-eu-pii"  "enewable/eu/pii/>"   "${PUB_EU_PII_PASSWORD:-pub-eu-pii-pw}"

cat <<INFO

Klaar. Volgende stap: local-broker/semp/configure-rdp-export.sh -- richt de
3 export-queues en REST Delivery Points in die daadwerkelijk naar de 3
cloud-brokers publiceren (zie docs/lokale-broker.md, "Definitieve keuze").
INFO
