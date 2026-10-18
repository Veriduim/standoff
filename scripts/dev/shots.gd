extends Node
## Dev: screenshots of a match in progress (tools/shots.sh) - the start menu, a few turns in, your pick with a ghost,
## mid-playback, the result. Saved as PNGs to the folder given; then it quits.


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func run(game: Control, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(10)
	await _snap(out.path_join("1_start.png"))
	# a few turns played by a bot for you, to get everyone moving
	game.auto_me = true
	game.start_local("dancer", 5, "ffa")
	for _t in 14:
		if game.phase == "play":
			game.finish_playback()
	game.auto_me = false
	while game.phase == "play":
		game.finish_playback()
	if game.phase == "pick":
		game._select("divekick" if game.sim.legal_moves(game.me).has("divekick") else "dash")
		await _wait(40)
		await _snap(out.path_join("2_pick.png"))
		game._select("spin" if game.sim.legal_moves(game.me).has("spin") else "kick")
		await _wait(25)
		await _snap(out.path_join("3_pick_spin.png"))
		game._confirm()
		await _wait(16)
		await _snap(out.path_join("4_playing.png"))
	game.auto_me = true
	var guard := 0
	while game.phase != "over" and guard < 4000:
		if game.phase == "play":
			game.finish_playback()
		elif game.phase == "pick":
			game._commit({})
		guard += 1
	await _wait(20)
	await _snap(out.path_join("5_result.png"))
	get_tree().quit()
