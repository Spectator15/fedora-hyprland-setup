# Validation record and real laptop checklist

## What was actually tested

On 2026-09-13, development ran on Windows with Ubuntu/WSL for Linux-only checks.
The installer was **not run against the Windows host**. Official Fedora 43 and
44 x86_64 OCI images were unpacked into disposable Linux filesystems for DNF and native
binary checks. These were chroots, not booted graphical Fedora VMs: `/proc`,
`/sys`, systemd/logind, GPU devices and an interactive display were not provided.
Some RPM scriptlets reported that limitation; package transactions completed.

| Check | Result |
| --- | --- |
| `bash -n` on every project Bash file | Pass |
| ShellCheck with sourced libraries | Pass |
| Lua 5.4 parse of every project Lua file | Pass |
| 25 Python unit/integration tests in temporary homes | Pass |
| OS-release parsing, source selection, current-package rerun mocks, metadata failure | Pass |
| Actual installer dry-run branch with external side effects forbidden | Pass; no project/state directory created |
| Journal idempotency, original bytes/modes/symlinks, interrupted write recovery | Pass |
| Edited/unrelated-file retention, corrupt manifest, tampered backup and traversal refusal | Pass |
| DMS mixed-legacy-config guard, original app/Plasma configuration preservation | Pass |
| Session-local guards intercept upstream shared-environment writes | Pass |
| MRU forward/reverse/release/closed-window switching and 50 unique bindings | Pass using Lua API mocks |
| Clamshell close/open/external disconnect | Pass using the released monitor API shape in mocks |
| Session readiness, environment handoff and owned process cleanup | Pass using mock compositor/DMS |
| DMS managed restart, shell failure and compositor failure before readiness | Pass using mocks |
| Failed DMS setup, failed native parser and rollback of partial deployment | Pass using mocks and the real deployment journal |
| Cancelled OCR capture leaves clipboard untouched | Pass using CLI mocks |
| Real Fedora 43 and 44 package resolution/install, including extras and OBS | Pass |
| Actual DMS 1.6.1 headless Lua generation | Pass on both Fedora filesystems |
| Actual Hyprland 0.56.2 native profile parsing | Pass on both |
| Optional clamshell configuration native parsing | Pass on both |
| DMS's native cheat-sheet parser discovers project includes/keybinds | Pass on both |
| Native GIO launcher parsing of spaces, quotes, dollar signs and backslashes | Pass on both; harmless temporary executable only |
| Real DMS/Matugen palette outputs and generated Hyprland Lua | Pass on both |

Reproducible failures found and fixed included the DMS version command, Fedora
43's missing official Matugen, released-vs-development monitor APIs, backup reuse
after uninstall, and preflight checks before lock/file mutations. Tests validate
the specific failure behaviours, not just copied implementation strings.

The first CI run also exposed ShellCheck 0.9's handling of optional function
arguments and Hyprland's requirement for `XDG_RUNTIME_DIR` even for `--version`.
Callers now pass the OS-release path explicitly, and the native version probe runs
as the test user after creating its private runtime directory.

## Run tests

On Linux, install Python 3, Bash, ShellCheck and Lua 5.4, then:

```bash
./tests/run.sh
```

`LUA_BIN` and `LUAC_BIN` can select alternate Lua 5.4 binary paths. Run as a normal
user because the installer dry-run deliberately rejects root. This suite uses
temporary directories/mocks and does not install desktop packages.

The GitHub workflow also has Fedora 43/44 jobs. To repeat the package/parser probe
locally, use a **disposable** Fedora container, copy this checkout into it, and run
`FH_DISPOSABLE_TEST=1 bash tests/fedora-packages.sh` as that container's root.
The probe deliberately installs packages/enables COPRs inside the container,
then uses an unprivileged test user for DMS and configuration checks. Never run
that probe on your normal OS. No pass is claimed for remote CI until it actually runs.

Research clones, downloaded RPM/image layers, temporary logs and Python caches
are ignored and must never be committed. The checked-in tests do not depend on
the local `.work/` research cache.

## First Fedora laptop test

This checklist is still **unperformed**. A parsed config and successful container
package transaction cannot prove a desktop works on a GPU/laptop.

1. Record Fedora/kernel versions, GPU/driver, panel modes and existing power
   stack locally. Do not upload machine IDs, serials, account data or Wi-Fi secrets.
   Confirm Plasma, SDDM, suspend/resume and existing HDR-off state work first.
2. Run dry-run and inspect the DNF transactions. Install from Plasma. Verify that
   both Plasma and Hyprland (Fedora DMS) are selectable at SDDM; log into each.
3. Check DMS startup, app launcher, notification/polkit prompts, lock, logout,
   crash recovery and shell restart. Run `./scripts/verify-install.sh` inside and
   outside Hyprland. Test actual portal D-Bus activation, not just package files.
4. Open several native/XWayland/Flatpak windows across workspaces. Test quick and
   held Alt+Tab, reverse, closing mid-cycle, maximized/fullscreen windows, overview,
   numeric workspace moves, title-bar controls and Super+mouse drag/resize.
5. Test tapping/dragging, two-finger scroll/right-click, typing suppression and
   three-finger 1:1 swipes in both directions. Check animation pacing, scroll
   direction, keyboard layout and external mouse acceleration.
6. Test speakers/headphones, output switching, per-app volume, microphone mute,
   brightness, media keys, Bluetooth and VPN interactions. Check DMS's active-mode
   indicators and visible Stay Awake inhibition. Test Night Light separately.
7. Check native preferred refresh and scale, **SDR/sRGB with HDR off**, app text
   clarity, external monitor hotplug and recovery after unplugging. Enable the
   optional clamshell module only after normal lid behaviour works; test closed
   lid docked, undocking, opening and suspend/resume with both power sources.
8. Change wallpaper and dark/light mode. Verify GTK, Dolphin, Kitty, Brave and
   representative Flatpaks; restart apps as needed. Fully log out, return to
   Plasma and compare its theme, cursor, wallpaper, portals and display settings.
9. Test screenshot region/window/display, saved image and image clipboard history,
   OCR/QR cancellation/success, OBS PipeWire selection and separately chosen audio.
   Try LocalSend using your existing network/firewall policy.
10. Measure idle GPU/CPU use, real battery drain and thermal behaviour. Test lock
    before lid suspend/resume on AC and battery. Opt into separate DMS power
    profiles only after confirming no other active service fights them.
11. Rerun the installer from Plasma; confirm preferences survive. Test uninstall
    dry-run, edited-file retention, backup restore and removal of the project
    login entry. Plasma must remain usable throughout.

Known limitations are explicit in the README/theming/troubleshooting guides:
no Alt+Tab thumbnail preview, optional clamshell/kernel lid interface, manual OBS
setup, partial custom-app/Flatpak theming, existing-Snapper-only snapshots,
private-bus interaction with independently launched user services, and the guarded
DMS legacy cleanup. Report real-hardware findings before calling this release
fully tested.
