class_name Bot
extends RefCounted
## An opponent - fills empty seats and plays the test matches. The quick way (_quick) reads the stage the way a new
## player would: get close to the nearest enemy, then mix strikes, grabs, guard and parries, with the odd super when
## there's meter. A thinking bot (Normal / Hard - 19 Oct 01:32 "smarter bots") tries a handful of those picks
## forward against a few likely answers from the enemy - the same sim the ghost preview runs, the two of them alone -
## and plays the one that went best. Seeded, so a test match plays the same every time.

const GROUND_HITS := ["jab", "straight", "sidekick", "uppercut", "straight", "sweep", "axekick", "stomp",
	"fanslash", "pirouette", "pop", "snapkick", "windmill", "kipup", "updraft", "glide"]
const FROM_AFAR := ["fan", "fan", "recall", "glide", "dash", "pirouette"]
const FLOOR := ["windmill", "kipup", "sweep", "sweep", "floorslide", "flowform", "snapform", "block", "roll"]
const FORM_SWITCH := ["snapform", "floorform", "flowform"]
const AIR := ["airkick", "airknee", "airdash", "fastfall", "block", "wait", "airfan", "airthrow", "airjump",
	"airknee"]
const GRABS := ["grab"]
const SUPERS := ["fanstorm", "gale", "fanstorm", "finale"]
const CLOSE_IN := ["walk", "dash", "roll", "floorslide", "fanstep"]
const BACK_OFF := ["backstep", "walk", "dash"]
## A spacer (the Dancer - a melee one since 20 Oct, her fans her blades) plays her range: point blank she makes room...
const KEEP_OUT := ["backstep", "sidekick", "uppercut", "fanslash", "straight", "backstep"]
## ...and at her range she pokes - the Arabesque, the Fouetté - throws a fan, cuts in with a Pirouette or leaps a low.
const MID := ["fanslash", "sidekick", "fan", "straight", "sweep", "pirouette", "updraft", "sidekick"]
## The Bruiser - a rushdown (05:03): in at any cost - under shots, over them, through a guard...
const B_IN := ["dash", "dash", "bob", "bob", "walk", "flyknee", "superman"]
## ...and on top of them: his hands, shins and elbows, the clinch, the big armoured swings now and then
const B_HITS := ["jab", "jab", "body", "legkick", "elbow", "teep", "roundhouse", "uppercut", "haymaker", "flyknee",
	"superman", "quake"]
const B_AIR := ["airknee", "airhook", "elbowdrop", "fastfall", "fastfall", "block"]   ## (the air's his weak spot - down fast)
const B_GRABS := ["clinch"]
const B_SUPERS := ["bullrush", "barrage", "clinchfury"]
const B_FOLLOW := ["cross", "hook", "clinchknee", "clinchknee", "clinchelbow", "dump", "chase", "chase"]   ## (his strings, when they're there)

const LOOK := 28        ## (thinking) frames each try is played forward
## By level (Timmy 02:10 "Lets do difficulty please"): 0 Easy - the quick bot; 1 Normal; 2 Hard.
const LEVELS := ["Easy", "Normal", "Hard"]
const TRIES := [0, 4, 7]        ## ...its own picks it tries
const GUESSES := [0, 2, 3]      ## ...the enemy's answers each is tried against
const LOOSE := [0.0, 0.2, 0.0]  ## ...how often it just plays the quick pick anyway
const NEAR_BEST := [0.0, 0.4, 0.15]   ## ...how often it takes the near-best (so it can't be read)
const MARGIN := [0.0, 8.0, 3.0]       ## ...how near "near-best" is
const NEAR := 380.0     ## ...only with an enemy this close (farther off it's the quick way)

var rng := RandomNumberGenerator.new()
var level := 0          ## 0 Easy (the quick bot - the demo, the tests), 1 Normal, 2 Hard: they look ahead
static var chosen := 1  ## the level picked on the home screen (the game's bots, here and the host's online)


func _init(seed_value := 1, lvl := 0) -> void:
	rng.seed = seed_value
	level = clampi(lvl, 0, 2)


## What the enemy's running attack will do next: {frame: how many ticks until its next hit is out, height}.
func _read(t: Fighter) -> Dictionary:
	if t.move == "":
		return {}
	for e: Dictionary in Moves.move(t.character, t.move).get("hits", []):
		if int(e["from"]) > t.frame:
			return {"frame": int(e["from"]) - t.frame, "height": str(e.get("height", "mid"))}
	return {}


func choose(sim: Sim, id: int) -> Dictionary:
	var quick := _quick(sim, id)
	if level == 0 or rng.randf() < LOOSE[level]:
		return quick
	var f := sim.get_f(id)
	var t := sim.nearest_enemy(f)
	if t == null or sim.reeling(f) or f.down > 0 or absf(t.pos.x - f.pos.x) > NEAR:
		return quick
	var tries: Array = [quick]
	for _i in TRIES[level] * 3:   # (a handful of different picks the quick way would make)
		if tries.size() >= TRIES[level]:
			break
		var c := _quick(sim, id)
		if not tries.any(func(x: Dictionary) -> bool: return str(x["move"]) == str(c["move"])):
			tries.append(c)
	var legal := sim.legal_moves(id)
	if legal.has("block") and not tries.any(func(x: Dictionary) -> bool: return str(x["move"]) == "block"):
		var read := _read(t)   # (and a block read off their move, parrying on the frame it lands)
		tries.append({"move": "block", "y": 1.0 if str(read.get("height", "mid")) == "low" else -1.0,
			"pf": int(read.get("frame", 0))})
	var answers: Array = []
	if sim.deciders().has(t.id):   # (what they might do - the quick way's guesses for them)
		var them := Bot.new(rng.randi())
		for _i in GUESSES[level]:
			answers.append(them._quick(sim, t.id))
	else:
		answers.append({"move": "hold"})
	var base := _duel(sim, f, t)
	var scored: Array = []
	for c: Dictionary in tries:
		var sum := 0.0
		var worst := INF
		for a: Dictionary in answers:
			var v := _play(base, c, a)
			sum += v
			worst = minf(worst, v)
		scored.append([0.6 * sum / answers.size() + 0.4 * worst, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	if scored.size() > 1 and float(scored[1][0]) > float(scored[0][0]) - MARGIN[level] \
			and rng.randf() < NEAR_BEST[level]:
		return scored[1][1]   # (now and then the near-best - a bot that always does the same is easy to read)
	return scored[0][1]


## The two of them alone, as saved state (fighter 0 = this bot, 1 = the enemy; their shots kept).
static func _duel(sim: Sim, f: Fighter, t: Fighter) -> Dictionary:
	var d := sim.to_dict()
	var keep := {f.id: 0, t.id: 1}
	var fs: Array = []
	for g: Fighter in [f, t]:
		var gd := g.to_dict()
		gd["id"] = fs.size()
		gd["team"] = fs.size()
		gd["target"] = -1
		fs.append(gd)
	d["fighters"] = fs
	d["mode"] = "ffa"
	var flying: Array = []
	for s: Dictionary in d["shots"]:
		if keep.has(int(s["owner"])):
			s["owner"] = keep[int(s["owner"])]
			s["team"] = s["owner"]
			if s.has("hits"):
				s["hits"] = (s["hits"] as Array).filter(func(x: Variant) -> bool: return keep.has(int(x))).map(
						func(x: Variant) -> int: return int(keep[int(x)]))
			flying.append(s)
	d["shots"] = flying
	return d


## One try played forward: this pick against that answer until someone can act again (or LOOK frames); how it went
## for the bot - damage both ways, who's reeling or down, who acts first, the Dancer at her fan's distance.
func _play(base: Dictionary, mine: Dictionary, theirs: Dictionary) -> float:
	var s := Sim.from_dict(base)
	var f := s.fighters[0]
	var t := s.fighters[1]
	var hp_f := f.hp
	var hp_t := t.hp
	var picks := {}
	var free := s.deciders()
	if free.has(0):
		picks[0] = mine
	if free.has(1):
		picks[1] = theirs
	s.apply(picks)
	for _i in LOOK:
		s.step()
		if s.over():
			break
		free = s.deciders()
		if free.any(func(i: int) -> bool: return s.fighters[i].actionable()):
			break   # (someone's free again - the exchange is over)
		if not free.is_empty():
			var hold := {}
			for i: int in free:
				hold[i] = {"move": "hold"}
			s.apply(hold)
	var v := float(hp_t - t.hp) - 1.3 * float(hp_f - f.hp)
	if t.ko:
		v += 60.0
	if f.ko:
		v -= 80.0
	if t.stun > 0:
		v += 10.0
	if f.stun > 0:
		v -= 12.0
	if t.down > 0:
		v += 6.0
	if f.down > 0:
		v -= 6.0
	if t.stun > 0 and f.cancelled in ["clinch", "clinchknee"]:   # (holding them in the clinch)
		v += 6.0
	if f.actionable() and not t.actionable():
		v += 4.0
	elif t.actionable() and not f.actionable():
		v -= 4.0
	var gap := absf(t.pos.x - f.pos.x)
	if str(Moves.stats(f.character).get("trait", "")) == "spacer":   # (a spacer: her fan's distance is hers - 03:32
		if gap > 90.0 and gap < 260.0:                                 # the zoner rework: room is worth something,
			v += 5.0                                                   # point blank costs her)
		elif gap < 60.0:
			v -= 4.0
	elif str(Moves.stats(f.character).get("trait", "")) == "rushdown":   # (a rushdown: close is his, far off isn't)
		if gap < 90.0:
			v += 4.0
		elif gap > 250.0:
			v -= 3.0
	return v


## The quick way: a reasonable pick from the stage as it is, no looking ahead.
func _quick(sim: Sim, id: int) -> Dictionary:
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
	if str(Moves.stats(f.character).get("trait", "")) == "rushdown":
		return _rush(f, t, legal, c, pick, dist)
	if not f.grounded():
		c["move"] = pick.call(AIR)
		c["y"] = 0.8 if c["move"] == "airfan" else rng.randf_range(-0.6, 0.6)
		return c
	var spacer := str(Moves.stats(f.character).get("trait", "")) == "spacer"
	if dist > 170.0:
		var r0 := rng.randf()
		if r0 < 0.18:
			c["move"] = pick.call(["jump", "superjump"])
			c["x"] = toward * 0.7
			c["y"] = -1.0
		elif r0 < 0.22:
			c["move"] = pick.call(["taunt", "wait"])
		elif r0 < (0.7 if spacer else 0.45):   # (from afar: a fan, a ripple, a ward - a spacer keeps them out there)
			c["move"] = pick.call(FROM_AFAR)
			if c["move"] == "fanward" and rng.randf() < 0.4:   # (now and then hung up high, over a jump)
				c["y"] = -0.7
			c["dist"] = rng.randf_range(40.0, 100.0)
		else:
			c["move"] = pick.call(CLOSE_IN)
		return c
	if t.down > 0 and legal.has("stomp") and dist < 90.0 and rng.randf() < 0.6:   # (they're down: stomp them)
		c["move"] = "stomp"
		return c
	# the x-factors on trial: Encore when it's there, a Recall now and then, forms switched now and then
	if legal.has("encore") and dist < 130.0 and rng.randf() < 0.6:
		c["move"] = "encore"
		return c
	if legal.has("recall") and rng.randf() < 0.25:   # (home, or flung at the nearest enemy)
		if rng.randf() < 0.5:
			return {"move": "recall"}
		var to := (t.pos + Vector2(0, -60) - f.pos).normalized()
		return {"move": "recall", "x": to.x, "y": to.y}
	if rng.randf() < 0.07 and FORM_SWITCH.any(func(m: String) -> bool: return legal.has(m)):
		return {"move": pick.call(FORM_SWITCH)}
	if f.form == "floor" and legal.has("windmill"):   # (on the floor: its own moves)
		c["move"] = pick.call(FLOOR)
		if c["move"] == "block":
			c["y"] = 1.0
		return c
	if legal.has("burstcancel") and rng.randf() < 0.15:
		return {"move": "burstcancel"}
	if spacer and rng.randf() < 0.32:   # (a spacer: room when they're on top of her, her own tools at her range)
		c["move"] = pick.call(KEEP_OUT if dist < 80.0 else MID)
		c["dist"] = rng.randf_range(40.0, 100.0)
		return c
	var r := rng.randf()
	if f.meter >= Sim.BAR and r < 0.04:   # (supers now and then - meter comes quickly the wiki's way)
		c["move"] = pick.call(SUPERS)
	elif r < 0.55:
		c["move"] = pick.call(GROUND_HITS)
	elif r < 0.68:
		c["move"] = pick.call(GRABS)
	elif r < 0.71:   # (now and then the Mirror)
		c["move"] = pick.call(["mirror", "block"])
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


## The Bruiser's quick way (05:03 - a rushdown): far off, in - dashing, slipping under shots, leaping over the floor;
## close, his strings when they're there (Jab -> Cross -> Hook, the clinch's knees), the K.O. Punch when it's full,
## then hands, shins, the clinch, a block now and then.
func _rush(f: Fighter, t: Fighter, legal: Array[String], c: Dictionary, pick: Callable, dist: float) -> Dictionary:
	var toward := float(c["x"])
	if not f.grounded():
		c["move"] = pick.call(B_AIR)
		return c
	if dist > 170.0:
		var r0 := rng.randf()
		if r0 < 0.1:
			c["move"] = pick.call(["jump", "superjump"])
			c["x"] = toward * 0.7
			c["y"] = -1.0
		elif r0 < 0.15:
			c["move"] = pick.call(["taunt", "wait"])
		elif f.meter >= Sim.BAR and r0 < 0.2:   # (armour through it all)
			c["move"] = pick.call(["bullrush"])
		else:
			c["move"] = pick.call(B_IN)
		c["dist"] = rng.randf_range(60.0, 100.0)
		return c
	var follow: Array = B_FOLLOW.filter(func(m: String) -> bool: return legal.has(m))
	if not follow.is_empty() and rng.randf() < 0.85:
		c["move"] = str(follow[rng.randi() % follow.size()])
		return c
	if legal.has("kopunch") and dist < 110.0 and rng.randf() < 0.7:
		c["move"] = "kopunch"
		return c
	if legal.has("burstcancel") and rng.randf() < 0.15:
		return {"move": "burstcancel"}
	var r := rng.randf()
	if f.meter >= Sim.BAR and r < 0.05:
		c["move"] = pick.call(B_SUPERS)
	elif r < 0.6:
		c["move"] = pick.call(B_HITS)
	elif r < 0.74:
		c["move"] = pick.call(B_GRABS)
	elif r < 0.77:
		c["move"] = pick.call(["catch", "block"])
	elif r < 0.9:
		c["move"] = "block" if r < 0.86 else "pushblock"
		var read := _read(t)
		c["y"] = 1.0 if str(read.get("height", "mid")) == "low" else -1.0
		if rng.randf() < 0.5:
			c["pf"] = int(read.get("frame", 0))
	else:
		c["move"] = pick.call(["bob", "dash", "backstep"])
	c["free"] = f.fc > 0 and rng.randf() < 0.5
	c["dist"] = rng.randf_range(40.0, 100.0)
	return c
