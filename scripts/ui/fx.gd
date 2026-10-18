class_name Fx
extends RefCounted
## The stage's hit effects - the first style pass (Timmy, 18 Oct 18:07: "Your suggestion looks good" - picks 4, 5, 6, 9
## from the YOMI study; our own drawing, the study is reference only):
##   sparks    a spiky burst where a hit lands, rings and squares flying on along the hit, chips, a white shockwave on
##             big hits; a guard arc on a block, a glint on a parry, an orange flash on a clash, a big double ring on a KO
##   freeze    the playback holds still a moment on contact (hitstop) - longer for harder hits; the one hit shakes in
##             place; a small screen shake (kept small - in Life After Dark he found a big shake "way too much")
##   combos    the hit count and damage over whoever is being comboed, in the hitter's colour
##   arcs      the striking hand or foot leaves a pale arc while its hit is out
## The second, flashier pass (18:35: "Im excited to see the flashy animations and burst effects"; scenery and the floor
## reflection left out, "those are mods"):
##   impacts   a hard hit flashes the one hit white for a few frames and throws out impact lines (the speed streaks
##             across the stage went at 19:41: "They kind of look like rain. Remove those")
##   supers    the stage dims round the one starting it, light rays and rings burst out of them, everything holds a
##             moment and the picture splits into colours (pick 13); KOs split too
##   after     fast movers leave fading copies of themselves (pick 8)
## Positions are world px (StageView draws them through its camera). The screens read frozen() before playing on.

const YELLOW := Color("#ffd23f")
const HOT := Color("#fff6cf")
const BLOCK := Color("#a6dcff")
const ORANGE := Color("#ff9f1c")
const TRAIL_KEEP := 10       ## ticks of a limb's path kept for its arc (a longer sweep)
const TRAIL_FADE := 0.12     ## seconds an arc takes to fade once the hit's over
const INNER := 0.38          ## a swoosh's inner edge, as a share of the way from the joint to the tip (a fuller crescent)
const COMBO_HOLD := 0.8      ## seconds a finished combo's count stays up, then fades over COMBO_FADE
const COMBO_FADE := 0.4

var parts: Array = []        ## {k: kind, p: world pos, v: px/s, age, life, c: colour, s: size, r: angle, w: spin, sp}
var hitstop := 0.0           ## seconds the playback holds (frozen())
var jitter: Array = []       ## ids shaking in place during the freeze
var shake := 0.0             ## screen px, fading
var offset := Vector2.ZERO   ## this frame's shake (StageView adds it to the camera)
var combos := {}             ## victim id -> {hits, dmg, by: colour, pop: 1 -> 0, end: -1 live / seconds since it ended}
var trails := {}             ## fighter id -> {pts: [[tip, pivot], ...], c: colour, fade: -1 live / seconds}
var flash := {}              ## fighter id -> seconds they're drawn white (the impact frame)
var afters: Array = []       ## afterimages: {id, rec: Sim.record row, age, life}
const BIG := 1.3              ## every effect this much bigger (22:40 "elevate this a lot")
const INK := Color("#3b3f52")    ## the dark starburst behind a hit (23:05)
var dim := 0.0               ## how dark the stage goes round a super (0-1); `dim_id` is drawn over it
var dim_id := -1
var split := 0.0             ## the colour split (0-1, fading) - the screens' post shader reads it
var punch := 0.0             ## the camera's push-in on a big hit (a share of the zoom, fading)
var split_at := Vector2.ZERO ## (world) where it splits from
var _rng := RandomNumberGenerator.new()
static var _bold: FontVariation


func frozen() -> bool:
	return hitstop > 0.0


func clear() -> void:
	parts.clear()
	jitter.clear()
	combos.clear()
	trails.clear()
	flash.clear()
	punch = 0.0
	afters.clear()
	hitstop = 0.0
	shake = 0.0
	dim = 0.0
	dim_id = -1
	split = 0.0
	offset = Vector2.ZERO


## One sim event at a world point. `face` = the hitter's facing (sparks fly on along the hit), `reeling` = the one hit
## was already reeling (the combo goes on).
func on_event(type: String, at: Vector2, face: float, dmg: int, by: Color, victim: int, victim_col: Color,
		reeling: bool, seed_n: int, counter := false, push := false) -> void:
	_rng.seed = seed_n
	match type:
		"down":   # (floored: dust both ways along the ground)
			for i in 10:
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("chip", at, Vector2(side * _rng.randf_range(120.0, 320.0), _rng.randf_range(-160.0, -40.0)),
						_rng.randf_range(0.25, 0.45), Color("#9a9daa"), _rng.randf_range(3.0, 6.0))
			_add("shock", at, Vector2.ZERO, 0.2, Color("#c9ccd8"), 40.0)
			kick(2.0)
		"shot":   # (a throw: a quick flash at the hand)
			_add("shock", at, Vector2.ZERO, 0.14, by.lightened(0.5), 26.0)
		"countered":   # (Mirror: a big white flash and MIRROR)
			_add("glint", at, Vector2.ZERO, 0.3, Color.WHITE, 80.0)
			_add("shock", at, Vector2.ZERO, 0.32, by.lightened(0.4), 110.0)
			_add("text", at + Vector2(0, -70), Vector2(0, -40), 0.7, Color.WHITE, 30.0)
			parts[-1]["txt"] = "MIRROR!"
			splash(0.5, at)
			freeze(0.18, victim)
			kick(4.0)
		"bounce":   # (off the ground: a flat shockwave and dust - small and grey, 22:57 no massive white circles)
			_add("shock", at, Vector2.ZERO, 0.22, Color("#9a9daa"), 38.0)
			for i in 10:
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("chip", at, Vector2(side * _rng.randf_range(150.0, 360.0), _rng.randf_range(-260.0, -80.0)),
						_rng.randf_range(0.3, 0.5), Color("#b9bcc8"), _rng.randf_range(3.0, 6.0))
			freeze(0.07, victim)
			kick(4.0)
		"splat":   # (stuck to the wall: a big impact on it)
			_add("spokes", at, Vector2.ZERO, 0.22, Color.WHITE, 70.0)
			_add("shock", at, Vector2.ZERO, 0.3, victim_col.lightened(0.4), 90.0)
			_add("text", at + Vector2(-face * 70.0, -60), Vector2(0, -30), 0.7, Color.WHITE, 26.0)
			parts[-1]["txt"] = "WALL SPLAT"
			splash(0.4, at)
			freeze(0.12, victim)
			kick(6.0)
		"ic":   # (an Instant Cancel: a purple snap)
			_add("shock", at, Vector2.ZERO, 0.18, Color("#c58bff"), 50.0)
			_add("text", at + Vector2(0, -64), Vector2(0, -40), 0.5, Color("#c58bff"), 18.0)
			parts[-1]["txt"] = "INSTANT CANCEL"
		"whiff":   # (a Whiff Cancel: a quick white ring off them)
			_add("shock", at, Vector2.ZERO, 0.18, Color.WHITE, 46.0)
			_add("text", at + Vector2(0, -60), Vector2(0, -50), 0.5, Color.WHITE, 18.0)
			parts[-1]["txt"] = "WHIFF CANCEL"
		"edge":   # (a spacer's hit at the fan's edge: a gold glint)
			_add("glint", at, Vector2.ZERO, 0.32, Color("#ffd23f"), 34.0)
		"blink":   # (Fan Step: a flash where she lands, a ring of her colour)
			_add("glow", at, Vector2.ZERO, 0.25, by.lightened(0.4), 60.0)
			_add("sweep", at, Vector2.ZERO, 0.25, by, 70.0, 0.0)
		"sweep", "sweep_up":   # (a giant fan swept out in her colour - Violet's arc in the mod study; up for Updraft)
			_add("sweep", at, Vector2.ZERO, 0.3, by, 92.0, face if type == "sweep" else 0.0)
		"gust":   # (Updraft: wind off both fans, rushing up in front of her)
			for k in 9:
				var off := Vector2(face * _rng.randf_range(-20.0, 60.0), _rng.randf_range(-20.0, 30.0))
				_add("wind", at + off, Vector2(face * _rng.randf_range(0.0, 80.0), -_rng.randf_range(650.0, 950.0)),
						_rng.randf_range(0.35, 0.5), Color("#dff3ff"), _rng.randf_range(26.0, 44.0))
		"beat":   # (Tempo: a beat - a small pink flick off her, no word: Tempo's always on now, it'd be noise)
			_add("glint", at + Vector2(0, -40), Vector2(0, -60), 0.3, Color("#ff7ab6"), 14.0)
		"onbeat":   # (Tempo full: ON BEAT!)
			_add("shock", at, Vector2.ZERO, 0.3, Color("#ff7ab6"), 70.0)
			_add("text", at + Vector2(0, -80), Vector2(0, -40), 0.9, Color("#ff7ab6"), 24.0)
			parts[-1]["txt"] = "ON BEAT!"
		"catch", "recall":   # (Fans: one back in hand / called home - a gold ring)
			_add("shock", at, Vector2.ZERO, 0.18, Color("#ffd23f"), 34.0 if type == "catch" else 64.0)
		"form_snap", "form_floor", "form_flow":   # (Forms: into one - its name)
			_add("shock", at, Vector2.ZERO, 0.2, Color("#9fd8ff"), 50.0)
			_add("text", at + Vector2(0, -70), Vector2(0, -40), 0.6, Color("#9fd8ff"), 20.0)
			parts[-1]["txt"] = type.trim_prefix("form_").to_upper()
		"sad":   # (Sadness building: SAD!)
			_add("text", at + Vector2(0, -80), Vector2(0, -40), 0.9, Color("#7fa6ff"), 24.0)
			parts[-1]["txt"] = "SAD!"
		"sadness":   # (SADNESS!: a blue wash and the word)
			_add("text", at + Vector2(0, -80), Vector2(0, -40), 1.2, Color("#5d7bd6"), 30.0)
			parts[-1]["txt"] = "SADNESS!"
			_add("shock", at, Vector2.ZERO, 0.4, Color("#5d7bd6"), 120.0)
		"time":   # (the round's out)
			_add("text", at + Vector2(0, -120), Vector2.ZERO, 1.6, Color.WHITE, 64.0)
			parts[-1]["txt"] = "TIME!"
			splash(0.6, at)
			freeze(0.4, -1)
		"wall":   # (launched into the wall and off it)
			_add("shock", at, Vector2.ZERO, 0.2, Color("#9a9daa"), 34.0)
			_add("spokes", at, Vector2.ZERO, 0.14, Color.WHITE, 40.0)
			for i in 6:
				_add("chip", at, Vector2(-face * _rng.randf_range(150.0, 380.0), _rng.randf_range(-300.0, 80.0)),
						_rng.randf_range(0.3, 0.5), Color("#c9ccd8"), _rng.randf_range(3.0, 6.0))
			freeze(0.06, victim)
			kick(3.0)
		"hit", "throw", "armor":
			var s := clampf(float(dmg) / 32.0, 0.5, 1.8)
			if type == "throw":   # (a dark sphere closes round the two of them - the mods' grabs)
				_add("bubble", at, Vector2.ZERO, 0.5, Color("#05060a"), 72.0)
			# (23:05 "This is an example of the normal hit effect": a dark jagged starburst behind it, longest along
			# the hit - the YOMI mods' look; low contrast, so the fighters and sparks read on top)
			_add("ink", at, Vector2.ZERO, 0.42, INK, 60.0 + 26.0 * s, face)
			_burst(at, face, s, by, victim_col)
			if counter:   # (they were mid-attack: a red COUNTER and a harder flash)
				_add("text", at + Vector2(0, -40), Vector2(0, -50), 0.42, Color("#ff5d5d"), 17.0)   # (small - they're common)
				parts[-1]["txt"] = "COUNTER"
				flash[victim] = 0.08
			if dmg >= 30:   # (a hard one: impact lines in the hitter's colour, the one hit flashes white - no big white
				# ring any more: 22:57 "I dont love the massive white circle thing")
				_add("spokes", at, Vector2.ZERO, 0.14, by.lightened(0.55), 34.0 * s)
				flash[victim] = 0.06
			if dmg >= 45:
				splash(0.35, at)
			freeze(clampf(0.04 + float(dmg) * 0.0018, 0.05, 0.14), victim)
			kick(clampf(float(dmg) * 0.1, 1.5, 5.0))
			if type != "armor":
				_count(victim, dmg, by, reeling)
		"block":   # (a guard arc - red when blocked at the wrong height; a big one and PUSH for a Push Block)
			_add("guard", at, Vector2.ZERO, 0.2 if not push else 0.3, Color("#ff7a7a") if counter else BLOCK,
					30.0 if not push else 48.0, -face)
			if push:
				_add("text", at + Vector2(0, -50), Vector2(0, -40), 0.5, BLOCK, 18.0)
				parts[-1]["txt"] = "PUSH"
			for i in 4:
				_add("chip", at, _fan(-face, 1.3) * _rng.randf_range(160.0, 320.0), _rng.randf_range(0.2, 0.32),
						Color.WHITE, _rng.randf_range(2.5, 4.0))
			freeze(0.04, victim)
			kick(1.0)
		"parry":
			_add("glint", at, Vector2.ZERO, 0.26, Color.WHITE, 58.0)
			_add("text", at + Vector2(0, -56), Vector2(0, -40), 0.55, Color.WHITE, 22.0)
			parts[-1]["txt"] = "PARRY"
			_add("shock", at, Vector2.ZERO, 0.2, BLOCK, 44.0)
			freeze(0.12, -1)
			kick(2.0)
		"clash", "tech":
			var big := type == "clash"
			_add("star", at, Vector2.ZERO, 0.16, ORANGE, 30.0 if big else 20.0)
			for i in (8 if big else 4):
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("box" if i % 3 else "ring", at, _fan(side, 1.0) * _rng.randf_range(220.0, 480.0),
						_rng.randf_range(0.25, 0.4), ORANGE if i % 2 else YELLOW, _rng.randf_range(3.0, 6.0))
			freeze(0.08 if big else 0.05, -1)
			kick(2.5 if big else 1.5)
		"ko":
			_add("shock", at, Vector2.ZERO, 0.42, victim_col.lightened(0.35), 150.0)
			_add("shock", at, Vector2.ZERO, 0.3, Color.WHITE, 96.0)
			for i in 14:
				_add("chip", at, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(200.0, 560.0),
						_rng.randf_range(0.4, 0.7), victim_col if i % 3 else Color.WHITE, _rng.randf_range(3.0, 6.0))
			_add("spokes", at, Vector2.ZERO, 0.2, Color.WHITE, 90.0)
			flash[victim] = 0.12
			splash(0.8, at)
			freeze(0.22, victim)
			kick(6.0)


## Someone bursts out of a combo: a white flash bursts out of them, shards and rings fly, everything nearby is blown
## back (the sim), it holds a moment and splits.
func burst_out(id: int, at: Vector2, col: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	_add("flash", at, Vector2.ZERO, 0.32, Color.WHITE, 150.0)
	_add("shock", at, Vector2.ZERO, 0.42, col.lightened(0.5), 210.0)
	_add("rays", at, Vector2.ZERO, 0.35, Color.WHITE, 170.0)
	for i in 18:
		var dir := Vector2.from_angle(TAU * float(i) / 18.0 + _rng.randf_range(-0.15, 0.15))
		_add("shard", at + dir * 30.0, dir * _rng.randf_range(420.0, 820.0), _rng.randf_range(0.35, 0.6),
				Color("#9fe8ff") if i % 3 else col.lightened(0.5), _rng.randf_range(10.0, 20.0))
	flash[id] = 0.1   # (no confetti rings or white ring - 23:11, 00:22)
	splash(0.9, at)
	freeze(0.3, -1)
	kick(5.0)


## Someone starts a super: the stage dims round them, rays and rings burst out, it all holds a moment and splits.
func super_start(id: int, at: Vector2, col: Color, seed_n: int, title := "") -> void:
	_rng.seed = seed_n
	if title != "":   # (its name, big, over them)
		_add("text", at + Vector2(0, -150), Vector2(0, -24), 0.95, col.lightened(0.55), 46.0)
		parts[-1]["txt"] = title.to_upper()
	dim = 0.62
	dim_id = id
	_add("rays", at, Vector2.ZERO, 0.4, col.lightened(0.45), 190.0)
	_add("glow", at, Vector2.ZERO, 0.45, col, 95.0)
	_add("shock", at, Vector2.ZERO, 0.4, col.lightened(0.3), 170.0)
	_add("floorring", Vector2(at.x, 0.0), Vector2.ZERO, 1.1, col, 130.0)   # (a ring of her colour glowing on the floor -
	# Yharim's; no confetti shapes - 23:11)
	splash(1.0, at)
	freeze(0.3, -1)
	kick(3.0)


## A stretch of ribbon along the floor (Silk Glide), from a to b (world), fading from where it was laid.
func ribbon(a: Vector2, b: Vector2, c: Color) -> void:
	parts.append({"k": "ribbon", "p": a, "b": b, "v": Vector2.ZERO, "age": 0.0, "life": 0.45, "c": c, "s": 9.0,
		"r": 0.0, "w": 0.0, "x": 0.0})


## Dust off the ground (a landing, feet sliding): grey bits kicked out both ways, low.
func dust(at: Vector2, s: float, seed_n: int) -> void:
	_rng.seed = seed_n
	for i in int(4 + 6 * s):
		var side := 1.0 if i % 2 == 0 else -1.0
		_add("chip", at + Vector2(side * _rng.randf_range(4.0, 14.0), -2.0),
				Vector2(side * _rng.randf_range(80.0, 260.0) * s, -_rng.randf_range(40.0, 160.0) * s),
				_rng.randf_range(0.2, 0.38), Color("#8d909c"), _rng.randf_range(2.5, 5.0))
	if s > 0.7:
		kick(1.0 + s)


## The colour split (the post shader): `amount` 0-1, from a world point.
func splash(amount: float, at: Vector2) -> void:
	if amount >= split:
		split_at = at
	split = maxf(split, amount)


## A fading copy of a fast mover (StageView calls it every couple of ticks they're quick).
func afterimage(id: int, rec: Array) -> void:
	afters.append({"id": id, "rec": rec.duplicate(), "age": 0.0, "life": 0.32})


func freeze(seconds: float, who: int) -> void:
	hitstop = maxf(hitstop, seconds * 1.35)   # (a hit holds a little longer - it lands harder)
	if who >= 0 and not jitter.has(who):
		jitter.append(who)


func kick(px: float) -> void:
	px *= 1.3
	shake = maxf(shake, px)
	punch = maxf(punch, clampf(px * 0.012, 0.0, 0.08))


## The burst where a hit lands: a spiky star (the dark starburst goes behind it - on_event).
## (23:11 "remove the random shapes on hit as well": no flying rings, squares or chips - the spark and the dark
## starburst behind it carry the hit)
func _burst(at: Vector2, _face: float, s: float, _by: Color, _victim_col: Color) -> void:
	_add("star", at, Vector2.ZERO, 0.15 + 0.05 * s, YELLOW, 30.0 * s)


## A direction fanned round the way a hit goes (a little upward).
func _fan(face: float, spread: float) -> Vector2:
	var ang := Vector2(face, -0.35).angle() + _rng.randf_range(-spread, spread)
	return Vector2.from_angle(ang)


func _add(kind: String, at: Vector2, vel: Vector2, life: float, c: Color, size: float, extra := 0.0) -> void:
	size *= BIG if kind != "text" else 1.12   # (22:40 "We dont do things big enough": every effect bigger)
	life *= 1.15
	vel *= BIG
	var p := {"k": kind, "p": at, "v": vel, "age": 0.0, "life": life, "c": c, "s": size, "r": _rng.randf() * TAU,
		"w": _rng.randf_range(-9.0, 9.0), "x": extra}
	if kind == "star":
		var sp: Array = []
		for i in 12:
			sp.append(_rng.randf_range(0.65, 1.0) if i % 2 == 0 else 0.34)
		p["sp"] = sp
	if kind == "ink":   # (spikes: long and uneven, the longest along the hit's way (extra = facing) and up / down)
		var sp: Array = []
		var n := 18
		for i in n * 2:
			var ang := float(p["r"]) + i * PI / n
			if i % 2 == 1:
				sp.append(_rng.randf_range(0.22, 0.38))
				continue
			var along := absf(cos(ang - (0.0 if extra >= 0.0 else PI)))
			sp.append(_rng.randf_range(0.45, 0.8) + 0.35 * along * (1.0 if cos(ang) * extra > 0.0 else 0.6))
		p["sp"] = sp
	parts.append(p)


func _count(victim: int, dmg: int, by: Color, reeling: bool) -> void:
	if victim < 0:
		return
	var c: Dictionary = combos.get(victim, {})
	if reeling and not c.is_empty() and float(c["end"]) < 0.0:
		c["hits"] = int(c["hits"]) + 1
		c["dmg"] = int(c["dmg"]) + dmg
		c["by"] = by
		c["pop"] = 1.0
	else:
		combos[victim] = {"hits": 1, "dmg": dmg, "by": by, "pop": 1.0, "end": -1.0}


## A combo ends when its victim stops reeling (or goes down) - the count then stays a moment and fades.
func settle_combos(frame: Array) -> void:
	for id: int in combos:
		var c: Dictionary = combos[id]
		if float(c["end"]) < 0.0 and (id >= frame.size() or int(frame[id][5]) != 1):
			c["end"] = 0.0


## A striking limb's tip and the joint it swings from (world), each tick its hit is out.
func trail_point(id: int, tip: Vector2, pivot: Vector2, c: Color) -> void:
	var t: Dictionary = trails.get(id, {})
	if t.is_empty() or float(t["fade"]) >= 0.0:
		t = {"pts": [], "c": c, "fade": -1.0}
		trails[id] = t
	var pts: Array = t["pts"]
	pts.append([tip, pivot])
	if pts.size() > TRAIL_KEEP:
		pts.pop_front()


func trail_end(id: int) -> void:
	if trails.has(id) and float(trails[id]["fade"]) < 0.0:
		trails[id]["fade"] = 0.0


func update(delta: float) -> void:
	hitstop = maxf(0.0, hitstop - delta)
	if hitstop <= 0.0:
		jitter.clear()
	for p: Dictionary in parts:
		p["age"] = float(p["age"]) + delta
		var v: Vector2 = p["v"]
		if p["k"] == "chip":
			v.y += 1100.0 * delta
			v *= pow(0.3, delta)
		else:
			v *= pow(0.02, delta)
		p["v"] = v
		p["p"] = (p["p"] as Vector2) + v * delta
		p["r"] = float(p["r"]) + float(p["w"]) * delta
	parts = parts.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	shake *= pow(0.5, delta / 0.05)
	if shake < 0.3:
		shake = 0.0
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shake
	for id: int in combos.keys():
		var c: Dictionary = combos[id]
		c["pop"] = maxf(0.0, float(c["pop"]) - delta / 0.15)
		if float(c["end"]) >= 0.0:
			c["end"] = float(c["end"]) + delta
			if float(c["end"]) > COMBO_HOLD + COMBO_FADE:
				combos.erase(id)
	for id: int in trails.keys():
		if float(trails[id]["fade"]) >= 0.0:
			trails[id]["fade"] = float(trails[id]["fade"]) + delta
			if float(trails[id]["fade"]) > TRAIL_FADE:
				trails.erase(id)
	for a: Dictionary in afters:
		a["age"] = float(a["age"]) + delta
	afters = afters.filter(func(a: Dictionary) -> bool: return float(a["age"]) < float(a["life"]))
	for id: int in flash.keys():
		flash[id] = float(flash[id]) - delta
		if float(flash[id]) <= 0.0:
			flash.erase(id)
	if hitstop <= 0.0:   # (the dim holds through a super's freeze, then lifts)
		dim = maxf(0.0, dim - delta * 2.2)
		if dim <= 0.0:
			dim_id = -1
	split = maxf(0.0, split - delta * 2.6)
	punch = maxf(0.0, punch - delta * 0.25)


# ---------- drawing (through the stage's camera) ----------

## The arcs: pale, see-through, thin at the tail and widest at the limb's tip.
func draw_trails(st: StageView) -> void:
	for id: int in trails:
		var t: Dictionary = trails[id]
		var raw: Array = t["pts"]
		if raw.size() < 2:
			continue
		# (between two ticks the tip swings round its joint - an arc, not a straight cut). The swoosh fills what the
		# lower limb swept: from the tip in to a little past halfway to the joint.
		var outer: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for k in raw.size():
			var a: Array = raw[k]
			var b: Array = raw[mini(k + 1, raw.size() - 1)]
			var ra := ((a[0] as Vector2) - (a[1] as Vector2))
			var rb := ((b[0] as Vector2) - (b[1] as Vector2))
			for s in (4 if k < raw.size() - 1 else 1):
				var u := float(s) / 4.0
				var pivot := (a[1] as Vector2).lerp(b[1], u)
				var arm := Vector2.from_angle(lerp_angle(ra.angle(), rb.angle(), u)) * lerpf(ra.length(), rb.length(), u)
				outer.append(st.w2s(pivot + arm))
				inner.append(st.w2s(pivot + arm * INNER))
		var span := 0.0
		for k in outer.size() - 1:
			span += outer[k].distance_to(outer[k + 1])
		if span < 12.0:
			continue
		var fade := 1.0 if float(t["fade"]) < 0.0 else 1.0 - float(t["fade"]) / TRAIL_FADE
		var col := (t["c"] as Color).lerp(Color.WHITE, 0.55)
		var n := outer.size()
		var cols: Array[Color] = []
		for k in n:
			var c := col
			c.a = 0.85 * smoothstep(0.0, 0.55, float(k) / float(n - 1)) * fade
			cols.append(c)
		for k in n - 1:   # (raw triangles - a thin tail would fail draw_polygon's triangulation)
			st.draw_primitive(PackedVector2Array([outer[k], outer[k + 1], inner[k + 1]]),
					PackedColorArray([cols[k], cols[k + 1], cols[k + 1]]), PackedVector2Array())
			st.draw_primitive(PackedVector2Array([outer[k], inner[k + 1], inner[k]]),
					PackedColorArray([cols[k], cols[k + 1], cols[k]]), PackedVector2Array())
		# a bright rim along the tip's path
		var rim := PackedVector2Array()
		var rim_cols := PackedColorArray()
		for k in n:
			rim.append(outer[k])
			var c := Color(1, 1, 1, cols[k].a)
			rim_cols.append(c)
		st.draw_polyline_colors(rim, rim_cols, maxf(1.5, 3.0 * st.zoom), true)


## Behind the fighters: the dark starbursts of hits - quick to full size, holding, then fading; drawn as a fan of
## triangles (a star isn't convex).
func draw_back(st: StageView) -> void:
	for p: Dictionary in parts:
		var k := str(p["k"])
		if k in ["bubble", "floorring", "ribbon"]:
			_draw_back_part(st, p)
			continue
		if k != "ink":
			continue
		var t := float(p["age"]) / float(p["life"])
		var grow := minf(1.0, t / 0.12)
		var c: Color = p["c"]
		c.a = 0.95 * (1.0 - maxf(0.0, (t - 0.5) / 0.5))
		var at := st.w2s(p["p"])
		var s := float(p["s"]) * st.zoom * (0.6 + 0.4 * grow) * (1.0 + 0.08 * t)
		var sp: Array = p["sp"]
		var n := sp.size()
		var pts: Array[Vector2] = []
		for i in n:
			pts.append(at + Vector2.from_angle(float(p["r"]) + i * TAU / n) * s * float(sp[i]))
		for i in n:
			st.draw_colored_polygon(PackedVector2Array([at, pts[i], pts[(i + 1) % n]]), c)


## The mod-study pieces drawn behind the fighters: a throw's dark sphere, a super's ring on the floor, a glide's ribbon.
func _draw_back_part(st: StageView, p: Dictionary) -> void:
	var t := float(p["age"]) / float(p["life"])
	var c: Color = p["c"]
	var at := st.w2s(p["p"])
	var z := st.zoom
	match str(p["k"]):
		"bubble":   # (closing in fast, holding, fading - a pale rim)
			var r := float(p["s"]) * z * (1.3 - 0.3 * minf(1.0, t / 0.15))
			var a := 0.8 * (1.0 - maxf(0.0, (t - 0.55) / 0.45))
			for layer in 4:   # (soft-edged: darker toward the middle, no white rim - 23:11 no big white circles)
				c.a = a * 0.32
				st.draw_circle(at, r * (1.0 - layer * 0.16), c, true, -1.0, true)
		"floorring":   # (a flat glowing ring on the floor, opening out)
			var rx := float(p["s"]) * z * (0.5 + 0.5 * minf(1.0, t / 0.3))
			for layer in 3:
				var cc := c.lightened(0.3 * layer)
				cc.a = (0.5 - layer * 0.12) * (1.0 - t)
				var pts := PackedVector2Array()
				for n in 49:
					var a := TAU * n / 48.0
					pts.append(at + Vector2(cos(a) * rx * (1.0 + layer * 0.12), sin(a) * rx * 0.16 * (1.0 + layer * 0.12)))
				st.draw_polyline(pts, cc, maxf(1.5, (5.0 - layer) * z), true)
		"ribbon":   # (a flat band of her colour along the floor, thinning as it fades)
			var b := st.w2s(p["b"])
			c.a = 0.75 * (1.0 - t)
			st.draw_line(at, b, c, maxf(2.0, float(p["s"]) * z * (1.0 - 0.6 * t)), true)
			var hi := c.lightened(0.5)
			hi.a = c.a * 0.8
			st.draw_line(at, b, hi, maxf(1.0, 2.0 * z), true)


## Sparks, rings, shockwaves - over the fighters.
func draw_parts(st: StageView) -> void:
	var z := st.zoom
	for p: Dictionary in parts:
		var t := float(p["age"]) / float(p["life"])
		var at := st.w2s(p["p"])
		var c: Color = p["c"]
		var s := float(p["s"]) * z
		match str(p["k"]):
			"ink", "bubble", "floorring", "ribbon":   # (behind the fighters - draw_back)
				pass
			"sweep":   # (a giant fan sweeping open: from up behind her round to the way she faces (x = facing; 0 = up))
				var face := float(p["x"])
				var e := 1.0 - pow(1.0 - minf(1.0, t / 0.45), 3.0)
				var a0 := -PI / 2.0 - 0.9 if face != 0.0 else -PI / 2.0 - 1.2   # (worked out facing right, then mirrored)
				var a1 := 0.25 if face != 0.0 else -PI / 2.0 + 1.2
				var mx := face if face != 0.0 else 1.0
				var reach := s * (0.85 + 0.15 * e)
				var ins := reach * 0.28
				var n := 14
				var fill := c
				fill.a = 0.32 * (1.0 - t)
				var rib := c.lightened(0.5)
				rib.a = 0.55 * (1.0 - t)
				var rimc := Color(1, 1, 1, 0.85 * (1.0 - t))
				var rim := PackedVector2Array()
				var dirs: Array[Vector2] = []
				for i in n + 1:
					var d := Vector2.from_angle(lerpf(a0, a0 + (a1 - a0) * e, float(i) / n))
					dirs.append(Vector2(d.x * mx, d.y))
				for i in n:
					var cc := fill if i % 2 == 0 else fill.lightened(0.15)
					st.draw_colored_polygon(PackedVector2Array([at + dirs[i] * reach, at + dirs[i + 1] * reach,
						at + dirs[i + 1] * ins, at + dirs[i] * ins]), cc)
					if i % 3 == 0:
						st.draw_line(at + dirs[i] * ins, at + dirs[i] * reach, rib, maxf(1.0, 2.0 * z), true)
				for i in n + 1:
					rim.append(at + dirs[i] * reach)
				st.draw_polyline(rim, rimc, maxf(2.0, 4.0 * z * (1.0 - t)), true)
			"star":   # (near full size the moment it lands - the freeze shows it - then it shrinks away)
				var grow := (0.75 + 0.25 * minf(1.0, t / 0.2)) * (1.0 - maxf(0.0, (t - 0.5) / 0.5))
				_star(st, at, s * grow, float(p["r"]), p["sp"], c)
				_star(st, at, s * grow * 0.55, float(p["r"]) + 0.3, p["sp"], HOT)
				st.draw_circle(at, s * grow * 0.22, Color.WHITE, true, -1.0, true)
			"ring":
				c.a = 1.0 - t * t
				st.draw_arc(at, s, 0.0, TAU, 14, c, maxf(1.5, 3.0 * z), true)
			"box":
				c.a = 1.0 - t * t
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(at + Vector2.from_angle(float(p["r"]) + PI / 4.0 + k * PI / 2.0) * s * 1.3)
				st.draw_polyline(pts, c, maxf(1.5, 3.0 * z), true)
			"chip":
				c.a = 1.0 - t * t
				st.draw_rect(Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s)), c)
			"wind":   # (a streak of wind, rushing up and thinning)
				c.a = 0.85 * (1.0 - t)
				st.draw_line(at, at + Vector2(sin(float(p["r"])) * 5.0 * z, s * (1.0 - 0.5 * t)), c, maxf(1.5, 3.0 * z), true)
			"shock":
				var e := 1.0 - pow(1.0 - t, 3.0)
				c.a = 0.9 * (1.0 - t)
				st.draw_arc(at, s * (0.35 + 0.65 * e), 0.0, TAU, 40, c, maxf(1.0, 4.5 * z * (1.0 - t)), true)
			"guard":
				c.a = 1.0 - t
				var mid := 0.0 if float(p["x"]) > 0.0 else PI
				st.draw_arc(at, s * (1.0 + 0.3 * t), mid - 1.0, mid + 1.0, 16, c, maxf(1.5, 6.0 * z * (1.0 - t)), true)
			"glint":
				c.a = 1.0 - t
				var len := s * (0.6 + 0.4 * minf(1.0, t / 0.2))
				for k in 4:
					var dir := Vector2.from_angle(PI / 4.0 + k * PI / 2.0)
					var side := Vector2(-dir.y, dir.x) * maxf(1.5, 4.0 * z) * (1.0 - t)
					st.draw_colored_polygon(PackedVector2Array([at + side, at + dir * len, at - side]), c)
				st.draw_circle(at, maxf(2.0, 7.0 * z * (1.0 - t)), c, true, -1.0, true)
			"spokes":   # (impact lines: thin wedges round the hit, pointing in)
				c.a = 1.0 - t
				for k in 14:
					var u := float(k) / 14.0
					var dir := Vector2.from_angle(float(p["r"]) + u * TAU)
					var inner := s * (0.55 + 0.3 * t) * (0.8 + 0.4 * float(k % 3) / 2.0)
					var outer := inner + s * (0.9 + 0.5 * float((k * 7) % 5) / 4.0)
					var side := Vector2(-dir.y, dir.x) * maxf(1.0, 3.2 * z) * (1.0 - t)
					st.draw_colored_polygon(PackedVector2Array([at + dir * inner, at + dir * outer + side,
							at + dir * outer - side]), c)
			"rays":   # (a super's light rays: long wedges turning slowly, out of the one starting it)
				c.a = 0.75 * (1.0 - t * t)
				for k in 16:
					var dir := Vector2.from_angle(float(p["r"]) + t * 0.6 + float(k) / 16.0 * TAU)
					var reach := s * (0.6 + 0.4 * minf(1.0, t / 0.15)) * (0.7 + 0.6 * float((k * 5) % 7) / 6.0)
					var side := Vector2(-dir.y, dir.x) * s * 0.07
					st.draw_colored_polygon(PackedVector2Array([at + dir * s * 0.25, at + dir * reach + side,
							at + dir * reach - side]), c)
			"glow":   # (a soft light round them - stacked see-through discs)
				for k in 4:
					var g := c
					g.a = 0.12 * (1.0 - t)
					st.draw_circle(at, s * (0.5 + 0.17 * k) * (0.9 + 0.2 * t), g, true, -1.0, true)
			"flash":   # (a burst's white disc: full at once, then it opens out and thins away)
				var e := 1.0 - pow(1.0 - t, 2.0)
				c.a = 0.95 * (1.0 - t)
				st.draw_circle(at, s * (0.45 + 0.55 * e), c, true, -1.0, true)
			"text":   # (a word popping up off a hit - COUNTER)
				if _bold == null:
					_bold = FontVariation.new()
					_bold.base_font = ThemeDB.fallback_font
					_bold.variation_embolden = 1.1
				var size := int(float(p["s"]) * (1.25 - 0.25 * minf(1.0, t / 0.15)))
				var tw := _bold.get_string_size(str(p["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				c.a = 1.0 - maxf(0.0, (t - 0.6) / 0.4)
				var ink := Color(0.02, 0.02, 0.03, c.a)
				st.draw_string_outline(_bold, at - Vector2(tw / 2.0, 0), str(p["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1,
						size, 7, ink)
				st.draw_string(_bold, at - Vector2(tw / 2.0, 0), str(p["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
			"shard":   # (a long triangle flying out, point first)
				c.a = 1.0 - t * t
				var dir := (p["v"] as Vector2).normalized() if (p["v"] as Vector2).length() > 1.0 else Vector2.RIGHT
				var side := Vector2(-dir.y, dir.x) * s * 0.28
				st.draw_colored_polygon(PackedVector2Array([at + dir * s, at - dir * s * 0.4 + side,
						at - dir * s * 0.4 - side]), c)


func _star(st: StageView, at: Vector2, s: float, rot: float, sp: Array, c: Color) -> void:
	if s < 1.0:
		return
	var pts := PackedVector2Array()
	for i in sp.size():
		pts.append(at + Vector2.from_angle(rot + TAU * float(i) / float(sp.size())) * s * float(sp[i]))
	st.draw_colored_polygon(pts, c)


## The counts over whoever's being comboed (2 hits and up), kept inside the stage band.
func draw_combos(st: StageView, frame: Array) -> void:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 1.1
	var placed: Array[Vector2] = []
	for id: int in combos:
		var c: Dictionary = combos[id]
		if int(c["hits"]) < 2 or id >= frame.size():
			continue
		var a := 1.0
		if float(c["end"]) >= 0.0:
			a = clampf(1.0 - (float(c["end"]) - COMBO_HOLD) / COMBO_FADE, 0.0, 1.0)
		var r: Array = frame[id]
		var p := st.w2s(Vector2(float(r[0]), float(r[1]) - 150.0))
		p.x = clampf(p.x, st.view_left + 70.0, st.view_right - 70.0)
		p.y = clampf(p.y, st.view_top + 60.0, st.view_bottom - 50.0)
		var moved := true
		while moved:   # (two counts over fighters stood together go one above the other)
			moved = false
			for q: Vector2 in placed:
				if absf(q.x - p.x) < 120.0 and absf(q.y - p.y) < 72.0:
					p.y = q.y - 76.0
					moved = true
		placed.append(p)
		var size := int(46.0 + 18.0 * float(c["pop"]))
		var col: Color = c["by"]
		col = col.lightened(0.15)
		col.a = a
		var ink := Color(0.02, 0.02, 0.03, a)
		var num := str(int(c["hits"]))
		var nw := _bold.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		st.draw_string_outline(_bold, p - Vector2(nw / 2.0, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, ink)
		st.draw_string(_bold, p - Vector2(nw / 2.0, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		var sub := "HITS  ·  %d" % int(c["dmg"])
		var sw := _bold.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var white := Color(1, 1, 1, a)
		st.draw_string_outline(_bold, p + Vector2(-sw / 2.0, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, ink)
		st.draw_string(_bold, p + Vector2(-sw / 2.0, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
