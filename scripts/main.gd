extends Node
## The boot node: `-- --test` runs the headless tests (tools/test.sh) and quits; otherwise the game.

## (loaded only when testing - the phone build leaves scripts/tests out)
const SUITES := ["res://scripts/tests/sim_test.gd", "res://scripts/tests/ui_test.gd", "res://scripts/tests/online_test.gd"]


func _ready() -> void:
	if "--test" in OS.get_cmdline_user_args():
		var code := await _run_tests()
		get_tree().quit(code)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--figlab="):   # (dev: body styles side by side - scripts/dev/figure_lab.gd)
			var lab: Node2D = load("res://scripts/dev/figure_lab.gd").new()
			add_child(lab)
			lab.call("run", arg.trim_prefix("--figlab="))
			return
	var game: Control = load("res://scripts/ui/game_screen.gd").new()
	add_child(game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):   # (dev: screenshots of a match - tools/shots.sh)
			var shots: Node = load("res://scripts/dev/shots.gd").new()
			add_child(shots)
			shots.call("run", game, arg.trim_prefix("--shots="))
		elif arg.begins_with("--lobbyshots="):   # (dev: the lobby screens - scripts/dev/lobby_shots.gd)
			var ls: Node = load("res://scripts/dev/lobby_shots.gd").new()
			add_child(ls)
			ls.call("run", game, arg.trim_prefix("--lobbyshots="))
		elif arg.begins_with("--reel="):   # (dev: bots play a match for a video - tools/reel.sh)
			var reel: Node = load("res://scripts/dev/shots.gd").new()
			add_child(reel)
			reel.call("reel", game, float(arg.trim_prefix("--reel=")))


func _areas() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-areas="):
			return arg.trim_prefix("--test-areas=").split(",", false)
	return PackedStringArray()


func _run_tests() -> int:
	var areas := _areas()
	print("=== Standoff - tests ===")
	var tests := 0
	var failed := 0
	var checks := 0
	var failures := 0
	for path: String in SUITES:
		var area: String = path.get_file().get_basename().trim_suffix("_test")
		if not areas.is_empty() and not areas.has(area):
			continue
		var suite: Node = (load(path) as GDScript).new()
		add_child(suite)
		print("\n-- %s --" % area.capitalize())
		var started := Time.get_ticks_msec()
		await suite.call("run")
		print("   (%s: %.1f s)" % [area, (Time.get_ticks_msec() - started) / 1000.0])
		tests += int(suite.get("tests"))
		failed += int(suite.get("failed_tests"))
		checks += int(suite.get("checks"))
		failures += int(suite.get("failures"))
		suite.queue_free()
	print("\n=== Results: %d/%d tests passed (%d/%d checks) ===" % [tests - failed, tests, checks - failures, checks])
	return 1 if failures > 0 else 0
