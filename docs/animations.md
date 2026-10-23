# Every move's drawings - the checklist

Timmy, 23 Oct 13:25: "i relaised we need an animation basically for everything". YOMI (study only) draws every move,
shared ones included (jump, dash, landing, grabbed, wall slam...). This lists what ours still borrow or lack. A move's
drawings are its `pose` keys in `scripts/sim/moves.gd`; the drawings themselves are `Poses.P`. Review sheets come from
Standoff Workshop/tools (frames_sheet.gd draws a move's frames as the game poses them; "move!" = moving backward).

## Done 23 Oct
- Dodge (a dive / sitting back, then a tumbling ball), Air Jump (a spin), Jump backward (an arch with a back bend, then
  the ball) - both fighters
- Grabbed (held in the clinch or a throw), Wall splat - everyone
- Taunts: routines of 8-10 drawings (YOMI-long)
- Fan Step: a spin out with arms crossed high, catching the fan in the air, a plie; an after-image where she vanished
- Bruiser: hand wraps; Elbow C (a loose shoulder so the point clears his head)
- A bendable spine (1/4, 1/2, 3/4 down) and loose shoulders for any drawing

## No drawing of their own (stand, crouch, dash, jump, fall borrowed)
- Both: Dash, Jump, Super Jump, Fast Fall
- Dancer: Back Step, Air Dash, Flow Form
- Everyone: Block, Wait, Whiff Cancel, Get Up, Hold

## One drawing only
- Mirror, Push Block (Dancer); Elbow Drop, Catch (Bruiser)

## Borrowing another move's drawings
- Dancer: Fan Slash and Recall (Fan Throw's), Fouette Storm (Fouette's), Gale (the taunt's gather / spread), Mirror
  Strike (Arabesque's), Stomp (Grand Battement's chop), Grab and Air Throw (the same pair), Encore (a mix)
- Bruiser: Clinch Elbow (Elbow's), Air Hook (Hook's), Barrage and Bull Rush (his strikes), Dump and Catch Dump (a
  generic throw)

## Effects (the audit, 23 Oct 13:41 - Timmy: "our effects should be cool and snappy", YOMI + its char mods the
inspiration, not copied)
Every hit already gets a dark ink starburst, hitstop, shake and smear frames; a swing trail follows the striking limb;
her fan hits cut (crescents), the rest thump (a star); big hits (45+) a giant starburst; supers a flash; fast movers
after-images.
- Fixed 23 Oct: Sauté Kick, Stomp, Kip-Up, Air Knee, Flying Knee, Quake Stomp traced a hand (now the foot / knee -
  moves can name their "tip"); Clinch Fury (a grab) got no super flash; walking left after-images
- Step 2 done: YOMI's movement particles - round dots in their colour on take-off, air jump, dash, landing
- Nothing of their own beyond the generic hit: Dancer - Fan Tap, Fouette, Port de Bras, Pirouette, Saute Kick, Tour en
  l'Air, Stomp, Pop, Snap Kick, Windmill, Plie Cut, Grand Jete, Kip-Up, Mirror Strike; Bruiser - Jab, Cross, Hook,
  Body Blow, Leg Kick, Elbow, Clinch Knee, Dump, Air Knee, Air Hook, Rising Uppercut, Superman Punch
- Nothing at all: both Taunts, Wait, Hold, Get Up; Mirror and Catch until they trigger
- The three Forms all show the same pale ring
- Dead (nothing triggers them): gust / gusted / ward effects, the sfan / cyclone / ripple shot drawings, the super
  cut-in (`draw_cutin` is never called)

## Next (Timmy's "with the spine now existing a lot of our poses could use work")
1. Getting hit with the spine: a body hit doubling over, a head hit snapping back, the crumple
2. Her dance moves bending through the back (arabesque, bow, fouette, grand jete)
3. His bob and weave, clinch, kicks leaning back; both guards with a slight hunch
