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

## Next (0.5.0)
- **Free Cancel:** a "Free" switch with an attack. You're free as soon as the others are. 2 charges, refilled when anyone
  lands a melee hit; +1 to the attacker when their hit is blocked; costs meter when you're out.
- **Whiff Cancel:** costs 75% of the Burst gauge. It cuts a committed move when the others are free and you're not;
  2 frames, then attacks only for that turn.
- **Knockdown and getting up:** landing from certain hits knocks you down. You pick hold, get up or tech roll, and you
  get up by yourself after 20 frames.
- **Super meter in levels:** gained by hitting (the damage), getting hit (a third of it), whiffing, moving forward,
  parrying and taunting. All of it shrinks with combo scaling.
- **Round timer:** 3600 ticks; when time runs out, the higher HP share wins.
- **Sadness (anti-stall):** builds while running away. At full it stops meter gain, takes defensive options and makes
  hits do 1.5x.
- **Air options:** a limited number of air moves until you land, shown on the card.

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
