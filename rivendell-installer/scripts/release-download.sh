#!/usr/bin/env bash
set -euo pipefail

# Download a release asset from a private or public GitHub repo.
# Prefers gh CLI if available; falls back to GitHub REST API using GH_TOKEN/GITHUB_TOKEN
# or a token discovered in ~/.git-credentials (repo scope required for private repos).
#
# Usage:
#   scripts/release-download.sh [-R owner/repo] <tag> <asset-name> [<asset-name> ...]
# Example:
#   scripts/release-download.sh -R anjeleno/rivendell-installer v0.1.1-20251019 \
#     rivendell-mate-bundle-24.04-0.1.1-20251019.run SHA256SUMS.txt

OWNER_REPO_ARG=""
if [[ "${1:-}" == "-R" ]]; then
  OWNER_REPO_ARG=${2:-}
  shift 2 || true
fi

TAG=${1:-}
shift || true
if [[ -z "${TAG}" || $# -lt 1 ]]; then
  echo "Usage: $0 [-R owner/repo] <tag> <asset-name> [<asset-name> ...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OWNER_REPO=${OWNER_REPO_ARG:-${OWNER_REPO:-}}
if [[ -z "$OWNER_REPO" ]]; then
  # Try to infer from a local git repo if available
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ORIGIN_URL=$(git -C "$REPO_ROOT" remote get-url origin)
    OWNER_REPO=$(echo "$ORIGIN_URL" | sed -E 's#.*github.com[:/]+([^/]+/[^/.]+)(\.git)?$#\1#')
  fi
fi
if [[ -z "$OWNER_REPO" ]]; then
  echo "Error: Missing owner/repo. Provide -R owner/repo or set OWNER_REPO env var." >&2
  exit 1
fi

if command -v gh >/dev/null 2>&1; then
  echo "Using gh CLI to download from $OWNER_REPO @$TAG..."
  gh release download "$TAG" -R "$OWNER_REPO" $(printf ' -p %q' "$@")
  exit 0
fi

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${TOKEN}" && -f "$HOME/.git-credentials" ]]; then
  # Avoid echoing secrets if xtrace is enabled
  _xtrace_state=$(set +o | grep xtrace || true)
  set +x 2>/dev/null || true
  CRED_LINE=$(grep -m1 'github.com' "$HOME/.git-credentials" || true)
  if [[ -n "$CRED_LINE" ]]; then
    DISCOVERED_TOKEN=$(echo "$CRED_LINE" | sed -E 's#https://[^:]+:([^@]+)@github.com.*#\1#')
    if [[ -n "$DISCOVERED_TOKEN" && "$DISCOVERED_TOKEN" != "$CRED_LINE" ]]; then
      TOKEN="$DISCOVERED_TOKEN"
      echo "Using token from ~/.git-credentials for github.com"
    fi
  fi
  eval "$_xtrace_state"
fi

if [[ -z "$TOKEN" ]]; then
  echo "Error: gh not found and GH_TOKEN/GITHUB_TOKEN not set; cannot download private assets." >&2
  exit 1
fi

API="https://api.github.com/repos/$OWNER_REPO"
REL=$(curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/releases/tags/$TAG")

# For each requested asset, resolve id and download
for name in "$@"; do
  if command -v jq >/dev/null 2>&1; then
    ID=$(printf '%s' "$REL" | jq -r --arg n "$name" '.assets[] | select(.name==$n) | .id')
  else
    ID=$(printf '%s' "$REL" | awk -v n="$name" '/"assets":/{inassets=1} inassets && /"name":/ {gsub(/[",]/,""); nm=$2} inassets && /"id":/ {sub(/,$/,"",$2); id=$2} inassets && nm==n {print id; exit}')
  fi
  if [[ -z "$ID" || "$ID" == "null" ]]; then
    echo "Asset not found in release: $name" >&2
    exit 1
  fi
  echo "Downloading $name..."
  curl --http1.1 -L \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/octet-stream" \
    -o "$name" \
    "$API/releases/assets/$ID"
  echo "Saved $name"
done
