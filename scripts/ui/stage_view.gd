class_name StageView
extends Node2D
## The stage on screen. It draws a near-black stage with one white floor line marked every 100 px, every fighter as a
## chunky figure in their own colour (Stick), the ghost of a picked move looping over them, the hit effects (Fx: sparks,
## the freeze on contact, a small shake, combo counts and limb arcs), and a camera that keeps everyone in frame. It draws
## one recorded tick at a time (Sim.record) and knows nothing about turns.
## This look is the first style pass (Timmy, 18 Oct 18:07: "Your suggestion looks good"). It covers picks 1, 3, 4, 5,
## 6, 9 and 10 from the YOMI study in Standoff Workshop/references/yomi/_study/NOTES.md. The study was reference only;
## the drawing is our own.

signal fighter_tapped(id: int)

const COLOURS := [Color("#e5484d"), Color("#3e8ed0"), Color("#46a758"), Color("#f5c518"), Color("#9b5de5"),
	Color("#f7782a")]
const BG := Color("#0b0c10")
const BEYOND := Color("#050507")   ## past the walls
const LINE := Color("#ececf2")     ## the floor
const WALL := Color("#2a2c36")
const GHOST_ALPHA := 0.55
const PAD := 170.0          ## world px kept round everyone
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.8        ## (22:40 "really small": in close, the camera comes right in)
const TIPS := ["hand_f", "hand_b", "foot_f", "foot_b"]
const LAND_TICKS := 7        ## the landing squash
const LEAN := 0.03           ## radians of lean per px a tick of speed (up to LEAN_MAX)
const LEAN_MAX := 0.32   ## what can strike (the one nearest the hit box leaves an arc)

var characters: Array = []   ## per fighter id
var palette: Array = []      ## each fighter's colour (empty = COLOURS in order) - the player picks theirs
var outlines: Array = []     ## each fighter's outline colour (empty = ink) - their Style (02:28)
var trails: Array = []       ## each fighter's trail ("None" / "Glints" / ...) - their Style
var names: Array = []
var frame: Array = []        ## the tick shown (Sim.record)
var ghost: Array = []        ## a preview's ticks, looped
var ghost_only := -1         ## draw only this fighter's ghost (-1 = all that move)
var ghost_ids: Array = []    ## or only these (you and the ones you're guessing for)
var ghost_shots: Array = []  ## the ghost's projectiles, a list per ghost frame
var shots: Array = []        ## the projectiles on the tick shown (Sim.record_shots)
var _shot_trail := {}        ## projectile (owner, kind, ...) -> its last few screen spots, for the fan's trail
var you := -1                ## this phone's fighter (a marker over them)
var deciding: Array = []     ## who's choosing now (a pulse over them)
var fx := Fx.new()           ## sparks, the freeze, the shake, combo counts, arcs
var time_scale := 1.0        ## the playback speed (the effects keep up at 2x)
var half := Sim.STAGE_HALF   ## the match's half stage width (its rules)
var cam := Vector2(0, -120)
var view_top := 70.0        ## the screen area the stage may use (under the cards, above the bar, left of the tabs -
var view_bottom := 680.0    ## the screens set it)
var view_left := 0.0
var ceiling := 900.0         ## (the match's ceiling, for its line)
var view_right := 1280.0
var ghost_play := true      ## the ghost loops; false = held on the scrubbed frame, everyone's predicted spot shown
var show_boxes := false     ## hurt boxes (outlines) and live hit boxes (red) - testing the frames
var quiet := false          ## no effects (skipping ahead)
var sfx: Sfx                 ## the sounds (the game screen's) - none if unset
var _swinging := {}          ## fighter id -> true while an attack's arc is out (its swing sound played once)
var zoom := 0.8
var _ghost_i := 0
var _time := 0.0
var _tip_of := {}            ## "character:move:hit" -> the joint that strikes
var _spin := {}              ## fighter id -> how far round a launched fighter has tumbled (radians)
var _after_n := {}           ## fighter id -> ticks they've been moving fast (an afterimage every other one)
var _land := {}              ## fighter id -> ticks of landing squash left (weight - 19:38)
var _vx := {}                ## fighter id -> how far they moved last tick (they lean into it)
var _tick_n := 0
var _glow: GradientTexture2D
var advantage := {}          ## your pick: enemy id -> the ticks you're free before them (drawn "+N" under them)
var guessing := -1           ## the opponent whose move you're guessing (a "?" over them)


func colour_of(i: int) -> Color:
	return palette[i] if i < palette.size() else COLOURS[i % COLOURS.size()]


func setup(chars: Array, fighter_names: Array) -> void:
	characters = chars
	names = fighter_names
	fx.clear()
	shots = []
	_spin.clear()
	_after_n.clear()
	_land.clear()
	_vx.clear()
	advantage = {}


func show_tick(rec: Array, events: Array = [], flying: Array = []) -> void:
	var prev := frame
	frame = rec
	shots = flying
	for sh: Array in flying:   # (a thrown fan trails a ribbon of her colour - the mods' beams)
		if str(sh[2]) == "fan" and int(sh[3]) < frame.size():
			fx.ribbon(Vector2(float(sh[0]) - float(sh[4]), float(sh[1]) - float(sh[5])), Vector2(float(sh[0]),
					float(sh[1])), colour_of(int(sh[3])))
	for sh: Array in flying:   # (the ground wave kicks up dust as it runs)
		if str(sh[2]) == "ripple" and int(sh[6]) % 3 == 0:
			fx.dust(Vector2(float(sh[0]), -2.0), 0.55, _tick_n * 7 + int(sh[6]))
	if quiet:
		fx.clear()
		_spin.clear()
		queue_redraw()
		return
	for e: Dictionary in events:
		_effect(e, prev)
		if sfx != null:
			sfx.event(e)
	if prev.size() == frame.size():
		_motion_fx(prev)
	fx.settle_combos(frame)
	_arcs()
	queue_redraw()


## What movement shows: a super starting (its flash), fast movers' afterimages, and a launched fighter tumbling.
func _motion_fx(prev: Array) -> void:
	for i in frame.size():
		var r: Array = frame[i]
		var p: Array = prev[i]
		var mv := str(r[3])
		var kind := str(Moves.move(_char(i), mv).get("kind", "")) if mv != "" else ""
		if kind == "super" and int(r[4]) <= 1 and (str(p[3]) != mv or int(p[4]) > int(r[4])):
			fx.super_start(i, _chest(i), colour_of(i), _tick_n * 13 + i, str(Moves.move(_char(i), mv)["name"]),
					Moves.icon_pose(Moves.move(_char(i), mv)), float(r[2]))
			if sfx != null:
				sfx.play("super")
		var speed := maxf(absf(float(r[0]) - float(p[0])), absf(float(r[1]) - float(p[1])) * 0.8)
		var fast := int(r[5]) != 4 and (speed > 5.5 or kind in ["super", "burst"])
		_after_n[i] = int(_after_n.get(i, 0)) + 1 if fast else 0
		if fast and int(_after_n[i]) % 3 == 1:   # (a fading copy every third tick they're quick - fx keeps them longer)
			fx.afterimage(i, r)
		var tr := str(trails[i]) if i < trails.size() else "None"   # (their Style's trail, while they move)
		if tr != "None" and int(r[5]) != 4 and (speed > 2.0 or float(r[1]) < -12.0) and (_tick_n + i) % 2 == 0:
			fx.trail_bit(tr, Vector2(float(r[0]), float(r[1]) - 40.0), colour_of(i), _tick_n * 11 + i)
		var dy := float(r[1]) - float(p[1])
		_vx[i] = float(r[0]) - float(p[0])
		if mv == "glide" and int(r[5]) == 0 and absf(_vx[i]) > 2.0:   # (Silk Glide: a ribbon of her colour along the
			fx.ribbon(Vector2(float(p[0]), -16.0), Vector2(float(r[0]), -16.0), colour_of(i))   # floor - the mods' beams)
		if float(p[1]) < -6.0 and float(r[1]) >= -0.5 and int(r[5]) != 4:   # (landed: squash, and dust if it was a drop)
			_land[i] = LAND_TICKS
			if dy > 6.0:
				fx.dust(Vector2(float(r[0]), 0.0), clampf(dy / 14.0, 0.4, 1.2), _tick_n * 5 + i)
				if sfx != null:
					sfx.play("land", -4.0)
		elif _land.has(i):
			_land[i] = int(_land[i]) - 1
			if int(_land[i]) <= 0:
				_land.erase(i)
		if int(r[5]) == 1 and float(r[1]) >= -0.5 and absf(float(_vx[i])) > 4.0 and _tick_n % 3 == 0:
			fx.dust(Vector2(float(r[0]), 0.0), 0.35, _tick_n * 5 + i)   # (sliding back from a hit: dust off the feet)
		if int(r[5]) == 1 and float(r[1]) < -20.0:   # (launched: they tumble the way they're flying)
			_spin[i] = float(_spin.get(i, 0.0)) - 0.3 * float(r[2])
		else:
			_spin.erase(i)
	_tick_n += 1


## One sim event -> its effect at the point it happened.
func _effect(e: Dictionary, prev: Array) -> void:
	var type := str(e["type"])
	var a := int(e.get("a", -1))
	var d := int(e.get("d", -1))
	var n := int(e["t"]) * 7
	if a < 0 or a >= frame.size():
		return
	var face := float(frame[a][2])
	if type == "ko":   # (a = the one knocked out)
		fx.on_event(type, _chest(a), face, 0, colour_of(a), a, colour_of(a), false, n + a)
		return
	if type == "burst":   # (a = the one bursting out)
		fx.burst_out(a, _chest(a), colour_of(a), n + a)
		return
	if type in ["down", "whiff", "sad", "sadness", "bounce", "splat", "ic", "beat", "onbeat", "catch", "recall",
			"form_snap", "form_floor", "form_flow", "gust", "sweep", "sweep_up", "blink"]:   # (a = who it happened to)
		var at := _chest(a) if not type in ["down", "bounce"] else Vector2(float(frame[a][0]), -6.0)
		if type == "gust":   # (in front of her, low)
			at = Vector2(float(frame[a][0]) + face * 50.0, -70.0)
		if type == "splat":   # (at the wall they hit)
			at = Vector2(signf(float(frame[a][0])) * (half - 4.0), _chest(a).y)
			face = signf(float(frame[a][0]))
		fx.on_event(type, at, face, 0, colour_of(a), a, colour_of(a), false, n + a)
		return
	if type == "shot":   # (a throw: a flash at the hand)
		fx.on_event(type, _chest(a) + Vector2(face * 34.0, -10.0), face, 0, colour_of(a), -1, colour_of(a), false, n + a)
		return
	if type == "countered":   # (Mirror: the strike caught and turned)
		fx.on_event(type, (_chest(a) + _chest(d)) / 2.0 if d >= 0 else _chest(a), face, 0, colour_of(a), d,
				colour_of(d) if d >= 0 else Color.WHITE, false, n + a)
		return
	if type == "time":
		fx.on_event(type, cam, 1.0, 0, Color.WHITE, -1, Color.WHITE, false, n)
		return
	if type == "wall":   # (a = the one bouncing off the wall)
		var side := signf(float(frame[a][0]))
		var at := Vector2(side * (half - 4.0), _chest(a).y)
		fx.on_event(type, at, side, 0, colour_of(a), a, colour_of(a), false, n + a)
		return
	if d < 0 or d >= frame.size():
		return
	var at := _contact(a, d) if type in ["hit", "throw", "armor", "block"] else (_chest(a) + _chest(d)) / 2.0
	var reeling := d < prev.size() and int(prev[d][5]) == 1
	if type == "hit":
		fx.style = _hit_style(e, a)
	fx.on_event(type, at, face, int(e.get("dmg", 0)), colour_of(a), d, colour_of(d), reeling, n + d,
			bool(e.get("counter", false)) or bool(e.get("worse", false)), bool(e.get("push", false)))
	if type == "hit" and int(e.get("spot", 0)) == 1:   # (the fan's edge - a gold glint where it lands)
		fx.on_event("edge", at, face, 0, colour_of(a), d, colour_of(d), false, n + d)


## Step 4: what a hit looks like by what made it - "slash" her fans (her hand strikes, a thrown fan), "wave" the
## ground ripple, "blunt" anything else (kicks, knees).
func _hit_style(e: Dictionary, a: int) -> String:
	var src := str(e.get("src", ""))
	if src != "":
		return "wave" if src == "ripple" else ("slash" if src in ["fan", "airfan"] else "blunt")
	var mv := str(frame[a][3])
	if mv == "" or _char(a) != "dancer":
		return "blunt"
	var tip := _striking(a, mv, int(frame[a][4]))
	return "slash" if tip.begins_with("hand") else "blunt"


func _char(i: int) -> String:
	return str(characters[i]) if i < characters.size() else "dancer"


func _chest(i: int) -> Vector2:
	var h := float(Moves.stats(_char(i))["height"])
	return Vector2(float(frame[i][0]), float(frame[i][1]) - h * 0.62)


## A fighter's hurt box in the world - the same maths as Sim.hurtbox.
func hurt_rect(i: int, r: Array) -> Rect2:
	var st := Moves.stats(_char(i))
	var w := float(st["width"])
	var h := float(st["height"])
	if r.size() > 14 and int(r[14]) == 2 and int(r[5]) != 1:   # (the Floor form: low)
		h = Sim.FLOOR_HEIGHT
	if int(r[5]) == 0 and str(r[3]) != "":   # (a low-profile move)
		var lp: Array = Moves.move(_char(i), str(r[3])).get("low_profile", [])
		if not lp.is_empty() and int(r[4]) >= int(lp[0]) and int(r[4]) <= int(lp[1]):
			h = Sim.FLOOR_HEIGHT
	return Rect2(float(r[0]) - w / 2.0, float(r[1]) - h, w, h)


## A hit entry's box in the world - the same maths as Sim.hitbox.
func hit_rect(r: Array, entry: Dictionary) -> Rect2:
	var b: Array = entry["box"]
	var left := float(r[0]) + float(b[0]) if int(r[2]) == 1 else float(r[0]) - float(b[0]) - float(b[2])
	return Rect2(left, float(r[1]) + float(b[1]), float(b[2]), float(b[3]))


## Where a hit landed: the middle of where the hitter's box meets the other's body (the hit nearest its frame), or the
## body's near side at chest height when there's no box to go by.
func _contact(a: int, d: int) -> Vector2:
	var ra: Array = frame[a]
	var body := hurt_rect(d, frame[d])
	var hits: Array = Moves.move(_char(a), str(ra[3])).get("hits", []) if str(ra[3]) != "" else []
	var best: Dictionary = {}
	var gap := 999
	var f := int(ra[4])
	for e: Dictionary in hits:
		var g := mini(absi(f - int(e["from"])), absi(f - int(e["to"])))
		if f >= int(e["from"]) and f <= int(e["to"]) + 1:
			g = 0
		if g < gap:
			gap = g
			best = e
	if not best.is_empty():
		var box := hit_rect(ra, best)
		if box.intersects(body):
			return box.intersection(body).get_center()
		var c := box.get_center()
		return Vector2(clampf(c.x, body.position.x, body.end.x), clampf(c.y, body.position.y, body.end.y))
	var side := body.position.x if float(ra[0]) < body.get_center().x else body.end.x
	return Vector2(side, _chest(d).y)


## The striking hand or foot leaves an arc from just before its hit is out until it's done (pick 6).
func _arcs() -> void:
	for i in frame.size():
		var r: Array = frame[i]
		var tip := _striking(i, str(r[3]), int(r[4])) if int(r[5]) == 0 and str(r[3]) != "" and not _free(r) else ""
		if tip == "":
			fx.trail_end(i)
			_swinging.erase(i)
			continue
		if not _swinging.has(i) and sfx != null:   # (an attack's arc starting: its swish)
			sfx.play("swing", -2.0, randf_range(0.9, 1.1))
		_swinging[i] = true
		var pose := Poses.for_record(_char(i), r)
		var pivot := "hip" if tip.begins_with("foot") else "neck"
		var tip_w := _world(i, r, pose[tip])
		if tip.begins_with("hand") and _char(i) == "dancer":   # (her fan's edge, not her hand: the slash a fan leaves -
			var elbow := _world(i, r, pose["elbow_" + tip.trim_prefix("hand_")])   # Colossus's sword arcs, 23:01)
			if tip_w.distance_to(elbow) > 0.5:
				tip_w += (tip_w - elbow).normalized() * Stick.FAN_R * float(Moves.stats(_char(i))["height"]) / 100.0
		fx.trail_point(i, tip_w, _world(i, r, pose[pivot]), colour_of(i))


## A pose point (Poses units) in the world for fighter i on record r.
func _world(i: int, r: Array, v: Vector2) -> Vector2:
	var h := float(Moves.stats(_char(i))["height"]) / 100.0
	return Vector2(float(r[0]), float(r[1])) + Vector2(v.x * float(r[2]), v.y) * h


## The joint a move strikes with on this frame ("" outside its hits): the hand or foot that travels furthest around
## the hit, worked out once per move.
func _striking(i: int, mv: String, f: int) -> String:
	var ch := _char(i)
	var hits: Array = Moves.move(ch, mv).get("hits", [])
	for k in hits.size():
		var e: Dictionary = hits[k]
		if f < int(e["from"]) - 5 or f > int(e["to"]) + 3:   # (a longer sweep either side of the hit)
			continue
		var key := "%s:%s:%d" % [ch, mv, k]
		if not _tip_of.has(key):
			var travel := {}
			var last := {}
			for g in range(maxi(0, int(e["from"]) - 3), int(e["to"]) + 2):
				var pose := Poses.for_record(ch, [0.0, 0.0, 1, mv, g, 0, 0, 0])
				for t: String in TIPS:
					if last.has(t):
						travel[t] = float(travel.get(t, 0.0)) + (pose[t] as Vector2).distance_to(last[t])
					last[t] = pose[t]
			var most := "hand_f"
			for t: String in TIPS:
				if float(travel.get(t, 0.0)) > float(travel.get(most, 0.0)):
					most = t
			_tip_of[key] = most
		return str(_tip_of[key])
	return ""


func _process(delta: float) -> void:
	_time += delta
	if not ghost.is_empty() and ghost_play:
		_ghost_i = (_ghost_i + 1) % (ghost.size() + 20)   # (a short hold on the last pose before it loops)
	fx.update(delta * time_scale)
	_follow(delta)
	queue_redraw()


## The camera eases to fit everyone standing (and the ghost).
func _follow(delta: float) -> void:
	if frame.is_empty():
		return
	var lo := INF
	var hi := -INF
	var top := 0.0
	var pts: Array = frame.duplicate()
	for g: Array in ghost:   # (the ghost's whole path, not the frame it's looping on - 02:19 "when I uppercut the camera
		pts.append_array(g)  # start panning in and out constantly")
	for r: Array in pts:
		lo = minf(lo, float(r[0]))
		hi = maxf(hi, float(r[0]))
		top = minf(top, float(r[1]))
	var span := maxf(hi - lo + PAD * 2.0, 400.0)
	var tall := absf(top) + 260.0
	var want_zoom := clampf(minf((view_right - view_left) / span, (view_bottom - view_top) / tall), ZOOM_MIN, ZOOM_MAX)
	var want := Vector2((lo + hi) / 2.0, top * 0.5 - 70.0)
	# the floor always on screen (02:34 "Cant see myself anymore" - a ghost going high had the camera up so far the floor
	# and everyone on it slid under the bar): anything higher can go off the top instead
	var floor_room := view_bottom - 34.0 - _anchor().y
	want.y = maxf(want.y, -floor_room / want_zoom)
	var k := 1.0 - pow(0.02, delta)
	cam = cam.lerp(want, k)
	zoom = lerpf(zoom, want_zoom * (1.0 + fx.punch), k)   # (a big hit pushes the camera in a touch)


## The camera's centre sits a little above the band's middle (the floor near its foot).
func _anchor() -> Vector2:
	return Vector2((view_left + view_right) / 2.0, view_top + (view_bottom - view_top) * 0.6)


func w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + _anchor() + fx.offset


func s2w(p: Vector2) -> Vector2:
	return (p - fx.offset - _anchor()) / zoom + cam


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BG)
	if _glow == null:   # (a soft light behind the action - a radial gradient)
		var g := Gradient.new()
		g.set_color(0, Color(0.5, 0.56, 0.85, 0.075))
		g.set_color(1, Color(0.5, 0.56, 0.85, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	var gr := 760.0 * zoom
	draw_texture_rect(_glow, Rect2(w2s(cam + Vector2(0, 40)) - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false)
	var floor_y := w2s(Vector2(0, 0)).y
	var wl := w2s(Vector2(-half, 0)).x
	var wr := w2s(Vector2(half, 0)).x
	draw_rect(Rect2(wl - vp.x, -20, vp.x, vp.y + 40), BEYOND)
	draw_rect(Rect2(wr, -20, vp.x, vp.y + 40), BEYOND)
	var top_y := w2s(Vector2(0, -ceiling)).y   # (the ceiling - a faint line where heads bump)
	for wx in [wl, wr]:
		draw_line(Vector2(wx, maxf(-20.0, top_y)), Vector2(wx, floor_y), WALL, 3.0)
	if top_y > -10.0:
		draw_line(Vector2(wl, top_y), Vector2(wr, top_y), Color(WALL, 0.6), 2.0)
	# the floor: one white line, a mark every 100 px (longer every 400) so distance reads
	draw_line(Vector2(wl, floor_y), Vector2(wr, floor_y), LINE, 3.0)
	var steps := int(half / 100.0)
	for i in range(-steps, steps + 1):
		var x := w2s(Vector2(i * 100.0, 0)).x
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y + (16.0 if i % 4 == 0 else 9.0)), LINE, 2.0)
	if frame.is_empty():
		return
	for i in frame.size():   # (a faint spot under anyone in the air, so heights read)
		var r: Array = frame[i]
		var lift := clampf(-float(r[1]) / 300.0, 0.0, 0.8)
		if lift > 0.03 and int(r[5]) != 4:
			draw_set_transform(w2s(Vector2(float(r[0]), 0)), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 26.0 * zoom * (1.0 - lift * 0.6), Color(1, 1, 1, 0.12 * (1.0 - lift)))
			draw_set_transform(Vector2.ZERO)
	if not ghost.is_empty():
		var g: Array = ghost[ghost_index()]
		for i in g.size():
			if int(g[i][5]) == 4:
				continue
			if (ghost_ids.is_empty() and (ghost_only < 0 or i == ghost_only)) or ghost_ids.has(i):
				_figure(i, g[i], GHOST_ALPHA)
			elif not ghost_play:   # (held: where everyone else would be on that frame)
				_figure(i, g[i], GHOST_ALPHA * 0.6)
	if not ghost.is_empty():
		_predict_labels()
	fx.draw_back(self)   # (the dark starbursts of hits, behind everyone)
	for a: Dictionary in fx.afters:   # (afterimages - fading copies behind fast movers)
		var id := int(a["id"])
		if id < frame.size():
			_figure(id, a["rec"], 0.5 * (1.0 - float(a["age"]) / float(a["life"])), true)
	for i in frame.size():   # (the knocked out first - the standing stay on top)
		if int(frame[i][5]) == 4:
			_figure(i, frame[i], 1.0)
	for i in frame.size():
		if int(frame[i][5]) != 4:
			_figure(i, frame[i], 1.0)
	fx.draw_trails(self)   # (over the fighters - a kick's path mostly runs along its own leg)
	if not ghost.is_empty() and ghost_index() < ghost_shots.size():   # (the ghost's projectiles, faint)
		for s: Array in ghost_shots[ghost_index()]:
			if ghost_ids.is_empty() or ghost_ids.has(int(s[3])):
				_shot(s, GHOST_ALPHA)
	for s: Array in shots:
		_shot(s, 1.0)
	if fx.dim > 0.0:   # (a super: the stage goes dark round the one starting it)
		draw_rect(Rect2(Vector2(-20, -20), vp + Vector2(40, 40)), Color(0, 0, 0, fx.dim))
		if fx.dim_id >= 0 and fx.dim_id < frame.size():
			_figure(fx.dim_id, frame[fx.dim_id], 1.0)
	if show_boxes:
		var rows: Array = ghost[ghost_index()] if not ghost.is_empty() else frame
		for i in rows.size():
			_boxes(i, rows[i])
	fx.draw_parts(self)
	fx.draw_combos(self, frame)
	_advantage_labels()


## A projectile: [x, y, kind, owner, vx, vy, life]. A fan: three blades spinning, a fading trail; a ripple: a low wave
## running along the floor, its crest bright.
func _shot(s: Array, alpha: float) -> void:
	var at := w2s(Vector2(float(s[0]), float(s[1])))
	var col := colour_of(int(s[3])).lightened(0.35)
	if alpha < 1.0:
		col = col.lerp(BG, 1.0 - alpha)
	var dir := signf(float(s[4])) if absf(float(s[4])) > 0.1 else 1.0
	var spin := float(s[6]) * 0.55 * dir
	match str(s[2]):
		"fan":   # (a folding fan spinning - the same size as the ones in her hands: 00:43 "why the fans [are] so small?")
			var r := Stick.FAN_R * float(Moves.stats(_char(int(s[3])))["height"]) / 100.0 * zoom
			if alpha >= 1.0:   # (the trail - a few fading copies behind)
				var back := Vector2(-float(s[4]), -float(s[5])).normalized() * 9.0 * zoom
				for k in range(3, 0, -1):
					var c := col
					c.a = 0.18 * (4 - k)
					draw_circle(at + back * k, r * (0.8 - 0.12 * k), c, true, -1.0, true)
			var turn := Vector2.from_angle(spin)
			Stick.fan(self, at - turn * r * 0.5, turn, r, 0.9, colour_of(int(s[3])) if alpha >= 1.0 else col,
					alpha >= 1.0)   # (spun round its middle, the way a thrown fan turns)
		"cyclone":   # (her Cyclone super: a whirlwind - rings stacked up its height, turning, wider at the top)
			var turn := float(s[6]) * 0.5
			for k in 7:
				var rx := (12.0 + k * 6.5) * zoom
				var ry := rx * 0.32
				var y := (54.0 - k * 19.0) * zoom
				var cx := sin(turn + k * 0.7) * 7.0 * zoom
				var c := col
				c.a = (0.85 - k * 0.07) * (alpha if alpha < 1.0 else 1.0)
				var ring := PackedVector2Array()
				for n in 17:
					var a := TAU * n / 16.0 + turn * (1.0 + k * 0.1)
					ring.append(at + Vector2(cx + cos(a) * rx, y + sin(a) * ry))
				draw_polyline(ring, c, maxf(1.5, 3.0 * zoom), true)
		"ripple":   # (22:53 "what is the ground wave?" - a shockwave running along the floor off her fans' slam)
			var floor_y := w2s(Vector2(0, 0)).y
			var base := Vector2(at.x, floor_y)
			var pulse := 0.85 + 0.15 * sin(float(s[6]) * 0.9)
			var w := 46.0 * zoom
			var h := 52.0 * zoom * pulse
			for layer in 3:   # (a dome of wind: three shells, the outer faint)
				var k := 1.0 - layer * 0.22
				var dome := PackedVector2Array([base + Vector2(-w * k, 0)])
				for n in 13:
					var u := float(n) / 12.0
					var x := (u * 2.0 - 1.0) * w * k
					var y := -h * k * pow(maxf(0.0, 1.0 - pow(u * 2.0 - 1.0, 2.0)), 0.6)
					dome.append(base + Vector2(x + dir * h * 0.25 * (1.0 - u) * k, y))
				dome.append(base + Vector2(w * k, 0))
				var c := col
				c.a = alpha * (0.16 + 0.12 * layer)
				draw_colored_polygon(dome, c)
				var crest := col.lightened(0.45)
				crest.a = alpha * (0.5 + 0.25 * layer)
				draw_polyline(dome, crest, maxf(1.5, (2.0 + layer * 1.5) * zoom), true)
			for k in 3:   # (streaks of wind trailing it, low)
				var y0 := -(8.0 + k * 12.0) * zoom
				var a0 := base + Vector2(-dir * (w * 0.6 + k * 8.0 * zoom), y0)
				var a1 := a0 + Vector2(-dir * (40.0 + k * 14.0) * zoom, 0)
				var sc := Color(1, 1, 1, alpha * (0.55 - k * 0.15))
				draw_line(a0, a1, sc, maxf(1.0, 2.5 * zoom), true)
			draw_line(base + Vector2(-w, 1), base + Vector2(w, 1), Color(1, 1, 1, alpha * 0.8), maxf(1.5, 3.0 * zoom), true)


func _free(r: Array) -> bool:
	return int(r[12]) == 1 if r.size() > 12 else (str(r[3]) == "" and int(r[5]) == 0)


## YOMI's prediction labels (the research, 00:22): over each ghost picked this turn, "Ready in N" - or "Interrupt in N"
## when it's cut short mid-move - drawn where they'll be then. Yours green when you get your options first or together,
## yellow when an enemy gets theirs first.
func _predict_labels() -> void:
	var ids: Array = ghost_ids if not ghost_ids.is_empty() else ([ghost_only] if ghost_only >= 0 else [])
	var at := {}   # id -> the ghost frame they're free on
	for id: int in ids:
		for k in range(1, ghost.size()):
			var rows: Array = ghost[k]
			if id < rows.size() and _free(rows[id]):
				at[id] = k
				break
	var mine := int(at.get(you, 9999))
	var first_foe := 9999
	for id: int in at:
		if id != you:
			first_foe = mini(first_foe, int(at[id]))
	for id: int in at:
		var k := int(at[id])
		var r: Array = ghost[k][id]
		var cut := str(r[3]) != "" and str(r[3]) != "wait" and int(r[5]) == 0
		var text := ("Interrupt in %d" if cut else "Ready in %d") % k
		var col := colour_of(id).lerp(Color.WHITE, 0.55)
		if id == you:
			col = Color("#5ee08a") if mine <= first_foe else Color("#ffd23f")
		var font := ThemeDB.fallback_font
		var h := float(Moves.stats(_char(id))["height"])
		var p := w2s(Vector2(float(r[0]), float(r[1]) - h * 1.5))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(font, p - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.02, 0.02,
				0.03, 0.9))
		draw_string(font, p - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _ready_label(i: int, r: Array) -> void:
	var font := ThemeDB.fallback_font
	var h := float(Moves.stats(_char(i))["height"])
	var p := w2s(Vector2(float(r[0]), float(r[1]) - h * 1.45))
	var w := font.get_string_size("READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, p - Vector2(w / 2.0, 0), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour_of(i).lerp(Color.WHITE, 0.6))


## On your pick: "+N" over each enemy you're free before - how many ticks they're still tied up (pick 11).
func _advantage_labels() -> void:
	var font := ThemeDB.fallback_font
	for id: int in advantage:
		if id >= frame.size() or int(advantage[id]) <= 0:
			continue
		var r: Array = frame[id]
		var p := w2s(Vector2(float(r[0]), 0.0)) + Vector2(0, 44)   # (under them, below the floor - clear of combo counts)
		var text := "+%d" % int(advantage[id])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var box := Rect2(p - Vector2(w / 2.0 + 7.0, 19.0), Vector2(w + 14.0, 24.0))
		draw_rect(box, Color(0.05, 0.06, 0.08, 0.85))
		draw_rect(box, Color("#7ee0a1"), false, 1.5)
		draw_string(font, p - Vector2(w / 2.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#7ee0a1"))


## The ghost frame on show.
func ghost_index() -> int:
	return mini(_ghost_i, ghost.size() - 1) if not ghost.is_empty() else 0


func scrub_to(i: int) -> void:
	_ghost_i = clampi(i, 0, maxi(0, ghost.size() - 1))
	queue_redraw()


## A fighter's hurt box (outline) and any hit box live on this frame (red) - the same maths as Sim.
func _boxes(i: int, r: Array) -> void:
	if int(r[5]) == 4:
		return
	var body := hurt_rect(i, r)
	draw_rect(Rect2(w2s(body.position), body.size * zoom), Color(1, 1, 1, 0.55), false, 1.5)
	if str(r[3]) == "" or int(r[5]) != 0 or _free(r):
		return
	var m := Moves.move(_char(i), str(r[3]))
	for e: Dictionary in m.get("hits", []):
		if int(r[4]) >= int(e["from"]) and int(r[4]) <= int(e["to"]):
			var box := hit_rect(r, e)
			var rect := Rect2(w2s(box.position), box.size * zoom)
			draw_rect(rect, Color(1.0, 0.2, 0.25, 0.35))
			draw_rect(rect, Color(1.0, 0.3, 0.35, 0.9), false, 2.0)


func _figure(i: int, r: Array, alpha: float, bare := false) -> void:
	var ch := _char(i)
	var h := float(Moves.stats(ch)["height"]) / 100.0
	var base := Vector2(float(r[0]), float(r[1]))
	if alpha >= 1.0 and fx.frozen() and fx.jitter.has(i):   # (the one hit shakes in place through the freeze)
		base.x += sin(_time * 95.0) * 3.0
	var face := float(r[2])
	var col := colour_of(i)
	if int(r[5]) == 4:
		col = col.darkened(0.55)
	elif r.size() > 11 and int(r[11]) == 2:   # (SADNESS!: washed out blue)
		col = col.lerp(Color("#5d7bd6"), 0.55)
	if alpha < 1.0:   # (a ghost: mixed into the stage, not see-through - overlapping limbs stay one flat shape)
		col = col.lerp(BG, 1.0 - alpha)
	elif fx.flash.has(i):   # (the impact frame: drawn white)
		col = Color.WHITE
	var head_r := Stick.head(h * zoom)
	var ink: Color = outlines[i] if i < outlines.size() else Stick.INK   # (their Style's outline)
	var pose := Poses.for_record(ch, r)
	if alpha >= 1.0 and int(r[5]) == 0 and (str(r[3]) == "" or str(r[3]) == "wait") and float(r[1]) >= -1.0:
		var bob := sin(_time * 3.2 + i * 1.3) * 1.6   # (standing free: breathing - the top half rises and falls)
		for j: String in ["head", "neck", "elbow_f", "hand_f", "elbow_b", "hand_b"]:
			pose[j] = (pose[j] as Vector2) + Vector2(0, bob * (1.0 if j in ["head", "neck"] else 0.7))
		pose["hip"] = (pose["hip"] as Vector2) + Vector2(0, bob * 0.4)
	if alpha >= 1.0 and int(r[5]) in [0, 3] and _land.has(i):   # (just landed: sink into a crouch and come back up)
		var k := float(_land[i]) / float(LAND_TICKS)
		pose = Poses.blend(pose, Poses.get_pose("crouch"), 0.65 * k * k)
	if alpha >= 1.0 and int(r[5]) == 0 and float(r[1]) >= -1.0 and absf(float(_vx.get(i, 0.0))) > 1.0:
		# (moving along the ground: the top half leans into it - forward when going the way they face)
		var ang := clampf(float(_vx[i]) * LEAN, -LEAN_MAX, LEAN_MAX) * float(r[2])
		var hip: Vector2 = pose["hip"]
		for j: String in ["head", "neck", "elbow_f", "hand_f", "elbow_b", "hand_b"]:
			pose[j] = hip + ((pose[j] as Vector2) - hip).rotated(ang)
	if alpha >= 1.0 and _spin.has(i):   # (launched: tumbling round their middle)
		var hip: Vector2 = pose["hip"]
		var mid := hip + Vector2(0, -14)
		for j: String in Poses.JOINTS:
			pose[j] = mid + ((pose[j] as Vector2) - mid).rotated(float(_spin[i]))
	var dancer := ch == "dancer"
	var sc := h * zoom
	var open := 0.0
	var fans := 0
	if dancer:   # (21:59 "feel like a dancer. With proper fans": her fans and a sway while she stands - 22:26 "Just go
		# no clothes just fans")
		var mvk := str(Moves.move(ch, str(r[3])).get("kind", "")) if str(r[3]) != "" else ""
		open = Stick.fan_open(int(r[5]), mvk)
		fans = int(r[16]) if r.size() > 16 else 2
		if int(r[5]) == 0 and str(r[3]) in ["", "wait"] and float(r[1]) >= -1.0 and (r.size() <= 14 or int(r[14]) == 0):
			var k := 0.5 + 0.5 * sin(_time * 1.9 + i * 1.1)
			pose = Poses.blend(pose, Poses.get_pose("idle2"), k * (1.0 if alpha >= 1.0 else 0.0))
		var pre := Stick._place(pose, w2s(base), sc, face)
		if fans >= 2 and not bare:   # (an afterimage: just her - its fans would double what it costs to draw)
			Stick.fan_at(self, pre, "b", face, sc, open, col, alpha >= 1.0, Stick.STEEL if alpha >= 1.0 else col, ink)
	var pts := Stick.draw(self, pose, w2s(base), sc, face, col, Stick.limb(sc), head_r, alpha >= 1.0, ink)
	if dancer and fans >= 1 and not bare:   # (ghosts: their fans in their own faded colour, not bright steel)
		Stick.fan_at(self, pts, "f", face, sc, open, col, alpha >= 1.0, Stick.STEEL if alpha >= 1.0 else col, ink)
	if alpha < 1.0:
		return
	if alpha >= 1.0 and r.size() > 15 and int(r[15]) > 0 and int(r[5]) != 4:   # (Tempo: shards of her colour orbit her,
		_tempo_aura(i, pts, int(r[15]), col, h * zoom)                          # one a beat - Yharim's in the mod study)
	if deciding.has(i):
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(pts["head"], head_r + (7.0 + 3.0 * pulse) * zoom, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.4 * pulse), 2.0)
	if i == guessing:   # (the one you're guessing for: a yellow "?" over them)
		var font := ThemeDB.fallback_font
		var q: Vector2 = pts["head"] - Vector2(8, head_r + 12.0 * zoom)
		draw_string_outline(font, q, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.02, 0.02, 0.03))
		draw_string(font, q, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffd23f"))
	if i == you:   # (a small white arrow over your head)
		var tip: Vector2 = pts["head"] - Vector2(0, head_r + 16.0 * zoom)
		var s := maxf(6.0, 9.0 * zoom)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -s * 1.1), tip + Vector2(s, -s * 1.1)]),
				Color.WHITE)


func _tempo_aura(i: int, pts: Dictionary, beats: int, col: Color, sc: float) -> void:
	var mid: Vector2 = (pts["neck"] as Vector2).lerp(pts["hip"], 0.4)
	for k in beats:
		var a := _time * 2.6 + k * TAU / float(beats) + i
		var p := mid + Vector2(cos(a) * 44.0, sin(a) * 18.0) * sc
		var s := (4.5 + (2.0 if beats == Sim.TEMPO_MAX else 0.0)) * sc
		var dir := Vector2.from_angle(a + PI / 2.0)
		var c := col.lightened(0.45)
		if sin(a) < 0.0:   # (the far side of the orbit, behind her - dimmer)
			c = col.darkened(0.2)
		draw_colored_polygon(PackedVector2Array([p + dir * s * 1.8, p + dir.orthogonal() * s * 0.7, p - dir * s * 1.8,
			p - dir.orthogonal() * s * 0.7]), c)


func _unhandled_input(event: InputEvent) -> void:
	var tap := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not tap or frame.is_empty():
		return
	var p := (event as InputEventMouseButton).position
	var best := -1
	var best_d := 70.0
	for i in frame.size():
		if int(frame[i][5]) == 4:
			continue
		var c := w2s(Vector2(float(frame[i][0]), float(frame[i][1]) - 55.0))
		var d := c.distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		fighter_tapped.emit(best)
