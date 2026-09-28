#!/usr/bin/env bash
# Read-only diagnostic, round 6: the requestTargetEvaluation fix (see
# PLAN.md section 13, item 23) is CONFIRMED applied and live in the
# broker's own CONFIG ("requestTargetEvaluation": "substitution-expressions"
# now shows on all 3 queue-bindings), but round-5 diagnose-rdp.sh showed
# the queue-binding's "Down"/503 state is BYTE-FOR-BYTE UNCHANGED -- see
# PLAN.md section 13, item 24. That fix was real but not (solely) the
# cause of the 503.
#
# NEW LEAD (Emil, 28/09/2026, round 5 data): the REST CONSUMER's own
# monitor data carries a field diagnose-rdp.sh dumps but nobody had
# actually READ closely yet:
#   "lastConnectionFailureReason": "Peer TCP Closed"
#   "lastConnectionFailureTime": <a few seconds before the queue-binding's
#     own lastFailureTime>
# This is DIFFERENT from "up": true / remoteOutgoingConnectionUpCount: 3 --
# those describe the connection pool's state AT THE MOMENT SEMP is polled,
# not what happens when the RDP actually tries to hand a message to one of
# those pooled connections. "Peer TCP Closed" means the CLOUD broker's own
# side is closing these persistent/keep-alive connections -- possibly an
# idle-connection timeout on Solace Cloud's front-end load balancer, or the
# REST-messaging ingress not supporting the kind of persistent connection
# reuse the RDP's REST-consumer pool (outgoingConnectionCount: 3) assumes.
# If the connection the queue-binding tries to actually POST on is stale or
# mid-teardown, the send could fail before it's ever counted as a
# transmitted message -- which would explain httpRequestTxMsgCount staying
# at 0 even with 20 real messages sitting in the queue, AND why a one-shot
# curl (which opens a fresh connection every time, never reuses one) always
# succeeds while the RDP's persistent pool never delivers.
#
# This script does NOT prove that theory -- it gathers the evidence needed
# to confirm or kill it: it polls the 3 REST-consumers' and queue-bindings'
# MONITOR data every 2 seconds for ~30 seconds, so the exact moment of a
# connection drop/reconnect (and whether httpRequestTxMsgCount or
# httpResponseErrorRxMsgCount EVER ticks up, even transiently) becomes
# visible -- something a single diagnose-rdp.sh snapshot cannot show.
#
# HOW TO USE THIS (matters -- run in this order):
#   1. In one terminal: ./demo-apps/stm-public/publish-public.sh
#      (or the python/sdkperf demo app) to put fresh messages in the queue.
#   2. Immediately after (within a few seconds): ./watch-rdp-live.sh
#   3. Read output/watch-rdp-live.txt afterwards -- look specifically for:
#      - does httpRequestTxMsgCount (or httpResponseErrorRxMsgCount) ever
#        move off 0 in ANY sample, even briefly?
#      - does lastConnectionFailureTime keep advancing every ~3s
#        (matching retryDelay), i.e. is this a tight, continuous
#        connect/drop loop rather than a one-time historical value?
#      - is "up": true ever simultaneously true with a queue-binding
#        successfully draining (uptime > 0)?
#
# Usage: ./watch-rdp-live.sh [iterations] [sleep_seconds]
#   Defaults: 15 iterations, 2 seconds apart (~30 seconds total).
# Requires: curl, and a populated ../.env
# Makes NO changes -- GET requests only.
# Output goes to <repo-root>/output/watch-rdp-live.txt (gitignored, same
# convention as diagnose-rdp.sh).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_FILE="${OUT_DIR}/watch-rdp-live.txt"

ITERATIONS="${1:-15}"
SLEEP_SECONDS="${2:-2}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${OUT_DIR}"

MONITOR="${LOCAL_SEMP_HOST}/SEMP/v2/monitor"
AUTH=(-u "${LOCAL_SEMP_USER}:${LOCAL_SEMP_PASSWORD}")
VPN="${LOCAL_MSG_VPN}"

# Pulls just the handful of fields that matter for this specific question,
# with jq if available (falls back to raw JSON via python3 if not).
extract() {
  local json="$1"
  if command -v jq >/dev/null 2>&1; then
    echo "${json}" | jq -c '.data | {up, uptime, lastFailureReason, lastFailureTime, lastConnectionFailureReason, lastConnectionFailureTime, remoteOutgoingConnectionUpCount, outgoingConnectionCount, httpRequestTxMsgCount, httpResponseSuccessRxMsgCount, httpResponseErrorRxMsgCount}' 2>/dev/null || echo "${json}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "${json}" << 'PY'
import json, sys
try:
    d = json.loads(sys.argv[1]).get("data", {})
except Exception:
    print(sys.argv[1]); sys.exit(0)
keys = ["up","uptime","lastFailureReason","lastFailureTime","lastConnectionFailureReason",
        "lastConnectionFailureTime","remoteOutgoingConnectionUpCount","outgoingConnectionCount",
        "httpRequestTxMsgCount","httpResponseSuccessRxMsgCount","httpResponseErrorRxMsgCount"]
print(json.dumps({k: d.get(k) for k in keys if k in d}))
PY
  else
    echo "${json}"
  fi
}

{
  echo "watch-rdp-live.sh -- start $(date -u +%Y-%m-%dT%H:%M:%SZ), ${ITERATIONS} samples, ${SLEEP_SECONDS}s apart"
  echo "(run this immediately after a publish-test so messages are actively queued)"
  echo

  for i in $(seq 1 "${ITERATIONS}"); do
    echo "--- sample ${i}/${ITERATIONS} -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ---"
    for entry in "rdp-aws:consumer-aws:q-export-public" "rdp-azure:consumer-azure:q-export-eu-ops" "rdp-stackit:consumer-stackit:q-export-eu-pii"; do
      IFS=":" read -r rdp consumer queue <<< "${entry}"
      consumer_json="$(curl -sS "${AUTH[@]}" "${MONITOR}/msgVpns/${VPN}/restDeliveryPoints/${rdp}/restConsumers/${consumer}")"
      binding_json="$(curl -sS "${AUTH[@]}" "${MONITOR}/msgVpns/${VPN}/restDeliveryPoints/${rdp}/queueBindings/${queue}")"
      queue_json="$(curl -sS "${AUTH[@]}" "${MONITOR}/msgVpns/${VPN}/queues/${queue}?select=spooledMsgCount,bindRequestCount,bindSuccessCount")"
      echo "  ${rdp} consumer: $(extract "${consumer_json}")"
      echo "  ${rdp} binding:  $(extract "${binding_json}")"
      echo "  ${rdp} queue:    $(echo "${queue_json}" | (command -v jq >/dev/null 2>&1 && jq -c '.data' || cat))"
    done
    echo
    if [[ "${i}" -lt "${ITERATIONS}" ]]; then
      sleep "${SLEEP_SECONDS}"
    fi
  done
} | tee "${OUT_FILE}"

cat <<INFO

Klaar. Output ook geschreven naar: ${OUT_FILE}
Kijk vooral of httpRequestTxMsgCount / httpResponseErrorRxMsgCount OOIT
van 0 afgaat, en of lastConnectionFailureTime steeds opnieuw vlak vóór het
moment van bevragen ligt (= continue connect/drop-lus).
INFO
