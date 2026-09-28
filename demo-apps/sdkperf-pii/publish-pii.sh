#!/usr/bin/env bash
# Publishes a burst of sensitive PII Enewable data (smart-meter readings) to
# the local broker on enewable/eu/pii/meter/reading, using SDKPerf.
#
# Assumes sdkperf_java.sh is on PATH -- override with SDKPERF_BIN if not.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
[[ -f "${SCRIPT_DIR}/../../local-broker/.env" ]] && source "${SCRIPT_DIR}/../../local-broker/.env"

: "${SDKPERF_BIN:=sdkperf_java.sh}"
: "${LOCAL_SMF_HOST:=localhost:55554}"
: "${LOCAL_MSG_VPN:=enewable}"
: "${PUB_EU_PII_USER:=pub-eu-pii}"
: "${PUB_EU_PII_PASSWORD:?Set PUB_EU_PII_PASSWORD (see local-broker/.env)}"

COUNT="${1:-20}"

"${SDKPERF_BIN}" \
  -cip="${LOCAL_SMF_HOST}" \
  -cu="${PUB_EU_PII_USER}@${LOCAL_MSG_VPN}" \
  -cp="${PUB_EU_PII_PASSWORD}" \
  -ptl=enewable/eu/pii/meter/reading \
  -mt=direct -mn="${COUNT}" -mr=2 -msa=200 -md
