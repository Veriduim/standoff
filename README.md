# Standoff

A simultaneous-turn stick-figure fighter for phones, for 2 to 6 players. The match runs at 60 ticks a second until
someone is free to act. Then everyone picks a move in secret, previewed with a ghost of what it will do. The picks play
out together, and the match runs on to the next stop. It has free-for-all and teams, bots in empty seats, and online
lobbies.

It is an original game; Your Only Move Is HUSTLE was studied as a reference only.

**Play:** the Android APK is on the [releases page](https://github.com/Veriduim/standoff/releases); on an iPhone or a PC,
play in the browser at https://veriduim.github.io/standoff/ (on an iPhone, Share, then Add to Home Screen, for full
screen).

- **Engine:** Godot 4.7, landscape 1280x720, Android and the web.
- **Code:**
  - `scripts/sim/`: the deterministic match.
  - `scripts/ui/`: the screens.
  - `scripts/net/`: lobbies and online matches.
  - `relay/`: the Cloudflare lobby server.
- **Docs:**
  - `docs/plan.md`: the plan and the calls made so far.
  - `docs/mechanics.md`: the fighting systems.
  - `docs/lobby.md`: online play.
- **Tests:** `bash tools/test.sh [sim|ui|online]`, run headless.
- **Android:** `godot --headless --path . --export-debug "Android" build/Standoff-<version>.apk`.
- **Web:** `bash tools/release_web.sh` builds it and puts it on GitHub Pages (`--build` to only build). The icons the
  game's text uses come in its own small fonts (`assets/fonts`, made by `tools/icon_fonts.py`), since a browser has no
  system fonts to borrow. `node tools/web_check.mjs` plays it in a hidden Chrome posing as a phone (screenshots, console).
