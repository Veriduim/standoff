extends Node
## Dev: any moves as they play - one on one, the other standing still; for each move a strip of frames through it.
##   godot --path . -- --moveshots=<dir>:<move>,<move>@<gap>...   ->  <dir>/<move>.png (a strip of 5 frames; @gap: how
##   far apart they start, 90 if not given)


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
	for item in list:
		var mid := item.get_slice("@", 0)
		var gap := float(item.get_slice("@", 1)) if item.contains("@") else 90.0
		game.start_local(1, "ffa", 0)
		game.bots[1] = Still.new()
		game.sim.fighters[1].burst = 0
		game.sim.fighters[0].meter = Sim.METER_MAX   # (supers too)
		game.sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
		game.sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
		game.sim.fighters[0].facing = 1
		game.sim.fighters[1].facing = -1
		game.stage.show_tick(game.sim.record(), [], game.sim.record_shots())
		await _wait(20)
		var t0: int = game.sim.tick
		game._commit({"move": mid, "x": 1.0})
		var shots: Array[Image] = []
		for k in 5:   # (by the game's own ticks: 6, 12, 18, 24, 30 into the move - off-screen frames run faster)
			for _i in 600:
				var shown: int = game._first_tick + game._shown
				if shown >= t0 + 6 * (k + 1) or game.phase == "over":
					break
				if game.phase == "pick":   # (a stop for a pick: carry on as you are)
					game._commit({"move": "hold"})
				await get_tree().process_frame
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
