class_name HomeScreen
extends Control
## The home screen (Timmy, 18 Oct 17:52: "make the home screen better"): a live bot match plays behind it (dimmed - the
## game shows itself), the title with two fighters squaring off, and a card to set up a fight: your colour, how many
## opponents, free-for-all or teams, FIGHT. Online is on its way.

signal fight(opponents: int, mode: String, colour: int)
signal online(colour: int)   ## the online lobbies (YOMI's Steam lobbies - Timmy 20:19)

const VERSION := "v" + Version.TAG

const SETTINGS := "user://settings.cfg"

var colour := 0
var opponents := 3
var mode := "ffa"
var pixel := false   ## the pixel look (Timmy 18:35 - pick 2 from the YOMI study, as a switch); kept between plays
## The Dancer's x-factors on trial (Timmy 21:14 "Can we try the fans, temp and dance forms? Maybe combine two of them
## honestly"; 21:17 "We may pick one or a combination of two"): switched on here, any mix; kept between plays.
var xf := {}
var xf_panel: PanelContainer

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
	st.set_content_margin_all(22)
	st.border_color = Color("#2c2f3c")
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(_heading("YOUR COLOUR"))
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 10)
	v.add_child(sw)
	for i in StageView.COLOURS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
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
		b.custom_minimum_size = Vector2(170, 52)
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#3a3d4d"), 10))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#1e2029"), 10))
		modes.add_child(b)
	v.add_child(_heading("LOOK"))
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 8)
	v.add_child(looks)
	var look_group := ButtonGroup.new()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		pixel = bool(cfg.get_value("look", "pixel", false))
	for l: Array in [["Smooth", false], ["Pixel", true]]:
		var px: bool = l[1]
		var on_look := func() -> void: set_pixel(px)
		var b := Ui.button(str(l[0]), on_look, 20)
		b.name = "Look" + str(l[0])
		b.toggle_mode = true
		b.button_group = look_group
		b.button_pressed = px == pixel
		b.custom_minimum_size = Vector2(170, 52)
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#3a3d4d"), 10))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#1e2029"), 10))
		looks.add_child(b)
	var go := Ui.button("FIGHT", func() -> void: fight.emit(opponents, mode, colour), 34)
	go.name = "Fight"
	go.custom_minimum_size = Vector2(0, 76)
	for s in ["normal", "hover", "focus"]:
		go.add_theme_stylebox_override(s, Ui.box(Color("#d63d3d"), 14))
	go.add_theme_stylebox_override("pressed", Ui.box(Color("#a82f2f"), 14))
	v.add_child(go)
	var lobbies := Ui.button("Online lobbies", func() -> void: online.emit(colour), 22)
	lobbies.name = "Online"
	lobbies.custom_minimum_size = Vector2(0, 56)
	for s in ["normal", "hover", "focus"]:
		lobbies.add_theme_stylebox_override(s, Ui.box(Color("#2b4f8a"), 12))
	v.add_child(lobbies)
	var ver := Ui.label(VERSION + "  ·  one fighter for now: the Dancer", 15, Color("#6b6b78"))
	ver.name = "Version"
	add_child(ver)
	_build_xf()
	var saved := ConfigFile.new()   # (your colour, kept between plays - 21:37 "remember the last option we choice")
	_set_colour(int(saved.get_value("home", "colour", 0)) if saved.load(SETTINGS) == OK else 0)
	_set_count(3)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Bottom left: DANCER'S X-FACTOR (trying out) - Fans / Tempo / Forms, each on or off.
func _build_xf() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		xf = Sim.xf_set(str(cfg.get_value("trial", "xf", "")))
	xf_panel = PanelContainer.new()
	var st := Ui.box(Color("#15161ee0"), 14)
	st.set_content_margin_all(14)
	st.border_color = Color("#2c2f3c")
	st.set_border_width_all(2)
	xf_panel.add_theme_stylebox_override("panel", st)
	add_child(xf_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	xf_panel.add_child(v)
	v.add_child(_heading("DANCER'S X-FACTOR  ·  TRYING OUT (ONE, OR TWO TOGETHER)"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var tips := {"fans": "Fans", "tempo": "Tempo", "forms": "Forms"}
	for k: String in Sim.XF:
		var key := k
		var b := Ui.button(str(tips[k]), func() -> void: _toggle_xf(key), 20)
		b.name = "XF" + str(tips[k])
		b.toggle_mode = true
		b.button_pressed = xf.has(k)
		b.custom_minimum_size = Vector2(140, 50)
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#7a3d8f"), 10))
		b.add_theme_stylebox_override("hover_pressed", Ui.box(Color("#8c4aa3"), 10))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#1e2029"), 10))
		row.add_child(b)


func _toggle_xf(k: String) -> void:
	if xf.has(k):
		xf.erase(k)
	else:
		xf[k] = true
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("trial", "xf", xf_rule())
	cfg.save(SETTINGS)


## The rules' "xf": "fans,tempo" (in Sim.XF's order).
func xf_rule() -> String:
	return ",".join(PackedStringArray(Sim.XF.filter(func(k: String) -> bool: return xf.has(k))))


func _heading(text: String) -> Label:
	return Ui.label(text, 15, Color("#8a8a9c"))


func _round(text: String, on: Callable) -> Button:
	var b := Ui.button(text, on, 30)
	b.custom_minimum_size = Vector2(58, 58)
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


## Smooth or pixel - saved, so the game opens the way it was left.
func set_pixel(on: bool) -> void:
	pixel = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("look", "pixel", on)
	cfg.save(SETTINGS)


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
	if xf_panel != null:
		xf_panel.reset_size()
		xf_panel.position = Vector2(30, vp.y - xf_panel.size.y - 52)


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
