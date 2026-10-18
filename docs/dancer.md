# The Dancer - who she is

Timmy, 18 Oct 23:59: "We need to decide what kind of fighter she is and limits. So she is clearly control and spacer so
I think we need to make up for that with the space we have normally and work that into her kit."

**Archetype:** control and spacing. She wins at mid range by holding the space in front of her. Her fans are her prop,
her reach and her zoning tool, like the YOMI mods whose prop carries the character. YOMI's own characters and the mods
are study only.

## Strengths: the space in front of her
- **The fan's edge.** Her melee hits that land with the far end of their reach hit harder, which teaches spacing:
  - damage x1.25 and +4 hitstun;
  - on block she's +3 safer;
  - a gold glint marks it;
  - the preview says "at the fan's edge!".
  The edge is the outer 45% of the hitbox (`Sim.EDGE_AT` 0.55), on hitboxes 40 px wide or more.
- **Zoning tools:**
  - Fan Throw (8 directions) and Air Fan are boomerangs that hit on the way out and back;
  - Ground Ripple runs along the floor (low, can't be parried);
  - Recall turns her fans home - or, with a direction on the pad, flings them that way first (`Sim.FAN_FLING` 16
    ticks, fast, hitting again) before they head home (like Cowboy's bullets taking DI);
  - Fan Step blinks her to a thrown fan.
- **Sadness:** as for anyone (00:06-00:09: YOMI's universal rules stay faithful; its zoners, Cowboy and Wizard, live
  with it too). Her fan's edge rewards spacing instead.
- **Getting out:** Silk Glide (low profile, passes under projectiles), Snap Step, Sway, Dodge.
- **Tempo:** beats from landing, being blocked or dodging through a hit. Each beat adds damage and movement speed.
  At four she gets Encore.

## Limits
- **Point blank she's weaker.** Hits with her body almost touching theirs (`CLOSE_PX` 40) do x0.8 damage, -3 hitstun,
  and leave her 3 worse on block. She wants space, not a brawl.
- **No fan, no guard.** With both fans out she blocks worse: chip x1.5 and blockstun +3. She also can't use Fan Throw,
  Air Fan or Fan Slash until a fan comes home or she catches one with Fan Step.
- **Two fans only** (`FANS_MAX`). She keeps falling while she throws an Air Fan, as in YOMI.
- **Light:** 450 HP and weight 0.85, so she flies further and dies sooner when she's caught.
- **Losing the beat:** getting hit drops all her Tempo, and beats fade when she isn't landing anything.

## Numbers to tune (Sim)
`EDGE_AT` 0.55, `EDGE_DMG` 1.25, `EDGE_STUN` 4, `EDGE_BLOCK` 3, `CLOSE_PX` 40, `CLOSE_DMG` 0.8, `CLOSE_STUN` 3,
`NO_FAN_CHIP` 1.5, `NO_FAN_BLOCK` 3, `FANS_MAX` 2, `TEMPO_DMG` 0.06, `TEMPO_MOVE` 0.08.

The trait is `"trait": "spacer"` on her stats, so a future character can be something else.
