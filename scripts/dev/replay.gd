extends Node
## Dev (23 Oct, Timmy: "Show me their moves in a video replay"): moves played out one by one, one on one - each to the
## end, until both are back on their feet and free - for Godot's movie writer:
##   godot --path . --write-movie out.avi -- --as=bruiser --vs=dancer --replay=haymaker@120,jump+elbowdrop,catch<jab
##   (a+b: b at his next pick; <m: the other one does m at the start - for counters; @gap: how far apart, 90 if not
##   given). Prints "seg|<name>|<frame>" as each starts (labels for the video).


class Still extends Bot:
	var first := ""

	func choose(_sim: Sim, _id: int) -> Dictionary:
		var m := first
		first = ""
		return {"move": m if m != "" else "wait", "x": -1.0}


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func run(game: Control, arg: String) -> void:
	for item in arg.split(",", false):
		var gap := float(item.get_slice("@", 1)) if item.contains("@") else 90.0
		var body := item.get_slice("@", 0)
		var opp := body.get_slice("<", 1) if body.contains("<") else ""
		var seq := body.get_slice("<", 0).split("+")
		game.start_local(1, "ffa", 0)
		var still := Still.new()
		still.first = opp
		game.bots[1] = still
		var me: Fighter = game.sim.fighters[0]
		me.meter = Sim.METER_MAX   # (supers too)
		me.grit = Sim.GRIT_MAX     # (his K.O. Punch)
		game.sim.fighters[1].burst = 0
		me.pos = Vector2(-gap / 2.0, 0.0)
		game.sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
		me.facing = 1
		game.sim.fighters[1].facing = -1
		game.stage.view_min = 640.0   # (in close: the fighters big in the video)
		game.stage.show_tick(game.sim.record(), [], game.sim.record_shots())
		await _wait(24)
		print("seg|%s|%d" % [Moves.move(me.character, seq[seq.size() - 1])["name"], Engine.get_process_frames()])
		var t0: int = game.sim.tick
		game._commit({"move": seq[0], "x": 1.0})
		seq.remove_at(0)
		for _i in 1500:   # (on until the next pick that finds both free and standing)
			if game.phase == "over":
				break
			if game.phase == "pick":
				var them: Fighter = game.sim.fighters[1]
				if not seq.is_empty() and game.sim.legal_moves(0).has(seq[0]):
					game._commit({"move": seq[0], "x": 1.0})
					seq.remove_at(0)
				elif seq.is_empty() and game.sim.tick > t0 + 2 and them.actionable() and them.pos.y >= -0.5 						and me.actionable() and me.pos.y >= -0.5:
					break
				else:
					game._commit({"move": "hold", "x": 1.0})
			await get_tree().process_frame
		await _wait(30)
	get_tree().quit()
