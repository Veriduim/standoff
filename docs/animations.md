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
- Step 4, her own drawings (Umbra the inspiration): Fan Slash, Recall, Fouette Storm, Gale, Mirror, Mirror Strike,
  Stomp, Air Throw, Push Block - and her petals: spins shed them, slaps throw a cone, Recall swirls them, Windmill /
  Floor Slide / Grand Jete's landing kick them up; each Form its own
- Step 5, his own drawings (Nakmuay the inspiration): Clinch Elbow (a shove, then the elbow rising), Dump and Catch
  Dump (pulled down, twisted round, flung behind), Catch (guard, the scoop, guard), Air Hook, Elbow Drop (up, over, the
  dive), Bull Rush (a two-stride run, the skid), Barrage (rolling hooks, his own uppercut) - shown as drawn. Bull
  Rush's speed lines off his back and dust (Rhino's Charge), Elbow Drop slamming the floor; both elbows trace their
  arc from the elbow

- Specials and supers exaggerated (14:49 "special and supers should be exaggerated to hell!"): `Poses._hell`, his pick
  strength 2 - more lean, a wider stance, more spine, the striking limb stretched while it hits; limbs lost in the body
  found with Standoff Workshop/tools/limb_check.gd and fixed (the Flying Knee and the clinch knee redrawn)
- The Barrage (15:11-15:40): five hooks with a dash-in drawing between every two (the next arm cocked), right to the
  body / left to the head, the punching shoulder turned through; the high left cross cocked (elbow out to the left),
  the elbow up over his head, smashed down with the right arm hanging; the one hit pinned flat (`floor_splat`)
- Bull Rush (15:42-15:49): set like a bull, the back foot scraping; the ram, the drive through, a crouched guard

## No drawing of their own (stand, crouch, dash, jump, fall borrowed)
- Dash, Jump, Super Jump, Fast Fall, Back Step, Air Dash: their own since step 2
- Dancer: Flow Form
- Everyone: Block, Wait, Whiff Cancel, Get Up, Hold

## One drawing only
- None left (steps 4 and 5)

## Borrowing another move's drawings
- Dancer: Grab (the shared reach and throw), Encore (a mix of her moves - on purpose?)
- Bruiser: Clinch and Clinch Fury reach with the shared grab; Air Knee is the shared knee

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
