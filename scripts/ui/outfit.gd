class_name Outfit
extends RefCounted
## The Dancer's look over the stick figure (Timmy 22:12: "I want their model to be better as well as I dont like the
## headband. Maybe investigate pixel art for dancers to help?"). What made the dancers in the study pictures read
## (Standoff Workshop/references/dancer - study only): flowing hair, cloth that swings (panels, a skirt), long sleeves,
## a waist. All drawn from the posed joints, so every move gets them for free. `look` = the pieces on; back() goes
## under the body, front() over it.

const HAIR := Color("#241f2f")
const LOOKS := {
	"1": {"name": "1  Ponytail + cloth panels", "hair": "ponytail", "panels": true},
	"2": {"name": "2  Bun + veil + skirt", "hair": "bun", "veil": true, "skirt": true},
	"3": {"name": "3  Long hair + sleeves + panels", "hair": "long", "sleeves": true, "panels": true},
	"4": {"name": "4  Ponytail + veil + skirt + sleeves", "hair": "ponytail", "veil": true, "skirt": true,
		"sleeves": true},
}

static var look := {}   ## the Dancer's pieces (empty = the plain figure)


## Her hair: her colour, deep - dark, but it still shows on the dark stage.
static func _hair(col: Color) -> Color:
	var h := col.darkened(0.62).lerp(HAIR, 0.3)
	h.a = col.a
	return h


static func _ink(c: Color) -> Color:
	return Color(0.02, 0.02, 0.03, c.a)


## A tapered line through pts, w0 thick at the start to w1 at the end, an ink edge.
static func _strand(ci: CanvasItem, pts: Array[Vector2], w0: float, w1: float, col: Color, edge: bool) -> void:
	for pass_n in (2 if edge else 1):
		for k in pts.size() - 1:
			var w := lerpf(w0, w1, float(k) / maxf(1.0, pts.size() - 2))
			var c := _ink(col) if pass_n == 0 and edge else col
			ci.draw_line(pts[k], pts[k + 1], c, w + (3.0 if pass_n == 0 and edge else 0.0), true)
			ci.draw_circle(pts[k + 1], (w + (3.0 if pass_n == 0 and edge else 0.0)) / 2.0, c, true, -1.0, true)


## Under the body: the hair's tail, the back cloth panel, the back sleeve.
static func back(ci: CanvasItem, pts: Dictionary, sc: float, face: float, col: Color, head_r: float, t: float, vx: float,
		edge := true) -> void:
	if look.is_empty():
		return
	var hair := _hair(col)
	var head: Vector2 = pts["head"]
	match str(look.get("hair", "")):
		"ponytail":   # (high at the back of the head, swinging - longer the faster she goes)
			var tie := head + Vector2(-face * head_r * 0.55, -head_r * 0.8)
			var tail: Array[Vector2] = [tie]
			for k in range(1, 8):
				var u := float(k)
				var wave := sin(t * 5.0 + u * 0.7) * u * 0.55 * sc
				tail.append(tie + Vector2(-face * u * 5.2 * sc - vx * u * 0.5 * sc, u * 2.6 * sc + u * u * 0.32 * sc + wave))
			_strand(ci, tail, head_r * 0.62, head_r * 0.16, hair, edge)
			if edge:   # (a sheen along it)
				var sheen: Array[Vector2] = []
				for k in range(1, 6):
					sheen.append(tail[k] + Vector2(0, -head_r * 0.12))
				_strand(ci, sheen, head_r * 0.14, head_r * 0.06, hair.lightened(0.35), false)
		"long":   # (falling down her back to the shoulder blades, swaying)
			var nape := head + Vector2(-face * head_r * 0.7, -head_r * 0.2)
			for side in [0.0, 1.0]:
				var fall: Array[Vector2] = [nape + Vector2(face * side * head_r * 0.3, 0.0)]
				for k in range(1, 7):
					var u := float(k)
					var wave := sin(t * 3.5 + u * 0.6 + side) * u * 0.45 * sc
					fall.append(fall[0] + Vector2(-face * (u * 2.4 + side * 2.0) * sc - vx * u * 0.4 * sc + wave,
							u * 6.8 * sc))
				_strand(ci, fall, head_r * 0.7, head_r * 0.35, hair, edge)
	if look.get("panels", false):   # (the back panel off her belt, trailing)
		var hip: Vector2 = pts["hip"]
		var bottom := hip + Vector2(-face * 10.0 * sc - vx * 2.0 * sc, 34.0 * sc) + Vector2(sin(t * 4.0) * 2.0 * sc, 0.0)
		_panel(ci, hip + Vector2(-face * 3.0 * sc, -2.0 * sc), bottom, 9.0 * sc, 7.0 * sc, col.darkened(0.25), edge)
	if look.get("sleeves", false):
		_sleeve(ci, pts, "b", sc, face, col.darkened(0.3), t, vx, edge)


## Over the body: the front panel or the skirt, the hair on her head (a cap, a bun and its pins), the veil, the front
## sleeve.
static func front(ci: CanvasItem, pts: Dictionary, sc: float, face: float, col: Color, head_r: float, t: float, vx: float,
		edge := true) -> void:
	if look.is_empty():
		return
	var hip: Vector2 = pts["hip"]
	var neck: Vector2 = pts["neck"]
	var cloth := col.lightened(0.22)
	if look.get("skirt", false):   # (from her hips, flaring out over the tops of the legs - a fan from the hip)
		var kf: Vector2 = pts["knee_f"]
		var kb: Vector2 = pts["knee_b"]
		var top := hip.lerp(neck, 0.1)
		var af := (kf - hip).angle()
		var ab := (kb - hip).angle()
		var span := wrapf(af - ab, -PI, PI)
		var reach := 25.0 * sc
		var flare := 0.28 + absf(vx) * 0.02
		var arc := PackedVector2Array([top])
		for k in 7:
			var a := ab - signf(span if span != 0.0 else 1.0) * flare + (span + signf(span if span != 0.0 else 1.0) * flare * 2.0) * float(k) / 6.0
			arc.append(hip + Vector2.from_angle(a) * reach)
		if edge:
			var ink_arc := PackedVector2Array()
			for p in arc:
				ink_arc.append(hip + (p - hip) * 1.08 + Vector2(0, 0))
			for k in range(1, ink_arc.size() - 1):
				ci.draw_colored_polygon(PackedVector2Array([ink_arc[0], ink_arc[k], ink_arc[k + 1]]), _ink(col))
		for k in range(1, arc.size() - 1):
			ci.draw_colored_polygon(PackedVector2Array([arc[0], arc[k], arc[k + 1]]), cloth if k % 2 == 0 else col.lightened(0.1))
	elif look.get("panels", false):   # (the front panel, hanging between her legs, pushed by the front thigh)
		var kf2: Vector2 = pts["knee_f"]
		var down := hip + Vector2(face * 2.0 * sc, 34.0 * sc)
		var bottom := down.lerp(kf2 + Vector2(0, 10.0 * sc), 0.35) + Vector2(sin(t * 4.0 + 1.0) * 1.5 * sc - vx * 0.8 * sc, 0.0)
		_panel(ci, hip + Vector2(face * 3.0 * sc, -2.0 * sc), bottom, 10.0 * sc, 7.5 * sc, cloth, edge)
	if look.get("panels", false) or look.get("skirt", false):   # (a belt)
		var b0 := hip.lerp(neck, 0.08)
		var across := Vector2(face * 7.5 * sc, 0.0)
		ci.draw_line(b0 - across, b0 + across, _ink(col), 5.0 * sc + 2.0, true)
		ci.draw_line(b0 - across, b0 + across, Outfit.HAIR.lerp(col, 0.25) if col.a >= 1.0 else col, 5.0 * sc, true)
	var head: Vector2 = pts["head"]
	var hair := _hair(col)
	if look.has("hair"):   # (hair on top and at the back of her head)
		var cap := PackedVector2Array([head + Vector2(face * head_r * 0.15, -head_r * 0.05)])
		for k in 9:
			var a := lerpf(-PI * 0.42, -PI * 1.15, float(k) / 8.0)   # (from the forehead over the top to the nape)
			cap.append(head + Vector2(cos(a) * face, sin(a)) * head_r * 1.06)
		for k in range(1, cap.size() - 1):
			ci.draw_colored_polygon(PackedVector2Array([cap[0], cap[k], cap[k + 1]]), hair)
	if str(look.get("hair", "")) == "bun":
		var bun := head + Vector2(-face * head_r * 0.85, -head_r * 0.6)
		if edge:
			ci.draw_circle(bun, head_r * 0.55 + 1.5, _ink(col), true, -1.0, true)
		ci.draw_circle(bun, head_r * 0.55, hair, true, -1.0, true)
		for k in 2:   # (two pins standing out of it, up and back)
			var d := Vector2(-face * (0.35 + k * 0.5), -1.0).normalized()
			ci.draw_line(bun + d * head_r * 0.3, bun + d * head_r * 1.05, Stick.STEEL if col.a >= 1.0 else col,
					maxf(1.5, head_r * 0.13), true)
			ci.draw_circle(bun + d * head_r * 1.05, maxf(1.5, head_r * 0.13), Stick.STEEL if col.a >= 1.0 else col, true,
					-1.0, true)
	if look.get("veil", false):   # (a veil over her nose and mouth, as a masked fighter's)
		var veil := PackedVector2Array([head + Vector2(-face * head_r * 0.1, head_r * 0.05)])
		for k in 7:
			var a := lerpf(-0.15, PI * 0.62, float(k) / 6.0)
			veil.append(head + Vector2(cos(a) * face, sin(a)) * head_r * 1.04)
		var vc := col.darkened(0.45)
		for k in range(1, veil.size() - 1):
			ci.draw_colored_polygon(PackedVector2Array([veil[0], veil[k], veil[k + 1]]), vc)
		ci.draw_line(veil[1], veil[1] + Vector2(-face * head_r * 0.9, head_r * 0.15), col.lightened(0.35),
				maxf(1.0, head_r * 0.12), true)
	if look.get("sleeves", false):
		_sleeve(ci, pts, "f", sc, face, col.lightened(0.3), t, vx, edge)


## A cloth panel: from its top centre to its bottom centre, w0 wide at the top, w1 at the bottom.
static func _panel(ci: CanvasItem, top: Vector2, bottom: Vector2, w0: float, w1: float, c: Color, edge: bool) -> void:
	var d := bottom - top
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var quad := PackedVector2Array([top + n * w0 / 2.0, top - n * w0 / 2.0, bottom - n * w1 / 2.0, bottom + n * w1 / 2.0])
	if edge:
		var e := 1.6
		ci.draw_colored_polygon(PackedVector2Array([top + n * (w0 / 2.0 + e), top - n * (w0 / 2.0 + e),
			bottom - n * (w1 / 2.0 + e) + d.normalized() * e, bottom + n * (w1 / 2.0 + e) + d.normalized() * e]), _ink(c))
	ci.draw_colored_polygon(quad, c)


## A long sleeve off the wrist - a silk ribbon trailing back from the hand and falling.
static func _sleeve(ci: CanvasItem, pts: Dictionary, side: String, sc: float, face: float, c: Color, t: float, vx: float,
		edge: bool) -> void:
	var hand: Vector2 = pts["hand_" + side]
	var elbow: Vector2 = pts["elbow_" + side]
	var cuff := hand.lerp(elbow, 0.3)   # (from the wrist it hangs: falling, trailing back as she moves)
	var line: Array[Vector2] = [cuff]
	for k in range(1, 6):
		var u := float(k)
		var wave := sin(t * 6.0 + u * 0.9 + (0.0 if side == "f" else 2.0)) * u * 0.9 * sc
		line.append(cuff + Vector2(-face * u * 1.6 * sc - vx * u * 0.6 * sc + wave, u * 5.2 * sc))
	_strand(ci, line, 7.0 * sc, 3.0 * sc, c, edge)
