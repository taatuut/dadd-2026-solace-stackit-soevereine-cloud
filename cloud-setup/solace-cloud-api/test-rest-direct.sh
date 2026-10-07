#!/usr/bin/env bash
# Bypasses the local broker's RDP entirely and POSTs straight to each cloud
# broker's REST messaging endpoint with curl, using the exact same
# http-basic credentials the RDP's rest-consumer uses. Purpose: the RDP's
# own SEMP monitor data only exposes the terse
# "lastFailureReason": "Service Unavailable" for a failing queue-binding --
# it does not show the actual HTTP status line or response body the cloud
# broker sent back.
#
# RESULT (Emil, 28/09/2026): all 3 cloud brokers returned HTTP 200 OK to a
# direct curl POST with real content -- so REST-incoming, http-basic auth,
# host:port and topic-from-path construction are all confirmed working,
# independently of the RDP. This rules out those causes for the RDP's
# persistent 503. The mystery deepens: local-broker/semp/diagnose-rdp.sh's
# REST-consumer counters (httpRequestTxMsgCount etc.) are all 0, meaning
# the RDP's consumer has never actually sent a real message POST -- so the
# "Service Unavailable" the queue-binding reports is most likely NOT from
# a failed real-message delivery (there hasn't been one yet), but from
# some other RDP-internal readiness/probe step. See PLAN.md section 13,
# item 18. Next step: an actual end-to-end publish test (see
# demo-apps/stm-public/publish-public.sh), then re-check diagnose-rdp.sh's
# REST-consumer counters and the queue's spooledMsgCount/msgSpoolUsage to
# see whether a REAL message actually gets captured and delivered, versus
# what the RDP's Down/Up status alone says.
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
#
# Output goes to <repo-root>/output/test-rest-direct.txt (gitignored, same
# convention as diagnose-rdp.sh), AND is still printed to the console.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../local-broker/.env"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_FILE="${OUT_DIR}/test-rest-direct.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${OUT_DIR}"

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

{
  test_one "AWS US East"         "${AWS_REMOTE_REST_HOST}"     "${AWS_REMOTE_REST_PORT}"     "${AWS_BRIDGE_USER}"     "${AWS_BRIDGE_PASSWORD}"     "enewable/public/test-direct"
  test_one "Azure West Europe"   "${AZURE_REMOTE_REST_HOST}"   "${AZURE_REMOTE_REST_PORT}"   "${AZURE_BRIDGE_USER}"   "${AZURE_BRIDGE_PASSWORD}"   "enewable/eu/ops/test-direct"
  test_one "STACKIT eu01"        "${STACKIT_REMOTE_REST_HOST}" "${STACKIT_REMOTE_REST_PORT}" "${STACKIT_BRIDGE_USER}" "${STACKIT_BRIDGE_PASSWORD}" "enewable/eu/pii/test-direct"
} | tee "${OUT_FILE}"

cat <<INFO
Klaar. Output ook geschreven naar: ${OUT_FILE}
INFO
