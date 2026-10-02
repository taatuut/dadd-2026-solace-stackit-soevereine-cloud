#!/usr/bin/env bash
# Haalt de Broker Manager-admin (manager-rol) username/password op voor de
# 3 cloud broker-services (AWS, Azure, STACKIT) en schrijft ze naar
# ../../output/broker-admin-credentials.json.
#
# Bron: Terraform-state (`terraform output -json`, zie ../terraform/
# outputs.tf), NIET een curl naar de Mission Control REST API. Reden:
# GET .../missionControl/eventBrokerServices/{id} -- ook met
# expand=broker/serviceConnectionEndpoints/allowedActions/
# messageSpoolDetails -- geeft geen messageVpn-/credential-velden terug.
# Bevestigd zowel empirisch (een echte respons bevatte alleen basisvelden
# als id/name/datacenterId/serviceClassId, geen messageVpn) als tegen de
# publieke OpenAPI-spec van deze API
# (https://api.solace.dev/cloud/openapi/mission-control.json): de
# substring "ManagementCredential" komt daar nergens in voor. De
# `solacecloud` Terraform-provider heeft deze credentials wel (ze staan al
# in `output/service-{aws,azure,stackit}.json` in deze repo, gevuld via
# `terraform output -json` ten tijde van het aanmaken van de services) --
# kennelijk via een andere/interne route dan de publiek gedocumenteerde
# GET. `terraform output` tegen de actuele state is daarom de bron die
# hier werkt. Zie `SKILLS.md`, "Mission Control API geeft geen
# broker-management-credentials terug via GET" voor de volledige
# uitzoekstappen.
#
# Vereist: de `terraform` CLI, jq, en een actuele state in ../terraform/
# (d.w.z. de 3 services staan er al, zie ../terraform/README.md).
#
# Gebruik:
#   ./get-broker-manager-credentials.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
OUTPUT_DIR="${SCRIPT_DIR}/../../output"
mkdir -p "${OUTPUT_DIR}"

command -v terraform >/dev/null 2>&1 || { echo "terraform CLI is vereist voor dit script." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is vereist voor dit script." >&2; exit 1; }

extract() {
  local output_name="$1"
  terraform -chdir="${TERRAFORM_DIR}" output -json "${output_name}" \
    | jq '{adminUsername: .message_vpn.manager_management_credential.username,
           adminPassword: .message_vpn.manager_management_credential.password}'
}

jq -n \
  --argjson aws "$(extract aws_service)" \
  --argjson azure "$(extract azure_service)" \
  --argjson stackit "$(extract stackit_service)" \
  '{aws: $aws, azure: $azure, stackit: $stackit}' \
  > "${OUTPUT_DIR}/broker-admin-credentials.json"

echo "Geschreven: ${OUTPUT_DIR}/broker-admin-credentials.json"
echo
echo "Als adminUsername/adminPassword 'null' zijn: draai 'terraform apply'"
echo "(of 'terraform refresh') in ../terraform/ zodat de state actueel is,"
echo "en controleer met 'terraform output -json aws_service | jq .' of het"
echo "veld message_vpn.manager_management_credential daar echt in zit."
