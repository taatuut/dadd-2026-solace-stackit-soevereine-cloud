#!/usr/bin/env bash
# Bypasses the local broker's RDP entirely and POSTs straight to each cloud
# broker's REST messaging endpoint with curl, using the exact same
# http-basic credentials the RDP's rest-consumer uses. Purpose: the RDP's
# own SEMP monitor data only exposes the terse
# "lastFailureReason": "Service Unavailable" for a failing queue-binding --
# it does not show the actual HTTP status line or response body the cloud
# broker sent back. A direct curl call surfaces both, which should say
# definitively whether this is (a) REST-incoming disabled on the VPN
# (typically a 503 with a specific body, or connection refused if the
# service-level protocol itself isn't provisioned), (b) an auth problem
# (401/403), (c) something else entirely.
#
# WHY THIS SCRIPT EXISTS (28/09/2026): after configure-rdp-export.sh ran
# clean (0 WARN) and diagnose-rdp.sh confirmed the REST-consumer's
# underlying connection is healthy and the queue's topic subscription is
# present, the queue-binding itself still fails with HTTP 503 "Service
# Unavailable" on every re-run of diagnose-rdp.sh -- including after
# enable-rest-on-cloud-vpns.sh was expected to rule out "REST-incoming not
# enabled" as the cause. This script gets the real HTTP response directly,
# instead of continuing to guess from the RDP's internal state.
#
# This script must be run by Emil, not the assistant: this session's
# network cannot reach *.messaging.solace.cloud -- confirmed blocked
# earlier, see PLAN.md section 13.
#
# Usage: ./test-rest-direct.sh
# Requires: curl, and a populated ../../local-broker/.env
# Sends one harmless test message per cloud broker on a topic under the
# matching enewable/* subtree (so if it succeeds, the message also lands
# in the matching queue -- safe, and useful to see in Broker Manager too).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../local-broker/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

test_one() {
  local label="$1" host="$2" port="$3" user="$4" pass="$5" topic="$6"
  echo "== ${label}: POST https://${host}:${port}/${topic} =="
  curl -sS -i -u "${user}:${pass}" \
    -X POST "https://${host}:${port}/${topic}" \
    -H "Content-Type: text/plain" \
    -d "test-rest-direct.sh diagnostic message, $(date -u +%FT%TZ)"
  echo
  echo
}

test_one "AWS US East"         "${AWS_REMOTE_REST_HOST}"     "${AWS_REMOTE_REST_PORT}"     "${AWS_BRIDGE_USER}"     "${AWS_BRIDGE_PASSWORD}"     "enewable/public/test-direct"
test_one "Azure West Europe"   "${AZURE_REMOTE_REST_HOST}"   "${AZURE_REMOTE_REST_PORT}"   "${AZURE_BRIDGE_USER}"   "${AZURE_BRIDGE_PASSWORD}"   "enewable/eu/ops/test-direct"
test_one "STACKIT/GCP-interim" "${STACKIT_REMOTE_REST_HOST}" "${STACKIT_REMOTE_REST_PORT}" "${STACKIT_BRIDGE_USER}" "${STACKIT_BRIDGE_PASSWORD}" "enewable/eu/pii/test-direct"

cat <<INFO
Klaar. Stuur de volledige output (incl. de HTTP-statusregel en eventuele
response-body per broker) -- dat is veel specifieker dan de RDP's eigen
"Service Unavailable"-samenvatting en zou het echte 503-antwoord (of iets
anders, zoals 401/403) moeten tonen.
INFO
