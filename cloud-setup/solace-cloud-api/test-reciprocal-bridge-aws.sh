#!/usr/bin/env bash
# EXPERIMENT (AWS only, for now) -- tests whether a reciprocal bridge on the
# AWS cloud broker can attach to the connection our EXISTING "bridge-to-aws"
# already has open, using the "v:<router-name>" addressing form, instead of
# AWS having to dial a NEW connection back to our local broker (which would
# require the local broker to be reachable from the public internet).
#
# Background (see PLAN.md section 13 and docs/lokale-broker.md, "Open
# architectuurpunt"): a Solace bridge's remoteSubscription only ever PULLS
# messages from whichever VPN it points at as "remote". Our local broker's
# bridges pull FROM the cloud brokers; to get local publishes EXPORTED to a
# cloud broker, that cloud broker needs its OWN bridge pulling FROM
# "enewable". Normally that means the cloud broker dials OUT to us, which
# needs us to be publicly reachable. BUT Solace's docs describe a
# "bi-directional bridge" mode where one side connects by IP/FQDN (already
# true for our existing bridge-to-aws) and the OTHER side is configured
# using the peer's *virtual router name* (form "v:<name>") instead of an
# address, and "discovers the existing connection" rather than dialing a new
# one. This script creates that second bridge, on AWS, using
# "v:${LOCAL_ROUTER_NAME}" -- to find out empirically whether that theory
# holds for a plain Message VPN bridge (not confirmed in Solace's public
# docs beyond the one sentence quoted above -- this is a genuine test, not
# a guaranteed fix).
#
# What to check afterwards:
#   - AWS's own Broker Manager (via the Solace Cloud console for the AWS
#     service) > Bridges > "bridge-from-enewable": if it comes Up and shows
#     the local broker's remote Message VPN, the router-name-discovery
#     theory holds -- no public reachability needed for the local broker.
#   - If it stays Down / errors on connect, AWS is trying (and failing) to
#     dial OUT to "v:${LOCAL_ROUTER_NAME}" as if it were a resolvable
#     address, which would mean this needs a DMR cluster (or does not work
#     for a plain VPN bridge at all) -- fall back to the reachability
#     options (tunnel / port-forward / cloud VM) or the local-relay-app
#     alternative discussed in PLAN.md.
#
# Usage: ./test-reciprocal-bridge-aws.sh
# Requires: curl, and a populated ../../local-broker/.env (needs
# AWS_SEMP_HOST/AWS_SEMP_ADMIN_USER/AWS_SEMP_ADMIN_PASSWORD, AWS_REMOTE_VPN,
# LOCAL_ROUTER_NAME, SUB_AWS_USER/SUB_AWS_PASSWORD -- run
# local-broker/semp/configure-local-broker.sh first so SUB_AWS_USER exists
# on the local broker).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../local-broker/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ -z "${LOCAL_ROUTER_NAME:-}" || "${LOCAL_ROUTER_NAME}" == CHANGEME_* ]]; then
  echo "LOCAL_ROUTER_NAME is not set in local-broker/.env -- get it with:"
  echo "  curl -u admin:admin -H \"Content-Type: application/xml\" -d '<rpc><show><router-name></router-name></show></rpc>' http://localhost:8080/SEMP"
  exit 1
fi

AWS_SEMP_HOST_CLEAN="${AWS_SEMP_HOST#https://}"
AWS_SEMP_HOST_CLEAN="${AWS_SEMP_HOST_CLEAN#http://}"
SEMP="https://${AWS_SEMP_HOST_CLEAN}/SEMP/v2/config"
AUTH=(-u "${AWS_SEMP_ADMIN_USER}:${AWS_SEMP_ADMIN_PASSWORD}")
VPN="${AWS_REMOTE_VPN}"
NAME="bridge-from-enewable"
VR="auto"

semp() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "${method}" "${AUTH[@]}" -H "content-type: application/json" "${SEMP}${path}")
  if [[ -n "${body}" ]]; then
    args+=(-d "${body}")
  fi
  local response
  response="$(curl "${args[@]}")"
  if echo "${response}" | grep -q '"code"'; then
    if echo "${response}" | grep -q '"code": *6001' || echo "${response}" | grep -q '"status": *"ALREADY_EXISTS"'; then
      echo "  (already exists, skipping) ${path}"
    else
      echo "  WARN on ${method} ${path}:"
      echo "${response}"
    fi
  fi
}

echo "== Creating reciprocal bridge '${NAME}' on AWS (VPN '${VPN}'), pointing at v:${LOCAL_ROUTER_NAME} =="

semp POST "/msgVpns/${VPN}/bridges" \
  "{\"bridgeName\":\"${NAME}\",\"bridgeVirtualRouter\":\"${VR}\",\"enabled\":true,\"remoteConnectionRetryCount\":10,\"remoteConnectionRetryDelay\":3}"

semp PATCH "/msgVpns/${VPN}/bridges/${NAME},${VR}" \
  "{\"remoteAuthenticationScheme\":\"basic\",\"remoteAuthenticationBasicClientUsername\":\"${SUB_AWS_USER}\",\"remoteAuthenticationBasicPassword\":\"${SUB_AWS_PASSWORD}\"}"

semp POST "/msgVpns/${VPN}/bridges/${NAME},${VR}/remoteMsgVpns" \
  "{\"remoteMsgVpnName\":\"${LOCAL_MSG_VPN}\",\"remoteMsgVpnLocation\":\"v:${LOCAL_ROUTER_NAME}\",\"remoteMsgVpnInterface\":\"\",\"tlsEnabled\":true,\"enabled\":true}"

semp POST "/msgVpns/${VPN}/bridges/${NAME},${VR}/remoteSubscriptions" \
  "{\"remoteSubscriptionTopic\":\"enewable/public/>\",\"deliverAlwaysEnabled\":true}"

cat <<INFO

Klaar. Check nu in de Solace Cloud console voor de AWS-service (niet
localhost!) > Bridges > '${NAME}': is die Up of Down? Check ook of onze
LOKALE 'bridge-to-aws' bridge van status/vorm veranderd is (bv. naar
bi-directional). Plak beide statussen terug.
INFO
