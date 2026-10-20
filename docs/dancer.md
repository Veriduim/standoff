# The Dancer - who she is

Timmy, 18 Oct 23:59: "We need to decide what kind of fighter she is and limits. So she is clearly control and spacer so
I think we need to make up for that with the space we have normally and work that into her kit."

**20 Oct 15:28-16:17 - the rework:** a MELEE spacer now, YOMI's Cowboy the model (15:28 "YOMI is normally a very melee
focused game"): her fans are her blades, her strikes are dance moves (0.41.0: Fan Tap, Fouetté, Arabesque, Plié Cut,
Grand Battement, Sauté Kick, Tour en l'Air - each on its nearest YOMI move's frames), the zoning cut down to Fan Throw /
Air Fan, Recall and Fan Step (next: Port de Bras, Pirouette, Grand Jeté; then the melee supers). The notes below are
the zoner she was; they go as the rework lands.

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
- **Control (0.29.0 - 03:32 "rework dancer kit ... really fits the zoner/control space char"; the research and the
  reasons: docs/dancer_research.md):**
  - Fan Ward sends a fan out (8 ways, as far as the Distance says) to hang there 5 s as a trap (Recall pulls it home
    through whoever's between; Fan Step blinks to it; into the floor it sits low as a mine);
  - Fan Gust is wind - it shoves them off (no damage), blows their shots back and carries her fans on;
  - Fan Flick, right after landing a Fan Slash, flicks the fan out and knocks them back to her range;
  - Mirror also turns shots round in its window.
  - Cut as rushdown: Knee Dash, Flash Kick, One-Two / Spin Finish, Dive Kick, Air Spin, Hip Toss, Spin Throw, the Sway
    stance (in git at 0.28.0).
- **Sadness:** as for anyone (00:06-00:09: YOMI's universal rules stay faithful; its zoners, Cowboy and Wizard, live
  with it too). Her fan's edge rewards spacing instead.
- **Supers, a zoner's** (03:03 "Why are all the supers for Dancer melee supers when she is supposed to be a zoner
  char?" - 0.26.0): Fan Storm (1 bar: five spectral fans in a spread), Gale (1 bar: wind all round her that blows
  rushers off, untouchable as it starts), Cyclone (2 bars: a whirlwind sent slowly forward, hitting every 10 ticks,
  not stopped by other projectiles), Grand Finale (3 bars: eight fans falling from the sky across the stage in front).
  The spectral fans aren't her two.
- **Getting out:** Fan Gust, Silk Glide (low profile, passes under projectiles), Back Step, Dodge. (Snap Step went
  at 0.30.0 - a rushdown's step; her forward dash is 15, not 17: a zoner is slower going in.)
- **Tempo:** beats from landing, being blocked or dodging through a hit. Each beat adds damage and movement speed.
  At four she gets Encore - since 0.30.0 a finisher from range: three spectral fans in a burst, the last floors
  them (it was a four-kick rush).

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
`NO_FAN_CHIP` 1.5, `NO_FAN_BLOCK` 3, `FANS_MAX` 2, `TEMPO_DMG` 0.06, `TEMPO_MOVE` 0.08; Fan Ward `WARD_NEAR` 3 /
`WARD_FAR` 18 ticks out, `WARD_LIFE` 300; Fan Gust `GUST_PUSH` 9, `GUST_TICKS` 6, `GUST_FAN` 14, `WARD_DRIFT` 7; Mirror
`REFLECT` 1.2.

The trait is `"trait": "spacer"` on her stats, so a future character can be something else.
