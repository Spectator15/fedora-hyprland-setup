"""Confirm DMS's real parser can discover the included user keybindings."""
import json
from pathlib import Path
import sys

sheet = json.loads(Path(sys.argv[1]).read_text())
text = json.dumps(sheet).lower()
for description in ("file manager", "clipboard history", "keyboard shortcuts", "workspace 9"):
    if description not in text:
        raise SystemExit("DMS cheatsheet missed: " + description)
print("PASS: DMS native keybind parser discovers included project shortcuts")
