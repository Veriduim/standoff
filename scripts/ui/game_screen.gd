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
const PIXEL := 3.0         ## the pixel look's block size, in game pixels

var sim: Sim
var bots := {}             ## fighter id -> Bot
var me := 0
var phase := "menu"        ## menu | pick | play | over
var speed := 1.0
var setup_count := 3       ## opponents
var setup_mode := "ffa"
var setup_colour := 0      ## your colour (StageView.COLOURS) - the bots take the others
var auto_me := false       ## a bot plays you too (the tests; a demo)

var stage: StageView
var sfx: Sfx                 ## the sounds (stage events, the menus, your turn)
var _tick_at := -1           ## the last whole second the turn clock ticked on
var pick: PickPanel
var cards: HBoxContainer
var banner: Label
var home: HomeScreen
var lobby: LobbyScreen
var net_match: NetMatch      ## an online match (null = this phone against bots)
var _net_queue: Array = []   ## turns that came in while one was still playing - played next, in order
var leave_btn: Button
var clock: Label
var post: ColorRect
var pixel_size := 1.0        ## the after-pass's block size now (screen px; 1 = smooth)
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
	post = ColorRect.new()   # (over the stage, under everything else: the colour split, the pixel look)
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
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_start()
	if HowToPlay.auto and not HowToPlay.seen():   # (the first launch: the cards once, by themselves)
		how.open()


func _layout() -> void:
	var vp := get_viewport_rect().size
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
	stage.view_bottom = vp.y - (PickPanel.BAR_H + 10.0 if picking else 24.0)
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
	var again := Ui.button("Rematch", func() -> void: start_local(setup_count, setup_mode, setup_colour), 22)
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
	for i in 4:
		players.append({"name": "", "character": "dancer"})
	_demo = Sim.create(players, "ffa")
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
func start_local(opponents: int, mode: String, colour := 0) -> void:
	setup_count = opponents
	setup_mode = mode
	setup_colour = colour
	_demo = null
	var players := [{"name": "You", "character": "dancer", "team": 0}]
	for i in opponents:
		players.append({"name": "Bot %d" % (i + 1), "character": "dancer", "team": (i + 1) % 2})
	if mode == "teams" and opponents < 2:
		mode = "ffa"
	sim = Sim.create(players, mode)   # (the Dancer as she is: Fans + Tempo - 23:31)
	menu_btn.visible = true
	_menu_shown(false)
	_history.clear()
	_replay_log.clear()
	stage.ceiling = sim.ceiling
	bots.clear()
	for i in range(1, players.size()):
		bots[i] = Bot.new(i * 7 + 3)
	me = 0
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	var palette: Array = [StageView.COLOURS[colour]]
	for c: Color in StageView.COLOURS:
		if c != StageView.COLOURS[colour]:
			palette.append(c)
	stage.palette = palette
	stage.you = me
	stage.time_scale = speed
	stage.show_tick(sim.record(), [], sim.record_shots())
	_lag.clear()
	home.visible = false
	fast_btn.visible = true
	over_panel.visible = false
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
		var hpb := _hp_bar(stage.colour_of(f.id))
		v.add_child(hpb)
		var mb := _bar("Meter", Color("#ffd166"), 6)
		for k in [1, 2]:   # (meter in three bars: two dividers)
			var cut := ColorRect.new()
			cut.color = Color("#0e0f14")
			cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mb.add_child(cut)
			cut.anchor_left = k / 3.0
			cut.anchor_right = k / 3.0
			cut.anchor_bottom = 1.0
			cut.offset_left = -1.0
			cut.offset_right = 1.0
		v.add_child(mb)
		v.add_child(_bar("Burst", Color("#6fd3ff"), 4))
		cards.add_child(p)
		if mirror and f.id == 1:
			for b in p.find_children("*", "ProgressBar", true, false):
				(b as ProgressBar).fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_update_cards()


## HP in their colour over a white chunk: the HP just lost shows white a moment, then drains away (pick 10).
func _hp_bar(col: Color) -> Control:
	var stack := Control.new()
	stack.name = "HPStack"
	stack.custom_minimum_size = Vector2(0, 12)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lag := _bar("Lag", Color(1, 1, 1, 0.85), 12)
	var hp := _bar("HP", col, 12)
	hp.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	for b: ProgressBar in [lag, hp]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(b)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		var mb := card.find_child("Meter", true, false) as ProgressBar
		mb.max_value = Sim.METER_MAX
		mb.value = meter
		var bb := card.find_child("Burst", true, false) as ProgressBar   # (the Burst gauge - bright when it's full)
		bb.max_value = Sim.BURST_FULL
		bb.value = float(rec[f.id][8]) if not rec.is_empty() and rec[f.id].size() > 8 else float(f.burst)
		bb.modulate = Color(1.6, 1.6, 1.6) if bb.value >= Sim.BURST_FULL else Color(0.75, 0.75, 0.75)
		var fcs := int(rec[f.id][9]) if not rec.is_empty() and rec[f.id].size() > 9 else f.fc
		var airs := int(rec[f.id][10]) if not rec.is_empty() and rec[f.id].size() > 10 else Sim.AIR_OPTIONS - f.air_moves
		var ex := card.find_child("Extras", true, false) as RichTextLabel
		var text := "[right]%s[color=#46d17a]%s[/color][color=#3a3d4d]%s[/color] [color=#e8e8f0]%s[/color][color=#3a3d4d]%s[/color][/right]" \
				% [_trial_marks(f, rec[f.id] if not rec.is_empty() else []), "✕".repeat(fcs), "✕".repeat(Sim.FC_MAX - fcs),
				"●".repeat(airs), "●".repeat(Sim.AIR_OPTIONS - airs)]
		if ex.text != text:
			ex.text = text
		card.modulate = Color(1, 1, 1, 0.45) if hp <= 0.0 else Color.WHITE


## The x-factors on trial on a card: the form (Flow / Snap / Floor), the beats (pink), the fans in hand (gold).
func _trial_marks(f: Fighter, row: Array) -> String:
	var out := ""
	var has := row.size() > 16
	if sim.xf.has("forms"):
		var fm := int(row[14]) if has else maxi(0, Sim.FORMS.find(f.form))
		out += "[color=#9fd8ff]%s[/color] " % ["Flow", "Snap", "Floor"][fm]
	if sim.xf.has("tempo"):
		var tp := int(row[15]) if has else f.tempo
		out += "[color=#ff7ab6]%s[/color][color=#3a3d4d]%s[/color] " % ["▮".repeat(tp), "▮".repeat(Sim.TEMPO_MAX - tp)]
	if sim.xf.has("fans"):
		var fn := int(row[16]) if has else f.fans
		out += "[color=#ffd23f]%s[/color][color=#3a3d4d]%s[/color] " % ["◆".repeat(fn), "◆".repeat(Sim.FANS_MAX - fn)]
	return out


## Online: a match from the lobby - this phone's copy of it, from the host's start (or, watching, from where it is).
func start_online(nm: NetMatch) -> void:
	net_match = nm
	_net_queue.clear()
	if nm.get_parent() == null:
		add_child(nm)
	nm.turn.connect(_on_net_turn)
	nm.ended.connect(_on_net_end)
	_demo = null
	bots.clear()
	sim = Sim.from_dict(nm.start_snap)
	_replay_log.clear()
	me = nm.mine
	stage.setup(sim.fighters.map(func(f: Fighter) -> String: return f.character),
			sim.fighters.map(func(f: Fighter) -> String: return f.name))
	stage.palette = nm.seats.map(func(s: Dictionary) -> Color:
		return StageView.COLOURS[int(s.get("colour", 0)) % StageView.COLOURS.size()])
	stage.you = me
	stage.half = sim.half
	stage.ceiling = sim.ceiling
	stage.time_scale = speed
	stage.show_tick(sim.record(), [], sim.record_shots())
	_lag.clear()
	home.visible = false
	lobby.visible = false
	fast_btn.visible = true
	menu_btn.visible = true
	over_panel.visible = false
	_build_cards()
	_next()


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
			stage.show_tick(sim.record(), [], sim.record_shots())
			_update_cards()
		return
	pick.close()
	_stage_band()
	stage.deciding = []
	stage.advantage = {}
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
	(over_panel.find_child("Rematch", true, false) as Button).visible = false
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
			start_local(setup_count, setup_mode, setup_colour)
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


## Undo (against bots only): back to your last pick - the match as it was, everyone's ghosts and cards with it.
func undo() -> void:
	if net_match != null or _history.is_empty() or phase != "pick":
		return
	sim = Sim.from_dict(_history.pop_back())
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
	clock.visible = phase != "menu" and sim != null
	if clock.visible:
		var left := maxi(0, sim.round_len - (_first_tick + maxi(_shown, 0) if phase == "play" else sim.tick))
		clock.text = "⏱ %d" % ceili(left / 60.0)
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


## The after-pass: on only while the picture splits (supers, KOs, Bursts) or with the pixel look switched on.
func _post() -> void:
	var split := stage.fx.split
	post.visible = split > 0.01 or home.pixel
	if not post.visible:
		return
	var mat := post.material as ShaderMaterial
	mat.set_shader_parameter("split", split)
	mat.set_shader_parameter("centre", stage.w2s(stage.fx.split_at) / get_viewport_rect().size)
	var k := maxf(1.0, get_viewport().get_final_transform().get_scale().y)   # (the phone's pixels per game pixel)
	pixel_size = PIXEL * k if home.pixel else 1.0
	mat.set_shader_parameter("pixel", pixel_size)


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
	(over_panel.find_child("Rematch", true, false) as Button).visible = net_match == null
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
