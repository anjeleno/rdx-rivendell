#!/usr/bin/env bash
set -euo pipefail

# RDX OPAM-based Liquidsoap installer (PPA-free)
# - Installs system build dependencies (root)
# - Initializes OPAM per user and builds Liquidsoap with AAC/FFmpeg support (user)
# - Creates a stable shim in ~/.local/bin/liquidsoap so the app can find it

log() { echo "[rdx-opam] $*"; }
warn() { echo "[rdx-opam][WARN] $*" >&2; }
err() { echo "[rdx-opam][ERROR] $*" >&2; }

need_root_pkgs=(
  opam bubblewrap build-essential m4 pkg-config git curl unzip rsync
  libpcre3-dev libtag1-dev libmad0-dev libfaad-dev libfdk-aac-dev
  libasound2-dev libpulse-dev libjack-jackd2-dev
  libavcodec-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev libavfilter-dev
  libssl-dev zlib1g-dev libflac-dev libogg-dev libvorbis-dev libopus-dev libmp3lame-dev libsamplerate0-dev libsoxr-dev
)

# Determine target user when invoked via pkexec or sudo
resolve_target_user() {
  if [ "${EUID}" -ne 0 ]; then
    # Already user context
    id -un
    return 0
  fi
  if [ -n "${PKEXEC_UID:-}" ]; then
    getent passwd "${PKEXEC_UID}" | cut -d: -f1
    return 0
  fi
  if [ -n "${SUDO_UID:-}" ]; then
    echo "${SUDO_USER}"
    return 0
  fi
  # Fallback: attempt logname
  if logname 2>/dev/null; then
    logname
    return 0
  fi
  err "Unable to determine invoking user. Set PKEXEC_UID or run without root."
  return 1
}

apt_install_deps() {
  log "Installing system dependencies (requires root)…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update || true
  # Ensure universe/multiverse for codecs
  if command -v add-apt-repository >/dev/null 2>&1; then
    add-apt-repository -y universe || true
    add-apt-repository -y multiverse || true
    apt-get update || true
  fi
  apt-get install -y --no-install-recommends "${need_root_pkgs[@]}"
}

user_install_opam() {
  local user_home="$1"; shift
  local user_shell="$1"; shift
  local user_name="$1"; shift

  log "Initializing OPAM for user: ${user_name}"

  # Ensure ~/.profile has ~/.local/bin in PATH
  mkdir -p "${user_home}/.local/bin"
  if ! grep -qs 'export PATH=.*\.local/bin' "${user_home}/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${user_home}/.profile"
  fi

  # Non-interactive opam init
  OPAMYES=1 OPAMERRLOGLEN=0 opam init -y --disable-sandboxing || true

  # Create or select switch (prefer OCaml 4.14 for liquidsoap 2.x compatibility)
  if ! opam switch show 2>/dev/null | grep -q '^rdx-liq$'; then
    if ! opam switch create rdx-liq 4.14.2 -y; then
      warn "OCaml 4.14.2 switch failed; trying default compiler"
      opam switch create rdx-liq -y
    fi
  fi
  eval "$(opam env --switch=rdx-liq --set-switch)"

  # Depext + install liquidsoap
  OPAMYES=1 opam install -y opam-depext || true
  OPAMYES=1 opam depext -y liquidsoap || true
  OPAMYES=1 opam install -y liquidsoap

  # Determine liquidsoap binary path
  local opam_bin
  opam_bin="$(opam var bin)" || opam_bin="${user_home}/.opam/rdx-liq/bin"
  local liq_bin="${opam_bin}/liquidsoap"
  if [ ! -x "${liq_bin}" ]; then
    err "Liquidsoap binary not found at ${liq_bin}"
    return 2
  fi

  # Create shim in ~/.local/bin to ensure it's on PATH
  cat > "${user_home}/.local/bin/liquidsoap" <<EOF
#!/usr/bin/env bash
# RDX shim to ensure opam Liquidsoap is used
if [ -f "$HOME/.opam/opam-init/init.sh" ]; then
  . "$HOME/.opam/opam-init/init.sh" >/dev/null 2>&1 || true
fi
exec "${liq_bin}" "$@"
EOF
  chmod +x "${user_home}/.local/bin/liquidsoap"

  # Verify encoders
  if ! "${liq_bin}" -h encoder.fdkaac >/dev/null 2>&1; then
    warn "encoder.fdkaac help not available; will rely on FFmpeg AAC if present"
  fi
  if ! "${liq_bin}" -h encoder.ffmpeg >/dev/null 2>&1; then
    warn "encoder.ffmpeg help not available; check libav* dev packages"
  fi

  # Optional: if FDK-AAC dev libraries are present but encoder not detected, try a one-time rebuild
  if dpkg -s libfdk-aac-dev >/dev/null 2>&1; then
    if ! "${liq_bin}" -h encoder.fdkaac >/dev/null 2>&1; then
      warn "libfdk-aac-dev is installed but encoder.fdkaac not detected. Attempting opam reinstall of liquidsoap…"
      OPAMYES=1 opam reinstall -y liquidsoap || warn "opam reinstall liquidsoap failed; continuing with current build"
      if ! "${liq_bin}" -h encoder.fdkaac >/dev/null 2>&1; then
        warn "FDK-AAC still not detected after rebuild; falling back to FFmpeg AAC in RDX when needed."
      else
        log "FDK-AAC encoder detected after rebuild."
      fi
    fi
  fi

  # Optional: if FFmpeg encoder still not detected, attempt a one-time rebuild to link against dev libs
  if ! "${liq_bin}" -h encoder.ffmpeg >/dev/null 2>&1; then
    warn "FFmpeg encoder not detected. Attempting opam reinstall of liquidsoap to link against FFmpeg dev libs…"
    OPAMYES=1 opam reinstall -y liquidsoap || warn "opam reinstall liquidsoap failed; continuing with current build"
    if ! "${liq_bin}" -h encoder.ffmpeg >/dev/null 2>&1; then
      warn "FFmpeg encoder still not detected after rebuild. AAC via FFmpeg may be unavailable."
    else
      log "FFmpeg encoder detected after rebuild."
    fi
  fi

  log "OPAM Liquidsoap installed at ${liq_bin}"
}

main() {
  local tgt_user
  tgt_user="$(resolve_target_user)"

  if [ "${EUID}" -eq 0 ]; then
    apt_install_deps
    # Run user phase as target user in login shell to pick up opam env
    local home shell
    home="$(getent passwd "${tgt_user}" | cut -d: -f6)"
    shell="$(getent passwd "${tgt_user}" | cut -d: -f7)"
    if [ -z "${home}" ] || [ ! -d "${home}" ]; then
      err "Cannot determine home for ${tgt_user}"
      exit 1
    fi
    log "Switching to user ${tgt_user} for OPAM install"
    su - "${tgt_user}" -c "bash -lc 'set -e; export OPAMYES=1; opam --version >/dev/null 2>&1 || true; $(typeset -f user_install_opam); user_install_opam \"${home}\" \"${shell}\" \"${tgt_user}\"'"
  else
    # User context: just run user phase
    user_install_opam "${HOME}" "${SHELL}" "$(id -un)"
  fi

  log "OPAM installation complete."
}

main "$@"
