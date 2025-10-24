#!/usr/bin/env bash
set -euo pipefail

# Publish a GitHub Release for the RDX Broadcast Control Center with attached .deb asset in a single step.
# Usage:
#   scripts/publish-rdx-release.sh <tag> [--notes-file FILE | --from-changelog]
# Examples:
#   scripts/publish-rdx-release.sh v3.3.1 --notes-file CHANGELOG.md
#   scripts/publish-rdx-release.sh v3.3.1 --from-changelog   # extracts only the v3.3.1 section
#
# Requires: gh CLI authenticated (gh auth login)

TAG=${1:-}
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag> [--notes-file FILE]" >&2
  exit 2
fi
shift || true

NOTES_ARGS=( )
FROM_CHANGELOG=false
if [[ ${1:-} == "--notes-file" && -n ${2:-} ]]; then
  # Safety: if CHANGELOG.md is passed, prefer extracting only this tag's section
  if [[ "$2" == "CHANGELOG.md" || "$2" == "./CHANGELOG.md" ]]; then
    FROM_CHANGELOG=true
    shift 2 || true
  else
    NOTES_ARGS=( --notes-file "$2" )
    shift 2 || true
  fi
elif [[ ${1:-} == "--from-changelog" ]]; then
  FROM_CHANGELOG=true
  shift 1 || true
else
  # Fallback minimal notes if not provided
  NOTES_ARGS=( --notes "RDX Broadcast Control Center ${TAG}" )
fi

# Locate asset in releases/ matching the tag version.
VER=${TAG#v}
ASSET="releases/rdx-broadcast-control-center_${VER}_amd64.deb"
if [[ ! -f "$ASSET" ]]; then
  echo "Error: Asset not found: $ASSET" >&2
  exit 1
fi

# Ensure idempotency: delete existing release if present (keep tag)
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Deleting existing release $TAG (keeping tag)..."
  gh release delete -y "$TAG"
fi

echo "Creating release $TAG with asset $ASSET..."
if $FROM_CHANGELOG; then
  # Extract only the section for this tag and use it as notes
  NOTES_TMP=$(mktemp)
  python3 scripts/extract-changelog-section.py "$TAG" CHANGELOG.md > "$NOTES_TMP"
  gh release create "$TAG" "$ASSET" --title "$TAG" --notes-file "$NOTES_TMP"
  rm -f "$NOTES_TMP"
else
  # Single-step create with asset attached
  gh release create "$TAG" "$ASSET" --title "$TAG" "${NOTES_ARGS[@]}"
fi

# Verify asset presence
ASSET_COUNT=$(gh release view "$TAG" --json assets -q '.assets | length')
if [[ "$ASSET_COUNT" -lt 1 ]]; then
  echo "Release $TAG created without assets. Retrying upload..." >&2
  gh release upload "$TAG" "$ASSET" --clobber
fi

echo "Done. Release URL: $(gh release view "$TAG" --json url -q .url)"
