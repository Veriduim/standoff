# Mechanics: the YOMI Hustle wiki, and where Standoff is with each

Timmy, 18 Oct 2026:
- 18:42: "Review the ref material as it covers most of it"
- 18:44: "Use that page more. It seems near perfect for what we need mechanics wise"

The source is the community wiki's mechanics pages: Basics, Actionability, Blocking, Combo Mechanics, Glossary, HUD
and Rules. They were saved as text in `Standoff Workshop/references/yomi/wiki_text`, and they are study only. We take
the rules of play. The names, art, characters and code are not ours to take, and the numbers are ours to tune.

## Built (0.4.0)
| Mechanic | The wiki | Standoff |
|---|---|---|
| Hitstun | You can only DI or Burst | You can only lean (Hold + the pad) or Burst |
| Burst | From hitstun with a full gauge; frame-2 hit; can't be hit; no damage; launches the attacker; both back to neutral | `burst` (`Sim._burst`, Moves COMMON) |
| Burst gauge | "Slowly regenerate over time, and at an increased rate while being comboed"; full at the round start (the HUD in the screenshots) | Starts full; `BURST_FULL` 1500 ticks (25 s) to refill, x2 while reeling, +1 per 4 damage dealt. Timmy 19:02 "You can kind of burst a lot" - it was 600 ticks + 3 per damage taken, so 2-3 Bursts each in a 30 s match; now about 1 each (`scripts/dev/burst_stats.gd`) |
| Blocking a Burst | Blocked = safe, much less knockback; parried = it resets scaling and can be punished (Glossary) | Guard blocks it (a short push); Parry Early on its frame parries it (the burster is stuck) |
| Endless combos | Combos can last forever, but reusing a move in the same combo gives less hitstun | `REUSE_DECAY` 0.25 per reuse, floor 0.3 |
| DI | Shifts knockback; set before the hit; stronger as the combo grows | Lean: a direction picked on your reeling turn, `LEAN_PUSH` x (1 + 0.1 x combo) |
| Hit cancel | Most melee attacks free you when they land; some limit what you can do next | Attacks free you on a hit, except `no_cancel` ones (uppercut, flash kick); the move just landed can't be picked that turn |
| Interruptible moves | Movement, block and hustle make you actionable as soon as the opponent is | `interrupt` moves (walk, dash, back step, jumps, air dash, fast fall, guard, wait, taunt); pick again or Hold |
| Hold | Carry on with the move in progress | `hold` |
| Damage scaling | d x (0.8 x ((15 - c) / 15)^2 + 0.2), so about 0.9x per hit and 20% from the 15th | The same curve (`Sim._hurt`) |
| Counter hit | Hitting someone mid-attack does +10% | The same, with a red COUNTER |
| Launch | The 7th hit of a ground combo always launches | `LAUNCH_HIT` 7 |
| Wall bounce | Launched into a wall, bounce off with +3 hitstun, no limit | `WALL_BOUNCE` 0.6, `WALL_STUN` 3 |
| Turn clock | 30 s by default | 30 s; then your pick as it stands goes in |
| Frame advantage | The prediction shows plus / minus frames | "+N" under each enemy still tied up on your turn |
| Hitstop | Mostly cosmetic | The freeze on contact (Fx) |
| HUD | HP, BURST gauge, meter | HP (with the white chunk), meter, Burst gauge (bright when full) |

## Built (0.5.0 - Timmy 19:10: "Continue on with the other features. Same as before wiki for mechanics")
| Mechanic | The wiki | Standoff |
|---|---|---|
| Free Cancel | A "Free" switch on an attack: actionable as soon as the opponent is; 2 charges, refreshed when either is hit by a melee attack, +1 on block, +1 each on a clash; a bar when out; on by default; holding it makes it committed | The Free switch on the bar (on by default); `FC_MAX` 2; the same refills; a bar when out |
| Whiff Cancel | 75% of the Burst gauge; cuts a committed move when the opponent is actionable; 2 frames; melee attacks only that turn | The same (`WHIFF_COST`, `WHIFF_LOCK`), offered only with a free enemy within 300 px (six on a stage stop often) |
| Knockdown | Landing in hitstun from a knockdown move: get up, tech roll or hold; up by themselves after 20 frames; hits out of hold / tech roll continue the combo | Sweep, axe kick, flash kick, the grabs and the supers' last hits knock down; lying down is untouchable (no OTG moves yet); `DOWN_TICKS` 20 |
| Meter | 125 a bar; dealing damage, taking it (a third), whiffing (9), moving toward the opponent (v/4, at least 1 a frame), parrying (50), blocking (both a third), taunt (a bar); combo scaling and Sadness shrink it | `BAR` 125, 3 bars; damage x `METER_PER_DMG` 3 (our HP is about a third of YOMI's); the rest as the wiki. Supers: Flurry 1 bar, Cyclone 2 |
| Round | 3600 frames (default ruleset) | `ROUND_TICKS` 3600; the best share of HP left wins on time; the clock top right |
| Sadness | Builds over time, faster backing off; down moving in and on melee hits (below 0 after a combo); SAD! at 66%; SADNESS! at 100% for 120 frames: meter gone, no gain, no defensive options, 1.5x damage, damage over time | The same (`SAD_MAX` 900 ticks of standing about) |
| Air options | Shown under the HP bar; recharge on landing | `AIR_OPTIONS` 2 (air jump, air dash); dots on the card |
| Dash distance | Dash takes a distance 0-100; duration scales with it | Dash, jumps and air dash take a Distance (the slider); `dist` in Moves (Timmy 19:12) |
| Predictions | Click the opponent's moves to see what happens | Tap an opponent who's picking: pick their move; their ghost plays against yours (19:14) |
| Ready | Ghosts labelled when they're actionable | READY over your ghost once it's free again |

## Built (0.6.0 - Timmy 19:46 "as like for like as we can besides art", 19:48 "Continue working on that please")
| Mechanic | The wiki | Standoff |
|---|---|---|
| Block | Block high or low; the frame the hit lands picked = a parry (actionable at once); filled in when you click the opponent's move | Block (↑ high / ↓ low) with "Parry on frame" (the slider) - filled in from the preview when a hit's coming; Guard and Parry Early / Late are gone |
| Wrong height | Blocked worse: more chip, more block advantage | Double chip, +4 blockstun (`WRONG_HEIGHT`); low kick / sweep / stomp are low, the axe kick is high |
| Push Block | Both heights, no chip, a big push on the striker | Push Block (not interruptible, never parries) |
| Air block | Worse: +2 block advantage | +2 blockstun (`AIR_BLOCK`) |
| Block advantage | The prediction says how far ahead / behind | "(+N / -N)" on blocks in the info line |
| Guard Break | Beats Block | The rule is in; none of hers since the zoner rework (0.29.0 - the knee dash was cut) |
| Proration | A starter's proration adds to the combo count from the 2nd hit; negative = the 2nd hit unscaled | Jab +2, straight / low kick / air kick / air knee +1, sweep -1 |
| Air hitstun | +1 frame | The same |
| Combo pushback | Both pushed apart more as scaling grows | The hitter's pushed back a little more each hit (`COMBO_PUSH`) |
| Minimum damage | Some moves never do less | The supers' last hits (12) |
| Ground bounce | Once a combo | The axe kick |
| Wall splat | Slide down the wall; floored at the bottom, off after 30 frames; 3 a combo, faster each time | The side kick, Flurry's last hit |
| OTG | Hits the floored | A new Stomp (low) |
| Instant Cancel | A bar: full moveset 1 frame later | A bar: the move you just landed, again ("IC" on its icon) |
| Burst Cancel | The whole Burst gauge: an offensive burst, +24 on hit | Burst Cancel (full gauge, someone in a combo close by) |

## Built (0.7.0 - step 3, cooler moves; Timmy 20:05 "continue on please")
| Mechanic | The wiki (character pages) | Standoff |
|---|---|---|
| Projectiles | Thrown things with their own hitboxes; parried by blocking within 3 frames; some can't be parried; projectiles cancel each other | `Sim.shots`: Fan Throw, Air Fan (down-forward), Ground Ripple (low, can't be parried); a Block started 3 frames or less before parries a parryable one; two meeting clash |
| Stances | Moves that open their own moveset (Ninja's Back Sway -> Palm Strike) | The rule is in; the Sway stance was cut in 0.29.0 (a rushdown stance) |
| Follow-ups | Actions only available after a specific one | Fan Slash -> Fan Flick (back out to range; 0.29.0) |
| Hit-cancel limits | A landed hit can limit what you can do next | Uppercut / Rising Heel cancel only into jumps (`cancel_into`) - the launch-and-chase |
| Counter stance | (several characters' counters) | Mirror: struck in frames 3-24 it strikes back at once ("MIRROR!"); grabs beat it |
| Initiative | Moves get invulnerability, or a faster startup, when the opponent's not already committed | `init_invuln`: the uppercut and Rising Heel (frames 1-6), Silk Glide (2-8); `init_faster`: Side Kick and Fan Throw start 2 frames in (0.19.0) - when the nearest enemy was choosing too; the card says so |
| Restands | Landing in hitstun without a knockdown: 3 frames unable to act; a grounded hit in the 5 frames as they land puts them back in a ground combo (the 7th-hit launch count carries on) | `Sim.RESTAND_LAG` 3 / `RESTAND` 5 for anyone launched or hit in the air (`Fighter.launched`); a hit in the window shows RESTAND; no hit - the combo's over. Before 0.19.0 a landing kept them reeling, so air combos went on along the ground for free |
| Command grab / air grab | Grabs with their own rules; same air/ground state | Air Throw (air to air); her command grabs were cut in 0.29.0 |
| Supers | 1-3 bars | Flurry (1), Cyclone (2), Grand Finale (3 - a rush and a launch); the super's name splashed over them |

## Built (0.11.0-0.12.0 - Timmy 23:23 "better movement", 23:34 "moving over any more mechanics we miss")
| Mechanic | The wiki | Standoff |
|---|---|---|
| Momentum | Ninja's Boost and momentum carry into attacks; Beating Backdash | An attack started on the move slides on through its startup (`CARRY`), and its lunge never slows a faster slide |
| Attack distance | (dash distance) | Distance on the lunging attacks (Straight, Side Kick, Sweep, Silk Glide; Fan Ward's placement) |
| Ceiling | Rules: Ceiling Height 800 | Rule "ceiling", 900 by default (in the lobby rules); heads bump off it; a faint line shows it |
| Air options | Air jump / air dash, 2 a jump; air attacks keep falling | Air Fan no longer hangs - she keeps falling as she throws (23:34 "Air Fan spam!!!", 00:09 "We should fall"); two fans limit it |
| Land Cancel | Landing ends the move with a little landing lag | Air Kick, Air Knee, Air Throw, Air Fan |
| Low Profile | The hurtbox goes low; high hits pass over | Sweep, Silk Glide, Windmill (`low_profile`) |
| Undo | Single player only: undo a turn | ↶ Undo at the top right against bots (up to 40 turns back) |

## Later
- **Chess Timer**: built 0.17.0, dropped 0.17.1 (Timmy 01:24 "I think round and turn timers are better"). It's in git
  (commit 9c2fc68) if it's ever wanted.
- **Burst Cancel's** slower Burst refill for the rest of the combo.
- ~~**Super Armor**~~ (0.30.0, the Bruiser: one hit tanked, the damage taken, grabs go through - the Glossary) and
  ~~the **parry lock-out**~~ - it IS universal after all (the Basics page: "missing a block disables the ability to
  parry, but also makes all guardbreaks no longer break guard"; a guard break can be parried on its frame). 0.30.0:
  someone in blockstun blocks a guard break and can't parry; a Block parries a guard break on its frame.
- **Stage width** 2800 by default since 0.30.0 (05:27 "I feel our map is small"). **Spacing and the camera** since
  0.35.0 at YOMI's scale, from its own source (GitHub uzkbwza/hustle - study only): its fighters are 32 tall (hurtbox
  28 x 32), the lobby default puts them 250 apart (Start Distance 125 = each side of the middle) on a stage 1600 across
  (Stage Width 800 = half), they can never be more than 600 apart, and the camera is a fixed 640 x 360 that never zooms
  in. In fighter heights: 7.8 apart, a screen 20 wide, a stage 50 wide. Ours are ~106 tall: 1v1 starts 840 apart
  (Sim.START_1V1, was 600), and the camera never shows less than 2120 across (StageView.VIEW_MIN = 20 heights, was
  400 - it came in to ~9 heights in a 1v1). The stage stays 2800 (26 heights) - six fighters fill it.
- **Frame data** (20 Oct 15:34 "grab the frame data for the basic attacks from YOMI as I think our grab is 5 frames
  instead of the standard 3"): from YOMI's source (a hit box's start_tick is live on that frame of the move, counting
  the first as 1 - as ours does). First live frame / frames live / whole move (IASA = can act early from):

  | YOMI | | Standoff | |
  |---|---|---|---|
  | Throw (everyone, ground and air) | 3 / 3 / 16 | Dancer Grab (0.39.1; was 5 / 2 / 22) | 3 / 3 / 16 |
  | Jump throw | 6 / 3 / 15 | Bruiser Clinch (0.39.1; was 4) | 3 / 3 / 24 |
  | Ninja Punch | 4 / 2 / 14 | Dancer Air Throw | 3 / 4 / 20 |
  | Robot Punch | 4 / 2 / 15 | Dancer Jab | 3 / 2 / 13 |
  | Ninja Kick | 5 / 3 / 18 | Bruiser Jab | 2 / 2 / 11 |
  | Mutant Slash | 6 / 4 / 18 | Bruiser Cross | 3 / 3 / 16 |
  | Cowboy Horiz. Slash | 6 / 2 (+8 / 2) / 20, IASA 15 | Dancer Low Kick | 5 / 2 / 16 |
  | Ninja Sweep | 7 / 2 / 22 | Bruiser Hook, Body Blow, Leg Kick | 5 / 3 / 18-22 |
  | Wizard Kick | 7 / 13 / 30, IASA 24 | Dancer Straight | 7 / 3 / 20 |
  | Cowboy Upward Swipe | 8 / 4 / 32, IASA 22 | Dancer Side Kick | 8 / 3 / 24 |
  | Mutant Sweep | 10 / 3 / 25 | Dancer Sweep | 9 / 3 / 28 |
  | Cowboy Vert. Slash, Stinger | 11 / 2 / 30, IASA 18-20 | Bruiser Teep | 6 / 3 / 22 |
  | Mutant Kick, Robot Side Kick | 11 / 3 / 24 | Dancer Axe Kick | 15 / 3 / 32 |

  YOMI's quickest strike is out on frame 4; our jabs on 3 (her) and 2 (him). A strike live on the same frame as a
  grab beats it (ours, as YOMI's).
- **Launch pace** since 0.37.0 (YOMI's knockback is ~4x ours for the fighters' size, its gravity 2-3x - its source):
  hits send them twice as fast sideways, easing off in the air to about the old distance (Sim.LAUNCH_PACE / DRAG /
  FLING_DRAG), up and down x1.4 with gravity x1.4 while reeling (LAUNCH_LIFT - the same air time, higher), and a
  reeling fighter on the ground stops twice as quickly. Bot matches and combos about as long as before.
- Step 3 - much cooler moves (projectiles, a stance with its own moves, rekka chains, a command grab, a launcher route,
  a counter stance, supers with their own animation); ~~step 4 - effects per move~~ (0.20.0: a hit looks like what
  made it - `StageView._hit_style`: her fans cut (Fx "slash"), kicks and knees thump (the spark on the dark starburst),
  the ground wave throws up dust, grabs close a dark sphere; a super gets a cut-in band, `Fx.draw_cutin`); ~~sound~~
  (0.15.0); ~~replays~~ (0.13.0); ~~lobby rules~~ (0.8.0). Still open from step 4: YOMI's customisation (outline
  colour, a particle trail).
