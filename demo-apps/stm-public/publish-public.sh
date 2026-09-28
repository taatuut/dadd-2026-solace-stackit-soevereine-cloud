#!/usr/bin/env bash
# Publishes a burst of PUBLIC Enewable data (day-ahead prices) to the local
# broker on enewable/public/market/price, using the Solace Try-Me CLI.
#
# NOTE (fixed 28/09/2026): the messaging subcommand in the installed stm
# CLI (v1.0.0) is "send", not "publish" -- "stm publish" fails with
# "error: unknown option '--url'" because there is no "publish" command at
# all in this version (the full command tree is send/receive/request/
# reply/config/manage/feed -- see the SolaceLabs/solace-tryme-cli README).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
[[ -f "${SCRIPT_DIR}/../../local-broker/.env" ]] && source "${SCRIPT_DIR}/../../local-broker/.env"

: "${LOCAL_WEB_MESSAGING_URL:=ws://localhost:8008}"
: "${LOCAL_MSG_VPN:=enewable}"
: "${PUB_PUBLIC_USER:=pub-public}"
: "${PUB_PUBLIC_PASSWORD:?Set PUB_PUBLIC_PASSWORD (see local-broker/.env)}"

COUNT="${1:-10}"

stm send \
  --url "${LOCAL_WEB_MESSAGING_URL}" \
  --vpn "${LOCAL_MSG_VPN}" \
  --username "${PUB_PUBLIC_USER}" --password "${PUB_PUBLIC_PASSWORD}" \
  --topic enewable/public/market/price \
  --file "${SCRIPT_DIR}/sample-payload.json" \
  --count "${COUNT}" --interval 1000
