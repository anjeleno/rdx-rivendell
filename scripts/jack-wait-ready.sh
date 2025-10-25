#!/usr/bin/env bash
# jack-wait-ready.sh — Wait for a running JACK server with at least one port.
# Usage: jack-wait-ready.sh [--timeout SECONDS] [--interval SECONDS]
# Exits 0 when ready, 1 on timeout, 2 on missing tools.
set -euo pipefail

TIMEOUT=30
INTERVAL=0.5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout|-t)
      TIMEOUT=${2:-30}; shift 2;;
    --interval|-i)
      INTERVAL=${2:-0.5}; shift 2;;
    *)
      echo "[jack-wait] Unknown arg: $1" >&2; exit 2;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

if ! have jack_lsp; then
  echo "[jack-wait] jack_lsp not found in PATH" >&2
  exit 2
fi

start_ts=$(date +%s)
end_ts=$(( start_ts + TIMEOUT ))

log_once=true
while :; do
  # Fast probe first
  if jack_lsp >/dev/null 2>&1; then
    # Optionally verify there is at least one port name
    if ports=$(jack_lsp -p 2>/dev/null); then
      if [[ -n "${ports}" ]]; then
        echo "[jack-wait] JACK is ready (ports detected)."
        exit 0
      fi
    else
      # jack_lsp -p not supported/failed: consider RUNNING if plain jack_lsp succeeded
      echo "[jack-wait] JACK is ready."
      exit 0
    fi
  fi

  now=$(date +%s)
  if (( now >= end_ts )); then
    echo "[jack-wait] Timeout after ${TIMEOUT}s waiting for JACK to become ready." >&2
    # Print a brief diagnostic to help operators
    if have jack_control; then
      jack_control status 2>/dev/null || true
    fi
    exit 1
  fi

  if $log_once; then
    echo "[jack-wait] Waiting for JACK to be ready (timeout=${TIMEOUT}s)…"
    log_once=false
  fi
  sleep "${INTERVAL}"

done
