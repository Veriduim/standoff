extends Control
## The game on one phone (for now: you against bots - the same-Wi-Fi lobby plugs into this later): the start menu,
## everyone's cards along the top, the stage, and - when it's your turn - the move menu along the bottom: tap a move,
## aim it (a direction, a distance, a length or a parry frame), tap who it's for, watch its ghost loop, Confirm. Then
## the segment plays out and the next turn comes.

const CARD_H := 64.0
const MENU_H := 236.0
const FONT := 22
const SMALL := 17
const DIRS := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2.ZERO, Vector2(1, 0),
	Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]
const ARROWS := ["↖", "↑", "↗", "←", "", "→", "↙", "↓", "↘"]

var sim: Sim
var bots := {}             ## fighter id -> Bot
var me := 0
var phase := "menu"        ## menu | pick | play | over
var choice := {}           ## your pick being made
var speed := 1.0
var setup_char := "bruiser"
var setup_count := 3       ## opponents
var setup_mode := "ffa"
var auto_me := false       ## a bot plays you too (the tests; a demo)

var stage: StageView
var cards: HBoxContainer
var menu_panel: PanelContainer
var moves_row: HBoxContainer
var param_box: VBoxContainer
var info: Label
var confirm_btn: Button
var banner: Label
var start_panel: PanelContainer
var over_panel: PanelContainer
var fast_btn: Button

var _frames: Array = []
var _events: Array = []
var _first_tick := 0
var _play_pos := 0.0
var _shown := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # (taps on the stage reach StageView's _unhandled_input)
	stage = StageView.new()
	add_child(stage)
	stage.fighter_tapped.connect(_on_tap_fighter)
	cards = HBoxContainer.new()
	cards.position = Vector2(8, 6)
	cards.add_theme_constant_override("separation", 6)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	banner = _label("", FONT, Color("#e8e8f0"))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	fast_btn = _button("1x", func() -> void: _toggle_speed())
	add_child(fast_btn)
	_build_menu()
	_build_start()
	_build_over()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_start()


func _layout() -> void:
	var vp := get_viewport_rect().size
	banner.position = Vector2(0, CARD_H + 14)
	banner.size = Vector2(vp.x, 30)
	fast_btn.position = Vector2(vp.x - 86, CARD_H + 10)
	fast_btn.size = Vector2(76, 44)
	menu_panel.position = Vector2(0, vp.y - MENU_H)
	menu_panel.size = Vector2(vp.x, MENU_H)
	_stage_band()
	for p in [start_panel, over_panel]:
		(p as Control).position = (vp - (p as Control).size) / 2.0


# ---------- building the screen ----------

func _label(text: String, fs := FONT, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, on: Callable, fs := FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(64, 52)
	b.pressed.connect(on)
	return b


func _box(col := Color("#1e2029ee"), radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	return s


func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _box(Color("#16171ff0"), 0))
	add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	menu_panel.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 64)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	moves_row = HBoxContainer.new()
	moves_row.add_theme_constant_override("separation", 6)
	scroll.add_child(moves_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	param_box = VBoxContainer.new()
	param_box.custom_minimum_size = Vector2(380, 0)
	row.add_child(param_box)
	info = _label("", SMALL, Color("#c9c9d6"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	confirm_btn = _button("Confirm", func() -> void: _confirm(), 26)
	confirm_btn.custom_minimum_size = Vector2(200, 0)
	var cs := _box(Color("#2f9e5b"))
	confirm_btn.add_theme_stylebox_override("normal", cs)
	confirm_btn.add_theme_stylebox_override("hover", cs)
	confirm_btn.add_theme_stylebox_override("pressed", _box(Color("#24804a")))
	row.add_child(confirm_btn)
	menu_panel.visible = false


func _build_start() -> void:
	start_panel = PanelContainer.new()
	start_panel.add_theme_stylebox_override("panel", _box())
	start_panel.size = Vector2(620, 420)
	add_child(start_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	start_panel.add_child(v)
	var title := _label("STANDOFF", 46, Color("#f2f2f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var pick_char := func(x: String) -> void: setup_char = x
	var pick_count := func(x: String) -> void: setup_count = int(x)
	var pick_mode := func(x: String) -> void: setup_mode = x
	v.add_child(_choice_row("You", [["Bruiser", "bruiser"], ["Dancer", "dancer"]], pick_char, "bruiser"))
	v.add_child(_choice_row("Opponents", [["1", "1"], ["2", "2"], ["3", "3"], ["4", "4"], ["5", "5"]], pick_count,
			"3"))
	v.add_child(_choice_row("Mode", [["Free-for-all", "ffa"], ["Teams", "teams"]], pick_mode, "ffa"))
	var go := _button("Fight", func() -> void: start_local(setup_char, setup_count, setup_mode), 30)
	go.add_theme_stylebox_override("normal", _box(Color("#c0392b")))
	go.add_theme_stylebox_override("hover", _box(Color("#c0392b")))
	v.add_child(go)
	var wifi := _button("Same Wi-Fi (coming next)", func() -> void: pass, SMALL)
	wifi.disabled = true
	v.add_child(wifi)


func _choice_row(title: String, opts: Array, on: Callable, start: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t := _label(title, FONT, Color("#a7a7b8"))
	t.custom_minimum_size = Vector2(150, 0)
	h.add_child(t)
	var group := ButtonGroup.new()
	for o: Array in opts:
		var b := _button(str(o[0]), func() -> void: on.call(str(o[1])))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = str(o[1]) == start
		h.add_child(b)
	return h


func _build_over() -> void:
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", _box())
	over_panel.size = Vector2(520, 230)
	add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	over_panel.add_child(v)
	var l := _label("", 40)
	l.name = "Result"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	h.add_child(_button("Rematch", func() -> void: start_local(setup_char, setup_count, setup_mode)))
	h.add_child(_button("Menu", func() -> void: _show_start()))
	over_panel.visible = false


func _show_start() -> void:
	phase = "menu"
	start_panel.visible = true
	over_panel.visible = false
	menu_panel.visible = false
	banner.text = ""


# ---------- the match ----------

## You plus `opponents` bots; teams = two sides (you on the first), else everyone for themselves.
func start_local(character: String, opponents: int, mode: String) -> void:
	var players := [{"name": "You", "character": character, "team": 0}]
	var chars := ["dancer", "bruiser"]
	for i in opponents:
		players.append({"name": "Bot %d" % (i + 1), "character": chars[i % 2], "team": (i + 1) % 2})
	if mode == "teams" and opponents < 2:
		mode = "ffa"
	sim = Sim.create(players, mode)
	bots.clear()
	for i in range(1, players.size()):
		bots[i] = Bot.new(i * 7 + 3)
	me = 0
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	stage.you = me
	stage.show_tick(sim.record())
	start_panel.visible = false
	over_panel.visible = false
	_build_cards()
	_next()


func _build_cards() -> void:
	for c in cards.get_children():
		c.queue_free()
	var vp := get_viewport_rect().size
	var w := minf(206.0, (vp.x - 16.0 - 6.0 * (sim.fighters.size() - 1)) / sim.fighters.size())
	for f in sim.fighters:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(w, CARD_H - 8)
		var st := _box(Color("#1e2029dd"), 10)
		st.set_content_margin_all(6)
		st.border_color = StageView.COLOURS[f.id % 6]
		st.border_width_left = 5
		p.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		p.add_child(v)
		var n := _label("%s · %s" % [f.name, Moves.stats(f.character)["name"]], 15, Color("#e2e2ea"))
		n.name = "Name"
		v.add_child(n)
		v.add_child(_bar("HP", StageView.COLOURS[f.id % 6], 12))
		v.add_child(_bar("Meter", Color("#ffd166"), 6))
		cards.add_child(p)
	_update_cards()


func _bar(bar_name: String, col: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.name = bar_name
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#0e0f14")
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _update_cards(rec: Array = []) -> void:
	if sim == null:
		return
	for f in sim.fighters:
		if f.id >= cards.get_child_count():
			return
		var card := cards.get_child(f.id)
		var hp := float(rec[f.id][6]) if not rec.is_empty() else float(f.hp)
		var meter := float(rec[f.id][7]) if not rec.is_empty() else float(f.meter)
		var hb := card.find_child("HP", true, false) as ProgressBar
		hb.max_value = f.max_hp
		hb.value = hp
		var mb := card.find_child("Meter", true, false) as ProgressBar
		mb.max_value = Sim.METER_MAX
		mb.value = meter
		card.modulate = Color(1, 1, 1, 0.45) if hp <= 0.0 else Color.WHITE


## The next turn: bots pick at once; if you're free you pick; then it plays.
func _next() -> void:
	if sim.over():
		_finish()
		return
	var free := sim.deciders()
	stage.deciding = free
	if free.has(me) and not auto_me:
		phase = "pick"
		_open_menu()
	else:
		_commit({})


func _commit(mine: Dictionary) -> void:
	var picks := {}
	for id in sim.deciders():
		if id == me and not mine.is_empty():
			picks[id] = mine
		elif bots.has(id):
			picks[id] = (bots[id] as Bot).choose(sim, id)
		elif id == me and auto_me:
			picks[id] = Bot.new(sim.tick + 99).choose(sim, id)
	menu_panel.visible = false
	_stage_band()
	stage.ghost = []
	stage.target = -1
	stage.deciding = []
	sim.apply(picks)
	var seg := sim.run_segment()
	_frames = seg["frames"]
	_events = seg["events"]
	_first_tick = int(seg["end_tick"]) - _frames.size() + 1
	_play_pos = 0.0
	_shown = -1
	phase = "play"
	banner.text = ""


func _process(delta: float) -> void:
	if phase != "play":
		return
	_play_pos += delta * 60.0 * speed
	var i := mini(int(_play_pos), _frames.size() - 1)
	while _shown < i:
		_shown += 1
		var t := _first_tick + _shown
		stage.show_tick(_frames[_shown], _events.filter(func(e: Dictionary) -> bool: return int(e["t"]) == t))
	_update_cards(_frames[i] if not _frames.is_empty() else [])
	if int(_play_pos) >= _frames.size():
		stage.show_tick(sim.record())
		_update_cards()
		_next()


## Play out what's left at once (the tests; a skip).
func finish_playback() -> void:
	if phase == "play":
		_play_pos = float(_frames.size())
		stage.quiet = true
		_process(0.0)
		stage.quiet = false


func _finish() -> void:
	phase = "over"
	menu_panel.visible = false
	var won := sim.winners()
	var text := "Everyone's down"
	if won.has(me):
		text = "You win!" if won.size() == 1 else "Your team wins!"
	elif not won.is_empty():
		text = "%s wins" % sim.fighters[won[0]].name if sim.mode == "ffa" else "The other team wins"
	(over_panel.find_child("Result", true, false) as Label).text = text
	over_panel.visible = true
	banner.text = ""


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	fast_btn.text = "%dx" % int(speed)


# ---------- your pick ----------

## The stage keeps to the screen between the cards and the menu (when it's up).
func _stage_band() -> void:
	var vp := get_viewport_rect().size
	stage.view_top = CARD_H + 48.0
	stage.view_bottom = vp.y - (MENU_H + 10.0 if menu_panel.visible else 24.0)


func _open_menu() -> void:
	menu_panel.visible = true
	_stage_band()
	banner.text = "Your move"
	for c in moves_row.get_children():
		c.queue_free()
	for mid in sim.legal_moves(me):
		var m := Moves.move(sim.fighters[me].character, mid)
		var b := _button(str(m["name"]), func() -> void: _select(mid), 19)
		b.custom_minimum_size = Vector2(118, 56)
		b.toggle_mode = true
		var on := _box(StageView.COLOURS[me % 6].darkened(0.15), 10)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.name = mid
		moves_row.add_child(b)
	var f := sim.fighters[me]
	var t := sim.get_f(f.target)
	choice = {"target": t.id if t != null and not t.ko else (sim.nearest_enemy(f).id if sim.nearest_enemy(f) else -1)}
	_select(sim.legal_moves(me)[0])


func _select(mid: String) -> void:
	choice["move"] = mid
	for c in moves_row.get_children():
		(c as Button).set_pressed_no_signal(c.name == mid)
	var f := sim.fighters[me]
	var m := Moves.move(f.character, mid)
	var t := sim.get_f(int(choice.get("target", -1)))
	var toward := 1.0 if t == null or t.pos.x >= f.pos.x else -1.0
	match str(m.get("param", "")):
		"dist":
			choice["x"] = 1.0
		"dir":
			choice["x"] = toward * 0.7
			choice["y"] = 0.7 if mid == "divekick" else (-1.0 if mid == "jump" else 0.0)
		"frames":
			choice["x"] = float(m["frames"])
		"frame":
			choice["x"] = 6.0
		_:
			choice["x"] = 0.0
	choice["y"] = choice.get("y", 0.0) if str(m.get("param", "")) == "dir" else 0.0
	_build_param(m)
	_refresh()


func _build_param(m: Dictionary) -> void:
	for c in param_box.get_children():
		c.queue_free()
	match str(m.get("param", "")):
		"dist":
			param_box.add_child(_label("Distance  (back ← → forward)", SMALL, Color("#a7a7b8")))
			param_box.add_child(_slider(-1.0, 1.0, 0.25, float(choice["x"]), func(v: float) -> void:
				choice["x"] = v
				_refresh()))
		"frames":
			var r: Array = m["range"]
			param_box.add_child(_label("How long (frames)", SMALL, Color("#a7a7b8")))
			param_box.add_child(_slider(float(r[0]), float(r[1]), 1.0, float(choice["x"]), func(v: float) -> void:
				choice["x"] = v
				_refresh()))
		"frame":
			var r2: Array = m["range"]
			param_box.add_child(_label("Parry on frame", SMALL, Color("#a7a7b8")))
			param_box.add_child(_slider(float(r2[0]), float(r2[1]), 1.0, float(choice["x"]), func(v: float) -> void:
				choice["x"] = v
				_refresh()))
		"dir":
			param_box.add_child(_label("Direction", SMALL, Color("#a7a7b8")))
			var g := GridContainer.new()
			g.columns = 3
			for k in 9:
				var d: Vector2 = DIRS[k]
				if d == Vector2.ZERO:
					g.add_child(Control.new())
					continue
				var aim := func() -> void:
					choice["x"] = d.x
					choice["y"] = d.y
					_refresh()
				var b := _button(ARROWS[k], aim, 20)
				b.custom_minimum_size = Vector2(54, 42)
				g.add_child(b)
			param_box.add_child(g)
		_:
			param_box.add_child(_label("Tap a fighter to pick your target", SMALL, Color("#a7a7b8")))


func _slider(lo: float, hi: float, step: float, value: float, on: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(340, 44)
	s.value_changed.connect(on)
	return s


func _on_tap_fighter(id: int) -> void:
	if phase != "pick" or sim == null:
		return
	if sim.enemies(sim.fighters[me], sim.fighters[id]):
		choice["target"] = id
		_refresh()


## The ghost and the move's numbers for the pick as it stands.
func _refresh() -> void:
	var f := sim.fighters[me]
	var m := Moves.move(f.character, str(choice["move"]))
	var pv := sim.preview({me: choice}, 80)
	stage.ghost = pv["frames"]
	stage.ghost_only = me
	stage.target = int(choice.get("target", -1))
	var parts: Array[String] = [str(m["name"])]
	var hits: Array = m.get("hits", [])
	if not hits.is_empty():
		var dmg := 0
		for e: Dictionary in hits:
			dmg += int(e["dmg"])
		parts.append("hits on frame %d" % int(hits[0]["from"]))
		parts.append("%d damage" % dmg)
	var length := int(choice["x"]) if str(m.get("param", "")) == "frames" else int(m["frames"])
	parts.append("%d frames" % length)
	if m.has("armor"):
		parts.append("armoured %d-%d" % [int(m["armor"][0]), int(m["armor"][1])])
	if int(m.get("cost", 0)) > 0:
		parts.append("costs %d meter" % int(m["cost"]))
	var kind := str(m["kind"])
	var tip := {"grab": "Beats guard and parry, loses to strikes.", "guard": "Blocks strikes (a little chip damage). Loses to grabs.",
		"parry": "Stops a strike that lands on your frame - then they're stunned.", "wait": "Do nothing for a while."}
	var t := sim.get_f(int(choice.get("target", -1)))
	info.text = " · ".join(parts) + ("\n" + str(tip[kind]) if tip.has(kind) else "") + \
			("\nTarget: %s" % t.name if t != null else "") + _outcome(pv["events"])


## What the preview says happens, in a line: your hits, and anything that lands on you (others standing still).
func _outcome(events: Array) -> String:
	var mine := {}
	var hurt := {}
	for e: Dictionary in events:
		var type := str(e["type"])
		if int(e["a"]) == me and type in ["hit", "throw", "armor"]:
			mine[int(e["d"])] = int(mine.get(int(e["d"]), 0)) + int(e["dmg"])
		elif int(e["d"]) == me and type in ["hit", "throw"]:
			hurt[int(e["a"])] = true
	var out := ""
	for id in mine:
		out += "\nHits %s for %d" % [sim.fighters[id].name, int(mine[id])]
	for id in hurt:
		out += "\n⚠ You get hit by %s" % sim.fighters[id].name
	return out


func _confirm() -> void:
	if phase != "pick":
		return
	_commit(choice.duplicate())
