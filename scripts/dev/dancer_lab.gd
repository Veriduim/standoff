extends Node2D
## Dev: the Dancer's looks side by side (Timmy 22:12: "I want their model to be better as well as I dont like the
## headband") - the figure as it is, then each Outfit.LOOKS option, the same poses along a labelled row, her fans in
## hand.   godot --path . -- --dancerlab=<out.png>

const POSES := [["idle", 0.55], ["idle2", 0.55], ["walk1", 0.18], ["side_kick", 1.0], ["spin2", 1.0], ["fan_up", 1.0],
	["glide", 1.0], ["uppercut", 1.0], ["hurt", 0.1], ["jump", 0.18]]
const CELL := Vector2(124, 190)
const COL := Color("#e5484d")

var out := ""


func run(path: String) -> void:
	out = path
	get_window().size = Vector2i(int(CELL.x * POSES.size() + 40), int(CELL.y * (Outfit.LOOKS.size() + 1) + 20))
	queue_redraw()
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("dancerlab ", out)
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(4000, 4000)), Color("#0b0c10"))
	var font := ThemeDB.fallback_font
	var keep_style: Dictionary = Stick.style.duplicate()
	var rows: Array = [["0  Now (headband gone)", {}]]
	for k: String in Outfit.LOOKS:
		rows.append([str(Outfit.LOOKS[k]["name"]), Outfit.LOOKS[k]])
	for r in rows.size():
		var y := 20.0 + r * CELL.y
		draw_string(font, Vector2(14, y + 18), str(rows[r][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffd166"))
		Outfit.look = rows[r][1]
		Stick.style["waist"] = 1.0 if r > 0 else 0.0
		for c in POSES.size():
			var pose := Poses.get_pose(str(POSES[c][0]))
			var sc := 1.15
			var origin := Vector2(20.0 + c * CELL.x + CELL.x / 2.0, y + CELL.y - 16.0)
			var head_r := Stick.head(sc)
			var t := 0.4 + c * 0.7
			var pre := Stick._place(pose, origin, sc, 1.0)
			Outfit.back(self, pre, sc, 1.0, COL, head_r, t, 0.0)
			Stick.fan_at(self, pre, "b", 1.0, sc, float(POSES[c][1]), COL)
			var pts := Stick.draw(self, pose, origin, sc, 1.0, COL, Stick.limb(sc), head_r)
			Outfit.front(self, pts, sc, 1.0, COL, head_r, t, 0.0)
			Stick.fan_at(self, pts, "f", 1.0, sc, float(POSES[c][1]), COL)
			draw_line(Vector2(origin.x - 50, origin.y), Vector2(origin.x + 50, origin.y), Color(1, 1, 1, 0.15), 1.0)
	Outfit.look = {}
	Stick.style = keep_style
