#!/usr/bin/env bash
# Creates the bridge client-username + scoped ACL profile on each of the 3
# remote Solace Cloud brokers (AWS, Azure, STACKIT/GCP-interim), via each
# broker's OWN SEMP v2 Config API -- i.e. the same kind of call that
# local-broker/semp/configure-local-broker.sh makes against the local broker,
# just pointed at a remote host each time.
#
# IMPORTANT -- this is a DIFFERENT API from cloud-setup/solace-cloud-api/create-service.sh:
#   - create-service.sh talks to the Solace Cloud MISSION CONTROL API
#     (api.solace.cloud), authenticated with the SOLACE_CLOUD_API_TOKEN
#     (token-dadd-2026.txt) -- it creates/manages the SERVICES themselves.
#   - THIS script talks to each broker's own SEMP v2 Config API directly
#     (its management/SEMP endpoint, typically <host>:943), authenticated
#     with that broker's own SEMP admin username/password -- it creates
#     OBJECTS INSIDE an existing broker (client-usernames, ACL profiles).
#   The Mission Control API token does NOT work as SEMP admin credentials,
#   and cannot be used to create client-usernames/ACL profiles -- these are
#   two separate authentication systems. Do not reuse solace-cloud-client
#   for this either (see docs/cloud-brokers.md, "Credentials").
#
# Get each broker's SEMP host:port and admin username/password from its
# Connect tab in the Solace Cloud console (SEMP/management section), and put
# them in local-broker/.env as AWS_SEMP_HOST / AWS_SEMP_ADMIN_USER /
# AWS_SEMP_ADMIN_PASSWORD (and the AZURE_*/STACKIT_* equivalents).
#
# Usage: ./configure-remote-bridge-users.sh
# Requires: curl, and a populated ../../local-broker/.env

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../local-broker/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy local-broker/.env.example to local-broker/.env and fill it in first."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

semp() {
  # semp SEMP_BASE METHOD PATH JSON_BODY AUTH_USER AUTH_PASS
  local semp_base="$1" method="$2" path="$3" body="$4" user="$5" pass="$6"
  local response
  response="$(curl -sS -X "${method}" -u "${user}:${pass}" -H "content-type: application/json" "${semp_base}${path}" -d "${body}")"
  if echo "${response}" | grep -q '"code"'; then
    if echo "${response}" | grep -q '"code": *6001'; then
      echo "    (already exists, skipping) ${path}"
    else
      echo "    WARN on ${method} ${path}:"
      echo "${response}"
    fi
  fi
}

configure_remote_bridge_user() {
  local label="$1" semp_host="$2" admin_user="$3" admin_pass="$4" \
        remote_vpn="$5" bridge_user="$6" bridge_pass="$7" topic="$8"

  if [[ "${semp_host}" == "CHANGEME_host:943" || -z "${admin_user}" || "${admin_user}" == "CHANGEME_semp_admin_username" ]]; then
    echo "== ${label}: SKIPPED -- ${label}_SEMP_HOST/${label}_SEMP_ADMIN_USER not filled in in local-broker/.env yet =="
    return
  fi

  # Accept the host with or without a scheme prefix (the Connect tab may show
  # it either way) -- strip any existing http(s):// before rebuilding the URL,
  # so a value like "https://mr-connection-...:943" doesn't get doubled up.
  semp_host="${semp_host#https://}"
  semp_host="${semp_host#http://}"
  local semp_base="https://${semp_host}/SEMP/v2/config"
  local acl="acl-enewable-local-bridge"

  echo "== ${label}: ${remote_vpn} @ ${semp_host} =="
  semp "${semp_base}" POST "/msgVpns/${remote_vpn}/aclProfiles" \
    "{\"aclProfileName\":\"${acl}\",\"clientConnectDefaultAction\":\"allow\",\"publishTopicDefaultAction\":\"disallow\",\"subscribeTopicDefaultAction\":\"disallow\"}" \
    "${admin_user}" "${admin_pass}"
  semp "${semp_base}" POST "/msgVpns/${remote_vpn}/aclProfiles/${acl}/publishTopicExceptions" \
    "{\"publishTopicExceptionSyntax\":\"smf\",\"publishTopicException\":\"${topic}\"}" \
    "${admin_user}" "${admin_pass}"
  semp "${semp_base}" POST "/msgVpns/${remote_vpn}/clientUsernames" \
    "{\"clientUsername\":\"${bridge_user}\",\"password\":\"${bridge_pass}\",\"enabled\":true,\"aclProfileName\":\"${acl}\",\"clientProfileName\":\"default\"}" \
    "${admin_user}" "${admin_pass}"
  echo "  ${bridge_user} -> may only publish on ${topic}"
}

configure_remote_bridge_user "AWS"     "${AWS_SEMP_HOST:-}"     "${AWS_SEMP_ADMIN_USER:-}"     "${AWS_SEMP_ADMIN_PASSWORD:-}"     "${AWS_REMOTE_VPN}"     "${AWS_BRIDGE_USER}"     "${AWS_BRIDGE_PASSWORD}"     "enewable/public/>"
configure_remote_bridge_user "AZURE"   "${AZURE_SEMP_HOST:-}"   "${AZURE_SEMP_ADMIN_USER:-}"   "${AZURE_SEMP_ADMIN_PASSWORD:-}"   "${AZURE_REMOTE_VPN}"   "${AZURE_BRIDGE_USER}"   "${AZURE_BRIDGE_PASSWORD}"   "enewable/eu/ops/>"
configure_remote_bridge_user "STACKIT" "${STACKIT_SEMP_HOST:-}" "${STACKIT_SEMP_ADMIN_USER:-}" "${STACKIT_SEMP_ADMIN_PASSWORD:-}" "${STACKIT_REMOTE_VPN}" "${STACKIT_BRIDGE_USER}" "${STACKIT_BRIDGE_PASSWORD}" "enewable/eu/pii/>"

cat <<INFO

Klaar (of overgeslagen waar SEMP-admin-gegevens nog ontbraken -- zie boven).
Controleer per service in de Solace Cloud console onder Manage > Client
Usernames dat 'enewable-local-bridge' bestaat en enabled is, en onder Manage
> ACL Profiles dat 'acl-enewable-local-bridge' alleen publiceren toestaat op
de juiste topic-subtree. Daarna: local-broker/semp/configure-local-broker.sh
draaien om de lokale broker + bridges op te zetten.
INFO
