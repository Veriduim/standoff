class_name Moves
extends RefCounted
## Every character's moves as data (the sim reads these; nothing here runs). An original roster - Your Only Move Is
## HUSTLE is the reference for how a simultaneous-turn fighter plays, nothing more (Timmy, 18 Oct 2026: our own game).
##
## Units: world pixels and ticks (60 a second). A fighter's origin is between their feet; y grows DOWN (the ground is
## y = 0, up is negative). Box and motion numbers are relative to the way the fighter faces (+x = in front).
##
## The one thing a player picks with a move is a DIRECTION (Timmy 17:37: "I dont like target ... Just have the
## direction functionality"): ← / → is the way they face and swing; some moves take more.
##   aim       "facing" ← or → | "dir8" any of 8 | "up" ↖ ↑ ↗ | "down" ↙ ↓ ↘ | "none" (no direction - guard, wait)
## A move:
##   name      shown in the menu      tab   "move" | "attack" | "air" | "grab" | "defend" | "super" (the menu's tabs)
##   kind      "move" | "attack" | "grab" | "guard" | "wait" | "super" | "burst" | "hold" | "whiff" | "getup"
##   (a hit) height "high" (an overhead - block it high) | "low" (block it low) | mid by default (either works);
##   guardbreak true = goes straight through a Block (the wiki's Guard Break)
##   interrupt true = gives way when anyone else can act (they pick again, or Hold)
##   no_cancel true = landing it doesn't free them at once (most attacks do - a hit cancel)
##   dist      [shortest frames, longest frames, slowest speed share] - the move takes a distance 0-100 (dashes, jumps)
##   air_option true = uses one of the air options (Sim.AIR_OPTIONS) until they land
##   knockdown (on a hit) floors them when they land
##   spawn     a projectile thrown on frame `at`: {kind, speed, from: [x, y], box: [w, h], dmg, stun, kb, block, chip,
##             life, height, parry: false = can't be parried, grav, ward: true = a fan that stops where the Distance
##             says and hangs there (Fan Ward)}
##   gust      [from, to, box] wind in front on those frames: enemies shoved away, their shots blown back, her fans
##             carried on (Fan Gust - no damage)
##   reflect   true = a counter stance that also turns shots round in its window (Mirror)
##   slip      [from, to] shots that aren't low pass by on these frames (Bob & Weave)
##   grit      true = needs a full Grit gauge and spends it (the Bruiser's K.O. Punch)
##   repeat    N = can follow itself N times in a row without an Instant Cancel (the clinch knee)
##   stop_near N = a run that ends the moment an enemy's within N px in front (Chase)
##   (on a hit) fling true = sent sliding / flying a long way (Sim.FLING_*) - a ring of air and cracks on screen
##   (on a hit) hold true = keeps them right in front, no knockback (the Clinch); behind true = puts them behind first
##             (a dump - its knockback carries them on); strike true = in a grab move, a
##             strike on the one it grabbed (Clinch Fury's knees)
##   note      a few words for the move's card (what the frame data can't say)
##   enter     a stance move: puts them in that stance (its moves - "stance": that name - are open while it runs)
##   after     [move ids] - a follow-up: there only right after landing one of those
##   cancel_into [move ids] - landing this only frees them into these (the wiki's hit-cancel limits)
##   init_invuln [from, to] - invulnerable on these frames too, with initiative (the nearest enemy was choosing too)
##   init_faster N - with initiative it starts N frames in: a faster startup (the wiki: "some moves have reduced startup")
##   window / counter_hit / counter_move - a counter stance: struck in the window, counter_hit lands on the striker
##   air_grab  true = a grab that takes them out of the air; hidden true = never in the menu (a counter's follow-up)
##   proration the combo scaling a combo starting with this move starts at (the wiki: +2 = starts 2 hits in)
##   (on a hit) min_dmg - never less than this, scaling or not; bounce - off the ground once a combo; splat - stuck to
##   the wall (3 a combo); otg - hits someone lying down (picks them up into the combo)
##   frames    how long it lasts                    where   "ground" | "air" | "both" - where it can be started
##   motion    [[from, to, vx, vy], ...] velocity on those frames; a number is relative to the facing, ["px", k] /
##             ["py", k] = the picked direction's x / y times k (world - already left or right), ["pyd", k] = its
##             downward part (at least a little) times k
##   hits      [{from, to, box: [x, y, w, h], dmg, stun, kb: [x, y], block, chip, group}] - one hit per group per
##             target; a grab's entry is the throw (a negative kb x throws them behind you)
##   armor     [from, to] Super Armor: a strike or a shot in this window hurts but doesn't stop the move - one hit
##             (armor_hits: more); grabs still take them
##   invuln    [from, to] nothing touches them (strikes and grabs pass through)
##   window    [from, to] a parry's frames: a strike landing then is stopped and its striker stunned
##   land_ends true = ends on touching the ground (`landing` frames of lag follow)
##   cost      meter it needs          meter_gain   meter given when it finishes (a taunt)
##   float     no gravity while it runs (air dash)
##   pose      [[frame, pose name], ...] for the stick figure (scripts/ui/poses.gd); eased into the next entry
##   icon      the pose the menu icon shows (default: the pose at the first hit, else the move's first)

const COMMON := {
	# ---- defence the YOMI way (the wiki's Blocking page): Block high (↑) or low (↓), with a frame - a hit landing on
	# exactly that frame of the Block (at the right height) is parried: they're free at once, the striker carries on
	# into their recovery. Any other frame is a block; the wrong height blocks worse. Push Block takes both heights,
	# no chip, and shoves the striker away - but never parries.
	"block": {"name": "Block", "tab": "defend", "kind": "guard", "interrupt": true, "frames": 20, "where": "both",
		"aim": "height", "parry_frame": true, "pose": [[0, "guard"]], "icon": "guard"},
	"pushblock": {"name": "Push Block", "tab": "defend", "kind": "guard", "push": true, "frames": 22, "where": "both",
		"aim": "none", "pose": [[0, "parry"]], "icon": "parry"},
	"wait": {"name": "Wait", "tab": "move", "kind": "wait", "interrupt": true, "frames": 10, "where": "both", "aim": "none",
		"pose": [[0, "idle"]]},
	# ---- only while reeling with a full Burst gauge (Timmy 18:37: "Burst is the move we do to get out of stun lock")
	"burst": {"name": "Burst", "tab": "defend", "kind": "burst", "frames": 26, "where": "both", "aim": "none",
		"float": true, "invuln": [0, 16],
		"hits": [{"from": 2, "to": 5, "box": [-110, -150, 220, 170], "dmg": 0, "stun": 22, "kb": [13.0, -8.0],
			"block": 14, "chip": 0, "group": 0, "away": true}],
		"pose": [[0, "crouch"], [2, "burst"], [18, "fall"]], "icon": "burst"},
	# ---- Hold: carry on with the move running (an interruptible one), or - reeling - ride it out, leaning with the pad
	# ---- Whiff Cancel (stuck in a committed move, 3/4 of the Burst gauge) and getting up off the floor
	"whiff": {"name": "Whiff Cancel", "tab": "super", "kind": "whiff", "frames": 2, "where": "both", "aim": "none",
		"pose": [[0, "crouch"]], "icon": "crouch"},
	"getup": {"name": "Get Up", "tab": "defend", "kind": "getup", "frames": 12, "where": "both", "aim": "none",
		"invuln": [0, 10], "pose": [[0, "down"], [4, "crouch"], [10, "idle"]], "icon": "crouch"},
	"techroll": {"name": "Tech Roll", "tab": "defend", "kind": "getup", "frames": 20, "where": "both", "aim": "facing",
		"invuln": [0, 13], "motion": [[2, 15, 10.0, 0.0]], "pose": [[0, "roll"], [16, "crouch"]], "icon": "roll"},
	# ---- Burst Cancel (the attacker's: the whole Burst gauge, mid-combo - +lots, the combo goes on)
	"burstcancel": {"name": "Burst Cancel", "tab": "super", "kind": "burst", "frames": 18, "where": "both",
		"aim": "none", "float": true, "invuln": [0, 8],
		"hits": [{"from": 1, "to": 3, "box": [-90, -140, 180, 150], "dmg": 0, "stun": 40, "kb": [3.0, -4.0], "block": 10,
			"chip": 0, "group": 0, "away": true}],
		"pose": [[0, "burst"], [12, "idle"]], "icon": "burst"},
	"hold": {"name": "Hold", "tab": "move", "kind": "hold", "frames": 1, "where": "both", "aim": "lean",
		"pose": [[0, "guard"]], "icon": "guard"},
}

## The Dancer - the full kit (17:37: "one char that has as many moves as what a YOMIH char would have and see how we
## get that to fit with icons"): light, quick on her feet, a zoner. 19 Oct 03:32 "rework dancer kit. Make sure she really
## fits the zoner/control space char" (docs/dancer_research.md): the rushdown moves went (Knee Dash, Flash Kick, the
## One-Two chain, Dive Kick, Air Spin, the command grabs, the Sway stance - all in git before 0.29.0); in came a fan hung
## as a trap (Fan Ward), wind that moves fighters and shots (Fan Gust), Fan Slash's follow-up (Fan Flick) and a Mirror
## that turns shots round.
const DANCER := {
	"stats": {"name": "Dancer", "hp": 450, "weight": 0.85, "width": 34, "height": 104, "trait": "spacer",
		"xf": ["fans", "tempo", "forms"]},
	"moves": {
		# ---- moving
		"walk": {"name": "Walk", "tab": "move", "kind": "move", "interrupt": true, "frames": 16, "where": "ground", "aim": "facing",
			"motion": [[0, 13, 6.5, 0.0]], "pose": [[0, "walk1"], [5, "walk2"], [10, "walk1"], [14, "idle"]]},
		"dash": {"name": "Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground", "aim": "facing",
			"motion": [[1, 30, 15.0, 0.0]], "dist": [10, 20, 0.3], "pose": [[0, "dash_off"], [3, "dash"], [8, "dash_2"], [12, "idle"]]},   # (17 -> 15 (05:03):
		# a zoner is slower going in - her Back Step stays as quick)
		"backstep": {"name": "Back Step", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "ground",
			"aim": "facing", "motion": [[1, 10, -11.0, 0.0]], "invuln": [1, 6],
			"pose": [[0, "crouch"], [2, "backstep_hop"], [9, "fs_land"], [12, "idle"]], "icon": "backstep_hop"},
		"roll": {"name": "Dodge", "tab": "defend", "floor": true, "kind": "move", "frames": 22, "where": "ground", "aim": "facing",
			"motion": [[2, 17, 12.0, 0.0]], "invuln": [2, 14], "pose": [[0, "crouch"], [2, "dive"], [5, "tuck@90g"], [9, "tuck@180g"], [13, "tuck@270g"], [17, "crouch"]],
			"pose_back": [[0, "crouch"], [2, "sitback"], [5, "tuck@-90g"], [9, "tuck@-180g"], [13, "tuck@-270g"], [17, "crouch"]],
			"icon": "roll"},
		"jump": {"name": "Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "ground", "aim": "up",
			"dist": [6, 6, 0.72], "motion": [[1, 1, ["px", 8.5], -16.0]], "pose": [[0, "crouch"], [1, "jump_off"], [4, "jump"]], "icon": "jump",
			"pose_back": [[0, "crouch"], [1, "arch"], [3, "arch@-75"], [5, "tuck@-220"]]},
		"superjump": {"name": "Super Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground",
			"aim": "up", "motion": [[5, 5, ["px", 9.5], -21.5]], "pose": [[0, "crouch_deep"], [5, "jump_off"], [9, "jump"]], "icon": "jump"},
		"airdash": {"name": "Air Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "air", "aim": "dir8",
			"float": true, "air_option": true, "dist": [8, 16, 0.4], "motion": [[0, 13, ["px", 14.0], ["py", 14.0]]], "pose": [[0, "airdash"]], "icon": "airdash"},
		"airjump": {"name": "Air Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air",
			"aim": "up", "air_option": true, "dist": [6, 6, 0.65], "motion": [[1, 1, ["px", 7.5], -14.0]],
			"pose": [[0, "tuck@30"], [1, "tuck@120"], [3, "tuck@210"], [5, "tuck@300"]], "icon": "jump",
			"pose_back": [[0, "arch"], [2, "arch@-80"], [4, "tuck@-220"]]},
		"fastfall": {"name": "Fast Fall", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air", "aim": "none",
			"motion": [[0, 0, 0.0, 18.0]], "pose": [[0, "fastfall"]], "icon": "fastfall"},
		# ---- on the ground
		# ---- her dance moves (20 Oct 16:17 "All sounds good to me": a melee spacer - YOMI's Cowboy the model, her fans
		# her blades; each move's frames its nearest YOMI move's; "drawn": posed at full stretch, no exaggeration)
		# (the quick poke: the shut fan snapped out)
		"jab": {"name": "Fan Tap", "tab": "attack", "kind": "attack", "proration": 2, "frames": 14, "where": "ground",
			"aim": "facing", "motion": [[1, 5, 3.5, 0.0]], "drawn": true, "fan_open": 0.12,
			"hits": [{"from": 4, "to": 5, "box": [8, -84, 56, 18], "dmg": 18, "stun": 12, "kb": [2.0, 0.0],
				"block": 6, "chip": 1, "group": 0}],
			"pose": [[0, "tap_wind"], [4, "tap_hit"], [9, "idle"]], "icon": "tap_hit"},
		# (a whipping kick at hip height)
		"straight": {"name": "Fouetté", "tab": "attack", "kind": "attack", "proration": 1, "frames": 20, "where": "ground",
			"aim": "facing", "motion": [[2, 7, 5.0, 0.0]], "dist": [20, 20, 0.0], "drawn": true,
			"hits": [{"from": 6, "to": 8, "box": [10, -72, 66, 30], "dmg": 32, "stun": 16, "kb": [5.0, -1.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "fou_chamber"], [6, "fou_kick"], [13, "idle"]], "icon": "fou_kick"},
		# (her longest reach: up on one leg, one long line out to the open fan)
		"sidekick": {"name": "Arabesque", "tab": "attack", "kind": "attack", "frames": 24, "where": "ground", "init_faster": 2,
			"aim": "facing", "motion": [[3, 12, 6.0, 0.0]], "dist": [24, 24, 0.0], "drawn": true,
			"hits": [{"from": 11, "to": 13, "box": [14, -98, 88, 28], "dmg": 40, "stun": 18, "kb": [9.0, -2.0],
				"block": 12, "chip": 3, "group": 0, "splat": true}],
			"pose": [[0, "arab_wind"], [11, "arab_hit"], [18, "idle"]], "icon": "arab_hit"},
		# (Port de Bras - the anti-air: fans crossed low, then swept up over her head, up on her toes; YOMI's Uppercut,
		# out on 4, slipping through with initiative)
		"uppercut": {"name": "Port de Bras", "tab": "special", "kind": "attack", "init_invuln": [1, 4],
			"cancel_into": ["jump", "superjump"], "frames": 26, "where": "ground", "aim": "facing",
			"motion": [[2, 6, 3.0, 0.0]], "drawn": true,
			"hits": [{"from": 4, "to": 7, "box": [-8, -150, 62, 100], "dmg": 38, "stun": 26, "kb": [1.5, -10.5],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "pdb_wind"], [4, "pdb_hit"], [15, "idle"]], "icon": "pdb_hit"},
		# (Pirouette - a spinning double cut, stepping in: gathered in, a turn on one foot, then flung wide - her way
		# back in after holding the space)
		"pirouette": {"name": "Pirouette", "tab": "special", "kind": "attack", "proration": 1, "frames": 28,
			"where": "ground", "aim": "facing", "motion": [[2, 12, 6.5, 0.0]], "drawn": true, "no_cancel": true,
			"hits": [{"from": 8, "to": 9, "box": [-34, -100, 96, 64], "dmg": 16, "stun": 14, "kb": [3.0, -1.0],
				"block": 8, "chip": 1, "group": 0},
				{"from": 12, "to": 13, "box": [-10, -104, 102, 44], "dmg": 22, "stun": 18, "kb": [6.0, -3.0],
				"block": 10, "chip": 2, "group": 1}],
			"pose": [[0, "pir_prep"], [8, "pir_spin"], [12, "pir_cut"], [20, "idle"]], "icon": "pir_cut"},
		# (the low: down into a deep plié, the fan swept along the floor - knocks down)
		"sweep": {"name": "Plié Cut", "tab": "attack", "floor": true, "kind": "attack", "proration": -1, "frames": 22,
			"where": "ground", "aim": "facing", "motion": [[2, 9, 6.0, 0.0]], "dist": [28, 28, 0.0], "low_profile": [2, 15],
			"drawn": true,
			"hits": [{"from": 7, "to": 8, "box": [10, -22, 84, 22], "dmg": 30, "stun": 34, "kb": [3.0, -3.0],
				"block": 10, "chip": 2, "group": 0, "height": "low", "knockdown": true}],
			"pose": [[0, "plie_wind"], [7, "plie_cut"], [14, "plie_cut"], [19, "idle"]], "icon": "plie_cut"},
		# (the overhead: a kick up past her head, then the leg and the fan chop down together)
		"axekick": {"name": "Grand Battement", "tab": "attack", "kind": "attack", "frames": 30, "where": "ground",
			"aim": "facing", "motion": [[1, 7, 4.0, 0.0]], "drawn": true,
			"hits": [{"from": 11, "to": 12, "box": [10, -110, 56, 90], "dmg": 60, "stun": 22, "kb": [4.0, 4.0],
				"block": 14, "chip": 5, "group": 0, "bounce": true, "height": "high", "knockdown": true}],
			"pose": [[0, "tap_wind"], [6, "bat_kick"], [11, "bat_chop"], [20, "idle"]], "icon": "bat_kick"},
		# ---- in the air
		# (the air attack: one leg driven down and forward)
		"airkick": {"name": "Sauté Kick", "tab": "attack", "kind": "attack", "proration": 1, "frames": 22, "where": "air",
			"aim": "facing", "land_ends": true, "landing": 4, "drawn": true,
			"hits": [{"from": 5, "to": 11, "box": [6, -58, 60, 32], "dmg": 24, "stun": 14, "kb": [4.0, -1.0],
				"block": 8, "chip": 1, "group": 0}],
			"pose": [[0, "fall"], [5, "saute_kick"], [15, "fall"]], "icon": "saute_kick"},
		# (an air spin: two cuts as she turns)
		"airknee": {"name": "Tour en l'Air", "tab": "attack", "kind": "attack", "proration": 1, "frames": 18, "where": "air",
			"aim": "facing", "land_ends": true, "landing": 4, "drawn": true, "no_cancel": true,
			"hits": [{"from": 6, "to": 7, "box": [-40, -100, 100, 44], "dmg": 14, "stun": 12, "kb": [2.0, -2.0],
				"block": 6, "chip": 1, "group": 0},
				{"from": 10, "to": 11, "box": [-40, -100, 100, 44], "dmg": 16, "stun": 16, "kb": [5.0, -4.0],
				"block": 8, "chip": 2, "group": 1}],
			"pose": [[0, "tour_wrap"], [6, "tour_cut"], [8, "tour_wrap"], [10, "tour_cut"], [14, "fall"]], "icon": "tour_cut"},
		# ---- specials: projectiles, a counter
		"fan": {"name": "Fan Throw", "tab": "special", "kind": "special", "fans": 1, "frames": 24, "where": "ground",
			"init_faster": 2,
			"aim": "dir8",
			"spawn": {"at": 8, "kind": "fan", "speed": 11.0, "from": [30, -74], "box": [26, 20], "dmg": 20, "stun": 14,
				"kb": [4.0, -2.0], "block": 8, "chip": 2, "life": 70},
			"pose": [[0, "throw_wind"], [8, "throw_out"], [17, "idle"]], "icon": "throw_out"},
		"airfan": {"name": "Air Fan", "tab": "special", "kind": "special", "fans": 1, "frames": 20, "where": "air",
			"aim": "down", "land_ends": true, "landing": 4,   # (she keeps falling as she throws - YOMI's way; the two
			# fans are its limit - 23:34 "Air Fan spam!!!", 00:09 "We should fall")
			"spawn": {"at": 6, "kind": "fan", "speed": 11.0, "from": [24, -60], "box": [26, 20], "dmg": 18, "stun": 14,
				"kb": [3.0, 2.0], "block": 8, "chip": 2, "life": 50},
			"pose": [[0, "throw_wind"], [6, "throw_out"], [14, "fall"]], "icon": "throw_out"},
		"mirror": {"name": "Mirror", "tab": "special", "kind": "counter", "frames": 34, "where": "ground", "aim": "none",
			"window": [3, 24], "counter_move": "mirrorstrike", "reflect": true,
			"note": "catches a strike and kicks back; turns shots round",
			"counter_hit": {"dmg": 42, "stun": 30, "kb": [6.0, -11.0], "group": 0},
			"pose": [[0, "mirror"]], "icon": "mirror"},
		"mirrorstrike": {"name": "Mirror Strike", "tab": "special", "kind": "attack", "hidden": true, "frames": 20,
			"where": "both", "aim": "none", "invuln": [0, 12], "pose": [[0, "side_kick"], [12, "idle"]]},
		"stomp": {"name": "Stomp", "tab": "attack", "kind": "attack", "frames": 22, "where": "ground", "aim": "facing", "motion": [[2, 8, 5.0, 0.0]],
			"hits": [{"from": 8, "to": 10, "box": [8, -26, 54, 28], "dmg": 26, "stun": 18, "kb": [2.0, -7.0], "block": 8,
				"chip": 2, "group": 0, "height": "low", "otg": true}],
			"pose": [[0, "kick_wind"], [8, "axe_down"], [15, "idle"]], "icon": "axe_down"},
		"airthrow": {"name": "Air Throw", "tab": "attack", "kind": "grab", "air_grab": true, "frames": 16, "where": "air",
			"land_ends": true, "landing": 6,
			"aim": "facing",
			"hits": [{"from": 3, "to": 5, "box": [4, -100, 50, 80], "dmg": 50, "stun": 26, "kb": [-6.0, 9.0],
				"group": 0, "knockdown": true}],
			"pose": [[0, "grab_reach"], [5, "throw"], [11, "fall"]], "icon": "grab_reach"},
		# ---- grabs
		# (20 Oct 15:34 "I think our grab is 5 frames instead of the standard 3": YOMI's own Throw, from its source, is out
		# frames 3-5 of 16 - so is ours now; it was 5-6 of 22)
		"grab": {"name": "Grab", "tab": "attack", "kind": "grab", "frames": 16, "where": "ground", "aim": "facing", "motion": [[1, 4, 5.0, 0.0]],
			"hits": [{"from": 3, "to": 5, "box": [6, -88, 38, 60], "dmg": 50, "stun": 26, "kb": [10.0, -5.0],
				"group": 0, "knockdown": true}],
			"pose": [[0, "grab_reach"], [5, "throw"], [11, "idle"]], "icon": "grab_reach"},
		# ---- show-off
		"taunt": {"name": "Taunt", "tab": "defend", "kind": "wait", "interrupt": true, "frames": 50, "where": "ground", "aim": "facing",
			"meter_gain": 125, "pose": [[0, "gather"], [5, "fan_spread"], [11, "twirl_a"], [15, "twirl_b"], [19, "twirl_a"],
				[23, "pir_spin"], [29, "fan_up"], [36, "bow"], [44, "taunt"]], "icon": "taunt"},   # (23 Oct: a routine, YOMI-long - it was one pose)
		# (her supers, a melee spacer's - 20 Oct 16:17: the dance itself, her fans the blades. Fouetté Storm - 1 bar: five
		# whipping kicks as she travels on, the last floors them)
		"fanstorm": {"name": "Fouetté Storm", "tab": "super", "kind": "super", "frames": 46, "where": "ground",
			"aim": "facing", "cost": 125, "invuln": [0, 4], "no_cancel": true, "drawn": true,
			"motion": [[4, 34, 5.0, 0.0]], "cue": {"at": 6, "type": "sweep"},
			"hits": [{"from": 8, "to": 9, "box": [-16, -96, 92, 56], "dmg": 14, "stun": 14, "kb": [1.5, 0.0], "block": 8, "chip": 1, "group": 0},
				{"from": 14, "to": 15, "box": [-16, -96, 92, 56], "dmg": 14, "stun": 14, "kb": [1.5, 0.0], "block": 8, "chip": 1, "group": 1},
				{"from": 20, "to": 21, "box": [-16, -96, 92, 56], "dmg": 14, "stun": 14, "kb": [1.5, 0.0], "block": 8, "chip": 1, "group": 2},
				{"from": 26, "to": 27, "box": [-16, -96, 92, 56], "dmg": 14, "stun": 14, "kb": [1.5, 0.0], "block": 8, "chip": 1, "group": 3},
				{"from": 32, "to": 33, "box": [-16, -96, 92, 56], "dmg": 28, "stun": 26, "kb": [7.0, -8.0], "block": 9, "chip": 2, "group": 4, "knockdown": true}],
			"pose": [[0, "fou_chamber"], [8, "fou_kick"], [11, "fou_chamber"], [14, "fou_kick"], [17, "fou_chamber"],
				[20, "fou_kick"], [23, "fou_chamber"], [26, "fou_kick"], [29, "fou_chamber"], [32, "fou_kick"], [40, "idle"]],
			"icon": "fou_kick"},
		"gale": {"name": "Gale", "tab": "super", "kind": "super", "frames": 30, "where": "both", "aim": "none", "cost": 125,
			"invuln": [0, 9],
			"hits": [{"from": 6, "to": 9, "box": [-110, -150, 220, 160], "dmg": 30, "stun": 24, "kb": [10.0, -6.0],
				"block": 10, "chip": 4, "group": 0, "away": true}],
			"cue": [{"at": 6, "type": "gust"}, {"at": 6, "type": "sweep_up"}, {"at": 6, "type": "galering"}],
			"pose": [[0, "gather"], [5, "fan_spread"], [17, "fan_spread"], [24, "idle"]], "icon": "fan_spread"},
		# (the Grand Finale - 3 bars: a Pirouette in, three Fouettés, a Grand Jeté landing on a cut that floors them, and
		# the Révérence - her bow)
		"finale": {"name": "Grand Finale", "tab": "super", "kind": "super", "frames": 92, "where": "ground", "aim": "facing",
			"cost": 375, "invuln": [0, 12], "no_cancel": true, "drawn": true, "cue": {"at": 8, "type": "sweep_up"},
			"motion": [[2, 14, 8.0, 0.0], [16, 34, 3.0, 0.0], [40, 47, 6.0, -7.0]],
			"hits": [{"from": 10, "to": 11, "box": [-34, -100, 96, 64], "dmg": 24, "stun": 18, "kb": [1.0, 0.0], "block": 8, "chip": 2, "group": 0},
				{"from": 14, "to": 15, "box": [-10, -104, 102, 44], "dmg": 24, "stun": 18, "kb": [1.0, 0.0], "block": 8, "chip": 2, "group": 1},
				{"from": 20, "to": 21, "box": [-16, -96, 92, 56], "dmg": 20, "stun": 20, "kb": [1.0, 0.0], "block": 8, "chip": 1, "group": 2},
				{"from": 26, "to": 27, "box": [-16, -96, 92, 56], "dmg": 20, "stun": 20, "kb": [1.0, 0.0], "block": 8, "chip": 1, "group": 3},
				{"from": 32, "to": 33, "box": [-16, -96, 92, 56], "dmg": 20, "stun": 30, "kb": [1.0, -1.0], "block": 8, "chip": 1, "group": 4},
				{"from": 54, "to": 55, "box": [6, -64, 78, 80], "dmg": 80, "stun": 40, "kb": [8.0, -9.0], "block": 12, "chip": 3, "group": 5, "knockdown": true}],
			"pose": [[0, "pir_prep"], [10, "pir_spin"], [14, "pir_cut"], [18, "fou_chamber"], [20, "fou_kick"],
				[23, "fou_chamber"], [26, "fou_kick"], [29, "fou_chamber"], [32, "fou_kick"], [38, "jete_prep"],
				[44, "jete_air"], [54, "jete_land"], [66, "bow"], [86, "bow"], [90, "idle"]], "icon": "bow"},
		# (Grand Jeté - a leap over low hits: a deep coil, the split in the air, landing on a cut; YOMI's dive kick,
		# out on 12. Clear of a low by frame 7)
		"updraft": {"name": "Grand Jeté", "tab": "special", "kind": "attack", "frames": 34, "where": "ground",
			"aim": "facing", "motion": [[3, 9, 8.0, -7.0]], "land_ends": true, "landing": 6, "drawn": true,
			"hits": [{"from": 12, "to": 30, "box": [6, -64, 78, 80], "dmg": 34, "stun": 20, "kb": [6.0, -2.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "jete_prep"], [5, "jete_air"], [12, "jete_land"], [24, "idle"]], "icon": "jete_air"},
		"glide": {"name": "Silk Glide", "tab": "special", "kind": "attack", "frames": 30, "where": "ground",
			"aim": "facing", "shot_invuln": [2, 18], "motion": [[3, 18, 15.0, 0.0]], "dist": [30, 30, 0.2],
			"init_invuln": [2, 8],
			"low_profile": [3, 20],
			"hits": [{"from": 6, "to": 18, "box": [12, -54, 54, 44], "dmg": 30, "stun": 22, "kb": [8.0, -6.0],
				"block": 8, "chip": 3, "group": 0, "height": "low"}],
			"pose": [[0, "crouch"], [3, "glide"], [20, "crouch"], [26, "idle"]], "icon": "glide"},
		# ---- the x-factors on trial (Timmy 21:14: "Can we try the fans, temp and dance forms? Maybe combine two of
		# ---- them honestly"; 21:17 "We may pick one or a combination of two") - each only with its rule on (Sim.xf)
		# Fans: two in hand; Fan Throw / Air Fan send one out and it comes back like a boomerang (hitting on the way
		# back too); Recall calls them home at once; Fan Slash needs one in hand
		"fanslash": {"name": "Fan Slash", "tab": "attack", "kind": "attack", "xf": "fans", "fans": 1, "frames": 18,
			"cue": {"at": 3, "type": "sweep"},
			"where": "ground", "aim": "facing", "motion": [[2, 6, 5.0, 0.0]], "proration": 1,
			"hits": [{"from": 4, "to": 6, "box": [6, -100, 96, 64], "dmg": 26, "stun": 16, "kb": [5.0, -2.0],
				"block": 8, "chip": 2, "group": 0}],
			"pose": [[0, "throw_wind"], [4, "throw_out"], [12, "idle"]], "icon": "throw_out"},
		"fanstep": {"name": "Fan Step", "tab": "move", "kind": "move", "xf": "fans", "needs_out": true, "blink_at": 5,
			"frames": 16, "where": "both", "aim": "none", "float": true, "invuln": [0, 8],
			"pose": [[0, "fs_vanish"], [5, "fs_catch"], [10, "fs_land"], [14, "idle"]], "icon": "fs_catch"},   # (23 Oct: its own drawings)
		"recall": {"name": "Recall", "tab": "special", "kind": "special", "xf": "fans", "recall_at": 3, "frames": 12,
			"where": "both", "aim": "lean", "float": true,   # (no direction: home; a direction: fling them that way first)
			"pose": [[0, "throw_out"], [3, "throw_wind"], [9, "idle"]], "icon": "throw_wind"},
		# (Encore - Tempo full: a flurry of three cuts, the last floors them - a melee finisher since 20 Oct; it was three
		# spectral fans)
		"encore": {"name": "Encore", "tab": "special", "kind": "special", "xf": "tempo", "tempo": 4, "frames": 36,
			"where": "ground", "aim": "facing", "invuln": [0, 4], "no_cancel": true, "drawn": true,
			"note": "three cuts - the last floors them", "cue": {"at": 6, "type": "sweep"},
			"motion": [[2, 10, 6.0, 0.0]],
			"hits": [{"from": 8, "to": 9, "box": [6, -96, 84, 40], "dmg": 14, "stun": 18, "kb": [1.0, 0.0], "block": 8, "chip": 1, "group": 0},
				{"from": 12, "to": 13, "box": [-10, -104, 102, 44], "dmg": 14, "stun": 18, "kb": [1.0, 0.0], "block": 8, "chip": 1, "group": 1},
				{"from": 16, "to": 17, "box": [14, -98, 88, 28], "dmg": 26, "stun": 30, "kb": [6.0, -9.0], "block": 10, "chip": 2, "group": 2, "knockdown": true}],
			"pose": [[0, "pir_prep"], [8, "tap_hit"], [12, "pir_cut"], [16, "arab_hit"], [28, "idle"]], "icon": "arab_hit"},
		# Forms: Flow (as she is), Snap (sharp: her strikes do more and stun longer; Pop, Snap Kick), Floor (low: high
		# hits pass over her; only her floor moves - Windmill, Kip-Up back to Flow, Floor Slide - and defence)
		"snapform": {"name": "Snap Form", "tab": "special", "kind": "move", "xf": "forms", "to_form": "snap",
			"frames": 8, "where": "ground", "aim": "none", "pose": [[0, "crouch"], [4, "snap"]], "icon": "snap"},
		"floorform": {"name": "Floor Form", "tab": "special", "kind": "move", "xf": "forms", "to_form": "floor",
			"frames": 8, "where": "ground", "aim": "none", "pose": [[0, "crouch"], [4, "floor"]], "icon": "floor"},
		"flowform": {"name": "Flow Form", "tab": "special", "kind": "move", "xf": "forms", "to_form": "flow",
			"frames": 8, "where": "ground", "aim": "none", "pose": [[0, "crouch"], [4, "idle"]], "icon": "sway"},
		"pop": {"name": "Pop", "tab": "attack", "kind": "attack", "xf": "forms", "form": "snap", "proration": 2,
			"frames": 10, "where": "ground", "aim": "facing", "motion": [[1, 3, 3.0, 0.0]],
			"hits": [{"from": 2, "to": 3, "box": [8, -88, 50, 26], "dmg": 13, "stun": 12, "kb": [2.0, 0.0], "block": 5,
				"chip": 1, "group": 0}],
			"pose": [[0, "snap"], [2, "jab_hit"], [6, "snap"]], "icon": "jab_hit"},
		# (Snap Step - a quick invulnerable step in - went at 05:03: a rushdown's tool; the Bruiser has Bob & Weave)
		"snapkick": {"name": "Snap Kick", "tab": "attack", "kind": "attack", "xf": "forms", "form": "snap",
			"frames": 17, "where": "ground", "aim": "facing", "motion": [[2, 7, 5.0, 0.0]],
			"hits": [{"from": 4, "to": 6, "box": [8, -112, 74, 44], "dmg": 30, "stun": 18, "kb": [5.0, -4.0], "block": 8,
				"chip": 2, "group": 0}],
			"pose": [[0, "snap"], [4, "kick_hit"], [11, "snap"]], "icon": "kick_hit"},
		"windmill": {"name": "Windmill", "tab": "attack", "kind": "attack", "floor": true, "low_profile": [2, 24],
			"no_cancel": true, "frames": 30, "where": "ground", "aim": "facing", "motion": [[4, 20, 3.0, 0.0]],
			"hits": [{"from": 6, "to": 8, "box": [-56, -44, 112, 42], "dmg": 12, "stun": 15, "kb": [2.0, 0.0],
				"block": 6, "chip": 1, "group": 0, "height": "low"},
				{"from": 12, "to": 14, "box": [-56, -44, 112, 42], "dmg": 12, "stun": 15, "kb": [2.0, 0.0], "block": 6,
				"chip": 1, "group": 1, "height": "low"},
				{"from": 18, "to": 21, "box": [-56, -44, 112, 42], "dmg": 18, "stun": 22, "kb": [5.0, -6.0], "block": 9,
				"chip": 2, "group": 2, "height": "low", "knockdown": true}],
			"pose": [[0, "floor"], [4, "windmill1"], [8, "windmill2"], [12, "windmill1"], [16, "windmill2"],
				[20, "windmill1"], [25, "floor"]], "icon": "windmill1"},
		"kipup": {"name": "Kip-Up", "tab": "special", "kind": "attack", "xf": "forms", "form": "floor",
			"to_form": "flow", "frames": 26, "where": "ground", "aim": "facing", "motion": [[5, 9, 2.0, 0.0]], "invuln": [1, 7],
			"hits": [{"from": 6, "to": 9, "box": [-4, -128, 56, 118], "dmg": 30, "stun": 26, "kb": [2.0, -13.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "down"], [6, "flash_kick"], [16, "fall"], [22, "idle"]], "icon": "flash_kick"},
		"floorslide": {"name": "Floor Slide", "tab": "move", "kind": "move", "xf": "forms", "form": "floor",
			"interrupt": true, "frames": 20, "where": "ground", "aim": "facing", "motion": [[2, 16, 11.0, 0.0]],
			"pose": [[0, "floor"], [2, "sweep"], [16, "floor"]], "icon": "sweep"},
	},
}

## The Bruiser - the rushdown (19 Oct 01:32 "I actually reallt liked him and wanted to work on him as our rush down char";
## 01:46 "a mix of the Nakmuay and Super Smash bros little mac"; 05:03 "we will work on our next char"). Study only
## (docs/bruiser.md): Muay Thai's knees, elbows, teeps, the clinch and the kick catch; Little Mac's fast ground game, armour
## on his big hits, a gauge that builds to one huge punch, and a poor air game. Our own moves and numbers.
## Strong: point blank and on the ground - fast jabs, a jab-cross-hook string, three ways in (Bob & Weave under shots,
## Flying Knee through a guard, Superman Punch over the floor), armour that walks through a fan, the clinch.
## Weak: far away (no projectile), in the air (low jumps, no air dash or air throw), and his big swings are slow and
## punishable; armour takes one hit and grabs go straight through it; floored, he loses half his Grit.
const BRUISER := {
	"stats": {"name": "Bruiser", "hp": 470, "weight": 1.1, "width": 40, "height": 108, "trait": "rushdown",
		"xf": ["grit"], "idle": "b_idle"},
	"moves": {
		# ---- moving: quick along the ground, short in the air
		"walk": {"name": "Walk", "tab": "move", "kind": "move", "interrupt": true, "frames": 16, "where": "ground", "aim": "facing",
			"motion": [[0, 13, 7.5, 0.0]], "pose": [[0, "b_walk1"], [5, "b_walk2"], [10, "b_walk1"], [14, "b_idle"]],
			"icon": "b_walk1"},
		"dash": {"name": "Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground", "aim": "facing",
			"motion": [[1, 30, 19.0, 0.0]], "dist": [10, 20, 0.3], "pose": [[0, "b_dash_off"], [3, "b_dash"], [12, "b_idle"]], "icon": "b_dash"},
		"backstep": {"name": "Back Step", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "ground",
			"aim": "facing", "motion": [[1, 9, -9.0, 0.0]], "invuln": [1, 5],
			"pose": [[0, "b_idle"], [3, "b_lean"], [11, "b_idle"]], "icon": "b_lean"},
		"bob": {"name": "Bob & Weave", "tab": "move", "kind": "move", "frames": 18, "where": "ground", "aim": "facing",
			"motion": [[1, 13, 11.0, 0.0]], "dist": [14, 18, 0.35], "low_profile": [2, 13], "slip": [2, 13],
			"note": "ducks high hits, slips shots that aren't low",
			"pose": [[0, "b_idle"], [2, "b_bob"], [8, "b_weave"], [14, "b_idle"]], "icon": "b_bob"},
		# Chase (05:27 "slapping an enemy accross map and being able to rush them down"): right after one of his big
		# hits sends them flying, he's after them - a run that stops the moment he's on them
		"chase": {"name": "Chase", "tab": "move", "kind": "move", "frames": 24, "where": "ground", "aim": "facing",
			"after": ["haymaker", "teep", "roundhouse", "clinchelbow"], "stop_near": 70, "invuln": [1, 3],
			"motion": [[1, 24, 30.0, 0.0]], "note": "after a big hit: across the stage after them",
			"pose": [[0, "b_dash"], [2, "b_rush"], [22, "b_idle"]], "icon": "b_rush"},
		"roll": {"name": "Dodge", "tab": "defend", "kind": "move", "frames": 20, "where": "ground", "aim": "facing",
			"motion": [[2, 15, 12.0, 0.0]], "invuln": [2, 13], "pose": [[0, "crouch"], [2, "dive"], [4, "tuck@90g"], [7, "tuck@180g"], [11, "tuck@270g"], [15, "crouch"]],
			"pose_back": [[0, "crouch"], [2, "sitback"], [4, "tuck@-90g"], [7, "tuck@-180g"], [11, "tuck@-270g"], [15, "crouch"]],
			"icon": "roll"},
		"jump": {"name": "Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "ground", "aim": "up",
			"dist": [6, 6, 0.72], "motion": [[1, 1, ["px", 7.5], -14.0]], "pose": [[0, "crouch"], [1, "jump_off"], [4, "jump"]], "icon": "jump",
			"pose_back": [[0, "crouch"], [1, "arch"], [3, "arch@-75"], [5, "tuck@-220"]]},
		"superjump": {"name": "Super Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground",
			"aim": "up", "motion": [[5, 5, ["px", 8.5], -18.5]], "pose": [[0, "crouch_deep"], [5, "jump_off"], [9, "jump"]], "icon": "jump"},
		"airjump": {"name": "Air Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air",
			"aim": "up", "air_option": true, "dist": [6, 6, 0.65], "motion": [[1, 1, ["px", 6.0], -11.0]],
			"pose": [[0, "tuck@30"], [1, "tuck@120"], [3, "tuck@210"], [5, "tuck@300"]], "icon": "jump",
			"pose_back": [[0, "arch"], [2, "arch@-80"], [4, "tuck@-220"]]},
		"fastfall": {"name": "Fast Fall", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air", "aim": "none",
			"motion": [[0, 0, 0.0, 18.0]], "pose": [[0, "fastfall"]], "icon": "fastfall"},
		# ---- on the ground: the boxer's hands, the Thai fighter's shins and elbows
		"jab": {"name": "Jab", "tab": "attack", "drawn": true, "kind": "attack", "proration": 2, "frames": 14, "where": "ground", "aim": "facing",
			"motion": [[2, 5, 3.0, 0.0]],
			"hits": [{"from": 4, "to": 5, "box": [8, -88, 48, 18], "dmg": 16, "stun": 12, "kb": [2.0, 0.0],
				"block": 6, "chip": 1, "group": 0}],
			"pose": [[0, "mt_jab_load"], [4, "mt_jab"], [9, "b_idle"]], "icon": "mt_jab"},
		"cross": {"name": "Cross", "tab": "attack", "drawn": true, "kind": "attack", "proration": 1, "after": ["jab"], "frames": 18,
			"where": "ground", "aim": "facing", "motion": [[2, 7, 4.5, 0.0]], "note": "after a Jab",
			"hits": [{"from": 6, "to": 7, "box": [10, -86, 62, 20], "dmg": 24, "stun": 15, "kb": [3.5, 0.0],
				"block": 7, "chip": 2, "group": 0}],
			"pose": [[0, "mt_cross_load"], [6, "mt_cross"], [12, "b_idle"]], "icon": "mt_cross"},
		"hook": {"name": "Hook", "tab": "attack", "drawn": true, "kind": "attack", "after": ["cross"], "frames": 22, "where": "ground",
			"aim": "facing", "motion": [[2, 7, 4.0, 0.0]], "note": "after a Cross - into the wall",
			"hits": [{"from": 6, "to": 8, "box": [2, -100, 58, 36], "dmg": 34, "stun": 20, "kb": [6.0, -3.0],
				"block": 10, "chip": 3, "group": 0, "splat": true}],
			"pose": [[0, "mt_hook_load"], [6, "mt_hook"], [15, "b_idle"]], "icon": "mt_hook"},
		"body": {"name": "Body Blow", "tab": "attack", "drawn": true, "kind": "attack", "proration": 1, "frames": 18, "where": "ground",
			"aim": "facing", "motion": [[2, 6, 5.0, 0.0]], "note": "to the liver: long hitstun",
			"hits": [{"from": 5, "to": 7, "box": [10, -66, 52, 24], "dmg": 24, "stun": 22, "kb": [2.0, 0.0],
				"block": 8, "chip": 2, "group": 0}],
			"pose": [[0, "mt_body_load"], [5, "mt_body"], [12, "b_idle"]], "icon": "mt_body"},
		"legkick": {"name": "Leg Kick", "tab": "attack", "drawn": true, "kind": "attack", "proration": 1, "frames": 18, "where": "ground",
			"aim": "facing", "motion": [[2, 6, 4.0, 0.0]],
			"hits": [{"from": 5, "to": 7, "box": [8, -36, 64, 24], "dmg": 26, "stun": 14, "kb": [2.0, 0.0],
				"block": 8, "chip": 2, "group": 0, "height": "low"}],
			"pose": [[0, "mt_legkick_load"], [5, "mt_legkick"], [12, "b_idle"]], "icon": "mt_legkick"},
		"teep": {"name": "Teep", "tab": "attack", "drawn": true, "kind": "attack", "frames": 24, "where": "ground", "aim": "facing",
			"init_faster": 2, "motion": [[4, 11, 4.0, 0.0]], "note": "the push kick: shoves them off - into the wall",
			"hits": [{"from": 11, "to": 13, "box": [12, -74, 72, 24], "dmg": 22, "stun": 26, "kb": [14.0, -1.0],
				"block": 10, "chip": 2, "group": 0, "splat": true, "fling": true}],
			"pose": [[0, "mt_teep_chamber"], [11, "mt_teep"], [18, "b_idle"]], "icon": "mt_teep"},
		"elbow": {"name": "Elbow", "tab": "attack", "drawn": true, "kind": "attack", "frames": 18, "where": "ground", "aim": "facing",
			"motion": [[2, 6, 4.0, 0.0]], "note": "point blank and sharp",
			"hits": [{"from": 6, "to": 9, "box": [4, -102, 42, 34], "dmg": 30, "stun": 18, "kb": [3.0, -1.0],
				"block": 9, "chip": 3, "group": 0}],
			"pose": [[0, "mt_elbow_load"], [6, "mt_elbow"], [13, "b_idle"]], "icon": "mt_elbow"},
		"roundhouse": {"name": "Roundhouse", "tab": "attack", "drawn": true, "kind": "attack", "frames": 32, "where": "ground",
			"aim": "facing", "armor": [3, 11], "motion": [[2, 10, 4.0, 0.0]],
			"note": "Super Armor f3-11: takes a hit and kicks on",
			"hits": [{"from": 11, "to": 13, "box": [-6, -106, 92, 52], "dmg": 50, "stun": 30, "kb": [13.0, -4.0],
				"block": 14, "chip": 5, "group": 0, "fling": true}],
			"pose": [[0, "mt_round_load"], [11, "mt_round"], [22, "b_idle"]], "icon": "mt_round"},
		"quake": {"name": "Quake Stomp", "tab": "attack", "kind": "attack", "frames": 24, "where": "ground", "aim": "facing",
			"cue": {"at": 8, "type": "quake"}, "note": "a shockwave both ways along the floor - picks them up off it",
			"hits": [{"from": 8, "to": 10, "box": [-90, -24, 180, 26], "dmg": 12, "stun": 22, "kb": [0.5, -7.0],
				"block": 8, "chip": 2, "group": 0, "height": "low", "otg": true}],
			"pose": [[0, "b_stomp_up"], [8, "b_stomp"], [16, "b_idle"]], "icon": "b_stomp_up"},
		# ---- the clinch (Muay Thai's): his grab holds them instead of throwing - then knees (up to three), an elbow
		# out, or a dump down behind him. They can Burst out.
		"clinch": {"name": "Clinch", "tab": "attack", "kind": "grab", "frames": 24, "where": "ground", "aim": "facing",
			"motion": [[1, 5, 4.5, 0.0]], "note": "holds them: knees, an elbow or a dump next",
			# (his grab: out on YOMI's standard frame 3 - 20 Oct 15:34; it was 4. Whiffed it still costs him 24)
			"hits": [{"from": 3, "to": 5, "box": [6, -100, 36, 72], "dmg": 8, "stun": 30, "kb": [0.0, 0.0], "group": 0,
				"hold": true}],
			"pose": [[0, "grab_reach"], [5, "b_clinch"], [18, "b_idle"]], "icon": "b_clinch"},
		"clinchknee": {"name": "Clinch Knee", "tab": "attack", "kind": "attack", "after": ["clinch", "clinchknee"],
			"repeat": 2, "frames": 16, "where": "ground", "aim": "facing", "note": "in the clinch: up to three",
			"hits": [{"from": 3, "to": 5, "box": [0, -86, 50, 46], "dmg": 20, "stun": 22, "kb": [0.5, -1.0],
				"block": 8, "chip": 2, "group": 0, "hold": true}],
			"pose": [[0, "b_clinch"], [3, "b_clinch_knee"], [10, "b_clinch"]], "icon": "b_clinch_knee"},
		"clinchelbow": {"name": "Clinch Elbow", "tab": "attack", "drawn": true, "kind": "attack", "after": ["clinch", "clinchknee"],
			"frames": 20, "where": "ground", "aim": "facing", "note": "out of the clinch: knocks them back",
			"hits": [{"from": 4, "to": 6, "box": [2, -106, 50, 44], "dmg": 30, "stun": 28, "kb": [13.0, -3.0],
				"block": 9, "chip": 3, "group": 0, "splat": true, "fling": true}],
			"pose": [[0, "b_clinch"], [4, "mt_elbow"], [12, "b_idle"]], "icon": "b_elbow"},
		"dump": {"name": "Dump", "tab": "attack", "kind": "attack", "after": ["clinch", "clinchknee"], "frames": 24,
			"where": "ground", "aim": "facing", "note": "out of the clinch: down behind him",
			"hits": [{"from": 5, "to": 7, "box": [-20, -104, 74, 104], "dmg": 28, "stun": 34, "kb": [-7.0, -5.0],
				"group": 0, "knockdown": true, "behind": true}],
			"pose": [[0, "b_clinch"], [5, "throw"], [14, "b_idle"]], "icon": "throw"},
		# ---- in the air (his weak spot): a knee, a hook, an elbow dropped on them
		"airknee": {"name": "Air Knee", "tab": "attack", "kind": "attack", "proration": 1, "frames": 15, "where": "air",
			"aim": "facing", "land_ends": true, "landing": 6,
			"hits": [{"from": 6, "to": 7, "box": [6, -82, 36, 32], "dmg": 24, "stun": 14, "kb": [5.0, -4.0],
				"block": 7, "chip": 1, "group": 0}],
			"pose": [[0, "knee"], [11, "fall"]], "icon": "knee"},
		"airhook": {"name": "Air Hook", "tab": "attack", "drawn": true, "kind": "attack", "proration": 1, "frames": 18, "where": "air",
			"aim": "facing", "land_ends": true, "landing": 4,
			"hits": [{"from": 5, "to": 7, "box": [4, -98, 42, 28], "dmg": 18, "stun": 13, "kb": [4.0, -1.0],
				"block": 7, "chip": 1, "group": 0}],
			"pose": [[0, "mt_hook_load"], [4, "mt_hook"], [12, "fall"]], "icon": "mt_hook"},
		"elbowdrop": {"name": "Elbow Drop", "tab": "attack", "kind": "attack", "frames": 40, "where": "air", "aim": "none",
			"motion": [[3, 40, 1.0, 13.0]], "land_ends": true, "landing": 16, "note": "an overhead, straight down",
			"hits": [{"from": 6, "to": 40, "box": [-6, -44, 52, 46], "dmg": 20, "stun": 15, "kb": [4.0, 3.0],
				"block": 12, "chip": 3, "group": 0, "height": "high", "bounce": true}],
			"pose": [[0, "b_elbow_drop"]], "icon": "b_elbow_drop"},
		# ---- specials: three ways in, an anti-air, the big one, the catch
		"uppercut": {"name": "Rising Uppercut", "tab": "special", "drawn": true, "kind": "attack", "init_invuln": [1, 4],
			"cancel_into": ["jump", "superjump"], "frames": 28, "where": "ground", "aim": "facing", "motion": [[2, 7, 3.0, 0.0]],
			"hits": [{"from": 4, "to": 7, "box": [4, -128, 46, 78], "dmg": 36, "stun": 26, "kb": [1.5, -11.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "mt_upper_load"], [4, "mt_upper"], [15, "b_idle"]], "icon": "mt_upper"},
		"haymaker": {"name": "Haymaker", "tab": "special", "drawn": true, "kind": "attack", "frames": 40, "where": "ground", "aim": "facing",
			"armor": [2, 13], "motion": [[6, 13, 10.0, 0.0]], "dist": [40, 40, 0.3],
			"note": "Super Armor f2-13; lunges as far as the Distance says",
			"hits": [{"from": 13, "to": 15, "box": [10, -100, 76, 32], "dmg": 66, "stun": 34, "kb": [15.0, -3.0],
				"block": 16, "chip": 8, "group": 0, "splat": true, "fling": true}],
			"pose": [[0, "mt_hay_load"], [13, "mt_hay"], [26, "b_idle"]], "icon": "mt_hay"},
		"flyknee": {"name": "Flying Knee", "tab": "special", "kind": "attack", "frames": 30, "where": "ground",
			"aim": "facing", "motion": [[3, 11, 12.0, -4.5]], "dist": [30, 30, 0.35], "land_ends": true, "landing": 8,
			"note": "leaps in - breaks a guard",
			"hits": [{"from": 8, "to": 12, "box": [8, -92, 48, 54], "dmg": 40, "stun": 22, "kb": [6.0, -6.0],
				"block": 12, "chip": 4, "group": 0, "guardbreak": true}],
			"pose": [[0, "crouch"], [3, "knee"], [8, "b_flyknee"], [16, "fall"]], "icon": "b_flyknee"},
		"superman": {"name": "Superman Punch", "tab": "special", "drawn": true, "kind": "attack", "frames": 30, "where": "ground",
			"aim": "facing", "motion": [[2, 9, 11.0, -5.0], [10, 14, 9.0, 0.0]], "dist": [30, 30, 0.35],
			"land_ends": true, "landing": 6, "note": "a leaping cross - an overhead",
			"hits": [{"from": 11, "to": 14, "box": [10, -76, 60, 34], "dmg": 38, "stun": 20, "kb": [7.0, -4.0],
				"block": 12, "chip": 4, "group": 0, "height": "high"}],
			"pose": [[0, "crouch"], [2, "b_hop"], [10, "mt_superman"], [18, "fall"]], "icon": "mt_superman"},
		"catch": {"name": "Catch", "tab": "special", "kind": "counter", "frames": 30, "where": "ground", "aim": "none",
			"window": [2, 12], "counter_move": "catchdump", "note": "catches a strike and dumps them (not shots)",
			"counter_hit": {"dmg": 44, "stun": 34, "kb": [-6.0, -5.0], "group": 0, "knockdown": true, "behind": true},
			"pose": [[0, "b_catch"]], "icon": "b_catch"},
		"catchdump": {"name": "Catch Dump", "tab": "special", "kind": "attack", "hidden": true, "frames": 22,
			"where": "both", "aim": "none", "invuln": [0, 14], "pose": [[0, "throw"], [14, "b_idle"]]},
		# Grit (his own gauge - Little Mac's Power Meter, studied): full, the K.O. Punch - quick, through a guard, huge;
		# missed, he's wide open
		"kopunch": {"name": "K.O. Punch", "tab": "special", "drawn": true, "kind": "attack", "xf": "grit", "grit": true, "no_cancel": true,
			"frames": 44, "where": "ground", "aim": "facing", "motion": [[2, 6, 6.0, 0.0]],
			"cue": {"at": 4, "type": "kopunch"}, "note": "full Grit: fast, through a guard - wide open if it misses",
			"hits": [{"from": 5, "to": 8, "box": [4, -132, 54, 98], "dmg": 100, "min_dmg": 60, "stun": 60,
				"kb": [4.0, -12.0], "block": 20, "chip": 10, "group": 0, "guardbreak": true, "knockdown": true}],
			"pose": [[0, "mt_ko_load"], [5, "mt_ko"], [20, "fall"], [34, "b_idle"]], "icon": "mt_ko"},
		# ---- show-off: the Wai Khru's bow
		"taunt": {"name": "Taunt", "tab": "defend", "kind": "wait", "interrupt": true, "frames": 50, "where": "ground", "aim": "facing",
			"meter_gain": 125, "pose": [[0, "b_tap"], [4, "b_idle"], [7, "b_tap"], [11, "b_beckon"], [15, "b_curl"],
				[19, "b_beckon"], [23, "b_curl"], [28, "b_flex"], [37, "b_pound"], [44, "b_taunt"]], "icon": "b_taunt"},   # (23 Oct: a routine)
		# ---- supers: armour through it all, a flurry, the clinch at its worst
		"bullrush": {"name": "Bull Rush", "tab": "super", "kind": "super", "frames": 40, "where": "ground", "aim": "facing",
			"cost": 125, "armor": [0, 30], "armor_hits": 3, "motion": [[4, 26, 12.0, 0.0]], "cue": {"at": 4, "type": "rush"},
			"note": "Super Armor for three hits - through shots and all",
			"hits": [{"from": 8, "to": 26, "box": [10, -106, 52, 98], "dmg": 40, "stun": 40, "kb": [16.0, -4.0],
				"block": 16, "chip": 6, "group": 0, "splat": true, "fling": true}],
			"pose": [[0, "b_idle"], [4, "b_rush"], [27, "mt_hay"], [34, "b_idle"]], "icon": "b_rush"},
		"barrage": {"name": "Barrage", "tab": "super", "kind": "super", "frames": 46, "where": "ground", "aim": "facing",
			"cost": 250, "invuln": [0, 8], "motion": [[2, 28, 2.5, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [8, -90, 56, 24], "dmg": 12, "stun": 16, "kb": [1.5, 0.0], "block": 6, "chip": 2, "group": 0},
				{"from": 12, "to": 13, "box": [8, -90, 56, 24], "dmg": 12, "stun": 16, "kb": [1.5, 0.0], "block": 6, "chip": 2, "group": 1},
				{"from": 16, "to": 17, "box": [8, -90, 56, 24], "dmg": 12, "stun": 16, "kb": [1.5, 0.0], "block": 6, "chip": 2, "group": 2},
				{"from": 20, "to": 21, "box": [8, -90, 56, 24], "dmg": 12, "stun": 16, "kb": [1.5, 0.0], "block": 6, "chip": 2, "group": 3},
				{"from": 24, "to": 25, "box": [8, -90, 56, 24], "dmg": 12, "stun": 16, "kb": [1.5, 0.0], "block": 6, "chip": 2, "group": 4},
				{"from": 30, "to": 33, "box": [4, -130, 50, 90], "dmg": 40, "stun": 30, "kb": [2.0, -14.0], "block": 14, "chip": 4, "group": 5},
			],
			"pose": [[0, "b_idle"], [8, "mt_jab"], [10, "mt_cross"], [12, "mt_jab"], [14, "mt_cross"], [16, "mt_jab"],
				[18, "mt_cross"], [20, "mt_jab"], [22, "mt_cross"], [24, "mt_jab"], [27, "crouch"], [30, "uppercut"],
				[40, "b_idle"]], "icon": "straight"},
		"clinchfury": {"name": "Clinch Fury", "tab": "super", "kind": "grab", "frames": 64, "where": "ground", "aim": "facing",
			"cost": 375, "no_cancel": true, "motion": [[2, 6, 5.0, 0.0]],
			"note": "a clinch that won't let go: three knees and an elbow",
			"hits": [
				{"from": 4, "to": 6, "box": [6, -100, 40, 72], "dmg": 20, "stun": 80, "kb": [0.0, 0.0], "group": 0, "hold": true},
				{"from": 16, "to": 17, "box": [0, -86, 50, 46], "dmg": 26, "stun": 70, "kb": [0.0, -1.0], "group": 1, "hold": true, "strike": true, "min_dmg": 18},
				{"from": 26, "to": 27, "box": [0, -86, 50, 46], "dmg": 26, "stun": 70, "kb": [0.0, -1.0], "group": 2, "hold": true, "strike": true, "min_dmg": 18},
				{"from": 36, "to": 37, "box": [0, -86, 50, 46], "dmg": 30, "stun": 70, "kb": [0.0, -1.0], "group": 3, "hold": true, "strike": true, "min_dmg": 20},
				{"from": 48, "to": 49, "box": [2, -106, 54, 48], "dmg": 50, "stun": 50, "kb": [9.0, -7.0], "group": 4, "strike": true, "min_dmg": 32, "knockdown": true},
			],
			"pose": [[0, "grab_reach"], [6, "b_clinch"], [13, "b_clinch"], [16, "b_clinch_knee"], [21, "b_clinch"],
				[26, "b_clinch_knee"], [31, "b_clinch"], [36, "b_clinch_knee"], [42, "b_elbow_wind"], [48, "b_elbow"],
				[58, "b_idle"]], "icon": "b_clinch_knee"},
	},
}

## The roster: the Dancer (18 Oct 17:52 "Just work on getting one char working and remove the other one" - her alone,
## until she was right) and, since 19 Oct 05:03, the Bruiser.
const ROSTER := {"dancer": DANCER, "bruiser": BRUISER}
const ORDER := ["dancer", "bruiser"]   ## (the picker's order)
## The menu's tabs, in order: [id, name] - YOMI's five (Timmy 21:03 "Get more references as i think your getting
## confused about the way moves are categorised"; its own menu, references/yomi/moves_menu): fixed columns whose moves
## change with the state - air attacks show in Attack in the air, Burst in Defense while reeling, Get Up there when
## down. Wait is Movement; Hold is a button by Confirm, as by YOMI's Lock In - and in Movement too whenever it's there
## (mid-move, stuck in a move, reeling: 22:37 "I cant just choice to wait if I click off that during a move").
## Top to bottom: Movement right above Defense (22:37 "Movement should be above the defence options").
const TABS := [["attack", "Attack"], ["special", "Special"], ["super", "Super"], ["move", "Movement"],
	["defend", "Defense"]]


## A character's full move list: their own plus the shared ones.
static func of(character: String) -> Dictionary:
	var out: Dictionary = (ROSTER[character]["moves"] as Dictionary).duplicate()
	out.merge(COMMON)   # (their own moves first in the menu)
	return out


static func stats(character: String) -> Dictionary:
	return ROSTER[character]["stats"]


static func move(character: String, id: String) -> Dictionary:
	return of(character).get(id, {})


## The pose a move's icon shows.
## A move's projectiles: "spawn" is one, or a list (a super's volley - 03:03).
static func spawns(m: Dictionary) -> Array:
	var sp: Variant = m.get("spawn", [])
	return sp if sp is Array else [sp]


## How soon a move does its thing (03:00 "in order of lowest frames to higest frames"): the frame its first hit is
## out, or it throws, its wind blows, its counter window opens, or it's on the move; else its length.
static func startup(m: Dictionary) -> int:
	var hits: Array = m.get("hits", [])
	if not hits.is_empty():
		return int(hits[0]["from"])
	if m.has("spawn"):
		return int((spawns(m)[0] as Dictionary).get("at", m.get("frames", 0)))
	for k in ["blink_at", "recall_at"]:
		if m.has(k):
			return int(m[k])
	if m.has("gust"):
		return int(m["gust"][0])
	if m.has("window"):   # (a counter: when it starts catching)
		return int(m["window"][0])
	var motion: Array = m.get("motion", [])
	if not motion.is_empty():
		return int(motion[0][0])
	return int(m.get("frames", 0))


## What's special about a move, as small badges (03:00 "icons/emojis for additional info like unblocakble and
## initave"); BADGE_KEY says what each means.
const BADGE_KEY := "✊ beats blocks   ⚡ initiative   👻 dodges   🔻 hits low   💥 guard break   🎯 projectile   🛡 armour"


static func badges(m: Dictionary) -> String:
	var out := ""
	var hits: Array = m.get("hits", [])
	if str(m.get("kind", "")) == "grab":
		out += "✊"
	if m.has("init_invuln") or m.has("init_faster"):
		out += "⚡"
	if m.has("invuln"):
		out += "👻"
	if hits.any(func(e: Dictionary) -> bool: return str(e.get("height", "mid")) == "low") \
			or spawns(m).any(func(sp: Dictionary) -> bool: return str(sp.get("height", "mid")) == "low"):
		out += "🔻"
	if hits.any(func(e: Dictionary) -> bool: return bool(e.get("guardbreak", false))):
		out += "💥"
	if m.has("spawn"):
		out += "🎯"
	if m.has("armor"):
		out += "🛡"
	return out


static func icon_pose(m: Dictionary) -> String:
	if m.has("icon"):
		return str(m["icon"])
	var keys: Array = m.get("pose", [[0, "idle"]])
	var hits: Array = m.get("hits", [])
	if not hits.is_empty():
		var at := int(hits[0]["from"])
		var name := str(keys[0][1])
		for k: Array in keys:
			if int(k[0]) <= at:
				name = str(k[1])
		return name
	return str(keys[0][1])
