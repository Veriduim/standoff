extends TestSuite
## The game screen driven like a player would: the start menu, a pick through the side tabs and the move icons, the
## direction pad, the frame scrubber, playback, the result.

const SCREEN := preload("res://scripts/ui/game_screen.gd")


func _screen() -> Control:
	PickPanel.forget()   # (no remembered pick from earlier play; nothing written)
	SCREEN.bots_as = "dancer"   # (the bots as one character - they're at random in play)
	HomeScreen.fighter = "dancer"
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
	g._process(0.016)
	_check("smooth only (02:19 - the pixel look's gone): no after-pass with nothing splitting", not g.post.visible
			and g.home.find_child("Look", true, false) == null)
	(g.home as HomeScreen)._set_colour(2)
	(g.home as HomeScreen)._set_count(9)
	_check("the home screen keeps 1-5 opponents (9 -> %d)" % g.home.opponents, g.home.opponents == 5)
	(g.home as HomeScreen)._set_count(3)
	(g.home.find_child("Fight", true, false) as Button).pressed.emit()
	var p: PickPanel = g.pick
	_check("a match with you and 3 bots: your turn first, the pick panel up (drawer tucked away), the start menu gone",
			g.sim.fighters.size() == 4 and g.phase == "pick" and p.visible and not p.drawer.visible
			and not g.home.visible and g._demo == null)
	_check("you wear the colour you picked and play the fighter you picked", g.stage.colour_of(0) == StageView.COLOURS[2]
			and g.sim.fighters[0].character == HomeScreen.fighter and g.sim.fighters.all(func(f: Fighter) -> bool:
				return Moves.ROSTER.has(f.character)))
	var names := p.menu_moves()
	_check("on the ground the tabs hold %d moves - ground attacks, grabs, moves, defence; no air moves, no supers yet"
			% names.size(), names.size() >= 20 and names.has("sweep") and names.has("fangust") and names.has("roll")
			and names.has("block") and names.has("pushblock") and not names.has("airkick") and not names.has("cyclone"))
	var tab_of := func(mid: String) -> String: return str(Moves.move("dancer", mid)["tab"])
	_check("YOMI's five tabs, Movement right above Defense; Wait is Movement, grabs and air attacks are Attack, Uppercut "
			+ "is Special, Dodge is Defense, Burst Cancel is Super; Hold (a button by Confirm) isn't offered standing free",
			Moves.TABS.map(func(t: Array) -> String: return str(t[1])) == ["Attack", "Special", "Super", "Movement",
				"Defense"] and tab_of.call("wait") == "move" and tab_of.call("grab") == "attack"
			and tab_of.call("airkick") == "attack" and tab_of.call("uppercut") == "special"
			and tab_of.call("roll") == "defend" and tab_of.call("burstcancel") == "super"
			and not names.has("hold") and p.hold_btn.disabled)
	_check("...the Super tab is greyed out (no meter yet)", (p.tabs_box.get_node("super") as Button).disabled)
	p._tab("attack")
	var icons: Array = p.drawer_grid.get_children()
	_check("the Attack tab slides out a grid of move icons (%d)" % icons.size(), p.drawer.visible
			and icons.size() >= 9 and icons.all(func(c: Node) -> bool: return c is MoveIcon))
	var sweep := p.drawer_grid.get_node("sweep") as MoveIcon
	sweep.pressed.emit()
	_check("tapping an icon picks the move and tucks the drawer away", str(p.choice["move"]) == "sweep"
			and not p.drawer.visible and p.picked_label.text.begins_with("%s\nhits f%d" % [Moves.move("dancer", "sweep")["name"], Moves.startup(Moves.move("dancer", "sweep"))]))
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
	p.select("dash")
	var long_x: float = g.stage.ghost[-1][0][0]
	p.dist_slider.value = 20.0
	var short_x: float = g.stage.ghost[-1][0][0]
	_check("a dash shows the Distance slider; a short one ends nearer (100: %.0f, 20: %.0f)" % [long_x, short_x],
			p.dist_row.visible and short_x < long_x - 40.0 and float(p.choice["dist"]) == 20.0)
	p.select("jab")
	_check("an attack has the Free switch, on while there's a charge (%s)" % p.free_btn.text, p.free_btn.visible
			and bool(p.choice["free"]) and not p.dist_row.visible)
	var foe := 1
	p._on_tap(foe)
	_check("tapping an opponent who's picking too: the tabs and pad are theirs (%s)" % p.picked_label.text.replace("\n", " "),
			p.who == foe and g.stage.guessing == foe and p.guesses.has(foe) and (p.cards["foe"]["panel"] as Control).visible)
	p.select("sidekick")
	_check("...guessing their side kick plays their ghost against yours", str(p.guesses[foe]["move"]) == "sidekick"
			and g.stage.ghost_ids.has(foe) and g.stage.ghost_ids.has(g.me) and str(p.choice["move"]) == "jab")
	p.guess(g.me)
	_check("...and back to you, your pick as it was", p.who == g.me
			and str(p.choice["move"]) == "jab")
	p.select("walk")
	p.set_dir(Vector2(1, 0))
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
			if p["k"] in ["star", "slash"] and seen["star"] == Vector2.INF:   # (a fan strike's is a slash - step 4)
				seen["star"] = p["p"]
				seen["look"] = str(p["k"])
		var card: Node = g.cards.get_child(1)
		var lag := (card.find_child("Lag", true, false) as ProgressBar).value
		seen["lag"] = seen["lag"] or lag > (card.find_child("HP", true, false) as ProgressBar).value + 1.0
		steps += 1
	return seen


func _test_hit_effects() -> void:
	_section("The hit effects (first style pass): sparks where it lands, the freeze, the arc, the HP chunk")
	var g := _screen()
	g.start_local(1, "ffa")
	g.bots.clear()   # (the other one just stands there)
	g.sim.fighters[0].burst = 0   # (no Whiff Cancel offers while the other stands about)
	g.sim.fighters[0].pos.x = -35.0
	g.sim.fighters[1].pos.x = 35.0
	var seen := _watch(g, {"move": "jab", "x": 1.0})
	var star: Vector2 = seen["star"]
	_check("a jab that lands - her fan - cuts where it meets the body (%s at %.0f, %.0f)" % [seen.get("look", ""),
			star.x, star.y], star.x > -10.0 and star.x < 60.0 and star.y < -60.0 and star.y > -100.0
			and seen.get("look", "") == "slash")
	_check("the playback freezes on contact and holds that frame", seen["froze"] and seen["held"])
	_check("the striking hand leaves an arc", seen["arc"])
	_check("your next pick shows how far ahead you are over the one reeling (+%s), on a turn clock (%s)"
			% [g.stage.advantage.get(1, 0), g.banner.text], g.phase == "pick" and int(g.stage.advantage.get(1, 0)) > 0
			and g.banner.text.ends_with("30"))
	_check("the HP lost shows as a white chunk before it drains", seen["lag"])
	for _i in 4:   # (the jab's combo over first)
		if g.sim.reeling(g.sim.fighters[1]):
			_watch(g, {"move": "wait"})
	g.sim.fighters[0].pos.x = g.sim.fighters[1].pos.x - 70.0
	_watch(g, {"move": "sweep", "x": 1.0})   # (a sweep leaves them reeling long enough for a jab)
	g.sim.fighters[0].pos.x = g.sim.fighters[1].pos.x - 46.0   # (close: since 0.37.0 the sweep sends her off twice as fast)
	_watch(g, {"move": "jab", "x": 1.0})
	_check("a hit while they still reel counts on as a combo - sweep, jab (%d), with no count or damage drawn over them "
			% g.sim.fighters[1].combo + "(20 Oct 14:22 \"Dont keep the words and damage numbers\")",
			g.sim.fighters[1].combo == 2 and g.stage.fx.get("combos") == null)
	for _i in 4:   # (they get their feet back - the combo's over)
		if g.sim.reeling(g.sim.fighters[1]):
			_watch(g, {"move": "wait"})
	for _i in 3:
		g._process(1.0)
		g.stage._process(1.0)
	var card: Node = g.cards.get_child(1)
	_check("...and later the white chunk has drained",
			is_equal_approx((card.find_child("Lag", true, false) as ProgressBar).value,
			(card.find_child("HP", true, false) as ProgressBar).value))
	g.queue_free()


func _test_block_reads_guess() -> void:
	_section("Block: guess their move and the parry frame fills itself in")
	var g := _screen()
	g.start_local(1, "ffa")
	g.bots.clear()
	g.sim.fighters[0].pos.x = -40.0
	g.sim.fighters[1].pos.x = 40.0
	g.sim.fighters[0].burst = 0
	g.pick.open(g.sim, g.me, g.stage)
	var p: PickPanel = g.pick
	p._on_tap(1)
	p.select("straight")
	p.guess(g.me)
	p.select("block")
	_check("guessing their straight sets your Block to parry on frame %d (%s)" % [Moves.startup(Moves.move("dancer", "straight")), p.choice.get("pf", 0)],
			int(p.choice.get("pf", 0)) == Moves.startup(Moves.move("dancer", "straight")) and p.dist_row.visible and p.dist_name.text.begins_with("Parry"))
	_check("...and the preview says you parry it (%s)" % p.info.text.replace("\n", " "), p.info.text.contains("You parry"))
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


func _test_xfactor_screen() -> void:
	_section("The Dancer's own styles through the screen (Fans + Tempo, 23:31): on the cards, Undo, a whole match")
	var g := _screen()
	g.start_local(1, "ffa")
	g._update_cards()
	var ex := (g.cards.get_child(0).find_child("Extras", true, false) as RichTextLabel).text
	_check("Fans + Tempo every match: the cards show her fans and beats (%s)" % [g.sim.xf.keys()],
			g.sim.xf.has("fans") and g.sim.xf.has("tempo") and not g.sim.xf.has("forms") and ex.contains("◆")
			and ex.contains("▮"))
	g.bots.clear()
	g.sim.fighters[0].pos.x = -60.0
	g.sim.fighters[1].pos.x = 60.0
	var t0: int = g.sim.tick
	var hp0: int = g.sim.fighters[1].hp
	g._commit({"move": "straight", "x": 1.0})
	var wait_n := 0
	while g.phase != "pick" and wait_n < 3000:
		g.finish_playback()
		wait_n += 1
	var moved: bool = g.sim.tick > t0
	var undo_shown: bool = g.pick.undo_btn.visible
	g.undo()
	_check("Undo (against bots): back to before your last pick (tick %d -> %d, their HP %d)" % [t0, g.sim.tick,
			g.sim.fighters[1].hp], moved and undo_shown and g.sim.tick == t0 and g.sim.fighters[1].hp == hp0
			and g.phase == "pick")
	g.auto_me = true
	g._next()
	var guard := 0
	while g.phase == "play" and guard < 5000:
		g.finish_playback()
		guard += 1
	_check("...and a whole match plays to the end", g.phase == "over")
	g.queue_free()


func _test_multiplayer_qol() -> void:
	_section("Multiplayer (Timmy 21:37): your tabs left, the nearest enemy's right; aimless moves face them; last pick kept")
	var g := _screen()
	g.start_local(3, "ffa")
	g.bots.clear()
	for i in 4:
		g.sim.fighters[i].pos = Vector2([-300.0, -120.0, 200.0, 420.0][i], 0.0)
	g.sim.fighters[0].facing = -1
	var p: PickPanel = g.pick
	p.open(g.sim, g.me, g.stage)
	var vp := p.get_viewport_rect().size
	_check("your tabs down the left, the nearest enemy picking too (Bot 1) down the right with their name (%s)"
			% p.foe_name.text, p.tabs_box.position.x < vp.x / 2.0 and p.foe_box.position.x > vp.x / 2.0 and p.foe == 1
			and p.foe_box.visible and p.foe_name.text.contains(g.sim.fighters[1].name))
	p._side_tab(p.foe, "attack")
	_check("...their Attack tab: your guess for them, the drawer opening from the right", p.who == 1
			and p.drawer.visible and absf(p.drawer.position.x + p.drawer.size.x - p.foe_box.position.x) < 20.0
			and p.guesses.has(1))
	p._side_tab(g.me, "attack")
	_check("...yours: back to your pick, the drawer from the left", p.who == g.me and p.drawer.visible
			and absf(p.drawer.position.x - (p.tabs_box.position.x + PickPanel.TAB_W)) < 20.0)
	p._close_drawer()
	var mine: Dictionary = p.cards["me"]
	var theirs: Dictionary = p.cards["foe"]
	_check("bottom left your card in your colour, bottom right theirs (%s)" % (theirs["label"] as Label).text.replace("
", " "),
			(mine["panel"] as Control).get_index() == 0
			and (theirs["panel"] as Control).get_index() == (theirs["panel"] as Control).get_parent().get_child_count() - 1
			and (theirs["panel"] as Control).visible
			and ((mine["panel"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color
				== g.stage.colour_of(g.me))
	p.guess(1)
	p.select("dash")   # (a guess of their dash)
	var far: float = g.stage.ghost[-1][1][0]
	(theirs["dist_slider"] as HSlider).value = 30.0
	var near: float = g.stage.ghost[-1][1][0]
	_check("...guess their dash and how far: their card's Distance (30) - their ghost stops short (%.0f -> %.0f)"
			% [far, near], str(p.guesses[1]["move"]) == "dash" and float(p.guesses[1]["dist"]) == 30.0
			and (theirs["dist_row"] as Control).visible and absf(near - g.sim.fighters[1].pos.x) < absf(far - g.sim.fighters[1].pos.x)
			and (theirs["label"] as Label).text.contains("Dash"))
	var their_icon: MoveIcon = theirs["icon"]
	var my_icon: MoveIcon = mine["icon"]
	var faced := their_icon.face == -1.0 and my_icon.face == 1.0
	g.sim.fighters[1].pos.x = -420.0   # (they get round to your left: the icons turn round)
	p.guess(1)
	p.select("jab")
	p.guess(g.me)
	p.select("jab")
	_check("the figures on the cards face each other (theirs toward you), and turn when you swap sides",
			faced and their_icon.face == 1.0 and my_icon.face == -1.0)
	g.sim.fighters[1].pos.x = -120.0
	p._on_tap(2)
	_check("tapping another enemy puts them down the right", p.foe == 2 and p.who == 2)
	p.guess(g.me)
	p.select("mirror")
	p._confirm()
	_check("a move with no direction turns you to the nearest enemy (Mirror, facing right now)", g.sim.fighters[0].facing == 1)
	g.start_local(1, "ffa")   # (a new match: your first pick is the last one you made)
	_check("your last pick (Mirror) is picked first on your next turn (%s), and kept (%s)" % [g.pick.choice.get("move", ""),
			PickPanel.last.get("dancer", {})], str(g.pick.choice.get("move", "")) == "mirror"
			and str(PickPanel.remembered("dancer").get("move", "")) == "mirror")
	g.queue_free()


func _test_hold_mid_move() -> void:
	_section("Mid-move you can always go back to waiting it out (Timmy 22:37): Hold in Movement and on its button")
	for cs: Array in [["walk", 600.0, "jab", "mid-walk"], ["axekick", 250.0, "wait", "stuck in an Axe Kick"]]:
		var g := _screen()
		g.start_local(1, "ffa")
		g.bots.clear()
		var s: Sim = g.sim
		s.fighters[0].pos.x = -float(cs[1]) / 2.0
		s.fighters[1].pos.x = float(cs[1]) / 2.0
		s.fighters[0].burst = Sim.BURST_FULL
		s.apply({0: {"move": cs[0], "x": 1.0}, 1: {"move": cs[2], "x": -1.0}})
		for _i in 400:
			s.step()
			if s.deciders().has(0) and not s.fighters[0].actionable():
				break
		var p: PickPanel = g.pick
		p.open(s, 0, g.stage)
		var first := str(p.choice.get("move", ""))
		var other: String = s.legal_moves(0).filter(func(m: String) -> bool: return m != "hold")[0]
		p.select(other)
		p._tab("move")
		var icon := p.drawer_grid.get_node_or_null("hold") as MoveIcon
		if icon != null:
			icon.pressed.emit()
		_check("%s: Hold picked first; picked something else, Movement still has Hold and it takes you back (%s -> %s -> %s)"
				% [cs[3], first, other, p.choice.get("move", "")], first == "hold" and icon != null
				and str(p.choice.get("move", "")) == "hold" and not p.hold_btn.disabled)
		g.queue_free()


func _test_enemy_always_shown() -> void:
	_section("The enemy's side is always there (Timmy 22:39): picking - guess them; mid-move - what they're doing")
	var g := _screen()
	g.start_local(1, "ffa")
	g.bots.clear()
	var s: Sim = g.sim
	s.fighters[0].pos.x = -150.0
	s.fighters[1].pos.x = 150.0
	s.apply({1: {"move": "straight", "x": -1.0}})   # (they're mid Fouetté; you're free)
	s.step()
	var p: PickPanel = g.pick
	p.open(s, 0, g.stage)
	var card: Dictionary = p.cards["foe"]
	var text := (card["label"] as Label).text
	_check("they're mid-move: their card shows it with the frames left, their tabs greyed (%s)" % text.replace("
", " "),
			p.foe == 1 and (card["panel"] as Control).visible and p.foe_box.visible and text.contains(Moves.move("dancer", "straight")["name"])
			and text.contains("left") and (p.foe_box.get_child(0) as Button).disabled and p.foe_name.text.contains("mid-move"))
	g.queue_free()


func _test_replay() -> void:
	_section("Replay (Timmy 23:59): the whole match again from the result, every turn as it played")
	var g := _screen()
	g.auto_me = true
	g.start_local(1, "ffa")
	var n := 0
	while g.phase != "over" and n < 5000:
		g.finish_playback()
		n += 1
	var turns: int = g._replay_log.size()
	g.watch_replay()
	var playing: bool = g._replaying and g.phase == "play" and not g.over_panel.visible
	var m := 0
	while g._replaying and m < 5000:
		g.finish_playback()
		m += 1
	_check("Replay plays every turn (%d) and comes back to the result" % turns, turns > 3 and playing
			and g.phase == "over" and g.over_panel.visible and m >= turns - 1)
	g.queue_free()


func _test_match_menu() -> void:
	_section("The match menu (Timmy 00:28 \"How do I quit a game with bots?\"): ☰ / Back - Resume, Restart, Quit")
	var g := _screen()
	g.start_local(2, "ffa")
	var shown: bool = g.menu_btn.visible
	g.toggle_menu()
	var t0: float = g._turn_left
	g._process(1.0)
	var waits: bool = g.menu_panel.visible and is_equal_approx(g._turn_left, t0)
	g._menu_pick("Resume")
	_check("☰ shows in a match; open, the turn clock waits; Resume closes it", shown and waits and not g.menu_panel.visible)
	g.toggle_menu()
	g._menu_pick("Quit")
	_check("Quit to menu: back to the home screen", g.phase == "menu" and g.home.visible and not g.menu_btn.visible)
	g.queue_free()


func _test_sound() -> void:
	_section("Sound (19 Oct list item 2): events play their sounds, quiet behind the home screen, on / off kept")
	var g := _screen()
	var was := Sfx.on
	Sfx.set_on(true)
	g.start_local(1, "ffa")
	g._process(0.0)
	g.sfx.event({"type": "hit", "dmg": 12})
	g.sfx.event({"type": "hit", "dmg": 45})
	g.sfx.event({"type": "hit", "dmg": 20}, "slash")
	var cut: bool = g.sfx.played.has("slash") and (g.sfx._streams.get("hit_light", []) as Array).size() == 3
	g.sfx.event({"type": "block", "push": true})
	g.sfx.event({"type": "shot", "kind": "fan"})
	var heard: Array[String] = g.sfx.played.duplicate()
	_check("a hit, a big hit, a fan's cut (the slash), a Push Block, a Fan Throw: %s; three variants of a hit" % [heard],
			heard.slice(-5) == ["hit_light", "hit_heavy", "slash", "push", "fan_throw"] and cut)
	Sfx.set_on(false)
	g.sfx.event({"type": "ko"})
	var muted: bool = not g.sfx.played.has("ko")
	Sfx.set_on(true)
	g._menu_pick("Quit")
	g._process(0.0)
	g.sfx.event({"type": "ko"})
	_check("off: silent; behind the home screen: silent", muted and not g.sfx.played.has("ko"))
	g._show_start()
	g.toggle_menu()
	Sfx.set_on(was)
	g.queue_free()


var _check_size := Vector2.ZERO


func _test_pad_neutral() -> void:
	_section("The pad (01:15): bigger arrows; the lit arrow tapped again = no direction, at the nearest enemy")
	var g := _screen()
	g.start_local(1, "ffa")
	var p: PickPanel = g.pick
	p.select("straight")
	var lit_first: bool = absf(float(p.choice["x"])) > 0.5
	var toward := signf(float(p.choice["x"]))
	p._pad_tap("me", Vector2(toward, 0.0))
	var neutral: bool = is_zero_approx(float(p.choice["x"])) and is_zero_approx(float(p.choice["y"]))
	var none_lit := true
	for k in 9:
		var b := (p.cards["me"]["pad"] as GridContainer).get_node_or_null("d%d" % k) as Button
		if b != null:
			none_lit = none_lit and not b.button_pressed
			_check_size = b.custom_minimum_size
	_check("a move starts aimed at the enemy; tapping that arrow again leaves it neutral, nothing lit", lit_first
			and neutral and none_lit)
	_check("the arrows are bigger (%s)" % _check_size, _check_size.x >= 56.0 and _check_size.y >= 38.0)
	g.queue_free()
	var s := Sim.create([{"character": "dancer"}, {"character": "dancer"}], "ffa")
	s.fighters[0].pos = Vector2(200, 0)
	s.fighters[1].pos = Vector2(-200, 0)
	s.fighters[0].facing = 1   # (facing away - neutral still goes at the enemy)
	s.apply({0: {"move": "straight", "x": 0.0, "y": 0.0}, 1: {"move": "wait"}})
	_check("neutral in the sim: she turns to the nearest enemy (facing %d)" % s.fighters[0].facing,
			s.fighters[0].facing == -1)


func _test_how_to_play() -> void:
	_section("How to play (01:32): cards from the home screen and the ☰ menu; the match waits while they're up")
	var g := _screen()
	var shut: bool = not g.how.visible   # (the tests: it doesn't pop up by itself)
	g.home.help.emit()
	var first: String = g.how._title.text
	for _i in HowToPlay.PAGES.size() - 1:
		g.how.next()
	var last: String = g.how._next.text
	g.how.next()
	_check("from home: %d cards (\"%s\" ... \"%s\"), then closed and remembered" % [HowToPlay.PAGES.size(), first,
			last], shut and first == "Everyone moves at once" and last == "Let's go" and not g.how.visible
			and HowToPlay.seen())
	g.start_local(1, "ffa")
	g.toggle_menu()
	g._menu_pick("Help")
	var t0: float = g._turn_left
	g._process(1.0)
	_check("from the ☰ menu: up over the match, and the turn clock waits", g.how.visible
			and is_equal_approx(g._turn_left, t0))
	g.how.close()
	g.queue_free()


func _test_clearer_bars() -> void:
	_section("Clearer bars, YOMI's way, on every card (02:01): HEALTH yellow + orange, BURST!!, LEVEL with its badge")
	var g := _screen()
	for n: int in [1, 5]:
		g.start_local(n, "ffa")
		g.sim.fighters[0].meter = Sim.BAR + Sim.BAR / 2
		g._update_cards()
		var card: Node = g.cards.get_child(0)
		var badge := (card.find_child("Level", true, false) as Label).text
		var part := (card.find_child("Meter", true, false) as ProgressBar).value
		_check("%d fighters: BURST!! and LEVEL named on every card; a level and a half = badge %s, the next half-full (%d)"
				% [n + 1, badge, part], g.cards.get_child_count() == n + 1 and badge == "1"
				and is_equal_approx(part, float(Sim.BAR / 2)) and card.find_child("BurstName", true, false) != null
				and card.find_child("MeterName", true, false) != null)
	g.start_local(1, "ffa")
	g.sim.fighters[0].pos.x = -30.0   # (close enough that a Straight lands)
	g.sim.fighters[1].pos.x = 30.0
	g.pick.select("straight")
	g._process(0.0)
	var pred: Dictionary = g._pred
	var bar := g.cards.get_child(1).find_child("Pred", true, false) as ColorRect
	var share := bar.anchor_right - bar.anchor_left
	_check("a pick that would hit: their health shows the damage in orange (%s, %.2f of the bar)" % [pred, share],
			int(pred.get(1, 0)) > 0 and bar.visible and is_equal_approx(share, float(pred[1]) / g.sim.fighters[1].max_hp))
	g.queue_free()


func _test_bot_levels() -> void:
	_section("Bot difficulty (02:10): Easy / Normal / Hard on the home screen, kept; the match's bots play it")
	var g := _screen()
	var was := Bot.chosen
	(g.home as HomeScreen).set_level(2)
	g.start_local(1, "ffa")
	var hard: int = (g.bots[1] as Bot).level
	(g.home as HomeScreen).set_level(0)
	g.start_local(1, "ffa")
	var easy: int = (g.bots[1] as Bot).level
	var cfg := ConfigFile.new()
	cfg.load(HomeScreen.SETTINGS)
	_check("Hard then Easy picked: the bots are %s then %s, and it's saved (%s)" % [Bot.LEVELS[hard], Bot.LEVELS[easy],
			cfg.get_value("home", "bots", -1)], hard == 2 and easy == 0 and int(cfg.get_value("home", "bots", -1)) == 0
			and g.home.find_child("BotsNormal", true, false) != null)
	(g.home as HomeScreen).set_level(was)
	g.queue_free()


func _test_saved_replays() -> void:
	_section("Saved replays (02:15): a finished match is kept; from the list it plays again exactly as it went")
	var g := _screen()
	var before: int = Replays.paths().size()
	g.auto_me = true
	g.start_local(1, "ffa")
	var guard := 0
	while g.phase != "over" and guard < 3000:
		g.finish_playback()
		guard += 1
	var kept: Array = Replays.paths()
	var rec := Replays.load_rec(str(kept[0])) if not kept.is_empty() else {}
	_check("the match is saved when it ends (%d turns, \"%s\")" % [(rec.get("turns", []) as Array).size(),
			rec.get("result", "")], g.phase == "over" and (kept.size() > before or kept.size() == Replays.KEEP)
			and not (rec.get("turns", []) as Array).is_empty())
	var built := Replays.rebuild(rec)
	var again: Sim = built[1]
	var same: bool = again.tick == g.sim.tick
	for i in g.sim.fighters.size():
		same = same and again.fighters[i].hp == g.sim.fighters[i].hp and again.fighters[i].pos == g.sim.fighters[i].pos
	_check("played again from its picks it ends exactly the same (tick %d / %d)" % [again.tick, g.sim.tick], same)
	g._show_start()
	g.home.replays.emit()
	var listed: int = g.replay_list._box.get_child_count()
	g.watch_saved(str(kept[0]))
	_check("the home screen's Replays lists it (%d) and watching plays it (%s)" % [listed, g.phase],
			g.replay_list != null and listed >= 1 and g._replaying and g.phase == "play")
	g._end_replay()
	_check("its end: the result, and Menu goes home", g.phase == "over" and g.over_panel.visible
			and not (g.over_panel.find_child("Rematch", true, false) as Button).visible)
	DirAccess.remove_absolute(str(kept[0]))   # (the test's own replay)
	g.queue_free()


func _test_replay_to_device() -> void:
	_section("Replays to the phone (02:19 \"save them to device\"): a copy in its Download/Standoff Replays")
	var tmp := OS.get_user_data_dir().path_join("_device_test")
	Replays.device_dir = tmp   # (not the PC's real Downloads)
	var rec := {"v": Version.TAG, "when": 1760000000, "names": ["You", "Bot 1"], "result": "You win!", "start": {},
		"turns": []}
	DirAccess.make_dir_recursive_absolute(Replays.DIR)
	var src := Replays.DIR.path_join("_device_test.json")
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string(JSON.stringify(rec))
	f.close()
	var out := Replays.export_to_device(src)
	_check("Save to phone writes a copy there (%s)" % out, out != "" and FileAccess.file_exists(out)
			and Replays.load_rec(out).get("result", "") == "You win!")
	DirAccess.remove_absolute(out)
	DirAccess.remove_absolute(tmp)
	DirAccess.remove_absolute(src)
	Replays.device_dir = ""


func _test_training() -> void:
	_section("Training (02:28): you and a Dummy - it does what it's set to, takes combos, and you're both topped up")
	var g := _screen()
	g.home.training.emit(0)
	var dummy: Bot = g.bots.get(1)
	_check("from the home screen: one on one against a Dummy, the bar up, the round endless",
			g.training and dummy is Dummy and g.sim.fighters[1].name == "Dummy" and g.train_bar.visible
			and g.sim.round_len > 100000)
	g.set_dummy("Block")
	_check("set to Block, it blocks", (dummy as Dummy).choose(g.sim, 1)["move"] == "block")
	g.sim.fighters[0].pos.x = -30.0
	g.sim.fighters[1].pos.x = 30.0
	g.set_dummy("Stand")
	g._commit({"move": "straight", "x": 1.0})
	var d: Fighter = g.sim.fighters[1]
	var hurt := false
	for _turn in 8:   # (the hit, then standing about until the combo's over)
		var guard := 0
		while g.phase == "play" and guard < 200:
			g.finish_playback()
			guard += 1
		hurt = hurt or d.hp < d.max_hp or d.stun > 0
		if d.stun == 0 and d.restand == 0 and d.hp == d.max_hp:
			break
		g._commit({"move": "wait"})
	_check("hit and the combo over: back to full health, your meter full (hp %d/%d, meter %d)" % [d.hp, d.max_hp,
			g.sim.fighters[0].meter], hurt and d.hp == d.max_hp and g.sim.fighters[0].meter == Sim.METER_MAX)
	g.reset_training()
	_check("Reset: back where you started, the setting kept", is_equal_approx(g.sim.fighters[1].pos.x,
			Sim.create([{"character": "dancer"}, {"character": "dancer"}]).fighters[1].pos.x)
			and (g.bots[1] as Dummy).mode == "Stand")
	g._menu_pick("Quit")
	_check("Quit: home, the bar gone", g.phase == "menu" and not g.train_bar.visible and not g.training)
	g.queue_free()


func _test_floor_on_screen() -> void:
	_section("The camera keeps the floor on screen (02:34 \"Cant see myself anymore\") - even with a ghost going high")
	var g := _screen()
	g.start_local(3, "ffa")
	var high: Array = []
	for i in 40:   # (a ghost that goes way up - a super jump's, an air throw's)
		var rows: Array = []
		for f in g.sim.fighters:
			var r: Array = f.record() if f.has_method("record") else g.sim.record()[f.id]
			r = r.duplicate()
			r[1] = -float(i) * 22.0
			rows.append(r)
		high.append(rows)
	g.stage.ghost = high
	for _i in 120:
		g.stage._follow(0.05)
	var floor_y: float = g.stage.w2s(Vector2(0, 0)).y
	_check("the floor stays above the bar (floor at %.0f, the stage's bottom %.0f)" % [floor_y, g.stage.view_bottom],
			floor_y <= g.stage.view_bottom - 20.0)
	g.stage.ghost = []
	g.queue_free()
	var one := _screen()   # (20 Oct 14:04 "C is the best" - YOMI's scale: the camera never comes in close)
	one.start_local(1, "ffa")
	one.sim.fighters[0].pos = Vector2(-50, 0)
	one.sim.fighters[1].pos = Vector2(50, 0)
	one.stage.show_tick(one.sim.record())
	one.stage.ghost = []
	for _i in 120:
		one.stage._follow(0.05)
	var w: float = one.stage.view_right - one.stage.view_left
	var across: float = w / one.stage.zoom
	_check("point blank in a 1v1, the camera still shows %.0f across - 20 fighter heights, YOMI's scale (or as far as it "
			% across + "pulls back, on a narrow screen)", across >= minf(StageView.VIEW_MIN, w / StageView.ZOOM_MIN) - 1.0)
	one.queue_free()


func _test_replay_codes() -> void:
	_section("Sharing replays by a code (02:36 \"I cant share those with my friends?\"): packed small, unpacked the same")
	var rec := {"v": Version.TAG, "when": 1760000000, "names": ["You", "Bot 1"], "result": "You win!",
		"start": Sim.create([{"character": "dancer"}, {"character": "dancer"}]).to_dict(), "turns": [{"t": 0,
		"p": {"0": {"move": "jab", "x": 1.0}, "1": {"move": "wait"}}}]}
	var packed := Replays.pack(rec)
	var back := Replays.unpack(packed)
	_check("packed (%d characters, from %d) and back, the same" % [packed.length(), JSON.stringify(rec).length()],
			back.get("result", "") == "You win!" and (back["turns"] as Array).size() == 1
			and packed.length() < JSON.stringify(rec).length())
	_check("the server address is the lobby server's (%s)" % Replays.share_url(),
			Replays.share_url().begins_with("https://") and Replays.share_url().ends_with("/replays"))


func _test_style() -> void:
	_section("Your look (02:28): an outline and a trail - picked, kept, worn in a match, the trail following you")
	var g := _screen()
	var was := [Style.outline, Style.trail]
	g.home.style.emit(0)
	g.style_panel.pick(2, 1)   # (Gold, Glints)
	g.style_panel.close()
	var cfg := ConfigFile.new()
	cfg.load(Style.SETTINGS)
	g.start_local(1, "ffa")
	var worn: bool = g.stage.outlines[0] == Style.outline_colour(2) and str(g.stage.trails[0]) == "Glints"
	g._commit({"move": "dash", "x": 1.0})
	var seen := false
	for _i in 120:
		g._process(1.0 / 60.0)
		g.stage._process(1.0 / 60.0)
		seen = seen or g.stage.fx.parts.any(func(p: Dictionary) -> bool: return str(p["k"]) == "tglint")
		if g.phase != "play":
			break
	_check("Gold + Glints: saved (%s / %s), worn, and glints trail off you as you dash" % [cfg.get_value("style",
			"outline", -1), cfg.get_value("style", "trail", -1)], worn and seen
			and int(cfg.get_value("style", "outline", -1)) == 2)
	Style.set_mine(int(was[0]), int(was[1]))
	g.queue_free()


func _test_drawer_order() -> void:
	_section("The move drawers (03:00): fastest first, badges for what's special, a drag on them scrolls")
	var g := _screen()
	g.start_local(1, "ffa")
	var p: PickPanel = g.pick
	p._tab("attack")
	var starts: Array = []
	for c in p.drawer_grid.get_children():
		starts.append(Moves.startup(Moves.move("dancer", str((c as MoveIcon).move_id))))
	var sorted := starts.duplicate()
	sorted.sort()
	_check("Attack's moves fastest first (%s)" % [starts], not starts.is_empty() and starts == sorted)
	_check("badges: a grab beats blocks, the Uppercut has initiative, Fan Throw's a projectile (%s / %s / %s)" % [
			Moves.badges(Moves.move("dancer", "grab")), Moves.badges(Moves.move("dancer", "uppercut")),
			Moves.badges(Moves.move("dancer", "fan"))], Moves.badges(Moves.move("dancer", "grab")).contains("✊")
			and Moves.badges(Moves.move("dancer", "uppercut")).contains("⚡")
			and Moves.badges(Moves.move("dancer", "fan")).contains("🎯"))
	var icon := p.drawer_grid.get_child(0) as MoveIcon
	var picked := [false]
	var b2 := MoveIcon.make("dancer", "jab", Color.WHITE, func() -> void: picked[0] = true)
	var down := InputEventMouseButton.new()
	down.pressed = true
	down.position = Vector2(10, 10)
	b2._gui_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(10, 60)
	b2._gui_input(drag)
	b2.pressed.emit()
	_check("a drag across an icon scrolls instead of picking it", icon.mouse_filter == Control.MOUSE_FILTER_PASS
			and not picked[0])
	b2.free()
	p._close_drawer()
	g.queue_free()



func _test_bar_fits() -> void:
	_section("The bottom bar stays on the screen (06:56 \"the bottom of the screen is cutting off now\")")
	var g := _screen()
	g.start_local(1, "ffa")
	var p: PickPanel = g.pick
	p.open(g.sim, 0, g.stage)
	var need := p.bar.get_combined_minimum_size().y
	var vp := g.get_viewport_rect().size
	_check("what's in it fits its height (%.0f of %.0f), the pad's arrows drawn - no glyph to grow them - and its foot is "
			% [need, PickPanel.BAR_H] + "the screen's (%.0f / %.0f)" % [p.bar.position.y + p.bar.size.y, vp.y],
			need <= PickPanel.BAR_H and (p.pad.get_node("d0") as Button).text == ""
			and is_equal_approx(p.bar.position.y + p.bar.size.y, vp.y))
	g.queue_free()


func _test_icon_fonts() -> void:
	_section("The game's own icons (made for the web version 19 Oct, kept for Android): the same on every phone")
	Ui.add_icon_fonts()
	var font := ThemeDB.fallback_font
	var missing := []
	for ch: String in _text_chars("res://scripts"):
		var have := font.has_char(ch.unicode_at(0))
		for f: Font in font.fallbacks:
			have = have or f.has_char(ch.unicode_at(0))
		if not have:
			missing.append("%s U+%X" % [ch, ch.unicode_at(0)])
	var tall := []   # (an icon font's line deeper than the game's own makes every button taller - 14:16, the home card)
	for f: Font in font.fallbacks:
		if f.get_ascent(22) > font.get_ascent(22) + 0.5 or f.get_descent(22) > font.get_descent(22) + 0.5:
			tall.append(f.resource_path.get_file())
	_check("every icon in the game's text is in the fonts it carries - none left to a phone's own (missing: %s), and "
			% [missing] + "none of them makes a line taller (%s)" % [tall], missing.is_empty()
			and tall.is_empty() and font.fallbacks.size() >= Ui.ICON_FONTS.size())


func _test_big_effects() -> void:
	_section("Effects that fill the screen (14:09 \"our attacks anf effects domt use the full width and height of the "
			+ "field\"; 14:35 \"Rest sounds good\")")
	var stars := []
	var none_small := true
	var wall_ok := true
	var rings_ok := true
	for z: float in [0.4, 1.6]:   # (pulled right back for six on a wide stage, and close in)
		var fx := Fx.new()
		fx.band = 420.0
		fx.view_zoom = z
		fx.span = 1000.0 / z
		fx.walls = 1400.0
		var kinds := func() -> Array: return fx.parts.map(func(p: Dictionary) -> String: return str(p["k"]))
		fx.on_event("hit", Vector2.ZERO, 1.0, 18, Color.RED, 1, Color.BLUE, false, 3)
		none_small = none_small and not kinds.call().has("bigstar")
		fx.on_event("hit", Vector2.ZERO, 1.0, 66, Color.RED, 1, Color.BLUE, false, 4)
		var star: Array = fx.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "bigstar")
		stars.append(float(star[0]["s"]) * fx.band if not star.is_empty() else 0.0)
		fx.parts.clear()   # (the quake's own parts and shake, apart from the hits before it)
		fx.shake = 0.0
		fx.on_event("quake", Vector2(200.0, -6.0), 1.0, 0, Color.RED, 0, Color.RED, false, 5)
		var wall: Array = fx.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "spikes")
		var xs: Array = (wall[0]["sp"] as Array).map(func(q: Array) -> float: return float(q[0])) if not wall.is_empty() else [0.0]
		var bits: Array = fx.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "chip")
		var spread := 0.0   # (how far from his foot any of it starts)
		for b: Dictionary in bits:
			spread = maxf(spread, absf((b["p"] as Vector2).x - 200.0))
		wall_ok = (wall_ok and not wall.is_empty() and not wall[0].has("scr") and float(xs.max()) - 200.0 <= Fx.QUAKE_REACH
				and 200.0 - float(xs.min()) <= Fx.QUAKE_REACH and float(xs.max()) - float(xs.min()) >= Fx.QUAKE_REACH
				and spread <= Fx.QUAKE_REACH and fx.shake < 5.0)
		fx.parts.clear()
		fx.on_event("throw", Vector2.ZERO, 1.0, 20, Color.RED, 1, Color.BLUE, false, 6)
		var ring: Array = fx.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "wring")
		rings_ok = rings_ok and not ring.is_empty() and float(ring[0]["s"]) * fx.band >= 2.0 * 60.0 * z * 1.4
	_check("a big hit's starburst is as big pulled back as close in (%.0f / %.0f px - over a third of the band), and an "
			% stars + "ordinary hit gets none", none_small and absf(float(stars[0]) - float(stars[1])) < 1.0
			and float(stars[0]) >= 0.35 * 420.0)
	_check("Quake Stomp's spikes and debris stay over the strip it hits (15:10 \"The animation should only be in the are "
			+ "it effects\"), the stage only shaken lightly; a grab's rings are wider than the two fighters at any zoom",
			wall_ok and rings_ok)
	var g := _screen()
	HomeScreen.fighter = "bruiser"
	g.start_local(1, "ffa")
	var st: StageView = g.stage
	var rec: Array = (st.frame as Array).duplicate(true)
	for k in 8:   # (the Bruiser dashing in)
		rec = rec.duplicate(true)
		rec[0][0] = float(rec[0][0]) + 15.0
		rec[0][3] = "dash"
		rec[0][4] = k + 1
		rec[0][5] = 0
		st.show_tick(rec)
	var solid := st.fx.afters.filter(func(a: Dictionary) -> bool: return int(a["id"]) == 0 and bool(a.get("solid", false)))
	_check("the Bruiser rushing in leaves solid grey copies of himself behind (%d)" % solid.size(), solid.size() >= 2)
	for k in 8:   # (20 Oct, YOMI's: both sent flying across the stage - the camera rushing after them)
		rec = rec.duplicate(true)
		for row: Array in rec:
			row[0] = float(row[0]) + 40.0
		rec[1][5] = 1
		st.show_tick(rec)
	var puffs := st.fx.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "puff").size()
	_check("the one knocked back fast leaves smoke behind (%d puffs) - and no speed lines (15:10 \"Remove the speed "
			% puffs + "lines\")", puffs >= 8 and not st.fx.has_method("draw_lines"))
	HomeScreen.fighter = "dancer"
	g.queue_free()
	var fx2 := Fx.new()
	fx2.band = 420.0
	fx2.view_zoom = 0.5
	for ev: String in ["splat", "parry", "grit", "onbeat", "sadness", "time", "countered", "restand", "sad", "ic",
			"guardbreak", "form_snap", "reflect", "whiff"]:
		fx2.on_event(ev, Vector2(1390.0, -60.0), 1.0, 0, Color.RED, 1, Color.BLUE, false, 7)
	fx2.on_event("hit", Vector2.ZERO, 1.0, 40, Color.RED, 1, Color.BLUE, true, 8, true)   # (a counter hit)
	fx2.on_event("block", Vector2.ZERO, 1.0, 0, Color.RED, 1, Color.BLUE, false, 9, false, true)   # (a Push Block)
	var words := fx2.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "text").size()
	var debris := fx2.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "chip" and p.has("scr")).size()
	_check("no words or numbers on the stage (%d) and no push-in on big hits; a wall splat throws %d big chunks off the "
			% [words, debris] + "wall (YOMI's wall slam)", words == 0 and debris >= 30 and fx2.get("punch") == null)
	fx2.parts.clear()
	fx2.on_event("fling", Vector2(0.0, -80.0), 1.0, 0, Color.RED, 1, Color.BLUE, false, 10)   # (his strike going right)
	var behind := fx2.parts.filter(func(p: Dictionary) -> bool: return str(p["k"]) == "mline")
	var trail_ok := not behind.is_empty() and behind.all(func(p: Dictionary) -> bool:
		return (p["p"] as Vector2).x < 0.0 and not p.has("scr") and (p["v"] as Vector2).x > 0.0)
	_check("a fling's streaks trail behind the impact, on his side, his strike's momentum (15:21) - fighter-sized, not "
			+ "across the screen (%d)" % behind.size(), trail_ok)


## Every character past plain ASCII inside the game's strings (as tools/icon_fonts.py scans: comments aren't shown).
func _text_chars(dir: String) -> Array:
	var out := {}
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		for line: String in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
			var q := ""   # (the quote we're inside, or "")
			var i := 0
			while i < line.length():
				var ch := line[i]
				if q == "":
					if ch == "#":
						break
					if ch == "\"" or ch == "'":
						q = ch
				elif ch == "\\":
					i += 1
				elif ch == q:
					q = ""
				elif ch.unicode_at(0) > 127:
					out[ch] = true
				i += 1
	for d: String in DirAccess.get_directories_at(dir):
		if d not in ["tests", "dev"]:
			for ch: String in _text_chars(dir.path_join(d)):
				out[ch] = true
	return out.keys()


func _test_squash_and_lag() -> void:
	_section("Squash and stretch, the head and fans lagging (06:38 \"Try the rest except 6\")")
	var g := _screen()
	g.start_local(1, "ffa")
	var st: StageView = g.stage
	var stand := Poses.get_pose("idle")
	var rec := [0.0, -80.0, 1, "jump", 3, 0, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0]
	st._vy[0] = -16.0
	var up := st._squash(0, rec, stand)
	var hit := [0.0, 0.0, 1, "", 0, 1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0]
	st._vy[0] = 0.0
	var blow := st._squash(0, hit, stand)
	var head_y := func(q: Dictionary) -> float: return (q["head"] as Vector2).y
	var hand_x := func(q: Dictionary) -> float: return absf((q["hand_f"] as Vector2).x)
	_check("going up they stretch tall (head %.0f vs %.0f); a blow squeezes them across (hand %.0f vs %.0f)"
			% [head_y.call(up), head_y.call(stand), hand_x.call(blow), hand_x.call(stand)],
			head_y.call(up) < head_y.call(stand) - 4.0 and hand_x.call(blow) < hand_x.call(stand) - 1.0)
	st._vx[0] = 18.0   # (dashing: the head trails behind)
	st._vy[0] = 0.0
	for k in 30:
		st._time += 0.016
		st._dt = 0.016
		st._spring_step(0, [0.0, 0.0, 1, "dash", 3, 0])
	var off: Vector2 = st._head[0][0]
	var pts := {"hand_f": Vector2(40, 0), "elbow_f": Vector2(0, 0)}
	st._fan_turn(0, "f", pts, true)
	for k in 6:   # (the arm whips round; the fan's left behind it)
		st._time += 0.016
		pts["hand_f"] = Vector2.from_angle(-0.4 * (k + 1)) * 40.0
		st._fan_turn(0, "f", pts, true)
	var lag := absf(st._fan_turn(0, "f", pts, true))
	_check("dashing, the head trails back (%.1f); a whipped arm leaves the fan lagging (%.2f rad)" % [off.x, lag],
			off.x < -3.0 and lag > 0.2)
	g.queue_free()


func _test_strike_timeline() -> void:
	_section("More to every move (06:22 \"Lets try 1 and 2\"): a wind-up pulled back, the strike overshooting, a follow-through")
	var a := Poses.get_pose("heavy_wind")
	var b := Poses.get_pose("heavy_hit")
	var p := Poses.push(a, b, 0.3)
	var kept := true
	for bone: Array in Poses.TREE:
		var lb := ((b[bone[1]] as Vector2) - (b[bone[0]] as Vector2)).length()
		var lp := ((p[bone[1]] as Vector2) - (p[bone[0]] as Vector2)).length()
		kept = kept and absf(lb - lp) < 0.01
	_check("a pose pushed on past another keeps every limb's length", kept)
	var m := Moves.move("bruiser", "haymaker")
	var keys: Array = m["pose"]
	var coil: Dictionary = Poses._strike(m, keys, 9)
	var land: Dictionary = Poses._strike(m, keys, 13)
	var held: Dictionary = Poses._strike(m, keys, 15)
	var fist := func(q: Dictionary) -> float: return (q["hand_f"] as Vector2).x
	var moved := 0.0   # (how far the landing frame is past the held strike, every joint)
	for j: String in Poses.JOINTS:
		moved += ((land[j] as Vector2) - (held[j] as Vector2)).length()
	_check("the Haymaker: its fist pulled back past the wind-up (%.0f vs %.0f), and landing it swings on past the strike "
			% [fist.call(coil), fist.call(a)] + "(%.0f px over all joints)" % moved, fist.call(coil) < fist.call(a) - 2.0
			and moved > 15.0)
	var same := func(p: Dictionary, q: Dictionary) -> bool:
		for j: String in Poses.JOINTS:
			if ((p[j] as Vector2) - (q[j] as Vector2)).length() > 0.01:
				return false
		return true
	var h19: Dictionary = Poses._strike(m, keys, 19)
	var r21: Dictionary = Poses._strike(m, keys, 21)
	_check("held like YOMI's drawings (20 Oct): the wind-up holds still (frames 3 and 9), the strike stays out (15 and 19), "
			+ "then a recovery pose holds (21 and 23) before the snap on", same.call(Poses._strike(m, keys, 3), coil)
			and same.call(held, h19) and same.call(r21, Poses._strike(m, keys, 23)) and not same.call(h19, r21))
	var look := Poses.for_record("dancer", [0.0, 0.0, 1, "", 0, 1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0,
		Sim.LOOKS.find("body"), 8])
	var head := Poses.for_record("dancer", [0.0, 0.0, 1, "", 0, 1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0,
		Sim.LOOKS.find("head"), 8])
	_check("hit reactions differ: doubled over at the body (head x %.0f), the head snapped back (%.0f)"
			% [(look["head"] as Vector2).x, (head["head"] as Vector2).x], (look["head"] as Vector2).x
			> (head["head"] as Vector2).x + 20.0)


func _test_pick_fighter() -> void:
	_section("Two fighters (05:03): pick the Bruiser on the home screen and you play him - his Grit on his card")
	var g := _screen()
	var home := g.home as HomeScreen
	var card := home.find_child("Pick_bruiser", true, false) as Button
	card.pressed.emit()
	_check("tapping the Bruiser's card picks him", card != null and HomeScreen.fighter == "bruiser")
	(home.find_child("Fight", true, false) as Button).pressed.emit()
	var me: Fighter = g.sim.fighters[0]
	g.sim.fighters[0].grit = 40
	g._update_cards()
	var shown := ""
	for c in g.cards.get_children():
		for l in c.find_children("*", "RichTextLabel", true, false):
			shown += (l as RichTextLabel).text
	_check("the stage is drawn as wide as the match's (06:14 \"they are off the map\"): %.0f / %.0f" % [g.stage.half,
			g.sim.half], is_equal_approx(g.stage.half, g.sim.half))
	_check("...the match has you as him, and his card shows his Grit (%s)" % ("grit pips" if shown.contains("#ff9a3c")
			else "no grit"), me.character == "bruiser" and shown.contains("#ff9a3c") and not g.pick.menu_moves().has("fan"))
	home.set_fighter("dancer")
	g.queue_free()
