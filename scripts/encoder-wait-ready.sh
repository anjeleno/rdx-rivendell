#!/usr/bin/env bash
# encoder-wait-ready.sh — Wait for at least one known encoder JACK client to appear.
# Usage: encoder-wait-ready.sh [--timeout SECONDS] [--interval SECONDS] [--clients REGEX] [--strict]
# Defaults: timeout=30s, interval=0.5s, clients="^(liquidsoap|darkice|butt|glasscoder):"
# Exit codes: 0 on success; 0 on timeout by default (soft), or 1 on timeout with --strict; 2 on missing deps/args.
set -euo pipefail

TIMEOUT=30
INTERVAL=0.5
CLIENTS_REGEX='^(liquidsoap|darkice|butt|glasscoder):'
STRICT=0

have() { command -v "$1" >/dev/null 2>&1; }

die() { echo "[encoder-wait] $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout|-t) TIMEOUT=${2:-30}; shift 2;;
    --interval|-i) INTERVAL=${2:-0.5}; shift 2;;
    --clients|-c) CLIENTS_REGEX=${2:-'^(liquidsoap|darkice|butt|glasscoder):'}; shift 2;;
    --strict) STRICT=1; shift;;
    *) die "Unknown arg: $1";;
  esac
done

if ! have jack_lsp; then
  die "jack_lsp not found in PATH"
fi

start_ts=$(date +%s)
end_ts=$(( start_ts + TIMEOUT ))

log_once=true
while :; do
  if jack_lsp -p 2>/dev/null | grep -qiE "${CLIENTS_REGEX}"; then
    echo "[encoder-wait] Encoder JACK client detected (regex: ${CLIENTS_REGEX})."
    exit 0
  fi
  now=$(date +%s)
  if (( now >= end_ts )); then
    if (( STRICT )); then
      echo "[encoder-wait] Timeout after ${TIMEOUT}s waiting for encoder (regex: ${CLIENTS_REGEX})." >&2
      exit 1
    else
      echo "[encoder-wait] Timeout after ${TIMEOUT}s; continuing without encoder (soft)." >&2
      exit 0
    fi
  fi
  if $log_once; then
    echo "[encoder-wait] Waiting up to ${TIMEOUT}s for encoder (regex: ${CLIENTS_REGEX})…"
    log_once=false
  fi
  sleep "${INTERVAL}"
done
