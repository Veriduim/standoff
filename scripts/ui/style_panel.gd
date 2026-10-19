class_name StylePanel
extends Control
## Picking your look (02:28 "3"): the outline and the trail, with you dancing back and forth in the preview so the
## trail shows.

signal closed

var _preview: Preview
var _panel: PanelContainer
var _outline_btns: Array[Button] = []
var _trail_btns: Array[Button] = []
var colour := Color("#e5484d")


## The preview: you in your colour and outline, swaying side to side, leaving your trail.
class Preview:
	extends Control
	var colour := Color("#e5484d")
	var t := 0.0
	var bits: Array = []
	var _rng := RandomNumberGenerator.new()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		t += delta
		var at := _at()
		if int(t * 30.0) % 2 == 0 and Style.trail > 0:
			Fx.trail_bit_into(bits, Style.trail_name(Style.trail), at + Vector2(0, -34), colour, _rng)
		Fx.age_bits(bits, delta)
		queue_redraw()

	func _at() -> Vector2:
		return Vector2(size.x / 2.0 + sin(t * 2.2) * size.x * 0.3, size.y - 18.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0c10"))
		draw_line(Vector2(0, size.y - 16), Vector2(size.x, size.y - 16), Color("#ececf2"), 2.0)
		for b: Dictionary in bits:
			Fx.draw_trail(self, b["p"], b, 1.0)
		var face := 1.0 if cos(t * 2.2) >= 0.0 else -1.0
		var pose := Poses.get_pose("idle")
		var s := 0.95
		var ink := Style.outline_colour(Style.outline)
		var origin := _at()
		Stick.fan_at(self, Stick._place(pose, origin, s, face), "b", face, s, 0.55, colour, true, Stick.STEEL, ink)
		var pts := Stick.draw(self, pose, origin, s, face, colour, Stick.limb(s), Stick.head(s), true, ink)
		Stick.fan_at(self, pts, "f", face, s, 0.55, colour, true, Stick.STEEL, ink)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var st := Ui.box(Color("#15161ef8"), 18)
	st.set_content_margin_all(20)
	st.border_color = Color("#3a3d4d")
	st.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Ui.label("YOUR STYLE", 28, Color("#f2f2f7"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var done := Ui.button("Done", func() -> void: close(), 20)
	done.name = "StyleDone"
	done.custom_minimum_size = Vector2(120, 48)
	top.add_child(done)
	_preview = Preview.new()
	_preview.custom_minimum_size = Vector2(560, 170)
	v.add_child(_preview)
	v.add_child(Ui.label("OUTLINE", 15, Color("#8a8a9c")))
	var outs := HBoxContainer.new()
	outs.add_theme_constant_override("separation", 8)
	v.add_child(outs)
	for k in Style.OUTLINES.size():
		var i: int = k
		var b := Ui.button(str(Style.OUTLINES[k][0]), func() -> void: pick(i, Style.trail), 17)
		b.name = "Outline" + str(Style.OUTLINES[k][0])
		b.custom_minimum_size = Vector2(84, 44)
		outs.add_child(b)
		_outline_btns.append(b)
	v.add_child(Ui.label("TRAIL", 15, Color("#8a8a9c")))
	var trs := HBoxContainer.new()
	trs.add_theme_constant_override("separation", 8)
	v.add_child(trs)
	for k in Style.TRAILS.size():
		var i: int = k
		var b := Ui.button(str(Style.TRAILS[k]), func() -> void: pick(Style.outline, i), 17)
		b.name = "Trail" + str(Style.TRAILS[k])
		b.custom_minimum_size = Vector2(100, 44)
		trs.add_child(b)
		_trail_btns.append(b)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open(col: Color) -> void:
	Style.load_saved()
	colour = col
	_preview.colour = col
	_preview.bits.clear()
	_mark()
	visible = true
	_layout()


func pick(o: int, t: int) -> void:
	Style.set_mine(o, t)
	_preview.bits.clear()
	_mark()


func close() -> void:
	visible = false
	closed.emit()


## The picked ones lit (an outline swatch in its own colour).
func _mark() -> void:
	for k in _outline_btns.size():
		var b := _outline_btns[k]
		var c := Style.outline_colour(k)
		var box := Ui.box(Color("#1e2029"), 10)
		box.border_color = c if k != 0 else Color("#6b6b78")
		box.set_border_width_all(4 if k == Style.outline else 2)
		if k == Style.outline:
			box.bg_color = Color("#3a3d4d")
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, box)
	for k in _trail_btns.size():
		var on := k == Style.trail
		for s in ["normal", "hover", "pressed", "focus"]:
			_trail_btns[k].add_theme_stylebox_override(s, Ui.box(Color("#3a3d4d") if on else Color("#1e2029"), 10))


func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_panel.reset_size()
	_panel.position = (vp - _panel.size) / 2.0
