"""No display: check process ownership, readiness handoff and cleanup with mocks."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SessionTests(unittest.TestCase):
    def simulate(self, mode):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for name, code in {
                "Hyprland": '''import os,socket,json,time
from pathlib import Path
Path(os.environ["TEST_DIR"],"hypr-pid").write_text(str(os.getpid()))
if os.environ["TEST_MODE"] == "early": raise SystemExit(23)
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
    s.connect(os.environ["FH_READY_SOCKET"])
    s.sendall(json.dumps({"WAYLAND_DISPLAY":"test-only","HYPRLAND_INSTANCE_SIGNATURE":"test-only"}).encode())
time.sleep(2.5 if os.environ["TEST_MODE"] == "restart" else 15)
''',
                "dms": '''import os,time,sys
from pathlib import Path
assert sys.argv[1:] == ["run", "--session"]
log=Path(os.environ["TEST_DIR"],"starts")
count=int(log.read_text())+1 if log.exists() else 1
log.write_text(str(count))
if os.environ["TEST_MODE"] == "fail": raise SystemExit(12)
if count == 1: raise SystemExit(75)
time.sleep(15)
''',
            }.items():
                binary = home / name
                binary.write_text("#!/usr/bin/env python3\n" + code)
                binary.chmod(0o755)
            env = dict(os.environ, PATH=str(home) + ":" + os.environ["PATH"], XDG_RUNTIME_DIR=str(home),
                       XDG_CONFIG_HOME=str(home), TEST_MODE=mode, TEST_DIR=str(home))
            result = subprocess.run(["python3", str(ROOT / "runtime/session.py")], env=env,
                                    capture_output=True, text=True, timeout=10)
            with self.assertRaises(ProcessLookupError):
                os.kill(int((home / "hypr-pid").read_text()), 0)
            if mode == "restart":
                self.assertEqual((home / "starts").read_text(), "2")
                self.assertEqual(result.returncode, 0, result.stderr)
            else:
                self.assertNotEqual(result.returncode, 0)
            self.assertFalse(list(home.glob("fh-*")))

    def test_managed_dms_restart_keeps_compositor(self):
        self.simulate("restart")

    def test_dms_failure_ends_session_cleanly(self):
        self.simulate("fail")

    def test_compositor_failure_before_readiness(self):
        self.simulate("early")

    def test_handoff_and_children_cleaned_after_compositor_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / "hypr").mkdir()
            (home / "hypr/hyprland.lua").write_text("-- mock")
            compositor = home / "Hyprland"
            compositor.write_text('''#!/usr/bin/env python3
import os,socket,json,time
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
    s.connect(os.environ["FH_READY_SOCKET"])
    s.sendall(json.dumps({"WAYLAND_DISPLAY":"test-only","HYPRLAND_INSTANCE_SIGNATURE":"test-only"}).encode())
time.sleep(1)
''')
            shell = home / "dms"
            shell.write_text('''#!/usr/bin/env python3
import os,json,time
from pathlib import Path
Path(os.environ["TEST_LOG"]).write_text(json.dumps({"pid":os.getpid(),"wayland":os.environ["WAYLAND_DISPLAY"],"config":os.environ["XDG_CONFIG_HOME"]}))
time.sleep(15)
''')
            for file in (compositor, shell):
                file.chmod(0o755)
            env = dict(os.environ, PATH=str(home) + ":" + os.environ["PATH"],
                       XDG_RUNTIME_DIR=str(home), XDG_CONFIG_HOME=str(home), TEST_LOG=str(home / "log"))
            result = subprocess.run(["python3", str(ROOT / "runtime/session.py")], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            logged = json.loads((home / "log").read_text())
            self.assertEqual(logged["wayland"], "test-only")
            self.assertEqual(logged["config"], str(home))
            with self.assertRaises(ProcessLookupError):
                os.kill(logged["pid"], 0)
            self.assertFalse(list(home.glob("fh-*")))

    def test_capture_cancel_keeps_clipboard(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for name, body in {"dms": "exit 1", "tesseract": "exit 99", "wl-copy": 'touch "$TEST_MARKER"'}.items():
                file = home / name
                file.write_text("#!/bin/sh\n" + body + "\n")
                file.chmod(0o755)
            env = dict(os.environ, PATH=str(home) + ":" + os.environ["PATH"], FH_SESSION="1", TEST_MARKER=str(home / "changed"))
            result = subprocess.run(["bash", str(ROOT / "runtime/capture-extra.sh"), "ocr"], env=env, capture_output=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((home / "changed").exists())

    def test_missing_optional_tool_explains_extra(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(["/bin/bash", str(ROOT / "runtime/capture-extra.sh"), "ocr"],
                                    env=dict(os.environ, PATH=directory, FH_SESSION="1"),
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("--with-extras", result.stderr)

    def test_environment_guards_block_only_shared_updates(self):
        wrapper = ROOT / "runtime/env-guard/systemctl"
        for action in ("import-environment", "set-environment", "unset-environment"):
            result = subprocess.run(["bash", str(wrapper), "--user", action, "QT_QPA_PLATFORMTHEME"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn("Shared user environment update skipped", result.stderr)
        result = subprocess.run(["bash", str(wrapper), "--version"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("systemd", result.stdout)
        with tempfile.TemporaryDirectory() as directory:
            # Replace the absolute delegate only in a temporary test copy.
            copy = Path(directory) / "dbus-wrapper"
            code = (ROOT / "runtime/env-guard/dbus-update-activation-environment").read_text()
            code = code.replace('exec /usr/bin/dbus-update-activation-environment', 'printf "%s\\n"')
            copy.write_text(code)
            result = subprocess.run(["bash", str(copy), "--systemd", "WAYLAND_DISPLAY", "XDG_DATA_DIRS"],
                                    capture_output=True, text=True)
            self.assertEqual(result.stdout.splitlines(), ["WAYLAND_DISPLAY", "XDG_DATA_DIRS"])
