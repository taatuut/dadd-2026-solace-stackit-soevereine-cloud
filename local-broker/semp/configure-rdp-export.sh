#!/usr/bin/env bash
# Configures REST Delivery Points (RDPs) on the LOCAL broker to export
# messages to the 3 cloud brokers, using Solace's native RDP feature --
# no relay app, no bridges. Chosen by Emil as the definitive replacement
# for the bridge-based approach in configure-local-broker.sh (see PLAN.md
# section 13/14 and docs/lokale-broker.md for why bridges don't work for
# export without a reciprocal bridge + public reachability, and why RDPs
# solve this natively).
#
# How it works, end to end:
#   1. The 3 demo apps (stm/web-messaging, python/SMF, sdkperf/SMF) keep
#      publishing DIRECT messages to their topics exactly as today --
#      NO APP CHANGES.
#   2. A durable QUEUE is created per topic subtree, with a matching topic
#      SUBSCRIPTION. Solace's "message promotion" feature automatically
#      captures (promotes) a matching DIRECT-published message into that
#      queue -- confirmed via Solace's own docs
#      (Topic-Matching-and-Delivery-Modes.htm): "No special configuration
#      is required -- it happens automatically whenever there is a topic
#      match." (Not lossless under sustained high-rate publishing, but
#      fine for a demo.)
#   3. An RDP is bound to that queue (a "queue binding") and configured
#      with a REST CONSUMER pointing at the target cloud broker's own REST
#      messaging endpoint. The RDP POSTs every message it drains from the
#      queue to that endpoint.
#   4. The POST request target is "/${topic()}" -- Solace's REST messaging
#      inbound service treats the URL path as the topic to publish on
#      (confirmed via tutorials.solace.dev/rest-messaging/publish-subscribe),
#      and "${topic()}" is Solace's substitution-expression syntax for "the
#      full original topic string" (confirmed via
#      Messaging/Substitution-Expressions-Overview.htm). So a message
#      published locally on "enewable/public/plant-1/telemetry" is
#      re-published on the SAME topic on the cloud broker -- topic
#      structure is preserved end to end.
#
# SEMP v2 object/attribute names below were NOT guessed from the CLI-only
# reference doc (Services/Managing-RDPs.htm gives CLI syntax, not REST
# attribute names) -- they were cross-checked against a working Go SEMP
# client's struct field/JSON tags (github.com/koverton/semp_client) for
# MsgVpnRestDeliveryPoint, MsgVpnRestDeliveryPointQueueBinding,
# MsgVpnRestDeliveryPointRestConsumer, MsgVpnQueue and
# MsgVpnQueueSubscription. Given this session's track record of 2 wrong
# schema guesses already on the bridge side (see PLAN.md section 13, items
# 8), TEST ONE BRIDGE FIRST if any WARN appears below rather than assuming
# the whole batch is right.
#
# CONFIRMED BUG #1 (first real run, 28/09/2026): authenticationScheme's
# value is NOT "basic" (that's the bridge convention) -- the broker
# rejected it with SEMP error 11, and its own error message gave the real
# enum: ['none', 'http-basic', 'client-certificate', 'http-header',
# 'oauth-client', 'oauth-jwt', 'transparent', 'aws']. Fixed to "http-basic".
# The Go client's FIELD names were still right; only this one VALUE was
# bridge-specific, not RDP-specific.
#
# CONFIRMED BUG #2, the real cause of the persistent HTTP 503 "Service
# Unavailable" that made all 3 RDPs show "Down" for the rest of that day
# (28/09/2026): "${topic()}" in postRequestTarget is NEVER evaluated
# unless the queue-binding's requestTargetEvaluation attribute is
# explicitly set to "substitution-expressions" -- it silently defaults to
# "none" (confirmed via the solacebroker Terraform provider's resource
# docs; this field isn't mentioned anywhere in Solace's CLI-only RDP
# reference doc). Without it, every single message was POSTed to the
# LITERAL, unevaluated path "/${topic()}", never the real topic. This
# almost certainly explains the 503 too: a literal "${...}" in a URL path
# is exactly the pattern Log4Shell-era WAF/CDN rules are tuned to reject,
# and it explains why the REST consumer's httpRequestTxMsgCount counters
# never moved even with real messages sitting in the queue (see PLAN.md
# section 13, item 23 for the full trail: message promotion into the
# queue was independently confirmed working via a real end-to-end publish
# test -- spooledMsgCount going from 0 to 10 -- while delivery onward
# stayed stuck at exactly this bug). Fixed by adding
# requestTargetEvaluation":"substitution-expressions" to the queueBindings
# POST body, plus an unconditional PATCH so it also fixes bindings
# created by an earlier, buggy run of this script.
#
# CONFIRMED BUG #3, the actual root cause of the persistent 503 (found via
# watch-rdp-live.sh, 28/09/2026): the queue-binding never even BINDS to its
# own local queue. Broker Manager's Queues page shows "Consumers: 0" for
# all 3 queues (should be 1 -- the RDP itself), and SEMP confirms
# bindRequestCount: 0 / bindSuccessCount: 0 on the queue, unchanged across
# 15 samples over 35+ seconds while 30 messages sat spooled and the REST
# consumer's own connections were healthy (up: true, 3/3) for most of that
# window. The REST-consumer's HTTP counters (httpRequestTxMsgCount etc.)
# never move either -- consistent with the binding never even reaching the
# point of dequeuing a message to POST, let alone the POST itself. The
# earlier "Peer TCP Closed" lead (see PLAN.md section 13, item 24) turned
# out to be a red herring: the queue-binding fails with "Service
# Unavailable" on almost every ~2s retry REGARDLESS of whether the REST
# consumer's connections are currently up -- so the two failures are
# independent, not cause-and-effect.
# Root cause: BOTH the RDP object itself AND every demo-app client-username
# use clientProfileName "default" (see configure-local-broker.sh), and
# diagnose-local-auth.sh already showed (28/09/2026, unconnected to this
# investigation until now) that the "default" client-profile has
# allowGuaranteedMsgReceiveEnabled: false. An RDP's queue-binding dequeues
# messages from a DURABLE QUEUE -- a guaranteed-message-RECEIVE operation --
# so if its client-profile forbids that, the binding can never actually
# bind/consume from the queue at all. This matches every symptom: the bind
# never registers (bindRequestCount stuck at 0), no message is ever
# dequeued to POST (httpRequestTxMsgCount stuck at 0), and the generic
# "Service Unavailable" is what the broker reports when it can't tell the
# operator anything more specific about why the binding can't come up.
# Fixed: a dedicated client-profile "rdp-deliver" is now created with
# allowGuaranteedMsgReceiveEnabled: true (guaranteed-receive is exactly
# what an RDP's queue-binding needs; nothing else about "default" needs to
# change, and demo-app publishers keep using "default" unaffected), and
# every RDP is created/patched to use it instead of "default".
#
# Usage: ./configure-rdp-export.sh
# Requires: curl, and a populated ../.env (same file configure-local-broker.sh
# uses), PLUS the new *_REMOTE_REST_HOST / *_REMOTE_REST_PORT variables --
# see local-broker/.env.example for what to fill in and where to find it
# (Solace Cloud console > service > Connect tab > REST section; you may
# need to ENABLE the REST messaging protocol for that service first, it is
# not always on by default the way SMF/Web-messaging are).

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
    if echo "${response}" | grep -q '"code": *6001' || echo "${response}" | grep -q '"status": *"ALREADY_EXISTS"'; then
      echo "  (already exists, skipping) ${path}"
    else
      echo "  WARN on ${method} ${path}:"
      echo "${response}"
    fi
  fi
}

create_export_route() {
  local queue="$1" topic="$2" rdp="$3" consumer="$4" \
        remote_host="$5" remote_port="$6" remote_user="$7" remote_pass="$8"

  echo "-- ${queue} (subscribes '${topic}') -> ${rdp} -> ${remote_host}:${remote_port} --"

  # 1. Durable queue that attracts (via message promotion) messages
  #    matching the topic subtree, even though the demo apps publish them
  #    as DIRECT, not guaranteed. "non-exclusive" so nothing about this
  #    queue depends on a single consumer -- the RDP itself is the only
  #    consumer in practice.
  semp POST "/msgVpns/${VPN}/queues" \
    "{\"queueName\":\"${queue}\",\"accessType\":\"non-exclusive\",\"permission\":\"consume\",\"ingressEnabled\":true,\"egressEnabled\":true,\"maxMsgSpoolUsage\":500}"

  semp POST "/msgVpns/${VPN}/queues/${queue}/subscriptions" \
    "{\"subscriptionTopic\":\"${topic}\"}"

  # 2. The RDP object itself (the "container" for the queue-binding +
  #    rest-consumer below).
  #
  #    BUG FOUND AND FIXED (28/09/2026): "default" (this RDP's original
  #    clientProfileName) has allowGuaranteedMsgReceiveEnabled: false,
  #    which blocks the RDP from ever binding/consuming from its own
  #    durable queue -- see the header comment for the full trail. Uses
  #    "rdp-deliver" instead (created just above the create_export_route
  #    calls, once, idempotently).
  semp POST "/msgVpns/${VPN}/restDeliveryPoints" \
    "{\"restDeliveryPointName\":\"${rdp}\",\"clientProfileName\":\"rdp-deliver\",\"enabled\":true}"
  semp PATCH "/msgVpns/${VPN}/restDeliveryPoints/${rdp}" \
    "{\"clientProfileName\":\"rdp-deliver\"}"

  # 3. Queue binding: which queue feeds this RDP, and what URL path
  #    (relative to the rest-consumer's host:port) each drained message is
  #    POSTed to. "${topic()}" reconstructs the FULL original topic, so
  #    the message lands on the identical topic on the remote broker.
  #
  #    BUG FOUND AND FIXED (28/09/2026): postRequestTarget's substitution
  #    expressions are NOT evaluated unless requestTargetEvaluation is
  #    explicitly set to "substitution-expressions" -- it defaults to
  #    "none" (confirmed via the solacebroker Terraform provider's own
  #    resource docs; Solace's CLI-only RDP docs don't mention this field
  #    at all). Without it, every queue-binding was POSTing to the
  #    LITERAL, unevaluated path "/${topic()}" on every single message --
  #    never the real topic -- which is almost certainly why the cloud
  #    broker's REST gateway (behind AWS/Azure/GCP-style front-end
  #    infrastructure) rejected it with HTTP 503 "Service Unavailable":
  #    a literal "${...}" pattern in a URL path is exactly what
  #    Log4Shell-era WAF/CDN rules are tuned to block. This also explains
  #    why the REST consumer's own httpRequestTxMsgCount counters never
  #    moved: whatever intercepted the "${topic()}" request likely never
  #    let it register as a normal transmitted message. A direct curl
  #    POST to a normal, real topic path never showed this because it
  #    never contained the "${...}" pattern in the first place.
  #    "substitution-expressions" makes the RDP evaluate it into the
  #    actual topic (e.g. "enewable/public/market/price") before POSTing.
  #    This PATCH is separate (unconditional, not idempotent-skipped)
  #    from the queueBindings POST below so it also fixes bindings
  #    created by an earlier run of this script, before this fix existed.
  semp POST "/msgVpns/${VPN}/restDeliveryPoints/${rdp}/queueBindings" \
    "{\"queueBindingName\":\"${queue}\",\"postRequestTarget\":\"/\${topic()}\",\"requestTargetEvaluation\":\"substitution-expressions\"}"
  semp PATCH "/msgVpns/${VPN}/restDeliveryPoints/${rdp}/queueBindings/${queue}" \
    "{\"requestTargetEvaluation\":\"substitution-expressions\"}"

  # 4. REST consumer: the actual remote endpoint the RDP POSTs to. Reuses
  #    the existing enewable-local-bridge credentials already created (and
  #    ACL-scoped publish-only on this exact topic subtree) on each cloud
  #    broker for the bridge experiment -- see
  #    cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh.
  semp POST "/msgVpns/${VPN}/restDeliveryPoints/${rdp}/restConsumers" \
    "{\"restConsumerName\":\"${consumer}\",\"remoteHost\":\"${remote_host}\",\"remotePort\":${remote_port},\"tlsEnabled\":true,\"authenticationScheme\":\"http-basic\",\"authenticationHttpBasicUsername\":\"${remote_user}\",\"authenticationHttpBasicPassword\":\"${remote_pass}\",\"enabled\":true}"

  echo "  OK: ${queue} --[promote]--> ${rdp}/${consumer} --[POST /\${topic()}]--> https://${remote_host}:${remote_port}"
}

echo "== Client-profile for RDPs: rdp-deliver (allowGuaranteedMsgReceiveEnabled) =="
# "default" (used by the demo-app publishers, unaffected by this) has
# allowGuaranteedMsgReceiveEnabled: false, which blocks an RDP's
# queue-binding from ever binding/consuming from its own durable queue --
# see header comment (CONFIRMED BUG #3). This profile is dedicated to the
# RDPs; nothing else uses it, so nothing else is affected by this change.
semp POST "/msgVpns/${VPN}/clientProfiles" \
  "{\"clientProfileName\":\"rdp-deliver\",\"allowGuaranteedMsgReceiveEnabled\":true,\"allowGuaranteedMsgSendEnabled\":true}"
semp PATCH "/msgVpns/${VPN}/clientProfiles/rdp-deliver" \
  "{\"allowGuaranteedMsgReceiveEnabled\":true,\"allowGuaranteedMsgSendEnabled\":true}"

echo "== REST Delivery Points: export enewable/* to the 3 cloud brokers =="

create_export_route "q-export-public"  "enewable/public/>" "rdp-aws"     "consumer-aws"     \
  "${AWS_REMOTE_REST_HOST}"     "${AWS_REMOTE_REST_PORT}"     "${AWS_BRIDGE_USER}"     "${AWS_BRIDGE_PASSWORD}"

create_export_route "q-export-eu-ops"  "enewable/eu/ops/>" "rdp-azure"   "consumer-azure"   \
  "${AZURE_REMOTE_REST_HOST}"   "${AZURE_REMOTE_REST_PORT}"   "${AZURE_BRIDGE_USER}"   "${AZURE_BRIDGE_PASSWORD}"

# NOTE: STACKIT_* currently points at the interim GCP europe-west1 stand-in
# until STACKIT is GA in Solace Cloud -- see ../../cloud-setup/stackit-eu01/README.md
create_export_route "q-export-eu-pii"  "enewable/eu/pii/>" "rdp-stackit" "consumer-stackit" \
  "${STACKIT_REMOTE_REST_HOST}" "${STACKIT_REMOTE_REST_PORT}" "${STACKIT_BRIDGE_USER}" "${STACKIT_BRIDGE_PASSWORD}"

cat <<INFO

Klaar. Controleer in Broker Manager (http://localhost:8080 > VPN 'enewable'):
  - Queues: q-export-public / q-export-eu-ops / q-export-eu-pii moeten
    bestaan met de juiste topic-subscription en "Bind Count" 1 (de RDP zelf).
  - REST Delivery Points: rdp-aws / rdp-azure / rdp-stackit moeten "Up" zijn
    (dat wil zeggen: de REST Consumer kan de remote host:port bereiken en
    TLS/auth is akkoord -- niet te verwarren met "gebonden aan een queue",
    wat een apart vinkje is).
Publiceer daarna een testbericht met stm/python/sdkperf op de juiste topic
en controleer in de Solace Cloud console van de DOELBROKER (Try Me! of de
queue browser) dat het bericht daar aankomt op DEZELFDE topic -- en dat het
NIET op de andere 2 cloud brokers verschijnt.
INFO
