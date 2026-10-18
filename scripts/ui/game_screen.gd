extends Control
## The game on one phone (for now: you against bots - the same-Wi-Fi lobby plugs into this later): the start menu,
## everyone's cards along the top, the stage, and - when it's your turn - the PickPanel (side tabs, the frame scrubber,
## Confirm). Then the segment plays out and the next turn comes.

const FONT := 22
const SMALL := 17

var sim: Sim
var bots := {}             ## fighter id -> Bot
var me := 0
var phase := "menu"        ## menu | pick | play | over
var speed := 1.0
var setup_char := "bruiser"
var setup_count := 3       ## opponents
var setup_mode := "ffa"
var auto_me := false       ## a bot plays you too (the tests; a demo)

var stage: StageView
var pick: PickPanel
var cards: HBoxContainer
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
	cards = HBoxContainer.new()
	cards.position = Vector2(8, 6)
	cards.add_theme_constant_override("separation", 6)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	banner = Ui.label("", FONT, Color("#e8e8f0"))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	fast_btn = Ui.button("1x", func() -> void: _toggle_speed())
	add_child(fast_btn)
	pick = PickPanel.new()
	add_child(pick)
	pick.confirmed.connect(func(c: Dictionary) -> void:
		if phase == "pick":
			_commit(c))
	_build_start()
	_build_over()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_start()


func _layout() -> void:
	var vp := get_viewport_rect().size
	banner.position = Vector2(0, Ui.CARD_H + 10)
	banner.size = Vector2(vp.x, 30)
	fast_btn.position = Vector2(10, Ui.CARD_H + 8)
	fast_btn.size = Vector2(70, 44)
	_stage_band()
	for p in [start_panel, over_panel]:
		(p as Control).position = (vp - (p as Control).size) / 2.0


## The stage keeps to the screen the panels leave: under the cards, above the bar and left of the tabs on your turn.
func _stage_band() -> void:
	var vp := get_viewport_rect().size
	var picking := pick != null and pick.visible
	stage.view_top = Ui.CARD_H + 48.0
	stage.view_bottom = vp.y - (PickPanel.BAR_H + 10.0 if picking else 24.0)
	stage.view_left = 0.0
	stage.view_right = vp.x - (PickPanel.TAB_W + 12.0 if picking else 0.0)


# ---------- the start and end ----------

func _build_start() -> void:
	start_panel = PanelContainer.new()
	start_panel.add_theme_stylebox_override("panel", Ui.box())
	start_panel.size = Vector2(620, 420)
	add_child(start_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	start_panel.add_child(v)
	var title := Ui.label("STANDOFF", 46, Color("#f2f2f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var pick_char := func(x: String) -> void: setup_char = x
	var pick_count := func(x: String) -> void: setup_count = int(x)
	var pick_mode := func(x: String) -> void: setup_mode = x
	v.add_child(_choice_row("You", [["Bruiser", "bruiser"], ["Dancer", "dancer"]], pick_char, "bruiser"))
	v.add_child(_choice_row("Opponents", [["1", "1"], ["2", "2"], ["3", "3"], ["4", "4"], ["5", "5"]], pick_count,
			"3"))
	v.add_child(_choice_row("Mode", [["Free-for-all", "ffa"], ["Teams", "teams"]], pick_mode, "ffa"))
	var go := Ui.button("Fight", func() -> void: start_local(setup_char, setup_count, setup_mode), 30)
	go.add_theme_stylebox_override("normal", Ui.box(Color("#c0392b")))
	go.add_theme_stylebox_override("hover", Ui.box(Color("#c0392b")))
	v.add_child(go)
	var wifi := Ui.button("Same Wi-Fi (coming next)", func() -> void: pass, SMALL)
	wifi.disabled = true
	v.add_child(wifi)


func _choice_row(title: String, opts: Array, on: Callable, start: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t := Ui.label(title, FONT, Color("#a7a7b8"))
	t.custom_minimum_size = Vector2(150, 0)
	h.add_child(t)
	var group := ButtonGroup.new()
	for o: Array in opts:
		var b := Ui.button(str(o[0]), func() -> void: on.call(str(o[1])))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = str(o[1]) == start
		h.add_child(b)
	return h


func _build_over() -> void:
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", Ui.box())
	over_panel.size = Vector2(520, 230)
	add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	over_panel.add_child(v)
	var l := Ui.label("", 40)
	l.name = "Result"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	h.add_child(Ui.button("Rematch", func() -> void: start_local(setup_char, setup_count, setup_mode)))
	h.add_child(Ui.button("Menu", func() -> void: _show_start()))
	over_panel.visible = false


func _show_start() -> void:
	phase = "menu"
	start_panel.visible = true
	over_panel.visible = false
	pick.close()
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
		p.custom_minimum_size = Vector2(w, Ui.CARD_H - 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := Ui.box(Color("#1e2029dd"), 10)
		st.set_content_margin_all(6)
		st.border_color = StageView.COLOURS[f.id % 6]
		st.border_width_left = 5
		p.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		p.add_child(v)
		var n := Ui.label("%s · %s" % [f.name, Moves.stats(f.character)["name"]], 15, Color("#e2e2ea"))
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
		banner.text = "Your move"
		pick.open(sim, me, stage)
		_stage_band()
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
	pick.close()
	_stage_band()
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
	pick.close()
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
