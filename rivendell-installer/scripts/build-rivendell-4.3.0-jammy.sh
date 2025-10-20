#!/usr/bin/env bash
set -euo pipefail
trap 'code=$?; echo "[FATAL] build script failed at line $LINENO with exit $code" >&2; exit $code' ERR

cleanup() {
  # Idempotent chroot unmount; only attempt if actually mounted, deepest first
  echo "[INFO] Cleaning up mounts..." >&2
  if command -v findmnt >/dev/null 2>&1; then
    # Collect all mount targets under the chroot and unmount lazily from deepest
    while read -r mnt; do
      [[ -z "$mnt" ]] && continue
      umount -l "$mnt" 2>/dev/null || true
    done < <(findmnt -R -o TARGET "$CHROOT_DIR" 2>/dev/null | tail -n +2 | sort -r)
  else
    # Fallback to individual checks
    mountpoint -q "$CHROOT_DIR/output" && umount -l "$CHROOT_DIR/output" 2>/dev/null || true
    mountpoint -q "$CHROOT_DIR$CCACHE_DIR_CHROOT" && umount -l "$CHROOT_DIR$CCACHE_DIR_CHROOT" 2>/dev/null || true
    mountpoint -q "$CHROOT_DIR/proc" && umount -l "$CHROOT_DIR/proc" 2>/dev/null || true
    mountpoint -q "$CHROOT_DIR/sys" && umount -l "$CHROOT_DIR/sys" 2>/dev/null || true
    mountpoint -q "$CHROOT_DIR/dev" && umount -l "$CHROOT_DIR/dev" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Build Rivendell 4.3.0 .deb packages targeting Ubuntu 22.04 (jammy)
# using a debootstrap chroot on this host. No containers required.
# Results are copied into installer/offline/packages/22.04.

if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root (sudo)." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUT_DIR="$REPO_ROOT/installer/offline/packages/22.04"
CHROOT_DIR="/srv/jammy-riv-build"
CCACHE_DIR_HOST="/srv/jammy-ccache"
CCACHE_DIR_CHROOT="/ccache"
SRC_DIR="/build/rivendell"

mkdir -p "$OUT_DIR" "$CCACHE_DIR_HOST"

echo "[INFO] Installing debootstrap if needed..."
apt-get update -qq
apt-get install -y debootstrap ca-certificates gnupg

if [[ ! -d "$CHROOT_DIR" ]]; then
  echo "[INFO] Creating jammy chroot at $CHROOT_DIR ..."
  debootstrap --variant=buildd jammy "$CHROOT_DIR" http://archive.ubuntu.com/ubuntu
fi

echo "[INFO] Wiring chroot mounts and network..."
cp -f /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf" || true
mountpoint -q "$CHROOT_DIR/proc" || mount -t proc proc "$CHROOT_DIR/proc"
mountpoint -q "$CHROOT_DIR/sys" || mount --rbind /sys "$CHROOT_DIR/sys"
mountpoint -q "$CHROOT_DIR/dev" || mount --rbind /dev "$CHROOT_DIR/dev"

# Bind output dir so we can copy results out easily
mkdir -p "$CHROOT_DIR/output" "$CHROOT_DIR$CCACHE_DIR_CHROOT"
mountpoint -q "$CHROOT_DIR/output" || mount --bind "$OUT_DIR" "$CHROOT_DIR/output"
mountpoint -q "$CHROOT_DIR$CCACHE_DIR_CHROOT" || mount --bind "$CCACHE_DIR_HOST" "$CHROOT_DIR$CCACHE_DIR_CHROOT"

echo "[INFO] Configuring apt sources inside chroot..."
cat >"$CHROOT_DIR/etc/apt/sources.list" <<'SL'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
SL

cat >"$CHROOT_DIR/setup-build.sh" <<'CH'
#!/usr/bin/env bash
set -euo pipefail
trap 'code=$?; echo "[FATAL] chroot build failed at line $LINENO with exit $code" >&2; exit $code' ERR
export DEBIAN_FRONTEND=noninteractive
PRECHECK="${PRECHECK:-0}"
RESUME="${RESUME:-0}"
CHECKDEPS="${CHECKDEPS:-0}"

# Conservative apt options to avoid long stalls
APT_OPTS=(
  -o Acquire::http::Timeout=20
  -o Acquire::https::Timeout=20
  -o Acquire::Retries=1
  -o Dpkg::Use-Pty=0
)

# Avoid locale noise during precheck by using C.UTF-8 (present by default)
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if ! timeout 120s apt-get "${APT_OPTS[@]}" update; then
  echo "[ERROR] apt-get update failed or timed out in chroot (network/mirror issue)." >&2
  exit 90
fi

# Speed up apt/dpkg and compiles, and ensure core build toolchain and deps
if [[ "$PRECHECK" == "1" || "$CHECKDEPS" == "1" ]]; then
  echo "[INFO] Preflight mode (${PRECHECK:+PRECHECK}${CHECKDEPS:+CHECKDEPS}): skipping heavy package installs."
else
  if ! timeout 900s apt-get "${APT_OPTS[@]}" install -y --no-install-recommends \
    apt-utils \
    eatmydata ccache pkg-config dpkg-dev \
    git build-essential debhelper devscripts fakeroot \
    rsync \
    autoconf automake libtool autoconf-archive \
    qtbase5-dev qttools5-dev-tools libqt5sql5-mysql libqt5webkit5-dev \
    libexpat1 libexpat1-dev libssl-dev \
    libsamplerate0-dev libsndfile1-dev libcdparanoia-dev \
    libcoverart-dev libdiscid-dev libmusicbrainz5-dev \
    libid3-3.8.3-dev libtag1-dev libcurl4-gnutls-dev libpam0g-dev \
    libsoundtouch-dev libjack-jackd2-dev libasound2-dev \
    libflac-dev libflac++-dev libmp3lame-dev libmad0-dev libtwolame-dev \
    libmagick++-6.q16-dev \
    libxml2-utils xsltproc \
    python3 python3-pycurl python3-serial python3-requests python3-mysqldb \
    apache2; then
    echo "[ERROR] apt-get install of build dependencies failed or timed out." >&2
    exit 91
  fi
fi

# Quiet locale warnings (optional). Only attempt if files/tools exist.
if [[ -f /etc/locale.gen ]]; then
  sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
fi
if command -v locale-gen >/dev/null 2>&1; then
  locale-gen en_US.UTF-8 || true
fi
if command -v update-locale >/dev/null 2>&1; then
  update-locale LANG=en_US.UTF-8 || true
fi

export CCACHE_DIR="/ccache"
export CC="ccache gcc"
export CXX="ccache g++"
export MAKEFLAGS="-j$(nproc)"
export EATMYDATA=1

rm -rf /build
mkdir -p /build
cd /build

echo "[INFO] Cloning Rivendell v4.3.0..."
git clone --branch v4.3.0 --depth 1 https://github.com/ElvishArtisan/rivendell.git
cd rivendell

# Optional dependency summary without building
if [[ "$CHECKDEPS" == "1" ]]; then
  echo "[INFO] CHECKDEPS mode: installing dpkg-dev (minimal) to run dpkg-checkbuilddeps..."
  if ! timeout 300s apt-get "${APT_OPTS[@]}" install -y --no-install-recommends dpkg-dev >/dev/null; then
    echo "[ERROR] Unable to install dpkg-dev for dependency checking." >&2
    exit 92
  fi
  if [[ -f debian/control ]] && command -v dpkg-checkbuilddeps >/dev/null 2>&1; then
    echo "[INFO] Running dpkg-checkbuilddeps..."
    if dpkg-checkbuilddeps >/tmp/depcheck.out 2>&1; then
      echo "[OK] All build-dependencies are satisfied according to debian/control."
    else
      echo "[WARN] Unmet build-dependencies reported by dpkg-checkbuilddeps:"
      cat /tmp/depcheck.out || true
    fi
  else
    echo "[INFO] Cannot run dpkg-checkbuilddeps (missing debian/control or tool)."
  fi
  echo "[OK] Deps-check phase complete; exiting as requested."
  exit 0
fi

if [[ "$PRECHECK" != "1" ]]; then
  echo "[INFO] Prepare build system..."
  if [[ -x ./configure_build.sh ]]; then ./configure_build.sh || true; fi
  if [[ ! -x ./configure ]]; then autoreconf -i; fi

  echo "[INFO] Configure with docs disabled..."
  ./configure --prefix=/usr \
    --libdir=/usr/lib \
    --libexecdir=/var/www/rd-bin \
    --sysconfdir=/etc/apache2/conf-enabled \
    --enable-rdxport-debug \
    --disable-docbook \
    MUSICBRAINZ_LIBS="-ldiscid -lmusicbrainz5cc -lcoverartcc"
fi

# Ensure Debian packaging disables docs + remove opsguide/manpages
if [[ -f debian/rules ]]; then
  sed -i 's|\./configure |./configure --disable-docbook |' debian/rules || true
  sed -i -E '/opsguide(\.pdf|\b)/Id' debian/rules || true
  sed -i -E '/rivendell-opsguide/Id' debian/rules || true
  sed -i -E '/\/(docs|html)\//Id' debian/rules || true
  sed -i -E '/\/usr\/share\/man\/man[0-9]\//Id' debian/rules || true
  sed -i -E '/^\s*(mv|install)\s+.*man\//Id' debian/rules || true
fi

if [[ -f debian/control ]]; then
  awk 'BEGIN{skip=0} { if ($0 ~ /^Package: rivendell-opsguide$/) {skip=1} if (!skip) print $0; if (skip && $0 ~ /^Package: /) {skip=0; print $0} }' debian/control > debian/control.new || true
  if grep -q '^Package: rivendell-opsguide' debian/control; then mv debian/control.new debian/control; else rm -f debian/control.new; fi
fi

if compgen -G "debian/*.install" > /dev/null; then
  sed -i -E '/opsguide/Id' debian/*.install || true
  sed -i -E '/\/(docs|html)\//Id' debian/*.install || true
  sed -i -E '/\/usr\/share\/man\/man[0-9]\//Id' debian/*.install || true
fi
if compgen -G "debian/*opsguide*.install" > /dev/null; then rm -f debian/*opsguide*.install || true; fi
if compgen -G "debian/*.manpages" > /dev/null; then rm -f debian/*.manpages || true; fi

mkdir -p debian/tmp/usr/share/rivendell || true
touch debian/tmp/usr/share/rivendell/opsguide.pdf || true

if [[ "$PRECHECK" == "1" ]]; then
  if [[ -f debian/control ]] && command -v dpkg-checkbuilddeps >/dev/null 2>&1; then
    echo "[INFO] Checking build-deps (dpkg-checkbuilddeps)..."
    if ! dpkg-checkbuilddeps; then
      echo "[ERROR] Missing build dependencies according to debian/control. See above output." >&2
      exit 3
    fi
  else
    echo "[INFO] Skipping dpkg-checkbuilddeps in PRECHECK (missing debian/control or tool)."
  fi
  echo "[OK] Precheck complete: apt reachable, sources cloned. Ready to build." >&2
  exit 0
fi

echo "[INFO] Build .debs for jammy..."
export DEB_BUILD_OPTIONS="nodoc nocheck parallel=$(nproc)"
dpkg_args=(-b -us -uc)
if [[ "$RESUME" == "1" ]]; then dpkg_args=(-nc "${dpkg_args[@]}"); fi
if ! eatmydata dpkg-buildpackage "${dpkg_args[@]}"; then
  echo "[ERROR] dpkg-buildpackage failed" >&2
  exit 4
fi

echo "[INFO] Copying .debs to /output ..."
shopt -s nullglob
artifacts=(/build/*.deb)
if (( ${#artifacts[@]} == 0 )); then
  echo "[ERROR] No .deb artifacts found in /build after dpkg-buildpackage" >&2
  exit 2
fi
# Require the core package to exist to avoid partial-success situations
if ! compgen -G "/build/rivendell_*_amd64.deb" > /dev/null; then
  echo "[ERROR] Core rivendell_* package missing; treat build as failed." >&2
  ls -l /build || true
  exit 5
fi
cp -f /build/*.deb /output/
shopt -u nullglob

echo "[DONE] Jammy .debs exported."
CH

chmod +x "$CHROOT_DIR/setup-build.sh"

echo "[INFO] Running build in chroot..."
if [[ "${PRECHECK:-0}" == "1" ]]; then
  echo "[INFO] PRECHECK mode enabled: will stop after checking build-deps and preparing sources."
fi
chroot "$CHROOT_DIR" /usr/bin/env PRECHECK="${PRECHECK:-0}" /bin/bash /setup-build.sh

echo "[DONE] Rivendell 4.3.0 .debs placed in: $OUT_DIR"
