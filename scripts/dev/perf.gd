extends Node
## Dev: how heavy a match is to run and draw - bots playing N against you, per frame: the script's time, draw calls,
## primitives, effect parts and afterimages.   godot --path . -- --perf=<seconds> [--opp=N] [--noafter]

func run(game: Control, seconds: float) -> void:
	var opp := 3
	var no_after := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opp="):
			opp = int(arg.trim_prefix("--opp="))
		elif arg == "--noafter":
			no_after = true
	game.auto_me = true
	game.start_local(opp, "ffa", 0)
	var n := 0
	var proc := 0.0
	var proc_max := 0.0
	var calls := 0.0
	var calls_max := 0.0
	var prims := 0.0
	var parts_max := 0
	var afters_max := 0
	var frame_ms := 0.0
	var frame_max := 0.0
	var last := Time.get_ticks_usec()
	for _i in int(seconds * 60.0):
		await get_tree().process_frame
		if no_after:
			game.stage.fx.afters.clear()
		var now := Time.get_ticks_usec()
		var ft := (now - last) / 1000.0
		last = now
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var c := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		n += 1
		proc += p
		proc_max = maxf(proc_max, p)
		calls += c
		calls_max = maxf(calls_max, c)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		parts_max = maxi(parts_max, game.stage.fx.parts.size())
		afters_max = maxi(afters_max, game.stage.fx.afters.size())
		frame_ms += ft
		frame_max = maxf(frame_max, ft)
	print("perf %d fighters%s: script %.2f ms (max %.2f), draw calls %.0f (max %.0f), primitives %.0f, frame %.1f ms (max %.1f), parts max %d, afterimages max %d"
			% [opp + 1, " no afterimages" if no_after else "", proc / n, proc_max, calls / n, calls_max, prims / n, frame_ms / n, frame_max, parts_max, afters_max])
	get_tree().quit()
