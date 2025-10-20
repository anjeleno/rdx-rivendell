#!/usr/bin/env bash
set -euo pipefail

# Collect exact .debs for a target Ubuntu series (jammy|noble) into
# installer/offline/packages/<22.04|24.04> without using containers.
# It uses a separate APT root with a custom sources.list for the target series.
#
# Usage:
#   scripts/collect-debs.sh <jammy|noble> <rivendell_version>
# Example:
#   scripts/collect-debs.sh jammy 4.3.0
#   scripts/collect-debs.sh noble 4.3.0

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <jammy|noble> <rivendell_version> [--include-mate]" >&2
  exit 1
fi

series="$1"; rver="$2"
case "$series" in
  jammy) codename_dir="22.04";;
  noble) codename_dir="24.04";;
  *) echo "Series must be jammy or noble" >&2; exit 1;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUT_DIR="$ROOT_DIR/installer/offline/packages/$codename_dir"
OUT_BASE="$OUT_DIR/base"
OUT_MATE="$OUT_DIR/mate"
LIST_DIR="$ROOT_DIR/installer/offline/package-lists"
LIST_FILE="$LIST_DIR/$series.txt"

if [[ ! -f "$LIST_FILE" ]]; then
  echo "Package list not found: $LIST_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_BASE"

TMPROOT="/tmp/riv-apt-$series"
rm -rf "$TMPROOT"
mkdir -p "$TMPROOT/etc/apt" "$TMPROOT/var/lib/apt/lists/partial" "$TMPROOT/var/cache/apt/archives/partial"

# Minimal sources for the target series: main/universe/multiverse and Paravel Rivendell repo if needed
cat >"$TMPROOT/etc/apt/sources.list" <<EOF
deb http://archive.ubuntu.com/ubuntu $series main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $series-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $series-security main restricted universe multiverse
# Paravel Rivendell repository (adjust if needed). Use trusted=yes inside isolated root to avoid key prompts.
deb [arch=amd64 trusted=yes] https://software.paravelsystems.com/ubuntu $series main
EOF

APT_OPTS=(
  -o Dir::Etc::sourcelist="$TMPROOT/etc/apt/sources.list"
  -o Dir::Etc::sourceparts="-"
  -o Dir::State::Lists="$TMPROOT/var/lib/apt/lists"
  -o Dir::Cache::Archives="$TMPROOT/var/cache/apt/archives"
  -o Dir::State::Status="$TMPROOT/var/lib/dpkg/status"
  -o Debug::NoLocking=1
)

echo "[INFO] Updating APT for $series..."
if ! apt-get "${APT_OPTS[@]}" update; then
  echo "[WARN] apt-get update reported errors (likely third-party repo unavailable). Proceeding with available indexes."
fi

# Try to prefer rivendell 4.3.0 by pinning if multiple versions exist
mkdir -p "$TMPROOT/etc/apt/preferences.d"
cat >"$TMPROOT/etc/apt/preferences.d/rivendell" <<PREF
Package: rivendell*
Pin: version $rver*
Pin-Priority: 1001
PREF

echo "[INFO] Resolving and downloading packages from $LIST_FILE"

# Let apt compute dependencies and download all .debs to the cache
apt-get "${APT_OPTS[@]}" -y --download-only install $(grep -vE '^(#|\s*$)' "$LIST_FILE" | sed '/^EOL$/d') || {
  echo "[WARN] Initial download attempt failed; check if rivendell $rver is available for $series." >&2
}

echo "[INFO] Copying base .debs to $OUT_BASE (skip existing)"
BASE_MANIFEST="$OUT_BASE/.files.txt"
touch "$BASE_MANIFEST"
shopt -s nullglob
for deb in "$TMPROOT/var/cache/apt/archives"/*.deb; do
  base=$(basename "$deb")
  if [[ ! -e "$OUT_BASE/$base" ]]; then
    cp "$deb" "$OUT_BASE/"
    echo "$base" >> "$BASE_MANIFEST"
  fi
done
shopt -u nullglob

count=$(ls -1 "$OUT_BASE"/*.deb 2>/dev/null | wc -l || true)
echo "[INFO] Collected $count base debs for $series into $OUT_BASE"

echo "[HINT] If rivendell $rver was not downloaded, verify repository availability or build .debs and place them into $OUT_DIR manually."

# Optionally collect MATE offline bundle
if [[ "${3:-}" == "--include-mate" ]]; then
  case "$series" in
    jammy) mate_list="$LIST_DIR/mate-jammy.txt";;
    noble) mate_list="$LIST_DIR/mate-noble.txt";;
  esac
  if [[ -f "$mate_list" ]]; then
    mkdir -p "$OUT_MATE"
    echo "[INFO] Downloading MATE desktop bundle from $mate_list"
    apt-get "${APT_OPTS[@]}" -y --download-only install $(grep -vE '^(#|\s*$)' "$mate_list") || {
      echo "[WARN] MATE bundle download encountered issues; some packages may be missing." >&2
    }
    echo "[INFO] Copying MATE .debs to $OUT_MATE (skip existing)"
    MATE_MANIFEST="$OUT_MATE/.files.txt"
    touch "$MATE_MANIFEST"
    shopt -s nullglob
    for deb in "$TMPROOT/var/cache/apt/archives"/*.deb; do
      base=$(basename "$deb")
      if [[ ! -e "$OUT_MATE/$base" ]]; then
        cp "$deb" "$OUT_MATE/"
        echo "$base" >> "$MATE_MANIFEST"
      fi
    done
    shopt -u nullglob
    mcount=$(ls -1 "$OUT_MATE"/*.deb 2>/dev/null | wc -l || true)
    echo "[INFO] Collected $mcount MATE debs for $series into $OUT_MATE"
  fi
fi
