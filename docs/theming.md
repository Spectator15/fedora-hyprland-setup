# Theming behaviour

Hyprland theming is designed to remain session-specific and should not replace
your Plasma theme.

## What changes

In DMS Settings, choose a wallpaper and the Dynamic theme. Matugen generates a
matching palette; light/dark mode is available in the control centre. The initial
scheme is tonal-spot, which also works with Fedora 44's Matugen 3.1. Smart/image
scheme features that require newer Matugen are not selected by this project.

| Application family | Integration | Refresh expectation |
| --- | --- | --- |
| DMS | Wallpaper palette, light/dark, rounded surfaces | Live |
| Hyprland | Borders from DMS-generated `dms/colors.lua` | Config reload on generated change |
| GTK 3 | adw-gtk3, generated CSS colours, Breeze icons, Noto fonts | Many live changes; reopen stubborn apps |
| GTK 4 / libadwaita | Supported CSS variables and portal dark/light | App-dependent; restart may be needed; no forced theme engine |
| Kitty | DMS-supported generated palette | DMS sends reload signals; reopen if needed |
| Qt 5 / Qt 6 | Fedora GTK platform bridge; icons and system palette where respected | Restart usually safest |
| Dolphin | Private `dolphinrc` selects generated DankMatugen KColorScheme | Reopen after a palette change if necessary |
| Brave / Chromium | Native system/GTK appearance and dark/light preference where supported | Select system/GTK theme in the browser; sometimes reopen |
| Electron / VS Code / VSCodium | System dark/light when the app is set to follow it | App-dependent; editor palette integration is optional |
| Flatpaks | Portal dark/light and the app's packaged theme support | App-dependent; no promise of host CSS/accent access |
| Steam, Mullvad, Stremio, LocalSend, web apps/custom UIs | Their own appearance settings | Usually only app-supported light/dark, sometimes neither |

There is no browser-profile rewrite, injected browser CSS, extension install,
input injection or broad Flatpak filesystem permission. Browser wallpaper accents
are not reliably portable. Set Brave's appearance to its system/GTK option if
offered; this is a browser preference shared between desktops. Web content may
ignore system dark mode.

Kitty was selected because Fedora supplies it, it supports Wayland and DMS has a
maintained palette template. Foot is also in Fedora but less convenient for this
existing integration. Ghostty was absent from the tested official Fedora 44
metadata. Only Kitty is added. DMS supplies its own Material Symbols font/icons;
the default terminal does not require a large Nerd Font bundle. Breeze cursor
at size 24 and Noto Sans/Mono are scoped to this session.

## Where isolation happens

The dedicated SDDM wrapper exports private `XDG_CONFIG_HOME`, `XDG_DATA_HOME`,
`XDG_STATE_HOME` and `DCONF_PROFILE` for its children. It starts a private D-Bus
session so activated portals/settings services see the same private environment.
It does **not** import theme values into the shared systemd user manager.
`HYPRLAND_NO_SD_VARS=1` disables the normal compositor import. Because 0.56.2 has
an additional startup import that ignores this flag, the session PATH contains
two narrow guards: `systemctl --user` environment writes are skipped, and
`dbus-update-activation-environment` drops `--systemd`. Other systemctl operations
delegate to Fedora's binary. These guards are not installed in a global PATH.
`QT_QPA_PLATFORMTHEME=gtk3` is set only here; `GTK_THEME`, `QT_STYLE_OVERRIDE` and
global HDR variables are not set. Fedora's Qt 5 and Qt 6 GTK plugins are installed.

Theme files live in `profile/config`, generated colour schemes in `profile/data`,
and dconf changes in the private `fedora-hyprland` database. The original dconf
database is copied once to preserve initial preferences. Original `kdeglobals`,
Plasma config, GTK config, editor preferences and cursor settings are not edited.
Dolphin preferences are copied once before selecting the private colour scheme.

Existing application configuration/data directories are linked into the private
profile, except desktop/theme/systemd/autostart directories. This preserves
existing browser profiles and installed applications. The project never writes
through those app links. Applications themselves can still change their shared
preferences during normal use. This is **theme isolation, not a security sandbox**.
Apps which ignore XDG, Flatpak apps, and settings such as an editor's own selected
theme can remain shared. An application first configured in this private profile
may have separate preferences from Plasma. Original user launchers remain visible
through `XDG_DATA_DIRS`.

DMS 1.6 has one known startup migration that reads `$HOME/.config/hypr` directly.
The preflight guard refuses startup if both an original `hyprland.lua` and legacy
`.conf` files would trigger that migration. It never moves them automatically.
See troubleshooting. This is why new DMS minor releases are gated for review.

The installer never adds exports to `.profile`, `.bash_profile`, `.bashrc`,
`environment.d`, `/etc/environment` or `/etc/profile.d`. Verification scans these
locations for project theme exports. The portal configuration is also private.
No Plasma service, session file, default selection or theme is replaced.

## Optional editor/static themes

DMS supports VS Code and other editor templates, but enabling them can edit
shared editor preferences/extensions outside the private desktop profile. They
are **off by default**, along with browser, Discord and other app-specific hooks.
If you opt in via DMS's theme template UI, back up that app's settings first and
expect its theme to be shared with Plasma. Such manual DMS template changes are
not covered by this installer's file journal. btop uses its own theme selector;
no brittle automatic btop or Brave recolouring is installed.

DMS's own built-in/static theme choices and theme catalogue remain available.
We do not duplicate Catppuccin/Tokyo Night/Gruvbox/Everforest presets into another
theme manager. Availability of downloadable community themes is upstream-owned.

To stop dynamic recolouring, choose a built-in/static DMS theme. To stop changing
application palettes, disable the relevant GTK/Kitty/Hyprland/KColorScheme
Matugen templates in DMS Settings. Existing generated files retain their last
palette until you deliberately remove or replace them. Plasma needs no cleanup.

## Verify on the laptop

Before installation, note Plasma's theme, wallpaper, cursor and a GTK/Qt app's
appearance. Install, select Hyprland, change wallpaper and light/dark mode, and
test native and Flatpak file pickers. Log out fully and return to Plasma: compare
the same settings/apps. Run verification from both environments. Do not run two
graphical desktops for the same account concurrently during this check.
