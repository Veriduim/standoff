class_name ReplayList
extends Control
## The saved replays, newest first (02:15 "When can I save replays??") - tap one to watch it.

signal picked(path: String)

var _box: VBoxContainer
var _panel: PanelContainer


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
	var t := Ui.label("REPLAYS", 28, Color("#f2f2f7"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var close := Ui.button("Close", func() -> void: visible = false, 20)
	close.name = "ReplaysClose"
	close.custom_minimum_size = Vector2(120, 48)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_box)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var all := Replays.paths()
	for path: String in all:
		var rec := Replays.load_rec(path)
		if rec.is_empty():
			continue
		var p := path
		var b := Ui.button(Replays.describe(rec), func() -> void:
			visible = false
			picked.emit(p), 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 54)
		b.clip_text = true
		_box.add_child(b)
	if _box.get_child_count() == 0:
		_box.add_child(Ui.label("No replays yet - every match you finish is kept here (the last %d)." % Replays.KEEP,
				19, Color("#a7a7b8")))
	visible = true
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_panel.size = Vector2(minf(820.0, vp.x - 40.0), vp.y - 40.0)
	_panel.position = (vp - _panel.size) / 2.0
