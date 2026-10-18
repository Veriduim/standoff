class_name MoveIcon
extends Button
## A move as an icon (17:37: "see how we get that to fit with icons"): the character's own stick figure in the move's
## key pose (Moves.icon_pose), its name under it, a badge for the direction it takes and the meter it costs. Drawn from
## the move data - no art to make for a new move.

const AIM_BADGE := {"facing": "↔", "dir8": "✣", "up": "↑", "down": "↓", "lean": "✣", "none": ""}
## Each tab's colour - its icons are drawn in it, so a move's kind reads at a glance (pick 12). YOMI's: Movement and
## Defense white, Attack yellow, Special red, Super blue (21:03).
const TAB_COLOURS := {"move": Color("#eef0f6"), "attack": Color("#ffd23f"), "special": Color("#ff6b6b"),
	"super": Color("#5aa9ff"), "defend": Color("#c9cede"), "none": Color("#8fd6ff")}


static func tab_colour(ch: String, mid: String) -> Color:
	return TAB_COLOURS.get(str(Moves.move(ch, mid).get("tab", "")), Color.WHITE)

var character := "dancer"
var move_id := ""
var colour := Color.WHITE
var selected := false
var note := ""               ## a tag top left (IC: picking it again is an Instant Cancel - a bar)
var face := 1.0              ## the way the figure faces (21:59: toward who it's up against - theirs face you)


static func make(ch: String, mid: String, col: Color, on: Callable) -> MoveIcon:
	var b := MoveIcon.new()
	b.character = ch
	b.move_id = mid
	b.colour = col
	if mid != "":
		b.name = mid
	b.custom_minimum_size = Vector2(88, 96)
	b.pressed.connect(on)
	var st := Ui.box(Color("#22242e"), 10)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", Ui.box(Color("#2c2f3c"), 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _draw() -> void:
	var m := Moves.move(character, move_id)
	if m.is_empty():
		return
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size), colour.darkened(0.55), true)
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), colour, false, 2.0)
	var pose := Poses.get_pose(Moves.icon_pose(m))
	var head_r := float(Stick.style["head"])
	var bb := Stick.bounds(pose, head_r)
	var area := Rect2(Vector2(8, 6), Vector2(size.x - 16, size.y - 30))
	# (one figure size for every icon - a curled-up roll isn't blown up to fill the box)
	var sc := minf(minf(area.size.x / maxf(bb.size.x, 1.0), area.size.y / maxf(bb.size.y, 1.0)) * 0.95, area.size.y / 108.0)
	var mid := bb.get_center()
	var origin := area.get_center() - Vector2(mid.x * face, mid.y) * sc
	var col := colour if not disabled else colour.darkened(0.6)
	var dancer := character == "dancer"
	var open := Stick.fan_open(0, str(m.get("kind", "")))
	if dancer:   # (her fans - the far one behind her)
		Stick.fan_at(self, Stick._place(pose, origin, sc, face), "b", face, sc, open, col)
	var pts := Stick.draw(self, pose, origin, sc, face, col, maxf(3.0, Stick.limb(sc)), head_r * sc)
	if dancer:
		Stick.fan_at(self, pts, "f", face, sc, open, col)
	var font := get_theme_default_font()
	var text_col := Color("#e8e8f0") if not disabled else Color("#6b6b78")
	draw_string(font, Vector2(2, size.y - 7), str(m["name"]), HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 13, text_col)
	var badge := str(AIM_BADGE.get(str(m.get("aim", "none")), ""))
	if badge != "":
		draw_string(font, Vector2(size.x - 20, 18), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a7a7b8"))
	if int(m.get("cost", 0)) > 0:
		draw_string(font, Vector2(5, 18), "%d bar" % int(int(m["cost"]) / Sim.BAR), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color("#ffd166"))
	if note != "":
		draw_string(font, Vector2(5, 18), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c58bff"))
