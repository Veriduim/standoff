extends Node
## The boot node: `-- --test` runs the headless tests (tools/test.sh) and quits; otherwise the game.

const SUITES := [
	preload("res://scripts/tests/sim_test.gd"),
	preload("res://scripts/tests/ui_test.gd"),
]


func _ready() -> void:
	if "--test" in OS.get_cmdline_user_args():
		var code := await _run_tests()
		get_tree().quit(code)
		return
	var game: Control = load("res://scripts/ui/game_screen.gd").new()
	add_child(game)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):   # (dev: screenshots of a match - tools/shots.sh)
			var shots: Node = load("res://scripts/dev/shots.gd").new()
			add_child(shots)
			shots.call("run", game, arg.trim_prefix("--shots="))


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
	for script: GDScript in SUITES:
		var area: String = script.resource_path.get_file().get_basename().trim_suffix("_test")
		if not areas.is_empty() and not areas.has(area):
			continue
		var suite: TestSuite = script.new()
		add_child(suite)
		print("\n-- %s --" % area.capitalize())
		var started := Time.get_ticks_msec()
		await suite.run()
		print("   (%s: %.1f s)" % [area, (Time.get_ticks_msec() - started) / 1000.0])
		tests += suite.tests
		failed += suite.failed_tests
		checks += suite.checks
		failures += suite.failures
		suite.queue_free()
	print("\n=== Results: %d/%d tests passed (%d/%d checks) ===" % [tests - failed, tests, checks - failures, checks])
	return 1 if failures > 0 else 0
