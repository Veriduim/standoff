extends Node
## Dev: any moves as they play - one on one, the other standing still; for each move a strip of frames through it.
##   godot --path . -- --moveshots=<dir>:<move>,<move>...   ->  <dir>/<move>.png (a strip of 5 frames)


class Still extends Bot:
	func choose(_sim: Sim, _id: int) -> Dictionary:
		return {"move": "wait"}


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func run(game: Control, arg: String) -> void:
	var out := arg.get_slice(":", 0) + ":" + arg.get_slice(":", 1) if arg.get_slice_count(":") > 2 else arg.get_slice(":", 0)
	var list := arg.get_slice(":", arg.get_slice_count(":") - 1).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	for mid in list:
		game.start_local(1, "ffa", 0)
		game.bots[1] = Still.new()
		game.sim.fighters[1].burst = 0
		game.sim.fighters[0].pos = Vector2(-45.0, 0.0)
		game.sim.fighters[1].pos = Vector2(45.0, 0.0)
		game.sim.fighters[0].facing = 1
		game.sim.fighters[1].facing = -1
		game.stage.show_tick(game.sim.record(), [], game.sim.record_shots())
		await _wait(20)
		game._commit({"move": mid, "x": 1.0})
		var shots: Array[Image] = []
		for k in 5:
			await _wait(5)
			await RenderingServer.frame_post_draw
			shots.append(get_viewport().get_texture().get_image())
		var w := shots[0].get_width() / 2
		var h := shots[0].get_height() / 2
		var strip := Image.create(w * 5, h, false, shots[0].get_format())
		for k in 5:
			var im := shots[k]
			im.resize(w, h)
			strip.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(w * k, 0))
		strip.save_png(out.path_join(mid + ".png"))
		print("shot ", mid)
		for _i in 600:
			if game.phase == "pick" or game.phase == "over":
				break
			await get_tree().process_frame
	get_tree().quit()
