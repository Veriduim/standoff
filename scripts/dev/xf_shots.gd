extends Node
## Dev: screenshots of the Dancer's x-factors on trial (all three on) - the home switches, the tabs with their moves, a
## Fan Throw going out and coming back, the Floor form and its Windmill, Tempo's ON BEAT!. The other fighter stands
## still. Off-screen.   godot --path . -- --xfshots=<dir>


## The other fighter: these picks in turn, then waits.
class Still extends Bot:
	var plan: Array = []

	func choose(_sim: Sim, _id: int) -> Dictionary:
		return plan.pop_front() if not plan.is_empty() else {"move": "wait"}


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


## Until it's your pick again (the playback done).
func _to_pick(game: Control) -> void:
	for _i in 900:
		if game.phase == "pick":
			return
		await get_tree().process_frame


## Play this pick, snapping the playback every `every` frames (n shots).
func _play(game: Control, pick: Dictionary, out: String, name: String, n: int, every: int, skip := 0) -> void:
	game._commit(pick)
	await _wait(skip)
	for i in n:
		await _wait(every)
		await _snap(out.path_join("%s_%d.png" % [name, i + 1]))
	await _to_pick(game)


func _place(game: Control, x0: float, x1: float) -> void:
	game.sim.fighters[0].pos = Vector2(x0, 0.0)
	game.sim.fighters[1].pos = Vector2(x1, 0.0)
	game.sim.fighters[0].facing = 1
	game.sim.fighters[1].facing = -1
	game.stage.show_tick(game.sim.record(), [], game.sim.record_shots())


func run(game: Control, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	game.home.xf = {"fans": true, "tempo": true, "forms": true}   # (not saved - just for these)
	for b in ["XFFans", "XFTempo", "XFForms"]:
		(game.home.find_child(b, true, false) as Button).set_pressed_no_signal(true)
	await _wait(120)
	await _snap(out.path_join("x0_home.png"))
	game.start_local(1, "ffa", 0)
	var still := Still.new()
	game.bots[1] = still
	game.sim.fighters[1].burst = 0
	_place(game, -260.0, 160.0)
	await _wait(10)
	var p: PickPanel = game.pick
	p.open(game.sim, game.me, game.stage)
	p._tab("special")
	await _wait(20)
	await _snap(out.path_join("x1_special.png"))
	p._tab("attack")
	await _wait(10)
	await _snap(out.path_join("x2_attack.png"))
	p._close_drawer()
	# Fans: out, hit, back to her hand
	await _play(game, {"move": "fan", "x": 1.0}, out, "x3_fan", 6, 9, 6)
	# Forms: into Floor, then a Windmill up close
	await _play(game, {"move": "floorform"}, out, "x4_floor", 1, 20)
	_place(game, -40.0, 40.0)
	p.open(game.sim, game.me, game.stage)
	p._tab("attack")
	await _wait(20)
	await _snap(out.path_join("x5_floor_attack.png"))
	p._close_drawer()
	await _play(game, {"move": "windmill", "x": 1.0}, out, "x6_windmill", 5, 6, 4)
	# Tempo: three beats, a hit - ON BEAT!
	await _play(game, {"move": "kipup", "x": 1.0}, out, "x7_kipup", 2, 8)
	for _i in 6:   # (until they're up and free)
		if game.sim.fighters[1].actionable():
			break
		await _play(game, {"move": "wait"}, out, "x7b", 0, 1)
	_place(game, -30.0, 30.0)
	game.sim.fighters[0].tempo = 3
	game.sim.fighters[1].burst = 0
	await _play(game, {"move": "jab", "x": 1.0}, out, "x8_beat", 4, 5, 2)
	get_tree().quit()
