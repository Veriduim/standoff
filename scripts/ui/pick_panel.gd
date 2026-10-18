class_name PickPanel
extends Control
## Your turn, kept out of the stage's way (Timmy, 18 Oct 17:29: "for actions move them to the tabs that we pop up or
## from the side so we can test the frames. It also let us use the space more"; 17:37: "I dont like target ... one char
## that has as many moves as what a YOMIH char would have and see how we get that to fit with icons. Just have the
## direction functionality"):
##   - a slim tab column on the right (Attack / Air / Grab / Move / Defend / Super); a tab slides out a grid of move
##     icons (MoveIcon - the character's own stick figure in the move's key pose); picking one tucks it away
##   - a slim bar along the bottom: the move picked (its icon, name, frame data), the direction pad - the only thing you
##     pick with a move - the frame scrubber over the ghost (frame by frame, everyone's predicted spot, marks where hits
##     land, Boxes for hit / hurt boxes) and Confirm
##   - a line over the stage saying what the pick does (hits, blocks, clashes, getting hit)

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
var stage: StageView
var choice := {}
var tab := ""                ## the drawer open ("" = closed)
var preview_events: Array = []

var tabs_box: VBoxContainer
var drawer: PanelContainer
var drawer_grid: GridContainer
var bar: PanelContainer
var picked_icon: MoveIcon
var picked_label: Label
var pad: GridContainer
var timeline: Control
var scrub: HSlider
var scrub_label: Label
var play_btn: Button
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
		var aim_at := func() -> void: set_dir(d)
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
	play_btn = Ui.button("⏸", func() -> void: _toggle_play(), 20)
	play_btn.custom_minimum_size = Vector2(52, 38)
	top.add_child(play_btn)
	scrub_label = Ui.label("Frame 1", 16, Color("#c9c9d6"))
	scrub_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(scrub_label)
	boxes_btn = Ui.button("Boxes", func() -> void: _toggle_boxes(), 16)
	boxes_btn.toggle_mode = true
	boxes_btn.custom_minimum_size = Vector2(80, 38)
	top.add_child(boxes_btn)
	timeline = Timeline.new()
	timeline.custom_minimum_size = Vector2(0, 12)
	mid.add_child(timeline)
	scrub = HSlider.new()
	scrub.custom_minimum_size = Vector2(0, 34)
	scrub.step = 1.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#3a3d4d")
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	scrub.add_theme_stylebox_override("slider", track)
	scrub.value_changed.connect(_on_scrub)
	mid.add_child(scrub)
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
	stage = the_stage
	visible = true
	_build_tabs()
	choice = {}
	var legal := sim.legal_moves(me)
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
		stage.show_boxes = false
		boxes_btn.set_pressed_no_signal(false)


## Every move id you could pick now, as the tabs list them (the tests).
func menu_moves() -> Array:
	var out: Array = []
	for t: Array in Moves.TABS:
		out.append_array(_moves_in(str(t[0])))
	return out


func _moves_in(tab_id: String) -> Array:
	var f := sim.fighters[me]
	return sim.legal_moves(me).filter(func(mid: String) -> bool:
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
		var on := Ui.box(StageView.COLOURS[me % 6].darkened(0.2), 10)
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
	var f := sim.fighters[me]
	for mid: String in _moves_in(tab):
		var pick := func() -> void:
			select(mid)
			_close_drawer()
		var icon := MoveIcon.make(f.character, mid, StageView.COLOURS[me % 6], pick)
		icon.selected = mid == str(choice.get("move", ""))
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
			parts.append("blocks strikes, loses to grabs")
		"parry":
			parts.append("stops a strike on f%d-%d" % [int(m["window"][0]), int(m["window"][1])])
		"grab":
			parts.append("beats guard")
	parts.append("%df" % int(m["frames"]))
	if m.has("armor"):
		parts.append("armour f%d-%d" % [int(m["armor"][0]), int(m["armor"][1])])
	if m.has("invuln"):
		parts.append("dodges f%d-%d" % [int(m["invuln"][0]), int(m["invuln"][1])])
	if int(m.get("cost", 0)) > 0:
		parts.append("%d meter" % int(m["cost"]))
	if int(m.get("meter_gain", 0)) > 0:
		parts.append("+%d meter" % int(m["meter_gain"]))
	return " · ".join(parts)


## Pick a move: it starts aimed at the nearest enemy (the way it can be aimed).
func select(mid: String) -> void:
	choice["move"] = mid
	var f := sim.fighters[me]
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
		"none":
			d = Vector2.ZERO
	picked_icon.character = f.character
	picked_icon.move_id = mid
	picked_icon.colour = StageView.COLOURS[me % 6]
	picked_icon.queue_redraw()
	picked_label.text = "%s\n%s" % [m["name"], frame_data(m)]
	set_dir(d)


## The direction (the only thing picked with a move); the pad shows the arrows this move takes.
func set_dir(d: Vector2) -> void:
	var f := sim.fighters[me]
	var kind := str(Moves.move(f.character, str(choice["move"])).get("aim", "none"))
	var a := Sim.aim(kind, d, f.facing)
	choice["x"] = a.x
	choice["y"] = a.y
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
			"dir8":
				usable = true
		b.disabled = not usable
		b.set_pressed_no_signal(usable and Sim.aim(kind, dk, f.facing).is_equal_approx(a))
	refresh()


## The ghost and the line about it for the pick as it stands; the scrubber starts over, playing.
func refresh() -> void:
	var f := sim.fighters[me]
	var m := Moves.move(f.character, str(choice["move"]))
	var pv := sim.preview({me: choice}, 80)
	preview_events = pv["events"]
	stage.ghost = pv["frames"]
	stage.ghost_only = me
	stage.ghost_play = true
	play_btn.text = "⏸"
	scrub.max_value = maxf(0.0, stage.ghost.size() - 1.0)
	scrub.set_value_no_signal(0.0)
	(timeline as Timeline).marks = _marks()
	timeline.queue_redraw()
	info.text = "%s%s" % [m["name"], _outcome()]
	info.reset_size()


## Where things land on the scrubber: [fraction along, colour].
func _marks() -> Array:
	var out: Array = []
	var n := maxi(1, stage.ghost.size() - 1)
	for e: Dictionary in preview_events:
		var k := int(e["t"]) - sim.tick - 1
		var c := Color("#8ecae6")
		var type := str(e["type"])
		if int(e["a"]) == me and type in ["hit", "throw", "armor"]:
			c = Color("#ffd166")
		elif int(e["d"]) == me and type in ["hit", "throw"]:
			c = Color("#ef476f")
		elif type == "parry":
			c = Color.WHITE
		elif type in ["clash", "tech"]:
			c = Color("#ff9f1c")
		out.append([clampf(float(k) / n, 0.0, 1.0), c])
	return out


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
			line = "%s blocks it" % other
		elif a == me and type == "armor":
			line = "%s's armour soaks it (%d)" % [other, int(e["dmg"])]
		elif d == me and type == "parry":
			line = "⚠ %s parries you" % other
		elif a == me and type == "parry":
			line = "You parry %s" % other
		elif (a == me or d == me) and type == "clash":
			line = "Clashes with %s - both stopped" % other
		elif (a == me or d == me) and type == "tech":
			line = "Grabs meet with %s - pushed apart" % other
		elif d == me and type in ["hit", "throw"]:
			line = "⚠ You get hit by %s" % other
		elif d == me and type == "block":
			line = "You block %s" % other
		if line != "" and not lines.has(line):
			lines.append(line)
	for id in dealt:
		lines.push_front("Hits %s for %d" % [sim.fighters[id].name, int(dealt[id])])
	return "" if lines.is_empty() else "\n" + "\n".join(lines)


func _on_scrub(v: float) -> void:
	stage.ghost_play = false
	stage.scrub_to(int(v))
	play_btn.text = "▶"
	scrub_label.text = "Frame %d / %d" % [int(v) + 1, stage.ghost.size()]


func _toggle_play() -> void:
	stage.ghost_play = not stage.ghost_play
	play_btn.text = "⏸" if stage.ghost_play else "▶"


func _toggle_boxes() -> void:
	stage.show_boxes = boxes_btn.button_pressed


func _process(_delta: float) -> void:
	if visible and stage != null and stage.ghost_play and not stage.ghost.is_empty():
		var i := stage.ghost_index()
		scrub.set_value_no_signal(float(i))
		scrub_label.text = "Frame %d / %d" % [i + 1, stage.ghost.size()]


func _confirm() -> void:
	if visible:
		confirmed.emit(choice.duplicate())


## The thin strip over the scrubber with a mark where each thing lands (yours yellow, on you red, blocks blue, clashes
## orange).
class Timeline:
	extends Control
	var marks: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, size.y / 2.0 - 1.0), Vector2(size.x, 2.0)), Color("#3a3d4d"))
		for m: Array in marks:
			var x := float(m[0]) * size.x
			draw_rect(Rect2(x - 2.0, 0, 4.0, size.y), m[1])
