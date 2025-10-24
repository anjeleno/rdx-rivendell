## v3.4.14 (2025-10-24)
### UI
- Jack Graph: Added drag-to-connect cables with live preview; connect on drop from outputs to inputs and cancel on outside drop.
- Jack Graph: Right-click cable menu refined with Lock/Unlock state and Disconnect disabled for locked pairs.
- Profiles: Added Edit… dialog to modify saved profiles (add/remove pairs) and save.
- Visibility: Thicker, higher-contrast cables and reliable rendering across environments.

### Fixed
- `jack_lsp -c` parsing tolerates any whitespace; existing connections now render consistently.
- Version strings aligned across header, window title, status bar, and application metadata.

### Packaging
- Bumped package to 3.4.14 and rebuilt `.deb`.

## v3.4.13 (2025-10-24)
### Fixed
- Profile generator now chooses true stereo pairs for each client (e.g., fm_l/fm_r, in_0/in_1) instead of occasionally picking two left channels (like fm_l + low_l).
- JACK connect: treat non-fatal "Cannot lock down ... memory area" messages as noise; verify actual connection state and proceed to avoid false failures.
- Applying a generated profile is now best-effort: each connect is attempted independently so a single transient warning won’t abort the whole apply. A concise summary is shown if any non-fatal issues occurred.

### UI
- Jack Graph: Lines (cables) are now more visible, and existing connections reliably render by tolerating any whitespace in `jack_lsp -c` output. This fixes the "only dots, no cables" issue on some systems.


### Packaging
- Prepared 3.4.13 with the above fixes.

## v3.4.12 (2025-10-24)
### Fixed
- Hotfix: Restored Jack Graph tab. An internal reference to a removed method during initialization caused a silent exception and the tab didn’t appear. The call is now removed.

### Packaging
- Rebuilt `.deb` as 3.4.12.

### Packaging
- Bumped to 3.4.11 and rebuilt `.deb`.

# RDX Broadcast Control Center Changelog

## v3.4.11 (2025-10-24)
### Fixed
- JACK connect reliability: treat "already connected" and generic "cannot connect" as success when the connection already exists.

### Changed
- Jack Graph UI: removed on-tab dropdowns; Profiles are now managed via a dialog (Profiles…) and a Generate button.
- Clear visual state: each cable shows 🔐 when locked and ⚠️ when unlocked; right‑click menu disables Disconnect for locked cables.

### Added
- Generate Profile: proposes a VLC→Rivendell, Rivendell→Stereo Tool, Stereo Tool→Liquidsoap, and Liquidsoap→system chain based on detected ports; saves and optionally applies it.

### Packaging
- Bumped to 3.4.11 and rebuilt `.deb`.

## v3.4.10 (2025-10-24)
### Added
- JACK Profiles: Save current graph connections as a named profile; Apply/Delete from the Jack Graph tab. Profiles are stored at `~/.config/rdx/jack_profiles.json`.

### Changed
- Jack Graph layout polish: moved client and port labels outward so the middle stays clean; drag from left output ports to right input ports is now visually clear and uncluttered.

### Packaging
- Bumped to 3.4.10 and rebuilt `.deb`.

## v3.4.9 (2025-10-24)
### Fixed
- Jack Graph: Zoom In/Out now work with smooth scaling and preserved zoom after refresh.
- JACK port parsing: Eliminated ghost "Properties" ports; Rivendell inputs and physical/USB I/O show correctly.

### Added
- Manual Connect/Disconnect UI on the Jack Graph tab with editable Output/Input selectors and Lock/Unlock for protected pairs.

### Improved
- Auto-Connect enhanced to route VLC outputs to Rivendell inputs when available, alongside RD → Stereo Tool → Liquidsoap chain.

### Packaging
- Bumped to 3.4.9 and rebuilt `.deb`.

## v3.4.8 (2025-10-24)
### Changed
- Version bump to publish jackd dummy backend fix and hardened release notes flow.

### Notes
- Use the built-in publish script with `--from-changelog` to keep release notes concise and attach the .deb automatically.

## v3.4.7 (2025-10-24)
### Fixed
- jackd dummy backend: omit `-n` (nperiods) which is not supported by the dummy driver, preventing "Unknown option n" errors with jackdmp 1.9.20.

### Release
- Hardened release script so passing `--notes-file CHANGELOG.md` automatically extracts only this version's section (same behavior as `--from-changelog`). This avoids full-changelog recaps and keeps assets prominent.

### Packaging
- Rebuilt `.deb` as 3.4.7.

## v3.4.5 (2025-10-24)
### Fixed
- Ensured `JackMatrixTab` defines its own pretty helpers in-class: `_pretty_client`, `_pretty_port_name`. This avoids AttributeError during startup.

### Build Safety
- Builder guard now verifies those methods exist inside `JackMatrixTab` via AST and fails the build if missing. This prevents packaging scoping mistakes from shipping.

### Packaging
- Bumped to 3.4.5 and rebuilt the `.deb`.

## v3.4.6 (2025-10-24)
### Changed
- Respect JACK backend selection strictly. Removed automatic ALSA device selection to avoid switching users from Dummy to ALSA.
- If backend=ALSA and no device is set, Start now fails fast with a clear message instead of guessing a device.

### Diagnostics
- jackd logs are still written to `~/.config/rdx/jackd.log` when starting in jackd mode.

### Packaging
- Rebuilt as 3.4.6.

## v3.4.4 (2025-10-24)
### Changed
- Version bump and rebuild to roll up the latest hotfixes and keep package metadata aligned with in-app version strings.

### Packaging
- Rebuilt `.deb` as 3.4.4 and published.

## v3.4.3 (2025-10-24)
### Fixed
- Startup crash on some installs: `AttributeError: 'JackMatrixTab' object has no attribute 'refresh_jack_connections'`.
  - Moved the full set of JACK Patchboard (Matrix) methods back inside `JackMatrixTab` so they are defined before use.
  - This restores proper behavior for Refresh, per-port connect/disconnect, stereo pair connect/disconnect, Auto-Connect, and Emergency Disconnect.

### Packaging
- Version bumped to 3.4.3 to deliver the hotfix immediately.

## v3.4.1 (2025-10-23)
### Added
- JACK Graph (preview): New visual graph tab that shows JACK clients/ports as nodes and connections as edges.
  - Click an output port then an input port to connect.
  - Right-click an edge to Disconnect or Lock/Unlock (protect) the client→client pair.
  - Shares protected pairs with the Patchboard via `~/.config/rdx/jack_protected.json`.
  - Includes Refresh, Auto-Connect, and Emergency Disconnect controls.

### Improved
- Fixed status bar initialization indentation to avoid class-scope execution; updated window title.

### Notes
- This is an initial, lightweight visualizer intended to complement the existing Patchboard. Future iterations will add draggable layout and per-edge persistence.

## v3.4.2 (2025-10-23)
### Fixed
- Hotfix: Restored protected-pairs persistence methods inside `JackMatrixTab` to prevent `AttributeError: 'JackMatrixTab' object has no attribute '_load_protected_pairs'` on startup.

### Packaging
- Bumped `.deb` to 3.4.2 so the fix is delivered immediately.

## v3.4.0 (2025-10-23)
### Added
- JACK jackdbus mode in Service Control: start/stop/restart via `jack_control`, with parameters applied using `ds/dps/eps`.
- ALSA device enumeration in JACK Settings: editable dropdown populated from `aplay -l`, plus a Refresh button.
- Presets in JACK Settings: "Live Low Latency", "Production Stable", and "Dummy (No HW)" apply typical backend/rate/period/nperiods/realtime setups.
- Adopt/Show Current: detects running JACK configuration (jackdbus via `jack_control`, or jackd command-line fallback) and fills the dialog or shows a summary.

### Improved
- Unified JACK start/stop helpers: both modes (jackd/jackdbus) route through consistent helpers with clearer error messages and status updates.

### Notes
- Visual graph-based patchboard is next. Current per-port manual patching remains available in the JACK tab and protected pairs behavior is unchanged.

## v3.3.5 (2025-10-23)
### Improved
- Build-time guard: Added an AST-based sanity check in the builder to detect any use of `self` at class scope (outside of methods). The builder will try a safe one-pass normalization for common mis-indents (status bar/title lines) and abort the build if violations remain. This prevents shipping packages that would crash with `NameError` at startup.

### Notes
- No functional UI changes; this release focuses on packaging resilience and preventing runtime class-scope errors from slipping through.

## v3.3.4 (2025-10-23)
### Fixed
- Hotfix: Resolved `NameError: name 'self' is not defined` during startup. A mis-indented status bar line ended up at class scope instead of inside `setup_ui()`. The line is now correctly indented so class creation no longer executes instance code.

### Packaging
- Rebuilt `.deb` as 3.3.4 to propagate the fix immediately.

## v3.3.3 (2025-10-23)
### Added
- Service Control: JACK Settings dialog. Configure backend (ALSA/Dummy), device, sample rate, frames/period, periods/buffer, realtime flag, and extra args. Settings are saved to `~/.config/rdx/jack_settings.json`.
- JACK management toggle: Choose whether RDX should manage the JACK server. When disabled, RDX won’t start/stop JACK and disables those buttons to avoid conflicts with Rivendell/QJackCtl.

### Improved
- Non-blocking status probes: All periodic checks for `jack_lsp`, `pgrep liquidsoap`, and `systemctl is-active` use short timeouts to prevent UI sluggishness if tools hang or respond slowly.
- Start All respects JACK management: only launches JACK if the RDX management toggle is enabled, then proceeds with Liquidsoap → Stereo Tool → Icecast.
- Safer JACK start/stop: starts jackd detached with your saved settings; stop also tries `jack_control exit` if available.

### Notes
- If Rivendell or QJackCtl already manages JACK on your system, keep the RDX JACK management toggle off to avoid double-management.
- ALSA device dropdown and jackdbus profiles are planned; current release focuses on a safe, minimal manager with solid UX.

## v3.3.2 (2025-10-23)
### Added
- JACK Patchboard: per-port manual patching controls. Select any specific output port and connect it to any input port, independently of L/R stereo pairing.

### Improved
- JACK routing UX: better L/R detection and ordering; recognizes more Stereo Tool client names (stereo_tool, stereotool, Stereo Tool). Clearer error feedback and an "already connected" tolerance.
- Emergency Disconnect uses safer checks when tearing down non-critical connections.
- Auto-Connect heuristics tuned to find ST and Liquidsoap more reliably.

### Build/Release Safety
- Packaging-time indentation guard broadened: any mis-indented method body lines in main UI classes are auto-normalized before packaging; build fails if still invalid.
- Pre-copy source compile check added (non-destructive). Optional flags:
  - RDX_FAIL_ON_SOURCE_SYNTAX=1 to hard-fail on source syntax errors
  - RDX_FIX_SOURCE=1 to opt-in source normalization with backup
- Atomic releases: new publisher supports --from-changelog to include only the relevant version section as notes.

### Notes
- This release focuses on JACK patching control and preventing future startup breaks due to indentation drift. Larger visual graphing (drag/drop) is on the roadmap.

## v3.3.1 (2025-10-23)
### Fixed
- Startup crash on fresh installs: corrected mis-indentation in `RDXBroadcastControlCenter.__init__` and a stray out-dented status bar line inside `setup_ui()`, which triggered `IndentationError: unexpected indent` on launch.

### Packaging
- Bumped builder to 3.3.1 and rebuilt the `.deb` so the fix is propagated. Update using the new package to permanently resolve the error.

## v3.3.0 (2025-10-23)
### Added
- JACK Patchboard: Replaced the old grid matrix with a simple, stereo-aware patchboard. Pick a Source (stereo out) and Destination (stereo in), then Connect L/R or Disconnect. Includes a quick “Unprotect current” action.
- Protected pairs persistence: Critical Source→Destination pairs are now saved to `~/.config/rdx/jack_protected.json` and preserved across restarts. Emergency Disconnect keeps protected pairs intact.
- Settings tab: User-level autostart for RDX via `systemd --user` (install/enable/disable/start/stop/restart controls). Tray options including “Minimize to tray on close” and “Hide to tray now”.
- System tray: Tray icon with Show/Hide and Quit menu; single-click toggles visibility.
- Stereo Tool “Latest URL” fallback: Optional field to store a curated or official stable link, and a button to download directly from it. Value persisted in `~/.config/rdx/settings.json`.

### Improved
- JACK UX: Clearer L/R semantics and less clutter versus the old matrix. Auto-Connect helper attempts RD → Stereo Tool → Liquidsoap and Liquidsoap → system:playback when detected.

### Notes
- The Thimeo auto-parser remains available; if it doesn’t find artifacts on your system, the new “Latest URL” path provides a reliable one-shot alternative.
- AAC/FLAC deep-dives are still deferred; MP3/OGG/OPUS remain solid. We’ll revisit FLAC edge cases separately.

## v3.2.31 (2025-10-23)
### Added
- Stereo Tool Manager tab: manage multiple Stereo Tool instances (add from URL/file, auto-download JACK x64 from Thimeo page), set active, start/stop.
- Per-user systemd unit: `rdx-stereotool-active.service` is generated under `~/.config/systemd/user` and points to the active instance via a symlink at `~/.config/rdx/processing/stereotool/active`.

### Improved
- Start order helper: “Start All Services” now sequences JACK → Liquidsoap → Stereo Tool → Icecast with simple readiness checks.
- UI consistency: Icecast Management “Generate/Prepare” buttons now match Stream Builder button sizing (min height + expanding width).

### Notes
- AAC/FLAC reliability work remains queued; current release focuses on Stereo Tool integration scaffolding.

## v3.2.30 (2025-10-23)
### Fixed
- FLAC streaming to Icecast now uses an Ogg container: `%ogg(%flac())` to prevent runtime failures.

### Improved
- Launcher PATH hardening: prepend `~/.local/bin` so the OPAM Liquidsoap shim is preferred by GUI launches.
- OPAM installer adds FFmpeg dev libs (`libswscale-dev`, `libavfilter-dev`) and performs a one-time rebuild if the FFmpeg encoder is still missing.
- Encoder detection continues to be capability-based and OPAM-aware; AAC prompts remain gated strictly to AAC configs.

### Packaging
- Builder updated to 3.2.30; rebuilt `.deb` with the above fixes.

## v3.2.29 (2025-10-23)
### Fixed
- UI Hotfix: Corrected remaining indentation in the Stream Builder actions row and main window setup that could crash on launch (IndentationError).

### Improved
- Post-OPAM messaging clarified when neither `fdkaac` nor FFmpeg AAC encoders are present: MP3/Opus/Vorbis/FLAC remain usable; AAC requires `libfdk-aac-dev` (for `%fdkaac`) or FFmpeg dev libs before OPAM build.
- Kept capability-based detection: AAC is only required if your generated config actually uses it; otherwise startup isn’t blocked.

### Packaging
- Rebuilt `.deb` with the hotfix and updated version metadata.

## v3.2.28 (2025-10-22)
### Added
- Service Control: compact encoder capability line (e.g., "Encoders: fdkaac, ffmpeg, mp3, opus"). It auto-refreshes after start/restart and hides itself if no encoders are detected to avoid UI clutter.
- OPAM installer: post-install verification that checks `liquidsoap --list-encoders` and, if `libfdk-aac-dev` is present but `encoder.fdkaac` is missing, performs a one-time `opam reinstall liquidsoap` to pick up FDK-AAC.

### Improved
- OPAM-aware detection and startup logic: capability-based checks (via `liquidsoap --list-encoders`/`--version`) instead of relying on apt package names.
- AAC is validated only when the generated config actually requests it. Either `fdkaac` or `ffmpeg` AAC satisfies AAC output; non-AAC streams are never blocked by AAC checks.
- Stream Builder AAC generation: prefer `%fdkaac` when available; fallback to `%ffmpeg` with explicit typing (`audio=true, video=false`) and sane defaults compatible with Liquidsoap 2.x.
- Unified logging: Liquidsoap log path is now `~/.config/rdx/liquidsoap.log` across generator and UI.
- OPAM installer ensures dev libs for MP3/Opus/Vorbis/FLAC/FFmpeg so other codecs continue to work out of the box when using OPAM.

### Fixed
- Fallback installer heredoc/redirect syntax error that occasionally broke non-interactive installs.

### Packaging
- Includes `/usr/share/rdx/install-liquidsoap-opam.sh` with the verify-and-rebuild step for FDK-AAC pickup.
- Builder bumped to 3.2.28 and `.deb` rebuilt and attached to the release.

## v3.2.27 (2025-10-22)
### Added
- In-app installer now offers a PPA-free option: "Build via OPAM" which compiles Liquidsoap per-user with AAC/FFmpeg support
- Live progress dialog for OPAM build; creates a user shim at `~/.local/bin/liquidsoap` so RDX can find the binary immediately

### Improved
- Fallback behavior: OPAM path bypasses broken PPA situations on jammy/noble and avoids adding focal sources

### Packaging
- Package now includes `/usr/share/rdx/install-liquidsoap-opam.sh`
- Builder bumped to 3.2.27

## v3.2.26 (2025-10-22)
### Fixed
- Hotfix: Resolved `IndentationError: unexpected indent` in Stream Builder actions block inside `setup_ui()`
- Affected v3.2.25 on some systems due to a mis-indented line; corrected and rebuilt

## v3.2.25 (2025-10-22)
### Improved
- Stream Builder: action buttons now match Icecast Management button sizing (consistent min height and expanding width)
- In-app FFmpeg plugin installer shows a live progress dialog (no more “hung” feeling), streaming logs during installation

### Fixed
- Liquidsoap AAC generation prefers native `%fdkaac` when available; falls back to `%ffmpeg` AAC automatically

### Packaging
- Hardened FFmpeg plugin installer helper:
  - Enables `universe`/`multiverse`
  - Logs to `/var/log/rdx-plugin-install.log`
  - Robust fallback when `add-apt-repository` fails for `savonet/ppa` (manual source + key import), then retries install

## v3.2.24 (2025-10-22)
### Fixed
- Startup crash on some environments: "QWidget: Must construct a QApplication before a QWidget"
  - Moved all Stream Builder widget creation strictly inside `setup_ui()` so no widgets are created at import time
  - Ensures clean startup when launching via desktop shortcut or wrapper scripts

### Notes
- No functional changes beyond the crash fix; recommended upgrade for all users seeing the startup error

## v3.2.23 (2025-10-22)
### Improved
- Installer elevation: use `pkexec /bin/bash /usr/share/rdx/install-liquidsoap-plugin.sh` to avoid noexec/permission issues and eliminate sudo TTY errors
- Better error messages when PolicyKit is unavailable or the operation is canceled

### Packaging
- Rebuilt and published `.deb` with the updated installer invocation

## v3.2.22 (2025-10-22)
### Fixed
- Restored Stream Builder controls accidentally removed during refactor:
  - "Generate Liquidsoap Config" and "Apply to Icecast" buttons
  - Configuration Status area reinstated and grouped
- Fixed Streams table to include an "Actions" column (7 columns total) to avoid out-of-bounds cell widget placement

## v3.2.21 (2025-10-22)
### Added
- Launcher diagnostics: logs Python runtime version and the first 3 lines of the installed app script to aid remote troubleshooting of indentation/version mismatches

### Fixed
- Minor version string alignment

## v3.2.20 (2025-10-22)
### Fixed
- Finalize indentation normalization for main window init and UI setup to ensure consistent behavior when launched via desktop shortcuts across environments

### Packaging
- Rebuilt and published 3.2.20 to ensure the corrected script is propagated cleanly

## v3.2.19 (2025-10-22)
### Fixed
- Residual indentation errors after 3.2.18 cleanup: removed stray duplicated block after `start_service()` and repaired mis-indented lines in main window

### Notes
- No functional changes beyond syntax fixes; retains guided FFmpeg plugin installer and preflight sanitizers

## v3.2.18 (2025-10-22)
### Fixed
- Resolved Python SyntaxError/indentation issues introduced during installer integration
- Cleaned up Service Control logic: correct try/except scoping and removed duplicate code

### Added
- Proper `restart_service()` implementation in Service Control tab (user-process for Liquidsoap; systemd for others)

### Changed
- `start_service()` now uses `systemctl start` for non-user Liquidsoap services (was incorrectly using restart)
- Version strings aligned across title bar, status bar, and application metadata

### Notes
- Retains guided FFmpeg plugin installation and preflight parse/sanitizer flow

## v3.2.17 (2025-10-22)
### Added
- In-app one-click installer for Liquidsoap FFmpeg plugin with choices:
  - Current OS repos
  - Official Liquidsoap repo
  - Vendor repo (Paravel)
- Post-installation automation: attempts to install the FFmpeg plugin during package configure

### Improved
- Hardened plugin detection and user guidance when encoder plugin is missing
- Adaptive sanitizer and capability probe for FFmpeg encoders and formats

### Packaging
- Built and published `.deb` to `releases/` as v3.2.17

## v3.2.16 (2025-10-22)
### Fixed
- Installation compatibility: Relaxed FFmpeg plugin requirement to avoid “dependency not satisfiable” on distros where that package name isn’t available

### Improved
- Preflight message now suggests alternative plugin packages: `liquidsoap-plugin-ffmpeg` | `liquidsoap-plugin-all` | `liquidsoap-plugin-extra`

### Packaging
- Depends: `liquidsoap (>= 2.0.0)`; Recommends include plugin alternatives
- Builder script bumped to 3.2.16 and rebuilt package

### Packaging
- Builder script bumped to 3.2.14 and rebuilt package

## v3.2.14 (2025-10-22)
### Fixed
- Hotfix: Moved status bar initialization inside `setup_ui()` and corrected `setWindowTitle` indentation in `__init__`
- Resolves NameError and IndentationError seen when launching from desktop shortcut

## v3.2.13 (2025-10-22)
### Fixed
- Hotfix: Resolved IndentationError in main window constructor (`__init__`) causing startup failure
- Version strings aligned across title bar, status bar, and application metadata

### Packaging
- Builder script version bumped to 3.2.13

## v3.2.12 (2025-10-22)
### Fixed
- Liquidsoap: eliminate NameError during Start by importing `re` at module scope
- Liquidsoap AAC typing: explicitly mark FFmpeg encoder as audio-only with `audio=true, video=false` to satisfy Liquidsoap 2.x type-checker

### Improved
- Auto-sanitizer now injects `audio=true, video=false` into `%ffmpeg(...)` when missing, quotes `audio_bitrate`, and removes `source=radio` label
- Installer template `radio.liq`: log path now `~/.config/rdx/liquidsoap.log` and includes a correct AAC example commented out

## v3.2.11 (2025-10-22)
### Fixed
- Liquidsoap: generator uses positional source (radio) again; removed unsupported source= label
- Auto-sanitize existing configs on start: quote ffmpeg audio_bitrate (e.g., 64k -> "64k"), replace source=radio

### Improved
- Preflight parse-check still runs; if it fails, the app attempts auto-fix then re-checks and shows any errors

## v3.2.10 (2025-10-22)
### Fixed
- Liquidsoap: pass stream source explicitly using `source=radio` in `output.icecast(...)` to resolve type mismatch errors in 2.x
- Update skeleton example (`radio.liq.example`) to use `source=radio`

## v3.2.9 (2025-10-22)
### Fixed
- Liquidsoap AAC config: quote ffmpeg audio_bitrate value (e.g., "64k") to fix parse error

### Improved
- Preflight: run `liquidsoap -c` to parse-check config before starting/restarting; show errors in-app

## v3.2.8 (2025-10-22)
### Fixed
- Liquidsoap AAC encoder config: replaced unsupported `%aac(...)` with widely-supported ffmpeg-based AAC encoder

### Packaging
- Recommend `liquidsoap-plugin-ffmpeg` to ensure AAC encoding availability by default

### Installer/Docs
- Installer now installs `liquidsoap-plugin-ffmpeg` by default on Debian/Ubuntu
- In-app guidance updated to suggest installing `liquidsoap-plugin-ffmpeg`

## v3.2.7 (2025-10-22)
### Changed
- Version bump to v3.2.7 and packaging refresh

### Docs
- Added/updated changelog entries for v3.2.4–v3.2.6

## v3.2.6 (2025-10-22)
### Fixed
- Resolved Python IndentationError and SyntaxError introduced during log viewer integration

### Improved
- Stabilized in-app Liquidsoap log viewer (auto-refresh timer, Follow toggle, manual Refresh)
- Polished Service Control status updates and UI behavior

### Packaging
- Bumped package and published clean v3.2.6 release
- Ensured .deb artifacts are saved under `releases/`

## v3.2.5 (2025-10-22)
### Added
- In-app Liquidsoap log viewer in Service Control tab
  - Per-user log at `~/.config/rdx/liquidsoap.log`
  - "Follow" checkbox and Refresh button

### Fixed
- Reliable Liquidsoap status detection using process checks (pgrep)
- Start/Restart launches Liquidsoap detached and captures stdout/stderr to per-user log

### Changed
- Launchers updated to use `$HOME` and be user-agnostic

## v3.2.4 (2025-10-22)
### Changed
- Universalized installer: removed `/home/rd` assumptions across packaging
- `postinst` now seeds `/etc/skel/.config/rdx` with examples for new users
- Automatically creates `~/.config/rdx` for all existing human users with correct ownership and permissions
- Moved build artifacts to `releases/` for predictable output location
- Desktop launcher updated to be user-agnostic and use `$HOME`

## v3.2.3 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed config directory permissions issue preventing stream loading
- **IMPROVED**: More robust ownership and permissions handling for `~/.config/rdx`
- **ENHANCED**: Better error messages with manual fix instructions for permission problems
- **ELIMINATED**: Fallback directories - exclusively uses `~/.config/rdx` with proper ownership

### Technical Improvements
- **Aggressive Permissions Fix**: Forces correct user:user ownership on config directories
- **Parent Directory Fix**: Ensures `.config` parent directory has correct ownership
- **Explicit Permissions**: Sets directory permissions to 755 explicitly
- **Better Error Recovery**: Provides clear manual fix commands when permissions fail
- **No Fallbacks**: Removed confusing fallback paths that caused ownership issues

### Permission Fix Details
- Forces creation of `~/.config/rdx` with correct user ownership
- Fixes parent `~/.config` directory ownership if needed
- Sets explicit 755 permissions on config directory
- Provides manual fix commands if automatic fixes fail

## v3.2.2 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed Python syntax error (IndentationError) that prevented application startup
- **CLEANED**: Removed leftover code fragments from previous config directory method refactoring
- **RESOLVED**: Application now starts without syntax errors

### Technical Cleanup
- Cleaned up duplicate and orphaned code lines in IcecastManagementTab class
- Fixed indentation issues from method refactoring
- Ensured clean Python syntax throughout codebase

## v3.2.1 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed config directory fallback causing files to save in `~/.rdx` instead of `~/.config/rdx`
- **CRITICAL**: Fixed stream persistence between tabs using JSON storage instead of in-memory references
- **CRITICAL**: Eliminated config directory ownership confusion - no more root:root directories
- **IMPROVED**: Icecast Management now reads streams from persistent storage, not parent tab references
- **ENHANCED**: Forced use of standard config directory `~/.config/rdx` - no confusing fallbacks

### Major Technical Improvements
- **Persistent Stream Storage**: Streams saved to `~/.config/rdx/streams.json` and loaded consistently
- **Unified Config Path**: All config files now use `~/.config/rdx/` directory exclusively
- **Cross-Tab Communication**: Icecast Management reads from JSON storage, not runtime parent references
- **Proper Ownership**: Config directories created with correct user:user ownership from start
- **Error Prevention**: Eliminated fallback to `~/.rdx` that caused path confusion

### Fixed Workflow
1. **Stream Builder**: Add streams → Auto-saved to `~/.config/rdx/streams.json`
2. **Icecast Management**: Reads streams from JSON storage → Generates correct configs
3. **Deployment**: Creates configs in `~/.config/rdx/` with proper ownership
4. **Result**: Streams appear correctly in Icecast config with proper mount points

## v3.2.0 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed config files not being generated (Liquidsoap and Icecast)
- **CRITICAL**: Fixed config directory ownership issues - now sets proper user:user ownership
- **IMPROVED**: Auto-generation of Icecast config during deployment if missing
- **ENHANCED**: Better error reporting showing why mount points might be 0
- **FIXED**: Stream Builder data not transferring to Icecast Management tab

### Major Improvements
- **Automatic Config Generation**: Deployment now auto-creates missing configs
- **Proper Ownership**: Config directories created with correct user ownership, not root:root
- **Enhanced Diagnostics**: Deployment success shows detailed stream information and troubleshooting
- **Seamless Workflow**: No more manual config generation required - everything automatic

### Technical Enhancements
- Added proper user/group ownership setting for config directories
- Enhanced error handling with specific guidance for missing streams
- Improved inter-tab communication for stream data access
- Added defensive programming for ownership operations

## v3.1.9 (2025-10-22)

Enhancements

- Liquidsoap ffmpeg adaptive sanitizer: Added runtime capability probe for `encoder.ffmpeg` and stricter auto-fixes
  - Switches to `audio_codec="libfdk_aac"` when native `aac` is unavailable
  - Removes explicit `format="adts"` if unsupported by local ffmpeg build
  - Ensures `audio=true, video=false` and converts `64k` style bitrates to numeric bps
- Improves reliability of preflight parse checks, reducing `Lang_ffmpeg` parse errors across distros
- Internal: Minor UI version bump wiring

Packaging

- Builder script bumped to 3.2.17 and rebuilt package

### Fixed
- **CRITICAL**: Fixed missing `streams` attribute error in Icecast config deployment
  - Corrected access to streams data from parent's stream_builder tab
  - Used proper inter-tab communication pattern: `self.parent().stream_builder.streams`
  - Fixed "object has no attribute 'streams'" error in IcecastManagementTab
  - Mount point count now correctly retrieved from StreamBuilderTab


### Technical Improvements
- Implemented proper tab communication for accessing stream configuration data
- Enhanced cross-tab data access with defensive programming checks
- Aligned with existing code patterns used elsewhere in the application

## v3.1.8 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed missing `get_mount_points()` method error in Icecast config deployment
  - Replaced non-existent `self.get_mount_points()` call with `len(self.streams)`
  - Fixed "object has no attribute 'get_mount_points'" error
  - Deployment success message now shows correct mount point count

### Technical Improvements
- Corrected mount point counting in deployment confirmation dialog
- Enhanced error handling for method existence checks

## v3.1.7 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed PolicyKit authentication loop in Icecast config deployment
  - Combined all privileged operations into single script executed with one `pkexec` call
  - Eliminated multiple authentication prompts that caused authentication loops
  - Added proper temporary script cleanup and error handling
  - Streamlined deployment process for better user experience

### Technical Improvements
- Single authentication prompt for entire Icecast deployment process
- Enhanced error handling with automatic cleanup of temporary files
- More robust privilege escalation with consolidated operations

## v3.1.6 (2025-10-22)
### Fixed
- **CRITICAL**: Fixed GUI sudo authentication for Icecast config deployment
  - Replaced `sudo` with `pkexec` for GUI-compatible privilege escalation
  - Fixed ownership setting to correct `root:icecast` (was `icecast2:icecast`)
  - Added proper PolicyKit integration for seamless GUI password prompts
  - Enhanced error handling with fallback suggestions if pkexec unavailable

### Technical Improvements
- Professional config deployment now works seamlessly from GUI
- Eliminated all terminal dependencies for privilege operations
- Added comprehensive error reporting for deployment failures

## v3.1.5 (2025-10-22)

### 🔧 ICECAST CONFIGURATION DEPLOYMENT FIX

#### Improved Configuration Deployment
- **FIXED**: `sudo cp` command failing with exit status 1 during config deployment
- **ENHANCED**: Added comprehensive error reporting with stdout/stderr capture
- **ADDED**: Automatic backup of original icecast.xml before applying changes
- **IMPROVED**: Proper file ownership and permissions after config deployment

#### Robust Error Handling
- **Validation**: Config file existence and content validation before deployment
- **Debugging**: Detailed error messages showing exact command, exit code, and output
- **Backup**: Automatic backup of original config to icecast.xml.backup
- **Permissions**: Proper chown/chmod after successful config deployment

#### Technical Improvements
- **sudo systemctl**: All service operations now use sudo consistently
- **File Verification**: Config file readability and content validation
- **Error Details**: Complete command output capture for debugging
- **Professional UX**: Clear success/failure feedback with file paths

#### Service Management
- **Stop Service**: Uses `sudo systemctl stop icecast2` properly
- **Config Copy**: Enhanced error handling for file copy operations
- **Ownership**: Sets proper `icecast2:icecast` ownership
- **Permissions**: Sets secure `640` permissions on config file
- **Start Service**: Reliable service restart with error capture

### 🎯 **User Experience**
- **Detailed Feedback**: Users see exactly what went wrong if deployment fails
- **Backup Safety**: Original config automatically backed up before changes
- **Professional Operation**: Seamless config deployment when everything works
- **Debug Information**: Complete error details for troubleshooting

## [3.1.4] - 2025-10-22 - "Syntax Error Fix" Release 🐛

### 🐛 CRITICAL SYNTAX ERROR FIX

#### Python SyntaxError Elimination
- **FIXED**: `SyntaxError: invalid decimal literal at line 1330`
- **CAUSE**: Broken CSS triple-quoted string and leftover guidance message fragments
- **SOLUTION**: Clean Python syntax with safe string concatenation
- **RESULT**: Application now starts without syntax errors

#### Code Cleanup
- **CSS Strings**: Replaced problematic triple-quoted CSS with single-line concatenation
- **Leftover Text**: Removed stray guidance message fragments causing syntax errors
- **Encoding Issues**: Eliminated emoji characters causing encoding problems
- **Syntax Validation**: Full codebase syntax validation and cleanup

#### Technical Improvements
- **Safe Strings**: No more unterminated or broken triple-quoted strings
- **Clean Code**: Proper Python syntax throughout entire codebase
- **Encoding**: UTF-8 safe character handling
- **Validation**: Source and installed files compile without errors

### ✅ **Validation Results**
- **Source File**: Compiles cleanly with `ast.parse()`
- **Installed App**: No syntax errors during Python compilation
- **Functionality**: All features preserved from v3.1.3
- **Startup**: Application launches properly without crashes

## [3.1.3] - 2025-10-22 - "Critical Bug Fixes" Release 🚑

### 🚑 CRITICAL FIXES

#### Missing Config Directory Method
- **FIXED**: Added missing `get_config_directory()` method to IcecastManagementTab class
- **RESOLVED**: "AttributeError: 'IcecastManagementTab' object has no attribute 'get_config_directory'"
- **IMPACT**: Application no longer crashes when generating Icecast configurations

#### Eliminated Amateur "Guidance" Messages
- **REMOVED**: All unprofessional "guidance" dialog boxes telling users to manually start services
- **REPLACED**: Service control now actually starts/stops/restarts services automatically
- **PROFESSIONAL**: No more "As system administrator..." amateur messages
- **AUTOMATIC**: Services are controlled directly by the application

#### Real Service Management
- **Liquidsoap**: Automatic start/stop with generated configuration files
- **JACK**: Direct jackd process management with proper parameters
- **Icecast**: Systemctl integration with automatic config deployment
- **Professional**: No manual intervention required from users

#### Configuration Deployment
- **REMOVED**: Amateur "deployment preparation" that created useless instruction files
- **REPLACED**: Direct config deployment to system locations with automatic service restart
- **PROFESSIONAL**: Config files are applied immediately without user intervention

### 🔧 Technical Improvements
- **Consistent Config Handling**: All tabs now use the same robust config directory logic
- **Error Recovery**: Proper exception handling for service management operations
- **Professional UX**: No more amateur guidance popups interrupting workflow
- **Automatic Operations**: Services controlled seamlessly without user intervention

### 🎯 User Experience
- **Zero Manual Steps**: Everything happens automatically
- **Professional Quality**: No more amateur "please run these commands" messages
- **Error-Free**: Critical crashes eliminated
- **Seamless Operation**: Services start/stop/restart with single button clicks

## [3.1.2] - 2025-10-22 - "Stream Persistence" Release 💾

### 🎯 MAJOR FEATURE: Stream Persistence System

#### Zero-Loss Stream Management
- **Automatic Stream Saving**: All configured streams automatically saved to disk
- **Seamless Reload**: Streams persist between application restarts
- **Professional Config Handling**: Uses standard directory patterns like VLC
- **No More Lost Configurations**: Eliminates "streams disappear after closing app" issue

#### Robust Configuration Directory Handling
- **Standard Location**: Prioritizes `~/.config/rdx/` (XDG standard)
- **Smart Fallback**: Falls back to `~/.rdx/` if permission issues exist
- **Emergency Fallback**: Uses temp directory as last resort
- **Permission-Safe**: Complete elimination of config file permission errors

#### Data Persistence Features
- **Stream Configuration**: All stream settings saved to `streams.json`
- **Auto-Save**: Streams automatically saved when added or removed
- **Data Integrity**: JSON format ensures reliable data storage
- **Cross-Session**: Configurations persist across application restarts

#### Technical Improvements
- **Professional Implementation**: Matches config handling standards used by major applications
- **Error Recovery**: Graceful handling of permission issues and corrupted files
- **User-Specific**: Each user gets their own isolated configuration
- **Complete sudo Elimination**: No root permission requirements anywhere

#### Directory Structure
```
~/.config/rdx/  (or ~/.rdx/ fallback)
├── streams.json      # Your saved streams
├── radio.liq         # Generated Liquidsoap config
└── icecast.xml       # Generated Icecast config
```

#### User Experience
- **Zero Configuration**: Works out of the box for all users
- **No More Lost Streams**: Streams persist between sessions
- **Professional Quality**: Config handling matches industry standards
- **Error-Free**: No more permission denied errors

## [2.1.0] - 2025-10-21 - "Automated Pro" Release 🤖

### 🚀 BREAKTHROUGH: Fully Automated Dependency Installation

#### Zero-Touch Installation Experience
- **Automated Installation**: Dependencies install automatically during package install
- **No User Interaction**: Complete hands-off dependency resolution
- **Enhanced Post-Install**: Smart installer runs automatically during dpkg
- **Error Recovery**: Fallback to manual mode with helpful guidance
- **Progress Feedback**: User sees installation progress and status

#### Enhanced Smart Installer
- **New Operation Modes**: `--auto-yes`, `--scan-only`, `--check-only`, `--install-deps-only`
- **Non-Interactive Mode**: `DEBIAN_FRONTEND=noninteractive` support
- **Specialized Functions**: Targeted operations for automated systems
- **Enhanced Error Handling**: Comprehensive error detection and recovery

#### Improved User Experience
- **One-Command Install**: Just `sudo dpkg -i package.deb` - everything else is automatic
- **Professional Installation**: Same seamless experience as commercial software
- **Universal Compatibility**: Works on any Ubuntu 22.04 system
- **Support Reduction**: Users won't get stuck on dependency issues

## [2.0.0] - 2025-10-20 - "Enhanced Pro" Release 🎵

### 🚀 MAJOR RELEASE: AAC+ Streaming & Smart Dependencies

#### Complete AAC+ Streaming System
- **Professional Streaming**: HE-AAC v1/v2 and LC-AAC support via FFmpeg
- **Quality Profiles**: High (128k HE-AAC v2), Medium (96k HE-AAC v1), Low (64k LC-AAC)
- **Multiple Protocols**: Icecast, Shoutcast, and RTMP streaming support
- **Automatic Reconnection**: Daemon mode with intelligent connection recovery
- **CLI Tools**: `rdx-stream` helper with start/stop/status commands
- **Configuration**: Profile-based configuration in `/etc/rdx/aac-profiles/`

#### Smart Dependency Management System
- **Intelligent Detection**: Automatic scanning of 15+ package categories
- **Auto-Installation**: Smart dependency resolution and installation
- **System Compatibility**: Ubuntu/Debian system optimization
- **Rivendell Integration**: Enhanced detection and configuration
- **CLI Tools**: `rdx-deps` helper for dependency management
- **Professional Error Handling**: Comprehensive validation and recovery

#### Enhanced Build System
- **Complete Builder**: `build-deb-enhanced.sh` with all features included
- **Command-Line Options**: Customizable builds with --no-aac, --include-gui, etc.
- **Professional Packaging**: v2.0.0 with enhanced metadata and dependencies
- **Multiple Variants**: Enhanced, Core, Adaptive, and Standard builders
- **Debug Support**: Development builds with symbols and logging

#### Comprehensive Documentation System
- **Package Builder Guide**: Complete guide with copy/paste examples
- **Quick Reference**: One-page cheat sheet for common operations
- **Scripts Documentation**: Feature matrix and usage instructions
- **AAC Streaming Guide**: Configuration and troubleshooting
- **Smart Installer Guide**: Dependency management and automation

### 📦 ENHANCED PACKAGE: rdx-rivendell-enhanced_2.0.0_amd64.deb

#### Professional Package Features
- **Size**: 74KB with comprehensive feature set
- **Dependencies**: Smart FFmpeg and multimedia library management
- **Installation**: Automated systemd service and user configuration
- **Desktop Integration**: Application launchers for streaming and control
- **Documentation**: Complete inline help and configuration guides

#### Enhanced CLI Toolset
- **rdx-jack-helper**: Core intelligent routing with enhanced features
- **rdx-stream**: AAC+ streaming management with profile support
- **rdx-deps**: Smart dependency detection and installation
- **rdx-aac-stream.sh**: Direct streaming script with advanced options
- **Enhanced Aliases**: Professional shortcuts for rd user

### 🎛️ SYSTEMD INTEGRATION

#### Professional Service Management
- **Enhanced Service**: rdx-jack-helper.service with streaming support
- **Environment Variables**: RDX_AAC_ENABLED, RDX_LOG_LEVEL configuration
- **Auto-Start**: Intelligent service enablement based on environment
- **Stream Management**: Automatic streaming service coordination
- **Monitoring**: Enhanced status reporting and logging

## [1.0.0] - 2025-10-20 - "WICKED" Release 🔥

### 🎉 MAJOR BREAKTHROUGH: Deb Packaging & Rivendell Integration

#### Complete Debian Package System
- **Multi-Package Strategy**: Core CLI, Standalone GUI, and Full Integration packages
- **Smart Adaptive Builder**: Auto-detects environment and builds appropriate package
- **Professional Installation**: Systemd service, shell aliases, desktop integration
- **Rivendell Web API Support**: Integration with official `rivwebcapi` headers
- **Zero-Dependency Core**: CLI package works on any Linux system

#### Rivendell Development Integration Discovery
- **rivendell-dev Package**: Successfully installed official Rivendell development package
- **Web API Headers**: Access to professional Rivendell Web API (`rivwebcapi`)
- **Enhanced Integration Path**: API-based coordination with broadcast automation
- **Future-Proof Design**: Uses stable Rivendell API contracts

#### Advanced Package Architecture
- **rdx-rivendell-core**: Universal CLI package with full intelligent routing
- **rdx-rivendell-gui**: Standalone GUI package for Qt5 systems  
- **rdx-rivendell-enhanced**: Professional API integration package
- **Smart Detection**: Builds appropriate package based on available dependencies

### 🖥️ COMPLETE GUI SYSTEM

#### Full-Featured Control Interface (800+ lines)
- **6-Tab Interface**: Profiles, Inputs, Services, Connections, Monitor, Advanced
- **Real-Time Monitoring**: Live JACK client display and connection status
- **Profile Management**: One-click switching between broadcast configurations
- **Service Control**: Start/stop audio processing services from GUI
- **Connection Viewer**: Visual display of all JACK connections
- **Advanced Controls**: Manual routing and system configuration

#### RDAdmin Integration Architecture
- **Seamless Integration**: 🔥 RDX Audio Control button in RDAdmin interface
- **Professional Experience**: Matches Rivendell's polished user interface
- **One-Click Access**: Full RDX control directly from broadcast automation
- **Context-Aware**: Knows when integrated with Rivendell systems

### 🚀 MAJOR FEATURES - Broadcast-Grade Intelligence

#### Intelligent Auto-Routing System
- **Smart Hardware Detection**: Automatically discovers audio processors (Stereo Tool, Jack Rack, Carla, Non-Mixer)
- **Streaming Client Recognition**: Detects streaming software (Liquidsoap, GlassCoder, Darkice, Butt, Icecast)  
- **Input Source Awareness**: Identifies input sources (VLC, System Capture, Hydrogen, Rosegarden)
- **Priority-Based Routing**: Configurable input source priorities (system=100, vlc=80, liquidsoap=60)

#### Critical Connection Protection 🛡️
- **Broadcast-Safe Operations**: Never interrupts live audio processing chains
- **Critical Client Protection**: Refuses to disconnect protected clients (processing, streaming)
- **Pattern-Based Safeguards**: Protects Rivendell→Processor→Streaming chains automatically
- **User-Configurable Protection**: XML-defined critical connections with priority levels
- **Override Protection**: Prevents accidental disconnection of live broadcast infrastructure

#### Profile-Based Service Orchestration
- **Auto-Service Startup**: Profile-driven service orchestration (Stereo Tool, Liquidsoap)
- **Smart Chain Building**: Automatically establishes processing chains based on detected hardware
- **Adaptive Configuration**: Works with any broadcast hardware setup, not hardcoded
- **Real-Time Monitoring**: Live JACK client detection and connection management

### �️ SIMPLIFIED MANAGEMENT

#### Replaces Manual JACK Control
- **Eliminates Complex Patching**: No need for manual JACK connection management
- **One-Command Operation**: Complete broadcast setup from single profile command
- **Intelligent Automation**: Automatic routing decisions based on audio context
- **Professional Workflow**: Focus on content creation, not technical routing

### �🎵 INTELLIGENT BEHAVIORS

#### VLC Auto-Routing
- **Intentional Media Detection**: VLC automatically routes to Rivendell (recognized as intentional playback)
- **Smart Conflict Prevention**: Only auto-routes when no other input is active
- **Dynamic Client Support**: Handles VLC instances with varying process IDs

#### System Capture Management  
- **Respectful Input Handling**: Physical inputs respect user/preset control (no automatic conflicts)
- **Manual Override Available**: `--switch-input system` for deliberate physical input routing
- **Live Switching**: Seamless input source changes without audio dropouts

#### Processing Chain Intelligence
- **Hardware Agnostic**: Detects and connects any audio processing setup
- **Flexible Port Matching**: Smart port detection with pattern matching (not hardcoded names)
- **Multi-Vendor Support**: Works with Stereo Tool, Jack Rack, Carla, and other processors

### 🛠️ TECHNICAL FEATURES

#### Enhanced JACK Management
- **Real-Time Client Monitoring**: 1-second interval JACK client change detection
- **Connection State Tracking**: Maintains awareness of current routing configuration  
- **Broadcast-Safe Disconnection**: Only touches input routing, never output connections
- **Multi-User JACK Support**: Promiscuous mode support for cross-user compatibility

#### Command-Line Interface
```bash
# Profile management with smart routing
rdx-jack-helper --profile live-broadcast    # Auto-establishes complete broadcast chain
rdx-jack-helper --list-profiles             # Show available configurations

# Input source control
rdx-jack-helper --switch-input vlc          # Route VLC to Rivendell
rdx-jack-helper --switch-input system       # Route physical inputs to Rivendell  
rdx-jack-helper --list-sources              # Show available sources with priorities

# Safety operations
rdx-jack-helper --disconnect vlc            # Safe disconnection (non-critical only)
rdx-jack-helper --scan                      # Hardware discovery and status
```

#### Configuration System
- **XML-Based Profiles**: User-configurable critical connections and routing rules
- **Hardware Detection Rules**: Configurable client type detection patterns
- **Priority Management**: User-defined input source priority systems
- **Profile Inheritance**: Multiple broadcast scenarios (live, production, automation)

### 🔧 INFRASTRUCTURE IMPROVEMENTS

#### Professional Build System
- **CMake Integration**: Professional build system with proper JACK/Qt5 linking
- **Multi-Target Support**: rdx-jack-helper service with modular architecture  
- **Library Management**: Proper ALSA, JACK, Qt5 Core/DBus dependencies
- **Conditional Building**: Smart detection of available components (GUI, API, headers)

#### Debian Package Infrastructure
- **Professional Package Builder**: Complete .deb creation with control files
- **Post-Installation Scripts**: Automatic service setup, user configuration, aliases
- **Dependency Management**: Smart detection and handling of system requirements
- **Multiple Package Variants**: Core, GUI, Enhanced, and Adaptive packages

#### Development Integration
- **rivendell-dev Support**: Integration with official Rivendell development package
- **Web API Integration**: Professional API coordination with broadcast automation
- **Header Compatibility**: Support for both local and system Rivendell headers
- **Future-Proof Architecture**: Ready for enhanced Rivendell integration

### 📦 PACKAGING & DEPLOYMENT

#### Package Variants
```bash
# Universal core package (works everywhere)
rdx-rivendell-core_1.0.0_amd64.deb
├── CLI tools: rdx-jack-helper
├── Systemd service integration
├── Shell aliases and desktop files
└── Professional installation scripts

# GUI-enabled package (Qt5 systems)
rdx-rivendell-gui_1.0.0_amd64.deb  
├── Includes: rdx-rivendell-core
├── Standalone GUI application
├── Desktop integration
└── Full control interface

# Enhanced API package (Rivendell systems)
rdx-rivendell-enhanced_1.0.0_amd64.deb
├── Core CLI + GUI functionality
├── Rivendell Web API integration
├── Professional broadcast coordination
└── Future-ready for full integration
```

#### Smart Installation System
- **Adaptive Detection**: Auto-detects Rivendell environment and builds appropriate package
- **User Aliases**: Convenient shell commands (rdx-scan, rdx-live, rdx-production)
- **Service Management**: Systemd integration with auto-start capabilities
- **Professional Deployment**: Production-ready installation for broadcast environments

#### Service Architecture
- **D-Bus Integration**: System bus service with fallback test mode
- **Real-Time Monitoring**: Timer-based JACK status and device scanning
- **Event-Driven Design**: Qt5 signal/slot architecture for responsive operations
- **Memory Management**: Proper resource cleanup and connection management

### 📡 BROADCAST ECOSYSTEM INTEGRATION

#### Rivendell Compatibility
- **Native Integration**: Built specifically for Rivendell broadcast automation
- **GlassCoder Support**: Fred Gleason's streaming encoder fully supported
- **RDAdmin Ready**: Architecture prepared for GUI plugin integration
- **Existing Workflow**: Enhances rather than replaces current Rivendell operations

#### Professional Features
- **Live Audio Priority**: Critical connections protected during all operations
- **Zero-Downtime Switching**: Input changes without interrupting broadcast output
- **Hardware Flexibility**: Supports any professional broadcast hardware configuration
- **Operator Safety**: Prevents accidental disconnection of live audio infrastructure

### 🚨 BREAKING CHANGES
- Initial release - no breaking changes from previous versions

### 📝 NOTES
- Requires JACK Audio Connection Kit
- Designed for Linux broadcast environments  
- Qt5 and ALSA dependencies required
- Tested with Stereo Tool, Liquidsoap, VLC, and standard ALSA hardware

### 🙏 ACKNOWLEDGMENTS
- Built for the professional broadcast community
- Inspired by real-world broadcast engineering needs
- Designed with live radio operation safety as primary concern

---

**This release represents a quantum leap in broadcast automation intelligence and safety.** 🎙️📡✨