#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
command -v shellcheck >/dev/null || { echo 'Install ShellCheck to run validation.' >&2; exit 1; }
lua_bin=${LUA_BIN:-lua}
luac_bin=${LUAC_BIN:-luac}
command -v "$lua_bin" >/dev/null
command -v "$luac_bin" >/dev/null
mapfile -t scripts < <(find install.sh uninstall.sh lib runtime scripts tests -name '*.sh' -type f | sort)
scripts+=(runtime/env-guard/systemctl runtime/env-guard/dbus-update-activation-environment)
for script in "${scripts[@]}"; do bash -n "$script"; done
shellcheck -x "${scripts[@]}"
while IFS= read -r file; do "$luac_bin" -p "$file"; done < <(find config tests -name '*.lua' -type f)
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/shell-tests.sh
"$lua_bin" tests/lua-tests.lua
printf 'PASS: Bash syntax, ShellCheck, Lua syntax, and all automated tests\n'
