#!/usr/bin/env python3
"""Own the compositor process group; teardown also covers DMS child processes."""
import os
from pathlib import Path
import signal
import socket
import json
import subprocess
import tempfile
import time


def main():
    config = Path(os.environ["XDG_CONFIG_HOME"]) / "hypr/hyprland.lua"
    children = []
    def terminate(child, sig):
        try:
            os.killpg(child.pid, sig)
        except ProcessLookupError:
            pass
    def stop(_signal, _frame):
        for child in children:
            terminate(child, signal.SIGTERM)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with tempfile.TemporaryDirectory(prefix="fh-", dir=os.environ["XDG_RUNTIME_DIR"]) as directory:
        os.environ["FH_READY_SOCKET"] = directory + "/ready"
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(os.environ["FH_READY_SOCKET"])
            server.listen(1)
            server.settimeout(1)
            compositor = subprocess.Popen(["Hyprland", "--config", str(config)], start_new_session=True)
            children.append(compositor)
            try:
                deadline = time.monotonic() + 30
                while compositor.poll() is None and time.monotonic() < deadline:
                    try:
                        connection, _ = server.accept()
                    except TimeoutError:
                        continue
                    with connection:
                        connection.settimeout(3)
                        values = json.loads(connection.recv(4096))
                    env = dict(os.environ)
                    for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
                        env[key] = str(values[key])
                    children.append(subprocess.Popen(["dms", "run", "--session"], env=env, start_new_session=True))
                    break
                if len(children) != 2:
                    print("Hyprland did not report ready; check its configuration and session log.", flush=True)
                    return 1
                while compositor.poll() is None:
                    if children[1].poll() is not None:
                        if children[1].returncode == 75:  # DMS 1.6's managed restart request
                            terminate(children[1], signal.SIGTERM)
                            time.sleep(0.3)
                            terminate(children[1], signal.SIGKILL)
                            children[1] = subprocess.Popen(["dms", "run", "--session"], env=env, start_new_session=True)
                            continue
                        print("DMS exited; ending the session so SDDM can offer Plasma again.", flush=True)
                        return 1
                    time.sleep(0.5)
                return compositor.returncode
            finally:
                stop(None, None)
                time.sleep(0.3)
                for child in children:
                    terminate(child, signal.SIGKILL)
                    child.wait()


if __name__ == "__main__":
    raise SystemExit(main())
