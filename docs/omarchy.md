# Omarchy-inspired features

The current Omarchy **Quattro** branch and its manual were inspected. DMS stays
the only desktop shell. We reuse its features instead of porting Omarchy scripts.

| Omarchy behaviour | DMS equivalent / our implementation | Tier and laptop benefit | Difference |
| --- | --- | --- | --- |
| Clickable audio, network, Bluetooth, power/display panels | DMS control centre, battery, media, clock and clickable/scrollable indicators configured in one bar | Core: operate with the trackpad | DMS's native panels/conventions, no Omarchy Shell |
| AC/battery profile memory | DMS already supports separate profiles through the system power-profile API; exposed in its settings | Optional setting: balanced AC and power-saving battery choices | Off by default; respects Fedora tuned/tuned-ppd, no extra switching daemon |
| Clamshell handling | Small session-only Hyprland Lua module detects internal connectors and external outputs; restores panels it disabled | Optional: docked laptop recovery | User enables after lid testing; no logind edits/inhibition, no hardcoded connector names |
| Persistent toggles | DMS Night Light, Do Not Disturb, dark/light, bar settings, microphone and output controls | Core controls; optional user choices | Persistence belongs to DMS; no new toggle scripts |
| Stay Awake | DMS idle inhibitor with visible control-centre indicator and OSD | Core: presentations/downloads without hidden mode | Session toggle; not a global power-policy change; verify lid behaviour separately |
| Screenshots to clipboard/file | DMS region/window/display capture plus searchable launcher actions | Core: familiar Super+Shift+S and mouse discovery | DMS's region selector and Pictures/Screenshots path |
| Recording with audio | OBS Studio, using PipeWire capture and explicit audio-source selection | Optional `--with-recording`: maintained GUI | Requires first-use source/output setup; no automatic audio capture or custom recorder daemon |
| Screen OCR/QR | Thin helpers around DMS screenshot + Tesseract/zbar + wl-copy | Optional `--with-extras`: copy screen text/QR contents | English OCR initially; failed/cancelled captures leave clipboard intact |
| Text/image clipboard history | DMS native searchable history, Super+V and bar button | Core: familiar reuse | Click selects/copies, then Ctrl+V; no global copy/paste emulation |
| LocalSend Share menu | Installed native/Flatpak LocalSend is discoverable in DMS launcher | Optional existing app: transfer files | Use LocalSend's own selection UI; no mandatory install, firewall changes or file-manager extension |
| Theme coherence | DMS/Matugen + private GTK, Kitty, Hyprland and Dolphin palettes | Core: consistent session without changing Plasma | Qt/Flatpak/custom UIs have limits; editor/browser hooks are off to protect shared settings |
| Wallpaper/static theme picker | DMS Settings and its own theme catalogue | Core: graphical theme workflow | No separate rice/theme manager or copied Omarchy themes |
| Activity/system tools, emoji, calculator, notifications | Native DMS tools/history; optional btop | Core DMS; btop in extras | No always-running CPU graph/process poller added to the bar |
| Snapshots around updates | Optional pre-install snapshot with existing Snapper `root` configuration | Optional `--snapshot`: useful when already configured | No automated update snapshots, Limine integration, partition/boot changes or new snapshot framework |

Touchpad enable/disable is not given a prominent toggle by default: accidentally
turning off a laptop's only pointer is a poor first-use experience. Input settings
remain editable in the preserved user Lua file. The control centre offers the
useful everyday toggles without a large required shortcut vocabulary.

No Omarchy code is copied. The implementation is written against Fedora, DMS and
the released Hyprland API; see [upstream research](upstream.md) and the [manual](https://omarchy.org/manual/).
