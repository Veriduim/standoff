extends TestSuite
## The game screen driven like a player would: the start menu, a pick through the move menu, playback, the result.

const SCREEN := preload("res://scripts/ui/game_screen.gd")


func _screen() -> Control:
	var g: Control = SCREEN.new()
	add_child(g)
	return g


func _test_your_pick() -> void:
	_section("Your turn: the menu, aiming, the target, the ghost, Confirm")
	var g := _screen()
	_check("it opens on the start menu", g.phase == "menu" and g.start_panel.visible)
	g.start_local("bruiser", 3, "ffa")
	_check("a match with you and 3 bots: your turn first, the move menu up, the start menu gone",
			g.sim.fighters.size() == 4 and g.phase == "pick" and g.menu_panel.visible and not g.start_panel.visible)
	var names: Array = g.moves_row.get_children().map(func(b: Node) -> String: return b.name)
	_check("the menu lists your legal moves (%s)" % [names], names.has("jab") and names.has("grab")
			and names.has("guard") and not names.has("slam"))
	g._select("step")
	_check("picking a move shows its ghost, for you only", not g.stage.ghost.is_empty() and g.stage.ghost_only == g.me)
	var gx0: float = g.stage.ghost[0][0][0]
	var gx1: float = g.stage.ghost[-1][0][0]
	_check("the step's ghost walks toward the target, on the right (you at %.0f, ghost %.0f -> %.0f)"
			% [g.sim.fighters[0].pos.x, gx0, gx1], gx1 > g.sim.fighters[0].pos.x + 30.0)
	g._select("jab")
	var jx: Array = g.stage.ghost.map(func(r: Array) -> float: return float(r[0][0]))
	_check("a jab's ghost stays where you stand (ghost x from %.0f to %.0f, you at %.0f)"
			% [jx.min(), jx.max(), g.sim.fighters[0].pos.x], absf(float(jx.min()) - g.sim.fighters[0].pos.x) < 4.0
			and absf(float(jx.max()) - g.sim.fighters[0].pos.x) < 4.0)
	g._select("step")
	var far: Fighter = g.sim.fighters[3]
	g._on_tap_fighter(far.id)
	_check("tapping an enemy makes them the target", int(g.choice["target"]) == far.id and g.stage.target == far.id)
	g._on_tap_fighter(g.me)
	_check("...tapping yourself doesn't", int(g.choice["target"]) == far.id)
	var x0: float = g.sim.fighters[0].pos.x
	g._confirm()
	_check("Confirm plays the turn", g.phase == "play" and not g.menu_panel.visible)
	var guard := 0
	while g.phase == "play" and guard < 50:
		g.finish_playback()
		guard += 1
	_check("after it plays you've stepped forward and it's a pick again (x %.0f -> %.0f, %s)"
			% [x0, g.sim.fighters[0].pos.x, g.phase], g.sim.fighters[0].pos.x > x0 + 30.0 and g.phase == "pick")
	g.queue_free()


func _test_full_matches() -> void:
	_section("Whole matches through the screen (a bot playing you): free-for-all and teams")
	var results: Array[String] = []
	for setup: Array in [["bruiser", 1, "ffa"], ["dancer", 5, "ffa"], ["bruiser", 5, "teams"], ["dancer", 3, "teams"]]:
		var g := _screen()
		g.auto_me = true
		g.start_local(setup[0], setup[1], setup[2])
		var guard := 0
		while g.phase == "play" and guard < 5000:
			g.finish_playback()
			guard += 1
		var result := (g.over_panel.find_child("Result", true, false) as Label).text
		results.append("%s %d %s: %s" % [setup[0], setup[1], setup[2], result])
		_check("%s with %d bots (%s) ends with a result on screen (%s)" % [setup[0], setup[1], setup[2], result],
				g.phase == "over" and g.over_panel.visible and not result.is_empty())
		g.queue_free()
