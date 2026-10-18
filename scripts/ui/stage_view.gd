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
const ZOOM_MAX := 1.35
const LIMB := 9.0           ## a limb's thickness for a fighter 100 tall (world px)
const HEAD := 11.5          ## the head's radius, the same scale
const TIPS := ["hand_f", "hand_b", "foot_f", "foot_b"]   ## what can strike (the one nearest the hit box leaves an arc)

var characters: Array = []   ## per fighter id
var palette: Array = []      ## each fighter's colour (empty = COLOURS in order) - the player picks theirs
var names: Array = []
var frame: Array = []        ## the tick shown (Sim.record)
var ghost: Array = []        ## a preview's ticks, looped
var ghost_only := -1         ## draw only this fighter's ghost (-1 = all that move)
var you := -1                ## this phone's fighter (a marker over them)
var deciding: Array = []     ## who's choosing now (a pulse over them)
var fx := Fx.new()           ## sparks, the freeze, the shake, combo counts, arcs
var time_scale := 1.0        ## the playback speed (the effects keep up at 2x)
var cam := Vector2(0, -120)
var view_top := 70.0        ## the screen area the stage may use (under the cards, above the bar, left of the tabs -
var view_bottom := 680.0    ## the screens set it)
var view_left := 0.0
var view_right := 1280.0
var ghost_play := true      ## the ghost loops; false = held on the scrubbed frame, everyone's predicted spot shown
var show_boxes := false     ## hurt boxes (outlines) and live hit boxes (red) - testing the frames
var quiet := false          ## no effects (skipping ahead)
var zoom := 0.8
var _ghost_i := 0
var _time := 0.0
var _tip_of := {}            ## "character:move:hit" -> the joint that strikes
var _spin := {}              ## fighter id -> how far round a launched fighter has tumbled (radians)
var _after_n := {}           ## fighter id -> ticks they've been moving fast (an afterimage every other one)
var _tick_n := 0
var advantage := {}          ## your pick: enemy id -> the ticks you're free before them (drawn "+N" over them)


func colour_of(i: int) -> Color:
	return palette[i] if i < palette.size() else COLOURS[i % COLOURS.size()]


func setup(chars: Array, fighter_names: Array) -> void:
	characters = chars
	names = fighter_names
	fx.clear()
	_spin.clear()
	_after_n.clear()
	advantage = {}


func show_tick(rec: Array, events: Array = []) -> void:
	var prev := frame
	frame = rec
	if quiet:
		fx.clear()
		_spin.clear()
		queue_redraw()
		return
	for e: Dictionary in events:
		_effect(e, prev)
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
			fx.super_start(i, _chest(i), colour_of(i), _tick_n * 13 + i)
		var speed := maxf(absf(float(r[0]) - float(p[0])), absf(float(r[1]) - float(p[1])) * 0.8)
		var fast := int(r[5]) != 4 and (speed > 6.5 or kind in ["super", "burst"])
		_after_n[i] = int(_after_n.get(i, 0)) + 1 if fast else 0
		if fast and int(_after_n[i]) % 2 == 1:
			fx.afterimage(i, r)
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
	if type == "wall":   # (a = the one bouncing off the wall)
		var side := signf(float(frame[a][0]))
		var at := Vector2(side * (Sim.STAGE_HALF - 4.0), _chest(a).y)
		fx.on_event(type, at, side, 0, colour_of(a), a, colour_of(a), false, n + a)
		return
	if d < 0 or d >= frame.size():
		return
	var at := _contact(a, d) if type in ["hit", "throw", "armor", "block"] else (_chest(a) + _chest(d)) / 2.0
	var reeling := d < prev.size() and int(prev[d][5]) == 1
	fx.on_event(type, at, face, int(e.get("dmg", 0)), colour_of(a), d, colour_of(d), reeling, n + d,
			bool(e.get("counter", false)))


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
		var tip := _striking(i, str(r[3]), int(r[4])) if int(r[5]) == 0 and str(r[3]) != "" else ""
		if tip == "":
			fx.trail_end(i)
			continue
		var pose := Poses.for_record(_char(i), r)
		var pivot := "hip" if tip.begins_with("foot") else "neck"
		fx.trail_point(i, _world(i, r, pose[tip]), _world(i, r, pose[pivot]), colour_of(i))


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
		if f < int(e["from"]) - 3 or f > int(e["to"]) + 1:
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
	if not ghost.is_empty():
		pts.append_array(ghost[mini(_ghost_i, ghost.size() - 1)])
	for r: Array in pts:
		lo = minf(lo, float(r[0]))
		hi = maxf(hi, float(r[0]))
		top = minf(top, float(r[1]))
	var span := maxf(hi - lo + PAD * 2.0, 400.0)
	var tall := absf(top) + 260.0
	var want_zoom := clampf(minf((view_right - view_left) / span, (view_bottom - view_top) / tall), ZOOM_MIN, ZOOM_MAX)
	var want := Vector2((lo + hi) / 2.0, top * 0.5 - 70.0)
	var k := 1.0 - pow(0.02, delta)
	cam = cam.lerp(want, k)
	zoom = lerpf(zoom, want_zoom, k)


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
	var floor_y := w2s(Vector2(0, 0)).y
	var wl := w2s(Vector2(-Sim.STAGE_HALF, 0)).x
	var wr := w2s(Vector2(Sim.STAGE_HALF, 0)).x
	draw_rect(Rect2(wl - vp.x, -20, vp.x, vp.y + 40), BEYOND)
	draw_rect(Rect2(wr, -20, vp.x, vp.y + 40), BEYOND)
	for wx in [wl, wr]:
		draw_line(Vector2(wx, -20), Vector2(wx, floor_y), WALL, 3.0)
	# the floor: one white line, a mark every 100 px (longer every 400) so distance reads
	draw_line(Vector2(wl, floor_y), Vector2(wr, floor_y), LINE, 3.0)
	var steps := int(Sim.STAGE_HALF / 100.0)
	for i in range(-steps, steps + 1):
		var x := w2s(Vector2(i * 100.0, 0)).x
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y + (16.0 if i % 4 == 0 else 9.0)), LINE, 2.0)
	fx.draw_streaks(self)
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
			if ghost_only < 0 or i == ghost_only:
				_figure(i, g[i], GHOST_ALPHA)
			elif not ghost_play:   # (held: where everyone else would be on that frame)
				_figure(i, g[i], GHOST_ALPHA * 0.6)
	for a: Dictionary in fx.afters:   # (afterimages - fading copies behind fast movers)
		var id := int(a["id"])
		if id < frame.size():
			_figure(id, a["rec"], 0.5 * (1.0 - float(a["age"]) / float(a["life"])))
	for i in frame.size():   # (the knocked out first - the standing stay on top)
		if int(frame[i][5]) == 4:
			_figure(i, frame[i], 1.0)
	for i in frame.size():
		if int(frame[i][5]) != 4:
			_figure(i, frame[i], 1.0)
	fx.draw_trails(self)   # (over the fighters - a kick's path mostly runs along its own leg)
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
	if str(r[3]) == "" or int(r[5]) != 0:
		return
	var m := Moves.move(_char(i), str(r[3]))
	for e: Dictionary in m.get("hits", []):
		if int(r[4]) >= int(e["from"]) and int(r[4]) <= int(e["to"]):
			var box := hit_rect(r, e)
			var rect := Rect2(w2s(box.position), box.size * zoom)
			draw_rect(rect, Color(1.0, 0.2, 0.25, 0.35))
			draw_rect(rect, Color(1.0, 0.3, 0.35, 0.9), false, 2.0)


func _figure(i: int, r: Array, alpha: float) -> void:
	var ch := _char(i)
	var h := float(Moves.stats(ch)["height"]) / 100.0
	var base := Vector2(float(r[0]), float(r[1]))
	if alpha >= 1.0 and fx.frozen() and fx.jitter.has(i):   # (the one hit shakes in place through the freeze)
		base.x += sin(_time * 95.0) * 3.0
	var face := float(r[2])
	var col := colour_of(i)
	if int(r[5]) == 4:
		col = col.darkened(0.55)
	if alpha < 1.0:   # (a ghost: mixed into the stage, not see-through - overlapping limbs stay one flat shape)
		col = col.lerp(BG, 1.0 - alpha)
	elif fx.flash.has(i):   # (the impact frame: drawn white)
		col = Color.WHITE
	var head_r := HEAD * h * zoom
	var pose := Poses.for_record(ch, r)
	if alpha >= 1.0 and _spin.has(i):   # (launched: tumbling round their middle)
		var hip: Vector2 = pose["hip"]
		var mid := hip + Vector2(0, -14)
		for j: String in Poses.JOINTS:
			pose[j] = mid + ((pose[j] as Vector2) - mid).rotated(float(_spin[i]))
	var pts := Stick.draw(self, pose, w2s(base), h * zoom, face, col, LIMB * h * zoom, head_r, alpha >= 1.0)
	if alpha < 1.0:
		return
	if ch == "dancer":   # (her headband - two short tails off the back of the head)
		var back := Vector2(-face, 0.0)
		var knot: Vector2 = pts["head"] + back * head_r * 0.85
		for k in 2:
			var wave := sin(_time * 8.0 + i + k * 1.7) * 2.5
			var mid := knot + (back * 9.0 + Vector2(0, 2.0 + k * 4.0)) * zoom
			var end := knot + (back * (17.0 - k * 4.0) + Vector2(0, 5.0 + k * 8.0 + wave)) * zoom
			draw_polyline(PackedVector2Array([knot, mid, end]), col.lightened(0.4), maxf(2.0, 3.5 * zoom), true)
	if deciding.has(i):
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(pts["head"], head_r + (7.0 + 3.0 * pulse) * zoom, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.4 * pulse), 2.0)
	if i == you:   # (a small white arrow over your head)
		var tip: Vector2 = pts["head"] - Vector2(0, head_r + 16.0 * zoom)
		var s := maxf(6.0, 9.0 * zoom)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -s * 1.1), tip + Vector2(s, -s * 1.1)]),
				Color.WHITE)


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
