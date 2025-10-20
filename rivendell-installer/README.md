# rivendell-installer
Automate Rivendell Installation with custom configuration on a VPS

## Quick start

This repository provides an offline-first installer for Rivendell 4.3.0 that works on Ubuntu 22.04 (jammy) and 24.04 (noble). It ships as separate artifacts (download only what you need) via GitHub Releases:

- Base installer (.run): installs Rivendell 4.3.0 from local .debs and deploys the APPS payload (configs, shortcuts, Icecast, helper scripts). For a smaller footprint, the base installer relies on apt for non-Rivendell dependencies if the network is available.
- Optional MATE bundles (.run per series): fully offline MATE desktop payloads for 22.04 and 24.04. Use these when you want an offline desktop/xRDP-capable environment.

### 1) Get the installer (download only what you need)
- Go to the Releases page and pick your version/tag, e.g.:
	- https://github.com/anjeleno/rivendell-installer/releases/tag/v0.1.1-20251019
- Download one or more of these files:
	- [rivendell-installer-0.1.1-20251019.run (base installer)](https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-installer-0.1.1-20251019.run)
	- [rivendell-mate-bundle-22.04-0.1.1-20251019.run (Ubuntu 22.04 MATE bundle)](https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-mate-bundle-22.04-0.1.1-20251019.run)
	- [rivendell-mate-bundle-24.04-0.1.1-20251019.run (Ubuntu 24.04 MATE bundle)](https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-mate-bundle-24.04-0.1.1-20251019.run)
- Optionally download SHA256SUMS.txt from the same release and verify checksums:

```bash
sha256sum -c SHA256SUMS.txt
```

Or download directly via wget:

```bash
# Base installer
wget -O rivendell-installer-0.1.1-20251019.run \
	"https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-installer-0.1.1-20251019.run"

# Ubuntu 22.04 MATE bundle
wget -O rivendell-mate-bundle-22.04-0.1.1-20251019.run \
	"https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-mate-bundle-22.04-0.1.1-20251019.run"

# Ubuntu 24.04 MATE bundle
wget -O rivendell-mate-bundle-24.04-0.1.1-20251019.run \
	"https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/rivendell-mate-bundle-24.04-0.1.1-20251019.run"

# Optional: checksums
wget -O SHA256SUMS.txt \
	"https://github.com/anjeleno/rivendell-installer/releases/download/v0.1.1-20251019/SHA256SUMS.txt"
sha256sum -c SHA256SUMS.txt
```

Private repo helper (no manual headers needed):

```bash
# Download via gh if installed; otherwise uses GH_TOKEN or token in ~/.git-credentials
bash scripts/release-download.sh v0.1.1-20251019 rivendell-installer-0.1.1-20251019.run
```

Note: We no longer store .run files in the git repository or Git LFS; Releases host the binaries to avoid cloning/downloading large files you don’t need.

### 2) Run the installer

Run as root (or with sudo). The installer detects your series (22.04/24.04) and installs from the bundled .debs.

```bash
chmod +x ./rivendell-installer-0.1.1-20251019.run
sudo ./rivendell-installer-0.1.1-20251019.run
```

The installer will prompt for:
- Installation type (Standalone/Server/Client)
- Hostname (defaults to onair)
- Optional timezone setup
- Optional UFW firewall configuration
- Optional SSH hardening (password auth off; ensure keys work first!)
- Optional MATE desktop for xRDP

It will then:
- Install Rivendell 4.3.0 from bundled .debs
- Create or prepare user (creates `rd` if running as root with no sudo user)
- Configure realtime/memlock limits
- Install xRDP and enable it
- Deploy APPS payload to `/usr/share/rivendell-cloud` (internal cache) and rd's home
- Configure Icecast (enable service)
- Create `/var/www/html/meta.txt` (owned by `pypad` if present)
- Apply xRDP Qt5/XCB fix by linking `.Xauthority`
- Import MariaDB schema from APPS using `/etc/rd.conf` credentials if present
- Optionally set UFW rules and harden SSH
- Pin Rivendell packages at 4.3.0

If you need a fully offline desktop:

```bash
chmod +x ./rivendell-mate-bundle-22.04-0.1.1-20251019.run
sudo ./rivendell-mate-bundle-22.04-0.1.1-20251019.run   # on Ubuntu 22.04
# or
chmod +x ./rivendell-mate-bundle-24.04-0.1.1-20251019.run
sudo ./rivendell-mate-bundle-24.04-0.1.1-20251019.run   # on Ubuntu 24.04
```

These MATE bundles install the desktop from a local cache and set LightDM as the display manager. The base installer detects the presence of local MATE packages and prefers them automatically when you choose to install a desktop.

Reboot is recommended after installation.

## Troubleshooting

### Downloaded .run won’t execute
Ensure the file is marked executable:

```bash
chmod +x ./<file>.run
```

### Installer asks for missing tools (whiptail/zenity)
The text UI uses `whiptail` and the optional GUI uses `zenity`.

```bash
sudo apt install -y whiptail zenity
```

### Database import fails
Ensure `/etc/rd.conf` has valid credentials (DbUser/DbPassword/Database). You can re-run just the DB import step manually:

```bash
sudo mysql -uRDUSER -pRDPASS Rivendell < /usr/share/rivendell-cloud/APPS/RDDB_v430_Cloud.sql
```

### xRDP session shows Qt/XCB display issues
Ensure `.Xauthority` for the selected user is linked for root-launched tools:

```bash
sudo ln -sf /home/rd/.Xauthority /root/.Xauthority
```

### UFW/SSH hardening locked me out
If you enabled SSH hardening, ensure your SSH keys are installed on the host. You can revert from console by restoring `/etc/ssh/sshd_config.bak*` and restarting SSH.

### I want to build the installers locally
Clone this repo and run the build scripts. You’ll need makeself and network access to fetch packages (or pre-populate caches):

```bash
# Build Rivendell 4.3.0 .debs for your series (24.04)
sudo bash scripts/build-rivendell-4.3.0.sh

# Build for 22.04 on a 24.04 host (uses chroot)
sudo bash scripts/build-rivendell-4.3.0-jammy.sh

# Create the offline .run artifacts
sudo apt install -y makeself
bash installer/offline/build-makeself.sh
ls -lh dist/

### Package cache layout (for maintainers)

Local package caches live under `installer/offline/packages/<series>/` where `<series>` is `22.04` or `24.04`:

- `base/`: rivendell*.deb and, optionally, other base deps if you choose to pre-bundle them.
- `mate/`: MATE desktop payload collected for offline installs.

Each directory contains a generated manifest `.files.txt` which is a sorted list of the `.deb` files present. These are used for traceability and quick verification; the installer itself relies on the files, not the manifests.
```

## Notes
- The installer is designed to be idempotent; re-running should patch missing bits without breaking an existing setup.
- If you encounter LFS bandwidth limits on GitHub, consider fetching the artifact from a GitHub Release or alternative mirror.
