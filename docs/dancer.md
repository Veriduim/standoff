# The Dancer - who she is

Timmy, 18 Oct 23:59: "We need to decide what kind of fighter she is and limits. So she is clearly control and spacer so
I think we need to make up for that with the space we have normally and work that into her kit."

20 Oct 15:28: "she is a bit to stiff ... YOMI is normally a very melee focused game"; 15:59 / 16:17 "All sounds good to
me" - the rework (0.41.0-0.43.0).

**Archetype:** a melee spacer, YOMI's Cowboy the model (his sword's long reach, the gun a side tool). Her fans are her
blades: she wins at mid range with long cuts that flow into each other, and every strike is a dance move. One ranged
tool (Fan Throw / Air Fan), one way of moving that's hers (Fan Step to a thrown fan). YOMI's own characters and the mods
are study only.

## Her moves (frames: out on / whole move - each on its nearest YOMI move's)
- **Basics:** Fan Tap 4 / 14 (the quick poke, the fan shut - YOMI's Punch); Fouetté 6 / 20 (a whipping kick at hip
  height); Plié Cut 7 / 22 (the low - a deep plié, the fan along the floor, knocks down); Arabesque 11 / 24 (her longest
  reach - up on one leg, one long line to the open fan); Grand Battement 11 / 30 (the overhead - a kick up, the chop
  down); Sauté Kick 5 / 22 (air, driving down); Tour en l'Air 6 / 18 (air, two cuts as she turns). Also Fan Slash,
  Stomp, Grab 3 / 16, Air Throw 3 / 16.
- **Specials:** Port de Bras 4 / 26 (the anti-air - fans swept up overhead, through a strike with initiative); Pirouette
  8 / 28 (steps in, two cuts); Grand Jeté 12 / 34 (a leap over low hits, clear of them by frame 7, landing on a cut);
  Fan Throw (8 ways) and Air Fan - boomerangs that hit going and coming back; Recall (her fans home - with a direction,
  flung that way first, `Sim.FAN_FLING` 16 ticks); Fan Step (a blink to a thrown fan); Mirror (her counter - turns a
  strike, and a shot round).
- **Supers:** Fouetté Storm (1 bar - five whipping kicks as she travels on, the last floors them); Gale (1 bar - wind
  all round her that blows rushers off, untouchable as it starts); Grand Finale (3 bars - a Pirouette in, three
  Fouettés, a Grand Jeté landing on a cut that floors them, and the Révérence - her bow).
- **Tempo** (her style): beats from landing, being blocked or dodging through a hit - each adds damage and movement
  speed; at four, **Encore** - a flurry of three cuts, the last floors them.
- **Cut in the rework:** Low Kick, Spin Kick, Ground Ripple, Fan Ward, Fan Gust, Fan Flick, Fan Storm's volley, the
  Cyclone, Encore's spectral fans, the projectile Grand Finale (all in git at 0.40.0). Earlier, as rushdown: Knee Dash,
  Flash Kick, One-Two / Spin Finish, Dive Kick, Air Spin, Hip Toss, Spin Throw, the Sway (git 0.28.0).

## How they're drawn
22 poses built from joint angles with her bone lengths kept (torso 34, head 12, upper arm 20, forearm 16, thigh 26, shin
26 - Poses.P, "the Dancer's dance moves"). Her moves are `"drawn"`: shown as made - no exaggeration and no extra coil -
with YOMI's held poses (a key held, a 2-frame snap to the next). `"fan_open"` sets how open her fans are (Fan Tap's
shut). Two-hit moves are `"no_cancel"` - the first hit landing doesn't end them.

## Strengths: the space in front of her
- **The fan's edge.** Her melee hits that land with the far end of their reach hit harder, which teaches spacing:
  damage x1.25, +4 hitstun, +3 safer on block, a gold glint, the preview says "at the fan's edge!". The edge is the
  outer 45% of the hitbox (`Sim.EDGE_AT` 0.55), on hitboxes 40 px wide or more - the Arabesque's is her longest.
- **Sadness:** as for anyone (YOMI's universal rules stay faithful). Her fan's edge rewards spacing instead.
- **Getting out:** Silk Glide (low profile, passes under projectiles), Back Step, Dodge, the Grand Jeté over a low.

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
`NO_FAN_CHIP` 1.5, `NO_FAN_BLOCK` 3, `FANS_MAX` 2, `TEMPO_DMG` 0.06, `TEMPO_MOVE` 0.08; Mirror `REFLECT` 1.2. Her
moves' frames, boxes and damage: scripts/sim/moves.gd (DANCER).

The trait is `"trait": "spacer"` on her stats, so a future character can be something else.
