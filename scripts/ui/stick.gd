class_name Stick
extends RefCounted
## Draws one fighter: a pose's joints (Poses, facing right, origin between the feet) scaled, flipped for facing and
## placed. Chunky since the first style pass (Timmy 18 Oct 18:07, pick 1): thick round-ended limbs, a thicker body,
## fists, a big round head, and the far arm and leg a shade darker so the body reads in any pose. A dark edge round it
## all keeps overlapping fighters apart. The stage and the move icons share it.

const BACK := [["neck", "elbow_b"], ["elbow_b", "hand_b"], ["hip", "knee_b"], ["knee_b", "foot_b"]]
const FRONT := [["hip", "knee_f"], ["knee_f", "foot_f"], ["neck", "elbow_f"], ["elbow_f", "hand_f"]]
const BODY := 1.45           ## the body's thickness, in limbs
const FIST := 0.62           ## a fist's radius, in limbs
const FAR := 0.3             ## how much darker the far arm and leg are


## pose: joint -> Vector2 (Poses); thick = a limb's thickness on screen. edge = false for ghosts (no outline).
static func draw(ci: CanvasItem, pose: Dictionary, origin: Vector2, scale: float, facing: float, col: Color,
		thick: float, head_r: float, edge := true) -> Dictionary:
	var pts := {}
	for j: String in Poses.JOINTS:
		var v: Vector2 = pose[j]
		pts[j] = origin + Vector2(v.x * facing, v.y) * scale
	var body := thick * BODY
	var fist := thick * FIST
	if edge:
		var ink := Color(0.02, 0.02, 0.03, col.a)
		var ew := maxf(1.5, thick * 0.3)
		for b: Array in BACK + FRONT:
			_bone(ci, pts[b[0]], pts[b[1]], thick + ew * 2.0, ink)
		_bone(ci, pts["neck"], pts["hip"], body + ew * 2.0, ink)
		for j: String in ["hand_f", "hand_b"]:
			ci.draw_circle(pts[j], fist + ew, ink, true, -1.0, true)
		ci.draw_circle(pts["head"], head_r + ew, ink, true, -1.0, true)
	var far := col.darkened(FAR)
	for b: Array in BACK:
		_bone(ci, pts[b[0]], pts[b[1]], thick, far)
	ci.draw_circle(pts["hand_b"], fist, far, true, -1.0, true)
	_bone(ci, pts["neck"], pts["hip"], body, col)
	for b: Array in FRONT:
		_bone(ci, pts[b[0]], pts[b[1]], thick, col)
	ci.draw_circle(pts["hand_f"], fist, col, true, -1.0, true)
	ci.draw_circle(pts["head"], head_r, col, true, -1.0, true)
	return pts


## A limb: a thick line with round ends.
static func _bone(ci: CanvasItem, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	ci.draw_line(a, b, c, w, true)
	ci.draw_circle(a, w / 2.0, c, true, -1.0, true)
	ci.draw_circle(b, w / 2.0, c, true, -1.0, true)


## A pose's extent (joints + head), for fitting it in a box.
static func bounds(pose: Dictionary, head_r: float) -> Rect2:
	var r := Rect2(pose["hip"], Vector2.ZERO)
	for j: String in Poses.JOINTS:
		r = r.expand(pose[j])
	var h: Vector2 = pose["head"]
	r = r.expand(h - Vector2(head_r, head_r)).expand(h + Vector2(head_r, head_r))
	return r
