class_name Sim
extends RefCounted
## The match: fighters on a flat stage, stepped 60 times a second. It runs until any fighter is free to act, then stops;
## everyone free picks a move in secret (apply), and it runs on (run_segment) - the simultaneous-turn idea. No graphics,
## no randomness: the same state and the same picks always play out the same, so the host's sim is the match and the
## phones replay the segments it sends for show.
##
## Who beats what: a strike beats a grab, a grab beats guard and parry, guard takes a strike (chip damage), a parry at
## the right frame stuns the striker, two strikes meeting clash (both stopped), armour soaks strikes but not grabs.

const STAGE_HALF := 800.0
const GRAVITY := 0.6
const MAX_FALL := 15.0
const FRICTION := 0.8
const SEGMENT_CAP := 900      ## ticks a segment may run without a decision (a safety net - 15 s)
const CLASH_LOCK := 10
const CLASH_PUSH := 5.0
const PARRY_STUN := 18
const TECH_LOCK := 12
const METER_MAX := 100
const DEFAULT := {"move": "wait"}   ## a pick that never came (a turn timer ran out)

var fighters: Array[Fighter] = []
var mode := "ffa"        ## "ffa" | "teams"
var tick := 0
var events: Array = []   ## this segment's: {t, type, a, d, dmg}


## A new match. players: [{name, character, team}] (team only read in "teams" mode) - spread across the stage, each
## facing the middle.
static func create(players: Array, match_mode := "ffa") -> Sim:
	var s := Sim.new()
	s.mode = match_mode
	var n := players.size()
	for i in n:
		var p: Dictionary = players[i]
		var f := Fighter.new()
		f.id = i
		f.character = str(p.get("character", "bruiser"))
		f.name = str(p.get("name", "P%d" % (i + 1)))
		f.team = int(p.get("team", i)) if match_mode == "teams" else i
		var st := Moves.stats(f.character)
		f.max_hp = int(st["hp"])
		f.hp = f.max_hp
		var x := lerpf(-STAGE_HALF * 0.75, STAGE_HALF * 0.75, (i + 0.5) / n) if n > 1 else 0.0
		f.pos = Vector2(x, 0.0)
		f.facing = 1 if x <= 0.0 else -1
		s.fighters.append(f)
	return s


func get_f(id: int) -> Fighter:
	return fighters[id] if id >= 0 and id < fighters.size() else null


func enemies(a: Fighter, b: Fighter) -> bool:
	return a.id != b.id and a.team != b.team


func alive() -> Array[Fighter]:
	var out: Array[Fighter] = []
	out.assign(fighters.filter(func(f: Fighter) -> bool: return not f.ko))
	return out


func over() -> bool:
	var teams := {}
	for f in alive():
		teams[f.team] = true
	return teams.size() <= 1


## The ids still standing when it's over (one fighter, or one team's survivors; empty = everyone fell together).
func winners() -> Array[int]:
	var out: Array[int] = []
	if over():
		for f in alive():
			out.append(f.id)
	return out


## Who has to choose now (empty while it runs, or when it's over).
func deciders() -> Array[int]:
	var out: Array[int] = []
	if over():
		return out
	for f in fighters:
		if f.actionable():
			out.append(f.id)
	return out


## The moves this fighter can pick right now (ids), in menu order.
func legal_moves(id: int) -> Array[String]:
	var f := get_f(id)
	var out: Array[String] = []
	if f == null or not f.actionable():
		return out
	var air := not f.grounded()
	var all := Moves.of(f.character)
	for mid: String in all:
		var m: Dictionary = all[mid]
		var where := str(m["where"])
		if (air and where == "ground") or (not air and where == "air"):
			continue
		if int(m.get("cost", 0)) > f.meter:
			continue
		if mid == "airdash" and f.air_moves >= 1:
			continue
		out.append(mid)
	return out


func nearest_enemy(f: Fighter) -> Fighter:
	var best: Fighter = null
	for g in alive():
		if enemies(f, g) and (best == null or absf(g.pos.x - f.pos.x) < absf(best.pos.x - f.pos.x)):
			best = g
	return best


## Start the picked moves: choices = {fighter id: {move, x, y}} - (x, y) is the picked direction (Sim.aim fits it to
## the move). A pick that isn't legal becomes a wait.
func apply(choices: Dictionary) -> void:
	for id in choices:
		var f := get_f(int(id))
		if f == null or not f.actionable():
			continue
		_start(f, choices[id])


func _start(f: Fighter, c: Dictionary) -> void:
	var mid := str(c.get("move", "wait"))
	if not legal_moves(f.id).has(mid):
		c = DEFAULT
		mid = "wait"
	var m := Moves.move(f.character, mid)
	f.param = aim(str(m.get("aim", "none")), Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0))), f.facing)
	if absf(f.param.x) > 0.2:
		f.facing = 1 if f.param.x > 0.0 else -1   # (aimed left or right - they turn that way)
	f.length = int(m["frames"])
	f.meter -= int(m.get("cost", 0))
	if mid == "airdash":
		f.air_moves += 1
	f.move = mid
	f.frame = 0
	f.instance += 1
	f.hit_done.clear()


## A picked direction made to fit the move (17:37 Timmy: "Just have the direction functionality"): "facing" -> ← or →
## (straight up / down or nothing keeps the way they face), "up" / "down" -> only those halves, "dir8" -> as picked,
## "none" -> nothing. A unit vector (or zero).
static func aim(kind: String, d: Vector2, facing: int) -> Vector2:
	match kind:
		"facing":
			return Vector2(signf(d.x) if absf(d.x) > 0.2 else float(facing), 0.0)
		"up":
			var u := Vector2(d.x, minf(d.y, -0.3)) if d.length() > 0.01 else Vector2(0.0, -1.0)
			return u.normalized()
		"down":
			var w := Vector2(d.x, maxf(d.y, 0.3)) if d.length() > 0.01 else Vector2(float(facing) * 0.7, 0.7)
			return w.normalized()
		"dir8":
			return d.normalized() if d.length() > 0.01 else Vector2(float(facing), 0.0)
	return Vector2.ZERO


## Run until someone has to choose (or it's over): every tick's picture for playback and what happened.
func run_segment(cap := SEGMENT_CAP) -> Dictionary:
	events.clear()
	var frames: Array = []
	for _i in cap:
		step()
		frames.append(record())
		if over() or not deciders().is_empty():
			break
	return {"frames": frames, "events": events.duplicate(), "end_tick": tick}


## What a picked move would do (the ghost preview): a copy of the match with these picks, every other fighter who's
## free standing still, run `ticks` ticks whatever happens -> {frames, events} (the events say what lands on whom - a
## dash into someone mid-swing shows you getting hit).
func preview(choices: Dictionary, ticks := 90) -> Dictionary:
	var copy := Sim.from_dict(to_dict())
	var all := {}
	for id in copy.deciders():
		all[id] = choices.get(id, {"move": "wait"})
	copy.apply(all)
	var frames: Array = []
	for _i in ticks:
		copy.step()
		frames.append(copy.record())
		var free := copy.deciders()
		if not free.is_empty():   # (whoever's free again stands still - the preview keeps going)
			var hold := {}
			for id in free:
				hold[id] = {"move": "wait"}
			copy.apply(hold)
	return {"frames": frames, "events": copy.events}


## One tick: the moves push their fighters, gravity and the stage, hits, then every counter ticks down.
func step() -> void:
	tick += 1
	for f in fighters:
		_motion(f)
	for f in fighters:
		_physics(f)
	_separate()
	var hit_now := _resolve_hits()
	for f in fighters:
		if not hit_now.has(f.id):
			_count(f)


func _val(v: Variant, f: Fighter) -> float:
	if v is Array:
		var k := float(v[1])
		match str(v[0]):
			"px":
				return f.param.x * k
			"py":
				return f.param.y * k
			"pyd":   # (down only, at least a little - a dive kick)
				return maxf(absf(f.param.y), 0.35) * k
	return float(v)


func _motion(f: Fighter) -> void:
	if f.ko or f.stun > 0 or f.blockstun > 0 or f.lock > 0 or f.move == "":
		return
	var m := Moves.move(f.character, f.move)
	for seg: Array in m.get("motion", []):
		if f.frame >= int(seg[0]) and f.frame <= int(seg[1]):
			var vx := _val(seg[2], f)
			f.vel.x = vx if seg[2] is Array else vx * f.facing   # (a picked direction is already left / right)
			f.vel.y = _val(seg[3], f)


func _floating(f: Fighter) -> bool:
	return f.move != "" and f.stun == 0 and bool(Moves.move(f.character, f.move).get("float", false))


func _physics(f: Fighter) -> void:
	var was_air := f.pos.y < 0.0
	if not _floating(f) and (f.pos.y < 0.0 or f.vel.y < 0.0):
		f.vel.y = minf(f.vel.y + GRAVITY, MAX_FALL)
	f.pos += f.vel
	if f.pos.y >= 0.0:
		f.pos.y = 0.0
		if f.vel.y > 0.0:
			f.vel.y = 0.0
		if was_air:
			f.air_moves = 0
			if f.move != "" and bool(Moves.move(f.character, f.move).get("land_ends", false)):
				f.lock = int(Moves.move(f.character, f.move).get("landing", 6))
				f.move = ""
		# sliding to a stop (knockback, the end of a step) unless a move is pushing them this frame
		if not _pushing(f):
			f.vel.x *= FRICTION
			if absf(f.vel.x) < 0.05:
				f.vel.x = 0.0
	var half := float(Moves.stats(f.character)["width"]) / 2.0
	if absf(f.pos.x) > STAGE_HALF - half:
		f.pos.x = signf(f.pos.x) * (STAGE_HALF - half)
		f.vel.x = 0.0


func _pushing(f: Fighter) -> bool:
	if f.move == "" or f.stun > 0 or f.blockstun > 0 or f.lock > 0:
		return false
	for seg: Array in Moves.move(f.character, f.move).get("motion", []):
		if f.frame >= int(seg[0]) and f.frame <= int(seg[1]):
			return true
	return false


## Bodies don't stand inside each other (KO'd ones excepted).
func _separate() -> void:
	var standing := alive()
	for i in standing.size():
		for j in range(i + 1, standing.size()):
			var a := standing[i]
			var b := standing[j]
			if absf(a.pos.y - b.pos.y) > 60.0:
				continue
			var need := (float(Moves.stats(a.character)["width"]) + float(Moves.stats(b.character)["width"])) / 2.0
			var dx := b.pos.x - a.pos.x
			if absf(dx) < need:
				var side := signf(dx) if absf(dx) > 0.01 else (1.0 if a.id < b.id else -1.0)
				var push := (need - absf(dx)) / 2.0
				a.pos.x -= side * push
				b.pos.x += side * push


func _count(f: Fighter) -> void:
	if f.ko:
		return
	if f.stun > 0:
		f.stun -= 1
		if f.stun == 0:
			f.combo = 0
	elif f.blockstun > 0:
		f.blockstun -= 1
	elif f.lock > 0:
		f.lock -= 1
	elif f.move != "":
		f.frame += 1
		if f.frame >= f.length:
			f.meter = mini(METER_MAX, f.meter + int(Moves.move(f.character, f.move).get("meter_gain", 0)))
			f.move = ""
			f.frame = 0


func hurtbox(f: Fighter) -> Rect2:
	var st := Moves.stats(f.character)
	var w := float(st["width"])
	var h := float(st["height"])
	return Rect2(f.pos.x - w / 2.0, f.pos.y - h, w, h)


## A move's hit box in the world (facing flips it).
func hitbox(f: Fighter, entry: Dictionary) -> Rect2:
	var b: Array = entry["box"]
	var x := float(b[0])
	var w := float(b[2])
	var left := f.pos.x + x if f.facing == 1 else f.pos.x - x - w
	return Rect2(left, f.pos.y + float(b[1]), w, float(b[3]))


## The hit entries live this tick (none while reeling).
func active_hits(f: Fighter) -> Array:
	var out: Array = []
	if f.ko or f.move == "" or f.stun > 0 or f.blockstun > 0 or f.lock > 0:
		return out
	var m := Moves.move(f.character, f.move)
	for e: Dictionary in m.get("hits", []):
		if f.frame >= int(e["from"]) and f.frame <= int(e["to"]):
			out.append(e)
	return out


## In a move's invulnerable frames (a roll, a flash kick's start) - nothing touches them.
func invulnerable(f: Fighter) -> bool:
	if f.move == "" or f.stun > 0:
		return false
	var inv: Array = Moves.move(f.character, f.move).get("invuln", [])
	return not inv.is_empty() and f.frame >= int(inv[0]) and f.frame <= int(inv[1])


func _kind(f: Fighter) -> String:
	return str(Moves.move(f.character, f.move).get("kind", "")) if f.move != "" else ""


func _event(type: String, a: Fighter, d: Fighter, dmg := 0) -> void:
	events.append({"t": tick, "type": type, "a": a.id, "d": d.id if d != null else -1, "dmg": dmg})


## Every hit this tick, worked out from the state at its start and applied together (trades happen). Returns the ids
## hit / blocked / stopped this tick (their counters don't tick down the same tick).
func _resolve_hits() -> Dictionary:
	var touched := {}
	# what each fighter is doing before anything lands
	var kind := {}
	var frame := {}
	var live := {}
	for f in fighters:
		kind[f.id] = _kind(f)
		frame[f.id] = f.frame
		live[f.id] = active_hits(f)
	# clashes: two enemies' strikes meeting - both stopped
	var clashed := {}
	for a in alive():
		for b in alive():
			if a.id >= b.id or not enemies(a, b) or kind[a.id] == "grab" or kind[b.id] == "grab":
				continue
			for ea: Dictionary in live[a.id]:
				for eb: Dictionary in live[b.id]:
					if not clashed.has(a.id) and hitbox(a, ea).intersects(hitbox(b, eb)):
						clashed[a.id] = b
						clashed[b.id] = a
	for id in clashed:
		var f := get_f(int(id))
		f.move = ""
		f.lock = CLASH_LOCK
		f.vel.x = -f.facing * CLASH_PUSH
		touched[f.id] = true
		if f.id < (clashed[id] as Fighter).id:
			_event("clash", f, clashed[id])
	# strikes, then grabs (a grabber struck this tick doesn't grab)
	var struck := {}
	for pass_grabs in [false, true]:
		for a in alive():
			if clashed.has(a.id) or (kind[a.id] == "grab") != pass_grabs:
				continue
			if pass_grabs and struck.has(a.id):
				continue
			for e: Dictionary in live[a.id]:
				var box := hitbox(a, e)
				for d in fighters:
					if d.ko or not enemies(a, d) or not box.intersects(hurtbox(d)) or invulnerable(d):
						continue
					var key := "%d:%d" % [int(e.get("group", 0)), d.id]
					if a.hit_done.has(key):
						continue
					if pass_grabs:
						if _grab(a, d, e, kind, live):
							a.hit_done[key] = true
							touched[a.id] = true
							touched[d.id] = true
					else:
						a.hit_done[key] = true
						_strike(a, d, e, kind[d.id], frame[d.id])
						struck[d.id] = true
						touched[d.id] = true
	for f in fighters:
		f.meter = clampi(f.meter, 0, METER_MAX)
		if not f.ko and f.hp <= 0:
			f.hp = 0
			f.ko = true
			f.move = ""
			f.stun = 0
			f.blockstun = 0
			f.lock = 0
			_event("ko", f, null)
	return touched


func _strike(a: Fighter, d: Fighter, e: Dictionary, d_kind: String, d_frame: int) -> void:
	var dmg := int(e["dmg"])
	var dm := Moves.move(d.character, d.move) if d.move != "" else {}
	var reeling := d.stun > 0
	if d_kind == "parry" and not reeling:
		var win: Array = dm.get("window", [0, 0])
		if d_frame >= int(win[0]) and d_frame <= int(win[1]):
			a.move = ""
			a.stun = PARRY_STUN
			a.vel = Vector2.ZERO
			d.move = ""
			d.meter += 15
			_event("parry", d, a)
			return
	if (d_kind == "guard" or d.blockstun > 0) and not reeling:
		var chip := int(e.get("chip", 0))
		d.hp -= chip
		d.blockstun = int(e.get("block", 8))
		d.vel.x = a.facing * 3.0
		a.meter += 2
		d.meter += 3
		_event("block", a, d, chip)
		return
	if d.move != "" and dm.has("armor") and not reeling:
		var arm: Array = dm["armor"]
		if d_frame >= int(arm[0]) and d_frame <= int(arm[1]):
			d.hp -= dmg
			a.meter += dmg / 6
			_event("armor", a, d, dmg)
			return
	_hurt(a, d, e, "hit")


func _hurt(a: Fighter, d: Fighter, e: Dictionary, type: String) -> void:
	var scale := maxf(0.35, 1.0 - 0.12 * d.combo)
	var dmg := int(round(float(e["dmg"]) * scale))
	d.hp -= dmg
	d.stun = int(e["stun"])
	d.move = ""
	d.blockstun = 0
	d.lock = 0
	d.combo += 1
	var kb: Array = e["kb"]
	var weight := float(Moves.stats(d.character)["weight"])
	d.vel = Vector2(float(kb[0]) * a.facing, float(kb[1])) / weight
	d.facing = -a.facing
	a.meter += dmg / 5
	d.meter += dmg / 8
	_event(type, a, d, dmg)


## A grab connects on someone standing who isn't reeling; two grabs meeting push apart (a tech).
func _grab(a: Fighter, d: Fighter, e: Dictionary, kind: Dictionary, live: Dictionary) -> bool:
	if not d.grounded() or d.stun > 0 or d.blockstun > 0:
		return false
	if kind[d.id] == "grab":
		for ed: Dictionary in live[d.id]:
			if hitbox(d, ed).intersects(hurtbox(a)):
				for f in [a, d]:
					f.move = ""
					f.lock = TECH_LOCK
					f.vel.x = -f.facing * CLASH_PUSH
				_event("tech", a, d)
				return true
	_hurt(a, d, e, "throw")
	return true


## One tick's picture of every fighter, for playback: [x, y, facing, move, frame, state, hp, meter].
## state: 0 free / in a move, 1 hit, 2 blocking, 3 locked, 4 KO.
func record() -> Array:
	var out: Array = []
	for f in fighters:
		var state := 4 if f.ko else (1 if f.stun > 0 else (2 if f.blockstun > 0 else (3 if f.lock > 0 else 0)))
		out.append([f.pos.x, f.pos.y, f.facing, f.move, f.frame, state, f.hp, f.meter])
	return out


func to_dict() -> Dictionary:
	return {"mode": mode, "tick": tick, "fighters": fighters.map(func(f: Fighter) -> Dictionary: return f.to_dict())}


static func from_dict(d: Dictionary) -> Sim:
	var s := Sim.new()
	s.mode = str(d["mode"])
	s.tick = int(d["tick"])
	for fd: Dictionary in d["fighters"]:
		s.fighters.append(Fighter.from_dict(fd))
	return s
