class_name Stick
extends RefCounted
## Draws one fighter: a pose's joints (Poses, facing right, origin between the feet) scaled, flipped for facing and
## placed. Chunky since the first style pass (Timmy 18 Oct 18:07, pick 1): thick round-ended limbs, a thicker body,
## fists, a big round head, and the far arm and leg a shade darker so the body reads in any pose. A dark edge round it
## all keeps overlapping fighters apart. The stage and the move icons share it.
## The body's proportions live in `style` (19:32 "I think visually we can do better" - the look is picked on a sheet of
## options drawn by scripts/dev/figure_lab.gd).

const BACK := [["neck", "elbow_b"], ["elbow_b", "hand_b"], ["hip", "knee_b"], ["knee_b", "foot_b"]]
const FRONT := [["hip", "knee_f"], ["knee_f", "foot_f"], ["neck", "elbow_f"], ["elbow_f", "hand_f"]]
const FAR := 0.3             ## how much darker the far arm and leg are
const STEEL := Color("#dfe4ee")   ## the Dancer's war fans: steel ribs and edge (21:59 "proper fans")
const FAN_R := 27.0               ## ...their reach, for a fighter 100 tall - her signature prop, big (23:01 the mods' props)

## limb / head: for a fighter 100 tall; body: the torso's thickness at the chest, in limbs (hips: `hips`); fist: a
## fist's radius in limbs; foot: a foot's length in limbs (0 = none); squash: the legs' length (1 = as posed); ink: the
## outline, in limbs. Optional (22:26 "Look into stick figure designs"): waist (the torso pinched, in limbs); gap (the
## head floating off the neck, in limbs - Animator vs Animation's); ring (1 = a hollow ring head, its band this many
## limbs thick); taper (0-1: limbs thinning toward the hands and feet); toe (pointed toes this many limbs long).
## A - the figure lab's first row (Timmy 19:38: "I actually like option A"; B-D stay in the lab).
static var style := {"limb": 9.0, "head": 11.5, "body": 1.45, "hips": 1.45, "fist": 0.62, "foot": 0.0, "squash": 1.0,
	"ink": 0.3}


## Each character's build over the shared style - the same body, their own prop (22:30 the mods "just do it with their
## props"): the Bruiser broader through the chest, in boxing gloves (05:03 Muay Thai + Little Mac); the Dancer as A is.
const BUILD := {"bruiser": {"fist": 1.2, "body": 1.8, "hips": 1.5, "glove": true}}
const CUFF := Color("#f2f2f7")    ## the gloves' wrist band


## A limb's thickness on screen for a fighter scaled `scale` (pose units -> px).
static func limb(scale: float) -> float:
	return float(style["limb"]) * scale


static func head(scale: float) -> float:
	return float(style["head"]) * scale


## pose: joint -> Vector2 (Poses); thick = a limb's thickness on screen. edge = false for ghosts (no outline).
const INK := Color(0.02, 0.02, 0.03)   ## the outline by default (Style's "Ink")


static func draw(ci: CanvasItem, pose: Dictionary, origin: Vector2, scale: float, facing: float, col: Color,
		thick: float, head_r: float, edge := true, ink_col := INK, ch := "") -> Dictionary:
	var pts := _place(pose, origin, scale, facing)
	var build: Dictionary = BUILD.get(ch, {})
	var glove := bool(build.get("glove", false))
	var gap := float(style.get("gap", 0.0)) * thick
	if gap > 0.0:   # (the head floats a little off the body)
		var up := ((pts["head"] as Vector2) - (pts["neck"] as Vector2)).normalized()
		pts["head"] = (pts["head"] as Vector2) + up * gap
	var taper := float(style.get("taper", 0.0))
	var toe := float(style.get("toe", 0.0)) * thick
	var ring := float(style.get("ring", 0.0)) * thick
	var chest := thick * float(build.get("body", style["body"]))
	var hips := thick * float(build.get("hips", style["hips"]))
	var fist := thick * float(build.get("fist", style["fist"]))
	var foot := thick * float(style["foot"])
	if edge:
		var ink := Color(ink_col.r, ink_col.g, ink_col.b, col.a)   # (the outline - your Style's, 02:28)
		var ew := maxf(1.5, thick * float(style["ink"]))
		for b: Array in BACK + FRONT:
			_bone(ci, pts[b[0]], pts[b[1]], _w(b, 0, thick, taper) + ew * 2.0, _w(b, 1, thick, taper) + ew * 2.0, ink)
		if toe > 0.0:
			for s: String in ["f", "b"]:
				_toe(ci, pts, s, facing, toe + ew, thick * (1.0 - 0.55 * taper) + ew * 2.0, ink)
		_torso(ci, pts, chest + ew * 2.0, thick * float(style.get("waist", 0.0)) + ew * 2.0, hips + ew * 2.0, ink)
		for j: String in ["hand_f", "hand_b"]:
			ci.draw_circle(pts[j], fist + ew, ink, true, -1.0, true)
		if foot > 0.0:
			for s: String in ["f", "b"]:
				_foot(ci, pts, s, facing, foot, thick + ew * 2.0, ink)
		if ring > 0.0:   # (a ring head: inked inside and out)
			ci.draw_arc(pts["head"], head_r - ring / 2.0, 0.0, TAU, 40, ink, ring + ew * 2.0, true)
		else:
			ci.draw_circle(pts["head"], head_r + ew, ink, true, -1.0, true)
	var far := col.darkened(FAR)
	for b: Array in BACK:
		_bone(ci, pts[b[0]], pts[b[1]], _w(b, 0, thick, taper), _w(b, 1, thick, taper), far)
	if toe > 0.0:
		_toe(ci, pts, "b", facing, toe, thick * (1.0 - 0.55 * taper), far)
	if glove:
		_glove(ci, pts, "b", fist, far, CUFF.darkened(FAR))
	else:
		ci.draw_circle(pts["hand_b"], fist * (1.0 - 0.6 * taper), far, true, -1.0, true)
	if foot > 0.0:
		_foot(ci, pts, "b", facing, foot, thick, far)
	_torso(ci, pts, chest, thick * float(style.get("waist", 0.0)), hips, col)
	for b: Array in FRONT:
		_bone(ci, pts[b[0]], pts[b[1]], _w(b, 0, thick, taper), _w(b, 1, thick, taper), col)
	if foot > 0.0:
		_foot(ci, pts, "f", facing, foot, thick, col)
	if toe > 0.0:
		_toe(ci, pts, "f", facing, toe, thick * (1.0 - 0.55 * taper), col)
	if glove:
		_glove(ci, pts, "f", fist, col, CUFF)
	else:
		ci.draw_circle(pts["hand_f"], fist * (1.0 - 0.6 * taper), col, true, -1.0, true)
	if ring > 0.0:
		ci.draw_arc(pts["head"], head_r - ring / 2.0, 0.0, TAU, 40, col, ring, true)
	else:
		ci.draw_circle(pts["head"], head_r, col, true, -1.0, true)
	return pts


## A boxing glove (the Bruiser's): a big round fist in their colour, a thumb along it, a white band at the wrist.
static func _glove(ci: CanvasItem, pts: Dictionary, side: String, r: float, c: Color, cuff: Color) -> void:
	var hand: Vector2 = pts["hand_" + side]
	var elbow: Vector2 = pts["elbow_" + side]
	var d := (hand - elbow).normalized() if hand.distance_to(elbow) > 0.5 else Vector2.RIGHT
	var n := Vector2(-d.y, d.x)
	var band := cuff
	band.a = c.a
	ci.draw_line(hand - d * r * 0.95 - n * r * 0.6, hand - d * r * 0.95 + n * r * 0.6, band, r * 0.5, true)
	ci.draw_circle(hand + d * r * 0.1, r, c.lightened(0.08), true, -1.0, true)
	ci.draw_circle(hand + d * r * 0.1, r * 0.62, c.lightened(0.2), true, -1.0, true)   # (a shine on the leather)
	ci.draw_circle(hand + n * r * 0.6 - d * r * 0.15, r * 0.36, c.darkened(0.12), true, -1.0, true)   # (the thumb)


## A limb's width at its start (end 0) or end (1): with taper, upper arms / thighs start a little thicker and the
## forearms / shins thin out toward the hands and feet.
static func _w(b: Array, end: int, thick: float, taper: float) -> float:
	if taper <= 0.0:
		return thick
	var upper := str(b[0]) in ["neck", "hip"]
	if upper:
		return thick * (1.0 + 0.15 * taper if end == 0 else 1.0 - 0.25 * taper)
	return thick * (1.0 - 0.25 * taper if end == 0 else 1.0 - 0.55 * taper)


## A pointed toe off the ankle: on along the shin, leaning the way she faces - a dancer's pointed foot.
static func _toe(ci: CanvasItem, pts: Dictionary, side: String, facing: float, length: float, w: float, c: Color) -> void:
	var ankle: Vector2 = pts["foot_" + side]
	var shin: Vector2 = ankle - (pts["knee_" + side] as Vector2)
	var d := (shin.normalized() + Vector2(facing, 0.0) * 0.9).normalized() if shin.length() > 0.01 else Vector2(facing, 0)
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([ankle + n * w / 2.0, ankle + d * length, ankle - n * w / 2.0]), c)
	ci.draw_circle(ankle, w / 2.0, c, true, -1.0, true)


## The body: neck to hip, chest-wide at the top and hips-wide at the bottom - pinched in at the waist when the style
## has one (waist > 0: its width in limbs, 22:12 "I want their model to be better").
static func _torso(ci: CanvasItem, pts: Dictionary, chest: float, waist: float, hips: float, c: Color) -> void:
	if waist <= 0.0 or float(style.get("waist", 0.0)) <= 0.0:
		_bone(ci, pts["neck"], pts["hip"], chest, hips, c)
		return
	var mid: Vector2 = (pts["neck"] as Vector2).lerp(pts["hip"], 0.62)
	_bone(ci, pts["neck"], mid, chest, waist, c)
	_bone(ci, mid, pts["hip"], waist, hips, c)


## The pose's joints on screen: the legs squashed toward the hip by `squash` (the body rides lower), then scaled,
## flipped and placed.
static func _place(pose: Dictionary, origin: Vector2, scale: float, facing: float) -> Dictionary:
	var sq := float(style["squash"])
	var hip: Vector2 = pose["hip"]
	var drop := -hip.y * (1.0 - sq)   # (how much lower everything above the hips sits)
	var pts := {}
	for j: String in Poses.JOINTS:
		var v: Vector2 = pose[j]
		if j.begins_with("knee") or j.begins_with("foot"):
			v = Vector2(v.x, hip.y + (v.y - hip.y) * sq + drop)
		else:
			v = v + Vector2(0, drop)
		pts[j] = origin + Vector2(v.x * facing, v.y) * scale
	return pts


## A limb: a line from a to b, wa thick at a and wb at b, with round ends.
static func _bone(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, c: Color) -> void:
	if is_equal_approx(wa, wb):
		ci.draw_line(a, b, c, wa, true)
	else:
		var d := (b - a)
		if d.length() > 0.01:
			var n := Vector2(-d.y, d.x).normalized()
			ci.draw_colored_polygon(PackedVector2Array([a + n * wa / 2.0, b + n * wb / 2.0, b - n * wb / 2.0,
					a - n * wa / 2.0]), c)
	ci.draw_circle(a, wa / 2.0, c, true, -1.0, true)
	ci.draw_circle(b, wb / 2.0, c, true, -1.0, true)


## A foot: a short block off the ankle, across the shin, toes the way they face.
static func _foot(ci: CanvasItem, pts: Dictionary, side: String, facing: float, length: float, w: float, c: Color) -> void:
	var ankle: Vector2 = pts["foot_" + side]
	var shin: Vector2 = ankle - (pts["knee_" + side] as Vector2)
	var across := Vector2(-shin.y, shin.x).normalized() if shin.length() > 0.01 else Vector2(facing, 0)
	if across.x * facing < 0.0 or (is_zero_approx(across.x) and across.y < 0.0):
		across = -across
	_bone(ci, ankle, ankle + across * length, w, w * 0.85, c)


## The Dancer's folding fans (Timmy 21:59 "With proper fans"): how open they are for what she's doing - shut when hit,
## down or moving, half open standing, wide on strikes, open as a shield guarding.
static func fan_open(state: int, kind: String) -> float:
	if state in [1, 4, 5]:
		return 0.1
	match kind:
		"attack", "special", "super", "grab", "counter", "burst":
			return 1.0
		"guard":
			return 0.85
		"move", "getup":
			return 0.18
	return 0.55


## A fan held in a hand (side "f" / "b"): pointing on along the forearm, tipped up a little.
static func fan_at(ci: CanvasItem, pts: Dictionary, side: String, facing: float, scale: float, open: float, col: Color,
		edge := true, metal := STEEL, ink_col := INK, turn := 0.0) -> void:
	var hand: Vector2 = pts["hand_" + side]
	var elbow: Vector2 = pts["elbow_" + side]
	var dir := (hand - elbow).normalized() if hand.distance_to(elbow) > 0.5 else Vector2(facing, 0.0)
	dir = dir.rotated(-0.3 * facing + turn)   # (turn: lagging behind the arm - StageView's spring, 06:38)
	fan(ci, hand - dir * 2.0 * scale, dir, FAN_R * scale, open, col.darkened(FAR) if side == "b" else col, edge,
			metal.darkened(FAR) if side == "b" else metal, ink_col)


## A folding war fan: pivot, the way it points (unit, on screen), its reach; open 0 (shut - a stick) to 1 (spread wide).
## The leaf in `col` (the fighter's colour), steel ribs and a steel edge (`metal` - a ghost passes its own faded colour),
## an ink outline.
static func fan(ci: CanvasItem, pivot: Vector2, dir: Vector2, radius: float, open: float, col: Color, edge := true,
		metal := STEEL, ink_col := INK) -> void:
	var half := lerpf(0.07, 1.25, clampf(open, 0.0, 1.0))
	var a0 := dir.angle() - half
	var a1 := dir.angle() + half
	var n := 8
	var inner := radius * 0.32
	var gold := metal
	gold.a = col.a
	var ink := Color(ink_col.r, ink_col.g, ink_col.b, col.a)
	var tri := PackedVector2Array()   # (02:39 "choppy ... with 4": the ink edge and the leaf, one batched draw - not 16)
	var cols := PackedColorArray()
	if edge:   # (the ink edge: the leaf a little bigger, under it)
		var e := maxf(1.5, radius * 0.09)
		var ea := e / maxf(radius, 1.0)
		for k in n:
			var u0 := lerpf(a0 - ea, a1 + ea, float(k) / n)
			var u1 := lerpf(a0 - ea, a1 + ea, float(k + 1) / n)
			_quad(tri, cols, pivot + Vector2.from_angle(u0) * (radius + e), pivot + Vector2.from_angle(u1) * (radius + e),
				pivot + Vector2.from_angle(u1) * maxf(0.0, inner - e), pivot + Vector2.from_angle(u0) * maxf(0.0, inner - e), ink)
	for k in n:   # (the leaf, a quad a fold)
		var u0 := lerpf(a0, a1, float(k) / n)
		var u1 := lerpf(a0, a1, float(k + 1) / n)
		var c := col.lightened(0.18) if k % 2 == 0 else col
		_quad(tri, cols, pivot + Vector2.from_angle(u0) * radius, pivot + Vector2.from_angle(u1) * radius,
			pivot + Vector2.from_angle(u1) * inner, pivot + Vector2.from_angle(u0) * inner, c)
	tris(ci, tri, cols)
	var w := maxf(1.0, radius * 0.07)
	var ribs := PackedVector2Array()   # (the ribs, from the pivot - one draw)
	for k in 5:
		var u := lerpf(a0, a1, float(k) / 4.0)
		ribs.append(pivot)
		ribs.append(pivot + Vector2.from_angle(u) * radius)
	ci.draw_multiline(ribs, gold.darkened(0.2), w, true)
	var rim := PackedVector2Array()
	for k in n + 1:
		rim.append(pivot + Vector2.from_angle(lerpf(a0, a1, float(k) / n)) * radius)
	ci.draw_polyline(rim, gold, maxf(1.5, radius * 0.11), true)
	ci.draw_circle(pivot, w * 1.3, gold, true, -1.0, true)


## Two triangles of a quad (a, b, c, d round its edge) into a batch.
static func _quad(tri: PackedVector2Array, cols: PackedColorArray, a: Vector2, b: Vector2, c: Vector2, d: Vector2,
		col: Color) -> void:
	for p: Vector2 in [a, b, c, a, c, d]:
		tri.append(p)
		cols.append(col)


## A batch of triangles (every three points one, each point its colour) in one draw call - the 2D renderer otherwise
## sends each polygon on its own (a phone wants few draws).
static func tris(ci: CanvasItem, tri: PackedVector2Array, cols: PackedColorArray) -> void:
	if tri.is_empty():
		return
	var idx := PackedInt32Array()
	idx.resize(tri.size())
	for i in tri.size():
		idx[i] = i
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, tri, cols)


## A pose's extent (joints + head), for fitting it in a box.
static func bounds(pose: Dictionary, head_r: float) -> Rect2:
	var r := Rect2(pose["hip"], Vector2.ZERO)
	for j: String in Poses.JOINTS:
		r = r.expand(pose[j])
	var h: Vector2 = pose["head"]
	r = r.expand(h - Vector2(head_r, head_r)).expand(h + Vector2(head_r, head_r))
	return r
