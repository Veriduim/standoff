class_name Ui
extends RefCounted
## Shared look for the screens: labels, buttons and rounded boxes in the game's dark style.

const CARD_H := 72.0   ## the top band: the cards (02:01 - a little taller for clearer bars)
const FONT := 22
## The icons behind the game's font (19 Oct 13:58 - made for the web version, kept for Android: the same icons on every
## phone): just the ones the game's text uses, made by tools/icon_fonts.py from Noto fonts (SIL OFL, licences beside).
const ICON_FONTS := ["res://assets/fonts/icons_emoji.ttf", "res://assets/fonts/icons_symbols.ttf",
	"res://assets/fonts/icons_arrows.ttf"]

## The icon fonts behind the game's own (once, at boot - main.gd; the same icons on every phone, Android included).
static func add_icon_fonts() -> void:
	for f: Font in [ThemeDB.fallback_font, ThemeDB.get_default_theme().default_font]:
		if f == null:
			continue
		var all: Array[Font] = []
		all.assign(f.fallbacks)
		for path: String in ICON_FONTS:
			var icon := load(path) as Font
			if icon != null and not all.has(icon):
				all.append(icon)
		f.fallbacks = all


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
