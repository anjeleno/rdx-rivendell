#!/usr/bin/env bash
#
# Rivendell offline installer builder
#
# Full usage (examples):
#   # Build ONLY the base installer (no MATE bundles)
#   /root/rivendell-cloud/installer/offline/build-makeself.sh --base-only
#   bash /root/rivendell-cloud/installer/offline/build-makeself.sh --base-only
#
#   # Build ONLY the MATE bundle for 24.04
#   /root/rivendell-cloud/installer/offline/build-makeself.sh --mate-only --series=24.04
#
#   # Build BOTH base installer and MATE bundles for 22.04 and 24.04 (default)
#   /root/rivendell-cloud/installer/offline/build-makeself.sh
#
#   # Override version/date in output filenames
#   /root/rivendell-cloud/installer/offline/build-makeself.sh --base-only \
#       --version=0.1.2 --date=20251019
#
# Output artifacts:
#   dist/rivendell-installer-<version>-<date>.run
#   dist/rivendell-mate-bundle-<series>-<version>-<date>.run
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
OFFLINE_DIR="$ROOT_DIR/installer/offline"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

if ! command -v makeself >/dev/null 2>&1; then
  echo "makeself not found. Install it (sudo apt install makeself) and retry." >&2
  exit 1
fi

VERSION="0.1.1"
DATE="$(date +%Y%m%d)"

# Defaults: build both base and mate bundles
BUILD_BASE=1
BUILD_MATE=1
SERIES_LIST=("22.04" "24.04")

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --base-only, -B         Build only the base installer (.run), skip MATE bundles
  --mate-only, -M         Build only the MATE bundle(s), skip base installer
  --series=LIST           Comma-separated series for MATE bundles (default: 22.04,24.04)
  --version=V             Override version string (default: $VERSION)
  --date=YYYYMMDD         Override date stamp (default: current date)
  --help, -h              Show this help and exit

Examples:
  $(basename "$0") --base-only
  $(basename "$0") --mate-only --series=24.04
EOF
}

# Parse simple CLI flags
for arg in "$@"; do
  case "$arg" in
    --base-only|-B)
      BUILD_BASE=1; BUILD_MATE=0 ;;
    --mate-only|-M)
      BUILD_BASE=0; BUILD_MATE=1 ;;
    --series=*)
      IFS=',' read -r -a SERIES_LIST <<< "${arg#*=}" ;;
    --version=*)
      VERSION="${arg#*=}" ;;
    --date=*)
      DATE="${arg#*=}" ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

if [[ "$BUILD_BASE" -eq 1 ]]; then
  # Prepare a temporary staging area for the base installer; exclude MATE subfolders entirely
  STAGE_BASE="$(mktemp -d)"
  rsync -a --exclude 'packages/*/mate' "$OFFLINE_DIR/" "$STAGE_BASE/"

  # Build base installer (no MATE)
  BASE_OUT="$DIST_DIR/rivendell-installer-$VERSION-$DATE.run"
  makeself --gzip \
    "$STAGE_BASE" \
    "$BASE_OUT" \
    "Rivendell Offline Installer" \
    bash ./driver.sh
  echo "Created $BASE_OUT"
fi

# Build per-series MATE bundles if directories exist
build_mate_bundle() {
  local series_dir="$1"
  local src_dir="$OFFLINE_DIR/packages/$series_dir/mate"
  [[ -d "$src_dir" ]] || return 0
  local stage_mate
  stage_mate="$(mktemp -d)"
  mkdir -p "$stage_mate/packages/$series_dir/mate"
  echo "[INFO] Building MATE bundle for series $series_dir"
  cp "$src_dir"/*.deb "$stage_mate/packages/$series_dir/mate/" 2>/dev/null || true
  # Include a tiny runner that installs from this cache
  cat > "$stage_mate/install-mate.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
SERIES="$(ls packages | head -n1)"
DEB_DIR="packages/$SERIES/mate"
echo "Installing MATE from local cache: $DEB_DIR"
apt-get -y -o Dir::Cache::Archives="$DEB_DIR" --no-download install ubuntu-mate-desktop lightdm dbus-x11 \
  || apt-get -y -o Dir::Cache::Archives="$DEB_DIR" --no-download install mate-desktop-environment lightdm dbus-x11 \
  || { dpkg -i "$DEB_DIR"/*.deb || true; apt-get -y -f install; }
echo "Setting LightDM as default display manager"
apt-get -y install lightdm debconf-utils || true
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections || true
dpkg-reconfigure -f noninteractive lightdm || true
echo "MATE installation done."
EOS
  chmod +x "$stage_mate/install-mate.sh"
  local mate_out="$DIST_DIR/rivendell-mate-bundle-$series_dir-$VERSION-$DATE.run"
  makeself --gzip "$stage_mate" "$mate_out" "Rivendell MATE Bundle $series_dir" bash ./install-mate.sh
  echo "Created $mate_out"
}

if [[ "$BUILD_MATE" -eq 1 ]]; then
  for s in "${SERIES_LIST[@]}"; do
    build_mate_bundle "$s" || true
  done
fi

echo "All artifacts created in $DIST_DIR"
