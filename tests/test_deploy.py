"""Exercise real journal/deployment code against isolated temporary homes."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("deploy", ROOT / "lib/deploy.py")
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project, self.state = self.base / "project", self.base / "state"
        self.config, self.data = self.base / "original-config", self.base / "original-data"
        self.config.mkdir()
        self.data.mkdir()
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, HOME=str(self.base), CONFIG_BASE=str(self.config), DATA_BASE=str(self.data),
                   STATE_DIR=str(self.state), PROJECT_HOME=str(self.project)).start()
        self.journal = deploy.Journal(self.project, self.state)
        self.output = io.StringIO()
        self.quiet = contextlib.redirect_stdout(self.output)
        self.quiet.__enter__()
        self.addCleanup(self.quiet.__exit__, None, None, None)

    def test_desktop_exec_escaping(self):
        self.assertEqual(deploy.desktop_escape('/space name'), '/space name')
        self.assertEqual(deploy.desktop_escape('a\\b'), 'a' + '\\' * 4 + 'b')
        for character in ('"', '`', '$'):
            self.assertEqual(deploy.desktop_escape(character), '\\' * 2 + character)
        for path in ('/a=b', '/100%', '/a\nb', '/a\rb'):
            with self.assertRaises(ValueError):
                deploy.desktop_escape(path)

    def test_rerun_leaves_identical_files_and_manifest_unchanged(self):
        self.journal.put("config/a", b"hello")
        before = (self.state / "manifest.json").stat().st_mtime_ns
        self.journal.put("config/a", b"hello")
        self.assertEqual(before, (self.state / "manifest.json").stat().st_mtime_ns)

    def test_backup_restores_original_bytes_and_mode_reinstall_works(self):
        self.project.mkdir()
        target = self.project / "a"
        target.write_bytes(b"original")
        target.chmod(0o640)
        for _ in range(2):
            journal = deploy.Journal(self.project, self.state)
            journal.put("a", b"installed")
            journal.uninstall()
            self.assertEqual(target.read_bytes(), b"original")
            self.assertEqual(target.stat().st_mode & 0o777, 0o640)
        self.assertEqual(len(list((self.state / "backups").iterdir())), 2)

    def test_original_symlink_restored_without_writing_target(self):
        self.project.mkdir()
        other = self.base / "untouched"
        other.write_text("private")
        (self.project / "a").symlink_to(other)
        self.journal.put("a", b"new")
        self.journal.uninstall()
        self.assertTrue((self.project / "a").is_symlink())
        self.assertEqual(other.read_text(), "private")

    def test_edits_retained_on_update_and_uninstall(self):
        self.journal.put("a", b"installed")
        (self.project / "a").write_bytes(b"my edits")
        with self.assertRaisesRegex(ValueError, "Locally edited"):
            self.journal.put("a", b"updated")
        self.assertEqual(self.journal.uninstall(), ["a"])
        self.assertEqual((self.project / "a").read_bytes(), b"my edits")

    def test_seed_preserved_on_rerun(self):
        self.journal.put("user.lua", b"first", seed=True)
        (self.project / "user.lua").write_bytes(b"user preferences")
        self.journal.put("user.lua", b"new defaults", seed=True)
        self.assertEqual((self.project / "user.lua").read_bytes(), b"user preferences")

    def test_unrelated_and_generated_files_survive(self):
        self.journal.put("managed", b"yes")
        (self.project / "unrelated").write_text("keep")
        self.journal.uninstall()
        self.assertEqual((self.project / "unrelated").read_text(), "keep")

    def test_crash_between_journal_and_write_can_resume(self):
        original_atomic = deploy.atomic
        def fail_target(path, content, mode=0o600):
            if path == self.project / "a":
                raise OSError("simulated power loss")
            original_atomic(path, content, mode)
        with patch.object(deploy, "atomic", side_effect=fail_target):
            with self.assertRaises(OSError):
                self.journal.put("a", b"new")
        resumed = deploy.Journal(self.project, self.state)
        resumed.put("a", b"new")
        self.assertEqual((self.project / "a").read_bytes(), b"new")
        self.assertNotIn("pending_from", resumed.data["files"]["a"])

    def test_backup_tampering_blocks_all_restorations(self):
        self.project.mkdir()
        (self.project / "a").write_bytes(b"original")
        self.journal.put("a", b"new")
        self.journal.put("b", b"new")
        backup = self.state / "backups" / self.journal.data["files"]["a"]["backup"]
        backup.write_bytes(b"bad")
        with self.assertRaisesRegex(ValueError, "backup"):
            self.journal.uninstall()
        self.assertTrue((self.project / "b").exists())

    def test_interrupted_uninstall_can_resume_after_restore(self):
        self.project.mkdir()
        (self.project / "a").write_bytes(b"original")
        self.journal.put("a", b"new")
        save = self.journal.save
        def fail_final_save():
            if not self.journal.data["files"]:
                raise OSError("power loss after restoration")
            save()
        with patch.object(self.journal, "save", side_effect=fail_final_save):
            with self.assertRaises(OSError):
                self.journal.uninstall()
        resumed = deploy.Journal(self.project, self.state)
        self.assertEqual(resumed.uninstall(), [])
        self.assertEqual((self.project / "a").read_bytes(), b"original")
        self.assertEqual(resumed.data["files"], {})

    def test_unsafe_paths_and_symlink_parents_rejected(self):
        for rel in ("../outside", "/etc/environment", "a/../../bad", ""):
            with self.assertRaises(ValueError):
                self.journal.put(rel, b"bad")
        self.project.mkdir()
        (self.project / "escape").symlink_to(self.config)
        with self.assertRaises(ValueError):
            self.journal.put("escape/a", b"bad")
        self.assertEqual(list(self.config.iterdir()), [])

    def test_corrupt_manifest_rejected(self):
        self.state.mkdir()
        for data in ({"schema": 8, "files": {}}, {"schema": 1, "files": {"../escape": {}}},
                     {"schema": 1, "files": {"a": {"installed": "x", "backup": "../bad"}}}):
            (self.state / "manifest.json").write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                deploy.Journal(self.project, self.state)

    def test_dry_run_render_and_uninstall_do_not_mutate(self):
        dry = deploy.Journal(self.project, self.state, dry=True)
        deploy.render(ROOT, None, dry, extras=True)
        dry.uninstall()
        self.assertFalse(self.project.exists())
        self.assertFalse(self.state.exists())

    def test_generation_isolation_and_preferences_survive(self):
        (self.config / "kdeglobals").write_text("Plasma colours")
        (self.config / "BraveSoftware").mkdir()
        (self.config / "BraveSoftware/Profile").write_text("browser data")
        stage = self.base / "stage/.config/hypr/dms"
        stage.mkdir(parents=True)
        for name in ("colors", "outputs", "layout", "cursor", "windowrules"):
            (stage / (name + ".lua")).write_text("-- generated by DMS\n")
        deploy.render(ROOT, self.base / "stage", self.journal, extras=True)
        deploy.link_existing(self.journal, self.config, self.data)
        profile = self.project / "profile/config"
        self.assertFalse((profile / "kdeglobals").is_symlink())
        self.assertTrue((profile / "BraveSoftware").is_symlink())
        self.assertIn('require("fedora.user")', (profile / "hypr/dms/binds-user.lua").read_text())
        settings = profile / "DankMaterialShell/settings.json"
        settings.write_text('{"user": true}')
        deploy.render(ROOT, self.base / "stage", self.journal, extras=True)
        self.assertEqual(json.loads(settings.read_text()), {"user": True})
        self.journal.uninstall()
        self.assertEqual((self.config / "kdeglobals").read_text(), "Plasma colours")
        self.assertEqual((self.config / "BraveSoftware/Profile").read_text(), "browser data")

    def test_entrypoint_dry_run_never_invokes_sudo_dnf_or_dms(self):
        # Override only OS admission; exercise the actual dry-run entrypoint.
        script = 'source "$1/install.sh"; validate_fedora() { :; }; sudo() { exit 97; }; dnf() { exit 98; }; dms() { exit 99; }; main --dry-run --with-extras --with-recording --snapshot'
        env = dict(os.environ, HOME=str(self.base), XDG_CONFIG_HOME=str(self.config),
                   XDG_DATA_HOME=str(self.data), XDG_STATE_HOME=str(self.base / "state-base"))
        result = subprocess.run(["bash", "-c", script, "test", str(ROOT)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[dry-run]", result.stdout)
        self.assertIn("fh-ocr.desktop", result.stdout)
        self.assertFalse((self.data / "fedora-hyprland-setup").exists())
        self.assertFalse((self.base / "state-base").exists())

    def test_dms_mixed_legacy_config_blocked_without_migration(self):
        legacy = self.base / ".config/hypr"
        legacy.mkdir(parents=True)
        (legacy / "hyprland.lua").write_text("-- current")
        (legacy / "hyprland.conf").write_text("# legacy")
        result = subprocess.run(["python3", str(ROOT / "runtime/preflight.py")],
                                env=dict(os.environ, HOME=str(self.base)), capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((legacy / "hyprland.conf").read_text(), "# legacy")

    def test_verifier_detects_hdr_and_global_theme_pollution(self):
        stage = self.base / "stage/.config/hypr/dms"
        stage.mkdir(parents=True)
        for name in ("colors", "outputs", "layout", "cursor", "windowrules"):
            (stage / (name + ".lua")).write_text("-- DMS")
        deploy.render(ROOT, self.base / "stage", self.journal)
        command = ["python3", str(ROOT / "lib/verify.py")]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        appearance = self.project / "profile/config/hypr/fedora/appearance.lua"
        original = appearance.read_text()
        appearance.write_text(original.replace("cm_auto_hdr = 0", "cm_auto_hdr = 1"))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HDR", result.stderr)
        appearance.write_text(original)
        (self.base / ".profile").write_text('export QT_QPA_PLATFORMTHEME=gtk3 # fedora-hyprland-setup\n')
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shared startup", result.stderr)

    def test_installer_dms_and_parser_failure_then_partial_uninstall(self):
        binaries = self.base / "bin"
        binaries.mkdir()
        dms = binaries / "dms"
        dms.write_text('''#!/bin/bash
if [[ $* == *--help* ]]; then echo --no-systemd; exit 0; fi
if [[ ${TEST_DMS_FAIL:-} == 1 ]]; then echo 'simulated DMS failure' >&2; exit 41; fi
mkdir -p "$HOME/.config/hypr/dms"
for name in colors outputs layout cursor windowrules; do echo '-- fixture' > "$HOME/.config/hypr/dms/$name.lua"; done
''')
        hypr = binaries / "Hyprland"
        hypr.write_text('#!/bin/bash\necho "simulated parser failure" >&2\nexit 33\n')
        sudo = binaries / "sudo"
        sudo.write_text('#!/bin/bash\necho "unexpected sudo" >&2\nexit 99\n')
        for file in (dms, hypr, sudo):
            file.chmod(0o755)
        env = dict(os.environ, PATH=str(binaries) + ":" + os.environ["PATH"],
                   XDG_CONFIG_HOME=str(self.config), XDG_DATA_HOME=str(self.data),
                   XDG_STATE_HOME=str(self.base / "state-base"))
        script = 'source "$1/install.sh"; validate_fedora() { :; }; install_packages() { :; }; main'
        command = ["bash", "-c", script, "test", str(ROOT)]
        result = subprocess.run(command, env=dict(env, TEST_DMS_FAIL="1"), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("simulated DMS failure", result.stderr)
        project = self.data / "fedora-hyprland-setup"
        state = self.base / "state-base/fedora-hyprland-setup"
        self.assertFalse(project.exists())
        self.assertFalse(list(state.glob("stage.*")))
        # Retry after DMS failure, reaching the deliberately failing native parser.
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parser rejected", result.stderr)
        self.assertTrue((state / "manifest.json").exists())
        self.assertNotIn("unexpected sudo", result.stderr)
        self.assertFalse(list(state.glob("stage.*")))
        # Rollback of this partial deployment invokes the real journal CLI.
        rollback_env = dict(env, PROJECT_HOME=str(project), STATE_DIR=str(state))
        result = subprocess.run(["python3", str(ROOT / "lib/deploy.py"), "uninstall"],
                                env=rollback_env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((state / "manifest.json").read_text())["files"], {})


if __name__ == "__main__":
    unittest.main()
