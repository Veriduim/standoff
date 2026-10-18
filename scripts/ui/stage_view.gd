class_name StageView
extends Node2D
## The stage on screen: the floor and walls, every fighter as a stick figure in their colour, the ghost of a picked move
## looping over them, hit sparks, and a camera that keeps everyone in frame. Draws one recorded tick at a time
## (Sim.record); knows nothing about turns.

signal fighter_tapped(id: int)

const COLOURS := [Color("#e5484d"), Color("#3e8ed0"), Color("#46a758"), Color("#f5c518"), Color("#9b5de5"),
	Color("#f7782a")]
const BG_TOP := Color("#1b1c24")
const BG_FLOOR := Color("#262833")
const LINE := Color("#0b0b0f")
const GHOST_ALPHA := 0.38
const PAD := 170.0          ## world px kept round everyone
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.35

var characters: Array = []   ## per fighter id
var names: Array = []
var frame: Array = []        ## the tick shown (Sim.record)
var ghost: Array = []        ## a preview's ticks, looped
var ghost_only := -1         ## draw only this fighter's ghost (-1 = all that move)
var target := -1             ## the picked target (a marker over them)
var you := -1                ## this phone's fighter (a marker under them)
var deciding: Array = []     ## who's choosing now (a pulse over them)
var sparks: Array = []       ## [world pos, age, colour]
var cam := Vector2(0, -120)
var view_top := 70.0        ## the screen band the stage may use (under the cards, above the menu - GameScreen sets it)
var view_bottom := 680.0
var quiet := false          ## no sparks (skipping ahead)
var zoom := 0.8
var _ghost_i := 0
var _time := 0.0


func setup(chars: Array, fighter_names: Array) -> void:
	characters = chars
	names = fighter_names


func show_tick(rec: Array, events: Array = []) -> void:
	frame = rec
	if quiet:
		sparks.clear()
		events = []
	for e: Dictionary in events:
		var d := int(e.get("d", -1))
		if d >= 0 and d < frame.size():
			var c := Color.WHITE
			match str(e["type"]):
				"hit", "throw":
					c = Color("#ffd166")
				"block":
					c = Color("#8ecae6")
				"parry":
					c = Color("#ffffff")
				"clash", "tech":
					c = Color("#ff9f1c")
				"ko":
					c = Color("#ef476f")
			var p := Vector2(float(frame[d][0]), float(frame[d][1]) - 60.0)
			sparks.append([p, 0.0, c])
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not ghost.is_empty():
		_ghost_i = (_ghost_i + 1) % (ghost.size() + 20)   # (a short hold on the last pose before it loops)
	for s: Array in sparks:
		s[1] = float(s[1]) + delta
	sparks = sparks.filter(func(s: Array) -> bool: return float(s[1]) < 0.35)
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
	var vp := get_viewport_rect().size
	var span := maxf(hi - lo + PAD * 2.0, 400.0)
	var tall := absf(top) + 260.0
	var want_zoom := clampf(minf(vp.x / span, (view_bottom - view_top) / tall), ZOOM_MIN, ZOOM_MAX)
	var want := Vector2((lo + hi) / 2.0, top * 0.5 - 70.0)
	var k := 1.0 - pow(0.02, delta)
	cam = cam.lerp(want, k)
	zoom = lerpf(zoom, want_zoom, k)


## The camera's centre sits a little above the band's middle (the floor near its foot).
func _anchor() -> Vector2:
	return Vector2(get_viewport_rect().size.x / 2.0, view_top + (view_bottom - view_top) * 0.6)


func w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + _anchor()


func s2w(p: Vector2) -> Vector2:
	return (p - _anchor()) / zoom + cam


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BG_TOP)
	var floor_y := w2s(Vector2(0, 0)).y
	draw_rect(Rect2(0, floor_y, vp.x, vp.y - floor_y), BG_FLOOR)
	draw_line(Vector2(0, floor_y), Vector2(vp.x, floor_y), Color("#4a4e62"), 3.0)
	# floor marks every 200 px (so movement reads) and the walls
	for i in range(-4, 5):
		var x := w2s(Vector2(i * 200.0, 0)).x
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y + 14.0), Color("#3a3d4d"), 2.0)
	for side in [-1.0, 1.0]:
		var wx := w2s(Vector2(side * Sim.STAGE_HALF, 0)).x
		draw_rect(Rect2(wx if side > 0 else wx - vp.x, 0, vp.x, vp.y), Color("#101117"))
		draw_line(Vector2(wx, 0), Vector2(wx, floor_y), Color("#4a4e62"), 4.0)
	if frame.is_empty():
		return
	for i in frame.size():   # shadows
		var r: Array = frame[i]
		var p := w2s(Vector2(float(r[0]), 0))
		var lift := clampf(-float(r[1]) / 300.0, 0.0, 0.7)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 30.0 * zoom * (1.0 - lift), Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
	if not ghost.is_empty():
		var g: Array = ghost[mini(_ghost_i, ghost.size() - 1)]
		for i in g.size():
			if (ghost_only < 0 or i == ghost_only) and int(g[i][5]) != 4:
				_figure(i, g[i], GHOST_ALPHA)
	for i in frame.size():
		_figure(i, frame[i], 1.0)
	for s: Array in sparks:
		var t := float(s[1]) / 0.35
		var c: Color = s[2]
		c.a = 1.0 - t
		draw_arc(w2s(s[0]), (12.0 + 50.0 * t) * zoom, 0, TAU, 20, c, 4.0)


func _figure(i: int, r: Array, alpha: float) -> void:
	var ch := str(characters[i]) if i < characters.size() else "bruiser"
	var st := Moves.stats(ch)
	var h := float(st["height"]) / 100.0
	var thick := 7.0 if ch == "bruiser" else 5.0
	var pose := Poses.for_record(ch, r)
	var base := Vector2(float(r[0]), float(r[1]))
	var face := float(r[2])
	var pts := {}
	for j: String in Poses.JOINTS:
		var v: Vector2 = pose[j]
		pts[j] = w2s(base + Vector2(v.x * face * h, v.y * h))
	var col: Color = COLOURS[i % COLOURS.size()]
	var ko := int(r[5]) == 4
	if ko:
		col = col.darkened(0.55)
	col.a = alpha
	var edge := LINE
	edge.a = alpha
	var w := thick * zoom
	for b: Array in Poses.BONES:   # a dark edge under each bone keeps them readable over each other
		draw_line(pts[b[0]], pts[b[1]], edge, w + 4.0 * zoom, true)
	for b: Array in Poses.BONES:
		draw_line(pts[b[0]], pts[b[1]], col, w, true)
	var head_r := (12.0 if ch == "bruiser" else 10.0) * h * zoom
	draw_circle(pts["head"], head_r + 2.0 * zoom, edge)
	draw_circle(pts["head"], head_r, col)
	if alpha < 1.0:
		return
	if ch == "dancer":   # (her scarf - two lines trailing behind the neck)
		var back := Vector2(-face, 0.0)
		draw_line(pts["neck"], pts["neck"] + (back * 26.0 + Vector2(0, 6)) * zoom, col.lightened(0.35), 3.0 * zoom)
	var over: Vector2 = pts["head"] + Vector2(0, -head_r - 18.0 * zoom)
	if i == target:
		draw_colored_polygon(PackedVector2Array([over + Vector2(-9, -12), over + Vector2(9, -12), over + Vector2(0, 0)]),
				Color("#ff5d73"))
	if deciding.has(i):
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(pts["head"], head_r + (6.0 + 3.0 * pulse) * zoom, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.4 * pulse), 2.0)
	if i == you:
		var feet := w2s(base) + Vector2(0, 10.0 * zoom)
		draw_line(feet + Vector2(-22, 0) * zoom, feet + Vector2(22, 0) * zoom, Color.WHITE, 3.0)


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
