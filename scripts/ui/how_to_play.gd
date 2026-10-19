class_name HowToPlay
extends Control
## How to play (Timmy 19 Oct 01:32, from my list: "2 makes sense" - "YOMI's 'everyone picks at once, then watch' idea
## confuses new players"): a few cards to tap through, big type. Shown once on the first launch, and any time from the
## home screen and the ☰ menu.

signal closed

const SETTINGS := "user://settings.cfg"
## [title, text, the move whose pose illustrates it]
const PAGES := [
	["Everyone moves at once", "Each turn, everyone picks a move in secret. When everyone has picked, the turn plays " +
		"out - then you all pick again. Winning is about guessing what they'll do.", "straight"],
	["Pick a move", "The tabs down the left: Attack, Special, Super, Movement, Defense. Tap a tab, then a move - your " +
		"card at the bottom shows it. The arrows aim it; tap the lit arrow again for no direction.", "fan"],
	["The move icons", "Each tab's moves go fastest first - the f number is the frame it hits. The badges: ✊ beats " +
		"blocks, ⚡ better with initiative (the enemy was choosing too), 👻 dodges, 🔻 hits low, 💥 guard break, " +
		"🎯 a projectile.", "grab"],
	["Watch the ghost", "The faded figures show what happens if you pick that. \"Ready in 12\" means you can act " +
		"again 12 frames later - green if you're first. Guess an enemy's move with their tabs on the right, and their " +
		"ghost plays against yours.", "dash"],
	["Lock it in", "Press Confirm. If the clock runs out, what you've picked goes in. Against bots, Undo (top right) " +
		"takes a turn back.", "taunt"],
	["Getting hit", "Stuck in a combo? Pick Hold and tap an arrow to lean away. When your Burst bar is full, BURST " +
		"throws everyone off you. Block: ↑ high, ↓ low.", "burst"],
	["The Dancer", "A zoner with two war fans. Thrown, they fly back to her hand; Fan Ward leaves one hanging as a " +
		"trap, and Recall pulls them home through anyone in the way. Fan Gust blows rushers and shots off her. Hits " +
		"at the fan's edge hurt most; point blank she's weaker - keep them out there.", "fanward"],
]

static var auto := true            ## open by itself on the first launch (off for the tests and the dev tools)

var page := 0
var _panel: PanelContainer
var _icon: MoveIcon
var _title: Label
var _text: Label
var _count: Label
var _back: Button
var _next: Button


static func seen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SETTINGS) == OK and bool(cfg.get_value("help", "seen", false))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # (nothing behind it takes a tap while it's up)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var st := Ui.box(Color("#15161ef8"), 18)
	st.set_content_margin_all(24)
	st.border_color = Color("#3a3d4d")
	st.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_panel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)
	_icon = MoveIcon.make("dancer", "straight", Color("#e5484d"), func() -> void: pass)
	_icon.custom_minimum_size = Vector2(130, 170)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	h.add_child(words)
	_title = Ui.label("", 32, Color("#f2f2f7"))
	words.add_child(_title)
	_text = Ui.label("", 22, Color("#d0d0dc"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 0)
	words.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var skip := Ui.button("Skip", func() -> void: close(), 20)
	skip.name = "HelpSkip"
	skip.custom_minimum_size = Vector2(110, 52)
	row.add_child(skip)
	_count = Ui.label("", 20, Color("#8a8a9c"))
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_count)
	_back = Ui.button("Back", func() -> void: show_page(page - 1), 20)
	_back.custom_minimum_size = Vector2(110, 52)
	row.add_child(_back)
	_next = Ui.button("Next", func() -> void: next(), 22)
	_next.name = "HelpNext"
	_next.custom_minimum_size = Vector2(150, 52)
	for k in ["normal", "hover", "focus"]:
		_next.add_theme_stylebox_override(k, Ui.box(Color("#2b4f8a"), 12))
	row.add_child(_next)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open() -> void:
	visible = true
	show_page(0)


func next() -> void:
	if page >= PAGES.size() - 1:
		close()
	else:
		show_page(page + 1)


func show_page(i: int) -> void:
	page = clampi(i, 0, PAGES.size() - 1)
	var p: Array = PAGES[page]
	_title.text = str(p[0])
	_text.text = str(p[1])
	_icon.move_id = str(p[2])
	_icon.colour = MoveIcon.tab_colour("dancer", str(p[2]))
	_icon.queue_redraw()
	_count.text = "%d / %d" % [page + 1, PAGES.size()]
	_back.disabled = page == 0
	_next.text = "Let's go" if page == PAGES.size() - 1 else "Next"
	_layout()


## Closed (done or skipped): it won't open by itself again.
func close() -> void:
	visible = false
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("help", "seen", true)
	cfg.save(SETTINGS)
	closed.emit()


func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_text.custom_minimum_size.x = minf(560.0, vp.x - 280.0)
	_panel.reset_size()
	_panel.position = (vp - _panel.size) / 2.0
