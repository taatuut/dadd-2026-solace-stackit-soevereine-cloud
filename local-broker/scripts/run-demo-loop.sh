#!/usr/bin/env bash
# Runs all 3 demo-apps continuously, in a loop, by periodically invoking
# their EXISTING publish scripts -- no app code duplicated or reimplemented
# here. Useful for a stand/booth demo (DADD exhibition floor) where the 3
# cloud "Try Me!" tabs should keep showing fresh traffic without someone
# manually re-running each script every time it finishes.
#
# Each cycle calls, in order:
#   1. demo-apps/stm-public/publish-public.sh
#   2. demo-apps/python-eu-nonpersonal/publisher.py
#   3. demo-apps/sdkperf-pii/publish-pii.sh
# and each of those 3 scripts, by default, publishes ALL 3 data classes
# itself (public -> AWS, eu-ops -> Azure, eu-pii -> STACKIT), each with its
# own scoped credential -- see PLAN.md section 13 for why (this used to be
# one class per app; now every app demonstrates that the destination is
# decided by TOPIC, not by which tool published the message). One full
# cycle therefore sends 9 class-runs total (3 apps x 3 classes), so it
# takes longer per cycle than before -- the default 30s INTERVAL below is
# the pause AFTER a cycle finishes, not a budget for how long it takes.
# Then either sleeps INTERVAL seconds (default 30) or, with --interval 0,
# immediately starts the next cycle as soon as the previous one's 3 scripts
# have all finished ("na aflopen van een run").
#
# One app failing (e.g. SDKPerf not installed, see SDKPERF_BIN in
# local-broker/.env.example) does NOT stop the loop or the other 2 apps --
# see README.md, "Doorlopend draaien" for the full explanation and
# prerequisites (this assumes you already completed the one-time setup:
# local broker running + configured, RDP-export configured, all 3 demo-app
# dependencies installed).
#
# Usage:
#   ./run-demo-loop.sh [--interval SECONDS] [--count N] [--once]
#
#   --interval SECONDS  Seconds to sleep between cycles (default: 30).
#                        Use 0 to chain cycles back-to-back with no pause.
#   --count N           Forward this burst size to all 3 scripts for this
#                        cycle -- applies PER CLASS within each script, not
#                        per script (default: each script's own built-in
#                        default -- stm: 10, python: 20, sdkperf: 20).
#   --once               Run exactly one cycle, then exit (no loop). Handy
#                        to sanity-check your setup before leaving this
#                        running unattended on a stand.
#
# Stop with Ctrl-C (or SIGTERM) -- prints a small summary on exit.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INTERVAL=30
COUNT=""
ONCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="${2:?--interval requires a value}"
      shift 2
      ;;
    --count)
      COUNT="${2:?--count requires a value}"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    -h|--help)
      sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Onbekende optie: $1 (zie --help)" >&2
      exit 1
      ;;
  esac
done

STM_SCRIPT="${REPO_ROOT}/demo-apps/stm-public/publish-public.sh"
PY_DIR="${REPO_ROOT}/demo-apps/python-eu-nonpersonal"
SDKPERF_SCRIPT="${REPO_ROOT}/demo-apps/sdkperf-pii/publish-pii.sh"

for f in "${STM_SCRIPT}" "${PY_DIR}/publisher.py" "${SDKPERF_SCRIPT}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Kan ${f} niet vinden -- draai dit script vanuit een checkout van de repo" >&2
    echo "(local-broker/scripts/run-demo-loop.sh), niet los gekopieerd." >&2
    exit 1
  fi
done

# Prefer the app's own venv (created per demo-apps/python-eu-nonpersonal/README.md)
# if it exists; fall back to plain python3 on PATH otherwise (e.g. if deps
# were installed globally/via pipx). Resolved once, up front, not per cycle.
if [[ -x "${PY_DIR}/.venv/bin/python3" ]]; then
  PYTHON_BIN="${PY_DIR}/.venv/bin/python3"
else
  PYTHON_BIN="python3"
fi

CYCLES=0
# Deliberately NOT using bash associative arrays (declare -A) here -- see
# local-broker/semp/configure-local-broker.sh for why: macOS ships bash 3.2
# as /bin/bash (frozen since El Capitan for licensing reasons), which
# predates bash 4's associative-array support. Plain per-app counters
# instead, same style as that script's create_scoped_publisher() calls.
OK_STM=0;      FAIL_STM=0
OK_PYTHON=0;   FAIL_PYTHON=0
OK_SDKPERF=0;  FAIL_SDKPERF=0

on_exit() {
  echo
  echo "== run-demo-loop.sh gestopt na ${CYCLES} cyclus/cycli =="
  echo "  stm-public           : ${OK_STM} ok, ${FAIL_STM} mislukt"
  echo "  python-eu-nonpersonal: ${OK_PYTHON} ok, ${FAIL_PYTHON} mislukt"
  echo "  sdkperf-pii          : ${OK_SDKPERF} ok, ${FAIL_SDKPERF} mislukt"
}
trap on_exit EXIT
trap 'echo; echo "(stop-signaal ontvangen)"; exit 0' INT TERM

run_step() {
  # run_step LABEL CMD... -- LABEL must be stm, python or sdkperf; updates
  # that app's own OK_*/FAIL_* counter (see note above on why not an array).
  local label="$1"; shift
  echo "-- [$(date -u +%H:%M:%S)] ${label} --"
  if "$@"; then
    case "${label}" in
      stm)     OK_STM=$(( OK_STM + 1 )) ;;
      python)  OK_PYTHON=$(( OK_PYTHON + 1 )) ;;
      sdkperf) OK_SDKPERF=$(( OK_SDKPERF + 1 )) ;;
    esac
  else
    case "${label}" in
      stm)     FAIL_STM=$(( FAIL_STM + 1 )) ;;
      python)  FAIL_PYTHON=$(( FAIL_PYTHON + 1 )) ;;
      sdkperf) FAIL_SDKPERF=$(( FAIL_SDKPERF + 1 )) ;;
    esac
    echo "   WARN: ${label} gaf een fout -- ga door met de rest van deze cyclus."
  fi
}

echo "run-demo-loop.sh -- start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "  interval: ${INTERVAL}s tussen cycli (0 = direct doorgaan na elke run)"
echo "  count   : ${COUNT:-<elk script se eigen default>}"
echo "  stop met Ctrl-C"
echo

while true; do
  CYCLES=$(( CYCLES + 1 ))
  echo "===== cyclus ${CYCLES} -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ====="

  if [[ -n "${COUNT}" ]]; then
    run_step stm "${STM_SCRIPT}" "${COUNT}"
  else
    run_step stm "${STM_SCRIPT}"
  fi

  if [[ -n "${COUNT}" ]]; then
    run_step python "${PYTHON_BIN}" "${PY_DIR}/publisher.py" --count "${COUNT}" --interval 1
  else
    run_step python "${PYTHON_BIN}" "${PY_DIR}/publisher.py" --count 20 --interval 1
  fi

  if [[ -n "${COUNT}" ]]; then
    run_step sdkperf "${SDKPERF_SCRIPT}" "${COUNT}"
  else
    run_step sdkperf "${SDKPERF_SCRIPT}"
  fi

  echo

  if [[ "${ONCE}" == true ]]; then
    break
  fi

  if [[ "${INTERVAL}" -gt 0 ]]; then
    echo "(wacht ${INTERVAL}s tot volgende cyclus...)"
    sleep "${INTERVAL}"
  fi
done
