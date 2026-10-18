# Standoff - plan (working title)

Timmy, 18 Oct 2026 17:05: "Im looking to try make a Phone version of your only move is hustle that could support up to 6
players". His picks: same Wi-Fi (one phone hosts, online later), free-for-all and teams (picked in the lobby), simple stick
figures, playable core first.

An original game: Your Only Move Is HUSTLE is the reference for how a simultaneous-turn fighter plays - no names,
characters, art, sounds or code from it.

## The idea
The match runs at 60 ticks a second until any fighter is free to act, then stops. Everyone free picks a move in secret
(with a ghost preview of what it does), the picks play out together, and it runs on to the next stop. Up to 6 fighters on
one stage; each attack aims at a picked target.

## Steps
1. **Engine** (done 18 Oct) - `scripts/sim/`: `Sim` (turns, physics, hits), `Fighter` (state, snapshots), `Moves`
   (every move as data), `Bot`. Rules: strike beats grab, grab beats guard / parry, guard takes chip damage, a parry on
   the right frame stuns the striker, strikes meeting clash, armour soaks strikes, hitstun + combo scaling, KO, the win
   check; free-for-all or teams (no friendly fire). Tests: `tools/test.sh` (headless; bot matches with 2-6 fighters).
2. **Two characters** (done, to tune) - Bruiser (600 HP, armoured haymaker, body drop, Ground Slam super) and Dancer
   (450 HP, dash / air dash, spin kick, dive kick, Flurry super).
3. **The phone screen** - stick figures in six colours, a camera that keeps everyone in frame, HP / meter bars; the move
   menu -> aim / target -> a looping ghost preview -> Confirm; a turn timer. Landscape.
4. **Same Wi-Fi** - one phone hosts (ENet), the others find it (UDP broadcast) or type a short code; lobby: name, colour,
   character, team; bots fill empty seats. The host runs the real match and sends each segment's picks + the snapshot at
   its end; phones replay it for show and take the snapshot as the truth.
5. **Android build** to try with friends.

## His calls so far (18 Oct)
- 17:29 "for actions move them to the tabs that we pop up or from the side so we can test the frames" -> side tabs that
  slide out the moves (PickPanel), a frame scrubber over the ghost with hit / hurt boxes.
- 17:37 "I dont like target ... one char that has as many moves as what a YOMIH char would have ... fit with icons.
  Just have the direction functionality" -> no targets; a DIRECTION is the only thing picked with a move (Moves `aim`:
  facing / dir8 / up / down / none); the Dancer has 31 moves; icons are drawn from her own stick figure in each move's
  key pose (MoveIcon); parry timing became Parry Early (frames 1-6) / Parry Late (7-13).
- 17:41 online: a phone can host, but players can't reach it over the internet directly (mobile CGNAT, routers) - a
  small relay with room codes is the way (his hosting call); same Wi-Fi first.

- 17:52 "Just work on getting one char working and remove the other one. Also make the home screen better. Then download
  as much reference material..." -> the Dancer only, a new home screen (0.2.1); the YOMI study (Standoff Workshop/
  references/yomi, reference only) -> 14 numbered style options in `_study/NOTES.md`.
- 18:07 "Your suggestion looks good so just continue working on that" -> **0.3.0, the first style pass** (picks 1, 3, 4,
  5, 6, 9 and 10; it stays smooth, not pixel art):
  - 1: chunky fighters (`Stick`)
  - 3: a near-black stage with a white floor line marked every 100 px
  - 4: layered hit sparks
  - 5: a freeze on contact plus a small shake
  - 6: swooshes behind the striking hand or foot
  - 9: combo counts
  - 10: a white HP chunk that drains

  The effects live in `scripts/ui/fx.gd`, and `tools/shots.sh` takes stills of them (7_hit to 10_arc). Not picked yet:
  2 (pixel look), 7 (speed streaks), 8 (afterimages), 11 (frame advantage line), 12 (tinted icons), 13 (colour-split
  flash) and 14 (floor reflection).

- 18:35 "Continue working o. This feature. Leaving scenery and reflection as those are mods ... Im excited to see the
  flashy animations and burst effects" -> 0.4.0 adds:
  - impact frames (the one hit flashes white), impact lines and speed streaks (pick 7)
  - afterimages (pick 8)
  - super flashes (the stage dims, rays, rings) and colour splits on supers, KOs and Bursts (pick 13)
  - a tumble when launched
  - "+N" frame advantage (pick 11)
  - tab-coloured icons (pick 12)
  - the pixel look as a switch on the home screen (pick 2, `shaders/post.gdshader`)
- 18:37 / 18:40 / 18:42 / 18:44 - Burst, then "Use that page more. It seems near perfect for what we need mechanics
  wise" -> the YOMI wiki's mechanics, mapped in `docs/mechanics.md`. 0.4.0 builds:
  - Burst, the lean (DI) and hit cancels
  - interruptible moves with Hold
  - the wiki's combo scaling and less stun for a reused move
  - counter hits, wall bounces and the 7th-hit launch
  - the 30 s turn clock

  The rest is listed for 0.5.0 and later.

- 19:02 "You can kind of burst a lot" -> 0.4.1: one Burst to start, refilling slowly (about one each a match).
- 19:10 "Continue on with the other features. Same as before wiki for mechanics and then the videos and images for
  looks and feel" -> 0.5.0: Free / Whiff Cancels, knockdowns and getting up, meter in bars, the round, Sadness, air
  options (docs/mechanics.md). 19:12 "Remove the frame thing from the bottom. Also how do I decide how far I dash?" ->
  the scrubber's gone; a Distance slider. 19:14 "How do I see how my and my opponents moves will interact?" -> tap an
  opponent to guess their move; their ghost plays against yours. READY over your ghost (the YOMI screenshots).

- 19:32 / 19:38 visual pass: body A kept ("I actually like option A"), weight added (0.5.2). 19:41 "What is with the
  white line streak things ... They kind of look like rain. Remove those" -> the speed streaks (pick 7) are gone (0.5.3).

- 19:46 "Whats next to make it as like for like as we can besides art? I want to have better effects and much
  cooler moves but im cool wjth it taking longer if thier is more mechanics missing" -> the plan: 1 defence the YOMI
  way, 2 combo depth, 3 much cooler moves, 4 effects per move (+ sound, replays, lobby rules). 19:48 "Continue working
  on that please" -> 0.6.0 = steps 1 and 2 (docs/mechanics.md).

- 20:03 the parry explained (a perfect block - the frame filled in from the preview). 20:05 "Ok. Then yeah continue
  on please" -> 0.7.0 = step 3: projectiles, the Sway stance, the jab chain, Mirror, Spin / Air Throw, initiative, Grand
  Finale (docs/mechanics.md).

- 20:19 "Can we work on the lobby system? Look at the steam lobby your only move is hustle has" -> 0.8.0 = online
  lobbies like YOMI's Steam ones: a list, lobbies with members / matches / owner's rules / chat, challenges for up to 6
  with bots, spectating; a Cloudflare lobby server (relay/). 20:57 deployed with his API token -> 0.8.1 plays online
  (docs/lobby.md). 20:59 "Also upload this to a new github repo please" -> github.com/Veriduim/standoff (private).

## To tune / later
- **Match length with 6:** bot matches take 120-270 decision points with 6 fighters (50-90 with 2). At ~10 s a decision
  that's far too long - lower HP or more damage with more players (a lobby setting), and a turn timer.
- Directional influence when hit, a burst out of combos, wall bounces, more characters, online play, replays.
