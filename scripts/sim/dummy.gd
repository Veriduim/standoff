class_name Dummy
extends Bot
## The training dummy (Timmy 19 Oct 02:28 - "1": a practice mode for combos like Uppercut -> Jump -> Air Knee). It does
## what it's set to - stand there, block (the height your move calls for), jump, attack, or fight like a Normal bot -
## and in a combo it just takes it: no Burst, no lean (except fighting).

const MODES := ["Stand", "Block", "Jump", "Attack", "Fight"]

var mode := "Stand"


func _init(seed_value := 1) -> void:
	super(seed_value, 1)


func choose(sim: Sim, id: int) -> Dictionary:
	if mode == "Fight":
		return super(sim, id)
	var f := sim.get_f(id)
	var t := sim.nearest_enemy(f)
	if sim.reeling(f):   # (it takes the combo - no Burst, no lean)
		return {"move": "hold"}
	if f.down > 0:
		return {"move": "getup"}
	var legal := sim.legal_moves(id)
	if legal.has("hold") and not f.actionable():
		return {"move": "hold"}
	var toward := 1.0
	if t != null and absf(t.pos.x - f.pos.x) > 1.0:
		toward = signf(t.pos.x - f.pos.x)
	match mode:
		"Block":
			if legal.has("block"):
				var read := _read(t) if t != null else {}
				return {"move": "block", "y": 1.0 if str(read.get("height", "mid")) == "low" else -1.0}
		"Jump":
			if legal.has("jump"):
				return {"move": "jump", "x": 0.0, "y": -1.0}
			return {"move": "wait"}
		"Attack":
			var hits := ["jab", "straight", "sweep", "sidekick", "fanslash"].filter(func(m: String) -> bool:
				return legal.has(m))
			if not hits.is_empty():
				return {"move": str(hits[rng.randi() % hits.size()]), "x": toward}
	return {"move": "wait"}
