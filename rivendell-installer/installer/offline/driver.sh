#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Prevent tzdata from prompting under remote shells
export TZ="${TZ:-$(cat /etc/timezone 2>/dev/null || echo Etc/UTC)}"

# Offline installer driver (TUI first, GUI optional if zenity found)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
PKG_DIR="$SCRIPT_DIR/packages"
WORK_DIR="/tmp/rivendell-installer"

mkdir -p "$WORK_DIR"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

use_gui=false
ZENITY_USER=""
if have_cmd zenity && [[ -n "${DISPLAY:-}" ]]; then
  use_gui=true
  # Prefer to display dialogs as the invoking desktop user, not root
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    ZENITY_USER="$SUDO_USER"
  else
    # Fallback to the logged-in console user if available
    u=$(logname 2>/dev/null || true)
    if [[ -n "$u" && "$u" != "root" ]]; then
      ZENITY_USER="$u"
    fi
  fi
fi

# Helper to run zenity as the desktop user so dialogs can display in GUI sessions
run_zenity() {
  # Usage: run_zenity <args...>
  if [[ -n "$ZENITY_USER" ]]; then
    sudo -u "$ZENITY_USER" -H env DISPLAY="$DISPLAY" XAUTHORITY="${XAUTHORITY:-/home/$ZENITY_USER/.Xauthority}" zenity "$@"
  else
    zenity "$@"
  fi
}

ask_select() {
  local title="$1"; shift
  local choices=("$@")
  if $use_gui; then
    run_zenity --list --title "$title" --column Options "${choices[@]}" || \
    whiptail --title "$title" --menu "Use arrows/Enter to choose" 15 60 4 "${choices[@]}" 3>&1 1>&2 2>&3
  else
    whiptail --title "$title" --menu "Use arrows/Enter to choose" 15 60 4 "${choices[@]}" 3>&1 1>&2 2>&3
  fi
}

ask_yesno() {
  local title="$1"
  if $use_gui; then
    run_zenity --question --text "$title"
    local rc=$?
    # If GUI question failed to show (e.g., no X perms), fallback to TUI
    if [[ $rc -eq 0 || $rc -eq 1 ]]; then return $rc; fi
    whiptail --yesno "$title" 10 60
    return $?
  else
    whiptail --yesno "$title" 10 60
    return $?
  fi
}

ask_input() {
  local prompt="$1"; local default_val="$2"
  if $use_gui; then
    run_zenity --entry --title "Input" --text "$prompt" --entry-text "$default_val" || \
    whiptail --inputbox "$prompt" 10 60 "$default_val" 3>&1 1>&2 2>&3
  else
    whiptail --inputbox "$prompt" 10 60 "$default_val" 3>&1 1>&2 2>&3
  fi
}

# Hidden password prompt
ask_password() {
  local prompt="$1"
  if $use_gui; then
    run_zenity --entry --title "Password" --text "$prompt" --hide-text || \
    whiptail --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3
  else
    whiptail --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root (or via sudo)." >&2
    exit 1
  fi
}

detect_series() {
  lsb_release -rs 2>/dev/null | cut -d. -f1,2
}

series="$(detect_series)"
case "$series" in
  22.04|24.04) :;;
  *) echo "Unsupported Ubuntu release: $series. Supported: 22.04, 24.04" >&2; exit 1;;
esac

require_root

# Gather choices
install_type=$(ask_select "Installation Type" Standalone Server Client || echo "Standalone")
hostname_val=$(ask_input "Hostname (Rivendell requires match)" "onair" || echo "onair")
set_tz=false; if ask_yesno "Configure timezone now?"; then set_tz=true; fi
enable_ufw=false; if ask_yesno "Enable UFW and open required ports?"; then enable_ufw=true; fi
harden_ssh=false; if ask_yesno "Harden SSH (disable password auth)? Ensure SSH keys work first."; then harden_ssh=true; fi
install_mate=false; if ask_yesno "Install MATE desktop (optional)?"; then install_mate=true; fi

# Decide target user (for desktop seeding), but always provision rd for Rivendell
target_user="${SUDO_USER:-${USER}}"
create_rd=true

echo "Series: $series"
echo "Type: $install_type"
echo "Hostname: $hostname_val"
echo "Target user: $target_user (create rd: $create_rd)"

log() { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

# Central DB log for visibility of all DB steps
DB_LOG="/var/log/rivendell-cloud-db.log"
dblog() {
  mkdir -p /var/log
  # Mask any password-looking substrings in log lines
  local msg="$*"
  msg="${msg//DbPassword=[^ ]*/DbPassword=****}"
  msg="${msg//Password=[^ ]*/Password=****}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $msg" >> "$DB_LOG"
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get -yq install "$@"
}

ensure_packages() {
  log "Installing base dependencies..."
  apt-get update -yq || true
  apt_install software-properties-common apt-transport-https ca-certificates gnupg \
    apt-utils tzdata whiptail zenity curl jq git sudo
}

set_hostname() {
  if [[ -n "$hostname_val" && "$hostname_val" != "$(hostname)" ]]; then
    log "Setting hostname to $hostname_val"
    hostnamectl set-hostname "$hostname_val" || true
    sed -i "/127.0.1.1/d" /etc/hosts || true
    echo "127.0.1.1 $hostname_val" >> /etc/hosts
  fi
}

set_timezone() {
  if $set_tz; then
    tz=$(ask_input "Enter timezone (e.g. America/Chicago)" "$(cat /etc/timezone 2>/dev/null || echo UTC)" || echo "UTC")
    log "Setting timezone to $tz"
    timedatectl set-timezone "$tz" || true
  fi
}

ensure_user() {
  # Ensure rd exists and is in key groups
  if ! id -u rd >/dev/null 2>&1; then
    log "Creating user rd"
    useradd -m -s /bin/bash rd
    # Prompt and set a password for rd
    local pw1 pw2 attempts=0
    while (( attempts < 3 )); do
      pw1=$(ask_password "Set password for user 'rd'") || pw1=""
      pw2=$(ask_password "Confirm password for user 'rd'") || pw2=""
      if [[ -n "$pw1" && "$pw1" == "$pw2" ]]; then
        echo "rd:$pw1" | chpasswd && break
      fi
      attempts=$((attempts+1))
      log "Passwords did not match or were empty. Try again ($attempts/3)."
    done
    if (( attempts == 3 )); then
      log "Password for rd not set (skipped after 3 attempts). You can set it later with 'passwd rd'."
    fi
  fi
  usermod -aG sudo,audio,pulse,pulse-access,adm,cdrom,video rd || true
  mkdir -p /home/rd /home/rd/imports /home/rd/logs
  chown -R rd:rd /home/rd

  # Also make sure target_user has a home and ownership (for Desktop seeding)
  mkdir -p "/home/$target_user"
  chown -R "$target_user:$target_user" "/home/$target_user"
}

configure_limits() {
  log "Configuring realtime and memlock limits"
  cat >/etc/security/limits.d/rivendell.conf <<EOF
@audio   -  rtprio     95
@audio   -  memlock    unlimited
EOF
}

install_local_debs() {
  local d_base="$PKG_DIR/$series/base"
  log "Installing Rivendell 4.3.0 from local packages: $d_base"
  if compgen -G "$d_base/*.deb" >/dev/null; then
    apt_install gdebi-core || true
    # Install in a single dpkg invocation to satisfy inter-deps; then fix with apt -f
    dpkg -i "$d_base"/*.deb || true
    apt-get -yq -f install
  else
    fail "No base .deb packages found in $d_base"
  fi
}

# Additional workstation apps Rivendell users expect
install_media_apps() {
  log "Installing media apps (qjackctl, vlc, liquidsoap, jackd2)"
  apt_install qjackctl vlc vlc-plugin-jack liquidsoap jackd2 pulseaudio-module-jack || true
}

install_xrdp_desktop() {
  log "Installing xrdp and optional desktop"
  apt_install xrdp dbus-x11
  if $install_mate; then
    # Prefer offline MATE bundle if .debs are present for this series
    local d_mate="$PKG_DIR/$series/mate"; local mate_debs_count=0
    mate_debs_count=$(ls -1 "$d_mate"/*.deb 2>/dev/null | wc -l || true)
    if (( mate_debs_count > 0 )); then
      log "Installing MATE from local packages (no-download)"
      # Use apt to resolve dependencies but only consume from local cache folder
      apt-get -y -o Dir::Cache::Archives="$d_mate" --no-download install ubuntu-mate-desktop lightdm dbus-x11 \
        || apt-get -y -o Dir::Cache::Archives="$d_mate" --no-download install mate-desktop-environment lightdm dbus-x11 \
        || { log "Offline MATE install via apt failed; attempting dpkg fallback"; dpkg -i "$d_mate"/*.deb || true; apt-get -yq -f install; }
    else
      log "Installing MATE via apt (online)"
      apt_install ubuntu-mate-desktop || apt_install mate-desktop-environment
    fi
    # Set LightDM as display manager to avoid Wayland/GDM issues for xRDP
    apt_install lightdm debconf-utils || true
    echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections || true
    dpkg-reconfigure -f noninteractive lightdm || true
  fi
  systemctl enable xrdp || true
  systemctl restart xrdp || true
}

# For Client installs: prompt for remote DB connection and write to /etc/rd.conf
configure_client_rd_conf() {
  # Only run if Client and rd.conf exists
  [[ "$install_type" == "Client" ]] || return 0
  [[ -f /etc/rd.conf ]] || return 0
  local host db user pass
  host=$(ask_input "MySQL server hostname or IP" "localhost" || echo "localhost")
  db=$(ask_input "Database name" "Rivendell" || echo "Rivendell")
  user=$(ask_input "Database username" "rduser" || echo "rduser")
  pass=$(ask_password "Database password (input hidden)" || true)
  # Update keys within [mySQL]
  tmp=$(mktemp)
  awk -v host="$host" -v db="$db" -v user="$user" -v pass="$pass" '
    BEGIN{section=""}
    /^\[/ {section=$0}
    { line=$0 }
    section=="[mySQL]" && /^Hostname=/ { sub(/^Hostname=.*/, "Hostname="host, line) }
    section=="[mySQL]" && /^(Loginname=|DbUser=)/ { sub(/^(Loginname=|DbUser=).*/, "Loginname="user, line) }
    section=="[mySQL]" && /^(Password=|DbPassword=)/ { sub(/^(Password=|DbPassword=).*/, "Password="pass, line) }
    section=="[mySQL]" && /^Database=/ { sub(/^Database=.*/, "Database="db, line) }
    { print line }
  ' /etc/rd.conf > "$tmp"
  install -m 644 "$tmp" /etc/rd.conf && rm -f "$tmp"
  systemctl restart rivendell || true
}

suppress_mate_power_manager() {
  # Disable mate-power-manager autostart to avoid xRDP crash dialog
  local sys_autostart="/etc/xdg/autostart/mate-power-manager.desktop"
  [[ -f "$sys_autostart" ]] || return 0
  for u in "$target_user" rd; do
    if id -u "$u" >/dev/null 2>&1; then
      local autostart="/home/$u/.config/autostart"
      mkdir -p "$autostart"
      install -m 644 "$sys_autostart" "$autostart/mate-power-manager.desktop" 2>/dev/null || true
      echo "Hidden=true" >> "$autostart/mate-power-manager.desktop"
      chown -R "$u:$u" "/home/$u/.config"
    fi
  done
}

deploy_apps_payload() {
  local sysdst="/usr/share/rivendell-cloud"
  local rddst="/home/rd/imports/APPS"
  log "Deploying APPS payload to rd home: $rddst"
  mkdir -p "$sysdst" "$rddst"
  rsync -a "$PAYLOAD_DIR/" "$sysdst/"
  rsync -a "$sysdst/APPS/" "$rddst/"
  chown -R rd:rd "/home/rd/imports" "/home/rd/logs"
  # Ensure required rd folders and logs exist
  mkdir -p /home/rd/imports/RECONCILE /home/rd/Music /home/rd/logs
  touch /home/rd/logs/soap.log /home/rd/logs/dropbox.log
  chown -R rd:rd /home/rd/imports /home/rd/Music /home/rd/logs
  
  # Compatibility symlink for older paths
  ln -sfn /home/rd/imports /rivendell-installer

  # Ensure executability for scripts and shortcuts in APPS
  if [[ -d "$rddst" ]]; then
    find "$rddst" -type f \( -name "*.sh" -o -name "*.desktop" -o -name "*.liq" -o -name "stl.sh" -o -name "autologgen.sh" -o -name "reconcile-traffic.sh" -o -name "stereo_tool_gui_jack_64_1030" \) -exec chmod +x {} + 2>/dev/null || true
    # Rewrite any legacy/system paths within scripts to rd home
    while IFS= read -r -d '' f; do
      sed -i 's|/usr/share/rivendell-cloud/APPS|/home/rd/imports/APPS|g' "$f"
      sed -i 's|/rivendell-installer/APPS|/home/rd/imports/APPS|g' "$f"
      sed -i 's|/home/.*/rivendell-installer/APPS|/home/rd/imports/APPS|g' "$f"
      sed -i 's|/home/.*/imports/APPS|/home/rd/imports/APPS|g' "$f"
      sed -i 's|/var/log/rivendell-cloud/soap.log|/home/rd/logs/soap.log|g' "$f"
    done < <(find "$rddst" -type f \( -name "*.sh" -o -name "*.liq" -o -name "*.desktop" -o -name "*.conf" -o -name "*.xml" \) -print0)
  fi

  # System applications menu uses rd-based Exec
  if compgen -G "$rddst/Shortcuts/*.desktop" >/dev/null; then
    mkdir -p /usr/share/applications
    while IFS= read -r -d '' f; do
      base=$(basename "$f")
      install -m 644 "$f" "/usr/share/applications/$base"
    done < <(find "$rddst/Shortcuts" -type f -name "*.desktop" -print0)
  fi

  # Helper to copy shortcuts to a user's Desktop
  copy_shortcuts_to_user() {
    local u="$1"; local home="/home/$u"; local desk="$home/Desktop"
    [[ -d "$home" ]] || return 0
    mkdir -p "$desk"
    if compgen -G "$rddst/Shortcuts/*.desktop" >/dev/null; then
      rsync -a "$rddst/Shortcuts/" "$desk/"
      chown -R "$u:$u" "$desk"
      chmod +x "$desk"/*.desktop 2>/dev/null || true
    fi
  }

  # Seed shortcuts for target user and for rd if present
  copy_shortcuts_to_user "$target_user"
  copy_shortcuts_to_user rd

  # Configs to user's home as needed
  mkdir -p "/home/$target_user/.config"
  if [[ -d "$rddst/configs" ]]; then
    rsync -a "$rddst/configs/" "/home/$target_user/.config/"
    chown -R "$target_user:$target_user" "/home/$target_user/.config"
  fi
  # Also seed configs for rd
  mkdir -p "/home/rd/.config"
  if [[ -d "$rddst/configs" ]]; then
    rsync -a "$rddst/configs/" "/home/rd/.config/"
    chown -R rd:rd "/home/rd/.config"
    # Place specific configs where apps expect them
    mkdir -p "/home/rd/.config/vlc" "/home/rd/.config/rncbc.org"
    [[ -f "$rddst/configs/vlcrc" ]] && install -m 644 "$rddst/configs/vlcrc" "/home/rd/.config/vlc/vlcrc"
    [[ -f "$rddst/configs/vlc-qt-interface.conf" ]] && install -m 644 "$rddst/configs/vlc-qt-interface.conf" "/home/rd/.config/vlc/vlc-qt-interface.conf"
    [[ -f "$rddst/configs/QjackCtl.conf" ]] && install -m 644 "$rddst/configs/QjackCtl.conf" "/home/rd/.config/rncbc.org/QjackCtl.conf"
    [[ -f "$rddst/configs/.stereo_tool_gui_jack_64_1030.rc" ]] && install -m 644 "$rddst/configs/.stereo_tool_gui_jack_64_1030.rc" "/home/rd/.stereo_tool_gui_jack_64_1030.rc"
    chown -R rd:rd "/home/rd/.config"
    chown rd:rd "/home/rd/.stereo_tool_gui_jack_64_1030.rc" 2>/dev/null || true
  fi
}

configure_icecast() {
  local src="/usr/share/rivendell-cloud/APPS/icecast.xml"
  if [[ -f "$src" ]]; then
    log "Configuring Icecast"
    apt_install icecast2 || true
    install -Dm644 "$src" /etc/icecast2/icecast.xml
    sed -i 's/ENABLE=false/ENABLE=true/' /etc/default/icecast2 || true
    systemctl enable icecast2 || true
    systemctl restart icecast2 || true
  fi
}

# Configure AudioStore for Standalone/Server (local /var/snd) and Client (NFS mount)
configure_audiostore() {
  # Ensure mountpoint exists
  # Ensure rivendell group exists, add rd to it, and set proper ownership and setgid on /var/snd
  getent group rivendell >/dev/null 2>&1 || groupadd rivendell || true
  id -u rd >/dev/null 2>&1 && usermod -aG rivendell rd || true
  install -d -m 2775 /var/snd
  chown rd:rivendell /var/snd 2>/dev/null || true

  # Helper to update [AudioStore] in /etc/rd.conf
  update_rdconf_audiostore() {
    local src="$1"; local mtype="$2"; local mopts="$3"
    [[ -f /etc/rd.conf ]] || return 0
    # If [AudioStore] section missing, append it
    if ! grep -q '^\[AudioStore\]' /etc/rd.conf; then
      cat >> /etc/rd.conf <<EOF
[AudioStore]
MountSource=${src}
MountType=${mtype}
MountOptions=${mopts}
EOF
      return 0
    fi
    local tmp
    tmp=$(mktemp)
    awk -v src="$src" -v mtype="$mtype" -v mopts="$mopts" '
      BEGIN{section=""}
      /^\[/ {section=$0}
      { line=$0 }
      section=="[AudioStore]" && /^MountSource=/ { sub(/^MountSource=.*/, "MountSource="src, line) }
      section=="[AudioStore]" && /^MountType=/ { sub(/^MountType=.*/, "MountType="mtype, line) }
      section=="[AudioStore]" && /^MountOptions=/ { sub(/^MountOptions=.*/, "MountOptions="mopts, line) }
      { print line }
    ' /etc/rd.conf > "$tmp"
    install -m 644 "$tmp" /etc/rd.conf && rm -f "$tmp"
  }

  case "$install_type" in
    Standalone)
      # Local audiostore only
      log "Configuring local AudioStore at /var/snd (Standalone)"
      update_rdconf_audiostore "/var/snd" "" "defaults"
      ;;
    Server)
      log "Configuring local AudioStore at /var/snd and exporting via NFS (Server)"
      # Local path
      update_rdconf_audiostore "/var/snd" "" "defaults"
      # NFS server
      apt_install nfs-kernel-server || true
      # Export /var/snd with safe defaults
      if ! grep -qE '^/var/snd\s' /etc/exports 2>/dev/null; then
        echo "/var/snd *(rw,sync,no_subtree_check)" >> /etc/exports
      fi
      exportfs -ra || true
      systemctl enable --now nfs-server || systemctl enable --now nfs-kernel-server || true
      ;;
    Client)
      # Prompt for NFS server (default to DB host if present)
      local dbhost
      dbhost=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Hostname=/{print $2}' /etc/rd.conf 2>/dev/null | tr -d ' \r' || true)
      local nfs_srv
      nfs_srv=$(ask_input "Enter NFS server for AudioStore" "${dbhost:-server}" || echo "${dbhost:-server}")
      log "Configuring NFS AudioStore from ${nfs_srv}:/var/snd"
      apt_install nfs-common || true
      # Add fstab line idempotently
      local fstab_line
      fstab_line="${nfs_srv}:/var/snd /var/snd nfs defaults,_netdev 0 0"
      if grep -qE '^[^#].*\s/var/snd\s' /etc/fstab; then
        sed -i "s|^[^#].*\s/var/snd\s.*|$fstab_line|" /etc/fstab
      else
        echo "$fstab_line" >> /etc/fstab
      fi
      # Try mounting now
      mkdir -p /var/snd
      mount -a || true
      # Update rd.conf [AudioStore]
      update_rdconf_audiostore "${nfs_srv}:/var/snd" "nfs" "defaults,_netdev"
      ;;
  esac

  # Ensure a test cart exists in /var/snd if Rivendell didn't generate one
  local tone_src
  if [[ -f "$PAYLOAD_DIR/999999_001.wav" ]]; then
    tone_src="$PAYLOAD_DIR/999999_001.wav"
  elif [[ -f "/usr/share/rivendell-cloud/999999_001.wav" ]]; then
    tone_src="/usr/share/rivendell-cloud/999999_001.wav"
  fi
  if [[ -n "${tone_src:-}" ]]; then
    install -m 664 -o rd -g rivendell "$tone_src" "/var/snd/999999_001.wav" || true
  fi
}

web_meta_file() {
  log "Creating /var/www/html/meta.txt (owned by pypad if exists)"
  mkdir -p /var/www/html
  touch /var/www/html/meta.txt
  if id -u pypad >/dev/null 2>&1; then
    chown pypad:pypad /var/www/html/meta.txt
  fi
}

qt5_xcb_fix() {
  # Prefer XCB for Qt apps in xRDP sessions
  echo 'export QT_QPA_PLATFORM=xcb' > /etc/profile.d/qt-xcb.sh
  chmod 644 /etc/profile.d/qt-xcb.sh
  # Also set per-user for common users (target and rd if exists)
  for u in "$target_user" rd; do
    if id -u "$u" >/dev/null 2>&1; then
      local xrc="/home/$u/.xsessionrc"
      grep -q 'QT_QPA_PLATFORM=xcb' "$xrc" 2>/dev/null || echo 'export QT_QPA_PLATFORM=xcb' >> "$xrc"
      chown "$u:$u" "$xrc" || true
    fi
  done

  # Share Xauthority so root-run Qt apps can display in xRDP
  if [[ -f "/home/rd/.Xauthority" ]]; then
    ln -sfn "/home/rd/.Xauthority" "/root/.Xauthority"
  fi
}

# After the first xRDP login, link rd's Xauthority to root automatically
setup_xauth_autolink() {
  local svc="/etc/systemd/system/rivendell-xauth-link.service"
  local path="/etc/systemd/system/rivendell-xauth-link.path"
  cat >"$svc" <<'EOF'
[Unit]
Description=Link rd .Xauthority to root for xRDP Qt apps

[Service]
Type=oneshot
ExecStart=/bin/ln -sfn /home/rd/.Xauthority /root/.Xauthority
ConditionPathExists=/home/rd/.Xauthority
EOF
  cat >"$path" <<'EOF'
[Unit]
Description=Watch for rd .Xauthority

[Path]
PathExists=/home/rd/.Xauthority

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload || true
  systemctl enable --now rivendell-xauth-link.path || true
}

configure_rd_conf() {
  # Prepare /etc/rd.conf with DB credentials prior to Rivendell install
  local db="Rivendell" user="rduser" pass="hackme" host="localhost"
  local u_in d_in p_in
  u_in=$(ask_input "Database username" "$user" || echo "$user")
  d_in=$(ask_input "Database name" "$db" || echo "$db")
  p_in=$(ask_password "Database password (leave blank to keep default)" || true)
  [[ -n "$u_in" ]] && user="$u_in"
  [[ -n "$d_in" ]] && db="$d_in"
  [[ -n "$p_in" ]] && pass="$p_in"
  cat >/etc/rd.conf <<EOF
[mySQL]
Driver=QMYSQL
DbUser=$user
DbPassword=$pass
Database=$db
Hostname=$host
EOF
}

# Ensure MariaDB is installed and running before Rivendell packages
ensure_mariadb() {
  log "Installing and starting MariaDB server"
  apt_install mariadb-server mariadb-client || true
  systemctl enable --now mariadb || true
  # Wait for server availability with retries and a restart if needed
  local i=0 max=120
  dblog "Waiting for MariaDB to become ready (timeout=${max}s)"
  until mysqladmin ping >/dev/null 2>&1; do
    sleep 1; i=$((i+1))
    if [[ $i -eq 20 ]]; then
      log "MariaDB not ready after 20s; attempting a restart"
      dblog "MariaDB not ready after 20s; restarting service"
      systemctl restart mariadb || true
    fi
    [[ $i -ge $max ]] && break
  done
  if ! mysql --protocol=socket -uroot -e 'SELECT 1' >/dev/null 2>&1; then
    dblog "FATAL: MariaDB root socket not responding after ${max}s"
    fail "MariaDB did not start correctly; aborting install to avoid a broken state. Check: systemctl status mariadb"
  fi
  dblog "MariaDB is ready"
}

# Helper to (re)grant MySQL privileges for multiple host forms
mysql_grant_matrix() {
  local db="$1" user="$2" pass="$3"
  local mysql_root
  mysql_root() { mysql --protocol=socket -uroot -NBe "$1"; }
  local hname
  hname=$(hostname 2>/dev/null || echo localhost)
  # Ensure users exist for common host forms
  mysql_root "CREATE USER IF NOT EXISTS '${user}'@'localhost' IDENTIFIED BY '${pass}'" || true
  mysql_root "CREATE USER IF NOT EXISTS '${user}'@'127.0.0.1' IDENTIFIED BY '${pass}'" || true
  mysql_root "CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${pass}'" || true
  mysql_root "CREATE USER IF NOT EXISTS '${user}'@'${hname}' IDENTIFIED BY '${pass}'" || true
  # Refresh passwords
  mysql_root "ALTER USER '${user}'@'localhost' IDENTIFIED BY '${pass}'" || true
  mysql_root "ALTER USER '${user}'@'127.0.0.1' IDENTIFIED BY '${pass}'" || true
  mysql_root "ALTER USER '${user}'@'%' IDENTIFIED BY '${pass}'" || true
  mysql_root "ALTER USER '${user}'@'${hname}' IDENTIFIED BY '${pass}'" || true
  # Ensure DB exists and grant
  mysql_root "CREATE DATABASE IF NOT EXISTS \`${db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
  for host in localhost '127.0.0.1' '%' "${hname}"; do
    mysql_root "GRANT ALL PRIVILEGES ON \`${db}\`.* TO '${user}'@'${host}'"
  done
  mysql_root "FLUSH PRIVILEGES"
}

# Create a minimal /etc/rd.conf and MySQL user/db BEFORE Rivendell packages
# so that any package-time rddbmgr calls succeed.
preseed_rd_conf_and_mysql() {
  # Removed: do not create /etc/rd.conf early. Let Rivendell generate it fully.
  :
}

# After packages are installed, try an initial DB create via rddbmgr
initial_rivendell_db_create() {
  case "$install_type" in
    Standalone|Server) :;;
    *) return 0;;
  esac
  if ! have_cmd rddbmgr; then return 0; fi
  # Wait for Rivendell to generate /etc/rd.conf
  local i=0; while [[ ! -f /etc/rd.conf && $i -lt 60 ]]; do sleep 1; i=$((i+1)); done
  if [[ ! -f /etc/rd.conf ]]; then
    dblog "rd.conf not present after Rivendell install; skipping initial rddbmgr"
    return 0
  fi
  log "Attempting initial Rivendell DB create via rddbmgr"
  dblog "rddbmgr --create (initial) starting"
  systemctl stop rivendell || true
  if out=$(rddbmgr --create 2>&1); then
    log "rddbmgr --create succeeded"
    dblog "rddbmgr --create succeeded"
    return 0
  fi
  # If failed, reinforce grants and retry once
  local db user pass
  db=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Database=/{print $2}' /etc/rd.conf | tr -d ' \r')
  user=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Loginname=/{print $2}' /etc/rd.conf | tr -d ' \r')
  [[ -n "$user" ]] || user=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^DbUser=/{print $2}' /etc/rd.conf | tr -d ' \r')
  pass=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Password=/{print $2}' /etc/rd.conf | tr -d ' \r')
  [[ -n "$pass" ]] || pass=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^DbPassword=/{print $2}' /etc/rd.conf | tr -d ' \r')
  if [[ -n "$db" && -n "$user" && -n "$pass" ]]; then
    mysql_grant_matrix "$db" "$user" "$pass"
    dblog "rddbmgr --create retry after grant reinforcement"
    if out2=$(rddbmgr --create 2>&1); then
      log "rddbmgr --create succeeded after grant reinforcement"
      dblog "rddbmgr --create succeeded after grant reinforcement"
    else
      log "rddbmgr --create still failing; will continue with finalize and custom import"
      dblog "rddbmgr --create failed: $out"
    fi
  fi
}

# After Rivendell installs and generates /etc/rd.conf, finalize DB tasks
finalize_rivendell_db() {
  # Only initialize local DB for Standalone or Server installs
  case "$install_type" in
    Standalone|Server) :;;
    *) return 0;;
  esac

  # Read the credentials Rivendell generated; wait briefly if needed
  local i=0; while [[ ! -f /etc/rd.conf && $i -lt 60 ]]; do sleep 1; i=$((i+1)); done
  if [[ ! -f /etc/rd.conf ]]; then
    log "/etc/rd.conf not present; skipping DB finalization"
    dblog "No /etc/rd.conf; finalize skipped"
    return 0
  fi

  log "Finalizing Rivendell database"
  dblog "--- Finalize DB begin ---"
  # Parse only within the [mySQL] section
  local db user pass host
  db=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Database=/{print $2}' /etc/rd.conf | tr -d ' \r')
  # Rivendell uses 'Loginname='; older templates may use 'DbUser='
  user=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Loginname=/{print $2}' /etc/rd.conf | tr -d ' \r')
  [[ -n "$user" ]] || user=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^DbUser=/{print $2}' /etc/rd.conf | tr -d ' \r')
  # Rivendell uses 'Password='; older templates may use 'DbPassword='
  pass=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Password=/{print $2}' /etc/rd.conf | tr -d ' \r')
  [[ -n "$pass" ]] || pass=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^DbPassword=/{print $2}' /etc/rd.conf | tr -d ' \r')
  host=$(awk -F= '/^\[mySQL\]/{s=1;next}/^\[/{s=0} s&&/^Hostname=/{print $2}' /etc/rd.conf | tr -d ' \r')
  [[ -z "$host" ]] && host=localhost

  if [[ -z "$db" || -z "$user" || -z "$pass" ]]; then
    log "Unable to parse DB credentials from /etc/rd.conf; found db='$db' user='$user' pass_len=${#pass}. Skipping custom DB import."
    dblog "Parse error: db='$db' user='$user' pass_len=${#pass}"
  else
    # Idempotence marker to avoid clobbering on re-runs unless schema changes
    local stamp_dir="/var/lib/rivendell-cloud"; local stamp_file="$stamp_dir/db.finalized"
    mkdir -p "$stamp_dir"

    # Determine SQL payload path
    local sql="/usr/share/rivendell-cloud/APPS/RDDB_v430_Cloud.sql"
    [[ -f "$sql" ]] || sql="$PAYLOAD_DIR/APPS/RDDB_v430_Cloud.sql"

    # Helper to exec as MariaDB root via unix_socket
    mysql_root() { mysql --protocol=socket -uroot -NBe "$1"; }

    # Ensure server is accepting connections
    local i=0
    until mysql --protocol=socket -uroot -e 'SELECT 1' >/dev/null 2>&1; do
      sleep 1; i=$((i+1)); [[ $i -ge 20 ]] && break
    done

  # Stop rivendell while altering DB
  systemctl stop rivendell || true

  # Create user and DB, grant privileges across common host forms
  log "Ensuring MySQL user '$user' and database '$db' exist"
  dblog "Finalize: ensure grants for user='$user' db='$db' host='$host'"
  mysql_grant_matrix "$db" "$user" "$pass"

    # Optionally initialize default Rivendell schema first (for completeness)
    # Detect if DB is empty (no tables). If so, try rddbmgr --create non-interactively.
    local tbl_count
    tbl_count=$(mysql --protocol=socket -uroot -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}'" 2>/dev/null || echo 0)
    dblog "Table count before: ${tbl_count}"
    if [[ "${tbl_count}" == "0" ]]; then
      if have_cmd rddbmgr; then
        log "Database '${db}' is empty; attempting initial create via rddbmgr"
        dblog "rddbmgr --create (finalize) starting"
        if out3=$(rddbmgr --create 2>&1); then
          log "rddbmgr create completed"
          dblog "rddbmgr create completed"
        else
          log "rddbmgr create failed or not available; proceeding without it"
          dblog "rddbmgr create failed: $out3"
        fi
      fi
    fi

    # If we have a custom schema, replace the DB contents with it
    if [[ -f "$sql" ]]; then
      log "Importing custom Rivendell schema from $(basename "$sql")"
      dblog "Importing custom schema from $(basename "$sql")"
      # Drop and recreate to ensure a clean import
      mysql_root "DROP DATABASE IF EXISTS \`${db}\`"
      mysql_root "CREATE DATABASE \`${db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
      # Ensure privileges after recreation across all relevant host variants
      mysql_grant_matrix "$db" "$user" "$pass"
      # Import with logging for diagnostics
      if mysql --protocol=socket -uroot "$db" < "$sql" >> "$DB_LOG" 2>&1; then
        dblog "Custom schema import: SUCCESS"
        date +%s > "$stamp_file"
      else
        log "Custom schema import failed; see $DB_LOG for details"
        # Best-effort retry once after re-grant
        mysql_grant_matrix "$db" "$user" "$pass"
        if mysql --protocol=socket -uroot "$db" < "$sql" >> "$DB_LOG" 2>&1; then
          log "Custom schema import succeeded on retry"
          dblog "Custom schema import: SUCCESS on retry"
          date +%s > "$stamp_file"
        else
          log "Custom schema import still failing; DB may be default. Check $DB_LOG"
          dblog "Custom schema import: FAILED"
        fi
      fi
    fi
  fi

  # Ensure rivendell waits for DB
  mkdir -p /etc/systemd/system/rivendell.service.d
  cat >/etc/systemd/system/rivendell.service.d/override.conf <<'EOF'
[Unit]
After=network-online.target mariadb.service
Wants=network-online.target mariadb.service
EOF
  systemctl daemon-reload
  systemctl restart rivendell || true
  dblog "--- Finalize DB end ---"
}

# Noble-only: fix pypad.py deprecated readfp usage
fix_pypad_syntax_noble() {
  if [[ "$series" != "24.04" ]]; then return 0; fi
  local py="/usr/lib/python3/dist-packages/rivendellaudio/pypad.py"
  if [[ -f "$py" ]] && grep -q "config.readfp(" "$py"; then
    log "Fixing pypad.py config.readfp() -> config.read() for 24.04"
    sed -i "s/config\.readfp(open('\/etc\/rd\.conf'))/config.read('\/etc\/rd.conf')/" "$py" || true
  fi
}

# Optional: generate a short test tone cart after DB import
generate_test_tone() {
  case "$install_type" in
    Standalone|Server) :;;
    *) return 0;;
  esac
  # Require sox and rdimport
  if ! have_cmd sox || ! have_cmd rdimport; then return 0; fi
  # Try importing into DEFAULT group
  local wav="/tmp/rd-test-tone.wav"
  log "Generating and importing test tone cart"
  if sox -n -r 44100 -b 16 -c 2 "$wav" synth 3 sine 1000 >/dev/null 2>&1; then
    # Best effort import; ignore failure
    rdimport DEFAULT "$wav" >/dev/null 2>&1 || true
    rm -f "$wav" || true
  fi
}

firewall_and_ssh() {
  if $enable_ufw; then
    log "Configuring UFW"
    apt_install ufw || true
    ufw allow OpenSSH || true
    ufw allow 3389/tcp || true
    ufw allow 8000/tcp || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
    # NFS ports for Server installs
    if [[ "$install_type" == "Server" ]]; then
      ufw allow 111/tcp || true
      ufw allow 111/udp || true
      ufw allow 2049/tcp || true
      ufw allow 2049/udp || true
      # Mountd often uses 20048; open it as well
      ufw allow 20048/tcp || true
      ufw allow 20048/udp || true
    fi
    ufw --force enable || true
  fi
  if $harden_ssh; then
    log "Hardening SSH"
    # Skip hardening if no SSH keys present for target_user, rd, or root
    local has_keys=false
    for u in "$target_user" rd root; do
      local ak
      if [[ "$u" == "root" ]]; then
        ak="/root/.ssh/authorized_keys"
      else
        ak="/home/$u/.ssh/authorized_keys"
      fi
      if [[ -s "$ak" ]]; then has_keys=true; break; fi
    done
    if [[ "$has_keys" != true ]]; then
      log "No authorized_keys found. Skipping SSH hardening to prevent lockout."
      return 0
    fi
    install -Dm600 /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart sshd || true
  fi
}

pin_rivendell() {
  log "Pinning Rivendell packages to 4.3.0"
  apt-mark hold rivendell rivendell-dev rivendell-importers rivendell-select rivendell-webapi rivendell-webget || true
}

post_notes() {
  log "Installation complete. A reboot is recommended."
}

# Execute steps
ensure_packages
set_hostname
set_timezone
ensure_user
configure_limits
install_xrdp_desktop
ensure_mariadb
preseed_rd_conf_and_mysql
install_local_debs
initial_rivendell_db_create
install_media_apps
deploy_apps_payload
configure_icecast
web_meta_file
qt5_xcb_fix
setup_xauth_autolink
suppress_mate_power_manager
firewall_and_ssh
if [[ "$install_type" == "Client" ]]; then configure_client_rd_conf; fi
configure_audiostore
finalize_rivendell_db
generate_test_tone
fix_pypad_syntax_noble
pin_rivendell
post_notes

