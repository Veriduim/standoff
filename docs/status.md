# Where Standoff stands - parked again 23 Oct 2026

Timmy, 23 Oct 15:52: "Lets get our changes in now. Doc and note everything and then push to guthub and we will go back
to LAD". It was back on from 12:42 for an animation and effects pass - YOMI and its character mods (Nakmuay for him,
Umbra for her) the study, nothing copied. **All of it is pushed to master but NOT released: the newest APK is still
0.46.1.** (It's a game for him and his friends - 13:30 "Their is no standoff release" - GitHub is how they get it.)

Before that, 21 Oct 09:59: "No issues at all. But just document everything on this and park it for now as we swtich
back to Life after Dark". The online fixes (0.46.0 / 0.46.1) were tested with a friend on real phones: no issues.

## 23 Oct: the animation and effects pass (on master, not in an APK yet)
- **Every move its own drawings** (`docs/animations.md` is the checklist): tumbles and flips with a bendable spine
  ("bend" at 1/4, 1/2, 3/4) and loose shoulders, grabbed / wall-splat / pinned-flat looks, taunt routines, his hand
  wraps, the movement moves, her borrowed moves redrawn after Umbra, his after Nakmuay.
- **Effects after the mods, toned to Nakmuay's scale** (14:02 "these are way too much" before): YOMI's movement dots,
  a look per hit (cone, crescent, rings), her petals in her colour.
- **Specials and supers "exaggerated to hell"** (14:49 - `Poses._hell`, strength 2 his pick): more lean, a wider
  stance, more spine, the striking limb stretched while it hits; capped so nobody lies flat; eases back after the last
  hit. Normal attacks and her Forms as drawn.
- **The Barrage, rebuilt with him** (15:11-15:40, "That is feeling good!"): five hooks, right to the body, left to the
  head, a short dash in after each (his words: "the first hit lands. Then he does a short dash like movement and hits
  with the left. Then repeat right"); about a quarter of the stage in all; a 10-frame beat with every hit freezing and
  shaking harder; the high left cross wound right back, pinning them flat on the floor 2 frames, then bouncing them up
  about 1.5x his height and on a little.
- **Bull Rush:** set like a bull (head down, the back foot scraping), the head-down run; landing it, its own follow-up -
  the shoulder ram in a big freeze, driving on through low, then a crouched guard (15:49 no back-swing).
- **New things moves can have** (sim): a hit's `"tip"` (the limb that strikes - its arc, its stretch), `"impact"`
  (freeze and shake x), `"pin"` (held flat on the floor first), `"bounce_up"` / `"bounce_x"` (the ground bounce's
  height and carry); a move's `"follow"` (dash-in windows) and `"hit_move"` (its own follow-up when it lands).
- **Dev:** `godot --path . --write-movie out.avi -- --as=bruiser --vs=dancer --replay=barrage@70,catch<jab` plays moves
  out one by one for a video, with a closer camera. Review tools in `Standoff Workshop/tools`: frames_sheet / seq_lab
  (drawings), hell_lab (strengths side by side), limb_check (limbs lost in the body), fist_heights (where a strike lands
  on them), barrage_probe, his_poses.py / her_poses.py (the pose builders - joint angles in, `Poses.P` lines out).

**Latest release:** 0.46.1 (versionCode 78).
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
- **New specials** (15:42 "a lot of our specials are kind of boring. Like what special does he do that is cool and not
  just a variation of a normal hit?") - my ideas, his pick: Ground and Pound (pounce, then punches on the floor -
  replacing Superman Punch), Rope Bounce (springs off the wall into a lariat - Clinch Fury's slot), Spinning Back
  Elbow (both sides, armour - replacing Haymaker), Plum Toss (a grab special over his head), a follow-up for Rising
  Uppercut. Catch is the one he has that's cool; the K.O. Punch stays.
- **Clinch Fury:** 15:42 "Maybe drop clinch fury. Its kind of boring" - agreed, not dropped yet.
- His verdict on Bull Rush's new follow-through (15:52).
- Gale's gather crouches almost to the floor at hell 2, and Grand Finale's - both flagged to him, no answer yet.
- His verdict on 0.45.0, the Bruiser's strikes. One known weak spot: the Elbow is hard to read side on.
- Older verdicts: 0.34.0's screen-filling effects; 0.30.0, the Bruiser himself.
- His list of lobby fixes (asked for, never sent - the online work on 20 Oct may have covered it).

## Next, when it's back
1. His special picks above, one at a time the way the Barrage went (wind-ups between strikes, left / right told
   apart, a dash between hits, hits landing mid body / head, impact on every hit, nothing through the floor).
2. Her supers the same way - Fouetté Storm, Gale, Grand Finale.
3. Her ranged ideas (`docs/dancer.md`): more fans, going further, moves through her fans, a giant-fan super.
4. A release when he wants one (0.47.0 = this pass).

Older (my list from 20 Oct 17:47):
1. Better hit reactions for both fighters. Each is one held drawing now, as in YOMI (since 23 Oct: bent drawings for
   each look, a grip, a wall splat, pinned flat).
2. The Dancer's motion between moves.
3. 6-player matches run long: 120-270 decisions. A lobby setting for less HP or more damage would help.
4. A third character.
5. The flaky crash in the online tests.

YOMI's source (github.com/uzkbwza/hustle, cloned at `Standoff Workshop/references/yomi_source`) and its mods are study
only - nothing copied.
