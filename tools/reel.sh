#!/usr/bin/env bash
# A video of bots playing a match at normal speed (the effects moving), rendered off-screen.
#   [OPP=n] tools/reel.sh <out.mp4> [seconds]   (OPP: bots against you, default 3)
# Renders on the GPU - not while a game is running on it. Silent unless SOUND=1 (the game's sounds, AAC).
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/c/Users/ajisa/Documents/LocalTools/Godot_v4.7.2-stable_win64_console.exe}"
FFMPEG="${FFMPEG:-/c/Users/ajisa/AppData/Local/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Lib/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe}"
OUT="${1:?usage: tools/reel.sh <out.mp4> [seconds]}"
SECS="${2:-25}"
busy=$(nvidia-smi --query-compute-apps=process_name --format=csv,noheader 2>/dev/null | tr -d '\r' | sed 's|.*[\/]||' \
  | grep -vixE "python.exe|firefox.exe|chrome.exe|msedge.exe|discord.exe|steamwebhelper.exe|steam.exe|explorer.exe|dwm.exe|claude.exe|code.exe|LogonUI.exe" | head -1)
if [ -n "$busy" ]; then echo "GPU IN USE by $busy - not rendering"; exit 3; fi
TMP="$(mktemp -d)"
timeout $((SECS * 3 + 60)) "$GODOT" --path . --position 9000,9000 --resolution 1280x720 --write-movie "$TMP/reel.avi" \
  -- --reel="$SECS" ${OPP:+--opp=$OPP} 2>&1 | grep -E "Done recording|ERROR" | grep -v "BUG\|leaked\|Pages" | head -5
"$FFMPEG" -v error -y -i "$TMP/reel.avi" $([ -n "$SOUND" ] && echo "-c:a aac -b:a 160k" || echo "-an") -c:v libx264 -pix_fmt yuv420p -crf 22 -preset veryfast "$OUT" && echo "reel $OUT"
rm -rf "$TMP"
