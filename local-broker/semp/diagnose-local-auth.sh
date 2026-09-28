#!/usr/bin/env bash
# Read-only diagnostic for a new, separate problem hit while trying to run
# the actual end-to-end publish test (PLAN.md section 13, item 18-19):
# after fixing the stm CLI's "publish" -> "send" subcommand bug,
# publish-public.sh now fails at the very first step -- connecting to the
# LOCAL broker itself, as client-username pub-public -- with:
#
#   error: connection failed to the message router
#   The RADIUS profile is shutdown - - check the connection parameters!
#
# This is unrelated to the cloud-side RDP/503 investigation: it's a local
# authentication problem on the "enewable" Message VPN, on the very first
# hop (stm -> local broker over Web Messaging, ws://localhost:8008).
#
# WHY THIS EXACT TEXT IS SUSPICIOUS: Solace's own error-subcode docs (the
# JS client library, which stm is built on) list several distinct
# "administratively shutdown" login-denial reasons (e.g.
# CLIENT_USERNAME_IS_SHUTDOWN, BASIC_AUTHENTICATION_IS_SHUTDOWN) -- but
# "The RADIUS profile is shutdown" specifically corresponds to the
# Message VPN's basic-auth TYPE being set to "radius" while no usable/
# enabled RADIUS profile exists for it. A freshly created Message VPN
# normally defaults to "internal" auth, not radius, so if this really is
# the cause, something set enewable's authenticationBasicType to radius
# (or left a previous experiment's setting in place) -- configure-local-
# broker.sh never sets this explicitly, so it never explains it either
# way. This script checks that theory directly, plus the more mundane
# possibilities (VPN disabled, client-username disabled, client-profile
# disabled) before assuming radius is really the cause.
#
# This script must be run by Emil, not the assistant: the assistant's
# sandbox cannot reach localhost:8080 on Emil's machine (it's a separate
# VM from the one running Docker Desktop) -- same kind of isolation as
# the *_SEMP_HOST cloud-side blocker documented elsewhere in PLAN.md.
#
# Usage: ./diagnose-local-auth.sh
# Requires: curl, and a populated ../.env
# Makes NO changes -- GET requests only.
#
# Output goes to <repo-root>/output/diagnose-local-auth.txt (gitignored,
# same convention as diagnose-rdp.sh).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/output"
OUT_FILE="${OUT_DIR}/diagnose-local-auth.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}."
  exit 1
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${OUT_DIR}"

CONFIG="${LOCAL_SEMP_HOST}/SEMP/v2/config"
AUTH=(-u "${LOCAL_SEMP_USER}:${LOCAL_SEMP_PASSWORD}")
VPN="${LOCAL_MSG_VPN}"

pp() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool 2>/dev/null || cat
  else
    cat
  fi
}

get() {
  local path="$1"
  echo "---- GET ${path} ----"
  curl -sS "${AUTH[@]}" "${CONFIG}${path}" | pp
  echo
}

{
  echo "diagnose-local-auth.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  echo "== VPN-level: enabled + basic-auth type =="
  get "/msgVpns/${VPN}?select=enabled,authenticationBasicEnabled,authenticationBasicType,authenticationBasicRadiusDomain"

  echo "== VPN-level: RADIUS profiles configured for this VPN (should be none for internal auth) =="
  get "/msgVpns/${VPN}/authenticationRadiusProfiles" || true

  echo "== client-profile 'default': enabled + allow-send =="
  get "/msgVpns/${VPN}/clientProfiles/default?select=allowGuaranteedMsgSendEnabled,allowGuaranteedMsgReceiveEnabled"

  for user in pub-public pub-eu-ops pub-eu-pii enewable-local-bridge; do
    echo "== client-username '${user}': enabled + profile/ACL =="
    get "/msgVpns/${VPN}/clientUsernames/${user}?select=enabled,aclProfileName,clientProfileName"
  done
} > "${OUT_FILE}"

echo "Klaar. Output geschreven naar: ${OUT_FILE}"
echo "Kijk vooral naar authenticationBasicType -- als dat 'radius' is,"
echo "is dat de oorzaak; zo niet, dan zit het probleem bij een van de"
echo "'enabled: false' velden hierboven."
