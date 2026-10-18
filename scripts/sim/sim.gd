class_name Sim
extends RefCounted
## The match: fighters on a flat stage, stepped 60 times a second. It runs until any fighter is free to act, then stops;
## everyone free picks a move in secret (apply), and it runs on (run_segment) - the simultaneous-turn idea. No graphics,
## no randomness: the same state and the same picks always play out the same, so the host's sim is the match and the
## phones replay the segments it sends for show.
##
## Who beats what: a strike beats a grab, a grab beats a block, a block takes a strike (chip damage) - parried if it
## lands on the Block's picked frame at the right height (the blocker's free at once) - two strikes meeting clash (both
## stopped), armour soaks strikes but not grabs, a Guard Break goes through a block.
##
## Getting out of a stun lock (Timmy 18:37: "Burst is the move we do to get out of stun lock. I also think a certain
## amount of time needs to pass for the stunlock yo go away?"):
## - Burst: everyone starts with one (a full gauge); once used it refills slowly with match time (BURST_FULL).
## - Someone reeling with a full gauge gets a pick whenever the match stops for someone else: Burst or Take It. A Burst
##   ends their stun, they can't be touched for a moment, and everyone near them is blown back.
## - 18:40: "Im pretty sure combos can last forever but the burst gauge fills up so you can burst out. Burst can also be
##   blocked". 18:42: "Review the ref material as it covers most of it" - the YOMI wiki (Combo Mechanics, Blocking; study
##   only, Standoff Workshop/references/yomi/wiki_text) has it as: the gauge fills with time and faster for damage taken
##   OR dealt; a Burst hits on frame 2, can't be touched, does no damage and blows the attacker far back; guarding
##   blocks it (safe, a short push - the Glossary) and a Parry on its frame parries it (the burster is stuck and a
##   fresh combo can start); a combo can go on forever but the same move
##   used again in it stuns for less (REUSE_DECAY); and someone reeling gets a pick at every stop - lean (a direction
##   that nudges their knockback, LEAN_PUSH) or Burst when the gauge is full.
##
## 0.5.0 - the wiki's next list (Timmy 19:10: "Continue on with the other features. Same as before wiki for mechanics"):
## - Free Cancel: an attack picked with Free on gives way when anyone else can act, like a dash. Two charges (FC_MAX),
##   both refilled whenever a melee hit lands on either of the two; +1 to the attacker on a blocked hit, +1 each on a
##   clash; with none left it costs a bar of meter. Holding a freed attack makes it committed again.
## - Whiff Cancel: stuck in a committed move when the match stops for someone else, with 3/4 of the Burst gauge: cut it
##   (WHIFF_COST); 2 ticks later they're free, attacks only for that pick.
## - Knockdown: hits marked "knockdown" floor them when they land (at once if they're never off the ground). Lying
##   down nothing touches them; the match stops for them to pick Get Up, Tech Roll (either way) or Hold (stay down);
##   after DOWN_TICKS they get up anyway. The combo carries on until they're up.
## - Meter in bars (BAR, up to 3): dealing damage (METER_PER_DMG a point), taking it (a third), whiffing an attack,
##   moving toward an enemy (at least 1 a tick), parrying (PARRY_METER), blocking (both, a third of that), a taunt (a
##   bar); combo scaling and Sadness shrink it.
## - The round: ROUND_TICKS (60 s of match time); when it runs out, the best share of HP left wins.
## - Sadness: builds every tick, faster backing away, drops moving in and on every melee hit (it goes below 0 after a
##   combo). SAD! at 2/3; at full, SADNESS! for SADNESS_TICKS: all meter gone, none gained, no guarding or parrying,
##   1.5x damage taken and a little lost over time.
## - Air options: AIR_OPTIONS air moves (air jump, air dash) until they land.
## - Distance (Timmy 19:12: "how do I decide how far I dash?" - the wiki's dash takes a distance 0-100): dashes and
##   jumps take a distance; a short one is slower, shorter and over sooner (Moves `dist`).

const STAGE_HALF := 800.0
const GRAVITY := 0.6
const GRAVITY_FALL := 0.85    ## falling pulls harder than rising (19:38 "feels a little weightless") - same jump height
const MAX_FALL := 16.0
const FRICTION := 0.8
const SEGMENT_CAP := 900      ## ticks a segment may run without a decision (a safety net - 15 s)
const CLASH_LOCK := 10
const CLASH_PUSH := 5.0
const PARRY_STUN := 18
const TECH_LOCK := 12
const BAR := 125              ## meter per bar (the wiki's "level")...
const METER_MAX := BAR * 3    ## ...three of them
const METER_PER_DMG := 3      ## meter for each point of damage dealt (a third of it for damage taken)
const WHIFF_METER := 9        ## an attack that hits nothing
const PARRY_METER := 50       ## a parry (a block gives each side a third)
const WRONG_HEIGHT := 4       ## blocked at the wrong height: this much more blockstun, and double chip
const AIR_BLOCK := 2          ## blocking in the air: this much more blockstun
const PUSH_BACK := 9.0        ## Push Block shoves the striker back this hard...
const PUSH_TICKS := 10        ## ...and their move can't carry them forward for this long
const COMBO_PUSH := 0.7       ## each hit in a combo pushes the hitter back this much more (px, up to COMBO_PUSH_MAX)
const COMBO_PUSH_MAX := 10.0
const BOUNCE_UP := 9.0        ## a ground bounce sends them back up this fast...
const BOUNCE_STUN := 6        ## ...with this much more stun
const SPLAT_TICKS := 30       ## stuck to the wall (each splat after the first lets go 8 sooner)
const SPLATS_MAX := 3
const SHOT_PARRY := 3         ## a projectile is parried by a Block started this many frames before it lands, or fewer
const FC_MAX := 2             ## Free Cancels
const WHIFF_COST := 1125      ## a Whiff Cancel takes this much of the Burst gauge (3/4 of BURST_FULL)
const WHIFF_LOCK := 2         ## ...and they're free this many ticks later
const DOWN_TICKS := 20        ## lying down before getting up by themselves
const ROUND_TICKS := 3600     ## the round (the wiki's default ruleset)
const SAD_MAX := 900          ## Sadness at SADNESS!...
const SAD_MIN := -300         ## ...and as low as it goes after a combo
const SAD_HIT := 150          ## a melee hit takes this much off both
const SADNESS_TICKS := 120    ## how long SADNESS! lasts
const AIR_OPTIONS := 2        ## air moves until they land
## The Burst gauge, in ticks of match time to fill (Timmy 19:02: "You can kind of burst a lot im seeing which is weird" -
## it was 600 ticks + 3 per point of damage taken: bots burst 2-3 times in a 30 s match). The wiki's Glossary: "Burst
## will slowly regenerate over time, and at an increased rate while being comboed".
const BURST_FULL := 1500      ## 25 s of match time...
const BURST_REELING := 2      ## ...filling this many times faster while they're reeling in a combo...
const BURST_DEALT_DIV := 4    ## ...and a little for damage dealt (a point per this many)
const REUSE_DECAY := 0.25     ## a move used again in the same combo stuns this much less each time...
const REUSE_FLOOR := 0.3      ## ...down to this share
const LEAN_PUSH := 2.5        ## a lean adds this much to the knockback (more as the combo grows)
const LAUNCH_HIT := 7         ## the combo hit that always launches someone on the ground
const KB_SCALE := 1.35        ## every hit's knockback (22:40 "We dont do things big enough" - launches that fly)
const WALL_BOUNCE := 0.6      ## how much of their speed someone launched into a wall keeps bouncing off it
const WALL_STUN := 3          ## ...and the stun it adds
const DEFAULT := {"move": "wait"}   ## a pick that never came (a turn timer ran out)

## The match's rules (a lobby's owner sets them - YOMI's lobby rules panel; defaults = the game as it is). "xf": the
## Dancer's x-factors on trial, e.g. "fans,tempo" (Timmy 21:14 / 21:17 - one of them, or two together).
const RULES := {"turn": 30, "round": 3600, "start": 0, "width": 1600, "damage": 1.0, "hitstun": 1.0, "meter": 0.0,
	"xf": "fans,tempo", "ceiling": 900}   # (23:31: the Dancer is Fans + Tempo; the wiki's Ceiling Height)
const XF := ["fans", "tempo", "forms"]
const FANS_MAX := 2           ## Fans: in hand to start
const FAN_OUT := 24           ## ...a thrown one flies out this long, then turns for home
const FAN_BACK := 13.0        ## ...coming back this fast (Recall: FAN_RECALL)
const FAN_RECALL := 20.0
const FAN_LIFE := 240         ## ...and is back in hand after this long whatever happens
const TEMPO_MAX := 4          ## Tempo: beats; Encore at four
const TEMPO_DMG := 0.06       ## ...each beat: this much more damage
const TEMPO_FADE := 300       ## ...a beat fades after this long without a new one
const TEMPO_MOVE := 0.08      ## ...and each beat moves her this much faster (dashes, steps, jumps)
const CARRY := 0.95           ## friction in an attack's startup - she slides on with her momentum (FRICTION otherwise)
const FORMS := ["flow", "snap", "floor"]
const FLOOR_HEIGHT := 56.0    ## Forms: how tall she is in the Floor form (high hits pass over)
const SNAP_DMG := 1.15        ## ...the Snap form's strikes: more damage...
const SNAP_STUN := 2          ## ...and more hitstun

var fighters: Array[Fighter] = []
var mode := "ffa"        ## "ffa" | "teams"
var half := STAGE_HALF   ## half the stage's width (the rules' width / 2)
var round_len := ROUND_TICKS
var dmg_mult := 1.0
var stun_mult := 1.0
var tick := 0
var events: Array = []   ## this segment's: {t, type, a, d, dmg (, counter)}
var _cancels := {}       ## attackers whose hit landed this tick (hit cancel)
var shots: Array = []    ## projectiles in flight: {id, owner, team, kind, pos, vel, box, dmg, stun, kb, block, chip, life,
                         ## parry, height, grav, src}
var _shot_n := 0
var xf := {}             ## the x-factors on: "fans" / "tempo" / "forms" -> true
var ceiling := 900.0     ## how high anyone can go (the wiki's Ceiling Height) - they bump their head on it


## "fans,tempo" -> {fans: true, tempo: true} (unknown names dropped).
static func xf_set(text: String) -> Dictionary:
	var out := {}
	for k in text.split(",", false):
		if XF.has(k.strip_edges()):
			out[k.strip_edges()] = true
	return out


## A new match. players: [{name, character, team}] (team only read in "teams" mode) - spread across the stage, each
## facing the middle.
static func create(players: Array, match_mode := "ffa", rules := {}) -> Sim:
	var s := Sim.new()
	s.mode = match_mode
	var r := RULES.duplicate()
	r.merge(rules, true)
	s.half = clampf(float(r["width"]), 800.0, 3200.0) / 2.0
	s.round_len = clampi(int(r["round"]), 600, 36000)
	s.dmg_mult = clampf(float(r["damage"]), 0.25, 4.0)
	s.stun_mult = clampf(float(r["hitstun"]), 0.25, 4.0)
	s.xf = xf_set(str(r["xf"]))
	s.ceiling = clampf(float(r["ceiling"]), 300.0, 3000.0)
	var n := players.size()
	for i in n:
		var p: Dictionary = players[i]
		var f := Fighter.new()
		f.id = i
		f.character = str(p.get("character", "dancer"))
		f.name = str(p.get("name", "P%d" % (i + 1)))
		f.team = int(p.get("team", i)) if match_mode == "teams" else i
		var st := Moves.stats(f.character)
		f.max_hp = int(st["hp"])
		f.hp = f.max_hp
		f.burst = BURST_FULL   # (one Burst to start - YOMI's HUD shows both gauges full at the round start)
		f.fc = FC_MAX
		f.meter = clampi(int(float(r["meter"]) * BAR), 0, METER_MAX)
		var x := lerpf(-s.half * 0.75, s.half * 0.75, (i + 0.5) / n) if n > 1 else 0.0
		if n == 2 and float(r["start"]) > 0.0:   # (one on one: the rules' start distance)
			x = (float(r["start"]) / 2.0) * (-1.0 if i == 0 else 1.0)
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
	return _teams_left() <= 1 or timed_out()


func timed_out() -> bool:
	return tick >= round_len and _teams_left() > 1


func _teams_left() -> int:
	var teams := {}
	for f in alive():
		teams[f.team] = true
	return teams.size()


## The ids still standing when it's over: the last fighter or team; on time, the side with the best share of HP left
## (ties all win; empty = everyone fell together).
func winners() -> Array[int]:
	var out: Array[int] = []
	if not over():
		return out
	if not timed_out():
		for f in alive():
			out.append(f.id)
		return out
	var share := {}
	for f in fighters:
		var t: Array = share.get(f.team, [0.0, 0.0])
		share[f.team] = [float(t[0]) + maxf(0.0, float(f.hp)), float(t[1]) + float(f.max_hp)]
	var best := -1.0
	for team in share:
		best = maxf(best, float(share[team][0]) / float(share[team][1]))
	for f in alive():
		if is_equal_approx(float(share[f.team][0]) / float(share[f.team][1]), best):
			out.append(f.id)
	return out


## Who has to choose now (empty while it runs, or when it's over): everyone free, and - when the match has stopped for
## them - everyone reeling (a lean, or a Burst).
func deciders() -> Array[int]:
	var out: Array[int] = []
	if over():
		return out
	for f in fighters:
		if f.actionable() or (f.down > 0 and f.down_pick):
			out.append(f.id)
	if not out.is_empty():
		for f in fighters:
			if not out.has(f.id) and (reeling(f) or interruptible(f) or can_whiff(f) or (f.down > 0 and not f.ko)):
				out.append(f.id)
	return out


func reeling(f: Fighter) -> bool:
	return f != null and not f.ko and f.stun > 0


## In a move that gives way when anyone else can act (walking, dashing, jumping, guarding, taunting, waiting): they
## pick again then - something new, or Hold to carry on.
func interruptible(f: Fighter) -> bool:
	if f == null or f.ko or f.stun > 0 or f.blockstun > 0 or f.lock > 0 or f.down > 0 or f.move == "":
		return false
	return bool(Moves.move(f.character, f.move).get("interrupt", false)) or (f.freed and _kind(f) == "attack")


## A Burst Cancel: a full gauge, free, with someone in a combo close by.
func _can_burst_cancel(f: Fighter) -> bool:
	if f.burst < BURST_FULL:
		return false
	for g in alive():
		if enemies(f, g) and reeling(g) and absf(g.pos.x - f.pos.x) < 200.0:
			return true
	return false


## Stuck in a committed move with 3/4 of the Burst gauge: they may Whiff Cancel when the match stops for someone else.
func can_whiff(f: Fighter) -> bool:
	return f != null and not f.ko and f.stun == 0 and f.blockstun == 0 and f.lock == 0 and f.down == 0 \
			and f.move != "" and not interruptible(f) and f.burst >= WHIFF_COST \
			and not _kind(f) in ["burst", "getup", "whiff"] and _threatened(f)


## A free enemy close enough to make a Whiff Cancel worth offering (with six on the stage, not every stop is a threat).
func _threatened(f: Fighter) -> bool:
	for g in alive():
		if enemies(f, g) and g.actionable() and absf(g.pos.x - f.pos.x) < 300.0:
			return true
	return false


## Reeling with a full Burst gauge.
func can_burst(f: Fighter) -> bool:
	return reeling(f) and f.burst >= BURST_FULL


## The x-factors on trial: a move tied to one is only there with its rule on, and only when it can be done - a fan in
## hand (Recall: one out), four beats, the right form; in the Floor form only her floor moves (and defence, supers).
func _xf_ok(f: Fighter, mid: String, m: Dictionary) -> bool:
	var tie := str(m.get("xf", ""))
	if tie != "" and not xf.has(tie):
		return false
	if xf.has("fans"):
		if f.fans < int(m.get("fans", 0)):
			return false
		if (m.has("recall_at") or m.has("needs_out")) and not _fans_out(f):
			return false
	if xf.has("tempo") and f.tempo < int(m.get("tempo", 0)):
		return false
	if xf.has("forms"):
		if m.has("form") and str(m["form"]) != f.form:
			return false
		if m.has("to_form") and not m.has("form") and str(m["to_form"]) == f.form:
			return false
		if f.form == "floor" and not (m.has("form") or m.has("to_form") or bool(m.get("floor", false))
				or str(m.get("tab", "")) in ["defend", "super"] or mid == "wait"):
			return false
	return true


func _fans_out(f: Fighter) -> bool:
	for s: Dictionary in shots:
		if int(s["owner"]) == f.id and bool(s.get("ret", false)):
			return true
	return false


## The moves this fighter can pick right now (ids), in menu order. Reeling: Take It (with a lean), or Burst when full.
func legal_moves(id: int) -> Array[String]:
	var f := get_f(id)
	var out: Array[String] = []
	if reeling(f):
		out.assign(["burst", "hold"] if can_burst(f) else ["hold"])
		return out
	if f != null and f.down > 0 and not f.ko:
		out.assign(["getup", "techroll", "hold"])
		return out
	if can_whiff(f):
		out.assign(["whiff", "hold"])
		return out
	if f == null or not (f.actionable() or interruptible(f)):
		return out
	var air := not f.grounded()
	var all := Moves.of(f.character)
	for mid: String in all:
		var m: Dictionary = all[mid]
		var where := str(m["where"])
		if (air and where == "ground") or (not air and where == "air"):
			continue
		var kind := str(m["kind"])
		if bool(m.get("hidden", false)):
			continue
		if not _xf_ok(f, mid, m):
			continue
		if kind in ["burst", "hold", "whiff", "getup"] and mid != "burstcancel":   # (only offered in their own moments)
			continue
		if int(m.get("cost", 0)) > f.meter:
			continue
		if bool(m.get("air_option", false)) and f.air_moves >= AIR_OPTIONS:
			continue
		if f.sadness > 0 and kind in ["guard", "counter"]:   # (SADNESS!: no defensive options)
			continue
		if f.whiffed and not kind in ["attack", "grab"]:   # (just Whiff Cancelled: attacks only)
			continue
		if mid == f.cancelled and f.meter < BAR:   # (just landed it - again only with an Instant Cancel: a bar)
			continue
		if str(m.get("stance", "")) != "" and str(m["stance"]) != f.stance:   # (a stance's moves, only in it)
			continue
		var after: Array = m.get("after", [])
		if not after.is_empty() and not after.has(f.cancelled):   # (a follow-up: only right after landing its opener)
			continue
		if f.cancelled != "" and f.actionable():   # (some hits only cancel into certain moves - the wiki's hit-cancel limits)
			var into: Array = Moves.move(f.character, f.cancelled).get("cancel_into", [])
			if not into.is_empty() and not into.has(mid) and after.is_empty() and mid != f.cancelled:
				continue
		if mid == "burstcancel" and not _can_burst_cancel(f):
			continue
		out.append(mid)
	if interruptible(f):
		out.append("hold")
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
	var choosing := deciders()   # (initiative: starting while the nearest enemy is choosing too, not already committed)
	for f in fighters:
		var n := nearest_enemy(f)
		f.initiative = n != null and choosing.has(n.id) and (n.actionable() or interruptible(n))
	for id in choices:
		var f := get_f(int(id))
		if f == null:
			continue
		var c: Dictionary = choices[id]
		var mid := str(c.get("move", "hold"))
		if f.actionable():
			_start(f, c)
		elif f.down > 0 and not f.ko:   # (lying down: up, a roll, or stay down)
			f.down_pick = false
			if mid in ["getup", "techroll"]:
				_get_up(f, mid, c)
		elif interruptible(f):   # (Hold carries on - a freed attack becomes committed again; anything else starts now)
			if mid != "hold":
				_start(f, c)
			else:
				f.freed = false
		elif can_whiff(f):
			if mid == "whiff":
				_whiff(f)
		elif can_burst(f) and str(c.get("move", "")) == "burst":
			_burst(f)
		elif reeling(f):   # (Take It: the lean they picked, none = ride it straight)
			f.di = aim("lean", Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0))), f.facing)


## Up off the floor: standing up on the spot or rolling away (picked left or right) - untouchable while they do.
func _get_up(f: Fighter, mid: String, c: Dictionary) -> void:
	var m := Moves.move(f.character, mid)
	f.down = 0
	f.down_pick = false
	if xf.has("forms"):   # (up off the floor: back in Flow)
		f.form = "flow"
	f.param = aim(str(m.get("aim", "none")), Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0))), f.facing)
	if absf(f.param.x) > 0.2:
		f.facing = 1 if f.param.x > 0.0 else -1
	f.move = mid
	f.length = int(m["frames"])
	f.frame = 0
	f.instance += 1
	f.hit_done.clear()


## A Whiff Cancel: the committed move is cut, 3/4 of the Burst gauge goes, and they're free in WHIFF_LOCK ticks -
## attacks only.
func _whiff(f: Fighter) -> void:
	f.burst -= WHIFF_COST
	f.move = ""
	f.frame = 0
	f.freed = false
	f.lock = WHIFF_LOCK
	f.whiffed = true
	_event("whiff", f, null)


## Meter gained: shrunk by the combo it's part of (c hits in) and by Sadness; none at all during SADNESS!.
func _gain(f: Fighter, amount: float, c := 0) -> void:
	if f.ko or f.sadness > 0 or amount <= 0.0:
		return
	var cc := float(mini(c, 15))
	amount *= 0.8 * pow((15.0 - cc) / 15.0, 2.0) + 0.2
	if f.sad > 0:
		amount *= 1.0 - 0.5 * float(f.sad) / float(SAD_MAX)
	f.meter = mini(METER_MAX, f.meter + maxi(1, int(round(amount))))


## Out of the stun lock: the stun's gone, the gauge is spent, and the Burst move runs (untouchable, blows people back).
func _burst(f: Fighter) -> void:
	f.stun = 0
	f.blockstun = 0
	f.lock = 0
	f.combo = 0
	f.vel = Vector2.ZERO
	f.burst = 0
	f.splat = 0
	f.combo_over()
	f.move = "burst"
	f.length = int(Moves.move(f.character, "burst")["frames"])
	f.frame = 0
	f.param = Vector2.ZERO
	f.instance += 1
	f.hit_done.clear()


func _start(f: Fighter, c: Dictionary) -> void:
	var mid := str(c.get("move", "wait"))
	if not legal_moves(f.id).has(mid):
		c = DEFAULT
		mid = "wait"
	var m := Moves.move(f.character, mid)
	f.param = aim(str(m.get("aim", "none")), Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0))), f.facing)
	if absf(f.param.x) > 0.2:
		f.facing = 1 if f.param.x > 0.0 else -1   # (aimed left or right - they turn that way)
	elif str(m.get("aim", "none")) in ["none", "height", "lean"]:   # (no way picked: they turn to the nearest enemy -
		var n := nearest_enemy(f)                                   # Timmy 21:37 "always ... the enemy closest")
		if n != null and absf(n.pos.x - f.pos.x) > 1.0:
			f.facing = 1 if n.pos.x > f.pos.x else -1
	f.dist = clampf(float(c.get("dist", 100.0)) / 100.0, 0.0, 1.0)
	f.parry_at = int(c.get("pf", 0)) if bool(m.get("parry_frame", false)) else 0
	f.length = int(m["frames"])
	if m.has("dist"):   # (a short dash / jump is over sooner)
		var d: Array = m["dist"]
		f.length = int(round(lerpf(float(d[0]), float(d[1]), f.dist)))
	f.meter -= int(m.get("cost", 0))
	if mid != "" and mid == f.cancelled:   # (an Instant Cancel: the move they just landed, again, for a bar)
		f.meter -= BAR
		_event("ic", f, null)
	if mid == "burstcancel":
		f.burst = 0
	if xf.has("forms") and m.has("to_form"):   # (into a form)
		f.form = str(m["to_form"])
		_event("form_" + f.form, f, null)
	if xf.has("tempo") and int(m.get("tempo", 0)) > 0:   # (Encore spends the beats; standing about, they fade)
		f.tempo = 0
	if bool(m.get("air_option", false)):
		f.air_moves += 1
	f.freed = false
	if bool(c.get("free", false)) and str(m["kind"]) == "attack":   # (Free Cancel: a charge, or a bar without one)
		if f.fc > 0:
			f.fc -= 1
			f.freed = true
		elif f.meter >= BAR:
			f.meter -= BAR
			f.freed = true
	f.move = mid
	f.frame = 0
	f.instance += 1
	f.hit_done.clear()
	f.cancelled = ""
	f.whiffed = false
	f.stance = str(m.get("enter", ""))   # (a stance move puts them in it; anything else takes them out)


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
		"lean":   # (reeling: any of 8, or none)
			return d.normalized() if d.length() > 0.01 else Vector2.ZERO
		"height":   # (a block: ↓ = low, anything else = high)
			return Vector2(0.0, 1.0) if d.y > 0.2 else Vector2(0.0, -1.0)
	return Vector2.ZERO


## Run until someone has to choose (or it's over): every tick's picture for playback and what happened.
func run_segment(cap := SEGMENT_CAP) -> Dictionary:
	events.clear()
	var frames: Array = []
	var flying: Array = []
	for _i in cap:
		step()
		frames.append(record())
		flying.append(record_shots())
		if over() or not deciders().is_empty():
			break
	return {"frames": frames, "events": events.duplicate(), "end_tick": tick, "shots": flying}


## What a picked move would do (the ghost preview): a copy of the match with these picks, every other fighter who's
## free standing still, run `ticks` ticks whatever happens -> {frames, events} (the events say what lands on whom - a
## dash into someone mid-swing shows you getting hit).
func preview(choices: Dictionary, ticks := 90) -> Dictionary:
	var copy := Sim.from_dict(to_dict())
	var all := {}
	for id in copy.deciders():
		all[id] = choices.get(id, {"move": "hold"})
	copy.apply(all)
	var frames: Array = []
	var flying: Array = []
	for _i in ticks:
		copy.step()
		frames.append(copy.record())
		flying.append(copy.record_shots())
		var free := copy.deciders()
		if not free.is_empty():   # (whoever's free again stands there, free; anyone mid-something carries on)
			var hold := {}
			for id in free:
				if not copy.fighters[id].actionable():
					hold[id] = {"move": "hold"}
			copy.apply(hold)
	return {"frames": frames, "events": copy.events, "shots": flying}


## One tick: the moves push their fighters, gravity and the stage, hits, then every counter ticks down.
func step() -> void:
	tick += 1
	for f in fighters:
		if f.move in ["burst", "burstcancel"] and f.frame == 0:   # (a Burst's first tick - the screens' flash)
			_event("burst", f, null)
		_motion(f)
		_spawn(f)
	for f in fighters:
		_physics(f)
	_separate()
	var hit_now := _resolve_hits()
	_shots_step(hit_now)
	for f in fighters:
		if not hit_now.has(f.id):
			_count(f)
		_upkeep(f)
	if tick == round_len and timed_out():
		_event("time", fighters[0], null)


## Every tick: meter for moving in, Sadness, lying down.
func _upkeep(f: Fighter) -> void:
	if f.ko:
		return
	var n := nearest_enemy(f)
	var v := f.vel.x * signf(n.pos.x - f.pos.x) if n != null and absf(n.pos.x - f.pos.x) > 1.0 else 0.0
	if v > 0.5 and f.stun == 0 and tick % 2 == 0:   # (moving in on someone: the wiki's v/4 (at least 1) - every other
		_gain(f, maxf(1.0, v / 4.0))                # tick: with up to six there's always someone to move in on)
	if xf.has("tempo") and f.tempo > 0:   # (a beat fades without a new one)
		f.tempo_idle += 1
		if f.tempo_idle >= TEMPO_FADE:
			f.tempo -= 1
			f.tempo_idle = 0
	if f.sadness > 0:   # (SADNESS!: a little HP lost over time, then it starts again from nothing)
		f.sadness -= 1
		if f.sadness % 10 == 0 and f.hp > 1:
			f.hp -= 1
		if f.sadness == 0:
			f.sad = 0
	elif f.stun == 0 and f.down == 0:
		var d := 1 + (2 if v < -0.5 else 0) - (2 if v > 0.5 else 0)
		f.sad = clampi(f.sad + d, SAD_MIN, SAD_MAX)
		if f.sad >= SAD_MAX * 2 / 3 and not f.sad_warned:
			f.sad_warned = true
			_event("sad", f, null)
		elif f.sad < SAD_MAX * 2 / 3:
			f.sad_warned = false
		if f.sad >= SAD_MAX:
			f.sadness = SADNESS_TICKS
			f.meter = 0
			f.sad_warned = false
			_event("sadness", f, null)
	if f.down > 0:
		f.down -= 1
		if f.down == 0:   # (they get up by themselves)
			_get_up(f, "getup", {})


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
	if f.pushed > 0:   # (shoved off a Push Block - their move doesn't carry them on)
		f.pushed -= 1
		return
	if f.ko or f.stun > 0 or f.blockstun > 0 or f.lock > 0 or f.move == "":
		return
	var m := Moves.move(f.character, f.move)
	var k := lerpf(float(m["dist"][2]), 1.0, f.dist) if m.has("dist") else 1.0   # (a short one goes slower)
	var kind := str(m.get("kind", ""))
	if xf.has("tempo") and kind == "move":   # (Tempo: each beat moves her faster)
		k *= 1.0 + TEMPO_MOVE * float(f.tempo)
	if m.has("blink_at") and int(m["blink_at"]) == f.frame:   # (Fan Step: to her thrown fan, in a blink)
		_blink(f)
	for seg: Array in m.get("motion", []):
		if f.frame >= int(seg[0]) and f.frame <= int(seg[1]):
			var vx := _val(seg[2], f) * k
			var nx := vx if seg[2] is Array else vx * f.facing   # (a picked direction is already left / right)
			# (an attack's lunge keeps any faster momentum the same way - 23:23 "better movement")
			if kind in ["attack", "special", "super"] and signf(f.vel.x) == signf(nx) and absf(f.vel.x) > absf(nx):
				nx = f.vel.x
			f.vel.x = nx
			f.vel.y = _val(seg[3], f) * k


func _floating(f: Fighter) -> bool:
	return f.move != "" and f.stun == 0 and bool(Moves.move(f.character, f.move).get("float", false))


func _physics(f: Fighter) -> void:
	if f.splat > 0:   # (stuck to the wall: sliding down it, then off - or floored if they reach the ground)
		f.splat -= 1
		f.vel = Vector2(0.0, 1.2)
		f.pos += f.vel
		if f.pos.y >= 0.0:
			f.pos.y = 0.0
			f.splat = 0
			_floor(f)
		elif f.splat == 0:
			f.vel = Vector2(-signf(f.pos.x) * 4.0, -3.0)
		return
	var was_air := f.pos.y < 0.0
	if not _floating(f) and (f.pos.y < 0.0 or f.vel.y < 0.0):
		f.vel.y = minf(f.vel.y + (GRAVITY if f.vel.y < 0.0 else GRAVITY_FALL), MAX_FALL)
	f.pos += f.vel
	if f.pos.y >= 0.0:
		f.pos.y = 0.0
		if f.vel.y > 0.0:
			f.vel.y = 0.0
		if was_air:
			f.air_moves = 0
			if f.stun > 0 and f.bounce_due and not f.bounced:   # (a ground bounce: back up instead of down)
				_bounce(f)
			elif f.stun > 0 and f.kd:   # (a knockdown hit: floored on landing)
				_floor(f)
			f.kd = false
			if f.move != "" and bool(Moves.move(f.character, f.move).get("land_ends", false)):
				f.lock = int(Moves.move(f.character, f.move).get("landing", 6))
				f.move = ""
		# sliding to a stop (knockback, the end of a step) unless a move is pushing them this frame
		if not _pushing(f):
			f.vel.x *= CARRY if _in_startup(f) else FRICTION   # (an attack's startup slides on with her momentum)
			if absf(f.vel.x) < 0.05:
				f.vel.x = 0.0
	if f.pos.y < -ceiling:   # (the ceiling: bump off it)
		f.pos.y = -ceiling
		if f.vel.y < 0.0:
			f.vel.y = 0.0
	var half := float(Moves.stats(f.character)["width"]) / 2.0
	if absf(f.pos.x) > self.half - half:
		f.pos.x = signf(f.pos.x) * (self.half - half)
		if f.stun > 0 and f.splat_due and f.pos.y < -2.0 and f.splats < SPLATS_MAX:   # (a wall splat: stuck there)
			f.splat = SPLAT_TICKS - 8 * f.splats
			f.splats += 1
			f.splat_due = false
			f.vel = Vector2.ZERO
			f.stun = maxi(f.stun, f.splat + 2)
			_event("splat", f, null)
		elif f.stun > 0 and f.pos.y < -2.0 and absf(f.vel.x) > 2.0:   # (launched into the wall: off it, a bit more stun)
			f.vel.x = -f.vel.x * WALL_BOUNCE
			f.stun += WALL_STUN
			_event("wall", f, null)
		else:
			f.vel.x = 0.0


## Off the ground and back up (once a combo), a bit more stun.
func _bounce(f: Fighter) -> void:
	f.vel.y = -BOUNCE_UP
	f.stun += BOUNCE_STUN
	f.bounced = true
	f.bounce_due = false
	_event("bounce", f, null)


## Knocked down: out of the stun, lying there untouchable; the match stops for their getting-up pick.
func _floor(f: Fighter) -> void:
	f.stun = 0
	f.move = ""
	f.down = DOWN_TICKS
	f.down_pick = true
	f.kd = false
	f.vel.x *= 0.3
	_event("down", f, null)


## In an attack's startup (before its first hit) - momentum carries through it.
func _in_startup(f: Fighter) -> bool:
	if f.move == "" or f.stun > 0 or f.blockstun > 0 or f.lock > 0:
		return false
	var m := Moves.move(f.character, f.move)
	if not str(m.get("kind", "")) in ["attack", "special", "super", "grab"]:
		return false
	var hits: Array = m.get("hits", [])
	return not hits.is_empty() and f.frame < int(hits[0]["from"])


## Fan Step: she blinks to her nearest fan in the air (a step off the ground at most) and catches it.
func _blink(f: Fighter) -> void:
	var best: Dictionary = {}
	for s: Dictionary in shots:
		if int(s["owner"]) == f.id and bool(s.get("ret", false)) and (best.is_empty()
				or (s["pos"] as Vector2).distance_to(f.pos) < (best["pos"] as Vector2).distance_to(f.pos)):
			best = s
	if best.is_empty():
		return
	var to: Vector2 = best["pos"]
	_event("blink", f, null, 0, {"from": [f.pos.x, f.pos.y]})
	f.pos = Vector2(clampf(to.x, -half + 20.0, half - 20.0), minf(0.0, to.y + 60.0))
	f.vel = Vector2.ZERO
	shots.erase(best)
	f.fans = mini(FANS_MAX, f.fans + 1)
	_event("catch", f, null)


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
	f.burst = mini(BURST_FULL, f.burst + (BURST_REELING if f.stun > 0 else 1))
	if f.stun > 0:
		f.stun -= 1
		if f.stun == 0 and f.splat == 0:
			f.combo_over()
	elif f.blockstun > 0:
		f.blockstun -= 1
	elif f.lock > 0:
		f.lock -= 1
	elif f.move != "":
		f.frame += 1
		if f.frame >= f.length:
			var m := Moves.move(f.character, f.move)
			_gain(f, float(m.get("meter_gain", 0)))
			if str(m["kind"]) == "attack" and f.hit_done.is_empty():   # (it hit nothing)
				_gain(f, WHIFF_METER)
			if str(m["kind"]) == "getup":   # (up again - the combo's over)
				f.combo_over()
			if m.has("enter"):   # (the stance move's run out - out of the stance)
				f.stance = ""
			f.move = ""
			f.frame = 0
			f.freed = false


func hurtbox(f: Fighter) -> Rect2:
	var st := Moves.stats(f.character)
	var w := float(st["width"])
	var h := float(st["height"])
	if xf.has("forms") and f.form == "floor" and f.stun == 0:   # (low on the floor - high hits pass over)
		h = FLOOR_HEIGHT
	if f.move != "" and f.stun == 0:   # (a low-profile move: ducked under high hits - the wiki's Low Profile)
		var lp: Array = Moves.move(f.character, f.move).get("low_profile", [])
		if not lp.is_empty() and f.frame >= int(lp[0]) and f.frame <= int(lp[1]):
			h = FLOOR_HEIGHT
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
	if f.down > 0:   # (lying down - nothing reaches them)
		return true
	if f.move == "" or f.stun > 0:
		return false
	var m := Moves.move(f.character, f.move)
	var inv: Array = m.get("invuln", [])
	if not inv.is_empty() and f.frame >= int(inv[0]) and f.frame <= int(inv[1]):
		return true
	var ini: Array = m.get("init_invuln", [])   # (with initiative: more invulnerable frames)
	return f.initiative and not ini.is_empty() and f.frame >= int(ini[0]) and f.frame <= int(ini[1])


## In a move's projectile-proof frames (Silk Glide) - projectiles pass by.
func _shot_proof(f: Fighter) -> bool:
	if f.move == "" or f.stun > 0:
		return false
	var r: Array = Moves.move(f.character, f.move).get("shot_invuln", [])
	return not r.is_empty() and f.frame >= int(r[0]) and f.frame <= int(r[1])


func _kind(f: Fighter) -> String:
	return str(Moves.move(f.character, f.move).get("kind", "")) if f.move != "" else ""


func _event(type: String, a: Fighter, d: Fighter, dmg := 0, extra := {}) -> void:
	var e := {"t": tick, "type": type, "a": a.id, "d": d.id if d != null else -1, "dmg": dmg}
	e.merge(extra)
	events.append(e)


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
			if a.id >= b.id or not enemies(a, b) or kind[a.id] in ["grab", "burst"] or kind[b.id] in ["grab", "burst"]:
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
		f.fc = mini(FC_MAX, f.fc + 1)
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
					var otg := d.down > 0 and bool(e.get("otg", false))   # (an OTG hit reaches someone lying down)
					if d.ko or not enemies(a, d) or not box.intersects(hurtbox(d)):
						continue
					if invulnerable(d) and not otg:
						if d.down == 0:   # (dodged through it - Tempo: a beat)
							_beat(d, "d%d" % d.instance)
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
	for id: int in _cancels:   # (hit cancels: out of the move, free next tick; not the same move straight away)
		var f := get_f(id)
		if f.move != "" and f.stun == 0:
			f.cancelled = f.move
			f.cancel_frame = f.frame
			f.move = ""
			f.frame = 0
	_cancels.clear()
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
	if d_kind == "counter" and not reeling:   # (a counter stance: struck in its window, it strikes back at once)
		var win: Array = dm.get("window", [0, 0])
		if d_frame >= int(win[0]) and d_frame <= int(win[1]):
			_counter(d, a, dm)
			return
	if _block(a, d, e, dm, d_frame, false):
		return
	if d.move != "" and dm.has("armor") and not reeling:
		var arm: Array = dm["armor"]
		if d_frame >= int(arm[0]) and d_frame <= int(arm[1]):
			d.hp -= dmg
			_gain(a, dmg * METER_PER_DMG)
			_event("armor", a, d, dmg)
			return
	_hurt(a, d, e, "hit")


## A hit meeting a block (or a Block's parry). shot = a projectile: parried by a Block started within SHOT_PARRY frames
## (any height) unless it can't be. True = it was blocked or parried.
func _block(a: Fighter, d: Fighter, e: Dictionary, dm: Dictionary, d_frame: int, shot: bool) -> bool:
	if not ((_kind(d) == "guard" or d.blockstun > 0) and d.stun == 0 and not e.get("guardbreak", false)):
		return false
	var push := bool(dm.get("push", false))
	var height := str(e.get("height", "mid"))
	var right := push or height == "mid" or (height == "low") == (d.param.y > 0.0)
	var parried := d.move == "block" and d.parry_at > 0 and d_frame == d.parry_at and right
	if shot:
		parried = d.move == "block" and d_frame <= SHOT_PARRY and bool(e.get("parry", true))
	if parried:   # (parried: free at once)
		d.move = ""
		d.frame = 0
		d.blockstun = 0
		_gain(d, PARRY_METER)
		_event("parry", d, a, 0, {"shot": shot})
		return true
	var chip := 0 if push else int(e.get("chip", 0)) * (1 if right else 2)
	d.hp -= chip
	d.blockstun = int(e.get("block", 8)) + (0 if right else WRONG_HEIGHT) + (0 if d.grounded() else AIR_BLOCK)
	var away := signf(d.pos.x - a.pos.x) if absf(d.pos.x - a.pos.x) > 1.0 else float(a.facing)
	d.vel.x = away * 3.0
	if push and not shot:   # (Push Block: the striker's shoved back)
		a.vel.x = -away * PUSH_BACK / float(Moves.stats(a.character)["weight"])
		a.pushed = PUSH_TICKS
	_gain(a, PARRY_METER / 3.0)
	_gain(d, PARRY_METER / 3.0)
	_beat(a, str(e.get("key", "m%d" % a.instance)))   # (Tempo: a move of theirs met - blocked counts)
	if not shot:
		a.fc = mini(FC_MAX, a.fc + 1)
	_event("block", a, d, chip, {"adv": a.busy() - d.blockstun, "worse": not right, "push": push, "shot": shot})
	return true


## A counter stance struck in its window: the striker's hit is caught and the counter lands on them at once.
func _counter(d: Fighter, a: Fighter, dm: Dictionary) -> void:
	var into := str(dm.get("counter_move", ""))
	d.facing = 1 if a.pos.x >= d.pos.x else -1
	if into != "":
		var cm := Moves.move(d.character, into)
		d.move = into
		d.frame = 0
		d.length = int(cm["frames"])
		d.instance += 1
		d.hit_done.clear()
	_event("countered", d, a)
	_hurt(d, a, dm["counter_hit"], "hit", into if into != "" else "counter", float(d.facing))


## A move's projectile, thrown on its frame: the way they aim it (straight ahead, or down for the air one).
func _spawn(f: Fighter) -> void:
	if f.ko or f.move == "" or f.stun > 0 or f.blockstun > 0 or f.lock > 0:
		return
	var m := Moves.move(f.character, f.move)
	if xf.has("fans") and m.has("recall_at") and int(m["recall_at"]) == f.frame:
		_recall(f)
	var cues: Variant = m.get("cue", [])   # (a move's own effects, each on its frame - Updraft's gust, a fan sweep)
	for cue: Dictionary in (cues if cues is Array else [cues]):
		if int(cue["at"]) == f.frame:
			_event(str(cue["type"]), f, null)
	var sp: Dictionary = m.get("spawn", {})
	if sp.is_empty() or int(sp["at"]) != f.frame:
		return
	var dir := Vector2(float(f.facing), 0.0)
	if str(m.get("aim", "")) in ["down", "dir8"] and f.param.length() > 0.1:
		dir = f.param.normalized()
	var off: Array = sp.get("from", [30, -70])
	_shot_n += 1
	shots.append({"id": _shot_n, "owner": f.id, "team": f.team, "kind": str(sp["kind"]),
		"pos": f.pos + Vector2(float(off[0]) * f.facing, float(off[1])), "vel": dir * float(sp["speed"]),
		"box": sp.get("box", [24, 18]), "dmg": int(sp["dmg"]), "stun": int(sp["stun"]), "kb": sp["kb"],
		"block": int(sp.get("block", 8)), "chip": int(sp.get("chip", 1)), "life": int(sp.get("life", 60)),
		"parry": bool(sp.get("parry", true)), "height": str(sp.get("height", "mid")),
		"grav": float(sp.get("grav", 0.0)), "src": f.move})
	if xf.has("fans") and int(m.get("fans", 0)) > 0:   # (Fans: one out of her hand - it comes back)
		f.fans -= 1
		shots[-1].merge({"ret": true, "leg": 0, "out": FAN_OUT, "hits": [], "life": FAN_LIFE}, true)
	_event("shot", f, null, 0, {"kind": str(sp["kind"])})


## Fans: Recall - every fan of hers in the air turns for home at once, fast, and may hit anyone again on the way.
func _recall(f: Fighter) -> void:
	for s: Dictionary in shots:
		if int(s["owner"]) == f.id and bool(s.get("ret", false)):
			s["leg"] = 1
			s["spd"] = FAN_RECALL
			s["hits"] = []
	_event("recall", f, null)


## A returning fan: out for FAN_OUT ticks, then home to her hand - caught there. False = it's gone (caught, or she is).
func _fan_fly(s: Dictionary) -> bool:
	var o := get_f(int(s["owner"]))
	if o == null or o.ko:
		return false
	if int(s["leg"]) == 0:
		s["out"] = int(s["out"]) - 1
		if int(s["out"]) <= 0:
			s["leg"] = 1
		return true
	var to := o.pos + Vector2(0.0, -70.0) - (s["pos"] as Vector2)
	if to.length() < 34.0:
		o.fans = mini(FANS_MAX, o.fans + 1)
		_event("catch", o, null)
		return false
	s["vel"] = to.normalized() * float(s.get("spd", FAN_BACK))
	return true


## Tempo: a beat (once for each thing that gives one - key), up to TEMPO_MAX.
func _beat(f: Fighter, key: String) -> void:
	if not xf.has("tempo") or f.ko or f.tempo_key == key:
		return
	f.tempo_key = key
	f.tempo_idle = 0
	if f.tempo < TEMPO_MAX:
		f.tempo += 1
		_event("onbeat" if f.tempo == TEMPO_MAX else "beat", f, null)


## Projectiles: two enemies' meeting cancel out; the rest fly on and hit (or are blocked / parried by) the first enemy
## they touch - invulnerable frames let them pass.
func _shots_step(touched: Dictionary) -> void:
	var dead := {}
	for i in shots.size():
		for j in range(i + 1, shots.size()):
			var p: Dictionary = shots[i]
			var q: Dictionary = shots[j]
			if int(p["team"]) != int(q["team"]) and _shot_rect(p).intersects(_shot_rect(q)):
				for sh: Dictionary in [p, q]:   # (a returning fan turns for home instead)
					if bool(sh.get("ret", false)):
						sh["leg"] = 1
					else:
						dead[int(sh["id"])] = true
				_event("clash", get_f(int(p["owner"])), get_f(int(q["owner"])))
	var keep: Array = []
	for s: Dictionary in shots:
		if dead.has(int(s["id"])):
			continue
		var ret := bool(s.get("ret", false))
		if ret and not _fan_fly(s):
			continue
		var v: Vector2 = s["vel"]
		if not ret:
			v.y += float(s["grav"])
			s["vel"] = v
		s["pos"] = (s["pos"] as Vector2) + v
		s["life"] = int(s["life"]) - 1
		var p: Vector2 = s["pos"]
		if int(s["life"]) <= 0 or absf(p.x) > half + 40.0 or p.y > 4.0:
			if not ret:
				continue
			if int(s["life"]) <= 0:   # (lost too long: back in hand anyway)
				var o := get_f(int(s["owner"]))
				o.fans = mini(FANS_MAX, o.fans + 1)
				continue
			s["leg"] = 1   # (off the edge or into the floor: it turns for home)
			s["pos"] = Vector2(clampf(p.x, -half - 30.0, half + 30.0), minf(p.y, 0.0))
		var landed := false
		for d in fighters:
			if d.ko or d.team == int(s["team"]) or not _shot_rect(s).intersects(hurtbox(d)):
				continue
			if invulnerable(d) or _shot_proof(d):
				if d.down == 0:
					_beat(d, "d%d" % d.instance)
				continue
			if ret and (s["hits"] as Array).has(d.id):   # (a fan hits each of them once a flight)
				continue
			_shot_hit(s, d)
			touched[d.id] = true
			landed = true
			if ret:
				(s["hits"] as Array).append(d.id)
				s["leg"] = 1
			break
		if not landed or ret:
			keep.append(s)
	shots = keep


func _shot_rect(s: Dictionary) -> Rect2:
	var b: Array = s["box"]
	return Rect2((s["pos"] as Vector2) - Vector2(float(b[0]), float(b[1])) / 2.0, Vector2(float(b[0]), float(b[1])))


func _shot_hit(s: Dictionary, d: Fighter) -> void:
	var a := get_f(int(s["owner"]))
	var e := {"dmg": s["dmg"], "stun": s["stun"], "kb": s["kb"], "block": s["block"], "chip": s["chip"],
		"height": s["height"], "parry": s["parry"], "key": "s%d" % int(s["id"])}
	var dm := Moves.move(d.character, d.move) if d.move != "" else {}
	if _block(a, d, e, dm, d.frame, true):
		return
	var v: Vector2 = s["vel"]
	_hurt(a, d, e, "hit", str(s["src"]), signf(v.x) if absf(v.x) > 0.1 else float(a.facing))


## Every projectile in flight, for playback: [x, y, kind, owner, vx, vy, life].
func record_shots() -> Array:
	var out: Array = []
	for s: Dictionary in shots:
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		out.append([p.x, p.y, s["kind"], s["owner"], v.x, v.y, s["life"]])
	return out


func _hurt(a: Fighter, d: Fighter, e: Dictionary, type: String, src := "", side_dir := 0.0) -> void:
	var mv := src if src != "" else a.move   # (the move it came from - a projectile's thrower may be doing something else)
	# combo scaling: full on the first hit, about 0.9x each hit after, 20% from the 15th on
	if d.combo == 0:   # (the starter's proration: a jab starts the scaling further in than a sweep)
		d.prorate = int(Moves.move(a.character, mv).get("proration", 0)) if mv != "" else 0
	var c := 0.0 if d.combo == 0 else float(clampi(d.combo + d.prorate, 0, 15))   # (the starter itself is unscaled)
	var scale := 0.8 * pow((15.0 - c) / 15.0, 2.0) + 0.2
	# a counter hit (they were mid-attack) does 10% more
	var counter := type == "hit" and int(e["dmg"]) > 0 and d.move != "" \
			and _kind(d) in ["attack", "super", "grab", "special"]
	var xk := 1.0   # (the x-factors on trial: Tempo's beats, the Snap form's strikes)
	if xf.has("tempo"):
		xk *= 1.0 + TEMPO_DMG * float(a.tempo)
	var snap := xf.has("forms") and a.form == "snap" and src == ""
	if snap:
		xk *= SNAP_DMG
	var dmg := maxi(int(e.get("min_dmg", 0)),
			int(round(float(e["dmg"]) * scale * (1.1 if counter else 1.0) * (1.5 if d.sadness > 0 else 1.0) * dmg_mult
			* xk)))
	d.hp -= dmg
	var in_air := d.pos.y < -1.0
	if d.down > 0:   # (an OTG hit: picked up off the floor, the combo goes on)
		d.down = 0
		d.down_pick = false
	d.splat = 0
	# (the same move again in this combo stuns for less - a combo can last forever, but not on one move)
	var used: Array = d.combo_used.get(mv, [0, -1])
	if int(used[1]) != a.instance:
		used = [int(used[0]) + 1, a.instance]
		d.combo_used[mv] = used
	d.stun = maxi(1, int(round(float(e["stun"]) * maxf(REUSE_FLOOR, 1.0 - REUSE_DECAY * (int(used[0]) - 1)) * stun_mult)))
	if in_air:   # (one more frame of hitstun in the air)
		d.stun += 1
	if snap:
		d.stun += SNAP_STUN
	if xf.has("tempo"):   # (Tempo: hit, the beat's gone; the hitter's move gets one - once)
		d.tempo = 0
		d.tempo_idle = 0
		if not e.get("away", false):
			_beat(a, str(e.get("key", "m%d" % a.instance)))
	a.burst = mini(BURST_FULL, a.burst + dmg / BURST_DEALT_DIV)
	d.move = ""
	d.blockstun = 0
	d.lock = 0
	d.combo += 1
	var kb: Array = e["kb"]
	var weight := float(Moves.stats(d.character)["weight"])
	var side := side_dir if side_dir != 0.0 else float(a.facing)
	if e.get("away", false):   # (a Burst blows everyone away from the one bursting, front or back)
		side = signf(d.pos.x - a.pos.x) if absf(d.pos.x - a.pos.x) > 1.0 else float(a.facing)
	d.vel = Vector2(float(kb[0]) * side, float(kb[1])) * KB_SCALE / weight
	if d.di != Vector2.ZERO:   # (their lean: added to the knockback - on the ground a flat hit only takes its sideways part)
		var lean := d.di
		if d.grounded() and float(kb[1]) >= 0.0:
			lean.y = 0.0
		d.vel += lean * LEAN_PUSH * (1.0 + 0.1 * d.combo)
	if d.combo == LAUNCH_HIT and d.pos.y >= 0.0 and d.vel.y > -4.0:   # (the 7th hit on the ground always launches)
		d.vel.y = -11.5
	# combo pushback: the longer the combo, the further the hitter's pushed off (not their speed - their place)
	if src == "":   # (combo pushback - on the hitter, when it's their own body that hit)
		a.pos.x -= side * minf(COMBO_PUSH * float(d.combo), COMBO_PUSH_MAX) * 0.5
	if e.get("bounce", false) and not d.bounced:   # (a ground bounce - once a combo)
		if d.pos.y >= 0.0 and float(kb[1]) >= 0.0:
			_bounce(d)
		else:
			d.bounce_due = true
	if e.get("splat", false) and d.splats < SPLATS_MAX:
		d.splat_due = true
	d.facing = -int(side)
	_gain(a, dmg * METER_PER_DMG, d.combo)
	_gain(d, dmg * METER_PER_DMG / 3.0, d.combo)
	for f in [a, d]:   # (a melee hit: both their Free Cancels back, and their Sadness down)
		f.fc = FC_MAX
		if f.sadness == 0:
			f.sad = maxi(SAD_MIN, f.sad - SAD_HIT)
	if e.get("knockdown", false):   # (floored when they land - at once if they never leave the ground)
		d.kd = true
		if d.pos.y >= 0.0 and d.vel.y >= 0.0:
			_floor(d)
	# a landed attack frees the attacker at once (most do) - the next hit is a new turn
	if type == "hit" and src == "" and _kind(a) == "attack" \
			and not bool(Moves.move(a.character, a.move).get("no_cancel", false)):
		_cancels[a.id] = true
	_event(type, a, d, dmg, {"counter": true} if counter else {})


## A grab connects on someone standing who isn't reeling; two grabs meeting push apart (a tech).
func _grab(a: Fighter, d: Fighter, e: Dictionary, kind: Dictionary, live: Dictionary) -> bool:
	var air := bool(Moves.move(a.character, a.move).get("air_grab", false))   # (an air grab takes them out of the air)
	if d.grounded() == air or d.stun > 0 or d.blockstun > 0:
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


## One tick's picture of every fighter, for playback: [x, y, facing, move, frame, state, hp, meter, burst gauge, Free
## Cancels, air options left, sad (0, 1 SAD!, 2 SADNESS!), free to act (1 / 0), blocking low (1 / 0), form (0 Flow,
## 1 Snap, 2 Floor), Tempo beats, fans in hand].
## state: 0 free / in a move, 1 hit, 2 blocking, 3 locked, 4 KO, 5 lying down. Someone free after a hit cancel is
## recorded in the move they landed, on its frame (they hold the strike until they pick - as YOMI draws it).
func record() -> Array:
	var out: Array = []
	for f in fighters:
		var state := 4 if f.ko else (5 if f.down > 0 else (1 if f.stun > 0 else (2 if f.blockstun > 0 \
				else (3 if f.lock > 0 else 0))))
		var sad := 2 if f.sadness > 0 else (1 if f.sad_warned else 0)
		var mv := f.move
		var fr := f.frame
		if mv == "" and f.cancelled != "" and f.actionable():
			mv = f.cancelled
			fr = f.cancel_frame
		var low := 1 if (f.move == "block" or f.blockstun > 0) and f.param.y > 0.0 else 0
		out.append([f.pos.x, f.pos.y, f.facing, mv, fr, state, f.hp, f.meter, f.burst, f.fc,
			AIR_OPTIONS - f.air_moves, sad, 1 if f.actionable() else 0, low, maxi(0, FORMS.find(f.form)), f.tempo, f.fans])
	return out


func to_dict() -> Dictionary:
	var flying: Array = []
	for s: Dictionary in shots:
		var c := s.duplicate()
		c["pos"] = [(s["pos"] as Vector2).x, (s["pos"] as Vector2).y]
		c["vel"] = [(s["vel"] as Vector2).x, (s["vel"] as Vector2).y]
		flying.append(c)
	return {"mode": mode, "tick": tick, "fighters": fighters.map(func(f: Fighter) -> Dictionary: return f.to_dict()),
		"shots": flying, "shot_n": _shot_n, "half": half, "round": round_len, "dmg": dmg_mult, "stun": stun_mult,
		"xf": ",".join(PackedStringArray(xf.keys())), "ceiling": ceiling}


static func from_dict(d: Dictionary) -> Sim:
	var s := Sim.new()
	s.mode = str(d["mode"])
	s.tick = int(d["tick"])
	s.half = float(d.get("half", STAGE_HALF))
	s.round_len = int(d.get("round", ROUND_TICKS))
	s.dmg_mult = float(d.get("dmg", 1.0))
	s.stun_mult = float(d.get("stun", 1.0))
	s.xf = xf_set(str(d.get("xf", "")))
	s.ceiling = float(d.get("ceiling", 900.0))
	for fd: Dictionary in d["fighters"]:
		s.fighters.append(Fighter.from_dict(fd))
	for sd: Dictionary in d.get("shots", []):
		var c := sd.duplicate()
		c["pos"] = Vector2(float(sd["pos"][0]), float(sd["pos"][1]))
		c["vel"] = Vector2(float(sd["vel"][0]), float(sd["vel"][1]))
		for k in ["id", "owner", "team", "dmg", "stun", "block", "chip", "life"]:
			c[k] = int(sd[k])
		for k in ["leg", "out"]:   # (a returning fan)
			if sd.has(k):
				c[k] = int(sd[k])
		if sd.has("hits"):
			c["hits"] = (sd["hits"] as Array).map(func(x: Variant) -> int: return int(x))
		s.shots.append(c)
	s._shot_n = int(d.get("shot_n", 0))
	return s
