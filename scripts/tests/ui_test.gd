extends TestSuite
## The game screen driven like a player would: the start menu, a pick through the side tabs and the move icons, the
## direction pad, the frame scrubber, playback, the result.

const SCREEN := preload("res://scripts/ui/game_screen.gd")


func _screen() -> Control:
	var g: Control = SCREEN.new()
	add_child(g)
	return g


func _test_your_pick() -> void:
	_section("Your turn: side tabs of move icons, the direction pad, the ghost, the frame scrubber, Confirm")
	var g := _screen()
	_check("it opens on the home screen with a bot match playing behind it", g.phase == "menu" and g.home.visible
			and g._demo != null and g._demo.fighters.size() == 4)
	g._process(1.0)
	_check("...and the match behind it moves", g._demo.tick > 0)
	var was_pixel: bool = g.home.pixel
	(g.home as HomeScreen).set_pixel(true)
	g._process(0.016)
	_check("the Pixel look switch puts the after-pass over the stage in blocks",
			g.post.visible and g.pixel_size > 1.0)
	(g.home as HomeScreen).set_pixel(was_pixel)
	(g.home as HomeScreen)._set_colour(2)
	(g.home as HomeScreen)._set_count(9)
	_check("the home screen keeps 1-5 opponents (9 -> %d)" % g.home.opponents, g.home.opponents == 5)
	(g.home as HomeScreen)._set_count(3)
	(g.home.find_child("Fight", true, false) as Button).pressed.emit()
	var p: PickPanel = g.pick
	_check("a match with you and 3 bots: your turn first, the pick panel up (drawer tucked away), the start menu gone",
			g.sim.fighters.size() == 4 and g.phase == "pick" and p.visible and not p.drawer.visible
			and not g.home.visible and g._demo == null)
	_check("you wear the colour you picked; everyone is the Dancer", g.stage.colour_of(0) == StageView.COLOURS[2]
			and g.sim.fighters.all(func(f: Fighter) -> bool: return f.character == "dancer"))
	var names := p.menu_moves()
	_check("on the ground the tabs hold %d moves - ground attacks, grabs, moves, defence; no air moves, no supers yet"
			% names.size(), names.size() >= 20 and names.has("sweep") and names.has("hiptoss") and names.has("roll")
			and names.has("parry_late") and not names.has("divekick") and not names.has("cyclone"))
	_check("...the Air and Super tabs are greyed out", (p.tabs_box.get_node("air") as Button).disabled
			and (p.tabs_box.get_node("super") as Button).disabled)
	p._tab("attack")
	var icons: Array = p.drawer_grid.get_children()
	_check("the Attack tab slides out a grid of move icons (%d)" % icons.size(), p.drawer.visible
			and icons.size() >= 9 and icons.all(func(c: Node) -> bool: return c is MoveIcon))
	var sweep := p.drawer_grid.get_node("sweep") as MoveIcon
	sweep.pressed.emit()
	_check("tapping an icon picks the move and tucks the drawer away", str(p.choice["move"]) == "sweep"
			and not p.drawer.visible and p.picked_label.text.begins_with("Sweep\nhits f9"))
	_check("a facing move aims at the nearest enemy (right) and only ← / → are usable on the pad",
			float(p.choice["x"]) == 1.0 and (p.pad.get_node("d5") as Button).button_pressed
			and not (p.pad.get_node("d3") as Button).disabled and (p.pad.get_node("d1") as Button).disabled
			and (p.pad.get_node("d7") as Button).disabled)
	p.select("jump")
	_check("a jump takes ↖ ↑ ↗ only", not (p.pad.get_node("d0") as Button).disabled
			and (p.pad.get_node("d7") as Button).disabled and float(p.choice["y"]) < 0.0)
	p.select("walk")
	var x_right: float = g.stage.ghost[-1][0][0]
	p.set_dir(Vector2(-1, 0))
	var x_left: float = g.stage.ghost[-1][0][0]
	_check("the direction steers the ghost: a walk right ends at %.0f, left at %.0f (you at %.0f)"
			% [x_right, x_left, g.sim.fighters[0].pos.x], x_right > g.sim.fighters[0].pos.x + 30.0
			and x_left < g.sim.fighters[0].pos.x - 30.0 and float(p.choice["x"]) == -1.0)
	p.set_dir(Vector2(1, 0))
	p.scrub.value = 7.0
	_check("dragging the scrubber holds the ghost on that frame (frame 8 shown)", not g.stage.ghost_play
			and g.stage.ghost_index() == 7 and p.scrub_label.text.begins_with("Frame 8"))
	p.boxes_btn.button_pressed = true
	p._toggle_boxes()
	_check("Boxes shows the hit / hurt boxes", g.stage.show_boxes)
	var x0: float = g.sim.fighters[0].pos.x
	p._confirm()
	_check("Confirm plays the turn and puts the panel away (boxes off)", g.phase == "play" and not p.visible
			and not g.stage.show_boxes)
	var guard := 0
	while g.phase == "play" and guard < 50:
		g.finish_playback()
		guard += 1
	_check("after it plays you've walked right and it's a pick again (x %.0f -> %.0f, %s)"
			% [x0, g.sim.fighters[0].pos.x, g.phase], g.sim.fighters[0].pos.x > x0 + 30.0 and g.phase == "pick")
	g.queue_free()


## Plays the turn out frame by frame like the screen does (the stage's effects ticking too); returns what was seen.
func _watch(g: Control, mine: Dictionary) -> Dictionary:
	var seen := {"froze": false, "held": true, "arc": false, "star": Vector2.INF, "lag": false}
	g._commit(mine)
	var steps := 0
	while g.phase == "play" and steps < 600:
		var shown: int = g._shown
		var was_frozen: bool = g.stage.fx.frozen()
		g._process(1.0 / 60.0)
		if was_frozen and g._shown != shown:
			seen["held"] = false
		g.stage._process(1.0 / 60.0)
		seen["froze"] = seen["froze"] or g.stage.fx.frozen()
		seen["arc"] = seen["arc"] or not g.stage.fx.trails.is_empty()
		for p: Dictionary in g.stage.fx.parts:
			if p["k"] == "star" and seen["star"] == Vector2.INF:
				seen["star"] = p["p"]
		var card: Node = g.cards.get_child(1)
		var lag := (card.find_child("Lag", true, false) as ProgressBar).value
		seen["lag"] = seen["lag"] or lag > (card.find_child("HP", true, false) as ProgressBar).value + 1.0
		steps += 1
	return seen


func _test_hit_effects() -> void:
	_section("The hit effects (first style pass): sparks where it lands, the freeze, the arc, combo counts, the HP chunk")
	var g := _screen()
	g.start_local(1, "ffa")
	g.bots.clear()   # (the other one just stands there)
	g.sim.fighters[0].pos.x = -35.0
	g.sim.fighters[1].pos.x = 35.0
	var seen := _watch(g, {"move": "jab", "x": 1.0})
	var star: Vector2 = seen["star"]
	_check("a jab that lands bursts where the fist meets the body (%.0f, %.0f)" % [star.x, star.y],
			star.x > -10.0 and star.x < 60.0 and star.y < -60.0 and star.y > -100.0)
	_check("the playback freezes on contact and holds that frame", seen["froze"] and seen["held"])
	_check("the striking hand leaves an arc", seen["arc"])
	_check("your next pick shows how far ahead you are over the one reeling (+%s), on a turn clock (%s)"
			% [g.stage.advantage.get(1, 0), g.banner.text], g.phase == "pick" and int(g.stage.advantage.get(1, 0)) > 0
			and g.banner.text.ends_with("30"))
	_check("the HP lost shows as a white chunk before it drains", seen["lag"])
	g.sim.fighters[0].pos.x = g.sim.fighters[1].pos.x - 70.0
	_watch(g, {"move": "sweep", "x": 1.0})   # (a sweep leaves them reeling long enough for a jab)
	g.sim.fighters[0].pos.x = g.sim.fighters[1].pos.x - 66.0
	_watch(g, {"move": "jab", "x": 1.0})
	var combo: Dictionary = g.stage.fx.combos.get(1, {})
	_check("a hit while they still reel counts on as a combo - sweep, jab (%s)" % [combo],
			not combo.is_empty() and int(combo["hits"]) == 2 and int(combo["dmg"]) > 30)
	for _i in 4:   # (they get their feet back - the combo's over)
		if g.sim.reeling(g.sim.fighters[1]):
			_watch(g, {"move": "wait"})
	for _i in 3:
		g._process(1.0)
		g.stage._process(1.0)
	var card: Node = g.cards.get_child(1)
	_check("...and later the white chunk has drained and the count is gone",
			is_equal_approx((card.find_child("Lag", true, false) as ProgressBar).value,
			(card.find_child("HP", true, false) as ProgressBar).value) and g.stage.fx.combos.is_empty())
	g.queue_free()


func _test_full_matches() -> void:
	_section("Whole matches through the screen (a bot playing you): free-for-all and teams")
	for setup: Array in [[1, "ffa"], [5, "ffa"], [5, "teams"], [3, "teams"]]:
		var g := _screen()
		g.auto_me = true
		g.start_local(setup[0], setup[1])
		var guard := 0
		while g.phase == "play" and guard < 5000:
			g.finish_playback()
			guard += 1
		var result := (g.over_panel.find_child("Result", true, false) as Label).text
		_check("%d bots (%s) ends with a result on screen (%s)" % [setup[0], setup[1], result],
				g.phase == "over" and g.over_panel.visible and not result.is_empty())
		g.queue_free()
