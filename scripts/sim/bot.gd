class_name Bot
extends RefCounted
## A simple opponent - fills empty seats and plays the test matches. It reads the stage the way a new player would: get
## close to the nearest enemy, then mix strikes, grabs, guard and parries, with the odd super when there's meter. Every
## pick is a move and a direction (toward that enemy). Seeded, so a test match plays the same every time.

const GROUND_HITS := ["jab", "straight", "lowkick", "sidekick", "uppercut", "spin", "sweep", "axekick", "kneedash",
	"flashkick"]
const AIR := ["divekick", "airkick", "airknee", "airspin", "airdash", "fastfall", "block", "wait"]
const GRABS := ["grab", "hiptoss"]
const SUPERS := ["flurry", "cyclone"]
const CLOSE_IN := ["walk", "dash", "roll", "kneedash"]
const BACK_OFF := ["backstep", "walk", "dash"]

var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


## What the enemy's running attack will do next: {frame: how many ticks until its next hit is out, height}.
func _read(t: Fighter) -> Dictionary:
	if t.move == "":
		return {}
	for e: Dictionary in Moves.move(t.character, t.move).get("hits", []):
		if int(e["from"]) > t.frame:
			return {"frame": int(e["from"]) - t.frame, "height": str(e.get("height", "mid"))}
	return {}


func choose(sim: Sim, id: int) -> Dictionary:
	var f := sim.get_f(id)
	var t := sim.nearest_enemy(f)
	if sim.reeling(f):   # (in a combo: Burst once it's a real combo or it's low - not on every first hit - else lean away)
		var low := float(f.hp) < 0.35 * float(f.max_hp)
		if sim.can_burst(f) and (f.combo >= 3 or low) and rng.randf() < 0.5:
			return {"move": "burst"}
		var away := -signf(t.pos.x - f.pos.x) if t != null and absf(t.pos.x - f.pos.x) > 1.0 else 0.0
		return {"move": "hold", "x": away, "y": rng.randf_range(-1.0, 0.3)}
	var legal := sim.legal_moves(id)
	if t == null or legal.is_empty():
		return {"move": "wait"}
	if f.down > 0:   # (floored: mostly up on the spot, sometimes a roll either way, now and then stay down)
		var r0 := rng.randf()
		if r0 < 0.5:
			return {"move": "getup"}
		if r0 < 0.8:
			return {"move": "techroll", "x": 1.0 if rng.randf() < 0.5 else -1.0}
		return {"move": "hold"}
	if legal.has("whiff"):   # (stuck in a move with someone close and free: sometimes cut it)
		return {"move": "whiff" if absf(t.pos.x - f.pos.x) < 160.0 and rng.randf() < 0.2 else "hold"}
	if legal.has("hold") and rng.randf() < 0.45:   # (mid-move that gives way: often carries on)
		return {"move": "hold"}
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
	if t.down > 0 and legal.has("stomp") and dist < 90.0 and rng.randf() < 0.6:   # (they're down: stomp them)
		c["move"] = "stomp"
		return c
	if legal.has("burstcancel") and rng.randf() < 0.15:
		return {"move": "burstcancel"}
	var r := rng.randf()
	if f.meter >= Sim.BAR and r < 0.08:   # (supers now and then - meter comes quickly the wiki's way)
		c["move"] = pick.call(SUPERS)
	elif r < 0.55:
		c["move"] = pick.call(GROUND_HITS)
	elif r < 0.68:
		c["move"] = pick.call(GRABS)
	elif r < 0.86:   # (a block - the height their move calls for; often reading the frame it lands on to parry)
		c["move"] = "block" if r < 0.8 else "pushblock"
		var read := _read(t)
		c["y"] = 1.0 if str(read.get("height", "mid")) == "low" else -1.0
		if rng.randf() < 0.5:
			c["pf"] = int(read.get("frame", 0))
	else:
		c["move"] = pick.call(BACK_OFF)
		if c["move"] != "backstep":
			c["x"] = -toward
	c["free"] = f.fc > 0 and rng.randf() < 0.5   # (Free Cancel on about half its attacks while it has charges)
	c["dist"] = rng.randf_range(30.0, 100.0)
	return c
