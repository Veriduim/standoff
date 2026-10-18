class_name Bot
extends RefCounted
## A simple opponent - fills empty seats and plays the test matches. It reads the stage the way a new player would: get
## close to the nearest enemy, then mix strikes, grabs, guard and parries, with the odd super when there's meter. Every
## pick is a move and a direction (toward that enemy). Seeded, so a test match plays the same every time.

const GROUND_HITS := ["jab", "straight", "lowkick", "sidekick", "uppercut", "spin", "sweep", "axekick", "kneedash",
	"flashkick"]
const AIR := ["divekick", "airkick", "airknee", "airspin", "airdash", "fastfall", "guard", "wait"]
const GRABS := ["grab", "hiptoss"]
const SUPERS := ["flurry", "cyclone"]
const CLOSE_IN := ["walk", "dash", "roll", "kneedash"]
const BACK_OFF := ["backstep", "walk", "dash"]

var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


func choose(sim: Sim, id: int) -> Dictionary:
	var f := sim.get_f(id)
	var legal := sim.legal_moves(id)
	var t := sim.nearest_enemy(f)
	if t == null or legal.is_empty():
		return {"move": "wait"}
	var dx := t.pos.x - f.pos.x
	var toward := signf(dx) if absf(dx) > 1.0 else float(f.facing)
	var dist := absf(dx)
	var pick := func(ids: Array) -> String:
		var ok := ids.filter(func(m: String) -> bool: return legal.has(m))
		return str(ok[rng.randi() % ok.size()]) if not ok.is_empty() else "wait"
	var c := {"x": toward, "y": 0.0}
	if not f.grounded():
		c["move"] = pick.call(AIR)
		c["y"] = 0.8 if c["move"] == "divekick" else rng.randf_range(-0.6, 0.6)
		return c
	if dist > 170.0:
		var r0 := rng.randf()
		if r0 < 0.18:
			c["move"] = pick.call(["jump", "superjump"])
			c["x"] = toward * 0.7
			c["y"] = -1.0
		elif r0 < 0.22:
			c["move"] = pick.call(["taunt", "wait"])
		else:
			c["move"] = pick.call(CLOSE_IN)
		return c
	var r := rng.randf()
	if f.meter >= 50 and r < 0.2:
		c["move"] = pick.call(SUPERS)
	elif r < 0.55:
		c["move"] = pick.call(GROUND_HITS)
	elif r < 0.68:
		c["move"] = pick.call(GRABS)
	elif r < 0.8:
		c["move"] = "guard"
	elif r < 0.9:
		c["move"] = pick.call(["parry_early", "parry_late"])
	else:
		c["move"] = pick.call(BACK_OFF)
		if c["move"] != "backstep":
			c["x"] = -toward
	return c
