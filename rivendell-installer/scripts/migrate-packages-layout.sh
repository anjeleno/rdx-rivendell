#!/usr/bin/env bash
set -euo pipefail

# One-time migration: move .deb files from installer/offline/packages/<series>
# into base/ and mate/ subdirectories.
# Heuristics:
# - Prefer existing manifest: .mate-files.txt listing MATE filenames
# - Otherwise, use package name prefixes from installer/offline/package-lists/mate-*.txt

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
PKG_ROOT="$ROOT_DIR/installer/offline/packages"
LIST_DIR="$ROOT_DIR/installer/offline/package-lists"

series_dirs=(22.04 24.04)

for s in "${series_dirs[@]}"; do
  src_dir="$PKG_ROOT/$s"
  [[ -d "$src_dir" ]] || continue
  base_dir="$src_dir/base"
  mate_dir="$src_dir/mate"
  mkdir -p "$base_dir" "$mate_dir"

  # Build mate filename set and prefix list
  declare -A mate_file_set=()
  mate_prefixes=()
  if [[ -f "$src_dir/.mate-files.txt" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      mate_file_set["$f"]=1
    done < "$src_dir/.mate-files.txt"
  else
    case "$s" in
      22.04) list="$LIST_DIR/mate-jammy.txt";;
      24.04) list="$LIST_DIR/mate-noble.txt";;
      *) list="";;
    esac
    if [[ -n "${list:-}" && -f "$list" ]]; then
      while IFS= read -r p; do
        [[ -z "$p" || "$p" =~ ^# ]] && continue
        mate_prefixes+=("$p")
      done < "$list"
    fi
  fi

  moved_any=false
  shopt -s nullglob
  for deb in "$src_dir"/*.deb; do
    fname=$(basename "$deb")
    # Skip if this deb is already inside base/ or mate/
    [[ "$deb" == *"/base/"* || "$deb" == *"/mate/"* ]] && continue
    dest="$base_dir"
    if [[ ${#mate_file_set[@]} -gt 0 ]]; then
      if [[ -n "${mate_file_set[$fname]:-}" ]]; then dest="$mate_dir"; fi
    elif [[ ${#mate_prefixes[@]} -gt 0 ]]; then
      for pref in "${mate_prefixes[@]}"; do
        if [[ "$fname" == "$pref"_* ]]; then dest="$mate_dir"; break; fi
      done
    fi
    mv -n "$deb" "$dest/"
    moved_any=true
  done
  shopt -u nullglob

  # Generate manifests
  if compgen -G "$base_dir/*.deb" >/dev/null; then
    : > "$base_dir/.files.txt"
    for f in "$base_dir"/*.deb; do echo "$(basename "$f")" >> "$base_dir/.files.txt"; done
  fi
  if compgen -G "$mate_dir/*.deb" >/dev/null; then
    : > "$mate_dir/.files.txt"
    for f in "$mate_dir"/*.deb; do echo "$(basename "$f")" >> "$mate_dir/.files.txt"; done
  fi

  echo "[INFO] Series $s migrated. Base: $(ls -1 "$base_dir"/*.deb 2>/dev/null | wc -l || true), Mate: $(ls -1 "$mate_dir"/*.deb 2>/dev/null | wc -l || true)"
done

echo "[DONE] Migration complete."
