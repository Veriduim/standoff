class_name HomeScreen
extends Control
## The home screen (Timmy, 18 Oct 17:52: "make the home screen better"): a live bot match plays behind it (dimmed - the
## game shows itself), the title with two fighters squaring off, and a card to set up a fight: your colour, how many
## opponents, free-for-all or teams, FIGHT. Online is on its way.

signal fight(opponents: int, mode: String, colour: int)
signal online(colour: int)   ## the online lobbies (YOMI's Steam lobbies - Timmy 20:19)
signal help                  ## How to play (19 Oct 01:32)
signal replays               ## the saved replays (02:15 "When can I save replays??")
signal training(colour: int) ## training mode against a dummy (02:28)
signal style(colour: int)    ## your look - outline and trail (02:28 "3")

const VERSION := "v" + Version.TAG

const SETTINGS := "user://settings.cfg"

var colour := 0
var opponents := 3
var mode := "ffa"

var dim: ColorRect
var card: PanelContainer
var count_label: Label
var swatches: Array[Button] = []
var title: TitleArt


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	title = TitleArt.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	card = PanelContainer.new()
	var st := Ui.box(Color("#15161ee8"), 18)
	st.set_content_margin_all(16)
	st.border_color = Color("#2c2f3c")
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)
	var head := HBoxContainer.new()   # (YOUR COLOUR, and Style - the outline and trail - beside it)
	v.add_child(head)
	var hl := _heading("YOUR COLOUR")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var sty := Ui.button("Style", func() -> void: style.emit(colour), 15)
	sty.name = "Style"
	sty.custom_minimum_size = Vector2(84, 30)
	head.add_child(sty)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 10)
	v.add_child(sw)
	for i in StageView.COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.toggle_mode = true
		var on_pick := func() -> void: _set_colour(i)
		b.pressed.connect(on_pick)
		swatches.append(b)
		sw.add_child(b)
	v.add_child(_heading("OPPONENTS"))
	var step := HBoxContainer.new()
	step.add_theme_constant_override("separation", 12)
	v.add_child(step)
	step.add_child(_round("−", func() -> void: _set_count(opponents - 1)))
	count_label = Ui.label("3 bots", 26, Color("#f2f2f7"))
	count_label.custom_minimum_size = Vector2(140, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_child(count_label)
	step.add_child(_round("+", func() -> void: _set_count(opponents + 1)))
	v.add_child(_heading("MODE"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	v.add_child(modes)
	var group := ButtonGroup.new()
	for m: Array in [["Free-for-all", "ffa"], ["Teams", "teams"]]:
		var mid: String = m[1]
		var on_mode := func() -> void: mode = mid
		var b := Ui.button(str(m[0]), on_mode, 20)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = mid == mode
		b.custom_minimum_size = Vector2(160, 46)
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#3a3d4d"), 10))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#1e2029"), 10))
		modes.add_child(b)
	v.add_child(_heading("BOTS"))   # (02:10 "Lets do difficulty please" - in the LOOK row's place; that's bottom left)
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 6)
	v.add_child(levels)
	var level_group := ButtonGroup.new()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		Bot.chosen = clampi(int(cfg.get_value("home", "bots", 1)), 0, 2)
	for k in Bot.LEVELS.size():
		var lvl: int = k
		var b := Ui.button(str(Bot.LEVELS[k]), func() -> void: set_level(lvl), 20)
		b.name = "Bots" + str(Bot.LEVELS[k])
		b.toggle_mode = true
		b.button_group = level_group
		b.button_pressed = k == Bot.chosen
		b.custom_minimum_size = Vector2(105, 46)
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#3a3d4d"), 10))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#1e2029"), 10))
		levels.add_child(b)
	var go := Ui.button("FIGHT", func() -> void: fight.emit(opponents, mode, colour), 34)
	go.name = "Fight"
	go.custom_minimum_size = Vector2(0, 62)
	for s in ["normal", "hover", "focus"]:
		go.add_theme_stylebox_override(s, Ui.box(Color("#d63d3d"), 14))
	go.add_theme_stylebox_override("pressed", Ui.box(Color("#a82f2f"), 14))
	v.add_child(go)
	var lobbies := Ui.button("Online lobbies", func() -> void: online.emit(colour), 22)
	lobbies.name = "Online"
	lobbies.custom_minimum_size = Vector2(0, 50)
	for s in ["normal", "hover", "focus"]:
		lobbies.add_theme_stylebox_override(s, Ui.box(Color("#2b4f8a"), 12))
	v.add_child(lobbies)
	var snd := Ui.button(Sfx.label(), func() -> void: _toggle_sound(), 18)   # (19 Oct: sound on / off, kept)
	snd.name = "Sound"
	snd.custom_minimum_size = Vector2(150, 46)
	for s in ["normal", "hover", "focus"]:
		snd.add_theme_stylebox_override(s, Ui.box(Color("#1e2029e8"), 12))
	add_child(snd)
	var how := Ui.button("How to play", func() -> void: help.emit(), 18)
	how.name = "HowToPlay"
	how.custom_minimum_size = Vector2(150, 46)
	for s in ["normal", "hover", "focus"]:
		how.add_theme_stylebox_override(s, Ui.box(Color("#1e2029e8"), 12))
	add_child(how)
	var rep := Ui.button("Replays", func() -> void: replays.emit(), 18)
	rep.name = "Replays"
	for s in ["normal", "hover", "focus"]:
		rep.add_theme_stylebox_override(s, Ui.box(Color("#1e2029e8"), 12))
	add_child(rep)
	var train := Ui.button("Training", func() -> void: training.emit(colour), 18)
	train.name = "Training"
	for s in ["normal", "hover", "focus"]:
		train.add_theme_stylebox_override(s, Ui.box(Color("#2b6e4a"), 12))
	add_child(train)
	for b: Button in [snd, how, rep, train]:   # (four along the bottom - narrow enough to clear the card on 16:9)
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_constant_override("h_separation", 0)
		for look in ["normal", "hover", "focus", "pressed"]:
			var box := b.get_theme_stylebox(look)
			if box is StyleBoxFlat:
				(box as StyleBoxFlat).content_margin_left = 14
				(box as StyleBoxFlat).content_margin_right = 14
	var ver := Ui.label(VERSION + "  ·  the Dancer: her war fans and her Tempo", 15, Color("#6b6b78"))
	ver.name = "Version"
	add_child(ver)
	var saved := ConfigFile.new()   # (your colour, kept between plays - 21:37 "remember the last option we choice")
	_set_colour(int(saved.get_value("home", "colour", 0)) if saved.load(SETTINGS) == OK else 0)
	_set_count(3)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _heading(text: String) -> Label:
	return Ui.label(text, 15, Color("#8a8a9c"))


func _round(text: String, on: Callable) -> Button:
	var b := Ui.button(text, on, 30)
	b.custom_minimum_size = Vector2(50, 50)
	for s in ["normal", "hover"]:
		b.add_theme_stylebox_override(s, Ui.box(Color("#262833"), 29))
	b.add_theme_stylebox_override("pressed", Ui.box(Color("#3a3d4d"), 29))
	return b


func _set_colour(i: int) -> void:
	if i != colour:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("home", "colour", i)
		cfg.save(SETTINGS)
	colour = i
	for k in swatches.size():
		var c: Color = StageView.COLOURS[k]
		var st := Ui.box(c, 26)
		if k == i:
			st.border_color = Color.WHITE
			st.set_border_width_all(4)
		swatches[k].add_theme_stylebox_override("normal", st)
		swatches[k].add_theme_stylebox_override("hover", st)
		swatches[k].add_theme_stylebox_override("pressed", st)
		swatches[k].set_pressed_no_signal(k == i)
	title.colour = StageView.COLOURS[i]
	title.queue_redraw()


## Easy / Normal / Hard - the game's bots; saved.
func set_level(lvl: int) -> void:
	Bot.chosen = clampi(lvl, 0, 2)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("home", "bots", Bot.chosen)
	cfg.save(SETTINGS)


func _toggle_sound() -> void:
	Sfx.set_on(not Sfx.on)
	sync_sound()
	Sfx.ui("ui_click")


## The button shows what's saved (the ☰ menu can change it too).
func sync_sound() -> void:
	(get_node("Sound") as Button).text = Sfx.label()


func _set_count(n: int) -> void:
	opponents = clampi(n, 1, 5)
	count_label.text = "%d bot%s" % [opponents, "" if opponents == 1 else "s"]


func _layout() -> void:
	var vp := get_viewport_rect().size
	dim.size = vp
	card.reset_size()
	card.position = Vector2(vp.x - card.size.x - 40.0, (vp.y - card.size.y) / 2.0)
	title.position = Vector2(30, 0)
	title.size = Vector2(maxf(300.0, card.position.x - 60.0), vp.y)
	var ver := get_node("Version") as Label
	ver.position = Vector2(24, vp.y - 36)
	var snd := get_node("Sound") as Button
	var x := 24.0
	for n: String in ["Sound", "HowToPlay", "Replays", "Training"]:   # (side by side, each as wide as its words)
		var b := get_node(n) as Button
		b.reset_size()
		b.position = Vector2(x, vp.y - 92)
		x += b.size.x + 8.0



## The title: STANDOFF over two fighters squaring off - you (your colour) and a rival.
class TitleArt:
	extends Control
	var colour := Color("#e5484d")

	func _draw() -> void:
		var font := get_theme_default_font()
		var cx := size.x / 2.0
		var top := size.y * 0.08
		draw_string_outline(font, Vector2(0, top + 96), "STANDOFF", HORIZONTAL_ALIGNMENT_CENTER, size.x, 104, 14,
				Color("#0b0b0f"))
		draw_string(font, Vector2(0, top + 96), "STANDOFF", HORIZONTAL_ALIGNMENT_CENTER, size.x, 104, Color("#f2f2f7"))
		var bar_w := minf(size.x * 0.7, 520.0)
		draw_rect(Rect2(cx - bar_w / 2.0, top + 118, bar_w, 6), colour)
		draw_string(font, Vector2(0, top + 160), "Up to six fighters. Everyone moves at once.", HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 22, Color("#b8b8c8"))
		# (no drawn fighters here - the live match behind the screen is the picture)
