# Standoff

A simultaneous-turn stick-figure fighter for phones, for 2 to 6 players. The match runs at 60 ticks a second until
someone is free to act. Then everyone picks a move in secret, previewed with a ghost of what it will do. The picks play
out together, and the match runs on to the next stop. It has free-for-all and teams, bots in empty seats, and online
lobbies.

It is an original game; Your Only Move Is HUSTLE was studied as a reference only.

**Play:** the newest Android APK is always at
https://github.com/Veriduim/standoff/releases/latest/download/Standoff.apk (every version is on the
[releases page](https://github.com/Veriduim/standoff/releases)). Install it on the phone; it updates the one there.

- **Engine:** Godot 4.7, landscape 1280x720, Android.
- **Code:**
  - `scripts/sim/`: the deterministic match.
  - `scripts/ui/`: the screens.
  - `scripts/net/`: lobbies and online matches.
  - `relay/`: the Cloudflare lobby server.
- **Docs:**
  - `docs/plan.md`: the plan and every call made so far, with Timmy's words.
  - `docs/mechanics.md`: the fighting systems - YOMI's rules, frame data, clashes, launch pace, the camera's scale.
  - `docs/dancer.md`, `docs/bruiser.md`: the two fighters - their moves, looks, strengths and limits.
  - `docs/xfactors.md`: the x-factors (Fans, Tempo, Forms...).
  - `docs/yomi_chars.md`, `docs/dancer_research.md`: the YOMI study (reference only).
  - `docs/lobby.md`: online play.
- **Tests:** `bash tools/test.sh [sim|ui|online]`, run headless.
- **Android:** `godot --headless --path . --export-debug "Android" build/Standoff-<version>.apk`.
- **Icons:** the ones the game's text uses come in its own small fonts (`assets/fonts`, made by `tools/icon_fonts.py`),
  so every phone shows the same.
