class_name Ui
extends RefCounted
## Shared look for the screens: labels, buttons and rounded boxes in the game's dark style.

const CARD_H := 64.0
const FONT := 22


static func label(text: String, fs := FONT, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, on: Callable, fs := FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(64, 52)
	b.pressed.connect(func() -> void: Sfx.ui("ui_click", -3.0))   # (every menu button clicks)
	b.pressed.connect(on)
	return b


static func box(col := Color("#1e2029ee"), radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	return s
