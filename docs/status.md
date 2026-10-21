# Where Standoff stands - parked 21 Oct 2026

Timmy, 21 Oct 09:59: "No issues at all. But just document everything on this and park it for now as we swtich back to
Life after Dark". The online fixes (0.46.0 / 0.46.1) were tested with a friend on real phones: no issues.

**Latest:** 0.46.1 (versionCode 78), released.
- Download, always the newest: https://github.com/Veriduim/standoff/releases/latest/download/Standoff.apk
- Repo (public): github.com/Veriduim/standoff. Every APK is a GitHub release.
- The lobby server (`relay/`) is deployed on his Cloudflare account. `docs/lobby.md` says how to deploy it.

## What's in it
- **The game:** YOMI Hustle's simultaneous-turn fighting on phones, 2-6 players, free-for-all or teams.
  - YOMI's frame data and clash rules, its scale and launch pace (`docs/mechanics.md`).
  - Effects stay in the area a move reaches. There are no words or damage numbers on the stage.
- **Two fighters:**
  - **The Dancer:** a melee spacer whose strikes are dance moves (`docs/dancer.md`).
  - **The Bruiser:** rushdown Muay Thai, with full-body strikes since 0.45.0 (`docs/bruiser.md`).
- **Play:**
  - against bots, and Training against a dummy;
  - Replays, saved and shared by code;
  - online lobbies (YOMI's Steam lobby as the model) and Nearby play (same Wi-Fi or a hotspot) (`docs/lobby.md`).
- **Online survives a phone put aside** (0.46.0 / 0.46.1, `docs/lobby.md` "Kept places"):
  - phones ping the server every 15 s, and a dropped player's place is kept 10 min;
  - if the host's phone goes away, the match moves to another player's phone;
  - "Back in" after Android closes the app.
- **UI:**
  - move cards read icon, text, distance, arrows, Confirm;
  - tags are coloured words, YOMI-style;
  - the ☰ menu has Resume, Restart (offline only), Sound, Hit boxes and Quit;
  - How to play is on the home screen.

## Picking it up again
1. Read this, then `docs/plan.md` "His calls so far" (every call, with his words) and the doc for the area.
2. The tests:
   - `bash tools/test.sh` runs everything (62 tests); `bash tools/test.sh sim|ui|online` runs one part.
   - Godot sometimes crashes (signal 11) in the online tests before the summary prints. That's known: rerun.
   - `relay/test.mjs` checks the server, against `npx wrangler dev` or the live URL.
   - `godot --headless --path . -- --awaycheck` runs two phones on real sockets with drops.
   - `-- --livecheck` runs a three-phone match on the live server.
3. A release:
   - bump `scripts/version.gd`, `project.godot` and `export_presets.cfg` (name and code);
   - run the tests and commit;
   - build: `--export-debug "Android" build/Standoff-<v>.apk`, with JAVA_HOME = LocalTools/android/jdk/jdk-17.0.20.1+1;
   - push, then `bash tools/release_apks.sh <v> HEAD`.
   - Android only: the web version was removed 20 Oct.

## Waiting on him
- His verdict on 0.45.0, the Bruiser's strikes. One known weak spot: the Elbow is hard to read side on.
- Older verdicts: 0.34.0's screen-filling effects; 0.30.0, the Bruiser himself.
- His list of lobby fixes (asked for, never sent - the online work on 20 Oct may have covered it).

## Next, when it's back (my list from 20 Oct 17:47)
1. Better hit reactions for both fighters. Each is one held drawing now, as in YOMI.
2. The Dancer's motion between moves.
3. 6-player matches run long: 120-270 decisions. A lobby setting for less HP or more damage would help.
4. A third character.
5. The flaky crash in the online tests.

YOMI's source (github.com/uzkbwza/hustle, cloned at `Standoff Workshop/references/yomi_source`) and its mods are study
only - nothing copied.
