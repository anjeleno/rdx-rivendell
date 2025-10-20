Rivendell Installer
=========================

This repo now includes two delivery paths for installing Rivendell 4.3.0 with your custom stack and configurations:

- Offline single-file installer (default): a self-contained .run file built with makeself, which includes all required .debs for Ubuntu 22.04 (Jammy) and 24.04 (Noble) plus your APPS payload.
- Online apt-based meta-package: a small .deb that drives apt to install dependencies and applies your configurations via maintainer scripts and debconf.

Both flows implement the same choices and safeguards and default to Rivendell 4.3.0 (pinned/held to avoid auto-upgrade to 4.4.x).

Conventions and goals
---------------------
- Support Ubuntu 22.04 and 24.04.
- Assume a desktop is present; MATE install is optional.
- Make xRDP work "universally" by relying on the system's default x-session-manager (no forced ~/.xsession).
- Create and configure user/groups/limits exactly as needed for Rivendell/JACK/Icecast when appropriate.
- Idempotent steps: safe to re-run / upgrade.
- Security prompts for UFW and SSH-hardening (opt-in).
- Hostname default: onair, with prompt; ensure Rivendell hostname matches Linux hostname.

Repository layout
-----------------

- debian/ — packaging files for the online meta-package (lives at the project root; not in /etc).
  - debian/control, rules, changelog, templates, postinst, config, etc.
- installer/offline/ — offline installer assets and build scripts.
  - driver.sh — TUI/GUI installer driver (whiptail by default, zenity if available).
  - build-makeself.sh — produces a single .run file bundling .debs and payload.
  - payload/ — files to embed into the offline bundle (APPS, optional desktop assets, scripts).
  - packages/ — per-series .deb cache (jammy, noble) populated by a helper script.
- scripts/collect-debs.sh — helper to download all required .debs for jammy/noble.

Quick start: offline installer (recommended)
-------------------------------------------

Requirements on the build machine:
- Ubuntu 22.04 or 24.04
- makeself, dpkg-dev, apt, curl

Steps:
1) Populate package caches (this only downloads; the final .run is offline):
   - scripts/collect-debs.sh jammy 4.3.0
   - scripts/collect-debs.sh noble 4.3.0
2) Place any non-redistributable payloads into installer/offline/payload/ as needed
   - Example: APPS/stereo_tool_gui_jack_64_1030 (if licensing allows). If not, the driver will offer to fetch or let the user provide it.
3) Build the installer:
   - installer/offline/build-makeself.sh
4) Transfer the resulting file (dist/rivendell-installer-<version>-<date>.run) to the target host and execute it as a sudo-capable user.

Notes on xRDP and desktops
--------------------------
- The driver will not write ~/.xsession by default.
- It ensures xrdp is installed and configured to use the system default x-session-manager via /etc/X11/Xsession, making it as desktop-agnostic as possible.
- MATE may be offered as an optional component for systems lacking a desktop.

Online meta-package build
-------------------------

This uses the debian/ directory at the repo root.

- Build: `dpkg-buildpackage -b -us -uc` (or use debhelper/dh). This produces a .deb that you can host on GitHub Releases or any HTTPS server.
- Install: `sudo dpkg -i rivendell-installer_*.deb && sudo apt -f install`
- Hosting: you can publish the .deb directly, or create a signed apt repository (GitHub Pages/Cloudsmith/PackageCloud/Launchpad PPA). Ubuntu official repos are not required.

Debconf questions (online .deb)
-------------------------------
- Install type: Standalone / Server / Client (default: Standalone)
- Hostname: default "onair"
- Timezone: select (optional)
- Security: enable UFW? harden SSH (disable password auth)?
- Create and use rd user if running as root; otherwise use current sudo user.

Rivendell 4.3.0 pinning strategy
---------------------------------
- For online installs: apt preferences in /etc/apt/preferences.d/rivendell, pinning rivendell packages to 4.3.0, and apt-mark hold after install.
- For offline: installer bundles exact 4.3.0 .debs and installs those; then optionally holds those packages.

MariaDB import and PyPAD fixes
------------------------------
- After Rivendell installation, we extract the DB password from /etc/rd.conf and import APPS/sql/RDDB_v430_Cloud.sql.
- On Ubuntu 24.04, we apply the pypad.py `config.readfp` to `config.read` sed fix if needed.

Licensing note (Stereo Tool)
----------------------------
- Please verify redistribution rights. If redistribution is not allowed, keep the binary out of the repo and the offline bundle; the installer will offer to download it with user consent or to use a locally provided copy.

Support matrix
--------------
- Ubuntu 22.04 (jammy): Rivendell 4.3.0, full stack
- Ubuntu 24.04 (noble): Rivendell 4.3.0, full stack with PyPAD fix

Next steps for contributors
---------------------------
- Wire the installer/offline/driver.sh TODOs to mirror rivendell-auto-install.sh logic.
- Add postinst logic into debian/ to match the same behavior with debconf answers.
- Keep steps idempotent and safe to re-run.
