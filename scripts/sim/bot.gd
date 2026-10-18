class_name Bot
extends RefCounted
## A simple opponent - fills empty seats and plays the test matches. It reads the stage the way a new player would: get
## close to the nearest enemy, then mix strikes, grabs, guard and parries, with the odd super when there's meter. Seeded,
## so a test match plays the same every time.

var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


func choose(sim: Sim, id: int) -> Dictionary:
	var f := sim.get_f(id)
	var legal := sim.legal_moves(id)
	var t := sim.nearest_enemy(f)
	if t == null or legal.is_empty():
		return {"move": "wait", "x": 8.0}
	var dx := t.pos.x - f.pos.x
	var dist := absf(dx)
	var ahead := 1.0 if (dx >= 0.0) == (f.facing == 1) else -1.0   # (a step is in front / behind the way they face)
	var pick := func(ids: Array) -> String:
		var ok := ids.filter(func(m: String) -> bool: return legal.has(m))
		return str(ok[rng.randi() % ok.size()]) if not ok.is_empty() else "wait"
	var c := {"target": t.id}
	if not f.grounded():
		var mv: String = pick.call(["drop", "divekick", "kick", "airdash", "guard", "wait"])
		c["move"] = mv
		c["x"] = signf(dx) * 0.6
		c["y"] = 0.8 if mv == "divekick" else rng.randf_range(-0.6, 0.6)
		if mv == "wait":
			c["x"] = 6.0
		return c
	if dist > 160.0:
		if rng.randf() < 0.2:
			c["move"] = pick.call(["jump"])
			c["x"] = signf(dx) * 0.7
			c["y"] = -1.0
		else:
			c["move"] = pick.call(["step", "dash"])
			c["x"] = ahead * rng.randf_range(0.6, 1.0)
		return c
	var r := rng.randf()
	if f.meter >= 50 and r < 0.25:
		c["move"] = pick.call(["slam", "flurry"])
	elif r < 0.55:
		c["move"] = pick.call(["jab", "kick", "haymaker", "spin"])
	elif r < 0.7:
		c["move"] = pick.call(["grab"])
	elif r < 0.82:
		c["move"] = "guard"
		c["x"] = rng.randi_range(10, 24)
	elif r < 0.92:
		c["move"] = "parry"
		c["x"] = rng.randi_range(2, 10)
	else:
		c["move"] = pick.call(["step", "dash"])
		c["x"] = -ahead * 0.7
	return c
