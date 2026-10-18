#!/usr/bin/env bash
# Screenshots of a match in progress (scripts/dev/shots.gd), rendered off-screen.   tools/shots.sh [out dir] [WxH]
# Renders on the GPU - not while a game is running on it.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/c/Users/ajisa/Documents/LocalTools/Godot_v4.7.2-stable_win64_console.exe}"
OUT="${1:-$(pwd)/.shots}"
busy=$(nvidia-smi --query-compute-apps=process_name --format=csv,noheader 2>/dev/null | tr -d '\r' | sed 's|.*[\/]||' \
  | grep -vixE "python.exe|firefox.exe|chrome.exe|msedge.exe|discord.exe|steamwebhelper.exe|steam.exe|explorer.exe|dwm.exe|claude.exe|code.exe|LogonUI.exe" | head -1)
if [ -n "$busy" ]; then echo "GPU IN USE by $busy - not rendering"; exit 3; fi
timeout 120 "$GODOT" --path . --position 9000,9000 --resolution "${2:-1280x720}" -- --shots="$OUT" 2>&1 \
  | grep -E "shot|ERROR" | head -20
