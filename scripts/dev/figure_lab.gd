extends Node2D
## Dev: the same poses drawn in each candidate body style, one labelled row each, saved as one PNG (Timmy 19:32: "I
## think visually we can do better" - YOMI's fighters, study only, are compact: a big head, a solid torso wider than
## the limbs, short thick limbs, feet).   godot --path . -- --figlab=<out.png>

const POSES := ["idle", "walk1", "side_kick", "spin2", "fan_up", "glide", "uppercut", "hurt", "jump", "crouch"]
const OPEN := [0.55, 0.18, 1.0, 1.0, 1.0, 1.0, 1.0, 0.1, 0.18, 0.55]   ## her fans, as each pose would hold them
## 22:26 "Just go no clothes just fans. Look into stick figure designs" - the study's directions (Standoff Workshop/
## references/stick): A as now; B Animator vs Animation (a ring head off the body, even limbs); C a dancer's line
## (tapering limbs, pointed toes, a waist, longer legs, the head off the body); D Henry Stickmin-ish (a big head, thin
## limbs); E C with a ring head.
const DESIGNS := [
	["A  now", {"limb": 9.0, "head": 11.5, "body": 1.45, "hips": 1.45, "fist": 0.62, "foot": 0.0, "squash": 1.0,
		"ink": 0.3}],
	["B  ring head", {"limb": 7.5, "head": 12.5, "body": 1.0, "hips": 1.0, "fist": 0.0, "foot": 0.0, "squash": 1.0,
		"ink": 0.3, "gap": 0.7, "ring": 0.75}],
	["C  dancer line", {"limb": 8.5, "head": 11.0, "body": 1.4, "hips": 1.25, "fist": 0.5, "foot": 0.0, "squash": 1.08,
		"ink": 0.3, "gap": 0.45, "taper": 1.0, "toe": 1.6, "waist": 0.85}],
	["D  big head", {"limb": 6.0, "head": 16.0, "body": 1.0, "hips": 1.0, "fist": 0.7, "foot": 0.0, "squash": 1.0,
		"ink": 0.35, "gap": 0.6}],
	["E  dancer + ring", {"limb": 8.5, "head": 12.0, "body": 1.4, "hips": 1.25, "fist": 0.5, "foot": 0.0, "squash": 1.08,
		"ink": 0.3, "gap": 0.55, "taper": 1.0, "toe": 1.6, "waist": 0.85, "ring": 0.8}],
]
const OLD_VARIANTS := [
	["A  now", {"limb": 9.0, "head": 11.5, "body": 1.45, "hips": 1.45, "fist": 0.62, "foot": 0.0, "squash": 1.0,
		"ink": 0.3}],
	["B  chunky", {"limb": 13.0, "head": 15.0, "body": 1.9, "hips": 1.5, "fist": 0.66, "foot": 1.0, "squash": 0.92,
		"ink": 0.22}],
	["C  compact", {"limb": 15.0, "head": 17.5, "body": 2.2, "hips": 1.6, "fist": 0.68, "foot": 1.1, "squash": 0.85,
		"ink": 0.2}],
	["D  heavy top", {"limb": 13.0, "head": 18.0, "body": 2.4, "hips": 1.3, "fist": 0.8, "foot": 1.0, "squash": 0.88,
		"ink": 0.2}],
]
const COLS := [Color("#e5484d"), Color("#3e8ed0"), Color("#46a758"), Color("#f5c518")]
const CELL := Vector2(118, 175)

var out := ""


func run(path: String) -> void:
	out = path
	get_window().size = Vector2i(int(CELL.x * POSES.size() + 230), int(CELL.y * DESIGNS.size() + 260))
	queue_redraw()
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("figlab ", out)
	get_tree().quit()


func _draw() -> void:
	var keep: Dictionary = Stick.style.duplicate()
	draw_rect(Rect2(Vector2.ZERO, Vector2(4000, 4000)), Color("#0b0c10"))
	var font := ThemeDB.fallback_font
	for r in DESIGNS.size():
		var v: Array = DESIGNS[r]
		Stick.style = v[1]
		var y := 70.0 + CELL.y * (r + 1) - 22.0
		draw_line(Vector2(140, y), Vector2(140 + CELL.x * POSES.size(), y), Color("#ececf2"), 2.0)
		draw_string(font, Vector2(10, y - 70), str(v[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		for k in POSES.size():
			var s := 1.25
			var origin := Vector2(140 + CELL.x * (k + 0.5), y)
			var col: Color = COLS[0]
			var pose := Poses.get_pose(POSES[k])
			Stick.fan_at(self, Stick._place(pose, origin, s, 1.0), "b", 1.0, s, float(OPEN[k]), col)
			var pts := Stick.draw(self, pose, origin, s, 1.0, col, Stick.limb(s), Stick.head(s))
			Stick.fan_at(self, pts, "f", 1.0, s, float(OPEN[k]), col)
	Stick.style = keep
