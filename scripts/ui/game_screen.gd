extends Control
## The game on one phone (for now: you against bots - online plugs into this later): the HomeScreen (a live bot match
## behind it), everyone's cards along the top, the stage, and - when it's your turn - the PickPanel (side tabs of move
## icons, the direction pad, the frame scrubber, Confirm). Then the segment plays out and the next turn comes.
## One character for now - everyone is the Dancer, in their own colour (Timmy 17:52).

const FONT := 22
const SMALL := 17
const LAG_HOLD := 0.45     ## seconds the HP lost stays showing (white) before it drains (pick 10)
const LAG_SPEED := 0.6     ## how fast it drains, in whole bars a second
const TURN_SECONDS := 30.0 ## the turn clock (the YOMI wiki's default ruleset: 30 s) - then your pick as it stands goes in

var sim: Sim
var bots := {}             ## fighter id -> Bot
var me := 0
var phase := "menu"        ## menu | pick | play | over
var speed := 1.0
var setup_count := 3       ## opponents
var setup_mode := "ffa"
var setup_colour := 0      ## your colour (StageView.COLOURS) - the bots take the others
var training := false        ## training mode: you and a Dummy (02:28)
static var bots_as := ""     ## the bots' character, when it mustn't be random (the tests)
var train_bar: HBoxContainer ## (training) the dummy's setting and Reset, top right
var auto_me := false       ## a bot plays you too (the tests; a demo)

var stage: StageView
var sfx: Sfx                 ## the sounds (stage events, the menus, your turn)
var _tick_at := -1           ## the last whole second the turn clock ticked on
var pick: PickPanel
var cards: HBoxContainer
var _pred := {}              ## fighter id -> the damage the picks being looked at would do (the cards' orange)
var banner: Label
var home: HomeScreen
var lobby: LobbyScreen
var net_match: NetMatch      ## an online match (null = this phone against bots)
var _net_queue: Array = []   ## turns that came in while one was still playing - played next, in order
var leave_btn: Button
var clock: Label
var post: ColorRect
var over_panel: PanelContainer
var fast_btn: Button

var _frames: Array = []
var _events: Array = []
var _shots: Array = []       ## the segment's projectiles, a list per frame
var _first_tick := 0
var _play_pos := 0.0
var _shown := -1
var _lag := {}               ## fighter id -> [HP shown by the white chunk, seconds before it drains, HP now]
var _turn_left := 0.0        ## seconds left on your turn
var _ask := ""               ## what your turn asks (the banner)
var _replay_log: Array = []   ## every turn as it played this match (frames, events, shots, first tick) - Replay
var _replaying := false
var _rec := {}               ## this match, recorded to save (02:15): {v, when, names, colours, me, mode, start, turns}
var _rec_saved := false
var _saved_replay := false   ## watching a saved replay (from the home screen) - its end goes back home
var replay_list: ReplayList
var style_panel: StylePanel   ## your look (02:28 "3")
var _replay_i := -1
var replay_btn: Button
var menu_btn: Button         ## ☰ - the match menu (00:28 "How do I quit a game with bots?")
var menu_panel: PanelContainer
var how: HowToPlay           ## How to play (01:32) - over everything
var _history: Array = []     ## against bots: the match as it was at each of your picks (Undo - YOMI's single player)
var _demo: Sim               ## the bot match behind the home screen
var _demo_bots: Array = []
var _demo_frames: Array = []
var _demo_events: Array = []
var _demo_shots: Array = []
var _demo_first := 0
var _demo_pos := 0.0
var _demo_shown := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # (taps on the stage reach StageView's _unhandled_input)
	stage = StageView.new()
	add_child(stage)
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	stage.sfx = sfx
	post = ColorRect.new()   # (over the stage, under everything else: the colour split)
	post.name = "Post"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/post.gdshader")
	post.material = mat
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.visible = false
	add_child(post)
	home = HomeScreen.new()
	add_child(home)
	home.fight.connect(func(n: int, m: String, c: int) -> void: start_local(n, m, c))
	home.online.connect(func(c: int) -> void:
		home.visible = false
		lobby.open(c))
	cards = HBoxContainer.new()
	cards.position = Vector2(8, 6)
	cards.add_theme_constant_override("separation", 6)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	banner = Ui.label("", FONT, Color("#e8e8f0"))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT   # (left, by the speed button - clear of the drawer)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	fast_btn = Ui.button("1x", func() -> void: _toggle_speed())
	add_child(fast_btn)
	clock = Ui.label("", 20, Color("#e8e8f0"))   # (the round: seconds of match time left)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock)
	pick = PickPanel.new()
	add_child(pick)
	pick.undone.connect(undo)
	pick.confirmed.connect(func(c: Dictionary) -> void:
		if phase == "pick":
			_commit(c))
	_build_over()
	lobby = LobbyScreen.new()
	add_child(lobby)
	lobby.play.connect(start_online)
	lobby.closed.connect(func() -> void: _show_start())
	lobby.rejoined.connect(_on_lobby_back)
	lobby.invited_away.connect(func() -> void:   # (a rematch invite while on a finished match's result: to it)
		if net_match != null and phase == "over":
			_leave_match())
	lobby.net.status.connect(_on_line)
	menu_btn = Ui.button("☰", func() -> void: toggle_menu(), 26)
	menu_btn.name = "MenuButton"
	menu_btn.visible = false
	add_child(menu_btn)
	_build_menu()
	replay_btn = Ui.button("Skip ▶▶", func() -> void: _end_replay(), 16)
	replay_btn.visible = false
	add_child(replay_btn)
	leave_btn = Ui.button("Leave", func() -> void: _leave_match(), 16)
	leave_btn.visible = false
	add_child(leave_btn)
	how = HowToPlay.new()
	how.name = "HowToPlay"
	add_child(how)
	home.help.connect(func() -> void: how.open())
	replay_list = ReplayList.new()
	replay_list.name = "ReplayList"
	add_child(replay_list)
	home.replays.connect(func() -> void: replay_list.open())
	Style.load_saved()
	style_panel = StylePanel.new()
	style_panel.name = "StylePanel"
	add_child(style_panel)
	home.style.connect(func(c: int) -> void: style_panel.open(StageView.COLOURS[c]))
	style_panel.closed.connect(func() -> void:   # (in a lobby: everyone's told your new look)
		if lobby.net.in_lobby():
			lobby.net.set_member({"outline": Style.outline, "trail": Style.trail}))
	home.training.connect(func(c: int) -> void: start_local(1, "ffa", c, true))
	_build_train_bar()
	replay_list.picked.connect(watch_saved)
	_build_turn_note()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_start()
	if HowToPlay.auto and not HowToPlay.seen():   # (the first launch: the cards once, by themselves)
		how.open()


## A phone held upright (the web version: a browser can't lock the screen sideways the way the app does) - over
## everything, until it's turned.
## Held upright: the turn note, until it's sideways.
func _turned(vp: Vector2) -> void:
	var turn := get_node_or_null("TurnNote") as CanvasLayer
	if turn != null:
		turn.visible = vp.x < vp.y


func _build_turn_note() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TurnNote"
	layer.layer = 90
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color("#0b0c11")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)
	var phone := TurnPhone.new()
	phone.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(phone)
	layer.visible = false


func _layout() -> void:
	var vp := get_viewport_rect().size
	_turned(vp)
	if train_bar != null:
		train_bar.position = Vector2(vp.x - 540.0, Ui.CARD_H + 44)
	banner.position = Vector2(152, Ui.CARD_H + 16)
	banner.size = Vector2(vp.x - 152.0 - PickPanel.TAB_W - 20.0, 30)
	fast_btn.position = Vector2(70, Ui.CARD_H + 8)
	fast_btn.size = Vector2(70, 44)
	if leave_btn != null:
		leave_btn.position = Vector2(vp.x - 230.0, Ui.CARD_H + 44)
		leave_btn.size = Vector2(90, 40)
	if replay_btn != null:
		replay_btn.position = Vector2(vp.x - 250.0, Ui.CARD_H + 44)
		replay_btn.size = Vector2(110, 40)
	if menu_btn != null:
		menu_btn.position = Vector2(10, Ui.CARD_H + 8)   # (top left, before the speed button)
		menu_btn.size = Vector2(54, 44)
		menu_panel.reset_size()
		menu_panel.position = (vp - menu_panel.size) / 2.0
	clock.position = Vector2(vp.x - 230.0, Ui.CARD_H + 14)
	clock.size = Vector2(120, 30)
	post.position = Vector2.ZERO   # (sized by hand - this screen's own rect isn't the viewport's)
	post.size = vp
	_stage_band()
	over_panel.reset_size()   # (fits what's shown - online there's no Rematch)
	over_panel.position = (vp - over_panel.size) / 2.0


## The stage keeps to the screen the panels leave: under the cards, above the bar and left of the tabs on your turn.
func _stage_band() -> void:
	var vp := get_viewport_rect().size
	var picking := pick != null and pick.visible
	stage.view_top = Ui.CARD_H + 48.0 if phase != "menu" else 40.0
	stage.view_bottom = vp.y - (pick.bar_h() + 10.0 if picking else 24.0)
	stage.view_left = PickPanel.TAB_W + 12.0 if picking else 0.0   # (tabs down both sides on your turn)
	stage.view_right = vp.x - (PickPanel.TAB_W + 12.0 if picking else 0.0)


# ---------- the start and end ----------

func _build_over() -> void:
	over_panel = PanelContainer.new()   # (00:57 "its side by side instead of stacked" - stacked, like the ☰ menu)
	var st := Ui.box(Color("#15161ef4"), 16)
	st.set_content_margin_all(22)
	st.border_color = Color("#3a3d4d")
	st.set_border_width_all(2)
	over_panel.add_theme_stylebox_override("panel", st)
	add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	over_panel.add_child(v)
	var l := Ui.label("", 36)
	l.name = "Result"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var again := Ui.button("Rematch", func() -> void: rematch(), 22)
	again.name = "Rematch"
	for k in ["normal", "hover", "focus"]:
		again.add_theme_stylebox_override(k, Ui.box(Color("#d63d3d"), 12))
	again.add_theme_stylebox_override("pressed", Ui.box(Color("#a82f2f"), 12))
	var rp := Ui.button("Replay", func() -> void: watch_replay(), 22)   # (23:59 "No replay on fight finish?")
	rp.name = "Replay"
	var menu := Ui.button("Menu", func() -> void: _leave_match(), 22)
	menu.name = "Menu"
	for b: Button in [again, rp, menu]:
		b.custom_minimum_size = Vector2(300, 54)
		v.add_child(b)
	over_panel.visible = false


func _show_start() -> void:
	phase = "menu"
	home.visible = true
	stage.outlines = []   # (the demo behind the home screen: plain)
	stage.trails = []
	training = false
	if train_bar != null:
		train_bar.visible = false
	_menu_shown(false)
	if menu_btn != null:
		menu_btn.visible = false
	over_panel.visible = false
	fast_btn.visible = false
	pick.close()
	banner.text = ""
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	_demo_start()
	_stage_band()


## The match behind the home screen: four bots, round and round.
func _demo_start() -> void:
	var players := []
	for i in 4:   # (both of them, mixed - 05:03 the Bruiser)
		players.append({"name": "", "character": Moves.ORDER[i % Moves.ORDER.size()]})
	_demo = Sim.create(players, "ffa")
	stage.half = _demo.half   # (the stage as wide as the match's - 06:14 "they are off the map")
	_demo_bots.clear()
	for i in 4:
		_demo_bots.append(Bot.new(randi() % 9999 + i))
	stage.setup(_demo.fighters.map(func(f: Fighter) -> String: return f.character), [])
	stage.palette = []
	stage.you = -1
	stage.deciding = []
	stage.ghost = []
	stage.time_scale = 1.0
	stage.show_tick(_demo.record(), [], _demo.record_shots())
	_demo_frames = []
	_demo_pos = 0.0
	_demo_shown = -1


## The match behind the home screen plays on - each tick shown once (its effects with it), held through a hit's freeze.
func _demo_step(delta: float) -> void:
	if _demo == null or stage.fx.frozen():
		return
	if _demo_shown >= _demo_frames.size() - 1:
		if _demo.over():
			_demo_start()
			return
		var picks := {}
		for id in _demo.deciders():
			picks[id] = (_demo_bots[id] as Bot).choose(_demo, id)
		_demo.apply(picks)
		var seg := _demo.run_segment()
		_demo_frames = seg["frames"]
		_demo_events = seg["events"]
		_demo_shots = seg.get("shots", [])
		_demo_first = int(seg["end_tick"]) - _demo_frames.size() + 1
		_demo_pos = 0.0
		_demo_shown = -1
	_demo_pos += delta * 60.0
	var upto := mini(int(_demo_pos), _demo_frames.size() - 1)
	while _demo_shown < upto:
		_demo_shown += 1
		var t := _demo_first + _demo_shown
		stage.show_tick(_demo_frames[_demo_shown], _demo_events.filter(func(e: Dictionary) -> bool: return int(e["t"]) == t),
				_demo_shots[_demo_shown] if _demo_shown < _demo_shots.size() else [])
		if stage.fx.frozen():
			_demo_pos = float(_demo_shown)
			break


# ---------- the match ----------

## You plus `opponents` bots, everyone the Dancer; teams = two sides (you on the first), else everyone for themselves.
## You wear `colour`; the bots take the others in order.
func start_local(opponents: int, mode: String, colour := 0, train := false) -> void:
	setup_count = opponents
	setup_mode = mode
	setup_colour = colour
	training = train
	_demo = null
	var players := [{"name": "You", "character": HomeScreen.fighter, "team": 0}]
	for i in opponents:   # (the bots: either of them, at random; the dummy - whoever the bar says)
		var ch: String = Moves.ORDER[randi() % Moves.ORDER.size()] if bots_as == "" else bots_as
		if train:
			ch = str(train_bar.get_meta("who", HomeScreen.fighter)) if train_bar != null else HomeScreen.fighter
		players.append({"name": "Dummy" if train else "Bot %d" % (i + 1), "character": ch, "team": (i + 1) % 2})
	if mode == "teams" and opponents < 2:
		mode = "ffa"
	sim = Sim.create(players, mode)   # (the Dancer as she is: Fans + Tempo - 23:31)
	menu_btn.visible = true
	_menu_shown(false)
	_history.clear()
	_replay_log.clear()
	stage.ceiling = sim.ceiling
	stage.half = sim.half   # (06:14 "they are off the map": the floor drawn the old width, 1600, on a 2800 stage)
	bots.clear()
	for i in range(1, players.size()):
		bots[i] = Bot.new(i * 7 + 3, Bot.chosen)   # (the level picked on the home screen - 02:10)
	if train:   # (training: the dummy, a round that never runs out)
		var d := Dummy.new(11)
		if train_bar != null:
			d.mode = str(train_bar.get_meta("mode", "Stand"))
		bots[1] = d
		sim.round_len = 1 << 30
	if train_bar != null:
		train_bar.visible = train
	me = 0
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	var palette: Array = [StageView.COLOURS[colour]]
	for c: Color in StageView.COLOURS:
		if c != StageView.COLOURS[colour]:
			palette.append(c)
	stage.palette = palette
	stage.outlines = [Style.outline_colour(Style.outline)]   # (your look; the bots plain)
	stage.trails = [Style.trail_name(Style.trail)]
	stage.you = me
	stage.time_scale = speed
	stage.show_tick(sim.record(), [], sim.record_shots())
	_rec_begin()
	_lag.clear()
	home.visible = false
	fast_btn.visible = true
	over_panel.visible = false
	_saved_replay = false
	_build_cards()
	_next()


func _build_cards() -> void:
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	var vp := get_viewport_rect().size
	# (23:05 "Depending on the amount of players we should expand the health, burst and level gauges": the cards share
	# the top bar - one on one, half each)
	var w := (vp.x - 16.0 - 6.0 * (sim.fighters.size() - 1)) / sim.fighters.size()
	var mirror := sim.fighters.size() == 2   # (one on one: the right one's bars fill from the right, as YOMI's)
	for f in sim.fighters:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(w, Ui.CARD_H - 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := Ui.box(Color("#1e2029dd"), 10)
		st.set_content_margin_all(6)
		st.border_color = stage.colour_of(f.id)
		st.border_width_left = 5
		p.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var head := HBoxContainer.new()   # (the name; Free Cancels as green crosses and air options as dots, right)
		v.add_child(head)
		var n := Ui.label(f.name, 15, Color("#e2e2ea"))
		n.name = "Name"
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		head.add_child(n)
		var extras := RichTextLabel.new()
		extras.name = "Extras"
		extras.bbcode_enabled = true
		extras.fit_content = true
		extras.scroll_active = false
		extras.autowrap_mode = TextServer.AUTOWRAP_OFF
		extras.custom_minimum_size = Vector2(62, 0)
		extras.add_theme_font_size_override("normal_font_size", 12 if w < 190.0 else 13)
		extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(extras)
		var hpb := _hp_bar()
		v.add_child(hpb)
		var gauges := HBoxContainer.new()   # (BURST!! and LEVEL side by side under the health - YOMI's, 02:01)
		gauges.add_theme_constant_override("separation", 4)
		gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(gauges)
		var burst := _named_bar("Burst", Color("#4fb8ff"), "BURST!!")
		var level := HBoxContainer.new()
		level.add_theme_constant_override("separation", 3)
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge := Label.new()   # (the full levels, in a round badge)
		badge.name = "Level"
		badge.text = "0"
		badge.custom_minimum_size = Vector2(20, 18)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_stylebox_override("normal", Ui.box(Color("#0e0f14"), 9))
		(badge.get_theme_stylebox("normal") as StyleBoxFlat).set_content_margin_all(0)
		(badge.get_theme_stylebox("normal") as StyleBoxFlat).border_color = Color("#ffd166")
		(badge.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var meter := _named_bar("Meter", Color("#ffd166"), "LEVEL")
		level.add_child(badge)
		level.add_child(meter)
		gauges.add_child(burst)
		gauges.add_child(level)
		cards.add_child(p)
		if mirror and f.id == 1:   # (the right one's the other way round: its gauges and its badge by the middle)
			gauges.move_child(level, 0)
			level.move_child(badge, 1)
		if mirror and f.id == 1:
			for b in p.find_children("*", "ProgressBar", true, false):
				(b as ProgressBar).fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_update_cards()


## HEALTH: YOMI's yellow over a white chunk - the HP just lost shows white a moment, then drains away (pick 10) - and
## in orange, the damage the picks being looked at would do (YOMI's predicted damage, 02:01).
func _hp_bar() -> Control:
	var stack := Control.new()
	stack.name = "HPStack"
	stack.custom_minimum_size = Vector2(0, 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lag := _bar("Lag", Color(1, 1, 1, 0.85), 16)
	var hp := _bar("HP", Color("#ffd23f"), 16)
	hp.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	for b: ProgressBar in [lag, hp]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(b)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pred := ColorRect.new()   # (orange: placed over the end of the yellow by _update_cards)
	pred.name = "Pred"
	pred.color = Color("#ff8a3d")
	pred.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pred.visible = false
	stack.add_child(pred)
	return stack


## A thin gauge with its name on it (BURST!!, LEVEL).
func _named_bar(bar_name: String, col: Color, label: String) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 18)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := _bar(bar_name, col, 18)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l := Ui.label(label, 11, Color("#f2f2f7"))
	l.name = bar_name + "Name"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return stack


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
		var l: Array = _lag.get(f.id, [hp, 0.0, hp])
		if hp < float(l[2]):   # (hit again: the white chunk holds - it grows through a combo)
			l[1] = LAG_HOLD
		l[0] = maxf(float(l[0]), hp)
		l[2] = hp
		_lag[f.id] = l
		var lb := card.find_child("Lag", true, false) as ProgressBar
		lb.max_value = f.max_hp
		lb.value = float(l[0])
		var mb := card.find_child("Meter", true, false) as ProgressBar   # (LEVEL: the next level filling; the badge, the full)
		var levels := int(meter / float(Sim.BAR))
		mb.max_value = Sim.BAR
		mb.value = Sim.BAR if levels >= Sim.METER_MAX / Sim.BAR else meter - levels * Sim.BAR
		var badge := card.find_child("Level", true, false) as Label
		badge.text = str(levels)
		badge.add_theme_color_override("font_color", Color("#ffd166") if levels > 0 else Color("#6b6b78"))
		var pv := int(_pred.get(f.id, 0))   # (the orange: what the picks being looked at would take)
		var pr := card.find_child("Pred", true, false) as ColorRect
		pr.visible = pv > 0 and hp > 0.0
		if pr.visible:   # (by anchors - a share of the bar, whatever its size)
			var fa := clampf((hp - float(pv)) / float(f.max_hp), 0.0, 1.0)
			var fb := clampf(hp / float(f.max_hp), 0.0, 1.0)
			var mirrored := sim.fighters.size() == 2 and f.id == 1
			pr.anchor_top = 0.0
			pr.anchor_bottom = 1.0
			pr.anchor_left = 1.0 - fb if mirrored else fa
			pr.anchor_right = 1.0 - fa if mirrored else fb
			pr.offset_left = 0.0
			pr.offset_right = 0.0
			pr.offset_top = 0.0
			pr.offset_bottom = 0.0
		var bb := card.find_child("Burst", true, false) as ProgressBar   # (the Burst gauge - bright when it's full)
		bb.max_value = Sim.BURST_FULL
		bb.value = float(rec[f.id][8]) if not rec.is_empty() and rec[f.id].size() > 8 else float(f.burst)
		bb.modulate = Color(1.6, 1.6, 1.6) if bb.value >= Sim.BURST_FULL else Color(0.75, 0.75, 0.75)
		(card.find_child("BurstName", true, false) as Label).modulate = Color.WHITE if bb.value >= Sim.BURST_FULL \
				else Color(0.7, 0.7, 0.75)
		var fcs := int(rec[f.id][9]) if not rec.is_empty() and rec[f.id].size() > 9 else f.fc
		var airs := int(rec[f.id][10]) if not rec.is_empty() and rec[f.id].size() > 10 else Sim.AIR_OPTIONS - f.air_moves
		var ex := card.find_child("Extras", true, false) as RichTextLabel
		var text := "[right]%s[color=#46d17a]%s[/color][color=#3a3d4d]%s[/color] [color=#e8e8f0]%s[/color][color=#3a3d4d]%s[/color][/right]" \
				% [_trial_marks(f, rec[f.id] if not rec.is_empty() else []), "✕".repeat(fcs), "✕".repeat(Sim.FC_MAX - fcs),
				"●".repeat(airs), "●".repeat(Sim.AIR_OPTIONS - airs)]
		if ex.text != text:
			ex.text = text
		card.modulate = Color(1, 1, 1, 0.45) if hp <= 0.0 else Color.WHITE


## The damage each fighter would take from the picks being looked at (the ghost preview) - YOMI's orange.
func _predicted() -> Dictionary:
	var out := {}
	if pick == null or phase != "pick":
		return out
	for e: Dictionary in pick.preview_events:
		if str(e.get("type", "")) == "hit":
			var d := int(e.get("d", -1))
			out[d] = int(out.get(d, 0)) + int(e.get("dmg", 0))
	return out


## A fighter's own systems on their card: the form (Flow / Snap / Floor), the beats (pink), the fans in hand (gold) -
## the Dancer's; the Bruiser's Grit (orange, ten pips; K.O. when it's full).
func _trial_marks(f: Fighter, row: Array) -> String:
	var out := ""
	var has := row.size() > 16
	if sim.has_xf(f, "forms"):
		var fm := int(row[14]) if has else maxi(0, Sim.FORMS.find(f.form))
		out += "[color=#9fd8ff]%s[/color] " % ["Flow", "Snap", "Floor"][fm]
	if sim.has_xf(f, "tempo"):
		var tp := int(row[15]) if has else f.tempo
		out += "[color=#ff7ab6]%s[/color][color=#3a3d4d]%s[/color] " % ["▮".repeat(tp), "▮".repeat(Sim.TEMPO_MAX - tp)]
	if sim.has_xf(f, "fans"):
		var fn := int(row[16]) if has else f.fans
		out += "[color=#ffd23f]%s[/color][color=#3a3d4d]%s[/color] " % ["◆".repeat(fn), "◆".repeat(Sim.FANS_MAX - fn)]
	if sim.has_xf(f, "grit"):
		var g := int(row[17]) if row.size() > 17 else f.grit
		var pips := clampi(int(floor(float(g) * 10.0 / float(Sim.GRIT_MAX))), 0, 10)
		if g >= Sim.GRIT_MAX:
			out += "[color=#ffb766]K.O.[/color] "
		else:
			out += "[color=#ff9a3c]%s[/color][color=#3a3d4d]%s[/color] " % ["▮".repeat(pips), "▮".repeat(10 - pips)]
	return out


## Online: a match from the lobby - this phone's copy of it, from the host's start (or, watching, from where it is).
func start_online(nm: NetMatch) -> void:
	net_match = nm
	_net_queue.clear()
	if nm.get_parent() == null:
		add_child(nm)
	nm.turn.connect(_on_net_turn)
	nm.ended.connect(_on_net_end)
	nm.resync.connect(_on_resync)
	_demo = null
	bots.clear()
	sim = Sim.from_dict(nm.start_snap)
	_replay_log.clear()
	me = nm.mine
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	stage.palette = nm.seats.map(func(s: Dictionary) -> Color:
		return StageView.COLOURS[int(s.get("colour", 0)) % StageView.COLOURS.size()])
	stage.outlines = nm.seats.map(func(s: Dictionary) -> Color: return Style.outline_colour(int(s.get("outline", 0))))
	stage.trails = nm.seats.map(func(s: Dictionary) -> String: return Style.trail_name(int(s.get("trail", 0))))
	stage.you = me
	stage.half = sim.half
	stage.ceiling = sim.ceiling
	stage.time_scale = speed
	stage.show_tick(sim.record(), [], sim.record_shots())
	_rec_begin()
	_saved_replay = false
	_lag.clear()
	home.visible = false
	lobby.visible = false
	fast_btn.visible = true
	menu_btn.visible = true
	over_panel.visible = false
	_build_cards()
	_next()


## Rematch: against bots, the same again; online (02:28 "2"), the same players challenged again - the same bots, the
## same mode - and this phone back in the lobby waiting for their answers.
func rematch() -> void:
	if net_match == null:
		start_local(setup_count, setup_mode, setup_colour, training)
		return
	var ids := _rematch_ids()
	var bots_n := 0
	for s: Dictionary in net_match.seats:
		if int(s["peer"]) == 0 and not bool(s.get("left", false)):
			bots_n += 1
	var mode := net_match.mode
	_leave_match()
	lobby.challenge(ids, bots_n, mode)


## The other players of this online match still in the lobby.
func _rematch_ids() -> Array:
	var out: Array = []
	if net_match == null:
		return out
	for s: Dictionary in net_match.seats:
		var peer := int(s["peer"])
		if peer != 0 and peer != lobby.net.id and lobby.net.members.has(peer):
			out.append(peer)
	return out


## Back after the line dropped (01:32 "3 makes sense"): the host's state as it is now, and on from there.
func _on_resync(snap: Dictionary) -> void:
	if net_match == null or phase == "over":
		return
	_net_queue.clear()
	pick.close()
	sim = Sim.from_dict(snap)
	_rec_jump(snap)
	stage.fx.clear()
	stage.show_tick(sim.record(), [], sim.record_shots())
	_update_cards()
	_stage_band()
	banner.text = ""
	_next()


## The lobby line, during an online match: dropped - say so; back in - ask for the seat; gone for good - it's over here.
func _on_line(state: String, _detail: String) -> void:
	if net_match == null or not net_match.live or phase == "over":
		return
	match state:
		"closed", "reconnecting":
			if lobby.net.want_back:
				banner.text = "Connection lost - getting back in..."
			else:
				_on_net_end("Lost the connection")
		"error":
			if not lobby.net.want_back:
				_on_net_end("Lost the connection")


func _on_lobby_back() -> void:
	if net_match != null and net_match.live and phase != "over":
		banner.text = "Back - catching up..."
		net_match.reclaim(lobby.my_name)


## The host's turn, played here: the same picks from the same state; then the host's state is the truth.
func _on_net_turn(t: int, picks: Dictionary, snap: Dictionary) -> void:
	if net_match == null:
		return
	if phase == "play":   # (still playing the last one - this one's next)
		_net_queue.append([t, picks, snap])
		return
	if sim.tick != t:   # (out of step - take the host's state as it is)
		if not snap.is_empty():
			sim = Sim.from_dict(snap)
			_rec_jump(snap)
			stage.show_tick(sim.record(), [], sim.record_shots())
			_update_cards()
		return
	pick.close()
	_stage_band()
	stage.deciding = []
	stage.advantage = {}
	_rec_turn(t, picks)
	sim.apply(picks)
	var seg := sim.run_segment()
	if net_match.is_host():
		var w := NetMatch.wire(sim.to_dict())
		sim = Sim.from_dict(w)   # (the host goes on from exactly what everyone else gets)
		net_match.publish(t, picks, w)
	elif not snap.is_empty():
		sim = Sim.from_dict(snap)
	_frames = seg["frames"]
	_events = seg["events"]
	_shots = seg.get("shots", [])
	_first_tick = int(seg["end_tick"]) - _frames.size() + 1
	_replay_log.append({"frames": _frames, "events": _events, "shots": _shots, "first": _first_tick})
	_play_pos = 0.0
	_shown = -1
	phase = "play"
	banner.text = ""


func _on_net_end(reason: String) -> void:
	if phase == "over":
		return
	phase = "over"
	pick.close()
	(over_panel.find_child("Result", true, false) as Label).text = reason if reason != "" else "The match ended"
	_rec_save(reason if reason != "" else "The match ended")
	(over_panel.find_child("Rematch", true, false) as Button).visible = net_match != null and me >= 0 \
			and not _rematch_ids().is_empty()   # (a match the host ended: Rematch if anyone's still about)
	(over_panel.find_child("Menu", true, false) as Button).text = "Back to lobby"
	over_panel.visible = true
	_layout()
	banner.text = ""


## Leave the match (or close the result): online, back to the lobby (the host leaving ends it for everyone).
func _leave_match() -> void:
	leave_btn.visible = false
	if net_match != null:
		net_match.finish("%s left" % (sim.fighters[me].name if me >= 0 and me < sim.fighters.size() else "The host")
				if net_match.is_host() else "")
		net_match.queue_free()
		net_match = null
		over_panel.visible = false
		pick.close()
		for c in cards.get_children():
			cards.remove_child(c)
			c.queue_free()
		phase = "menu"
		fast_btn.visible = false
		banner.text = ""
		_demo_start()
		_stage_band()
		lobby.back_from_match()
		return
	_show_start()


## The next turn: bots pick at once; if you're free you pick; then it plays. (Online: the host collects the picks.)
func _next() -> void:
	if training:
		_refill()
	if sim.over():
		_finish()
		return
	var free := sim.deciders()
	stage.deciding = free
	if net_match != null and not (free.has(me) and not auto_me):
		phase = "wait"
		banner.text = "Waiting for the others..." if me >= 0 else "Watching"
		if net_match.is_host():   # (the turn opens before anyone's pick goes in)
			net_match.open_turn(sim)
		if free.has(me):   # (a bot playing for this phone - the tests)
			net_match.submit(me, Bot.new(sim.tick + 99).choose(sim, me), sim.tick)
		return
	if free.has(me) and not auto_me:
		phase = "pick"
		_turn_left = float(net_match.rules.get("turn", TURN_SECONDS)) if net_match != null else TURN_SECONDS
		_tick_at = -1
		sfx.play("ui_turn", -8.0)
		var f := sim.fighters[me]
		_ask = "Your move"
		if f.down > 0:
			_ask = "You're down - Get Up, Tech Roll, or stay down"
		elif sim.can_whiff(f):
			_ask = "Stuck in your move - Whiff Cancel (3/4 Burst) or Hold"
		elif sim.can_burst(f):
			_ask = "You're in a combo - BURST out, or Hold and lean"
		elif sim.reeling(f):
			_ask = "You're in a combo - lean with the pad"
		elif sim.interruptible(f):
			_ask = "Your move - or Hold to carry on"
		_banner()
		var adv := {}   # (how many ticks each enemy is still tied up - "+N" over them)
		for g in sim.alive():
			if sim.enemies(f, g) and not g.actionable() and not sim.interruptible(g) and g.busy() > 0:   # (+N)
				adv[g.id] = g.busy()
		stage.advantage = adv
		pick.can_undo = can_undo()
		pick.open(sim, me, stage)
		_stage_band()
		if net_match != null and net_match.is_host():
			net_match.open_turn(sim)
	else:
		_commit({})


## The match menu (☰ / Back): Resume, Restart (against bots), Quit to menu - or Leave match online.
func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	var st := Ui.box(Color("#15161ef4"), 16)
	st.set_content_margin_all(22)
	st.border_color = Color("#3a3d4d")
	st.set_border_width_all(2)
	menu_panel.add_theme_stylebox_override("panel", st)
	menu_panel.visible = false
	add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	menu_panel.add_child(v)
	var t := Ui.label("Paused", 28, Color("#f2f2f7"))
	t.name = "MenuTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for b: Array in [["Resume", "Resume"], ["Restart", "Restart"], ["Help", "How to play"], ["Sound", Sfx.label()],
			["Quit", "Quit to menu"]]:
		var id: String = b[0]
		var btn := Ui.button(str(b[1]), func() -> void: _menu_pick(id), 22)
		btn.name = "Menu" + id
		btn.custom_minimum_size = Vector2(280, 54)
		v.add_child(btn)


func toggle_menu() -> void:
	if phase in ["menu", "over"] or _replaying:
		return
	_menu_shown(not menu_panel.visible)


func _menu_shown(on: bool) -> void:
	if menu_panel == null:
		return
	menu_panel.visible = on
	var online := net_match != null
	(menu_panel.find_child("MenuTitle", true, false) as Label).text = "Match menu" if online else "Paused"
	(menu_panel.find_child("MenuRestart", true, false) as Button).visible = not online
	(menu_panel.find_child("MenuQuit", true, false) as Button).text = "Leave match" if online else "Quit to menu"
	_layout()


func _menu_pick(id: String) -> void:
	if id == "Sound":   # (on / off - the menu stays open)
		Sfx.set_on(not Sfx.on)
		(menu_panel.find_child("MenuSound", true, false) as Button).text = Sfx.label()
		home.sync_sound()
		return
	_menu_shown(false)
	match id:
		"Help":   # (the match waits while the cards are up)
			how.open()
		"Restart":
			start_local(setup_count, setup_mode, setup_colour, training)
		"Quit":
			_leave_match()


## The phone's Back: the match menu in a match; the lobby -> home; the result -> on; home -> quit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if how != null and how.visible:
		how.close()
	elif lobby != null and lobby.visible:
		lobby._close()
	elif phase == "over":
		_leave_match()
	elif phase == "menu":
		get_tree().quit()
	elif _replaying:
		_end_replay()
	else:
		toggle_menu()


## Replay (23:59): the whole match again, every turn as it played, at the speed button's speed; Skip (or its end) back
## to the result.
func watch_replay() -> void:
	if _replay_log.is_empty() or phase != "over":
		return
	_replaying = true
	_replay_i = -1
	over_panel.visible = false
	leave_btn.visible = false
	replay_btn.visible = true
	fast_btn.visible = true
	stage.fx.clear()
	banner.text = "▶ Replay"
	_replay_next()


func _replay_next() -> void:
	_replay_i += 1
	if _replay_i >= _replay_log.size():
		_end_replay()
		return
	var seg: Dictionary = _replay_log[_replay_i]
	_frames = seg["frames"]
	_events = seg["events"]
	_shots = seg["shots"]
	_first_tick = int(seg["first"])
	_play_pos = 0.0
	_shown = -1
	phase = "play"


func _end_replay() -> void:
	if not _replaying:
		return
	_replaying = false
	replay_btn.visible = false
	phase = "over"
	banner.text = ""
	stage.fx.clear()
	stage.show_tick(sim.record(), [], sim.record_shots())
	_update_cards()
	over_panel.visible = true
	_layout()


## Training (02:28): the dummy's setting (cycles) and Reset, top right beside Undo.
func _build_train_bar() -> void:
	train_bar = HBoxContainer.new()
	train_bar.name = "TrainBar"
	train_bar.add_theme_constant_override("separation", 8)
	train_bar.visible = false
	train_bar.set_meta("mode", "Stand")
	add_child(train_bar)
	var mode_btn := Ui.button("Dummy: Stand", func() -> void: _cycle_dummy(), 18)
	mode_btn.name = "DummyMode"
	mode_btn.custom_minimum_size = Vector2(190, 44)
	train_bar.add_child(mode_btn)
	var who := Ui.button("vs Dancer", func() -> void: _cycle_who(), 18)   # (who the dummy is - 05:03 two to pick from)
	who.name = "DummyWho"
	who.custom_minimum_size = Vector2(150, 44)
	train_bar.add_child(who)
	var reset := Ui.button("Reset", func() -> void: reset_training(), 18)
	reset.name = "Reset"
	reset.custom_minimum_size = Vector2(100, 44)
	train_bar.add_child(reset)


## The dummy's character: the next one, and a fresh start against it.
func _cycle_who() -> void:
	var i := (Moves.ORDER.find(str(train_bar.get_meta("who", HomeScreen.fighter))) + 1) % Moves.ORDER.size()
	train_bar.set_meta("who", Moves.ORDER[i])
	(train_bar.get_node("DummyWho") as Button).text = "vs " + str(Moves.stats(Moves.ORDER[i])["name"])
	if training and phase in ["pick", "wait"]:
		start_local(1, "ffa", setup_colour, true)


func _cycle_dummy() -> void:
	var i := (Dummy.MODES.find(str(train_bar.get_meta("mode", "Stand"))) + 1) % Dummy.MODES.size()
	set_dummy(str(Dummy.MODES[i]))


## What the dummy does from its next pick.
func set_dummy(mode: String) -> void:
	train_bar.set_meta("mode", mode)
	(train_bar.get_node("DummyMode") as Button).text = "Dummy: " + mode
	if bots.has(1) and bots[1] is Dummy:
		(bots[1] as Dummy).mode = mode


## Back where you both started (the dummy's setting kept).
func reset_training() -> void:
	if training and phase in ["pick", "wait"]:
		start_local(1, "ffa", setup_colour, true)


## Training: once a combo's over, both of you are back to full health; your meter stays full; the dummy only bursts
## when it's fighting.
func _refill() -> void:
	for f in sim.fighters:
		if f.stun == 0 and f.blockstun == 0 and f.down == 0 and f.splat == 0 and f.restand == 0 and f.hp < f.max_hp:
			f.hp = f.max_hp
			f.combo_over()
	sim.fighters[me].meter = Sim.METER_MAX
	if bots.has(1) and bots[1] is Dummy and (bots[1] as Dummy).mode != "Fight":
		sim.fighters[1].burst = 0
	_lag.clear()
	_update_cards()


## Recording the match to save (02:15): its start now, each turn's picks, a jump to the host's state online.
func _rec_begin() -> void:
	if training:   # (training isn't kept as a replay)
		_rec = {}
		return
	_rec = {"v": Version.TAG, "when": int(Time.get_unix_time_from_system()), "me": me, "mode": sim.mode,
		"names": sim.fighters.map(func(f: Fighter) -> String: return f.name),
		"colours": sim.fighters.map(func(f: Fighter) -> String: return stage.colour_of(f.id).to_html(false)),
		"outlines": sim.fighters.map(func(f: Fighter) -> String:
			return (stage.outlines[f.id] if f.id < stage.outlines.size() else Stick.INK).to_html(false)),
		"trails": sim.fighters.map(func(f: Fighter) -> String:
			return str(stage.trails[f.id]) if f.id < stage.trails.size() else "None"),
		"start": NetMatch.wire(sim.to_dict()), "turns": []}
	_rec_saved = false


func _rec_turn(t: int, picks: Dictionary) -> void:
	if not _rec.is_empty() and not _replaying:
		(_rec["turns"] as Array).append({"t": t, "p": NetMatch.wire(picks)})


func _rec_jump(snap: Dictionary) -> void:
	if not _rec.is_empty() and not _replaying:
		(_rec["turns"] as Array).append({"t": int(snap.get("tick", 0)), "s": snap.duplicate(true)})


## The match over: saved (once), with how it ended - unless it never got going, or it's a replay being watched.
func _rec_save(result: String) -> void:
	if _rec.is_empty() or _rec_saved or _saved_replay or (_rec["turns"] as Array).is_empty():
		return
	_rec["result"] = result
	Replays.save(_rec)
	_rec_saved = true


## A saved replay from the home screen: the match played again from its picks, then watched.
func watch_saved(path: String) -> void:
	var rec := Replays.load_rec(path)
	if rec.is_empty() or not rec.has("start"):
		return
	_demo = null
	bots.clear()
	net_match = null
	var built := Replays.rebuild(rec)
	sim = Sim.from_dict(rec["start"])
	me = int(rec.get("me", 0))
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	stage.palette = (rec.get("colours", []) as Array).map(func(c: String) -> Color: return Color(c))
	stage.outlines = (rec.get("outlines", []) as Array).map(func(c: String) -> Color: return Color(c))
	stage.trails = rec.get("trails", [])
	stage.you = me
	stage.half = sim.half
	stage.ceiling = sim.ceiling
	stage.time_scale = speed
	_lag.clear()
	_history.clear()
	home.visible = false
	_build_cards()
	_replay_log = built[0]
	sim = built[1]
	_saved_replay = true
	_rec = {}
	(over_panel.find_child("Result", true, false) as Label).text = str(rec.get("result", ""))
	(over_panel.find_child("Rematch", true, false) as Button).visible = false
	(over_panel.find_child("Menu", true, false) as Button).text = "Menu"
	phase = "over"
	watch_replay()


## Undo (against bots only): back to your last pick - the match as it was, everyone's ghosts and cards with it.
func undo() -> void:
	if net_match != null or _history.is_empty() or phase != "pick":
		return
	sim = Sim.from_dict(_history.pop_back())
	_replay_log = _replay_log.filter(func(s: Dictionary) -> bool: return int(s["first"]) <= sim.tick)
	if not _rec.is_empty():   # (and out of the saved one)
		_rec["turns"] = (_rec["turns"] as Array).filter(func(x: Dictionary) -> bool: return int(x.get("t", 0)) < sim.tick)
	pick.close()
	stage.fx.clear()
	stage.show_tick(sim.record(), [], sim.record_shots())
	_update_cards()
	_next()


func can_undo() -> bool:
	return net_match == null and not _history.is_empty()


## The line over the stage on your turn, with the seconds left.
func _banner() -> void:
	banner.text = "%s  ·  %d" % [_ask, ceili(_turn_left)]


func _commit(mine: Dictionary) -> void:
	if net_match != null:   # (online: the pick goes to the host; the turn plays when everyone's is in)
		pick.close()
		_stage_band()
		stage.deciding = []
		stage.advantage = {}
		phase = "wait"
		banner.text = "Waiting for the others..."
		net_match.submit(me, mine if not mine.is_empty() else {"move": "hold"}, sim.tick)
		return
	if not auto_me and sim.deciders().has(me):   # (Undo: the match as it was before this pick)
		_history.append(sim.to_dict())
		if _history.size() > 40:
			_history.pop_front()
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
	stage.advantage = {}
	_rec_turn(sim.tick, picks)
	sim.apply(picks)
	var seg := sim.run_segment()
	_frames = seg["frames"]
	_events = seg["events"]
	_shots = seg.get("shots", [])
	_first_tick = int(seg["end_tick"]) - _frames.size() + 1
	_replay_log.append({"frames": _frames, "events": _events, "shots": _shots, "first": _first_tick})
	_play_pos = 0.0
	_shown = -1
	phase = "play"
	banner.text = ""


func _process(delta: float) -> void:
	_post()
	sfx.quiet = phase == "menu"   # (the demo behind the home screen plays silently)
	var pred := _predicted()   # (the orange on the cards follows the picks as they change)
	if pred != _pred:
		_pred = pred
		_update_cards()
	clock.visible = phase != "menu" and sim != null
	if clock.visible:
		var left := maxi(0, sim.round_len - (_first_tick + maxi(_shown, 0) if phase == "play" else sim.tick))
		clock.text = "⏱ ∞" if training else "⏱ %d" % ceili(left / 60.0)   # (training: no round to run out)
		clock.modulate = Color("#ff6b6b") if left < 600 else Color.WHITE
	if phase == "menu":
		_demo_step(delta)
		return
	if menu_panel.visible or how.visible:   # (the match menu or How to play is up: everything waits)
		return
	_drain(delta)
	if phase == "wait":
		return
	if phase == "pick":   # (the turn clock: when it runs out, what's picked goes in)
		_turn_left -= delta
		_banner()
		var whole := ceili(_turn_left)
		if whole <= 5 and whole >= 1 and whole != _tick_at:   # (the last five seconds tick)
			_tick_at = whole
			sfx.play("ui_tick", -4.0)
		if _turn_left <= 0.0:
			pick._confirm()
		return
	if phase != "play" or stage.fx.frozen():   # (a hit's freeze holds the playback a moment - pick 5)
		return
	_play_pos += delta * 60.0 * speed
	var i := mini(int(_play_pos), _frames.size() - 1)
	while _shown < i:
		_shown += 1
		var t := _first_tick + _shown
		stage.show_tick(_frames[_shown], _events.filter(func(e: Dictionary) -> bool: return int(e["t"]) == t),
				_shots[_shown] if _shown < _shots.size() else [])
		if stage.fx.frozen():
			_play_pos = float(_shown)
			break
	_update_cards(_frames[maxi(_shown, 0)] if not _frames.is_empty() else [])
	if not stage.fx.frozen() and int(_play_pos) >= _frames.size():
		if _replaying:   # (the replay: on to the next turn as it played)
			_replay_next()
			return
		stage.show_tick(sim.record(), [], sim.record_shots())
		_update_cards()
		if not _net_queue.is_empty():   # (online: a turn that came in meanwhile)
			phase = "wait"
			var q: Array = _net_queue.pop_front()
			_on_net_turn(int(q[0]), q[1], q[2])
			return
		_next()


## The after-pass: on only while the picture splits (supers, KOs, Bursts). (The pixel look went 02:19 "I think smooth
## works for us".)
func _post() -> void:
	var split := stage.fx.split
	post.visible = split > 0.01
	if not post.visible:
		return
	var mat := post.material as ShaderMaterial
	mat.set_shader_parameter("split", split)
	mat.set_shader_parameter("centre", stage.w2s(stage.fx.split_at) / get_viewport_rect().size)
	mat.set_shader_parameter("pixel", 1.0)


## The white chunk on each HP bar drains down to the HP once its moment's up.
func _drain(delta: float) -> void:
	if sim == null:
		return
	for f in sim.fighters:
		if not _lag.has(f.id) or f.id >= cards.get_child_count():
			continue
		var l: Array = _lag[f.id]
		if float(l[1]) > 0.0:
			l[1] = float(l[1]) - delta
		else:
			l[0] = maxf(float(l[2]), float(l[0]) - float(f.max_hp) * LAG_SPEED * delta)
		(cards.get_child(f.id).find_child("Lag", true, false) as ProgressBar).value = float(l[0])


## Play out what's left at once (the tests; a skip).
func finish_playback() -> void:
	if phase == "play":
		_play_pos = float(_frames.size())
		stage.quiet = true
		stage.fx.clear()
		_process(0.0)
		stage.quiet = false


func _finish() -> void:
	phase = "over"
	pick.close()
	var won := sim.winners()
	var text := "Everyone's down"
	if sim.timed_out():   # (the round ran out - the best share of HP left wins)
		text = "Time! It's a draw" if won.size() > 1 and sim.mode == "ffa" else text
	if won.has(me):
		text = "You win!" if won.size() == 1 else "Your team wins!"
	elif not won.is_empty():
		text = "%s wins" % sim.fighters[won[0]].name if sim.mode == "ffa" else "The other team wins"
	if sim.timed_out() and not text.begins_with("Time"):
		text = "Time! " + text
	(over_panel.find_child("Result", true, false) as Label).text = text
	_rec_save(text)
	(over_panel.find_child("Rematch", true, false) as Button).visible = net_match == null or me >= 0   # (online too)
	menu_btn.visible = false
	_menu_shown(false)
	(over_panel.find_child("Menu", true, false) as Button).text = "Back to lobby" if net_match != null else "Menu"
	over_panel.visible = true
	_layout()
	banner.text = ""
	leave_btn.visible = false


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	stage.time_scale = speed
	fast_btn.text = "%dx" % int(speed)


## "Turn your phone sideways": a phone outline tipping over, drawn (no glyphs), and the words.
class TurnPhone:
	extends Control

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 - Vector2(0, 40)
		var k := minf(size.x, size.y) / 900.0
		var t := fmod(Time.get_ticks_msec() / 1000.0, 2.4)
		var ang := -PI / 2.0 * clampf((t - 0.6) / 0.8, 0.0, 1.0)   # (upright, then it tips onto its side)
		var hw := 120.0 * k
		var hh := 220.0 * k
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)]:
			pts.append(c + p.rotated(ang))
		draw_polyline(pts, Color("#e8e8f0"), 10.0 * k, true)
		draw_circle(c + Vector2(0, hh - 34.0 * k).rotated(ang), 14.0 * k, Color("#e8e8f0"))
		var font := ThemeDB.fallback_font
		var fs := int(64.0 * k)
		var text := "Turn your phone sideways"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w / 2.0, c.y + hh + 140.0 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color("#e8e8f0"))
