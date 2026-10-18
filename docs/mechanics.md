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

## Later
- **Predict the others:** pick what you think an enemy will do and the ghost plays against it.
- **Parry on a picked frame:** instead of the Early / Late windows.
- **Guard height:** high or low. The wrong one blocks worse (more chip and block advantage).
- **Pushblock:** no chip, pushes the attacker back.
- **Block advantage:** a blocked hit delays your next move by the frames shown.
- **Proration:** per-move starting scaling.
- **Initiative:** some moves gain invulnerability against someone not yet committed.
- **Burst Cancel:** an attacker spends the whole gauge to cancel into an offensive burst.
- **OTG, restands, ground bounces, wall splats.**
