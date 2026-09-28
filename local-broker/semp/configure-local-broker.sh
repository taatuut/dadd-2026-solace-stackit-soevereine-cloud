#!/usr/bin/env bash
# Configures the local Solace broker for the Enewable DADD 2026 demo via SEMP v2:
#   - Message VPN "enewable" (+ web-messaging / SMF services enabled)
#   - 3 scoped publisher client-usernames (public / eu-ops / eu-pii), each
#     restricted by an ACL profile to its own topic subtree
#   - 3 bridges (local -> AWS, local -> Azure, local -> STACKIT), each with a
#     remoteSubscription that exports exactly one topic subtree
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
    if echo "${response}" | grep -q '"code": *6001'; then
      echo "  (already exists, skipping) ${path}"
    else
      echo "  WARN on ${method} ${path}:"
      echo "${response}"
    fi
  fi
}

echo "== 1. Message VPN '${VPN}' =="
semp POST "/msgVpns" "{\"msgVpnName\":\"${VPN}\",\"enabled\":true,\"maxMsgSpoolUsage\":1500}"
semp PATCH "/msgVpns/${VPN}" '{"serviceSmfPlainTextEnabled":true,"serviceWebPlainTextEnabled":true,"serviceRestIncomingPlainTextEnabled":true}'

echo "== 2. Scoped publisher client-usernames + ACL profiles =="
declare -A TOPIC_FOR=(
  [pub-public]="enewable/public/>"
  [pub-eu-ops]="enewable/eu/ops/>"
  [pub-eu-pii]="enewable/eu/pii/>"
)
declare -A PASSWORD_FOR=(
  [pub-public]="${PUB_PUBLIC_PASSWORD:-pub-public-pw}"
  [pub-eu-ops]="${PUB_EU_OPS_PASSWORD:-pub-eu-ops-pw}"
  [pub-eu-pii]="${PUB_EU_PII_PASSWORD:-pub-eu-pii-pw}"
)

for user in "${!TOPIC_FOR[@]}"; do
  acl="acl-${user}"
  topic="${TOPIC_FOR[$user]}"
  pass="${PASSWORD_FOR[$user]}"

  semp POST "/msgVpns/${VPN}/aclProfiles" \
    "{\"aclProfileName\":\"${acl}\",\"clientConnectDefaultAction\":\"allow\",\"publishTopicDefaultAction\":\"disallow\",\"subscribeTopicDefaultAction\":\"disallow\"}"
  semp POST "/msgVpns/${VPN}/aclProfiles/${acl}/publishTopicExceptions" \
    "{\"publishTopicExceptionSyntax\":\"smf\",\"publishTopicException\":\"${topic}\"}"
  semp POST "/msgVpns/${VPN}/clientUsernames" \
    "{\"clientUsername\":\"${user}\",\"password\":\"${pass}\",\"enabled\":true,\"aclProfileName\":\"${acl}\",\"clientProfileName\":\"default\"}"
  echo "  ${user} -> may only publish on ${topic}"
done

echo "== 3. Bridges to the 3 cloud brokers =="

create_bridge() {
  local name="$1" remote_vpn="$2" remote_host="$3" remote_user="$4" remote_pass="$5" export_topic="$6"

  semp POST "/msgVpns/${VPN}/bridges" \
    "{\"bridgeName\":\"${name}\",\"enabled\":true,\"remoteConnectionRetryCount\":10,\"remoteConnectionRetryDelay\":3}"

  semp POST "/msgVpns/${VPN}/bridges/${name}/remoteMsgVpns" \
    "{\"remoteMsgVpnName\":\"${remote_vpn}\",\"remoteMsgVpnLocation\":\"${remote_host}\",\"remoteMsgVpnInterface\":\"\",\"remoteAuthenticationScheme\":\"basic\",\"remoteAuthenticationBasicClientUsername\":\"${remote_user}\",\"remoteAuthenticationBasicPassword\":\"${remote_pass}\",\"tlsEnabled\":true,\"enabled\":true}"

  semp POST "/msgVpns/${VPN}/bridges/${name}/remoteSubscriptions" \
    "{\"remoteSubscriptionTopic\":\"${export_topic}\",\"deliverAlwaysEnabled\":true}"

  echo "  ${name}: exports '${export_topic}' -> vpn '${remote_vpn}' @ ${remote_host}"
}

create_bridge "bridge-to-aws"     "${AWS_REMOTE_VPN}"     "${AWS_REMOTE_SMF_HOST}"     "${AWS_BRIDGE_USER}"     "${AWS_BRIDGE_PASSWORD}"     "enewable/public/>"
create_bridge "bridge-to-azure"   "${AZURE_REMOTE_VPN}"   "${AZURE_REMOTE_SMF_HOST}"   "${AZURE_BRIDGE_USER}"   "${AZURE_BRIDGE_PASSWORD}"   "enewable/eu/ops/>"
# NOTE: STACKIT_* currently points at the interim GCP europe-west1 stand-in
# until STACKIT is GA in Solace Cloud -- see ../../cloud-setup/stackit-eu01/README.md
create_bridge "bridge-to-stackit" "${STACKIT_REMOTE_VPN}" "${STACKIT_REMOTE_SMF_HOST}" "${STACKIT_BRIDGE_USER}" "${STACKIT_BRIDGE_PASSWORD}" "enewable/eu/pii/>"

cat <<INFO

Klaar. Controleer nu in Broker Manager (http://localhost:8080 > VPN 'enewable'
> Bridges) dat alle 3 bridges 'Up' zijn. Als een bridge 'Down' blijft, is dat
vrijwel altijd een van: verkeerd remote host:port, TLS/CA-vertrouwen, of een
verkeerde remote client-username/password op de cloud-broker -- zie
docs/lokale-broker.md.
INFO
