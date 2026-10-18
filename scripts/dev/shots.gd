extends Node
## Dev: screenshots of a match in progress (tools/shots.sh) - the start menu, a few turns in, a tab's drawer open, your
## pick with its ghost, the scrubber held with the boxes on, mid-playback, the result. Saved as PNGs to the folder
## given; then it quits.


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func run(game: Control, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(150)   # (the match behind the home screen gets going)
	await _snap(out.path_join("1_home.png"))
	# a few turns played by a bot for you, to get everyone moving
	game.auto_me = true
	game.start_local(5, "ffa", 0)
	for _t in 14:
		if game.phase == "play":
			game.finish_playback()
	game.auto_me = false
	while game.phase == "play":
		game.finish_playback()
	if game.phase == "pick":
		var p: PickPanel = game.pick
		p._tab("attack")
		await _wait(20)
		await _snap(out.path_join("2_drawer.png"))
		p._tab("move")
		await _wait(10)
		await _snap(out.path_join("2b_drawer_move.png"))
		p._tab("defend")
		await _wait(10)
		await _snap(out.path_join("2c_drawer_defend.png"))
		p.select("sidekick" if game.sim.legal_moves(game.me).has("sidekick") else "jab")
		p._close_drawer()
		await _wait(40)
		await _snap(out.path_join("3_pick.png"))
		p.scrub.value = 9.0
		p.boxes_btn.button_pressed = true
		p._toggle_boxes()
		await _wait(6)
		await _snap(out.path_join("4_scrub_boxes.png"))
		p._confirm()
		await _wait(16)
		await _snap(out.path_join("5_playing.png"))
	game.auto_me = true
	var guard := 0
	while game.phase != "over" and guard < 4000:
		if game.phase == "play":
			game.finish_playback()
		elif game.phase == "pick":
			game._commit({})
		guard += 1
	await _wait(20)
	await _snap(out.path_join("6_result.png"))
	await _effects(game, out)
	get_tree().quit()


## Bots (you too) play a match at normal speed for `seconds`, then it quits - recorded with --write-movie
## (tools/reel.sh) to show the effects moving.
func reel(game: Control, seconds: float) -> void:
	game.auto_me = true
	game.start_local(3, "ffa", 0)
	await _wait(int(seconds * 60.0))
	get_tree().quit()


func _until(ok: Callable, frames: int) -> void:
	for _i in frames:
		if ok.call():
			return
		await get_tree().process_frame


## The hit effects, staged one on one: a side kick landing (the freeze, its arc), the sparks flying on a moment later,
## then a sweep -> jab combo and its count.
func _effects(game: Control, out: String) -> void:
	game.auto_me = false
	game.start_local(1, "ffa", 0)
	game.bots.clear()   # (the other one just stands there)
	game.sim.fighters[0].pos.x = -60.0
	game.sim.fighters[1].pos.x = 30.0
	game.stage.show_tick(game.sim.record())
	await _wait(40)
	game._commit({"move": "sidekick", "x": 1.0})
	await _until(func() -> bool: return game.stage.fx.frozen(), 240)
	await _snap(out.path_join("7_hit.png"))
	await _wait(7)
	await _snap(out.path_join("8_sparks.png"))
	await _until(func() -> bool: return game.phase == "pick", 400)
	game.sim.fighters[0].pos.x = game.sim.fighters[1].pos.x - 70.0
	game._commit({"move": "sweep", "x": 1.0})
	await _until(func() -> bool: return game.phase == "pick", 400)
	game.sim.fighters[0].pos.x = game.sim.fighters[1].pos.x - 66.0
	game._commit({"move": "jab", "x": 1.0})
	await _until(func() -> bool: return int(game.stage.fx.combos.get(1, {}).get("hits", 0)) >= 2, 300)
	await _wait(8)
	await _snap(out.path_join("9_combo.png"))
	await _until(func() -> bool: return game.phase == "pick", 400)
	game.sim.fighters[0].pos.x = game.sim.fighters[1].pos.x - 150.0
	game._commit({"move": "spin", "x": 1.0})
	var swinging := func() -> bool: return game.stage.fx.trails.has(0) and game.stage.fx.trails[0]["pts"].size() >= 7
	await _until(swinging, 300)
	await _snap(out.path_join("10_arc.png"))
