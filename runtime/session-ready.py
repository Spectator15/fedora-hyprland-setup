#!/usr/bin/env python3
"""Tell the session supervisor which display/socket Hyprland actually created."""
import json
import os
import socket

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect(os.environ["FH_READY_SOCKET"])
    client.sendall(json.dumps({key: os.environ[key] for key in
                              ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE")}).encode())
