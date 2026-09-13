#!/usr/bin/env python3
"""File deployment journal. Paths are data; no manifest content is executed.

Only files under this project's dedicated data directory are managed. Original
bytes/mode/symlink targets are backed up before replacement. Edited files are
kept on rerun and uninstall. The manifest is written before each file mutation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
import uuid


def fingerprint(path):
    if path.is_symlink():
        return "link:" + os.readlink(path)
    if not path.exists():
        return None
    if not path.is_file():
        raise ValueError(f"Expected a file, found directory/special file: {path}")
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def atomic(path, content, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".fh-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class Journal:
    def __init__(self, project, state, dry=False):
        self.project = Path(project).absolute()
        self.state = Path(state).absolute()
        self.dry = dry
        self.manifest = self.state / "manifest.json"
        if self.project.is_symlink() or self.state.is_symlink() or self.manifest.is_symlink() or (self.state / "backups").is_symlink():
            raise ValueError("Project/state/manifest must not be symlinks")
        self.data = {"schema": 1, "files": {}}
        if self.manifest.exists():
            self.data = json.loads(self.manifest.read_text())
            if self.data.get("schema") != 1 or not isinstance(self.data.get("files"), dict):
                raise ValueError("Unknown/corrupt installation manifest")
        for rel, entry in self.data["files"].items():
            self.path(rel)
            if not isinstance(entry, dict) or not isinstance(entry.get("installed"), str):
                raise ValueError("Invalid manifest entry")
            if entry.get("backup") and (not isinstance(entry["backup"], str) or not entry["backup"].isalnum()):
                raise ValueError("Invalid backup identifier")

    def path(self, rel):
        key = Path(rel)
        if key.is_absolute() or ".." in key.parts or not key.parts:
            raise ValueError(f"Unsafe manifest path: {rel}")
        result = self.project / key
        for parent in (result.parent, *result.parent.parents):
            if parent == self.project.parent:
                break
            if parent.is_symlink():
                raise ValueError(f"Refusing a symlinked parent: {parent}")
        return result

    def save(self):
        if not self.dry:
            atomic(self.manifest, (json.dumps(self.data, indent=2, sort_keys=True) + "\n").encode())

    def put(self, rel, content=None, mode=0o644, target=None, seed=False):
        path = self.path(rel)
        current = fingerprint(path)
        intended = "link:" + target if target is not None else "sha256:" + hashlib.sha256(content).hexdigest()
        entry = self.data["files"].get(rel)
        if entry:
            if seed and current is not None:
                return
            if current == intended:
                return
            # A crash between journal and file replacement can leave the old file.
            if current not in (entry["installed"], entry.get("pending_from")):
                raise ValueError(f"Locally edited file retained: {path}. Move it aside or merge changes before rerunning.")
        elif seed and current is not None:
            # Existing project-owned preferences are never reset.
            return
        if self.dry:
            print(f"[dry-run] Would back up if present and deploy {path}")
            return
        if not entry:
            backup = None
            if current is not None:
                backup = uuid.uuid4().hex
                backup_path = self.state / "backups" / backup
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                if backup_path.exists() or backup_path.is_symlink():
                    raise ValueError(f"Unclaimed backup exists: {backup_path}; inspect before continuing")
                if path.is_symlink():
                    backup_path.symlink_to(os.readlink(path))
                else:
                    shutil.copy2(path, backup_path)
                print(f"[backup] {path} -> {backup_path}")
            entry = {"backup": backup, "original": current}
            self.data["files"][rel] = entry
        entry.update(installed=intended, pending_from=current)
        self.save()
        path.parent.mkdir(parents=True, exist_ok=True)
        if target is not None:
            if path.exists() or path.is_symlink():
                path.unlink()
            path.symlink_to(target)
        else:
            atomic(path, content, mode)
        entry.pop("pending_from", None)
        self.save()
        print(f"[deploy] {path}")

    def uninstall(self):
        # Validate every restoration before touching any file.
        for entry in self.data["files"].values():
            if entry.get("backup") and fingerprint(self.state / "backups" / entry["backup"]) != entry["original"]:
                raise ValueError("Missing/modified backup; refusing partial restoration")
        retained = []
        for rel, entry in list(self.data["files"].items())[::-1]:
            path = self.path(rel)
            current = fingerprint(path)
            if entry.get("restoring") and current == entry["original"]:
                print(f"[restored] {path}")
                if not self.dry:
                    del self.data["files"][rel]
                    self.save()
                continue
            if current not in (None, entry["installed"], entry.get("pending_from")):
                print(f"[keep] Edited file: {path}")
                retained.append(rel)
                continue
            backup = self.state / "backups" / entry["backup"] if entry.get("backup") else None
            if backup and fingerprint(backup) != entry["original"]:
                raise ValueError(f"Missing/modified backup for {path}; refusing restoration")
            print(f"[{'dry-run' if self.dry else 'restore'}] {path}")
            if self.dry:
                continue
            entry["restoring"] = True
            self.save()
            if path.exists() or path.is_symlink():
                path.unlink()
            if backup:
                path.parent.mkdir(parents=True, exist_ok=True)
                if backup.is_symlink():
                    path.symlink_to(os.readlink(backup))
                else:
                    atomic(path, backup.read_bytes(), stat.S_IMODE(backup.stat().st_mode))
            del self.data["files"][rel]
            self.save()
            parent = path.parent
            while parent != self.project.parent:
                try:
                    parent.rmdir()
                except OSError:
                    break
                parent = parent.parent
        return retained


PROTECTED_CONFIG = {
    "hypr", "DankMaterialShell", "matugen", "gtk-3.0", "gtk-4.0", "qt5ct", "qt6ct",
    "qtengine", "kitty", "dconf", "kdeglobals", "dolphinrc", "konsolerc", "environment.d",
    "systemd", "autostart", "xdg-desktop-portal", "session.d", "fedora-hyprland-setup",
}
PROTECTED_DATA = {"themes", "color-schemes", "applications", "fedora-hyprland-setup"}


def link_existing(journal, original_config, original_data):
    # Share existing application preferences/data, but never desktop/theme files.
    # No files behind these links are written by this project.
    for source, prefix, excluded in ((original_config, "profile/config", PROTECTED_CONFIG),
                                     (original_data, "profile/data", PROTECTED_DATA)):
        if not source.is_dir():
            continue
        for child in source.iterdir():
            if child.name in excluded or child.name.startswith("."):
                continue
            path = journal.path(f"{prefix}/{child.name}")
            if path.exists() or path.is_symlink():
                continue
            journal.put(f"{prefix}/{child.name}", target=str(child), seed=True)


def render(root, stage, journal, extras=False):
    # All runtime code is copied; moving/deleting the checkout won't break login.
    for source in sorted((root / "config").rglob("*")):
        if source.is_file():
            relative = source.relative_to(root / "config").as_posix()
            seed = relative.endswith(("user.lua", "settings.json", "session.json"))
            journal.put("profile/config/" + relative, source.read_bytes(), seed=seed)
    for source in sorted((root / "runtime").rglob("*")):
        if source.is_file():
            journal.put("bin/" + source.relative_to(root / "runtime").as_posix(), source.read_bytes(), mode=0o755)
    journal.put("bin/deploy.py", (root / "lib/deploy.py").read_bytes(), mode=0o755)
    # Persist original XDG roots: SDDM need not inherit terminal-specific exports.
    paths = {key: os.environ[key] for key in ("CONFIG_BASE", "DATA_BASE", "STATE_DIR")}
    journal.put("paths.json", (json.dumps(paths) + "\n").encode(), mode=0o600)
    if stage:
        for source in sorted((stage / ".config/hypr/dms").glob("*.lua")):
            journal.put("profile/config/hypr/dms/" + source.name, source.read_bytes(), seed=True)
    # DMS may regenerate dms/*; the integration point for our overrides remains
    # binds-user.lua, and all project settings live outside generated files.
    journal.put("profile/config/hypr/dms/binds-user.lua", b'require("fedora.user")\n', seed=True)
    # KDE's file manager needs its own supported color scheme selection with
    # GTK platform passthrough. Copy preferences first, never edit the original.
    import configparser
    dolphin = configparser.RawConfigParser(strict=False)
    dolphin.optionxform = str
    dolphin.read(Path(os.environ["CONFIG_BASE"]) / "dolphinrc")
    if not dolphin.has_section("UiSettings"):
        dolphin.add_section("UiSettings")
    dolphin.set("UiSettings", "ColorScheme", "DankMatugen")
    import io
    output = io.StringIO()
    dolphin.write(output, space_around_delimiters=False)
    journal.put("profile/config/dolphinrc", output.getvalue().encode(), seed=True)
    journal.put("profile/config/dconf-profile", b"user-db:fedora-hyprland\n", seed=True)
    original_dconf = Path(os.environ["CONFIG_BASE"]) / "dconf/user"
    if original_dconf.is_file():
        journal.put("profile/config/dconf/fedora-hyprland", original_dconf.read_bytes(), mode=0o600, seed=True)
    # Include is relative to this private Kitty config directory.
    kitty = "font_family Noto Sans Mono\nfont_size 11\nbackground_opacity 1\ninclude dank-theme.conf\n"
    journal.put("profile/config/kitty/kitty.conf", kitty.encode(), seed=True)
    commands = {
        "fh-screenshot": ("Screenshot region", "screenshot", "camera-photo"),
        "fh-screenshot-window": ("Screenshot window", "screenshot window", "camera-photo"),
        "fh-screenshot-display": ("Screenshot display", "screenshot full", "camera-photo"),
        "fh-colour-picker": ("Pick a screen colour", "color pick", "color-picker"),
        "fh-shortcuts": ("Keyboard shortcuts", "ipc call keybinds toggle hyprland", "input-keyboard"),
    }
    for name, (label, command, icon) in commands.items():
        entry = f"[Desktop Entry]\nType=Application\nName={label}\nExec=dms {command}\nIcon={icon}\nCategories=Utility;\n"
        # applications is a private directory, never a link to real app entries.
        journal.put(f"profile/data/applications/{name}.desktop", entry.encode())
    if extras:
        executable = desktop_escape(str(journal.project / "bin/capture-extra.sh"))
        for mode in ("ocr", "qr"):
            entry = f'[Desktop Entry]\nType=Application\nName=Screen {mode.upper()}\nExec="{executable}" {mode}\nIcon=edit-find\nCategories=Utility;\n'
            journal.put(f"profile/data/applications/fh-{mode}.desktop", entry.encode())


def desktop_escape(value):
    # Exec has two escaping layers: argument quoting, then desktop string syntax.
    # https://specifications.freedesktop.org/desktop-entry/latest/exec-variables.html
    # GIO checks the executable before expanding %%: refuse that ambiguous path.
    if any(character in value for character in ("=", "%", "\n", "\r")):
        raise ValueError("Desktop executable paths cannot contain '=', '%', CR or LF")
    for character in ("\\", '"', "`", "$"):
        value = value.replace(character, "\\" + character)
    return value.replace("\\", "\\\\")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["plan", "install", "uninstall", "links"])
    parser.add_argument("--root", type=Path)
    parser.add_argument("--stage", type=Path)
    parser.add_argument("--extras", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    project = Path(os.environ["PROJECT_HOME"])
    state = Path(os.environ["STATE_DIR"])
    journal = Journal(project, state, args.dry_run or args.action == "plan")
    if args.action == "uninstall":
        kept = journal.uninstall()
        if kept:
            print("Edited/generated settings were retained. Backups and the remaining manifest are kept for manual recovery.")
        return
    if args.action == "links":
        link_existing(journal, Path(os.environ["CONFIG_BASE"]), Path(os.environ["DATA_BASE"]))
        return
    render(args.root, args.stage, journal, args.extras)
    # applications must be private, while installed user launchers stay visible
    # through XDG_DATA_DIRS; do not symlink this particular data directory.
    link_existing(journal, Path(os.environ["CONFIG_BASE"]), Path(os.environ["DATA_BASE"]))
    executable = str(project / "bin/session.sh")
    escaped = desktop_escape(executable)
    entry = f'[Desktop Entry]\nName=Hyprland (Fedora DMS)\nComment=Optional laptop session; Plasma remains available\nExec="{escaped}"\nType=Application\nDesktopNames=Hyprland;\n'
    if not journal.dry:
        atomic(state / f"fedora-hyprland-dms-{os.getuid()}.desktop", entry.encode(), 0o644)
    else:
        print("[dry-run] Would add one SDDM session entry. Existing Plasma/Hyprland/DMS configurations are not replaced.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        raise SystemExit(f"[error] {error}") from error
