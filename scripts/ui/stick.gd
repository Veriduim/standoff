class_name Stick
extends RefCounted
## Draws one stick figure: a pose's joints (Poses, facing right, origin between the feet) scaled, flipped for facing
## and placed - a dark edge under every bone so overlapping fighters stay readable. The stage and the move icons share it.


## pose: joint -> Vector2 (Poses); to_screen maps a pose point (already scaled / flipped) to the canvas.
static func draw(ci: CanvasItem, pose: Dictionary, origin: Vector2, scale: float, facing: float, col: Color,
		thick: float, head_r: float) -> Dictionary:
	var pts := {}
	for j: String in Poses.JOINTS:
		var v: Vector2 = pose[j]
		pts[j] = origin + Vector2(v.x * facing, v.y) * scale
	var edge := Color(0.04, 0.04, 0.06, col.a)
	for b: Array in Poses.BONES:
		ci.draw_line(pts[b[0]], pts[b[1]], edge, thick + maxf(2.0, thick * 0.6), true)
	for b: Array in Poses.BONES:
		ci.draw_line(pts[b[0]], pts[b[1]], col, thick, true)
	ci.draw_circle(pts["head"], head_r + maxf(1.5, thick * 0.3), edge)
	ci.draw_circle(pts["head"], head_r, col)
	return pts


## A pose's extent (joints + head), for fitting it in a box.
static func bounds(pose: Dictionary, head_r: float) -> Rect2:
	var r := Rect2(pose["hip"], Vector2.ZERO)
	for j: String in Poses.JOINTS:
		r = r.expand(pose[j])
	var h: Vector2 = pose["head"]
	r = r.expand(h - Vector2(head_r, head_r)).expand(h + Vector2(head_r, head_r))
	return r
