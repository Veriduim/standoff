class_name Moves
extends RefCounted
## Every character's moves as data (the sim reads these; nothing here runs). An original roster - Your Only Move Is
## HUSTLE is the reference for how a simultaneous-turn fighter plays, nothing more (Timmy, 18 Oct 2026: our own game).
##
## Units: world pixels and ticks (60 a second). A fighter's origin is between their feet; y grows DOWN (the ground is
## y = 0, up is negative). Every x is relative to the way the fighter faces (+x = in front).
##
## A move:
##   name      shown in the menu
##   kind      "move" | "attack" | "grab" | "guard" | "parry" | "wait" | "super"
##   frames    how long it lasts (a param can stretch it - see `param`)
##   where     "ground" | "air" | "both" - where it can be started
##   param     what the player picks with it: "" none | "dir" a direction (x, y) | "dist" -1..1 along the ground |
##             "frames" a length (min..max in `range`) | "frame" a parry frame (min..max in `range`)
##   motion    [[from, to, vx, vy], ...] velocity set on those frames (vx in front); "param" in a slot = the picked
##             value times the number after it, e.g. ["px", 11] = picked x * 11
##   hits      [{from, to, box: [x, y, w, h], dmg, stun, kb: [x, y], block, chip, group}] - one hit per group per
##             target; a grab's entry is the throw
##   armor     [from, to] - strikes in this window hurt but don't stop the move (grabs still do)
##   land_ends true = the move ends when they touch the ground (and `landing` frames of lag follow)
##   cost      meter it needs (supers)
##   pose      [[frame, pose name], ...] for the stick figure (scripts/ui/poses.gd); eased into the next entry

const COMMON := {
	"wait": {"name": "Wait", "kind": "wait", "frames": 10, "where": "both", "param": "frames", "range": [4, 40],
		"pose": [[0, "idle"]]},
	"guard": {"name": "Guard", "kind": "guard", "frames": 20, "where": "both", "param": "frames", "range": [8, 40],
		"pose": [[0, "guard"]]},
	"parry": {"name": "Parry", "kind": "parry", "frames": 20, "where": "both", "param": "frame", "range": [1, 14],
		"window": 3, "pose": [[0, "parry"]]},
}

const BRUISER := {
	"stats": {"name": "Bruiser", "hp": 600, "walk": 3.5, "jump": 12.5, "weight": 1.2, "width": 44, "height": 112},
	"moves": {
		"step": {"name": "Step", "kind": "move", "frames": 16, "where": "ground", "param": "dist",
			"motion": [[0, 13, ["px", 6.0], 0.0]], "pose": [[0, "walk1"], [5, "walk2"], [10, "walk1"], [14, "idle"]]},
		"jump": {"name": "Jump", "kind": "move", "frames": 8, "where": "ground", "param": "dir",
			"motion": [[2, 2, ["px", 5.0], -12.5]], "pose": [[0, "crouch"], [2, "jump"]]},
		"jab": {"name": "Jab", "kind": "attack", "frames": 18, "where": "ground", "param": "",
			"hits": [{"from": 6, "to": 8, "box": [10, -96, 56, 24], "dmg": 30, "stun": 16, "kb": [3.0, 0.0],
				"block": 10, "chip": 2, "group": 0}],
			"pose": [[0, "jab_wind"], [6, "jab_hit"], [11, "idle"]]},
		"haymaker": {"name": "Haymaker", "kind": "attack", "frames": 34, "where": "ground", "param": "",
			"motion": [[6, 10, 3.0, 0.0]], "armor": [5, 12],
			"hits": [{"from": 12, "to": 15, "box": [8, -108, 74, 44], "dmg": 90, "stun": 26, "kb": [9.0, -6.0],
				"block": 16, "chip": 8, "group": 0}],
			"pose": [[0, "heavy_wind"], [12, "heavy_hit"], [22, "idle"]]},
		"grab": {"name": "Grab", "kind": "grab", "frames": 26, "where": "ground", "param": "",
			"hits": [{"from": 6, "to": 8, "box": [8, -92, 44, 64], "dmg": 70, "stun": 30, "kb": [8.0, -8.0],
				"group": 0}],
			"pose": [[0, "grab_reach"], [9, "throw"], [18, "idle"]]},
		"drop": {"name": "Body Drop", "kind": "attack", "frames": 40, "where": "air", "param": "",
			"motion": [[3, 40, 1.0, 14.0]], "land_ends": true, "landing": 10,
			"hits": [{"from": 3, "to": 40, "box": [-12, -34, 56, 40], "dmg": 60, "stun": 20, "kb": [5.0, -4.0],
				"block": 12, "chip": 5, "group": 0}],
			"pose": [[0, "dive"]]},
		"slam": {"name": "Ground Slam", "kind": "super", "frames": 42, "where": "ground", "param": "", "cost": 50,
			"armor": [0, 16],
			"hits": [{"from": 15, "to": 19, "box": [-90, -64, 180, 64], "dmg": 120, "stun": 32, "kb": [6.0, -10.0],
				"block": 20, "chip": 12, "group": 0}],
			"pose": [[0, "heavy_wind"], [15, "slam"], [28, "idle"]]},
	},
}

const DANCER := {
	"stats": {"name": "Dancer", "hp": 450, "walk": 5.0, "jump": 13.5, "weight": 0.85, "width": 34, "height": 104},
	"moves": {
		"dash": {"name": "Dash", "kind": "move", "frames": 12, "where": "ground", "param": "dist",
			"motion": [[0, 9, ["px", 11.0], 0.0]], "pose": [[0, "dash"], [10, "idle"]]},
		"jump": {"name": "Jump", "kind": "move", "frames": 6, "where": "ground", "param": "dir",
			"motion": [[1, 1, ["px", 6.5], -13.5]], "pose": [[0, "crouch"], [1, "jump"]]},
		"airdash": {"name": "Air Dash", "kind": "move", "frames": 14, "where": "air", "param": "dir", "float": true,
			"motion": [[0, 11, ["px", 10.0], ["py", 10.0]]], "pose": [[0, "dash"]]},
		"kick": {"name": "Quick Kick", "kind": "attack", "frames": 14, "where": "both", "param": "",
			"hits": [{"from": 4, "to": 5, "box": [8, -72, 62, 22], "dmg": 22, "stun": 14, "kb": [2.0, 0.0],
				"block": 8, "chip": 1, "group": 0}],
			"pose": [[0, "kick_wind"], [4, "kick_hit"], [9, "idle"]]},
		"spin": {"name": "Spin Kick", "kind": "attack", "frames": 26, "where": "ground", "param": "",
			"hits": [{"from": 7, "to": 12, "box": [-64, -94, 128, 40], "dmg": 50, "stun": 20, "kb": [6.0, -5.0],
				"block": 12, "chip": 4, "group": 0}],
			"pose": [[0, "crouch"], [7, "spin1"], [10, "spin2"], [14, "idle"]]},
		"divekick": {"name": "Dive Kick", "kind": "attack", "frames": 32, "where": "air", "param": "dir",
			"motion": [[3, 32, ["px", 9.0], ["pyd", 12.0]]], "land_ends": true, "landing": 8,
			"hits": [{"from": 3, "to": 32, "box": [0, -26, 46, 30], "dmg": 45, "stun": 18, "kb": [5.0, -3.0],
				"block": 10, "chip": 3, "group": 0}],
			"pose": [[0, "dive"]]},
		"grab": {"name": "Grab", "kind": "grab", "frames": 22, "where": "ground", "param": "",
			"hits": [{"from": 5, "to": 6, "box": [6, -88, 38, 60], "dmg": 50, "stun": 26, "kb": [10.0, -5.0],
				"group": 0}],
			"pose": [[0, "grab_reach"], [7, "throw"], [15, "idle"]]},
		"flurry": {"name": "Flurry", "kind": "super", "frames": 44, "where": "ground", "param": "", "cost": 50,
			"motion": [[6, 30, 2.0, 0.0]],
			"hits": [
				{"from": 8, "to": 9, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 0},
				{"from": 14, "to": 15, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 1},
				{"from": 20, "to": 21, "box": [8, -90, 60, 40], "dmg": 25, "stun": 14, "kb": [1.0, 0.0], "block": 6, "chip": 3, "group": 2},
				{"from": 28, "to": 30, "box": [8, -100, 70, 50], "dmg": 45, "stun": 28, "kb": [10.0, -8.0], "block": 12, "chip": 5, "group": 3},
			],
			"pose": [[0, "jab_wind"], [8, "jab_hit"], [12, "kick_hit"], [18, "jab_hit"], [24, "spin1"], [28, "heavy_hit"], [36, "idle"]]},
	},
}

const ROSTER := {"bruiser": BRUISER, "dancer": DANCER}


## A character's full move list: their own plus the shared ones.
static func of(character: String) -> Dictionary:
	var out: Dictionary = (ROSTER[character]["moves"] as Dictionary).duplicate()
	out.merge(COMMON)   # (their own moves first in the menu)
	return out


static func stats(character: String) -> Dictionary:
	return ROSTER[character]["stats"]


static func move(character: String, id: String) -> Dictionary:
	return of(character).get(id, {})
