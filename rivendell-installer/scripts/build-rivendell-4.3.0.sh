#!/usr/bin/env bash
set -euo pipefail

# Build Rivendell 4.3.0 .deb packages on Ubuntu 24.04 (noble)
# and copy resulting .debs into installer/offline/packages/24.04

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUT_DIR="$REPO_ROOT/installer/offline/packages/24.04"
BUILD_DIR="/tmp/rivendell-build-4.3.0"
SRC_DIR="$BUILD_DIR/rivendell"

series=$(lsb_release -rs 2>/dev/null || true)
if [[ "${series:-}" != 24.04* ]]; then
  echo "This builder is intended for Ubuntu 24.04 (noble). Detected: ${series:-unknown}" >&2
  echo "Proceeding anyway, but results may not be noble-targeted."
fi

sudo apt-get update

# Install build dependencies per upstream INSTALL (trimmed to essentials)
sudo apt-get install -y \
  git build-essential debhelper devscripts fakeroot \
  autoconf automake libtool autoconf-archive \
  qtbase5-dev qttools5-dev-tools libqt5sql5-mysql libqt5webkit5-dev \
  libexpat1 libexpat1-dev libssl-dev \
  libsamplerate0-dev libsndfile1-dev libcdparanoia-dev \
  libcoverart-dev libdiscid-dev libmusicbrainz5-dev \
  libid3-dev libtag1-dev libcurl4-gnutls-dev libpam0g-dev \
  libsoundtouch-dev libjack-jackd2-dev libasound2-dev \
  libflac-dev libflac++-dev libmp3lame-dev libmad0-dev libtwolame-dev \
  libmagick++-dev \
  docbook5-xml libxml2-utils docbook-xsl-ns xsltproc fop \
  python3 python3-pycurl python3-serial python3-requests python3-mysqldb \
  apache2 gnupg pbuilder ubuntu-dev-tools apt-file

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"
cd "$BUILD_DIR"

echo "[INFO] Cloning Rivendell v4.3.0..."
git clone --branch v4.3.0 --depth 1 https://github.com/ElvishArtisan/rivendell.git
cd "$SRC_DIR"

echo "[INFO] Preparing configure/build system..."
if [[ -x ./configure_build.sh ]]; then
  ./configure_build.sh || true
fi
if [[ ! -x ./configure ]]; then
  echo "[INFO] Running autoreconf to generate configure..."
  autoreconf -i
fi

echo "[INFO] Configuring for Ubuntu 24.04..."
if [[ -x ./configure ]]; then
  ./configure --prefix=/usr \
    --libdir=/usr/lib \
    --libexecdir=/var/www/rd-bin \
    --sysconfdir=/etc/apache2/conf-enabled \
    --enable-rdxport-debug \
    --disable-docbook \
    MUSICBRAINZ_LIBS="-ldiscid -lmusicbrainz5cc -lcoverartcc"
fi

# Ensure Debian packaging also disables docbook (debian/rules runs its own configure)
if [[ -f debian/rules ]]; then
  echo "[INFO] Patching debian/rules to add --disable-docbook"
  sed -i 's|\./configure |./configure --disable-docbook |' debian/rules || true
  echo "[INFO] Stripping opsguide + manpage handling to avoid failures when docs are disabled"
  # Remove opsguide and HTML doc moves/dirs
  sed -i -E '/opsguide(\.pdf|\b)/Id' debian/rules || true
  sed -i -E '/rivendell-opsguide/Id' debian/rules || true
  sed -i -E '/\/(docs|html)\//Id' debian/rules || true
  # Remove any explicit manpage moves/dirs from rules (when nodoc, manpages may not be generated)
  sed -i -E '/\/usr\/share\/man\/man[0-9]\//Id' debian/rules || true
  sed -i -E '/^\s*(mv|install)\s+.*man\//Id' debian/rules || true
fi

# Remove opsguide packaging if present (prevents dpkg failures when docs are disabled)
if [[ -f debian/control ]]; then
  echo "[INFO] Removing rivendell-opsguide package stanza if present"
  awk 'BEGIN{skip=0} {
    if ($0 ~ /^Package: rivendell-opsguide$/) {skip=1}
    if (!skip) print $0;
    if (skip && $0 ~ /^Package: /) {skip=0; print $0}
  }' debian/control > debian/control.new || true
  if grep -q '^Package: rivendell-opsguide' debian/control; then
    mv debian/control.new debian/control
  else
    rm -f debian/control.new
  fi
fi

if compgen -G "debian/*.install" > /dev/null; then
  echo "[INFO] Cleaning opsguide lines from debian/*.install files"
  sed -i -E '/opsguide/Id' debian/*.install || true
  sed -i -E '/\/(docs|html)\//Id' debian/*.install || true
  # Also drop explicit manpage paths from .install if any snuck in
  sed -i -E '/\/usr\/share\/man\/man[0-9]\//Id' debian/*.install || true
fi

# If an opsguide .install file exists, remove it entirely
if compgen -G "debian/*opsguide*.install" > /dev/null; then
  echo "[INFO] Removing opsguide .install files"
  rm -f debian/*opsguide*.install || true
fi

# If any explicit manpage lists exist, clear them so dh_installman skips
if compgen -G "debian/*.manpages" > /dev/null; then
  echo "[INFO] Removing debian/*.manpages entries (docs disabled)"
  rm -f debian/*.manpages || true
fi

# Fallback: if debian/rules still references an opsguide.pdf move, pre-create a dummy to avoid mv failure
mkdir -p debian/tmp/usr/share/rivendell || true
touch debian/tmp/usr/share/rivendell/opsguide.pdf || true

echo "[INFO] Building .debs (skipping docs)..."
# Prefer Debian packaging paths and skip docs to avoid docbook generation failures
export DEB_BUILD_OPTIONS="nodoc nocheck parallel=$(nproc)"
if [[ -x ./build_debs.sh ]]; then
  DEB_BUILD_OPTIONS="$DEB_BUILD_OPTIONS" ./build_debs.sh || true
fi
if [[ -d debian ]]; then
  DEB_BUILD_OPTIONS="$DEB_BUILD_OPTIONS" dpkg-buildpackage -b -us -uc || true
fi

echo "[INFO] Copying resulting .debs to $OUT_DIR"
shopt -s nullglob
for deb in "$BUILD_DIR"/*.deb; do
  cp -f "$deb" "$OUT_DIR/"
done
shopt -u nullglob

echo "[DONE] Rivendell 4.3.0 .debs placed in: $OUT_DIR"
