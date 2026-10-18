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
##   kind      "move" | "attack" | "grab" | "guard" | "parry" | "wait" | "super" | "burst" | "hold"
##   interrupt true = gives way when anyone else can act (they pick again, or Hold)
##   no_cancel true = landing it doesn't free them at once (most attacks do - a hit cancel)
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
	"guard": {"name": "Guard", "tab": "defend", "kind": "guard", "interrupt": true, "frames": 20, "where": "both", "aim": "none",
		"pose": [[0, "guard"]]},
	"parry_early": {"name": "Parry Early", "tab": "defend", "kind": "parry", "frames": 16, "where": "both",
		"aim": "none", "window": [1, 6], "pose": [[0, "parry"]]},
	"parry_late": {"name": "Parry Late", "tab": "defend", "kind": "parry", "frames": 22, "where": "both",
		"aim": "none", "window": [7, 13], "pose": [[0, "idle"], [6, "parry"]], "icon": "parry"},
	"wait": {"name": "Wait", "tab": "defend", "kind": "wait", "interrupt": true, "frames": 10, "where": "both", "aim": "none",
		"pose": [[0, "idle"]]},
	# ---- only while reeling with a full Burst gauge (Timmy 18:37: "Burst is the move we do to get out of stun lock")
	"burst": {"name": "Burst", "tab": "defend", "kind": "burst", "frames": 26, "where": "both", "aim": "none",
		"float": true, "invuln": [0, 16],
		"hits": [{"from": 2, "to": 5, "box": [-110, -150, 220, 170], "dmg": 0, "stun": 22, "kb": [13.0, -8.0],
			"block": 14, "chip": 0, "group": 0, "away": true}],
		"pose": [[0, "crouch"], [2, "burst"], [18, "fall"]], "icon": "burst"},
	# ---- Hold: carry on with the move running (an interruptible one), or - reeling - ride it out, leaning with the pad
	"hold": {"name": "Hold", "tab": "defend", "kind": "hold", "frames": 1, "where": "both", "aim": "lean",
		"pose": [[0, "guard"]], "icon": "guard"},
}

## The Dancer - the full kit (17:37: "one char that has as many moves as what a YOMIH char would have and see how we
## get that to fit with icons"): fast, light, kicks and footwork.
const DANCER := {
	"stats": {"name": "Dancer", "hp": 450, "weight": 0.85, "width": 34, "height": 104},
	"moves": {
		# ---- moving
		"walk": {"name": "Walk", "tab": "move", "kind": "move", "interrupt": true, "frames": 16, "where": "ground", "aim": "facing",
			"motion": [[0, 13, 4.5, 0.0]], "pose": [[0, "walk1"], [5, "walk2"], [10, "walk1"], [14, "idle"]]},
		"dash": {"name": "Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground", "aim": "facing",
			"motion": [[0, 9, 11.0, 0.0]], "pose": [[0, "dash"], [10, "idle"]]},
		"backstep": {"name": "Back Step", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "ground",
			"aim": "facing", "motion": [[1, 10, -7.0, 0.0]], "invuln": [1, 6],
			"pose": [[0, "crouch"], [4, "fall"], [11, "idle"]], "icon": "fall"},
		"roll": {"name": "Roll", "tab": "move", "kind": "move", "frames": 22, "where": "ground", "aim": "facing",
			"motion": [[2, 17, 8.0, 0.0]], "invuln": [2, 14], "pose": [[0, "crouch"], [2, "roll"], [17, "crouch"]],
			"icon": "roll"},
		"jump": {"name": "Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "ground", "aim": "up",
			"motion": [[1, 1, ["px", 6.5], -13.5]], "pose": [[0, "crouch"], [1, "jump"]], "icon": "jump"},
		"superjump": {"name": "Super Jump", "tab": "move", "kind": "move", "interrupt": true, "frames": 12, "where": "ground",
			"aim": "up", "motion": [[5, 5, ["px", 7.0], -18.0]], "pose": [[0, "crouch"], [5, "jump"]], "icon": "jump"},
		"airdash": {"name": "Air Dash", "tab": "move", "kind": "move", "interrupt": true, "frames": 14, "where": "air", "aim": "dir8",
			"float": true, "motion": [[0, 11, ["px", 10.0], ["py", 10.0]]], "pose": [[0, "dash"]]},
		"fastfall": {"name": "Fast Fall", "tab": "move", "kind": "move", "interrupt": true, "frames": 6, "where": "air", "aim": "none",
			"motion": [[0, 0, 0.0, 15.0]], "pose": [[0, "fall"]]},
		# ---- on the ground
		"jab": {"name": "Jab", "tab": "attack", "kind": "attack", "frames": 13, "where": "ground", "aim": "facing",
			"hits": [{"from": 3, "to": 4, "box": [8, -80, 48, 18], "dmg": 18, "stun": 12, "kb": [2.0, 0.0],
				"block": 6, "chip": 1, "group": 0}],
			"pose": [[0, "jab_wind"], [3, "jab_hit"], [8, "idle"]]},
		"straight": {"name": "Straight", "tab": "attack", "kind": "attack", "frames": 20, "where": "ground",
			"aim": "facing", "motion": [[5, 8, 3.0, 0.0]],
			"hits": [{"from": 7, "to": 9, "box": [10, -82, 66, 20], "dmg": 32, "stun": 16, "kb": [5.0, -1.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "jab_wind"], [7, "straight"], [13, "idle"]]},
		"lowkick": {"name": "Low Kick", "tab": "attack", "kind": "attack", "frames": 16, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 5, "to": 6, "box": [6, -30, 58, 24], "dmg": 22, "stun": 14, "kb": [2.0, 0.0],
				"block": 8, "chip": 1, "group": 0}],
			"pose": [[0, "crouch"], [5, "low_kick"], [10, "idle"]]},
		"sidekick": {"name": "Side Kick", "tab": "attack", "kind": "attack", "frames": 24, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 8, "to": 10, "box": [12, -66, 78, 22], "dmg": 40, "stun": 18, "kb": [9.0, -2.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "kick_wind"], [8, "side_kick"], [15, "idle"]]},
		"uppercut": {"name": "Uppercut", "tab": "attack", "kind": "attack", "no_cancel": true, "frames": 26, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 6, "to": 9, "box": [4, -120, 46, 70], "dmg": 38, "stun": 26, "kb": [1.5, -12.0],
				"block": 12, "chip": 3, "group": 0}],
			"pose": [[0, "crouch"], [6, "uppercut"], [16, "idle"]]},
		"spin": {"name": "Spin Kick", "tab": "attack", "kind": "attack", "frames": 26, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 7, "to": 12, "box": [-64, -94, 128, 40], "dmg": 50, "stun": 20, "kb": [6.0, -5.0],
				"block": 12, "chip": 4, "group": 0}],
			"pose": [[0, "crouch"], [7, "spin1"], [10, "spin2"], [14, "idle"]], "icon": "spin2"},
		"sweep": {"name": "Sweep", "tab": "attack", "kind": "attack", "frames": 28, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 9, "to": 11, "box": [10, -22, 84, 22], "dmg": 30, "stun": 34, "kb": [3.0, -3.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "crouch"], [9, "sweep"], [18, "crouch"], [24, "idle"]]},
		"axekick": {"name": "Axe Kick", "tab": "attack", "kind": "attack", "frames": 32, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 15, "to": 17, "box": [10, -110, 56, 90], "dmg": 60, "stun": 22, "kb": [4.0, 4.0],
				"block": 14, "chip": 5, "group": 0}],
			"pose": [[0, "kick_wind"], [8, "axe_up"], [15, "axe_down"], [24, "idle"]], "icon": "axe_up"},
		"kneedash": {"name": "Knee Dash", "tab": "attack", "kind": "attack", "frames": 26, "where": "ground",
			"aim": "facing", "motion": [[4, 14, 9.0, 0.0]],
			"hits": [{"from": 6, "to": 14, "box": [10, -70, 40, 34], "dmg": 34, "stun": 18, "kb": [6.0, -3.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "dash"], [5, "knee"], [17, "idle"]]},
		"flashkick": {"name": "Flash Kick", "tab": "attack", "kind": "attack", "no_cancel": true, "frames": 30, "where": "ground",
			"aim": "facing", "invuln": [1, 8], "motion": [[4, 10, 1.0, -6.0]],
			"hits": [{"from": 4, "to": 9, "box": [-4, -140, 56, 120], "dmg": 48, "stun": 28, "kb": [3.0, -13.0],
				"block": 14, "chip": 4, "group": 0}],
			"pose": [[0, "crouch"], [4, "flash_kick"], [14, "fall"]]},
		# ---- in the air
		"airkick": {"name": "Air Kick", "tab": "air", "kind": "attack", "frames": 18, "where": "air", "aim": "facing",
			"hits": [{"from": 4, "to": 8, "box": [6, -66, 60, 24], "dmg": 24, "stun": 14, "kb": [4.0, -1.0],
				"block": 8, "chip": 1, "group": 0}],
			"pose": [[0, "kick_wind"], [4, "kick_hit"], [12, "fall"]]},
		"airknee": {"name": "Air Knee", "tab": "air", "kind": "attack", "frames": 16, "where": "air", "aim": "facing",
			"hits": [{"from": 3, "to": 6, "box": [6, -80, 40, 36], "dmg": 28, "stun": 16, "kb": [5.0, -4.0],
				"block": 8, "chip": 2, "group": 0}],
			"pose": [[0, "knee"], [10, "fall"]]},
		"divekick": {"name": "Dive Kick", "tab": "air", "kind": "attack", "frames": 32, "where": "air", "aim": "down",
			"motion": [[3, 32, ["px", 9.0], ["pyd", 12.0]]], "land_ends": true, "landing": 8,
			"hits": [{"from": 3, "to": 32, "box": [0, -26, 46, 30], "dmg": 45, "stun": 18, "kb": [5.0, -3.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "dive"]]},
		"airspin": {"name": "Air Spin", "tab": "air", "kind": "attack", "frames": 24, "where": "air", "aim": "facing",
			"hits": [{"from": 5, "to": 12, "box": [-56, -90, 112, 40], "dmg": 36, "stun": 16, "kb": [5.0, -5.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "fall"], [5, "spin1"], [9, "spin2"], [14, "fall"]], "icon": "spin1"},
		# ---- grabs
		"grab": {"name": "Grab", "tab": "grab", "kind": "grab", "frames": 22, "where": "ground", "aim": "facing",
			"hits": [{"from": 5, "to": 6, "box": [6, -88, 38, 60], "dmg": 50, "stun": 26, "kb": [10.0, -5.0],
				"group": 0}],
			"pose": [[0, "grab_reach"], [7, "throw"], [15, "idle"]], "icon": "grab_reach"},
		"hiptoss": {"name": "Hip Toss", "tab": "grab", "kind": "grab", "frames": 34, "where": "ground",
			"aim": "facing",
			"hits": [{"from": 12, "to": 14, "box": [6, -90, 46, 66], "dmg": 80, "stun": 34, "kb": [-9.0, -9.0],
				"group": 0}],
			"pose": [[0, "crouch"], [10, "grab_reach"], [14, "throw"], [26, "idle"]], "icon": "throw"},
		# ---- show-off
		"taunt": {"name": "Taunt", "tab": "defend", "kind": "wait", "interrupt": true, "frames": 50, "where": "ground", "aim": "facing",
			"meter_gain": 25, "pose": [[0, "taunt"]]},
		# ---- supers
		"flurry": {"name": "Flurry", "tab": "super", "kind": "super", "frames": 44, "where": "ground",
			"aim": "facing", "cost": 50, "motion": [[6, 30, 2.0, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 0},
				{"from": 14, "to": 15, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 1},
				{"from": 20, "to": 21, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 2},
				{"from": 28, "to": 30, "box": [8, -100, 70, 50], "dmg": 45, "stun": 28, "kb": [10.0, -8.0], "block": 12, "chip": 5, "group": 3},
			],
			"pose": [[0, "jab_wind"], [8, "jab_hit"], [12, "kick_hit"], [18, "jab_hit"], [24, "spin1"], [28, "heavy_hit"], [36, "idle"]],
			"icon": "kick_hit"},
		"cyclone": {"name": "Cyclone", "tab": "super", "kind": "super", "frames": 50, "where": "ground",
			"aim": "facing", "cost": 75, "motion": [[6, 40, 4.0, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 0},
				{"from": 14, "to": 15, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 1},
				{"from": 20, "to": 21, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 2},
				{"from": 26, "to": 27, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 3},
				{"from": 32, "to": 33, "box": [-50, -96, 100, 50], "dmg": 18, "stun": 12, "kb": [2.0, -1.0], "block": 5, "chip": 2, "group": 4},
				{"from": 40, "to": 42, "box": [-60, -110, 120, 60], "dmg": 40, "stun": 30, "kb": [8.0, -11.0], "block": 12, "chip": 6, "group": 5},
			],
			"pose": [[0, "crouch"], [8, "spin1"], [11, "spin2"], [14, "spin1"], [17, "spin2"], [20, "spin1"], [23, "spin2"],
				[26, "spin1"], [29, "spin2"], [32, "spin1"], [35, "spin2"], [40, "flash_kick"], [46, "fall"]],
			"icon": "spin1"},
	},
}

## One character for now (Timmy 18 Oct 17:52: "Just work on getting one char working and remove the other one").
const ROSTER := {"dancer": DANCER}
## The menu's tabs, in order: [id, name].
const TABS := [["attack", "Attack"], ["air", "Air"], ["grab", "Grab"], ["move", "Move"], ["defend", "Defend"],
	["super", "Super"]]


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
