# fedora-hyprland-setup

An optional, mouse and trackpad friendly Hyprland desktop for **Fedora KDE 43 and
44**. Keep Plasma, add DankMaterialShell (DMS), and choose either desktop at login.
This is an initial implementation for real laptop testing, not a tested hardware
distribution.

Hyprland arranges and draws your windows. DMS supplies the bar, app search,
notifications, lock screen, settings and wallpaper controls. Windows normally
tile automatically; you can also drag, resize, maximize or float them.

**Plasma and SDDM remain installed. HDR stays off.** No partition, bootloader,
Secure Boot, TPM, firmware, kernel parameter or Windows partition changes are made.
There is no Arch installer, Omarchy Shell, Waybar, Rofi or competing power daemon.

**Hyprland theming is designed to remain session-specific and should not replace
your Plasma theme.** See [theming behaviour](docs/theming.md) for the practical
limits, including Flatpaks and apps with their own appearance settings.

## Screenshots

Placeholder: add screenshots from the first Fedora laptop test here, including
the bar/control centre, overview, a GTK app and Dolphin. No simulated desktop
screenshots are presented as a working installation.

## Before installing

- Traditional Fedora KDE 43 or 44, with Plasma Wayland and SDDM already working.
  Fedora Kinoite/Atomic and other distributions are rejected.
- A normal user account with sudo access, internet access and several GB of
  free disk space. Install `git` first if it is missing.
- Run from Plasma or a TTY, not from this project's Hyprland session.
- Keep important personal data backed up. The installer backs up configuration
  files it replaces; it is not a whole-disk backup.

The reviewed API range is **Hyprland 0.56.x and DMS 1.6.x**, with Quickshell 0.3+
and Matugen 3.1+. New Hyprland or DMS minor releases require another review;
the installer and login wrapper stop with an explanation instead of loading an
untested configuration. Research was checked on **13 September 2026**.

## Install

```bash
git clone https://github.com/Spectator15/fedora-hyprland-setup.git
cd fedora-hyprland-setup
./install.sh --dry-run
./install.sh
```

Run these commands **without `sudo` in front of `install.sh`**. Only package and
system login-entry operations request sudo. DNF shows transactions for review.
Dry-run performs no writes, sudo calls, package queries or metadata refreshes; it
describes conditional repository choices rather than pretending to resolve them.

Optional additions:

```bash
./install.sh --with-extras        # OCR, QR extraction, btop
./install.sh --with-recording     # OBS Studio recording GUI
./install.sh --snapshot          # require an existing Snapper root setup
```

Flags can be combined with each other and with `--dry-run`. Reruns install
missing packages and preserve your preferences. They do not perform a blanket
system upgrade. A failed step exits with an error; fix it and rerun, or uninstall
the recorded configuration changes.

`--snapshot` only uses an already configured Snapper configuration named `root`
on Btrfs. It does not install Snapper, create subvolume layouts, set up automatic
update snapshots or change the bootloader. A root snapshot may exclude `/home`.

## Package sources

Fedora's `fedora` and `updates` repositories supply ordinary dependencies and
Matugen where available. Current Fedora repositories do not supply the required
Hyprland/DMS combination. These upstream-recommended COPRs are enabled as needed:

| COPR | Why |
| --- | --- |
| `lionheartp/Hyprland` | Hyprland 0.56 and its matching portal/libraries; currently recommended by the Hyprland installation wiki |
| `avengemedia/dms` | Stable DMS and DMS CLI; used by DMS's Fedora installer |
| `avengemedia/danklinux` | DMS's Quickshell/dgop dependencies; also Matugen on Fedora 43 |

COPRs are third-party repositories, not Fedora's official package collection.
They remain enabled after uninstall because installed packages still need updates.
The installer records newly enabled sources and checks availability before
deploying user configuration. It never uses `--allowerasing` to resolve conflicts.
See [upstream evidence and version details](docs/upstream.md).

## Choose the desktop at login

Log out of Plasma. In SDDM's session selector choose **Hyprland (Fedora DMS)**.
Choose **Plasma** to return to your familiar desktop. The RPM may also provide a
plain **Hyprland** entry; use **Hyprland (Fedora DMS)** for this setup.

This entry is installed for the account that ran the installer. Fully log out
before changing desktops; simultaneous graphical sessions for the same account
are deliberately rejected when Plasma or another DMS service is active.

On first login, click the launcher or press Super+Space. Open DMS Settings to
choose a wallpaper and enable dynamic colours. The initial palette works before
you choose a wallpaper; no personal wallpaper or location is downloaded.

## Everyday controls

**Super means the Windows-logo key.** Press **Super+Shift+/** (the `?` key on a US
layout) for DMS's visual shortcut cheat sheet. You can also search for **Keyboard
shortcuts** in the launcher; this works on other keyboard layouts too.

| Shortcut | Action |
| --- | --- |
| Alt+Tab / Alt+Shift+Tab | Next / previous recent window |
| Alt+F4 | Close active window |
| Super+Space | DMS app search, calculator and launcher tools |
| Super+Enter | Kitty terminal |
| Super+E | Dolphin file manager |
| Super+L | Lock |
| Super+Tab | Visual window/workspace overview |
| Super+V | Searchable text/image clipboard history; choose then Ctrl+V |
| Super+Shift+S or Print | Region screenshot: save and copy |
| Alt+Print / Ctrl+Print | Active window / focused display screenshot |
| Super+1…9 | Switch workspace |
| Super+Shift+1…9 | Move window to workspace, stay on current workspace |
| Super+left / right mouse drag | Move / resize window |
| Super+Up | Maximize / restore |
| Super+Shift+F | Float / tile the active window |
| Super+, | DMS Settings |
| Ctrl+Alt+Delete | Power menu and logout |

Volume, mute, microphone mute, brightness and media keys call DMS, including its
on-screen indicators. Normal Ctrl+C/Ctrl+V are unchanged. No H/J/K/L workflow is
required. Click window title-bar controls when an application provides them.

**Alt+Tab behaviour:** this project's small Lua switcher snapshots recent-window
order when you start cycling. Hold Alt and keep pressing Tab to visit every
eligible window; Shift reverses. Releasing Alt starts a new MRU cycle next time,
so a quick Alt+Tab returns to your previous window. It visits mapped, non-hidden
windows across normal workspaces, raises the selected window and focuses it
immediately. There is no thumbnail strip or Escape-to-cancel preview. Use
Super+Tab for DMS's visual overview. New windows join on the next cycle. This
avoids a fragile extra switcher daemon or focus-history churn on each Tab press.

## Trackpad and clickable panels

Tap to click, tap and drag, natural scrolling, two-finger scrolling, two-finger
right-click and disable-while-typing are enabled. Focus stays with the window you
click, rather than following incidental pointer movement.

**Three-finger horizontal swipes** use Hyprland's native workspace gesture: the
workspace follows your fingers continuously. Two-finger gestures remain available
to applications. Workspaces can also be clicked/scrolled on the bar.

Click the clock for the calendar, music for media controls, notifications for
history, clipboard for saved items, and battery for power information. The control
centre exposes audio output/input, volume, brightness, Wi-Fi, Bluetooth, Night
Light, dark/light mode, Do Not Disturb, Stay Awake and display profiles. Scroll
over the control-centre audio/brightness indicators to adjust them. DMS's native
interaction conventions are retained.

Stay Awake has an active indicator and OSD. It is temporary, not a change to
system suspend policy. Screen-sharing and microphone indicators are enabled.
Night Light changes colour temperature; **it does not enable HDR**.

## Laptop power and displays

The wildcard display rule uses the panel's **preferred resolution and refresh**,
scale 1, SDR/sRGB and 8-bit output. It does not assume 60 Hz or a GPU model.
For the 1920×1080 internal panel this gives its native mode. DMS Display Settings
can create connector-specific overrides. Existing Plasma monitor/HDR settings
are neither imported nor modified; configure a different scale in DMS if needed.

Fedora's existing power infrastructure is retained (normally tuned/tuned-ppd on
these releases). DMS uses its existing power-profile API. Automatic AC/battery
profile selection is **off by default**; in DMS's power settings you can opt into
remembered profiles, for example AC **Balanced**, battery **Power Saver**.
There is no additional profile-switching daemon or forced performance mode.

The session locks after 10 minutes on AC / 5 on battery and blanks displays after
15 / 10 minutes. Automatic idle suspend is not added. DMS requests locking before
suspend; logind retains normal lid policy. Verify this on your laptop before
depending on unattended suspend.

Optional clamshell support is described in [troubleshooting](docs/troubleshooting.md).
It is off until you enable it after checking your dock and lid behaviour. No
logind configuration is changed.

## Capture, sharing and extras

DMS screenshots save in your Pictures/Screenshots directory and copy to the
clipboard. Search **Screenshot window**, **Screenshot display**, or **Pick a
screen colour** in the launcher for mouse-accessible actions.

With `--with-extras`, search **Screen OCR** or **Screen QR** to select a region and
copy recognised text. Cancelling does not erase your clipboard. OCR initially
includes English; other Tesseract language packs are an optional Fedora install.
`btop` is also available for an optional system monitor. DMS already supplies
notifications, clipboard, calculator, emoji tools and media controls.

With `--with-recording`, launch **OBS Studio**, add a **Screen Capture (PipeWire)**
source and choose the display/window through the permission dialog. Add desktop
and/or microphone audio sources as desired; audio recording is never enabled
automatically. Configure the output directory in OBS. This is a richer GUI with
some first-use setup, not Omarchy's single-key recorder.

LocalSend remains optional. An already installed native or Flatpak LocalSend is
available in DMS's launcher; use its own file selection/share UI. This project
does not change firewall rules or install file-manager plugins.

## Configuration, updating and rollback

The default private profile is:

```text
~/.local/share/fedora-hyprland-setup/
  bin/                         copied session/helper code
  paths.json                   original XDG roots
  profile/config/hypr/
    hyprland.lua               project entrypoint
    dms/                       DMS-generated colours/layout/output files
    dms/binds-user.lua          supported user override hook
    fedora/user.lua            your preserved preferences
    fedora/{input,appearance,animations,keybinds,switcher,clamshell}.lua
  profile/config/DankMaterialShell/settings.json
  profile/config/{gtk-3.0,gtk-4.0,kitty,dconf}/
  profile/data/                private colour schemes and launcher actions
```

XDG custom paths are supported; the installer prints actual destinations. Edit
`fedora/user.lua` for your changes. For example, unbind Super+Return and bind your
preferred terminal as shown there. Put overrides after the `require` lines.
`hyprctl reload` applies Lua changes in the project session. DMS Settings is the
normal graphical place for appearance, controls and wallpaper preferences.

The installer invokes `dms setup headless --no-systemd` in a temporary staging
home. It never runs setup over your real home. It seeds generated files once,
uses DMS's `binds-user.lua` hook, and keeps custom modules separate. DMS's generated
`binds.lua` is not loaded, so shortcuts have a single owner. Existing `user.lua`,
DMS settings and generated preferences survive reruns. A bare `dms setup` acts
on DMS's ordinary paths, not this private profile; use this installer to refresh
our setup. An independent upstream setup may change ordinary desktop files and
is outside this project's rollback journal.

Update Fedora through its normal tools. From Plasma, update this checkout and
rerun the installer, then verify. When a new upstream minor version lands, wait
for an updated compatibility review rather than disabling the version guard.

```bash
git pull --ff-only
./install.sh
./scripts/verify-install.sh
```

Backups and the JSON change journal live under
`~/.local/state/fedora-hyprland-setup/`, including the change journal in
`manifest.json`, uniquely named backup files in `backups/`, and
observed package/new-repository lists. Original bytes, modes and symlink targets
are preserved before replacement. The installer refuses to overwrite edited
managed files; move your edit into `user.lua` or merge it deliberately.

From Plasma or a TTY:

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

Uninstall removes the matching project login entry and unchanged project files
and links, restoring verified backups. Edited/generated files and unrelated
files are retained with messages. It never recursively deletes the profile,
removes packages/dependencies, disables repositories or touches Plasma.
Backups and the remaining journal stay available for recovery. An interrupted
installation can be rerun; journaled writes are recoverable.

## Verification and further reading

`./scripts/verify-install.sh` checks packages, both login choices, commands,
configuration, symlinks, SDR defaults and theme isolation, and invokes Hyprland's
native parser. Inside the session it also checks `hyprctl` errors, duplicate
bindings and DMS IPC. Outside it, live checks are explicitly skipped.

- [Troubleshooting and recovery](docs/troubleshooting.md)
- [Theming behaviour and Plasma isolation](docs/theming.md)
- [Omarchy-inspired feature decisions](docs/omarchy.md)
- [Upstream versions, sources and attribution](docs/upstream.md)
- [Tests performed and real laptop checklist](docs/testing.md)

Repository structure: `install.sh` / `uninstall.sh` are small Bash entrypoints;
`lib/` separates packages, repositories, journaled deployment and diagnostics;
`config/` contains defaults; `runtime/` owns session processes; `scripts/` contains
verification/snapshot helpers; `tests/` and `.github/workflows/` validate changes.

## Credits and licence

[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) is the shell
and provides the supported integrations. [Dusky](https://github.com/dusklinux/dusky)
inspired the fluid curves, workspace slides and restrained opening/closing motion;
we adapted a few MIT-licensed curves with shorter timings and less zoom.
[Omarchy Quattro](https://github.com/omacom/omarchy/tree/quattro) inspired the
clickable controls and useful laptop workflows, implemented through DMS/Fedora.
Neither Arch project's installer or package framework is used.

This repository is MIT-licensed. Required notices for adapted DMS/Dusky
configuration are in [LICENSES](LICENSES/). No Omarchy code is copied.
