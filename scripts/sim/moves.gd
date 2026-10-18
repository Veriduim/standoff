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
##             life, height, parry: false = can't be parried, grav}
##   enter     a stance move: puts them in that stance (its moves - "stance": that name - are open while it runs)
##   after     [move ids] - a follow-up: there only right after landing one of those
##   cancel_into [move ids] - landing this only frees them into these (the wiki's hit-cancel limits)
##   init_invuln [from, to] - invulnerable on these frames too, with initiative (the nearest enemy was choosing too)
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
##   armor     [from, to] strikes in this window hurt but don't stop the move (grabs still do)
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
## get that to fit with icons"): fast, light, kicks and footwork.
const DANCER := {
	"stats": {"name": "Dancer", "hp": 450, "weight": 0.85, "width": 34, "height": 104},
	"moves": {
		# ---- moving
		"walk": {"name": "Walk", "tab": "move", "kind": "move", "interrupt": true, "frames": 16, "where": "ground", "aim": "facing",
			"motion": [[0, 13, 6.5, 0.0]], "pose": [[0, "walk1"], [5, "walk2"], [10, "walk1"], [14, "idle"]]},
		"dash": {"name": "Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground", "aim": "facing",
			"motion": [[1, 30, 17.0, 0.0]], "dist": [10, 20, 0.3], "pose": [[0, "dash"], [12, "idle"]]},
		"backstep": {"name": "Back Step", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "ground",
			"aim": "facing", "motion": [[1, 10, -11.0, 0.0]], "invuln": [1, 6],
			"pose": [[0, "crouch"], [4, "fall"], [11, "idle"]], "icon": "fall"},
		"roll": {"name": "Dodge", "tab": "defend", "floor": true, "kind": "move", "frames": 22, "where": "ground", "aim": "facing",
			"motion": [[2, 17, 12.0, 0.0]], "invuln": [2, 14], "pose": [[0, "crouch"], [2, "roll"], [17, "crouch"]],
			"icon": "roll"},
		"jump": {"name": "Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "ground", "aim": "up",
			"dist": [6, 6, 0.72], "motion": [[1, 1, ["px", 8.5], -16.0]], "pose": [[0, "crouch"], [1, "jump"]], "icon": "jump"},
		"superjump": {"name": "Super Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground",
			"aim": "up", "motion": [[5, 5, ["px", 9.5], -21.5]], "pose": [[0, "crouch"], [5, "jump"]], "icon": "jump"},
		"airdash": {"name": "Air Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "air", "aim": "dir8",
			"float": true, "air_option": true, "dist": [8, 16, 0.4], "motion": [[0, 13, ["px", 14.0], ["py", 14.0]]], "pose": [[0, "dash"]]},
		"airjump": {"name": "Air Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air",
			"aim": "up", "air_option": true, "dist": [6, 6, 0.65], "motion": [[1, 1, ["px", 7.5], -14.0]],
			"pose": [[0, "crouch"], [1, "jump"]], "icon": "jump"},
		"fastfall": {"name": "Fast Fall", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air", "aim": "none",
			"motion": [[0, 0, 0.0, 18.0]], "pose": [[0, "fall"]]},
		# ---- on the ground
		"jab": {"name": "Jab", "tab": "attack", "kind": "attack", "proration": 2, "frames": 13, "where": "ground", "aim": "facing", "motion": [[1, 4, 3.5, 0.0]],
			"hits": [{"from": 3, "to": 4, "box": [8, -80, 48, 18], "dmg": 18, "stun": 12, "kb": [2.0, 0.0],
				"block": 6, "chip": 1, "group": 0}],
			"pose": [[0, "jab_wind"], [3, "jab_hit"], [8, "idle"]]},
		"straight": {"name": "Straight", "tab": "attack", "kind": "attack", "proration": 1, "frames": 20, "where": "ground",
			"aim": "facing", "motion": [[3, 9, 6.5, 0.0]], "dist": [20, 20, 0.0],
			"hits": [{"from": 7, "to": 9, "box": [10, -82, 66, 20], "dmg": 32, "stun": 16, "kb": [5.0, -1.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "jab_wind"], [7, "straight"], [13, "idle"]]},
		"lowkick": {"name": "Low Kick", "tab": "attack", "floor": true, "kind": "attack", "proration": 1, "frames": 16, "where": "ground",
			"aim": "facing", "motion": [[2, 6, 4.0, 0.0]],
			"hits": [{"from": 5, "to": 6, "box": [6, -30, 58, 24], "dmg": 22, "stun": 14, "kb": [2.0, 0.0],
				"block": 8, "chip": 1, "group": 0, "height": "low"}],
			"pose": [[0, "crouch"], [5, "low_kick"], [10, "idle"]]},
		"sidekick": {"name": "Side Kick", "tab": "attack", "kind": "attack", "frames": 24, "where": "ground",
			"aim": "facing", "motion": [[2, 9, 6.0, 0.0]], "dist": [24, 24, 0.0],
			"hits": [{"from": 8, "to": 10, "box": [12, -66, 78, 22], "dmg": 40, "stun": 18, "kb": [9.0, -2.0],
				"block": 12, "chip": 3, "group": 0, "splat": true}],
			"pose": [[0, "kick_wind"], [8, "side_kick"], [15, "idle"]]},
		"uppercut": {"name": "Uppercut", "tab": "special", "kind": "attack", "init_invuln": [1, 6],
			"cancel_into": ["jump", "superjump"], "frames": 26, "where": "ground",
			"aim": "facing", "motion": [[3, 8, 3.0, 0.0]],
			"hits": [{"from": 6, "to": 9, "box": [4, -120, 46, 70], "dmg": 38, "stun": 26, "kb": [1.5, -12.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "crouch"], [6, "uppercut"], [16, "idle"]]},
		"spin": {"name": "Spin Kick", "tab": "attack", "kind": "attack", "frames": 26, "where": "ground",
			"cue": {"at": 4, "type": "sweep"},
			"aim": "facing", "motion": [[2, 14, 5.0, 0.0]],
			"hits": [{"from": 7, "to": 12, "box": [-64, -94, 128, 40], "dmg": 50, "stun": 20, "kb": [6.0, -5.0],
				"block": 12, "chip": 4, "group": 0}],
			"pose": [[0, "crouch"], [7, "spin1"], [10, "spin2"], [14, "idle"]], "icon": "spin2"},
		"sweep": {"name": "Sweep", "tab": "attack", "floor": true, "kind": "attack", "proration": -1, "frames": 28, "where": "ground",
			"aim": "facing", "motion": [[3, 12, 6.0, 0.0]], "dist": [28, 28, 0.0], "low_profile": [3, 20],
			"hits": [{"from": 9, "to": 11, "box": [10, -22, 84, 22], "dmg": 30, "stun": 34, "kb": [3.0, -3.0],
				"block": 10, "chip": 2, "group": 0, "height": "low", "knockdown": true}],
			"pose": [[0, "crouch"], [9, "sweep"], [18, "crouch"], [24, "idle"]]},
		"axekick": {"name": "Axe Kick", "tab": "attack", "kind": "attack", "frames": 32, "where": "ground",
			"aim": "facing", "motion": [[2, 10, 4.0, 0.0]],
			"hits": [{"from": 15, "to": 17, "box": [10, -110, 56, 90], "dmg": 60, "stun": 22, "kb": [4.0, 4.0],
				"block": 14, "chip": 5, "group": 0, "bounce": true, "height": "high", "knockdown": true}],
			"pose": [[0, "kick_wind"], [8, "axe_up"], [15, "axe_down"], [24, "idle"]], "icon": "axe_up"},
		"kneedash": {"name": "Knee Dash", "tab": "attack", "kind": "attack", "frames": 26, "where": "ground",
			"aim": "facing", "motion": [[4, 14, 13.0, 0.0]], "dist": [26, 26, 0.15],
			"hits": [{"from": 6, "to": 14, "box": [10, -70, 40, 34], "dmg": 34, "stun": 18, "kb": [6.0, -3.0],
				"block": 10, "chip": 3, "group": 0, "guardbreak": true}],
			"pose": [[0, "dash"], [5, "knee"], [17, "idle"]]},
		"flashkick": {"name": "Flash Kick", "tab": "special", "kind": "attack", "no_cancel": true, "frames": 30, "where": "ground",
			"aim": "facing", "invuln": [1, 8], "motion": [[4, 10, 2.5, -11.0]],
			"hits": [{"from": 4, "to": 9, "box": [-4, -140, 56, 120], "dmg": 48, "stun": 28, "kb": [3.0, -13.0],
				"block": 14, "chip": 4, "group": 0, "knockdown": true}],
			"pose": [[0, "crouch"], [4, "flash_kick"], [14, "fall"]]},
		# ---- in the air
		"airkick": {"name": "Air Kick", "tab": "attack", "kind": "attack", "proration": 1, "frames": 18, "where": "air", "aim": "facing",
			"land_ends": true, "landing": 4,
			"hits": [{"from": 4, "to": 8, "box": [6, -66, 60, 24], "dmg": 24, "stun": 14, "kb": [4.0, -1.0],
				"block": 8, "chip": 1, "group": 0}],
			"pose": [[0, "kick_wind"], [4, "kick_hit"], [12, "fall"]]},
		"airknee": {"name": "Air Knee", "tab": "attack", "kind": "attack", "proration": 1, "frames": 16, "where": "air", "aim": "facing",
			"land_ends": true, "landing": 4,
			"hits": [{"from": 3, "to": 6, "box": [6, -80, 40, 36], "dmg": 28, "stun": 16, "kb": [5.0, -4.0],
				"block": 8, "chip": 2, "group": 0}],
			"pose": [[0, "knee"], [10, "fall"]]},
		# ---- a chain off the jab (follow-ups: there only right after landing the move before - the wiki: "some actions
		# are only available after using a specific action")
		"onetwo": {"name": "One-Two", "tab": "attack", "kind": "attack", "after": ["jab"], "frames": 16,
			"where": "ground", "aim": "facing", "motion": [[1, 5, 4.0, 0.0]],
			"hits": [{"from": 3, "to": 4, "box": [10, -82, 62, 20], "dmg": 24, "stun": 16, "kb": [3.0, 0.0], "block": 8,
				"chip": 2, "group": 0}],
			"pose": [[0, "jab_wind"], [3, "straight"], [10, "idle"]], "icon": "straight"},
		"spinfinish": {"name": "Spin Finish", "tab": "attack", "kind": "attack", "after": ["onetwo"], "frames": 26,
			"cue": {"at": 5, "type": "sweep"},
			"where": "ground", "aim": "facing", "motion": [[2, 10, 6.0, 0.0]],
			"hits": [{"from": 6, "to": 9, "box": [-30, -96, 110, 44], "dmg": 38, "stun": 24, "kb": [9.0, -7.0],
				"block": 12, "chip": 4, "group": 0, "knockdown": true, "splat": true}],
			"pose": [[0, "crouch"], [6, "spin2"], [16, "idle"]], "icon": "spin2"},
		# ---- specials: projectiles, the Sway stance, a counter
		"fan": {"name": "Fan Throw", "tab": "special", "kind": "special", "fans": 1, "frames": 24, "where": "ground",
			"aim": "dir8",
			"spawn": {"at": 8, "kind": "fan", "speed": 11.0, "from": [30, -74], "box": [26, 20], "dmg": 20, "stun": 14,
				"kb": [4.0, -2.0], "block": 8, "chip": 2, "life": 70},
			"pose": [[0, "throw_wind"], [8, "throw_out"], [17, "idle"]], "icon": "throw_out"},
		"airfan": {"name": "Air Fan", "tab": "special", "kind": "special", "fans": 1, "frames": 20, "where": "air",
			"aim": "down", "air_option": true, "land_ends": true, "landing": 4,
			"motion": [[0, 7, 0.0, 0.0]],   # (a brief hang, then she falls - 23:34 "Air Fan spam!!!")
			"spawn": {"at": 6, "kind": "fan", "speed": 11.0, "from": [24, -60], "box": [26, 20], "dmg": 18, "stun": 14,
				"kb": [3.0, 2.0], "block": 8, "chip": 2, "life": 50},
			"pose": [[0, "throw_wind"], [6, "throw_out"], [14, "fall"]], "icon": "throw_out"},
		"ripple": {"name": "Ground Ripple", "tab": "special", "kind": "special", "floor": true, "frames": 30,
			"where": "ground",
			"aim": "facing",
			"spawn": {"at": 11, "kind": "ripple", "speed": 6.5, "from": [26, -12], "box": [44, 24], "dmg": 16, "stun": 20,
				"kb": [2.0, -7.0], "block": 10, "chip": 3, "life": 95, "height": "low", "parry": false},
			"pose": [[0, "crouch"], [11, "slam"], [22, "idle"]], "icon": "slam"},
		"sway": {"name": "Sway", "tab": "special", "kind": "move", "enter": "sway", "interrupt": true, "frames": 36,
			"where": "ground", "aim": "none", "invuln": [2, 9], "pose": [[0, "sway"]], "icon": "sway"},
		"swaykick": {"name": "Sway Kick", "tab": "special", "kind": "attack", "stance": "sway", "frames": 15,
			"where": "ground", "aim": "facing", "motion": [[2, 5, 4.0, 0.0]], "proration": 1,
			"hits": [{"from": 3, "to": 5, "box": [8, -28, 64, 24], "dmg": 20, "stun": 15, "kb": [3.0, 0.0], "block": 7,
				"chip": 1, "group": 0, "height": "low"}],
			"pose": [[0, "sway"], [3, "low_kick"], [10, "idle"]], "icon": "low_kick"},
		"risingheel": {"name": "Rising Heel", "tab": "special", "kind": "attack", "stance": "sway", "frames": 26,
			"where": "ground", "aim": "facing", "motion": [[4, 8, 2.0, 0.0]], "init_invuln": [1, 6], "cancel_into": ["jump", "superjump"],
			"hits": [{"from": 5, "to": 8, "box": [0, -130, 50, 110], "dmg": 34, "stun": 26, "kb": [2.0, -14.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "sway"], [5, "flash_kick"], [15, "fall"]], "icon": "flash_kick"},
		"swaystep": {"name": "Sway Step", "tab": "special", "kind": "move", "stance": "sway", "frames": 14,
			"where": "ground", "aim": "facing", "invuln": [1, 8], "motion": [[1, 10, -11.0, 0.0]],
			"pose": [[0, "sway"], [10, "idle"]], "icon": "sway"},
		"mirror": {"name": "Mirror", "tab": "special", "kind": "counter", "frames": 34, "where": "ground", "aim": "none",
			"window": [3, 24], "counter_move": "mirrorstrike",
			"counter_hit": {"dmg": 42, "stun": 30, "kb": [6.0, -11.0], "group": 0},
			"pose": [[0, "mirror"]], "icon": "mirror"},
		"mirrorstrike": {"name": "Mirror Strike", "tab": "special", "kind": "attack", "hidden": true, "frames": 20,
			"where": "both", "aim": "none", "invuln": [0, 12], "pose": [[0, "side_kick"], [12, "idle"]]},
		"spinthrow": {"name": "Spin Throw", "tab": "special", "kind": "grab", "frames": 32, "where": "ground",
			"aim": "facing", "motion": [[2, 8, 5.0, 0.0]],
			"hits": [{"from": 9, "to": 10, "box": [6, -96, 56, 76], "dmg": 72, "stun": 32, "kb": [13.0, -6.0], "group": 0,
				"knockdown": true, "splat": true}],
			"pose": [[0, "grab_reach"], [10, "spin1"], [14, "throw"], [24, "idle"]], "icon": "spin1"},
		"stomp": {"name": "Stomp", "tab": "attack", "kind": "attack", "frames": 22, "where": "ground", "aim": "facing", "motion": [[2, 8, 5.0, 0.0]],
			"hits": [{"from": 8, "to": 10, "box": [8, -26, 54, 28], "dmg": 26, "stun": 18, "kb": [2.0, -7.0], "block": 8,
				"chip": 2, "group": 0, "height": "low", "otg": true}],
			"pose": [[0, "kick_wind"], [8, "axe_down"], [15, "idle"]], "icon": "axe_down"},
		"airthrow": {"name": "Air Throw", "tab": "attack", "kind": "grab", "air_grab": true, "frames": 20, "where": "air",
			"land_ends": true, "landing": 6,
			"aim": "facing",
			"hits": [{"from": 3, "to": 6, "box": [4, -100, 50, 80], "dmg": 50, "stun": 26, "kb": [-6.0, 9.0],
				"group": 0, "knockdown": true}],
			"pose": [[0, "grab_reach"], [6, "throw"], [14, "fall"]], "icon": "grab_reach"},
		"divekick": {"name": "Dive Kick", "tab": "attack", "kind": "attack", "frames": 32, "where": "air", "aim": "down",
			"motion": [[3, 32, ["px", 12.0], ["pyd", 15.0]]], "land_ends": true, "landing": 8,
			"hits": [{"from": 3, "to": 32, "box": [0, -26, 46, 30], "dmg": 45, "stun": 18, "kb": [5.0, -3.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "dive"]]},
		"airspin": {"name": "Air Spin", "tab": "attack", "kind": "attack", "frames": 24, "where": "air", "aim": "facing",
			"land_ends": true, "landing": 6,
			"hits": [{"from": 5, "to": 12, "box": [-56, -90, 112, 40], "dmg": 36, "stun": 16, "kb": [5.0, -5.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "fall"], [5, "spin1"], [9, "spin2"], [14, "fall"]], "icon": "spin1"},
		# ---- grabs
		"grab": {"name": "Grab", "tab": "attack", "kind": "grab", "frames": 22, "where": "ground", "aim": "facing", "motion": [[2, 6, 5.0, 0.0]],
			"hits": [{"from": 5, "to": 6, "box": [6, -88, 38, 60], "dmg": 50, "stun": 26, "kb": [10.0, -5.0],
				"group": 0, "knockdown": true}],
			"pose": [[0, "grab_reach"], [7, "throw"], [15, "idle"]], "icon": "grab_reach"},
		"hiptoss": {"name": "Hip Toss", "tab": "attack", "kind": "grab", "frames": 34, "where": "ground",
			"aim": "facing", "motion": [[2, 6, 4.0, 0.0]],
			"hits": [{"from": 12, "to": 14, "box": [6, -90, 46, 66], "dmg": 80, "stun": 34, "kb": [-9.0, -9.0],
				"group": 0, "knockdown": true}],
			"pose": [[0, "crouch"], [10, "grab_reach"], [14, "throw"], [26, "idle"]], "icon": "throw"},
		# ---- show-off
		"taunt": {"name": "Taunt", "tab": "defend", "kind": "wait", "interrupt": true, "frames": 50, "where": "ground", "aim": "facing",
			"meter_gain": 125, "pose": [[0, "taunt"]]},
		# ---- supers
		"flurry": {"name": "Flurry", "tab": "super", "kind": "super", "frames": 44, "where": "ground",
			"aim": "facing", "cost": 125, "motion": [[6, 30, 4.0, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 0},
				{"from": 14, "to": 15, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 1},
				{"from": 20, "to": 21, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 2},
				{"from": 28, "to": 30, "box": [8, -100, 70, 50], "dmg": 45, "stun": 28, "kb": [10.0, -8.0], "block": 12, "chip": 5, "group": 3, "splat": true, "min_dmg": 12, "knockdown": true},
			],
			"pose": [[0, "jab_wind"], [8, "jab_hit"], [12, "kick_hit"], [18, "jab_hit"], [24, "spin1"], [28, "heavy_hit"], [36, "idle"]],
			"icon": "kick_hit"},
		"finale": {"name": "Grand Finale", "tab": "super", "kind": "super", "frames": 64, "where": "ground",
			"aim": "facing", "cost": 375, "motion": [[3, 12, 16.0, 0.0]], "invuln": [0, 6],
			"hits": [
				{"from": 10, "to": 11, "box": [6, -96, 70, 60], "dmg": 20, "stun": 16, "kb": [2.0, -1.0], "block": 6, "chip": 2, "group": 0},
				{"from": 16, "to": 17, "box": [6, -96, 70, 60], "dmg": 20, "stun": 16, "kb": [2.0, -1.0], "block": 6, "chip": 2, "group": 1},
				{"from": 22, "to": 23, "box": [6, -96, 70, 60], "dmg": 20, "stun": 16, "kb": [2.0, -1.0], "block": 6, "chip": 2, "group": 2},
				{"from": 28, "to": 29, "box": [6, -96, 70, 60], "dmg": 20, "stun": 16, "kb": [2.0, -1.0], "block": 6, "chip": 2, "group": 3},
				{"from": 34, "to": 35, "box": [6, -96, 70, 60], "dmg": 20, "stun": 18, "kb": [2.0, -1.0], "block": 6, "chip": 2, "group": 4},
				{"from": 44, "to": 47, "box": [-20, -150, 100, 150], "dmg": 70, "stun": 40, "kb": [4.0, -16.0], "block": 16, "chip": 8, "group": 5, "min_dmg": 30, "knockdown": true},
			],
			"pose": [[0, "dash"], [10, "kick_hit"], [16, "spin1"], [22, "jab_hit"], [28, "spin2"], [34, "heavy_hit"],
				[40, "crouch"], [44, "flash_kick"], [54, "fall"]], "icon": "flash_kick"},
		"cyclone": {"name": "Cyclone", "tab": "super", "kind": "super", "frames": 50, "where": "ground",
			"cue": [{"at": 8, "type": "sweep"}, {"at": 20, "type": "sweep"}, {"at": 32, "type": "sweep"}],
			"aim": "facing", "cost": 250, "motion": [[6, 40, 6.0, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 0},
				{"from": 14, "to": 15, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 1},
				{"from": 20, "to": 21, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 2},
				{"from": 26, "to": 27, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 3},
				{"from": 32, "to": 33, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 4},
				{"from": 40, "to": 42, "box": [-60, -110, 120, 60], "dmg": 40, "stun": 30, "kb": [8.0, -11.0], "block": 12, "chip": 6, "group": 5, "min_dmg": 12, "knockdown": true},
			],
			"pose": [[0, "crouch"], [8, "spin1"], [11, "spin2"], [14, "spin1"], [17, "spin2"], [20, "spin1"], [23, "spin2"],
				[26, "spin1"], [29, "spin2"], [32, "spin1"], [35, "spin2"], [40, "flash_kick"], [46, "fall"]],
			"icon": "spin1"},
		# ---- fan-dancer moves (Timmy 21:59: "make the dancer cooler and feel like a dancer. With proper fans. Thinking
		# ---- jade MK series" - MK is study only; our own): a gust off both fans that lifts them, a sliding kick that
		# ---- passes under / through projectiles
		"updraft": {"name": "Updraft", "tab": "special", "kind": "special", "frames": 30, "where": "ground",
			"aim": "facing", "motion": [[2, 8, 4.0, 0.0]], "cue": [{"at": 7, "type": "gust"}, {"at": 7, "type": "sweep_up"}],
			"hits": [{"from": 8, "to": 11, "box": [10, -130, 92, 130], "dmg": 14, "stun": 36, "kb": [1.5, -15.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "fan_low"], [8, "fan_up"], [20, "idle"]], "icon": "fan_up"},
		"glide": {"name": "Silk Glide", "tab": "special", "kind": "attack", "frames": 30, "where": "ground",
			"aim": "facing", "shot_invuln": [2, 18], "motion": [[3, 18, 15.0, 0.0]], "dist": [30, 30, 0.2],
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
			"pose": [[0, "crouch"], [5, "dash"], [10, "idle"]], "icon": "dash"},
		"recall": {"name": "Recall", "tab": "special", "kind": "special", "xf": "fans", "recall_at": 3, "frames": 12,
			"where": "both", "aim": "none", "float": true,
			"pose": [[0, "throw_out"], [3, "throw_wind"], [9, "idle"]], "icon": "throw_wind"},
		# Tempo: a beat for landing or having a move blocked, or dodging through a hit; four = Encore (spends them)
		"encore": {"name": "Encore", "tab": "special", "kind": "attack", "xf": "tempo", "tempo": 4, "no_cancel": true,
			"frames": 46, "where": "ground", "aim": "facing", "motion": [[2, 30, 4.5, 0.0]],
			"cue": {"at": 28, "type": "sweep_up"},
			"hits": [{"from": 6, "to": 8, "box": [4, -96, 64, 70], "dmg": 16, "stun": 18, "kb": [2.0, -1.0], "block": 6,
				"chip": 1, "group": 0},
				{"from": 13, "to": 15, "box": [4, -60, 70, 50], "dmg": 16, "stun": 18, "kb": [2.0, -1.0], "block": 6,
				"chip": 1, "group": 1},
				{"from": 20, "to": 22, "box": [-40, -100, 110, 80], "dmg": 18, "stun": 20, "kb": [2.0, -2.0], "block": 6,
				"chip": 1, "group": 2},
				{"from": 29, "to": 32, "box": [0, -140, 60, 130], "dmg": 34, "stun": 34, "kb": [5.0, -13.0], "block": 12,
				"chip": 3, "group": 3, "knockdown": true}],
			"pose": [[0, "crouch"], [5, "kick_hit"], [12, "low_kick"], [18, "spin1"], [21, "spin2"], [27, "crouch"],
				[29, "flash_kick"], [40, "fall"]], "icon": "spin2"},
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
		"snapstep": {"name": "Snap Step", "tab": "move", "kind": "move", "interrupt": true,
			"frames": 10, "where": "ground", "aim": "facing", "invuln": [1, 4], "motion": [[1, 6, 18.0, 0.0]],
			"dist": [10, 10, 0.3], "pose": [[0, "snap"], [1, "dash"], [7, "snap"]], "icon": "dash"},
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

## One character for now (Timmy 18 Oct 17:52: "Just work on getting one char working and remove the other one").
const ROSTER := {"dancer": DANCER}
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
