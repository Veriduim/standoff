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
	_check("it opens on the start menu", g.phase == "menu" and g.start_panel.visible)
	g.start_local("dancer", 3, "ffa")
	var p: PickPanel = g.pick
	_check("a match with you and 3 bots: your turn first, the pick panel up (drawer tucked away), the start menu gone",
			g.sim.fighters.size() == 4 and g.phase == "pick" and p.visible and not p.drawer.visible
			and not g.start_panel.visible)
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


func _test_full_matches() -> void:
	_section("Whole matches through the screen (a bot playing you): free-for-all and teams")
	for setup: Array in [["bruiser", 1, "ffa"], ["dancer", 5, "ffa"], ["bruiser", 5, "teams"], ["dancer", 3, "teams"]]:
		var g := _screen()
		g.auto_me = true
		g.start_local(setup[0], setup[1], setup[2])
		var guard := 0
		while g.phase == "play" and guard < 5000:
			g.finish_playback()
			guard += 1
		var result := (g.over_panel.find_child("Result", true, false) as Label).text
		_check("%s with %d bots (%s) ends with a result on screen (%s)" % [setup[0], setup[1], setup[2], result],
				g.phase == "over" and g.over_panel.visible and not result.is_empty())
		g.queue_free()
