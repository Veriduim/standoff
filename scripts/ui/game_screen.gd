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
var pick: PickPanel
var cards: HBoxContainer
var banner: Label
var home: HomeScreen
var clock: Label
var post: ColorRect
var pixel_size := 1.0        ## the after-pass's block size now (screen px; 1 = smooth)
var over_panel: PanelContainer
var fast_btn: Button

var _frames: Array = []
var _events: Array = []
var _first_tick := 0
var _play_pos := 0.0
var _shown := -1
var _lag := {}               ## fighter id -> [HP shown by the white chunk, seconds before it drains, HP now]
var _turn_left := 0.0        ## seconds left on your turn
var _ask := ""               ## what your turn asks (the banner)
var _demo: Sim               ## the bot match behind the home screen
var _demo_bots: Array = []
var _demo_frames: Array = []
var _demo_events: Array = []
var _demo_first := 0
var _demo_pos := 0.0
var _demo_shown := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # (taps on the stage reach StageView's _unhandled_input)
	stage = StageView.new()
	add_child(stage)
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
	pick.confirmed.connect(func(c: Dictionary) -> void:
		if phase == "pick":
			_commit(c))
	_build_over()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_start()


func _layout() -> void:
	var vp := get_viewport_rect().size
	banner.position = Vector2(96, Ui.CARD_H + 16)
	banner.size = Vector2(vp.x - 96.0 - PickPanel.TAB_W - 20.0, 30)
	fast_btn.position = Vector2(10, Ui.CARD_H + 8)
	fast_btn.size = Vector2(70, 44)
	clock.position = Vector2(vp.x - 230.0, Ui.CARD_H + 14)
	clock.size = Vector2(120, 30)
	post.position = Vector2.ZERO   # (sized by hand - this screen's own rect isn't the viewport's)
	post.size = vp
	_stage_band()
	over_panel.position = (vp - over_panel.size) / 2.0


## The stage keeps to the screen the panels leave: under the cards, above the bar and left of the tabs on your turn.
func _stage_band() -> void:
	var vp := get_viewport_rect().size
	var picking := pick != null and pick.visible
	stage.view_top = Ui.CARD_H + 48.0 if phase != "menu" else 40.0
	stage.view_bottom = vp.y - (PickPanel.BAR_H + 10.0 if picking else 24.0)
	stage.view_left = 0.0
	stage.view_right = vp.x - (PickPanel.TAB_W + 12.0 if picking else 0.0)


# ---------- the start and end ----------

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
	h.add_child(Ui.button("Rematch", func() -> void: start_local(setup_count, setup_mode, setup_colour)))
	h.add_child(Ui.button("Menu", func() -> void: _show_start()))
	over_panel.visible = false


func _show_start() -> void:
	phase = "menu"
	home.visible = true
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
	stage.show_tick(_demo.record())
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
		_demo_first = int(seg["end_tick"]) - _demo_frames.size() + 1
		_demo_pos = 0.0
		_demo_shown = -1
	_demo_pos += delta * 60.0
	var upto := mini(int(_demo_pos), _demo_frames.size() - 1)
	while _demo_shown < upto:
		_demo_shown += 1
		var t := _demo_first + _demo_shown
		stage.show_tick(_demo_frames[_demo_shown], _demo_events.filter(func(e: Dictionary) -> bool: return int(e["t"]) == t))
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
	sim = Sim.create(players, mode)
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
	stage.show_tick(sim.record())
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
	var w := minf(206.0, (vp.x - 16.0 - 6.0 * (sim.fighters.size() - 1)) / sim.fighters.size())
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
		extras.add_theme_font_size_override("normal_font_size", 13)
		extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(extras)
		v.add_child(_hp_bar(stage.colour_of(f.id)))
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
		var text := "[right][color=#46d17a]%s[/color][color=#3a3d4d]%s[/color] [color=#e8e8f0]%s[/color][color=#3a3d4d]%s[/color][/right]" \
				% ["✕".repeat(fcs), "✕".repeat(Sim.FC_MAX - fcs), "●".repeat(airs), "●".repeat(Sim.AIR_OPTIONS - airs)]
		if ex.text != text:
			ex.text = text
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
		_turn_left = TURN_SECONDS
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
			if sim.enemies(f, g) and not g.actionable() and not sim.interruptible(g) and g.busy() > 0:
				adv[g.id] = g.busy()
		stage.advantage = adv
		pick.open(sim, me, stage)
		_stage_band()
	else:
		_commit({})


## The line over the stage on your turn, with the seconds left.
func _banner() -> void:
	banner.text = "%s  ·  %d" % [_ask, ceili(_turn_left)]


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
	stage.advantage = {}
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
	_post()
	clock.visible = phase != "menu" and sim != null
	if clock.visible:
		var left := maxi(0, Sim.ROUND_TICKS - (_first_tick + maxi(_shown, 0) if phase == "play" else sim.tick))
		clock.text = "⏱ %d" % ceili(left / 60.0)
		clock.modulate = Color("#ff6b6b") if left < 600 else Color.WHITE
	if phase == "menu":
		_demo_step(delta)
		return
	_drain(delta)
	if phase == "pick":   # (the turn clock: when it runs out, what's picked goes in)
		_turn_left -= delta
		_banner()
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
		stage.show_tick(_frames[_shown], _events.filter(func(e: Dictionary) -> bool: return int(e["t"]) == t))
		if stage.fx.frozen():
			_play_pos = float(_shown)
			break
	_update_cards(_frames[maxi(_shown, 0)] if not _frames.is_empty() else [])
	if not stage.fx.frozen() and int(_play_pos) >= _frames.size():
		stage.show_tick(sim.record())
		_update_cards()
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
	over_panel.visible = true
	banner.text = ""


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	stage.time_scale = speed
	fast_btn.text = "%dx" % int(speed)
