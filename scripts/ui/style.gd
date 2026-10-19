class_name Style
extends RefCounted
## Your look beyond your colour (Timmy 19 Oct 02:28 - "3"; YOMI lets you pick an outline colour and a particle trail -
## our own set): the outline every figure of yours is drawn with, and a trail of bits that follows you while you move.
## Saved; online, everyone sees yours (it goes with your seat), and it's kept in your replays.

const SETTINGS := "user://settings.cfg"
const OUTLINES := [["Ink", "#050508"], ["White", "#f2f2f7"], ["Gold", "#ffd23f"], ["Cyan", "#5fe0ff"],
	["Pink", "#ff7ab6"], ["Violet", "#b07aff"]]
const TRAILS := ["None", "Glints", "Embers", "Petals", "Wisps"]

static var outline := 0
static var trail := 0
static var _loaded := false


static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		outline = clampi(int(cfg.get_value("style", "outline", 0)), 0, OUTLINES.size() - 1)
		trail = clampi(int(cfg.get_value("style", "trail", 0)), 0, TRAILS.size() - 1)


static func set_mine(o: int, t: int) -> void:
	outline = clampi(o, 0, OUTLINES.size() - 1)
	trail = clampi(t, 0, TRAILS.size() - 1)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("style", "outline", outline)
	cfg.set_value("style", "trail", trail)
	cfg.save(SETTINGS)


static func outline_colour(i: int) -> Color:
	return Color(str(OUTLINES[clampi(i, 0, OUTLINES.size() - 1)][1]))


static func trail_name(i: int) -> String:
	return str(TRAILS[clampi(i, 0, TRAILS.size() - 1)])
