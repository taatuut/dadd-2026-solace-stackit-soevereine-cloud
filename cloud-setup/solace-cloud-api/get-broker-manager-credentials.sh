#!/usr/bin/env bash
# Haalt de door Solace Cloud gegenereerde Broker Manager-admin (manager-rol)
# username/password op voor de 3 cloud broker-services (AWS, Azure,
# STACKIT) via de Mission Control REST API, en schrijft ze naar
# ../../output/broker-admin-credentials.json.
#
# Vereist een API-token per Solace Cloud-organisatie met de scope "Get My
# Services with Management Credentials" (of org-breed "Get Services with
# Management Credentials") aangevinkt -- zonder die scope geeft de API de
# service terug zonder messageVpn-credentials. Token aanmaken/bijwerken:
# Solace Cloud console > Mission Control > API Tokens. AWS+Azure staan in
# één organisatie, STACKIT in een andere, elk met een eigen token en
# eigen API-base-URL (zie ../terraform/README.md) -- vandaar de aparte
# AWS_AZURE_ORG_*/STACKIT_ORG_*-variabelen hieronder, i.p.v. de ene
# SOLACE_CLOUD_API_TOKEN die create-service.sh gebruikt.
#
# Responsvorm: de Mission Control API wikkelt elk antwoord in
# {"data": ..., "meta": ...} met camelCase-velden (geverifieerd tegen
# output/datacenters-aws-azure.json in deze repo). Het pad
# data.messageVpn.managerManagementCredential.{username,password} is
# afgeleid van het schema van de solacecloud Terraform-provider
# (message_vpn.manager_management_credential.{username,password}, zie
# https://registry.terraform.io/providers/SolaceProducts/solacecloud/latest/docs/resources/service),
# maar NIET zelf bevestigd tegen een live GET-respons vanuit deze sessie
# (netwerktoegang naar api.solace.cloud/het STACKIT-orgdomein is
# geblokkeerd vanuit deze sessie, zie ../../docs/cloud-brokers.md,
# "Netwerktoegang vanuit deze sessie"). Dit script schrijft daarom ook het
# volledige, rauwe antwoord per service weg, zodat je de jq-paden hieronder
# zelf kan verifiëren en corrigeren als de structuur afwijkt.
#
# Gebruik:
#   ./get-broker-manager-credentials.sh
#
# Vereist: curl, jq, en een ingevulde .env in deze map (zie .env.example).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
[[ -f "${SCRIPT_DIR}/.env" ]] && source "${SCRIPT_DIR}/.env"

command -v jq >/dev/null 2>&1 || { echo "jq is vereist voor dit script." >&2; exit 1; }

: "${AWS_AZURE_ORG_API_TOKEN:?Set AWS_AZURE_ORG_API_TOKEN (zie .env.example)}"
: "${AWS_AZURE_ORG_API_BASE:=https://api.solace.cloud/api/v2}"
: "${STACKIT_ORG_API_TOKEN:?Set STACKIT_ORG_API_TOKEN (zie .env.example)}"
: "${STACKIT_ORG_API_BASE:?Set STACKIT_ORG_API_BASE (zie .env.example -- afwijkend domein, zie ../terraform/README.md, punt over twee organisaties)}"

: "${AWS_SERVICE_ID:?Set AWS_SERVICE_ID (zie .env.example, of output/service-aws.json veld 'id')}"
: "${AZURE_SERVICE_ID:?Set AZURE_SERVICE_ID (idem)}"
: "${STACKIT_SERVICE_ID:?Set STACKIT_SERVICE_ID (idem)}"

OUTPUT_DIR="${SCRIPT_DIR}/../../output"
RAW_DIR="${OUTPUT_DIR}/broker-manager-credentials-raw"
mkdir -p "${RAW_DIR}"

fetch_service() {
  local base="$1" token="$2" service_id="$3" raw_file="$4"
  curl -sS "${base}/missionControl/eventBrokerServices/${service_id}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -o "${raw_file}"
}

fetch_service "${AWS_AZURE_ORG_API_BASE}" "${AWS_AZURE_ORG_API_TOKEN}" "${AWS_SERVICE_ID}" "${RAW_DIR}/aws.json"
fetch_service "${AWS_AZURE_ORG_API_BASE}" "${AWS_AZURE_ORG_API_TOKEN}" "${AZURE_SERVICE_ID}" "${RAW_DIR}/azure.json"
fetch_service "${STACKIT_ORG_API_BASE}" "${STACKIT_ORG_API_TOKEN}" "${STACKIT_SERVICE_ID}" "${RAW_DIR}/stackit.json"

extract() {
  local raw_file="$1"
  jq '{adminUsername: .data.messageVpn.managerManagementCredential.username,
       adminPassword: .data.messageVpn.managerManagementCredential.password}' \
    "${raw_file}"
}

jq -n \
  --argjson aws "$(extract "${RAW_DIR}/aws.json")" \
  --argjson azure "$(extract "${RAW_DIR}/azure.json")" \
  --argjson stackit "$(extract "${RAW_DIR}/stackit.json")" \
  '{aws: $aws, azure: $azure, stackit: $stackit}' \
  > "${OUTPUT_DIR}/broker-admin-credentials.json"

echo "Geschreven: ${OUTPUT_DIR}/broker-admin-credentials.json"
echo "Rauwe API-responses (voor verificatie van de jq-paden hierboven): ${RAW_DIR}/"
echo
echo "Als adminUsername/adminPassword 'null' zijn: controleer dat het"
echo "gebruikte token de scope 'Get My Services with Management"
echo "Credentials' (of org-breed 'Get Services with Management"
echo "Credentials') heeft (Mission Control > API Tokens)."
