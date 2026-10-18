class_name PickPanel
extends Control
## Your turn, kept out of the stage's way (Timmy, 18 Oct 17:29: "for actions move them to the tabs that we pop up or
## from the side so we can test the frames. It also let us use the space more"; 17:37: "I dont like target ... one char
## that has as many moves as what a YOMIH char would have and see how we get that to fit with icons. Just have the
## direction functionality"):
##   - a slim tab column on the right (Attack / Air / Grab / Move / Defend / Super); a tab slides out a grid of move
##     icons (MoveIcon - the character's own stick figure in the move's key pose); picking one tucks it away
##   - a slim bar along the bottom: the move picked (its icon, name, frame data), the direction pad - the only thing you
##     pick with a move - a Distance slider for dashes and jumps, the Free (Cancel) switch for attacks, Boxes (hit / hurt
##     boxes) and Confirm. (19:12: "Remove the frame thing from the bottom" - the frame scrubber's gone; the ghost loops.)
##   - a line over the stage saying what the pick does (hits, blocks, clashes, getting hit)
##   - guessing (19:14: "How do I see how my and my opponents moves will interact?" - the wiki's predictions): tap an
##     opponent who's picking too and the tabs are theirs - pick what you think they'll do; their ghost plays against
##     yours. Tap yourself (or Back to you) to carry on with your own. Guesses only change the preview.

signal confirmed(choice: Dictionary)

const TAB_W := 96.0
const COLS := 4
const DRAWER_W := COLS * 92.0 + 34.0
const BAR_H := 118.0
const DIRS := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2.ZERO, Vector2(1, 0),
	Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]
const ARROWS := ["↖", "↑", "↗", "←", "", "→", "↙", "↓", "↘"]

var sim: Sim
var me := 0
var who := 0                 ## whose move the tabs / pad are setting now: you, or an opponent you're guessing
var stage: StageView
var choice := {}             ## your pick
var guesses := {}            ## opponent id -> the move you think they'll pick (the preview only)
var tab := ""                ## the drawer open ("" = closed)
var preview_events: Array = []

var tabs_box: VBoxContainer
var drawer: PanelContainer
var drawer_grid: GridContainer
var bar: PanelContainer
var picked_icon: MoveIcon
var picked_label: Label
var pad: GridContainer
var dist_row: HBoxContainer   ## a dash / jump's Distance, or a Block's parry frame
var dist_name: Label
var dist_slider: HSlider
var dist_label: Label
var free_btn: Button
var back_btn: Button
var boxes_btn: Button
var confirm_btn: Button
var info: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs_box = VBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 5)
	add_child(tabs_box)
	drawer = PanelContainer.new()
	drawer.add_theme_stylebox_override("panel", Ui.box(Color("#17181ff2"), 12))
	add_child(drawer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.add_child(scroll)
	drawer_grid = GridContainer.new()
	drawer_grid.columns = COLS
	drawer_grid.add_theme_constant_override("h_separation", 4)
	drawer_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(drawer_grid)
	drawer.visible = false
	bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Ui.box(Color("#16171ff0"), 0))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	picked_icon = MoveIcon.make("dancer", "", Color.WHITE, func() -> void: pass)
	picked_icon.custom_minimum_size = Vector2(84, 0)
	picked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picked_icon)
	picked_label = Ui.label("", 15, Color("#c9c9d6"))
	picked_label.custom_minimum_size = Vector2(170, 0)
	picked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(picked_label)
	pad = GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 2)
	pad.add_theme_constant_override("v_separation", 2)
	row.add_child(pad)
	for k in 9:
		var d: Vector2 = DIRS[k]
		if d == Vector2.ZERO:
			pad.add_child(Control.new())
			continue
		var aim_at := func() -> void: _pad_tap(d)
		var b := Ui.button(ARROWS[k], aim_at, 18)
		b.name = "d%d" % k
		b.custom_minimum_size = Vector2(44, 30)
		var on := Ui.box(Color("#3e8ed0"), 6)
		on.set_content_margin_all(2)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.toggle_mode = true
		pad.add_child(b)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	row.add_child(mid)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	mid.add_child(top)
	free_btn = Ui.button("Free", func() -> void: _toggle_free(), 16)
	free_btn.toggle_mode = true
	free_btn.custom_minimum_size = Vector2(150, 40)
	free_btn.add_theme_stylebox_override("pressed", Ui.box(Color("#2b6e4a"), 8))
	top.add_child(free_btn)
	back_btn = Ui.button("Back to you", func() -> void: guess(me), 16)
	back_btn.custom_minimum_size = Vector2(140, 40)
	top.add_child(back_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	boxes_btn = Ui.button("Boxes", func() -> void: _toggle_boxes(), 16)
	boxes_btn.toggle_mode = true
	boxes_btn.custom_minimum_size = Vector2(80, 40)
	top.add_child(boxes_btn)
	dist_row = HBoxContainer.new()
	dist_row.add_theme_constant_override("separation", 10)
	mid.add_child(dist_row)
	dist_name = Ui.label("Distance", 15, Color("#a7a7b8"))
	dist_row.add_child(dist_name)
	dist_slider = HSlider.new()
	dist_slider.min_value = 0.0
	dist_slider.max_value = 100.0
	dist_slider.step = 5.0
	dist_slider.value = 100.0
	dist_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_slider.custom_minimum_size = Vector2(0, 40)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#3a3d4d")
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	dist_slider.add_theme_stylebox_override("slider", track)
	dist_slider.value_changed.connect(_on_dist)
	dist_row.add_child(dist_slider)
	dist_label = Ui.label("100", 16, Color("#e2e2ea"))
	dist_label.custom_minimum_size = Vector2(36, 0)
	dist_row.add_child(dist_label)
	confirm_btn = Ui.button("Confirm", func() -> void: _confirm(), 26)
	confirm_btn.custom_minimum_size = Vector2(170, 0)
	for st in ["normal", "hover", "focus"]:
		confirm_btn.add_theme_stylebox_override(st, Ui.box(Color("#2f9e5b")))
	confirm_btn.add_theme_stylebox_override("pressed", Ui.box(Color("#24804a")))
	row.add_child(confirm_btn)
	info = Ui.label("", 17, Color("#e2e2ea"))
	info.add_theme_stylebox_override("normal", Ui.box(Color("#0e0f14bb"), 8))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _layout() -> void:
	var vp := get_viewport_rect().size
	var tab_h := 54.0 * Moves.TABS.size() + 5.0 * (Moves.TABS.size() - 1)
	tabs_box.position = Vector2(vp.x - TAB_W - 6.0, maxf(Ui.CARD_H + 8.0, (vp.y - BAR_H + Ui.CARD_H - tab_h) / 2.0))
	tabs_box.size = Vector2(TAB_W, 0)
	drawer.position = Vector2(vp.x - TAB_W - 14.0 - DRAWER_W, Ui.CARD_H + 8.0)
	drawer.size = Vector2(DRAWER_W, vp.y - BAR_H - Ui.CARD_H - 18.0)
	bar.position = Vector2(0, vp.y - BAR_H)
	bar.size = Vector2(vp.x, BAR_H)
	info.position = Vector2(10, Ui.CARD_H + 62.0)   # (top left, under the speed button - the fighters stand low)


## Your turn: the tabs for what you can do, a first pick made (an attack, aimed at the nearest enemy).
func open(the_sim: Sim, id: int, the_stage: StageView) -> void:
	sim = the_sim
	me = id
	who = id
	stage = the_stage
	if not stage.fighter_tapped.is_connected(_on_tap):
		stage.fighter_tapped.connect(_on_tap)
	visible = true
	guesses = {}
	_build_tabs()
	choice = {}
	var legal := sim.legal_moves(me)
	if sim.reeling(sim.fighters[me]):   # (reeling: Hold - leaning with the pad - picked; Burst out beside it if ready)
		select("hold")
		_close_drawer()
		if legal.has("burst"):
			_tab("defend")
		return
	if legal.has("hold"):   # (mid-move that gives way: carrying on is picked, anything else is a tap away)
		select("hold")
		_close_drawer()
		return
	var first := ""
	for mid in legal:
		if str(Moves.move(sim.fighters[me].character, mid)["kind"]) == "attack":
			first = mid
			break
	select(first if first != "" else legal[0])
	_close_drawer()


func close() -> void:
	visible = false
	_close_drawer()
	if stage != null:
		stage.ghost = []
		stage.ghost_shots = []
		stage.ghost_ids = []
		stage.show_boxes = false
		stage.guessing = -1
		boxes_btn.set_pressed_no_signal(false)


## Every move id you could pick now, as the tabs list them (the tests).
func menu_moves() -> Array:
	var out: Array = []
	for t: Array in Moves.TABS:
		out.append_array(_moves_in(str(t[0])))
	return out


func _moves_in(tab_id: String) -> Array:
	var f := sim.fighters[who]
	return sim.legal_moves(who).filter(func(mid: String) -> bool:
		return str(Moves.move(f.character, mid).get("tab", "")) == tab_id)


func _build_tabs() -> void:
	for c in tabs_box.get_children():
		tabs_box.remove_child(c)
		c.queue_free()
	for t: Array in Moves.TABS:
		var tid: String = t[0]
		var b := Ui.button(str(t[1]), func() -> void: _tab(tid), 17)
		b.name = tid
		b.custom_minimum_size = Vector2(TAB_W, 54)
		b.toggle_mode = true
		b.disabled = _moves_in(tid).is_empty()
		var tint: Color = MoveIcon.TAB_COLOURS.get(tid, Color.WHITE)
		var off := Ui.box(Color("#1e2029"), 10)
		off.border_color = tint
		off.border_width_left = 4
		for s in ["normal", "hover"]:
			b.add_theme_stylebox_override(s, off)
		var on := Ui.box(tint.darkened(0.45), 10)
		on.border_color = tint
		on.border_width_left = 4
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		tabs_box.add_child(b)


func _tab(tid: String) -> void:
	if tab == tid:
		_close_drawer()
		return
	tab = tid
	for c in tabs_box.get_children():
		(c as Button).set_pressed_no_signal(c.name == tab)
	for c in drawer_grid.get_children():
		drawer_grid.remove_child(c)
		c.queue_free()
	var f := sim.fighters[who]
	for mid: String in _moves_in(tab):
		var pick := func() -> void:
			select(mid)
			_close_drawer()
		var icon := MoveIcon.make(f.character, mid, MoveIcon.tab_colour(f.character, mid), pick)
		if mid == f.cancelled:   # (the move just landed: again = an Instant Cancel, a bar)
			icon.note = "IC"
		icon.selected = mid == str(_c().get("move", ""))
		drawer_grid.add_child(icon)
	drawer.visible = true


func _close_drawer() -> void:
	tab = ""
	drawer.visible = false
	for c in tabs_box.get_children():
		(c as Button).set_pressed_no_signal(false)


## A move's frame data in a line: when it hits, how hard, how long, armour, invulnerability, cost.
static func frame_data(m: Dictionary) -> String:
	var parts: Array[String] = []
	var hits: Array = m.get("hits", [])
	if not hits.is_empty():
		var dmg := 0
		for e: Dictionary in hits:
			dmg += int(e["dmg"])
		parts.append("hits f%d" % int(hits[0]["from"]))
		parts.append("%d dmg" % dmg)
	match str(m["kind"]):
		"guard":
			parts.append("both heights, no chip, shoves them off" if m.get("push", false)
					else "↑ high / ↓ low · parries on its frame")
		"grab":
			parts.append("beats blocks")
	if not hits.is_empty() and str(hits[0].get("height", "mid")) != "mid":
		parts.append("block it " + str(hits[0]["height"]))
	if not hits.is_empty() and hits[0].get("guardbreak", false):
		parts.append("guard break")
	parts.append("%d-%df by distance" % [int(m["dist"][0]), int(m["dist"][1])] if m.has("dist")
			and int(m["dist"][0]) != int(m["dist"][1]) else "%df" % int(m["frames"]))
	if m.has("armor"):
		parts.append("armour f%d-%d" % [int(m["armor"][0]), int(m["armor"][1])])
	if m.has("invuln"):
		parts.append("dodges f%d-%d" % [int(m["invuln"][0]), int(m["invuln"][1])])
	if int(m.get("cost", 0)) > 0:
		parts.append("%d meter" % int(m["cost"]))
	if int(m.get("meter_gain", 0)) > 0:
		parts.append("+%d meter" % int(m["meter_gain"]))
	return " · ".join(parts)


## The pick being set: yours, or your guess for the opponent you tapped.
func _c() -> Dictionary:
	if who == me:
		return choice
	if not guesses.has(who):
		guesses[who] = {}
	return guesses[who]


## Pick a move (yours, or the one you're guessing for them): it starts aimed at the nearest enemy, full distance, Free
## on for attacks when there's a charge or a bar to pay with (the wiki: on by default).
func select(mid: String) -> void:
	var c := _c()
	c["move"] = mid
	c["dist"] = 100.0
	var f := sim.fighters[who]
	var mk := str(Moves.move(f.character, mid).get("kind", ""))
	c["free"] = mk == "attack" and (f.fc > 0 or f.meter >= Sim.BAR)
	var m := Moves.move(f.character, mid)
	var near := sim.nearest_enemy(f)
	var toward := float(f.facing) if near == null or absf(near.pos.x - f.pos.x) < 1.0 \
			else signf(near.pos.x - f.pos.x)
	var d := Vector2(toward, 0.0)
	match str(m.get("aim", "none")):
		"up":
			d = Vector2(toward, -1.0)
		"down":
			d = Vector2(toward, 1.0)
		"none", "lean":
			d = Vector2.ZERO
		"height":
			d = Vector2(0.0, -1.0)
	picked_icon.character = f.character
	picked_icon.move_id = mid
	picked_icon.colour = MoveIcon.tab_colour(f.character, mid) if who == me else stage.colour_of(who)
	picked_icon.queue_redraw()
	picked_label.text = "%s\n%s" % [m["name"], frame_data(m)] if who == me \
			else "Your guess for %s:\n%s" % [f.name, m["name"]]
	set_dir(d)


## The direction (the only thing picked with a move); the pad shows the arrows this move takes.
func set_dir(d: Vector2) -> void:
	var f := sim.fighters[who]
	var c := _c()
	var kind := str(Moves.move(f.character, str(c["move"])).get("aim", "none"))
	var a := Sim.aim(kind, d, f.facing)
	c["x"] = a.x
	c["y"] = a.y
	for k in 9:
		var dk: Vector2 = DIRS[k]
		if dk == Vector2.ZERO:
			continue
		var b := pad.get_node("d%d" % k) as Button
		var usable := false
		match kind:
			"facing":
				usable = dk.y == 0.0
			"up":
				usable = dk.y < 0.0
			"down":
				usable = dk.y > 0.0
			"height":
				usable = dk.x == 0.0
			"dir8", "lean":
				usable = true
		b.disabled = not usable
		b.set_pressed_no_signal(usable and Sim.aim(kind, dk, f.facing).is_equal_approx(a))
	refresh()


## A pad arrow: aims the move that way. A lean is optional - tapping the lit arrow again takes it off.
func _pad_tap(d: Vector2) -> void:
	var f := sim.fighters[who]
	var c := _c()
	var kind := str(Moves.move(f.character, str(c["move"])).get("aim", "none"))
	var now := Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
	set_dir(Vector2.ZERO if kind == "lean" and now.is_equal_approx(d.normalized()) else d)


## The ghost and the line about it for the pick as it stands; the scrubber starts over, playing.
func refresh() -> void:
	var f := sim.fighters[me]
	var m := Moves.move(f.character, str(choice["move"]))
	var picks := guesses.duplicate()
	picks[me] = choice
	var pv := sim.preview(picks, 80)
	var pf := _parry_frame(pv["events"])
	if pf > 0 and pf != int(choice.get("pf", 0)):   # (a Block: parry on the frame the first hit would land)
		choice["pf"] = pf
		pv = sim.preview(picks, 80)
	preview_events = pv["events"]
	stage.ghost = pv["frames"]
	stage.ghost_shots = pv.get("shots", [])
	stage.ghost_only = me
	stage.ghost_ids = [me] + guesses.keys()   # (guessing: their ghosts play against yours)
	stage.ghost_play = true
	stage.guessing = who if who != me else -1
	var c := _c()
	var cm := Moves.move(sim.fighters[who].character, str(c.get("move", "")))
	var parrying := bool(cm.get("parry_frame", false))
	dist_row.visible = cm.has("dist") or parrying
	dist_name.text = "Parry on frame" if parrying else "Distance"
	dist_slider.set_block_signals(true)   # (a new range clamps the value - not a pick)
	dist_slider.max_value = 20.0 if parrying else 100.0
	dist_slider.step = 1.0 if parrying else 5.0
	dist_slider.value = float(c.get("pf", 0)) if parrying else float(c.get("dist", 100.0))
	dist_slider.set_block_signals(false)
	dist_label.text = ("off" if int(dist_slider.value) == 0 else str(int(dist_slider.value))) if parrying \
			else str(int(dist_slider.value))
	var fw := sim.fighters[who]
	free_btn.visible = str(cm.get("kind", "")) == "attack"
	free_btn.disabled = fw.fc == 0 and fw.meter < Sim.BAR
	free_btn.set_pressed_no_signal(bool(c.get("free", false)))
	free_btn.text = "Free · %d left" % fw.fc if fw.fc > 0 else ("Free · 1 bar" if fw.meter >= Sim.BAR else "Free · none")
	back_btn.visible = who != me
	var guessed := ""
	for id in guesses:
		var gm := Moves.move(sim.fighters[id].character, str(guesses[id].get("move", "")))
		if not gm.is_empty():
			guessed += "\nIf %s picks %s:" % [sim.fighters[id].name, gm["name"]]
	var hint := "" if not guesses.is_empty() or sim.deciders().size() < 2 else "\n(tap an opponent to guess their move)"
	info.text = "%s%s%s%s" % [m["name"], guessed, _outcome(), hint]
	info.reset_size()


## What the preview says happens, a line each (others standing still): your hits, blocks, parries, clashes, armour - and
## anything that lands on you.
func _outcome() -> String:
	var lines: Array[String] = []
	var dealt := {}
	for e: Dictionary in preview_events:
		var type := str(e["type"])
		var a := int(e["a"])
		var d := int(e["d"])
		var other := sim.fighters[d if a == me else a].name if (a == me or d == me) and d >= 0 else ""
		var line := ""
		if a == me and type in ["hit", "throw"]:
			dealt[d] = int(dealt.get(d, 0)) + int(e["dmg"])
		elif a == me and type == "block":
			var adv := -int(e.get("adv", 0))
			line = "%s blocks it%s (you're %s%d)" % [other, " (worse - wrong height)" if e.get("worse", false) else "",
					"+" if adv >= 0 else "", adv]
		elif a == me and type == "armor":
			line = "%s's armour soaks it (%d)" % [other, int(e["dmg"])]
		elif d == me and type == "parry":
			line = "⚠ %s parries you" % other
		elif a == me and type == "parry":
			line = "You parry %s - free at once" % other
		elif (a == me or d == me) and type == "clash":
			line = "Clashes with %s - both stopped" % other
		elif (a == me or d == me) and type == "tech":
			line = "Grabs meet with %s - pushed apart" % other
		elif d == me and type in ["hit", "throw"]:
			line = "⚠ You get hit by %s" % other
		elif d == me and type == "block":
			var adv2 := int(e.get("adv", 0))
			line = "You block %s%s (%s%d)" % [other, " - wrong height!" if e.get("worse", false) else "",
					"+" if adv2 >= 0 else "", adv2]
		if line != "" and not lines.has(line):
			lines.append(line)
	for id in dealt:
		lines.push_front("Hits %s for %d" % [sim.fighters[id].name, int(dealt[id])])
	return "" if lines.is_empty() else "\n" + "\n".join(lines)


## The Block frame the first hit coming at you lands on (0 = none, or you've set it by hand) - from the preview.
func _parry_frame(evs: Array) -> int:
	if str(choice.get("move", "")) != "block" or bool(choice.get("pf_set", false)):
		return 0
	for e: Dictionary in evs:
		if int(e["d"]) == me and str(e["type"]) in ["block", "hit", "parry", "throw"]:
			var k := int(e["t"]) - sim.tick - 1
			return k if k >= 1 and k <= 20 else 0
	return 0


func _on_dist(v: float) -> void:
	var c := _c()
	if bool(Moves.move(sim.fighters[who].character, str(c.get("move", ""))).get("parry_frame", false)):
		c["pf"] = int(v)
		c["pf_set"] = true   # (picked by hand - no more filling it in from the preview)
	else:
		c["dist"] = v
	refresh()


func _toggle_free() -> void:
	_c()["free"] = free_btn.button_pressed
	refresh()


func _toggle_boxes() -> void:
	stage.show_boxes = boxes_btn.button_pressed


## A fighter tapped on the stage: an opponent picking too -> guess their move; you -> back to your own pick.
func _on_tap(id: int) -> void:
	if not visible:
		return
	if id == me or (sim.enemies(sim.fighters[me], sim.fighters[id]) and sim.deciders().has(id)):
		guess(id)
	else:
		info.text = "%s is mid-move - it plays out as shown" % sim.fighters[id].name
		info.reset_size()


## Set the tabs and pad to `id`'s move (you, or an opponent whose move you're guessing - their first attack, aimed at
## you, to start).
func guess(id: int) -> void:
	who = id
	_close_drawer()
	_build_tabs()
	if id != me and not guesses.has(id):
		var first := ""
		for mid in sim.legal_moves(id):
			if str(Moves.move(sim.fighters[id].character, mid)["kind"]) == "attack":
				first = mid
				break
		select(first if first != "" else str(sim.legal_moves(id)[0]))
		return
	var c := _c()
	var mid := str(c.get("move", ""))
	var keep := c.duplicate()
	select(mid)
	for k in ["x", "y", "dist", "free"]:
		if keep.has(k):
			c[k] = keep[k]
	set_dir(Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0))))


func _confirm() -> void:
	if visible:
		who = me
		stage.guessing = -1
		confirmed.emit(choice.duplicate())
