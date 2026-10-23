# The Bruiser - the rushdown (0.30.0)

Timmy, 19 Oct 01:32: "I actually reallt liked him and wanted to work on him as our rush down char". 01:46: "My mindset for
brusier at the monent is a mix of the Nakmuay and Super Smash bros little mac". 05:03: "we will work on our next char".
05:27: "Nakmuay. Did you look into? I want a lot of his effects of slapping an enemy accross map and being able to rush
them down. Also. I feel our map is small."

Everything below is study only. No move, name, art or number is copied; each idea is rebuilt as our own move
(memory "originality").

## Sources
- **Nakmuay** - a YOMI Hustle Workshop mod (item 2979385119, since taken down; Ong-Bak inspired). Read from its Steam
  comment page, a 17-minute review ("This Mod Almost took the #1 MOST POPULAR Spot", subtitles), and frame sheets of
  five videos (a showcase, a combo, a touch of death, two full fights):
  `Standoff Workshop/references/yomi_mods/nakmuay/` (videos, `review.txt`, `sheets/`).
- **Little Mac** - SmashWiki (SSBU): the Power Meter and KO Uppercut, super armour on his smash attacks, Straight Lunge,
  Jolt Haymaker, Rising Uppercut, Slip Counter; his ground speed and poor air game.
- **Muay Thai fighters** - Fahkumram (Tekken: OneEsports, Dashfight, tekkendocs), Sagat (SF6 previews, the SRK wiki),
  Joe Higashi (Dream Cancel, StrategyWiki).
- **Boxers** - Steve Fox (Tekken peekaboo / flicker guides), Balrog (SFV guides: dash punches, the turn punch).
- **Rushdown in general** - PlayStation Compete's archetype articles, FrayTools' archetypes, Smashboards "zoning vs
  rushdown"; YOMI's Mutant and Robot (docs/yomi_chars.md) and the wiki's Glossary (Super Armor).

## What the study says
1. **A rushdown wins up close and loses far away.** Speed, pressure and damage on top of you; little at range.
   "Failing to get in is a death sentence."
2. **"Zone breakers"** - ways past projectiles: going under them, over them, through them (armour), or a reflector.
3. **Armour on the big hits** (Little Mac's smash attacks, Robot): one hit tanked, the move carries on. YOMI's wiki:
   "Super Armor only lets you tank 1 hit"; grabs and hitgrabs go straight through it.
4. **A gauge that builds to one huge punch** (Little Mac's Power Meter): filled by dealing and - faster - by taking
   damage; lost if he's knocked about.
5. **Muay Thai's tools:** the teep (the push kick that stops an approach), the round kick, elbows that cut, knees, the
   clinch (hold the head, knee, then dump), the catch.
6. **Nakmuay's look and feel:** big hits slap them across the stage; he runs them down at once and keeps the combo
   going (40-50 hit combos); a tall ring of air bursting out where the hit lands, a white wind cone behind them, floor
   cracks; a stomp shockwave that pops them up; super armour on a big move. Fighters small on a wide stage.
7. **The fair limits:** short reach, a weak air game (Little Mac's is the worst in Smash), big moves that are slow and
   punishable.

## How it translates to Hustle
- **Simultaneous turns make armour a read:** you armour through what you think they'll throw; a grab beats you.
- **The clinch is a string of turns:** each knee is a new pick, and each turn they're held they can Burst - the
  YOMI-native escape.
- **A fling sets up a chase:** the big hit frees him at once (a hit cancel), and the next pick is the Chase.
- **The K.O. Punch is visible:** his gauge is on his card and his gloves glow when it's full, so the enemy can read it
  and play around it - or knock him down to halve it.

## His kit
| | Moves |
|---|---|
| **Moving** | Walk (7.5, faster than hers), Dash (19), Back Step (short), **Bob & Weave** (ducks high hits, slips shots that aren't low), **Chase** (after a big hit: runs them down, stops on them), Dodge, low jumps, one air jump, no air dash |
| **Hands** | **Jab** (f2 - the fastest in the game) → **Cross** → **Hook** (a rekka string), **Body Blow** (long hitstun) |
| **Shins, elbows, knees** | **Leg Kick** (low), **Teep** (a fling), **Elbow** (point blank, it cuts), **Roundhouse** (Super Armor f3-11, a fling), **Quake Stomp** (a floor shockwave both ways - picks them up off the floor) |
| **The clinch** | **Clinch** (his grab - holds them) → **Clinch Knee** (up to three in a row) / **Clinch Elbow** (a fling) / **Dump** (thrown down behind him) |
| **Specials** | **Rising Uppercut** (invulnerable start with initiative), **Haymaker** (Super Armor, lunges by the Distance, a fling), **Flying Knee** (leaps in - breaks a guard, clears the Ripple), **Superman Punch** (a leaping overhead), **Catch** (catches a strike and dumps them - not shots) |
| **Grit** | His gauge: dealing damage fills it (0.12 a point), taking it fills it faster (0.4 a point - tanked on armour too). Full: **K.O. Punch** - f5, through a guard, 100 damage, floors them; 36 frames open if it misses. Floored, he loses half his Grit. |
| **Air** (weak) | Air Knee, Air Hook, Elbow Drop (an overhead straight down) |
| **Supers** | **Bull Rush** (1 bar - armour for three hits, through shots; a fling; 23 Oct: set like a bull, landing it the ram and a drive through), **Barrage** (2 bars - 23 Oct, rebuilt with Timmy: five hooks, right to the body, left to the head, a dash in after each, about a quarter of the stage; the high left cross pins them flat a moment and bounces them up about 1.5x his height), **Clinch Fury** (3 bars - a clinch that won't let go: three knees and an elbow; 23 Oct: to be dropped - "its kind of boring") |
| **Rushdown trait** | Point blank (70 px) his strikes do 10% more and stun 2 longer; a blocked one barely pushes the blocker off - he stays on them |

**His limits:** nothing at range (no projectile); a weak air game; his big swings are slow and punishable; armour takes
one hit and grabs go straight through it; knocked down, he loses half his Grit. 470 HP, weight 1.1.

## The look
- **Gloves** - his prop (as her fans are hers): big round boxing gloves in his colour with a white wrist band; a broader
  chest. He bounces on his toes in a high guard.
- **A fling** - a tall thin ring of air opening out the way they fly; momentum lines in his colour trailing behind the
  impact, back toward him (0.39.0 - 20 Oct 15:21 "Put them behind the impact to try and show the momentum of his
  punch"; they used to streak across the screen); cracks in the floor where they land; they slide a long way, sent off
  at YOMI's pace (0.37.0, Sim.LAUNCH_PACE).
- **Quake Stomp** - spikes and a curtain of debris thrown up over the strip its shockwave hits, 100 px either side of
  his foot, and a light shake (0.38.0 - 15:10 "The animation should only be in the are it effects"; YOMI's Robot ground
  pound the model). It was a screen-wide wall of spikes (0.34.0).
- **Rushing in** (Dash, Chase, Bull Rush...) - solid grey copies of him left behind, hanging a moment (0.34.0).
- **Big hits** (45+ damage after scaling: the Haymaker, the Roundhouse, the K.O. Punch, supers - about 1 hit in 8, 3 a
  match) - a giant white starburst behind the fighters and rings opening out wide; grabs and clashes get wide rings.
  All of these are sized by the SCREEN, not the world (Fx.band), so they fill it however far the camera has pulled
  back (14:09 "our attacks anf effects domt use the full width and height of the field").
- **Grit full** - his gloves glow orange with sparks rising.
- **Armour** - a hard metal glint and a clang under the hit. **Guard break** - the guard in pieces. (No words on the
  stage since 0.36.0 - 20 Oct 14:22 "Dont keep the words and damage numbers".)
- **Frames** (0.40.0 - 15:40 "we should change our frames to match YOMI's"): Jab 4 / 14 (YOMI's Punch), Cross, Hook
  and Elbow out on 6, Body Blow and Leg Kick 5 / 18, Teep 11 / 24, Air Knee 6 / 15, Rising Uppercut 4, Clinch (his
  grab) 3 - the table in docs/mechanics.md "Frame data = YOMI's".
- **His strikes** (0.45.0 - 20 Oct 17:50 "Lets keep going": his were the generic boxing poses next to her dance moves):
  23 full-body Muay Thai / boxing shapes from joint angles with his bone lengths kept (torso 33, head 12, upper arm 18,
  forearm 16, thigh 26, shin 24 - Poses.P "the Bruiser's strikes"). Each strike is a loaded wind-up held, a snap to the
  committed shape, held, then back to his guard: the hips and back heel turn into a punch, the other glove stays at his
  chin, kicks lean back to balance. Jab (a step in), Cross (the whole body turned in, the back leg straight), Hook (round
  at shoulder height, the elbow out), Body Blow (a level change), Leg Kick (the shin into their knee), Teep (the knee
  up, the foot driven out), Elbow (a rising lead elbow), Roundhouse (the shin at head height, leaning right back),
  Haymaker (wound right back, then a lunge at full stretch), Rising Uppercut (up from a deep crouch), Superman Punch (a
  hop, the back leg kicked out, the rear hand through), K.O. Punch (a deep coil, an overhand thrown down). The Air Hook
  and Clinch Elbow, the Barrage's punches and the Bull Rush's finish use them too. His moves are `"drawn"` like hers -
  shown as made, no extra coil. **Weak spot:** the Elbow is hard to read side on (his gloves cover it); two other shapes
  (a level elbow, a slashing one) read no better.

## The wider stage (05:27)
- 2800 wide by default (was 1600); a lobby can set 1200-4800 ("Big stage" 4400). One on one still starts 600 apart.
- The camera can pull out a little further (zoom 0.4) so six spread across it still fit.

## Universal rule fixed on the way
The wiki's Basics: "parrying can be done on anything that isn't a grab, including guardbreaks", and "missing a block
disables the ability to parry, but also makes all guardbreaks no longer break guard". So a Guard Break goes through a
Block unless it's parried on its frame, and someone already in blockstun just blocks it (and can't parry). This is the
"parry lock-out" from 01:32 - it's YOMI's universal rule, not one character's.

## Checks
- **Tests (52, 278 checks, all pass):** a new Bruiser section (26 checks) covers:
  - the roster, his systems and his bots' moves;
  - the Jab → Cross → Hook string, and the point-blank bonus;
  - Super Armor (one hit; Bull Rush three; grabs go through; a thrown fan tanked);
  - the clinch (held, three knees with no bar, the dump behind), Clinch Fury (5 hits, floored; nothing on a miss);
  - Grit (both ways, the K.O. Punch through a block, half lost when floored);
  - Bob & Weave, the Flying Knee's guard break and height, the Superman Punch overhead, the Catch;
  - a fling + Chase + the combo going on, Quake Stomp off the floor, the wider stage, the blockstun guard-break rule.
- **Hard bots, Dancer vs Bruiser:** first 13-3 to him (his air game and armoured swings were too strong), then 5-11
  after cutting them, then **10-14** over 24 matches after meeting in the middle.

## Open questions for Timmy
- **The fling's look** - the ring of air is a thin tall ellipse, not a big circle (22:57 "I dont love the massive white
  circle thing"). Keep it, or smaller?
- **Gloves** - his colour with a white band. Red boxing gloves whatever his colour?
- **Grit numbers** - about one K.O. Punch a match in bot play. More often, or rarer?
