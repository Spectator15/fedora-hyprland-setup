"""Round-trip a harmless launcher through Fedora's actual GIO desktop parser."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("deploy", ROOT / "lib/deploy.py")
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    executable = base / 'space dollar$ back` quote" slash\\ apostrophe\''
    executable.write_text('#!/bin/sh\nprintf success > "$FH_LAUNCH_MARKER"\n')
    executable.chmod(0o755)
    marker = base / "result"
    entry = base / "test.desktop"
    entry.write_text('[Desktop Entry]\nType=Application\nName=Launch test\nExec="' +
                     deploy.desktop_escape(str(executable)) + '"\n')
    result = subprocess.run(["gio", "launch", str(entry)], capture_output=True, text=True,
                            env=dict(os.environ, FH_LAUNCH_MARKER=str(marker)), timeout=10)
    assert result.returncode == 0, result.stderr
    deadline = time.monotonic() + 5
    while not marker.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert marker.read_text() == "success", "Desktop executable path was not preserved"
print("PASS: native desktop launcher escaping, including spaces and reserved characters")
