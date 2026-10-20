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
- 21:03 "Why not the apk builds as releases?" -> every APK is a GitHub release (tools/release_apks.sh). "Get more
  refernces as i think your getting confused about the way moves are categorised" -> YOMI's own menu studied
  (Standoff Workshop/references/yomi/moves_menu/CATEGORIES.md) -> 0.8.2: its five tabs, Movement / Attack / Special /
  Super / Defense; air attacks and grabs in Attack, Wait in Movement, Uppercut / Flash Kick / Spin Throw in Special,
  Dodge (was Roll) in Defense, Burst Cancel / Whiff Cancel in Super; Hold a button by Confirm.
- 21:11 "So who is the char we are working in first? As every char an x factor so to speak" -> the Dancer, no x-factor
  yet; options offered. 21:14 "Can we try the fans, temp and dance forms? Maybe combine two of them honestly", 21:17 "We
  may pick one or a combination of two" -> 0.9.0: all three as switches (home screen / lobby rules), any mix
  (docs/xfactors.md). Also fixed: projectiles in flight weren't drawn while you picked.
- 21:37 "Some qol we will need for the multilayer. Have our options expand from the left and then the enemy closest to
  use expand from the right. Then we should always try move to the enemy closest to use for attacks. Last remember the
  last option we choice for our char" -> 0.9.1: your tabs + drawer down the left, the nearest enemy picking too down
  the right ("Guess <name>" - their tabs set your guess; tap another enemy to swap); moves with no direction (Mirror,
  Wait, Block) turn you to the nearest enemy (aimed moves already default to them); your last pick (move, Free,
  Distance) is picked first next turn and kept between plays; your colour is kept too.
- 21:51 "Show me the enemy frame stuff on the bottom right side similar to your only move is hustle so I see my own with
  my colour bottom left then enemy selected bottom right and also make guesses on how much they will move with dash or
  something" -> 0.9.2: the bottom bar is two pick cards as YOMI's panels - yours bottom left in your colour, the enemy
  down the right bottom right in theirs (their guessed move, its frame data, their pad, their Distance / parry frame);
  Boxes, Hold, Confirm in the middle. 21:52 "The other player should see themselves on the left side and have a
  simialr interface to me" -> each phone's panel is its own player's (tested online).
- 21:59 "the icon should flip based on who you selected so the purple guy should face us in the icons bottom right. Then
  if we are on different sides they should flip again. Last just make the dancer cooler and feel like a dancer. With
  proper fans. Thinking jade MK series" -> 0.9.3: card / drawer figures face who they're up against (and turn when
  sides swap); steel war fans in her hands (shut moving, half open standing, wide on strikes; thrown ones the same); a
  sash; a fan-dance stance that sways; Updraft (a gust off both fans that lifts them - a wind effect, the first move
  "cue") and Silk Glide (a sliding kick through projectiles); Fan Throw aimed any way. MK's Jade / Kitana: study only.
  -- --moveshots=<dir>:<moves> snaps any move as it plays.
- 22:12 "I want their model to be better as well as I dont like the headband. Maybe investigate pixel art for dancers to
  help? Then for attack select it should show your char colours again ... im giing to send this to two friends to test
  with so im hoping we have the option to still select a combo of styles?" -> 0.9.4: headband gone; drawer icons in
  your colour; a new lobby starts with the styles switched on at home (the owner changes them in RULES); the study
  (Standoff Workshop/references/dancer, tools/dancer_refs.py) -> Outfit (scripts/ui/outfit.gd): hair (ponytail / bun /
  long), a veil, cloth panels or a skirt, sleeves, a waist - four looks on a sheet for his pick (-- --dancerlab,
  -- --look=N to try one in game). Off until he picks. 22:26 "Just go no clothes just fans" / 22:30 "Just keep it as A": the outfit went.
- 22:37-22:39 -> 0.9.5: the enemy's side always shown (mid-move: what they're doing), Hold in Movement mid-move,
  tabs Attack / Special / Super / Movement / Defense.
- 22:40 "We dont do things big enough or for enough frames. Our movements are really small and unexpressive. We need to
  elevate this a lot please" -> 0.10.0: YOMI covers ground - dashes ~2x as far and faster, walking / back step / Dodge
  faster, jumps higher and longer, air dash longer; lunges on the strikes that stood still; knockback x1.35, launches
  higher; poses swing further from the stance (Poses.exaggerate - body and arms x1.32, legs x1.12, capped); effects
  x1.3, hits hold longer (hitstop x1.35) and shake more; afterimages last longer and show sooner; the camera comes in to
  x1.8. OPP=n tools/reel.sh for a 1v1 clip.
- 22:53 "what is the ground wave? ... you can see a ton of how animations can be done from videos. Just a graphical
  improvement overall"; 22:57 "I dont love the massive white circle thing"; 23:01 the mods (Colossus, Yharim - videos
  in Standoff Workshop/references/yomi_mods/video, study only) -> 0.10.1: YOMI-style extreme key poses, the Ground
  Ripple a shockwave along the floor, the big white impact ring gone; 0.10.2: her fans bigger (Stick.FAN_R 27 - the
  prop that makes her, as Colossus's sword makes him) and her hand strikes leave crescent slashes off the fan's edge,
  longer and fuller.
- 23:05-23:14 0.10.3-0.10.5: the mods' dark starburst hit, cards share the top bar, no shapes on hit; the mod study
  (giant fan sweeps, glide ribbon, throw sphere, super floor ring).
- 23:23 "Have we made it so more of our moves allow for better movement? Along with incorporating some of these into the
  styles" -> 0.11.0: attacks keep momentum (low friction in their startup, a lunge never slows a faster slide); a
  Distance on the lunging attacks (Straight, Side Kick, Sweep, Knee Dash, Silk Glide); per style: Fan Step (blink to
  your thrown fan) + fan ribbons, Tempo beats move you faster + a shard aura, Snap Step; Encore ends in a sweep.
- 23:31 my call: Fans + Tempo for the Dancer, Forms folded in. 23:34 "I agree with yiur decision" (also "I broke it ...
  Air Fan spam!!!" and "work on moving iver any more mechanics we miss and general ui improvments") -> 0.12.0:
  - Fans + Tempo always on (the switches gone; Forms stays in the code, off); Snap Step and Windmill in her normal kit;
  - Air Fan is an air option with a brief hang;
  - the Ceiling; Land Cancel; Low Profile; Undo against bots;
  - quieter beats; the enemy card's empty state (docs/mechanics.md).
- 23:59-00:11 0.13.x: the Dancer is a spacer (docs/dancer.md); Replay; lobbies survive the phone being put aside.
- 00:22-00:28 0.14.x: everything 25% bigger; the ☰ match menu; the YOMI character research (docs/yomi_chars.md),
  "Ready in N" labels, Beating Backdash.
- 00:38 "Continue working please" on my list (steerable fans, sound, the Chess Timer); 00:43 "1 sounds like a pretty
  good soultion" (local play over a phone's hotspot / the same Wi-Fi - next after sound); 00:43 "why the fans [are] so
  small? ... compared to the ones in hand" -> 0.15.0:
  - steerable fans: Recall with a direction flings her fans that way before they come home (Cowboy's bullets);
  - thrown fans drawn the same size as the ones in her hand (they'd kept the old size);
  - **sound**: 32 sounds made in code (`tools/sfx_make.py`; `tools/sfx_board.py` = a numbered listening video), played
    by `Sfx` (scripts/ui/sfx.gd) on every event, swing, super, drop landing, menu button, your turn and the last 5 s
    of the clock; a limiter on the master bus; quiet behind the home screen; Sound on/off on the home screen and in
    the ☰ menu, kept. `SOUND=1 tools/reel.sh` keeps the audio.
- 00:57 "its side by side instead of stacked" (the result panel) -> 0.15.1: Rematch / Replay / Menu stacked.
- 0.16.0: **Nearby play** - a phone hosts the lobby on the Wi-Fi / its hotspot, the others find it (docs/lobby.md
  "Nearby").
- 0.17.0: **YOMI's Chess Timer** as a lobby rule (a bank each, then the minimum a turn; a Ranked preset = the wiki's
  YomiRanked / Starlight rules); 01:15 "make the direction arrows a little bigger ... select the same arrow again to
  have no direction/netural" -> the pad 56x38 (the bar 144 tall), and the lit arrow tapped again = neutral for every
  move: at the nearest enemy (a jump straight up, a block high).
- 01:24 "Do we need the IP for hot-spot? If not I say we remove all that? Also I say we drop the chess timer stuff for
  nkw was well please. I think round and turn timers are better" -> 0.17.1: Nearby has no addresses (the list finds
  the hosts by itself); the Chess Timer and its Ranked preset are gone.
- 01:29 my list of what's left; 01:32 his calls: yes to How to play, rejoining a match, step 4 effects per move, smarter
  bots, the rest of YOMI's missing rules (restands, initiative, parry lock-out); less HP with more players banked;
  no pass-and-play; Super Armor is for the Bruiser, who comes back later as the rushdown character.
- 0.18.0: **How to play** (six cards: first launch, home, ☰); **back into a match after a drop** (docs/lobby.md); early
  picks kept by the host (they were being dropped).
- 0.19.0: **restands** and **initiative** on more moves (the wiki; docs/mechanics.md). 01:46 the Bruiser, later: "a mix
  of the Nakmuay and Super Smash bros little mac".
- 0.20.0: **step 4 - effects per move**: fan cuts, kick thumps, the ripple's dust, a super cut-in (docs/mechanics.md).
- 0.21.0: **smarter bots** (Bot.smart: each pick tried forward against a few likely answers, the best taken - it never
  sees the player's pick; scripts/dev/bot_duel.gd: 8 of 8 against the quick bot, ~24 ms a pick on the PC). 01:56 "match
  the health, burst and level meters more to YOMIH style"; 02:01 "I want this working for the 6 mode but im worried it
  will clutter ... I like where we put our resources btw! Its just the bars I want go be clearer!" -> every card:
  HEALTH in YOMI's yellow (the white chunk, the picks' damage in orange), BURST!! and LEVEL named under it, the full
  levels in a round badge; the head row unchanged; CARD_H 72. (A separate YOMI-layout 1v1 HUD was started and dropped
  for this.) Also: the restand state is saved (online lost it each turn) + a check that every fighter variable is.
- 02:10 "You can make the repo private. Lets do difficulty please" -> the repo's private again; 0.22.0: BOTS Easy /
  Normal / Hard on the home screen (the LOOK row's place; Look: Smooth / Pixel moved to the buttons bottom left), kept;
  Easy = the quick bot, Normal thinks a little and plays loose, Hard thinks the most (bot_duel: Normal beat Easy 9 of
  10, Hard beat Normal 8 of 10; ~10 / ~27 ms a pick on the PC). Online, the host's level runs the empty seats.
- 02:15 "When can I save replays??"; 02:19 "Would love to save them to device ... drop the pixel look. I think smooth
  works for us ... I will uppercut and send them flying up. Is the only way to follow super jump? ... when I uppercut
  the camera start panning in and out constantly" -> 0.23.0:
  - **saved replays**: every match (start + each turn's picks; the sim replays them exactly), the last 30, a Replays
    list on the home screen, and "Save to phone" (a copy in Download/Standoff Replays);
  - the pixel look's gone (smooth only);
  - the uppercut launches a little lower (-12 -> -10.5); a Jump straight after it reaches them (it always could - the
    uppercut cancels into Jump or Super Jump on hit; the card now says so);
  - the camera frames the ghost's whole path - it was following the looping ghost frame, zooming out and in with the
    uppercut's ghost on every loop.
- 02:28 "Lets get your 1, 2 and 3 done and then yeah there is a lot of lobby fixes" -> 0.23.1: **Training** (home:
  Training; you and a Dummy - Stand / Block / Jump / Attack / Fight, Reset, both topped up once a combo's over, your
  meter full, an endless round, Undo; not kept as a replay). 02:34 "Cant see myself anymore" (a screenshot: a ghost
  going high had the camera so high the floor was under the bar - from 0.23.0's whole-path framing) -> the camera
  always keeps the floor on screen. The home buttons sized by their words (they overlapped).
- 02:36 "Replays save as Jsons. I cant share those with my friends?" -> replay codes: Share puts it on the lobby
  server (Shelf, 30 days) under a 6-digit code; Replays -> type a code -> Watch code. 02:39 "I just want to be able to
  send my friend a short video in messenger? Also ... the replay was choppy on my ohone with 4" -> 0.24.0: drawing
  ~2x lighter (scripts/dev/perf.gd, `--perf=25 --opp=3`: 4 fighters 1,581 draw calls a frame -> 813, worst 3,635 ->
  914; fans and starbursts batched - Stick.tris; afterimages capped 2 a fighter / 6 in all, every 3rd tick, no fans).
  Video: Godot can't record video on a phone by itself - the phone's screen recorder for now.
- 0.25.0 (02:28 "2" and "3"): **Rematch online** (the same players, bots and mode challenged again; their phones go
  from the result to the invite) and **your look** (Style by YOUR COLOUR: outline Ink / White / Gold / Cyan / Pink /
  Violet, trail None / Glints / Embers / Petals / Wisps, with a live preview; saved; online it goes with your seat;
  replays keep it). This closes step 4.
- 03:00 "hard to scroll down the action menus ... in order of lowest frames to higest frames with icons/emojis for
  additional info like unblocakble and initave" + 03:03 "I dont like the big on screen super banner ... Why are all the
  supers for Dancer melee supers when she is supposed to be a zoner char?" + 03:05 "Move all the emoji details to a
  different place on home sceen" -> 0.26.0: drawers scroll from a drag anywhere (icons pass the drag; a drag isn't a
  pick), each tab fastest first (Moves.startup; the frame on each icon), badges (✊ beats blocks, ⚡ initiative, 👻
  dodges, 🔻 hits low, 💥 guard break, 🎯 projectile) with their key on the home screen; no super banner; **her supers
  a zoner's** - Fan Storm (1 bar, five spectral fans in a spread), Gale (1 bar, wind all round her, blows rushers off),
  Cyclone (2 bars, a whirlwind sent forward that keeps hitting), Grand Finale (3 bars, fans from the sky) - spawn lists,
  piercing / rehit / heavy projectiles.
- 03:11 "Those superstars definitely need some animation improvements. Also hone screen is getting very cluttered" ->
  0.27.0: new poses (twirl_a / twirl_b pirouette, fan_spread, gather, throw_high, throw_back) and a sequence for each
  super; spectral fans glow (kind "sfan") and the falling ones cast a shadow where they'll land; Gale's ring of wind
  arcs; home: Sound and How to play as two small icons top left, Training and Replays alone at the bottom, the badge
  key a How to play card. The slash shape's repeated tip points (a "triangulation failed") fixed.
- 03:07 "Also want to work on sound effects. They arent bad but they arent amazing what we have" -> 0.28.0: the second
  pass of tools/sfx_make.py - stereo, a small room reverb (Schroeder, in numpy), layered impacts (crack, body, smack,
  tail), variants for the ones heard most (hits x3 / x2, slash x3, block x2, swing x3, fan throw x2 - never the same
  twice running), a new slash for her fan cuts and a wood-and-steel clack for a block on her fans, bigger supers / KO /
  Burst; thuds raised so a phone plays them (all 300-8000 Hz share >= 0.8). A before/after board went to him.

- 03:32 "rework dancer kit. Make sure she really fits the zoner/control space char ... research othrr fighting games
  ... Smash Bros, MK, Street Fighter and then see how these would Translate to Hustle with the help of its wiki and 5
  base chars" -> 0.29.0 (docs/dancer_research.md): the rushdown moves cut (Knee Dash, Flash Kick, One-Two / Spin
  Finish, Dive Kick, Air Spin, Hip Toss, Spin Throw, the Sway stance); **Fan Ward** (a fan hung at the Distance as a
  trap - Recall's pincer, Fan Step to it, a floor mine), **Fan Gust** (wind: shoves them, blows shots back, carries her
  fans), **Fan Flick** (Fan Slash's follow-up, back out to range), **Mirror reflects** shots; bots play her range.

- 05:03 "Am arrange how you think and we will work on our next char then" + 05:27 "Nakmuay. Did you look into? I
  want a lot of his effects of slapping an enemy accross map and being able to rush them down. Also. I feel our map is
  small" -> 0.30.0 (docs/bruiser.md): **the Bruiser** - Muay Thai + a boxer (Little Mac, Nakmuay, Fahkumram, Sagat,
  Steve Fox studied): Jab -> Cross -> Hook, Bob & Weave, Teep, Elbow, Roundhouse and Haymaker with Super Armor, the
  Clinch (knees, elbow, dump), Flying Knee (guard break), Superman Punch (overhead), Catch, Quake Stomp; **flings** (his
  big hits send them sliding across the stage - a ring of air, cracks) and **Chase** to run them down; **Grit** -> the
  K.O. Punch; supers Bull Rush, Barrage, Clinch Fury; gloves; a fighter picker on the home screen (lobbies carry it,
  bots at random, the training dummy either); the stage 2800 wide; YOMI's blockstun / guard-break rule. The Dancer's
  open questions settled: Encore from range, dash 15, Snap Step gone.
- 06:14 "they are off the map" -> 0.30.1: the stage view drawn at the match's width in vs-bots / Training (it kept 1600).
- 06:20 "I still want more from our animations" / 06:22 "Lets try 1 and 2" -> 0.31.0: (1) every strike gets more to it
  without new art - Poses._strike coils past its wind-up key (COIL), snaps through and lands past the strike pose
  (OVERSHOOT), holds while it's out, follows through past it (FOLLOW) and eases back; Poses.push turns each bone on
  further with lengths kept. (2) hit reactions by how it landed - the sim keeps Fighter.hit_look (head / body / low /
  crush / slide / air, Sim._look) and hit_t; five new poses (doubled over, legs taken, crushed, flung, launched); the
  reaction snaps past its pose for 3 frames, then eases off toward a reeling guard.
- 06:38 "Try the rest except 6" -> 0.32.0 (StageView): (3) smear frames - a strike's limb whipping more than SMEAR_PX
  in a tick fills the area it swept (two see-through quads + a streak for the fist / foot); (4) squash and stretch -
  scaled about the feet: long going up, squat landing, squeezed by a blow, stretched along a strike; (5) lag - the head
  on a spring trailing fast moves (overshoots when they stop), her fans on a spring lagging the arm (Stick.fan_at turn).
  Not done (his word): 6 slow motion on a K.O. / a super.
- 06:56 "the bottom of the screen is cutting off now" -> 0.32.1: the pad's arrows drawn (a phone's font drew the
  diagonal glyphs taller), and the bottom bar grows up if what's in it ever needs more (PickPanel.bar_h).
- 11:45 "Could someone on ios play this?" / 11:48 "The web version makes a lot of sense" / 13:58 "Go through those
  steps" -> 0.33.0, the web version at https://veriduim.github.io/standoff/ (GitHub Pages, tools/release_web.sh with
  each release; single-threaded build, ~10 MB to download, plays bots offline once loaded):
  - The icons: a browser has no system fonts, so every icon and emoji drew as a box. The game carries its own - just
    the 29 its text uses, cut from Noto Color Emoji / Noto Sans Symbols 2 / Noto Sans Math (SIL OFL) by
    tools/icon_fonts.py, behind Godot's font (Ui.add_icon_fonts) on every platform. Their line spacing is capped at
    Open Sans's: Symbols 2's deep descent had made every button 13% taller (the home card ran off the screen).
  - In a browser: no Nearby tab (it can't host or find lobbies on the Wi-Fi - online only, with the same server, so
    browser and Android players meet in the same lobbies); "Turn your phone sideways" when held upright (Safari can't
    lock it); "Download" for a replay; on an iPhone's Safari, the home screen says Share, then Add to Home Screen, for
    full screen; the on-screen keyboard for names, codes and chat.
  - The lobby server answers a browser's ask-first (CORS preflight) so a replay can be shared from the web.
  - The APK no longer packs the lobby server's node_modules (relay/.gdignore; build/.gdignore too).
  - Not tested on a real iPhone yet (Chrome posing as one only) - a friend's iPhone is the next check.
- 14:05 / 14:09 two reference videos of YOMI mod fights (Standoff Workshop/references/yomi_mods/video_19oct_1405,
  _1409): "our attacks and effects dont use the full width and height of the field". 14:35 "Wouldn't worry too much
  about stage effects. Rest sounds good" -> 0.34.0, effects that fill the screen:
  - The cause: every effect was sized in world px x the camera's zoom, so it shrank whenever the camera pulled back
    for a wide stage or six fighters. The big moments are now sized by the SCREEN (Fx.band = the stage band's height,
    `_add_scr`, "scr" parts).
  - Quake Stomp: a wall of grey spikes bursting up across the whole screen, a wave racing out both ways from his
    foot, every sixth taller than the screen (Fx._spike_wall).
  - Big hits (Fx.BIG_HIT 45+ after scaling - about 1 hit in 8, 3 a match in bot matches; and every K.O.): a giant
    white starburst behind the fighters (their silhouettes on it) and three rings opening out wide (Fx._big).
  - Grabs and clashes: wide thin rings, wider than the two fighters at any zoom (Fx._wide_rings).
  - The Bruiser rushing in on his own feet: solid grey copies of himself left behind (Fx.afterimage solid, SOLID).
  - Flings and Bull Rush: their ring of air and wind streaks sized by the screen too.
  - Not done (his word): a super that changes the stage's colours.
- 20 Oct 13:24 "Revert it from being a Web app back to an apk please", 13:26 "I just dont care enough about ios users"
  -> the web version is gone: GitHub Pages off and the
  gh-pages branch deleted (veriduim.github.io/standoff no longer serves it), tools/release_web.sh and
  tools/web_check.mjs removed, the Web export preset removed, and the browser-only code out (no Nearby tab, the turn
  note, Download, the iPhone tip). Kept, as they help the APK too: the icon fonts (the same icons on every phone) and
  relay/.gdignore. The lobby server still answers a browser's ask-first (harmless; not worth a redeploy). The APK
  itself is unchanged - v0.34.0 stays the one to install. To bring the web back: git show 9f168a8 b0e1d32.
- 13:54 "Lets zoom out from the chars and move them further apart. Have you found the sizes from YOMIH wiki on their
  base stage sizes and char sizes?" - YOMI's own source is public (GitHub uzkbwza/hustle; numbers in docs/mechanics.md).
  A sheet of three: A now, B between, C YOMI's scale. 14:04 "I do think C is the best personally" -> 0.35.0: 1v1
  starts 840 apart (7.8 heights, YOMI's), the camera never closer than 20 heights across (VIEW_MIN 2120 - fighters
  ~52 px tall on his 20:9 at your pick, ~64 while a turn plays). Six players: unchanged - they already filled it.
  The lobby's start distance goes to 1200.
- 14:04 "pull that repo as reference and see how it does some of its animations to see if we are missing something or
  overdoing something" - the study: Standoff Workshop/references/yomi_source_notes.md (hit pause, shake and spark
  already match; YOMI also has speed lines, knockback smoke, held drawings, wall debris; we also had words, combo
  counts, a camera push-in). 14:22 "Dont keep the words and damage numbers and lets get these all in then and see how
  it is" -> 0.36.0:
  - No words on the stage (COUNTER, WALL SPLAT, PARRY, PUSH, GUARD BREAK, ON BEAT!, K.O. READY, SAD!, SADNESS!, TIME!,
    the form names, the cancels, a super's name) and no combo count or damage over whoever's comboed. The effects
    under them stay. Still there: the pick's own labels (Ready in, the +/- advantage) and a super's cut-in title.
  - No push-in on big hits (Fx.punch) - YOMI's camera never zooms in.
  - Speed lines (Fx.draw_lines, camera_tick): when the fighters' middle rushes - the camera chasing a launch - 100 thin
    white lines streak across the band against it, faded round the fighters; they need a few ticks of speed (a jolt
    doesn't count) and die away in a freeze, a pick or a super's dim. Calibrated on ours (LINES_FULL): a Haymaker full,
    a Roundhouse or Flying Knee most of the way, a dash faint at most.
  - Smoke behind knockback (Fx.smoke): two grey puffs a tick while someone hit moves faster than SMOKE_PX (6) a tick -
    a Haymaker leaves 35 ticks of it, a jab none.
  - Wall slams throw debris (Fx._debris): 32 big chunks off the wall back into the stage (20 bouncing off it).
  - Held poses (Poses): every key held, then a 2-frame snap to the next (SNAP; it eased the whole way). A strike snaps
    into its wind-up coiled and holds it still, one in-between to the strike, a small overshoot, held while it's out
    and HOLD_ON (4) past, then a recovery pose held until the snap on. A hit reaction holds its pose through the
    hitstun (it eased off toward a guard).
  - Six players: the Bruiser's Grit took the whole top card and hid the name - five pips on a narrow card now.
  - Found, not changed: YOMI's knockback is ~4x ours for the fighters' size (5-8 px a tick for a 32-tall fighter; ours
    ~4 for 106) and its gravity ~2-3x - its launches cross the screen far faster.
- 14:48 "Remove the speed lines again or rework them into the background more like YOMI. Can you make those changes
  please?" (read as: the lines, and yes to the faster launches) -> 0.37.0:
  - Speed lines in the background, as YOMI has them (its own layer just over the background colour): drawn under the
    glow, the walls, the floor and everyone, at most 45% see-through white, thinner. Recalibrated (LINES_FULL 0.75).
  - Launches at YOMI's pace (Sim.LAUNCH_PACE 2): a hit sends them twice as fast sideways, slowing in the air
    (LAUNCH_DRAG 0.9; a fling FLING_DRAG 0.95) so they end up about as far as before; up and down LAUNCH_LIFT 1.4 with
    gravity as much stronger while they reel - the same time in the air (combos keep their timing), higher; on the
    ground they stop twice as quickly (YOMI's ground friction is strong). A Haymaker sends her 48 px a tick (was 24).
    Tuned on bot matches (24 1v1 + 12 four-way each): a plain x2 made 1v1 39% longer (combos fell out of reach); as
    shipped, 1v1 ~101 turns (was ~100), four-way ~196 (~181, within the noise), the longest combo about the same.
  - Smoke only on the big ones now (SMOKE_PX 11 - an ordinary hit goes 7-10 px a tick at the new pace).
- 15:10 "Remove the speed lines and the ground shake is way too much know. The animation should only be in the are it
  effects. If it is the whole arena that needs to be limited to it still showing in the vicinity of the char and then
  just shake the whole stage lighlty ... We have YOMI now so we may be able to get inspiration for how they do
  ground/are ground slam attacks" -> 0.38.0:
  - The speed lines are gone (all their code).
  - The rule from now on: an effect stays in the area its move reaches; a move reaching the whole stage shows near
    the one doing it and shakes the stage lightly.
  - Quake Stomp only hits 90 px either side of his foot, but drew spikes across the whole screen and shook it hardest
    of anything (kick 9). YOMI's ground pound (its Robot's landing, from the source): a curtain of debris thrown
    straight up off a strip either side of the impact (64 bits, 3 fighters wide), small shockwaves that run along the
    floor carrying their own hit, and one short bump of the camera - nothing screen-wide. Now: 14 spikes and 36 bits of
    debris over its own strip (Fx.QUAKE_REACH 100, world sizes - the tallest by his foot), the floor ring and crack
    that size, and a light shake (2.5).
- 15:21 "Drop this streaks for hay maker. Actually. Put them behind the impact to try and show the momentum of his
  punch?" -> 0.39.0: a fling's streaks (Haymaker, Teep, Roundhouse, Clinch Elbow, Bull Rush - one shared effect)
  no longer fly off across the screen the way she goes. Nine momentum lines in his colour trail BEHIND the impact,
  back toward him - long wedges, thick at the impact end, easing on into it (Fx "mline"); over the starburst, under
  the fighters; fighter-sized.
- 15:28 "a lot of our hit animations a bit generic ... We should rework dancer as well. She is suppose to be a zoner/
  spacer but she is a bit to stiff ... YOMI is normally a very melee focused game" - YOMI's own hurt drawings are one
  still each (high / mid / low / air / down / wall slam); its life is in the attacks, each a full-body shape. 15:32
  "Sounds good then we can work on the rest": (1) the Dancer a MELEE spacer like YOMI's Cowboy - fans as blades, long
  cuts at mid range; keep Fan Throw / Air Fan, Recall and Fan Step; cut Ripple, Ward, Gust, Flick and the projectile
  supers; melee supers again; (2) her strikes as dance moves - a labelled pose sheet first. (3) moving like a dancer
  and (4) better hit reactions after.
- 15:34 "grab the frame data for the basic attacks from YOMI as I think our grab is 5 frames instead of the standard 3"
  -> 0.39.1: it was - YOMI's Throw is out frames 3-5 of 16 (its source). Her Grab now 3-5 of 16 (was 5-6 of 22), his
  Clinch out on 3 (was 4; still 24 long). The table: docs/mechanics.md "Frame data".
- 15:40 "I was actually saying we should change our frames to match YOMI's as their makes sense to me" -> 0.40.0:
  every basic attack retimed to its nearest YOMI move (docs/mechanics.md "Frame data = YOMI's"; poses, lunges, low
  profile and invulnerability stretched to fit - the retime script's map: the wind-up onto the new startup, the hit
  onto the new active frames, the recovery onto the rest). Both jabs out on 4 (hers was 3, his 2). YOMI's clash rule
  too (its source): a match in damage clashes, a mismatch goes through, a one-sided meeting isn't a clash - so an
  invulnerable Uppercut or Gale goes through a strike out on the same frame. Bot matches as long as before.
- 15:59 "Whats your suggestion? These would be basic or specials?" -> the kit: basics Fan Tap (was Jab), Fouetté
  (Straight + Spin Kick), Plié Cut (Sweep), Arabesque (Side Kick), Grand Battement (Axe Kick), Sauté Kick (Air Kick),
  Tour en l'Air (Air Knee); specials Port de Bras (Uppercut), Pirouette (new), Grand Jeté (Updraft) + Fan Throw / Air
  Fan, Recall, Fan Step, Mirror; supers Fouetté Storm (1), Grand Finale ending on the Révérence (3), Gale kept; cut Low
  Kick, Ripple, Ward, Gust, Flick, Fan Storm, Cyclone, Encore's spectral fans. 16:17 "All sounds good to me" ->
  0.41.0, group 1 - the basics: the moves keep their ids (bots, tests, chains key on them) with new names, poses (22
  new, Poses.P - built from joint angles, her bone lengths kept), YOMI's frames, hit boxes and icons. "drawn": true -
  no exaggeration and no extra coil (posed at full stretch); "fan_open" - Fan Tap pokes with the fan shut. A held
  strike stops at the next key (Tour en l'Air's second spin). Spin Kick and Low Kick gone.
  0.42.0, group 2 - the specials: Port de Bras (the Uppercut's id: fans swept up overhead, out on 4, through a strike
  with initiative), the Pirouette (new: steps in, two cuts - "no_cancel" so the first landing doesn't end it; Tour en
  l'Air too), the Grand Jeté (Updraft's id: a leap - clear of a low by frame 7 - landing on a cut, out on 12). Ground
  Ripple, Fan Ward, Fan Gust and Fan Flick cut (their code was all data - nothing left behind but generic shot and
  effect code). Her bots play her range with pokes, a Pirouette in, a Jeté over lows; the zoner-kit test is now
  the melee-spacer test.
  0.43.0, group 3 - the supers: Fouetté Storm (Fan Storm's id, 1 bar: five whipping kicks travelling on, the last
  floors them), the Grand Finale (3 bars: Pirouette in, three Fouettés, a Grand Jeté landing on a cut that floors them,
  then the Révérence bow - 112 damage on a fresh opponent after combo scaling), Encore a melee flurry (three cuts, the
  last floors them); Gale kept; the Cyclone cut. Bot matches as long as before (1v1 ~97 turns). docs/dancer.md
  rewritten for the melee spacer.
- 16:50 "The speed increase in the top left. Remove that please. Also ... along with our icons can we use coloured
  words similar to YOMI to say the effect in the frame data text?"; 16:59 "Our ui is getting cluttered in the fight.
  Lets remove the free box and then I think hold is fine in movement alone"; 17:00 "Dont we have that information above
  the health bar? Also can you cancel when its not free?" -> 0.44.0:
  - The 1x / 2x speed button gone (the playback's always 1x).
  - The cards' frame data in rich text: hits on, damage, length plain, then each effect as a coloured word with its
    icon (PickPanel.WORDS): ⚡ Initiative green and 💥 Guard Break orange (YOMI's own), a super's lvl1 / lvl2 / lvl3 in
    YOMI's cyan / orange / magenta, ✊ Grab, 🔻 Low, Overhead, 🛡 Super Armor, 👻 Invulnerable, 🎯 Projectile, Launcher,
    Knockdown - no-break spaces so an icon never wraps from its word.
  - No Free switch and no Hold button on the bar (Hold's in Movement). The Free Cancel charges are the crosses over the
    health bar; an attack takes one by itself while there's one - and never a bar of meter on its own (with none left a
    Free Cancel costs a bar - YOMI's rule - so with no switch that's off now).
- 17:05 "What is the boxes button for? Also now with the more space id use that for text now" -> 0.44.1: the cards'
  text takes the room the Free / Hold buttons left (it grows; the Distance column only as wide as its slider), back to
  14 px. (Boxes: the hit and hurt boxes drawn on the stage - YOMI's "show hitboxes".)
- 17:12 "Drop that and move it into the settings in the hamburger menu. Then for distance things. Put them on the left
  of arrows. So our order is action icon - text - distance(when applicable) - direction arrows - confirm" -> 0.44.2:
  Boxes off the bar, a match-menu setting ("Hit boxes: on / off", by Sound; kept between plays - PickPanel.boxes);
  the card's order icon - text - Distance - arrows (theirs mirrored); the bar's middle is Confirm alone.
- 17:18 "remove how to play from hamburger menu and put that back in main menu. Restart is fine as long as its only for
  bot games and dummy games" -> 0.44.3: How to play is a button on the home screen by Training and Replays (it was a
  small "?"), not in the ☰ menu; Restart there already shows offline only (bots, training). Her card's tag is "Spacer
  · war fans" and her How to play card describes the melee spacer (it still told of Fan Ward and Fan Gust).
- 17:39 "Final text change is for fighting text for move selection. Id have it for tags similar to the name if the
  move. So on its own line with tags in it separate maybe like tag . tag ?" -> 0.44.4: a card reads the move's name,
  then its tags on their own line (tag · tag - a super's lvl first), then hits on · damage · length.
- 17:50 "Lets keep going and mak sure you have kept the documentation for all of this. Also is this on GitHub and
  possible to download public?" -> the repo is public, every APK is a release, and
  https://github.com/Veriduim/standoff/releases/latest/download/Standoff.apk is always the newest (release_apks.sh
  uploads a copy named Standoff.apk too, since 0.44.4). 0.45.0: the Bruiser's strikes as full-body Muay Thai / boxing
  shapes (docs/bruiser.md "His strikes") - his moves were the generic poses next to her dance.
- Seen in the tests (not new - it was there at 0.43.0 too): Godot now and then crashes in the Nearby play test (a LAN
  host and finder) before the summary prints - rerun, it passes; the same crash usually lands after the summary.

## To tune / later
- **Match length with 6:** bot matches take 120-270 decision points with 6 fighters (50-90 with 2). At ~10 s a decision
  that's far too long - lower HP or more damage with more players (a lobby setting), and a turn timer.
- Directional influence when hit, a burst out of combos, wall bounces, more characters, online play, replays.
