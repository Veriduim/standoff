class_name PickPanel
extends Control
## Your turn, kept out of the stage's way (Timmy, 18 Oct 17:29: "for actions move them to the tabs that we pop up or
## from the side so we can test the frames. It also let us use the space more"; 17:37: "I dont like target ... one char
## that has as many moves as what a YOMIH char would have and see how we get that to fit with icons. Just have the
## direction functionality"):
##   - your tabs down the left - YOMI's five: Movement / Attack / Special / Super / Defense (21:03); a tab slides out a
##     grid of move icons (MoveIcon - the character's own stick figure in the move's key pose); picking one tucks it
##     away. Hold is a button by Confirm, as by YOMI's Lock In. The nearest enemy who's picking too has theirs down the
##     right (21:37 "Have our options expand from the left and then the enemy closest to use expand from the right") -
##     their tabs set your guess of their move. Your last pick is picked first next turn (21:37 "remember the last
##     option we choice for our char").
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
const SETTINGS := "user://settings.cfg"

## Your last pick for each character (move, Free, Distance) - picked first on your next turn if you can; kept between
## plays. keep = false: not written to the settings (the tests).
static var last := {}
static var keep := true
static var _loaded := false


static func remembered(character: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			var saved: Variant = cfg.get_value("last", "moves", {})
			if saved is Dictionary:
				last = saved
	return last.get(character, {})


static func remember(character: String, c: Dictionary) -> void:
	if str(c.get("move", "")) in ["", "hold"]:
		return
	last[character] = {"move": str(c["move"]), "free": bool(c.get("free", false)), "dist": float(c.get("dist", 100.0))}
	if not keep:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("last", "moves", last)
	cfg.save(SETTINGS)


## Start over with nothing remembered (the tests: and nothing written).
static func forget(write := false) -> void:
	last = {}
	_loaded = true
	keep = write

var sim: Sim
var me := 0
var who := 0                 ## whose move the tabs / pad are setting now: you, or an opponent you're guessing
var stage: StageView
var choice := {}             ## your pick
var guesses := {}            ## opponent id -> the move you think they'll pick (the preview only)
var tab := ""                ## the drawer open ("" = closed)
var preview_events: Array = []

var tabs_box: VBoxContainer   ## your tabs (left)
var foe := -1                ## the enemy down the right (the nearest one picking too; tap another to swap)
var foe_box: VBoxContainer   ## ...their tabs
var foe_name: Label
var drawer: PanelContainer
var drawer_grid: GridContainer
var bar: PanelContainer
var picked_icon: MoveIcon
var picked_label: Label
var pad: GridContainer
var dist_row: Control         ## a dash / jump's Distance, or a Block's parry frame
var dist_name: Label
var dist_slider: HSlider
var dist_label: Label
var free_btn: Button
var boxes_btn: Button
var cards := {}              ## the two pick cards along the bottom: "me" (yours, left) and "foe" (the enemy's, right)
var confirm_btn: Button
var hold_btn: Button
var info: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs_box = VBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 5)
	add_child(tabs_box)
	foe_box = VBoxContainer.new()
	foe_box.add_theme_constant_override("separation", 5)
	add_child(foe_box)
	foe_name = Ui.label("", 15, Color.WHITE)
	foe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(foe_name)
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
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	cards["me"] = _build_card(row, "me")
	var centre := HBoxContainer.new()   # (in the middle, as YOMI's Lock In)
	centre.add_theme_constant_override("separation", 6)
	row.add_child(centre)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	centre.add_child(side)
	boxes_btn = Ui.button("Boxes", func() -> void: _toggle_boxes(), 15)
	boxes_btn.toggle_mode = true
	boxes_btn.custom_minimum_size = Vector2(92, 0)
	boxes_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(boxes_btn)
	hold_btn = Ui.button("Hold", func() -> void: select("hold"), 17)   # (carry on / ride it out - by Confirm, as in YOMI)
	hold_btn.name = "Hold"
	hold_btn.toggle_mode = true
	hold_btn.custom_minimum_size = Vector2(92, 0)
	hold_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hold_btn.add_theme_stylebox_override("pressed", Ui.box(Color("#2b4f8a")))
	side.add_child(hold_btn)
	confirm_btn = Ui.button("Confirm", func() -> void: _confirm(), 24)
	confirm_btn.custom_minimum_size = Vector2(150, 0)
	for st in ["normal", "hover", "focus"]:
		confirm_btn.add_theme_stylebox_override(st, Ui.box(Color("#2f9e5b")))
	confirm_btn.add_theme_stylebox_override("pressed", Ui.box(Color("#24804a")))
	centre.add_child(confirm_btn)
	cards["foe"] = _build_card(row, "foe")
	var mine: Dictionary = cards["me"]   # (yours, by their old names - the tests and the screenshots use them)
	picked_icon = mine["icon"]
	picked_label = mine["label"]
	pad = mine["pad"]
	dist_row = mine["dist_row"]
	dist_name = mine["dist_name"]
	dist_slider = mine["dist_slider"]
	dist_label = mine["dist_label"]
	free_btn = mine["free"]
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
	var tab_y := maxf(Ui.CARD_H + 60.0, (vp.y - BAR_H + Ui.CARD_H - tab_h) / 2.0)
	tabs_box.position = Vector2(6.0, tab_y)   # (yours down the left)
	tabs_box.size = Vector2(TAB_W, 0)
	foe_box.position = Vector2(vp.x - TAB_W - 6.0, tab_y)   # (the enemy's down the right)
	foe_box.size = Vector2(TAB_W, 0)
	foe_name.position = Vector2(vp.x - 6.0 - 220.0, tab_y - 26.0)
	foe_name.size = Vector2(220.0, 22.0)
	var right := who != me   # (the drawer opens from the side whose tabs it is)
	drawer.position = Vector2(vp.x - TAB_W - 14.0 - DRAWER_W if right else TAB_W + 14.0, Ui.CARD_H + 52.0)   # (under
	drawer.size = Vector2(DRAWER_W, vp.y - BAR_H - Ui.CARD_H - 62.0)                                          # the banner)
	bar.position = Vector2(0, vp.y - BAR_H)
	bar.size = Vector2(vp.x, BAR_H)
	info.position = Vector2(TAB_W + 20.0, Ui.CARD_H + 62.0)   # (top left, beside your tabs - the fighters stand low)


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
	foe = _nearest_foe()
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
	var f := sim.fighters[me]
	var again := remembered(f.character)   # (your last pick first, if you can do it now - aimed at the nearest enemy)
	if legal.has(str(again.get("move", ""))):
		select(str(again["move"]))
		choice["dist"] = float(again.get("dist", 100.0))
		choice["free"] = bool(again.get("free", false)) and str(Moves.move(f.character, str(choice["move"]))["kind"]) == "attack" \
				and (f.fc > 0 or f.meter >= Sim.BAR)
		refresh()
		_close_drawer()
		return
	var first := ""
	for mid in legal:
		if str(Moves.move(f.character, mid)["kind"]) == "attack":
			first = mid
			break
	select(first if first != "" else legal[0])
	_close_drawer()


## The enemy for the right-hand tabs: the nearest one picking too (-1 = nobody).
func _nearest_foe() -> int:
	var f := sim.fighters[me]
	var best := -1
	for id in sim.deciders():
		var g := sim.fighters[id]
		if id != me and sim.enemies(f, g) and (best < 0 or absf(g.pos.x - f.pos.x) < absf(sim.fighters[best].pos.x - f.pos.x)):
			best = id
	return best

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
	return _moves_of(who, tab_id)


func _moves_of(id: int, tab_id: String) -> Array:
	var f := sim.fighters[id]
	return sim.legal_moves(id).filter(func(mid: String) -> bool:
		return str(Moves.move(f.character, mid).get("tab", "")) == tab_id)


## Both sides' tabs: yours down the left, the enemy's down the right (their name over them, in their colour).
func _build_tabs() -> void:
	hold_btn.disabled = not sim.legal_moves(me).has("hold")
	hold_btn.set_pressed_no_signal(str(choice.get("move", "")) == "hold")
	_build_side(tabs_box, me, false)
	foe_box.visible = foe >= 0
	foe_name.visible = foe >= 0
	if foe >= 0:
		_build_side(foe_box, foe, true)
		foe_name.text = "Guess %s" % sim.fighters[foe].name
		foe_name.add_theme_color_override("font_color", stage.colour_of(foe).lightened(0.25))


func _build_side(box: VBoxContainer, id: int, right: bool) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for t: Array in Moves.TABS:
		var tid: String = t[0]
		var b := Ui.button(str(t[1]), func() -> void: _side_tab(id, tid), 17)
		b.name = tid
		b.custom_minimum_size = Vector2(TAB_W, 54)
		b.toggle_mode = true
		b.disabled = _moves_of(id, tid).is_empty()
		var tint: Color = MoveIcon.TAB_COLOURS.get(tid, Color.WHITE)
		var off := Ui.box(Color("#1e2029"), 10)
		off.border_color = tint
		var on := Ui.box(tint.darkened(0.45), 10)
		on.border_color = tint
		for st: StyleBoxFlat in [off, on]:   # (the colour strip on the outer edge)
			if right:
				st.border_width_right = 4
			else:
				st.border_width_left = 4
		for s in ["normal", "hover"]:
			b.add_theme_stylebox_override(s, off)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		box.add_child(b)


## A tab on one side: that side's pick (yours, or your guess for them) and its drawer.
func _side_tab(id: int, tid: String) -> void:
	if who != id:
		guess(id)
	_tab(tid)


func _tab(tid: String) -> void:
	if tab == tid:
		_close_drawer()
		return
	tab = tid
	var box := tabs_box if who == me else foe_box
	for c in tabs_box.get_children() + foe_box.get_children():
		(c as Button).set_pressed_no_signal(c.get_parent() == box and c.name == tab)
	_layout()
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
		icon.face = _face_for(who, {})
		drawer_grid.add_child(icon)
	drawer.visible = true
	info.visible = who != me   # (your drawer covers the line about your pick)


func _close_drawer() -> void:
	tab = ""
	drawer.visible = false
	info.visible = true
	for c in tabs_box.get_children() + foe_box.get_children():
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


## A pick card along the bottom - YOMI's two panels: yours bottom left, the enemy's bottom right (mirrored: their
## icon on the outer edge). Your colour / theirs down the outer edge; the move's icon in it, its name and frame data, the
## direction pad, and Distance (a dash or jump's) or the parry frame (a Block's); Free on yours.
func _build_card(parent: Control, side: String) -> Dictionary:
	var right := side == "foe"
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	var icon := MoveIcon.make("dancer", "", Color.WHITE, func() -> void: pass)
	icon.custom_minimum_size = Vector2(72, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Ui.label("", 14, Color("#c9c9d6"))
	label.custom_minimum_size = Vector2(132, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in 9:
		var d: Vector2 = DIRS[k]
		if d == Vector2.ZERO:
			grid.add_child(Control.new())
			continue
		var aim_at := func() -> void: _pad_tap(side, d)
		var b := Ui.button(ARROWS[k], aim_at, 17)
		b.name = "d%d" % k
		b.custom_minimum_size = Vector2(40, 30)
		var on := Ui.box(Color("#3e8ed0"), 6)
		on.set_content_margin_all(2)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.toggle_mode = true
		grid.add_child(b)
	var ctl := VBoxContainer.new()
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.alignment = BoxContainer.ALIGNMENT_CENTER
	ctl.add_theme_constant_override("separation", 2)
	var free: Button = null
	if not right:
		free = Ui.button("Free", func() -> void: _toggle_free(), 15)
		free.toggle_mode = true
		free.custom_minimum_size = Vector2(0, 36)
		free.add_theme_stylebox_override("pressed", Ui.box(Color("#2b6e4a"), 8))
		ctl.add_child(free)
	var drow := VBoxContainer.new()
	drow.add_theme_constant_override("separation", 0)
	ctl.add_child(drow)
	var top := HBoxContainer.new()
	drow.add_child(top)
	var dn := Ui.label("Distance", 14, Color("#a7a7b8"))
	dn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(dn)
	var dl := Ui.label("100", 15, Color("#e2e2ea"))
	top.add_child(dl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = 100.0
	slider.custom_minimum_size = Vector2(96, 30)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#3a3d4d")
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)
	slider.value_changed.connect(func(v: float) -> void: _on_dist(side, v))
	drow.add_child(slider)
	var order: Array = [ctl, grid, label, icon] if right else [icon, label, grid, ctl]
	for n: Control in order:
		h.add_child(n)
	return {"panel": panel, "icon": icon, "label": label, "pad": grid, "dist_row": drow, "dist_name": dn,
		"dist_label": dl, "dist_slider": slider, "free": free, "right": right}


## Which way a figure on a card / in a drawer faces (21:59: "the purple guy should face us ... if we are on different
## sides they should flip again"): the way the pick's aimed, else toward who they're up against - yours the enemy down
## the right, theirs you.
func _face_for(id: int, c: Dictionary) -> float:
	var x := float(c.get("x", 0.0))
	if absf(x) > 0.2:
		return signf(x)
	var f := sim.fighters[id]
	var other: Fighter = sim.fighters[me] if id != me else (sim.fighters[foe] if foe >= 0 else sim.nearest_enemy(f))
	if other == null or absf(other.pos.x - f.pos.x) < 1.0:
		return float(f.facing)
	return signf(other.pos.x - f.pos.x)


## Whose card it is: "me" -> you; "foe" -> the enemy down the right (-1 = none).
func _side_id(side: String) -> int:
	return me if side == "me" else foe


## A fighter's pick being set: yours, or your guess for them.
func _pick_of(id: int) -> Dictionary:
	if id == me:
		return choice
	if not guesses.has(id):
		guesses[id] = {}
	return guesses[id]


## The pick the tabs are setting now: yours, or your guess for the enemy whose tabs you opened.
func _c() -> Dictionary:
	return _pick_of(who)


## Pick a move (yours, or the one you're guessing for them): it starts aimed at the nearest enemy, full distance, Free
## on for attacks when there's a charge or a bar to pay with (the wiki: on by default).
func select(mid: String) -> void:
	_select_for(who, mid)


func _select_for(id: int, mid: String) -> void:
	var c := _pick_of(id)
	c["move"] = mid
	if id == me:
		hold_btn.set_pressed_no_signal(mid == "hold")
	c["dist"] = 100.0
	var f := sim.fighters[id]
	var m := Moves.move(f.character, mid)
	c["free"] = str(m.get("kind", "")) == "attack" and (f.fc > 0 or f.meter >= Sim.BAR)
	var near := sim.nearest_enemy(f) if id == me else sim.fighters[me]   # (a guess for them: at you)
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
	_set_dir_for(id, d)


## The direction (the only thing picked with a move) - for the pick the tabs are on.
func set_dir(d: Vector2) -> void:
	_set_dir_for(who, d)


func _set_dir_for(id: int, d: Vector2) -> void:
	var f := sim.fighters[id]
	var c := _pick_of(id)
	var a := Sim.aim(str(Moves.move(f.character, str(c["move"])).get("aim", "none")), d, f.facing)
	c["x"] = a.x
	c["y"] = a.y
	refresh()


## A pad arrow on a card: aims that pick that way. A lean is optional - tapping the lit arrow again takes it off.
func _pad_tap(side: String, d: Vector2) -> void:
	var id := _side_id(side)
	if id < 0 or (id != me and str(_pick_of(id).get("move", "")) == ""):
		return
	var f := sim.fighters[id]
	var c := _pick_of(id)
	var kind := str(Moves.move(f.character, str(c["move"])).get("aim", "none"))
	var now := Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
	_set_dir_for(id, Vector2.ZERO if kind == "lean" and now.is_equal_approx(d.normalized()) else d)


## The ghost and the line about it for the picks as they stand; then both cards.
func refresh() -> void:
	var f := sim.fighters[me]
	var m := Moves.move(f.character, str(choice["move"]))
	var picks := {}
	for id in guesses:
		if str(guesses[id].get("move", "")) != "":
			picks[id] = guesses[id]
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
	stage.ghost_ids = [me] + picks.keys().filter(func(id: int) -> bool: return id != me)   # (their ghosts vs yours)
	stage.ghost_play = true
	stage.guessing = who if who != me else -1
	_show_card("me")
	_show_card("foe")
	var guessed := ""
	for id in picks:
		if id == me:
			continue
		var gm := Moves.move(sim.fighters[id].character, str(picks[id].get("move", "")))
		if not gm.is_empty():
			guessed += "\nIf %s picks %s:" % [sim.fighters[id].name, gm["name"]]
	var hint := "" if not picks.size() > 1 or sim.deciders().size() < 2 else ""
	if picks.size() == 1 and foe >= 0:
		hint = "\n(guess %s's move with their tabs on the right)" % sim.fighters[foe].name
	info.text = "%s%s%s%s" % [m["name"], guessed, _outcome(), hint]
	info.reset_size()


## A card as its pick stands: the icon in the fighter's colour, the name and frame data, the pad lit the way it's aimed
## (only the arrows the move takes), Distance or the parry frame, Free (yours).
func _show_card(side: String) -> void:
	var k: Dictionary = cards[side]
	var id := _side_id(side)
	(k["panel"] as Control).visible = id >= 0
	if id < 0:
		return
	var fw := sim.fighters[id]
	var col := stage.colour_of(id)
	var st := Ui.box(Color("#1c1d26"), 10)
	st.set_content_margin_all(6)
	st.border_color = col
	if bool(k["right"]):
		st.border_width_right = 5
	else:
		st.border_width_left = 5
	(k["panel"] as PanelContainer).add_theme_stylebox_override("panel", st)
	var c: Dictionary = choice if id == me else guesses.get(id, {})
	var mid := str(c.get("move", ""))
	var icon: MoveIcon = k["icon"]
	var pad_grid: GridContainer = k["pad"]
	var free: Button = k["free"]
	if mid == "":   # (no guess for them yet)
		icon.move_id = ""
		icon.queue_redraw()
		(k["label"] as Label).text = "%s\nno guess yet - their tabs" % fw.name
		for b in pad_grid.get_children():
			if b is Button:
				(b as Button).disabled = true
				(b as Button).set_pressed_no_signal(false)
		(k["dist_row"] as Control).visible = false
		return
	var cm := Moves.move(fw.character, mid)
	icon.character = fw.character
	icon.move_id = mid
	icon.colour = col
	icon.face = _face_for(id, c)
	icon.queue_redraw()
	(k["label"] as Label).text = "%s\n%s" % [cm["name"], frame_data(cm)] if id == me \
			else "%s: %s\n%s" % [fw.name, cm["name"], frame_data(cm)]
	var kind := str(cm.get("aim", "none"))
	var a := Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
	for n in 9:
		var dk: Vector2 = DIRS[n]
		if dk == Vector2.ZERO:
			continue
		var b := pad_grid.get_node("d%d" % n) as Button
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
		b.set_pressed_no_signal(usable and Sim.aim(kind, dk, fw.facing).is_equal_approx(a))
	var parrying := bool(cm.get("parry_frame", false))
	var slider: HSlider = k["dist_slider"]
	(k["dist_row"] as Control).visible = cm.has("dist") or parrying
	(k["dist_name"] as Label).text = "Parry on frame" if parrying else "Distance"
	slider.set_block_signals(true)   # (a new range clamps the value - not a pick)
	slider.max_value = 20.0 if parrying else 100.0
	slider.step = 1.0 if parrying else 5.0
	slider.value = float(c.get("pf", 0)) if parrying else float(c.get("dist", 100.0))
	slider.set_block_signals(false)
	(k["dist_label"] as Label).text = ("off" if int(slider.value) == 0 else str(int(slider.value))) if parrying \
			else str(int(slider.value))
	if free != null:
		free.visible = str(cm.get("kind", "")) == "attack"
		free.disabled = fw.fc == 0 and fw.meter < Sim.BAR
		free.set_pressed_no_signal(bool(c.get("free", false)))
		free.text = "Free · %d left" % fw.fc if fw.fc > 0 else ("Free · 1 bar" if fw.meter >= Sim.BAR else "Free · none")


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


## A card's Distance / parry-frame slider: how far that dash or jump goes (yours, or how far you guess theirs will).
func _on_dist(side: String, v: float) -> void:
	var id := _side_id(side)
	if id < 0:
		return
	var c := _pick_of(id)
	if bool(Moves.move(sim.fighters[id].character, str(c.get("move", ""))).get("parry_frame", false)):
		c["pf"] = int(v)
		c["pf_set"] = true   # (picked by hand - no more filling it in from the preview)
	else:
		c["dist"] = v
	refresh()


func _toggle_free() -> void:
	choice["free"] = free_btn.button_pressed
	refresh()


func _toggle_boxes() -> void:
	stage.show_boxes = boxes_btn.button_pressed


## A fighter tapped on the stage: an opponent picking too -> guess their move; you -> back to your own pick.
func _on_tap(id: int) -> void:
	if not visible:
		return
	if id == me or (sim.enemies(sim.fighters[me], sim.fighters[id]) and sim.deciders().has(id)):
		if id != me and id != foe:   # (another enemy: the right-hand tabs are theirs now)
			foe = id
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
		remember(sim.fighters[me].character, choice)
		confirmed.emit(choice.duplicate())
