# Troubleshooting and recovery

Start by logging out and choosing **Plasma** in SDDM. Run
`./scripts/verify-install.sh` from the checkout. Outside Hyprland, skipped live
checks are normal; a failed static or native parser check is not.

## No project session, or it returns to the login screen

Use **Hyprland (Fedora DMS)**, not the package's plain Hyprland entry. It runs the
copied session wrapper in your private project directory. The installer creates
one `/usr/share/wayland-sessions/fedora-hyprland-dms-UID.desktop` file after the
native parser succeeds. Existing Plasma entries and SDDM configuration are left
alone. Another account must install its own profile.

Home/XDG paths must be absolute and contain no line breaks. `XDG_DATA_HOME`
also cannot contain `=` or `%`, because desktop launchers cannot reliably encode
those executable paths. The installer rejects these before mutation. Spaces and
ordinary quoted path characters are supported and tested with Fedora's launcher parser.

Check the install error and SDDM's session log (commonly
`~/.local/share/sddm/wayland-session.log`) and `journalctl -b`. Logs may contain
private app/window names; review before sharing. From a TTY, log in normally and
run `./uninstall.sh` if you want to remove the project entry.

The wrapper intentionally refuses a concurrent Plasma session, a separate active
`dms.service`, an active installer/uninstaller, or an unreviewed Hyprland/DMS minor
version. Fully log out instead of using Switch User for the same account. If you
previously configured a global DMS service, inspect `systemctl --user status dms`
and stop it before this session. This installer does not disable your services.

The session supervisor starts Hyprland, waits for its ready hook, then runs
`dms run --session`. Here `--session` requests managed restart semantics; our
Python supervisor owns it, not a systemd unit. DMS exit 75 restarts the shell in
the same private environment. Other DMS failures end the compositor session and
return to SDDM. A normal exit terminates owned child groups. `launchPrefix=env`
keeps launcher apps in the same environment without systemd's default scope prefix.

## DMS reports mixed legacy Hyprland files

DMS 1.6's startup cleanup checks **`$HOME/.config/hypr` directly**, even when XDG
configuration is elsewhere. If that directory contains both `hyprland.lua` and
legacy `hyprland.conf` or `dms/*.conf`, upstream would relocate the legacy files.
Our preflight stops before it can do so and lists affected paths.

Back up and inspect your existing setup. If those legacy files are obsolete,
relocate them yourself outside that directory, preserving any data you need.
If they are still needed, keep using the existing setup/Plasma until this upstream
migration is resolved. The project never guesses which original config to remove.
This condition does not occur on a fresh Fedora KDE install with no Hyprland config.

## Package errors or an update changed versions

Check the exact repository/package named by the error and [the source notes](upstream.md).
Do not add random COPRs, downgrade a mixed graphics stack or use `--allowerasing`.
The reviewed version range is deliberately narrow. COPR availability and Fedora
dependencies can change; the script refuses incompatible candidates before user
deployment. Earlier successful package transactions are retained on a later
failure. Update the project after a compatibility review and rerun from Plasma.

If a project-managed file was edited, rerunning refuses to replace it. Move the
customisation into `profile/config/hypr/fedora/user.lua`, or save your version
elsewhere and deliberately merge. DMS preferences and this user file are seeded
once and are never reset on rerun. The manifest is JSON data, not executable shell.
Do not edit it to bypass a failure without understanding the backup mapping.

## File pickers, Flatpaks or screen sharing fail

A portal is a service that lets an app request a file picker, screenshot or
permission to share your screen. This profile selects the Hyprland backend for
ScreenCast/Screenshot, KDE for file selection, and GTK for Settings/dark-light
preferences, with GTK as a general fallback. All backends stay installed so
Plasma retains its normal KDE portal.

The private D-Bus session starts activated services with the project's XDG paths
and Wayland display. It does not change systemd's global user environment.
Session-local command guards also block the compositor's shared environment
imports. If you explicitly need to configure a shared user service's environment,
do that from Plasma or a TTY; importing the rice's variables would defeat isolation.
Always launch test apps inside this session, not through a stale Plasma terminal
or a separately configured systemd user service. Such services can inherit their
own old environment. No broad Flatpak filesystem or environment overrides are used.

Inside the project session try:

```bash
hyprctl configerrors
dms ipc list
busctl --user list
```

Use DMS's launcher to start a native app and a Flatpak, test their file pickers,
then test Brave/OBS screen sharing. Restart the app after changing desktops. Some
apps only support sharing an entire display or need their own Wayland setting.
XWayland is installed for applications that still need X11; it is not disabled.
Do not globally force browser/Electron flags. VPN, Bluetooth, LibrePods and other
existing application services are not reconfigured by this project.

## Colours differ or Plasma seems affected

See [theming behaviour](theming.md). Restart GTK/Qt apps that cached their palette.
Make sure you selected a wallpaper/dynamic theme in DMS. Flatpak sandbox access
and custom UI engines limit exact accents; do not weaken permissions to fix this.
Run the isolation verifier from Plasma. Inspect your own prior global theme
exports and manual DMS template choices; the project never installs such exports.

## Keyboard layout, pointer and displays

`fedora/input.lua` leaves `kb_layout` empty so XKB can use session defaults. If your
SDDM environment supplies no layout, set the correct value explicitly at the end
of preserved `fedora/user.lua`, for example:

```lua
hl.config({ input = { kb_layout = "gb" } }) -- replace with your actual layout
```

The physical `?` key varies by layout. The launcher action **Keyboard shortcuts**
always provides mouse access to the cheat sheet. Bind changes should unbind the
existing key before adding a replacement. DMS's generated bind list is not also
loaded, avoiding duplicate media keys and launcher actions.

Display defaults are native preferred refresh, scale 1 and SDR. Change connector
rules through DMS Display Settings or a user Lua override. Do not enable HDR or
10-bit output as a troubleshooting step. HDR experiments should be a separate
future change based on the current Hyprland monitor documentation; this project
does not ship an HDR toggle, global wide-gamut variables or KDE HDR changes.

To reduce GPU work, lower/disable blur and animations in `user.lua`, for example:

```lua
hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })
```

No continuous rotating border animation, forced performance profile, CAVA
visualizer or always-running system monitor is enabled. Measure actual idle
power, battery drain and frame smoothness on your hardware.

## Optional clamshell

After testing ordinary lid suspend, uncomment `require("fedora.clamshell")` in
`fedora/user.lua`, then reload. It detects eDP/LVDS/DSI internal outputs and active
external outputs, reads kernel lid state, and disables the internal output only
when closed with an external screen. It restores panels it disabled when opened
or when the last external output disappears, including after a config reload.
It uses a small two-second in-process timer only when enabled; there is no new daemon.

It needs `/proc/acpi/button/lid/*/state`, available on many x86 laptops. If absent,
the module remains inactive. It preserves scale/position when restoring but uses
the preferred mode. It does not override firmware or logind's suspend decision.
Dock-specific inhibitors, suspend while undocking, output ordering and GPU quirks
must be tested physically. If it misbehaves, disable the require line and use
DMS Display Settings/Plasma while investigating.

## Backups and removal

Uninstall first validates manifest paths and backup hashes, then removes only a
matching project login entry and safely restores/removes tracked files. Changed
files remain with `[keep]` messages. Backups, remaining manifest, packages and
COPRs are retained. It never calls `dnf remove`, disables SDDM or deletes an entire
home/config tree. A modified login entry is also kept for deliberate inspection.

The project holds a lock while its desktop session is active. Run updates or
uninstall from Plasma/TTY after logout. No installer is safe against concurrent
manual edits to its own state; avoid editing files while it is running.
