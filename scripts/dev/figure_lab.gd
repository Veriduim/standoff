extends Node2D
## Dev: the same poses drawn in each candidate body style, one labelled row each, saved as one PNG (Timmy 19:32: "I
## think visually we can do better" - YOMI's fighters, study only, are compact: a big head, a solid torso wider than
## the limbs, short thick limbs, feet).   godot --path . -- --figlab=<out.png>

const POSES := ["idle", "walk1", "jab_hit", "straight", "side_kick", "spin2", "uppercut", "hurt", "jump", "crouch"]
const VARIANTS := [
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
	get_window().size = Vector2i(int(CELL.x * POSES.size() + 150), int(CELL.y * VARIANTS.size() + 20))
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
	for r in VARIANTS.size():
		var v: Array = VARIANTS[r]
		Stick.style = v[1]
		var y := 20.0 + CELL.y * (r + 1) - 22.0
		draw_line(Vector2(140, y), Vector2(140 + CELL.x * POSES.size(), y), Color("#ececf2"), 2.0)
		draw_string(font, Vector2(10, y - 70), str(v[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		for k in POSES.size():
			var s := 1.25
			var origin := Vector2(140 + CELL.x * (k + 0.5), y)
			Stick.draw(self, Poses.get_pose(POSES[k]), origin, s, 1.0, COLS[r % COLS.size()], Stick.limb(s),
					Stick.head(s))
	Stick.style = keep
