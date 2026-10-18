#!/usr/bin/env bash
# The headless tests. Exit 0 = every check passed.   tools/test.sh [area ...]   (areas: scripts/tests/<area>_test.gd)
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/c/Users/ajisa/Documents/LocalTools/Godot_v4.7.2-stable_win64_console.exe}"
# new class_name scripts are unknown until the project is imported (an unknown class hangs the run)
STAMP=.godot/standoff_import_stamp
if [ ! -f "$STAMP" ] || [ -n "$(find scripts -newer "$STAMP" -name '*.gd' -exec grep -l '^class_name' {} + 2>/dev/null | head -1)" ]; then
  timeout 90 "$GODOT" --headless --path . --import >/dev/null 2>&1; touch "$STAMP"
fi
AREAS=""
[ $# -gt 0 ] && AREAS="--test-areas=$(IFS=,; echo "$*")"
OUT="$(timeout "${TEST_TIMEOUT:-240}" "$GODOT" --headless --path . -- --test $AREAS 2>&1)"
STATUS=$?
grep -vE "^Godot Engine|^$|OpenGL|Vulkan" <<<"$OUT"
if grep -q "SCRIPT ERROR" <<<"$OUT"; then echo "FAILED: script error during the run (see above)"; exit 1; fi
exit "$STATUS"
