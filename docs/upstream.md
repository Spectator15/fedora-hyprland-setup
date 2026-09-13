# Upstream research and compatibility record

Reviewed 2026-09-13. Re-check these sources before widening compatibility. Live
repository metadata, released package binaries and source were used together;
the latest wiki alone is insufficient during the Hyprland Lua transition.

## Fedora and package sources

- [Fedora release lifecycle](https://docs.fedoraproject.org/en-US/releases/lifecycle/):
  this implementation targets traditional Fedora KDE 43 and 44, not Rawhide or
  Atomic variants.
- [Fedora Hyprland package page](https://packages.fedoraproject.org/pkgs/hyprland/hyprland/)
  still reflects older/orphaned Fedora builds. Real Fedora 44 repository queries
  did not provide the required compositor; old 0.44/0.45 examples are unsuitable.
- [Current Hyprland installation recommendations](https://wiki.hypr.land/Getting-Started/Installation/)
  name `lionheartp/Hyprland` for Fedora. We verified its 43/44 metadata and installed
  **Hyprland 0.56.2** and **xdg-desktop-portal-hyprland 1.4.1** in disposable Fedora
  filesystems. No obsolete solopasha fallback is embedded.
- [DMS installation docs](https://danklinux.com/docs/dankmaterialshell/installation)
  currently show a simple Fedora `dnf install dms`. This differs from available
  official metadata. DMS's actual [Fedora installer source](https://github.com/AvengeMedia/DankMaterialShell/blob/6b50696b8acc25e9fc6d12fe88d86060525c97f0/core/internal/distros/fedora.go)
  specifies stable `avengemedia/dms` and companion `avengemedia/danklinux`.
  Both provide current Fedora 43/44 builds. We resolved and installed **DMS/CLI
  1.6.1**, **Quickshell 0.3.1** and **dgop 1.6.0**; dgop is a DMS dependency.
- Official Fedora 44 has Matugen **3.1.0**; Fedora 43 required the companion COPR
  (**4.2.0**) in our test. The selected tonal-spot/dark-light templates work with
  both. The installer prefers a sufficient official Matugen and fails if required
  metadata/package sources disappear.
- [Fedora's tuned power-profile change](https://fedoraproject.org/wiki/Changes/TunedAsTheDefaultPowerProfileManagementDaemon)
  explains tuned/tuned-ppd for KDE/GNOME. We use the existing API through DMS;
  neither TLP nor another power-profiles-daemon installation is added.

Live COPR projects: [Hyprland](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/),
[DMS stable](https://copr.fedorainfracloud.org/coprs/avengemedia/dms/),
[Dank Linux companions](https://copr.fedorainfracloud.org/coprs/avengemedia/danklinux/).
Only `fedora`, `updates` and explicitly selected repositories participate in the
stack transactions. Repository keys/acceptance use DNF's normal COPR workflow,
not downloaded scripts. Third-party repository trust and future availability
remain operational dependencies. Already installed sufficient packages are kept.

## Hyprland and DMS API decisions

- Released [Hyprland v0.56.2](https://github.com/hyprwm/Hyprland/tree/v0.56.2)
  (`efb50993780079460b0cbed1363e2166a2de1d9f`) was checked alongside current
  [wiki source](https://github.com/hyprwm/hyprland-wiki/tree/507259eb028c64d58bd080a157fe98f48d45b579).
  The native `Hyprland --verify-config --config ...` parser accepted the real
  generated profile. Lua syntax alone cannot validate compositor API calls.
- The released Lua API provides `hl.bind`, `hl.gesture`, `hl.curve`, `hl.animation`,
  query objects and window dispatchers. `hl.get_monitors()` in 0.56.2 returns active
  monitors; it does **not** support the newer development branch's `all` option
  or monitor `enabled` field. Our optional clamshell code uses the released API.
- The released [exec-once executor](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/supplementary/executor/Executor.cpp)
  imports environment values without checking `HYPRLAND_NO_SD_VARS`, unlike the
  main compositor startup/shutdown path. We set that flag and add session-local
  guards for shared systemctl environment writes / D-Bus `--systemd` imports.
  Other operations delegate to Fedora's binaries. No system files are patched.
- Native three-finger horizontal workspace gestures give continuous movement.
  No gesture daemon, key simulation or two-finger gesture capture is needed.
- DMS's `setup alttab` source currently supplies a **Niri** config, not a Hyprland
  Windows-style switcher. Hyprland's simple next-window cycling is not an MRU
  switcher with frozen order. Our small Lua implementation freezes addresses
  using `focus_history_id` and resets via non-consuming Alt release bindings.
  DMS's overview remains the visual alternative; no unreviewed plugin is installed.
- [DMS embedded Hyprland config](https://github.com/AvengeMedia/DankMaterialShell/tree/6b50696b8acc25e9fc6d12fe88d86060525c97f0/core/internal/config/embedded)
  establishes the Lua generated files and `dms/binds-user.lua` mechanism. We run
  headless setup in a temporary HOME, because the deployer currently uses HOME
  directly. The actual DMS keybind parser successfully discovers our includes,
  descriptions and numeric workspace loop.
- [DMS IPC reference](https://danklinux.com/docs/dankmaterialshell/keybinds-ipc)
  and current source were checked for launcher, lock, overview, audio, brightness,
  media, clipboard, settings and shortcut UI calls. Screenshots and colour picking
  use native DMS CLI functionality. Notifications, clipboard, power settings and
  Night Light also stay with DMS.
- DMS's backend runs with the UI in `dms run`. Its [supervisor source](https://github.com/AvengeMedia/dankgo/tree/07e1ef7caaea/shellapp)
  supports `--session` and restart exit 75. Our wrapper owns that lifecycle; no
  systemd theme environment import or user-unit enablement is performed.
- DMS's [startup migration](https://github.com/AvengeMedia/DankMaterialShell/blob/6b50696b8acc25e9fc6d12fe88d86060525c97f0/core/internal/config/hyprland_lua.go)
  ignores XDG for old Hyprland `.conf` cleanup. A read-only preflight blocks the
  affected mixed-config case. This prevents an upstream side effect on original
  user files without modifying DMS's installed code.

## Theme, portals and terminal choices

[DMS application theme documentation](https://danklinux.com/docs/dankmaterialshell/application-themes)
and its actual Matugen templates were inspected. Outputs use XDG config/data
roots. We enable GTK, Hyprland, Kitty and KColorScheme outputs, keeping unsupported
or shared editor/browser integrations off. The upstream Dolphin fallback is a
private `UiSettings/ColorScheme=DankMatugen` entry. Standard qt6ct does not fully
cover KDE applications; Fedora's GTK platform plugins were confirmed present for
both Qt versions. Global Qt overrides would also affect Plasma, so none are used.

[Portal configuration documentation](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html)
allows a desktop-specific `hyprland-portals.conf`. Its copy lives inside the
private config root. Hyprland handles screen sharing/screenshots; KDE handles
file selection; GTK supplies settings/fallback services. Real screen sharing,
Flatpak access and private-bus activation still need a graphical Fedora test.

Fedora 44 metadata provided Kitty 0.47.1 and Foot 1.27.0, but not Ghostty in the
official sources queried. Kitty has a maintained DMS template and is the only
terminal we add. Breeze/Noto come from Fedora; DMS provides its shell icon font.

## Dusky and Omarchy

The actual [Dusky Showcase preset](https://github.com/dusklinux/dusky/blob/a814be42e2e3d17d33696605acf38ee953397e8b/.config/hypr/source/animations/dusky.lua)
uses overshoot/fluid/snap curves and workspace/window animations. We adapted a
small subset with shorter timings, less zoom and slightly less overshoot. All
calls pass the released Hyprland parser. Attribution and its MIT notice are kept
in `LICENSES/Dusky-MIT.txt`. The installer was never executed.

[Omarchy's current Quattro branch](https://github.com/omacom/omarchy/tree/31bd80daa4613ffdee995ac27467fce5a2990806)
and the [top bar](https://omarchy.org/manual/the-top-bar/),
[monitors](https://omarchy.org/manual/monitors/), and
[capture manual](https://omarchy.org/manual/screenshots-recording/) informed the
feature choices in [the Omarchy matrix](omarchy.md). Its own Quickshell shell,
Arch package framework, global copy/paste emulation, branding, application bundle
and boot/snapshot integration are not used. No Omarchy code was copied.

DMS-derived configuration actions are attributed under its MIT notice in
`LICENSES/DankMaterialShell-MIT.txt`; the original project MIT licence is retained.
