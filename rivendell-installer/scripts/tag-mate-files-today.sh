#!/usr/bin/env bash
set -euo pipefail

# Tag .deb files modified since midnight today as the MATE bundle for each series.
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
PKG_DIR="$BASE_DIR/installer/offline/packages"

# Build a marker file for midnight today in local time
MARKER="/tmp/mate_today_marker"
YMD=$(date +%Y%m%d)
rm -f "$MARKER"
# touch -t expects [[CC]YY]MMDDhhmm[.ss]
touch -t ${YMD}0000 "$MARKER"

for series in 22.04 24.04; do
  dir="$PKG_DIR/$series"
  if [ ! -d "$dir" ]; then
    echo "[SKIP] $dir (not found)"
    continue
  fi
  echo "[SCAN] $dir"
  # List basenames of .deb files newer than the marker (today)
  mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name '*.deb' -newer "$MARKER" -printf '%f\n' | sort)
  count=${#files[@]}
  echo "New-today count: $count"
  if [ "$count" -gt 0 ]; then
    manifest="$dir/.mate-files.txt"
    : > "$manifest"
    for f in "${files[@]}"; do
      echo "$f" >> "$manifest"
    done
    echo "[WROTE] $manifest"
    for f in "${files[@]}"; do echo "  - $f"; done
  fi
done
