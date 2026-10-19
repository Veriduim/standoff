class_name LobbyScreen
extends Control
## Online lobbies - YOMI's Steam lobby (Timmy, 18 Oct 20:19: "Can we work on the lobby system? Look at the steam lobby
## your only move is hustle has"; its screens studied from a video - study only), for matches of up to six:
##   the list   your name; Refresh, Same version, a code to join by; the lobbies (name, version, players) - tap to join;
##              Create a lobby (a name, public or not, max players)
##   a lobby    members (status, the owner's crown, Challenge), the matches going on (Spectate), New match (several at
##              once, bots in the empty seats), the code, the rules (the owner sets them; presets), the chat, Leave
##   an invite  "Ana invites you to a 3-player free-for-all" - Accept / Decline; the one inviting sees who's in, and
##              starts when everyone's answered (or Start now)

signal play(nm: NetMatch)    ## a match to show - playing in it or watching it
signal closed                ## back to the home screen

const SETTINGS := "user://settings.cfg"
## The rules the owner can set: [key, label, min, max, step, shown as].
const RULE_ROWS := [["turn", "Turn clock", 10, 120, 5, "%d s"], ["round", "Round", 20, 120, 10, "%d s"],
	["start", "Start distance (1v1)", 0, 600, 50, "%d"], ["width", "Stage width", 1200, 3200, 200, "%d"],
	["damage", "Damage", 0.5, 2.0, 0.25, "x%.2f"], ["hitstun", "Hitstun", 0.5, 2.0, 0.25, "x%.2f"],
	["meter", "Starting meter", 0.0, 3.0, 0.5, "%.1f bars"], ["ceiling", "Ceiling", 400, 2000, 100, "%d"]]
const PRESETS := {"Default": {}, "Quick": {"round": 2400, "damage": 1.25}, "Thinking": {"turn": 90},
	"Big stage": {"width": 2800}}
const LIST_COLS := [440, 200, 120]   ## the list's columns: lobby name, version, players
const MAIN := Color("#2b4f8a")       ## the main action's blue (as on the home screen)

var net: LobbyNet
var my_name := "Player"
var my_colour := 0
var view := "list"
var lobbies: Array = []       ## the last list fetched

var list_view: Control
var room_view: Control
var name_edit: LineEdit
var code_edit: LineEdit
var same_ver: CheckButton
var list_box: VBoxContainer
var lname_edit: LineEdit
var public_btn: CheckButton
var max_label: Label
var max_players := 8
var note: Label
var members_box: VBoxContainer
var matches_box: VBoxContainer
var title: Label
var code_label: Label
var rules_box: VBoxContainer
var chat_log: RichTextLabel
var chat_edit: LineEdit
var modal: PanelContainer
var modal_body: VBoxContainer

var _out := {}                ## my match invite going out: {ch, invited: [ids], answers: {id: true/false}, bots, mode}
var _in := {}                 ## the invite I'm looking at: {from, ch, ...}
var _waiting: NetMatch
var nearby := false           ## the Nearby tab: lobbies on this Wi-Fi / hotspot, hosted by a phone (00:43)
var finder: LanFinder         ## (Nearby) the lobbies around
var host: LanHost             ## (Nearby) the lobby this phone hosts
var _list_t := 0.0
var _tries := 0               ## reconnect tries since the line dropped        ## accepted - waiting for the host to start


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # (no anchors: sized by hand in _layout)
	theme = _theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	net = LobbyNet.new()
	add_child(net)
	net.changed.connect(_refresh_room)
	net.status.connect(_on_status)
	net.direct.connect(_on_direct)
	net.channel.connect(_on_channel)
	finder = LanFinder.new()
	finder.name = "LanFinder"
	add_child(finder)
	finder.set_process(false)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		my_name = str(cfg.get_value("online", "name", my_name))
	_build_list()
	_build_room()
	_build_modal()
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


## One look for every button here: flat boxes; on (toggles) = the blue.
static func _theme() -> Theme:
	var th := Theme.new()
	var looks := {"normal": Color("#252733"), "hover": Color("#30333f"), "pressed": MAIN,
		"hover_pressed": MAIN.lightened(0.12), "disabled": Color("#1a1b22")}
	for k: String in looks:
		th.set_stylebox(k, "Button", Ui.box(looks[k], 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return th


## The main action on a screen: blue.
static func _main(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", Ui.box(MAIN, 10))
	b.add_theme_stylebox_override("hover", Ui.box(MAIN.lightened(0.12), 10))
	return b


func open(colour: int) -> void:
	my_colour = colour
	visible = true
	if net.in_lobby():
		_show("room")
	else:
		_show("list")
		if nearby:
			finder.start()
			finder.set_process(true)
		refresh()


func _show(v: String) -> void:
	view = v
	list_view.visible = v == "list"
	room_view.visible = v == "room"
	modal.visible = false
	if v == "room":
		_refresh_room()


func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO   # (sized by hand, as the post layer is - the game screen's own rect isn't the viewport's)
	size = vp
	var lw := minf(820.0, vp.x - 32.0)
	list_view.position = Vector2((vp.x - lw) / 2.0, 16.0)
	list_view.size = Vector2(lw, vp.y - 32.0)
	room_view.position = Vector2(16, 16)
	room_view.size = vp - Vector2(32, 32)
	modal.reset_size()
	modal.position = (vp - modal.size) / 2.0


# ---------- the list ----------

func _build_list() -> void:
	list_view = VBoxContainer.new()
	(list_view as VBoxContainer).add_theme_constant_override("separation", 10)
	add_child(list_view)
	var tabs := HBoxContainer.new()   # (Online: the lobby server; Nearby: this Wi-Fi or a phone's hotspot - 00:43)
	tabs.add_theme_constant_override("separation", 8)
	list_view.add_child(tabs)
	tabs.add_child(Ui.label("LOBBIES", 30, Color("#f2f2f7")))
	var mode_group := ButtonGroup.new()
	for m: Array in [["Online", false], ["Nearby (Wi-Fi / hotspot)", true]]:
		var on: bool = m[1]
		var b := Ui.button(str(m[0]), func() -> void: set_nearby(on), 18)
		b.name = "ModeNearby" if on else "ModeOnline"
		b.toggle_mode = true
		b.button_group = mode_group
		b.button_pressed = on == nearby
		tabs.add_child(b)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	list_view.add_child(top)
	top.add_child(Ui.label("Your name", 16, Color("#8a8a9c")))
	name_edit = _edit(my_name, 170)
	name_edit.text_changed.connect(func(t: String) -> void: _set_name(t))
	top.add_child(name_edit)
	top.add_child(Ui.button("Refresh", func() -> void: refresh(), 18))
	same_ver = CheckButton.new()
	same_ver.text = "Same version"
	same_ver.button_pressed = true
	same_ver.toggled.connect(func(_on: bool) -> void: _fill_list())
	top.add_child(same_ver)
	code_edit = _edit("", 110)
	code_edit.placeholder_text = "lobby code"
	top.add_child(code_edit)
	var join_code := _main(Ui.button("Join", func() -> void: join(code_edit.text), 18))
	join_code.name = "JoinCode"
	top.add_child(join_code)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	list_view.add_child(head)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(16, 0)
	head.add_child(pad)
	var heads := ["Lobby name", "Version", "Players"]
	for i in heads.size():
		var l := Ui.label(heads[i], 15, Color("#8a8a9c"))
		l.custom_minimum_size = Vector2(float(LIST_COLS[i]), 0)
		head.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_view.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)
	note = Ui.label("", 16, Color("#ffb86b"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (a long one wraps instead of widening the screen)
	list_view.add_child(note)
	var make := HBoxContainer.new()
	make.add_theme_constant_override("separation", 8)
	list_view.add_child(make)
	var create := _main(Ui.button("Create lobby", func() -> void: create_lobby(), 20))
	create.name = "Create"
	make.add_child(create)
	lname_edit = _edit("", 240)
	lname_edit.placeholder_text = "lobby name"
	make.add_child(lname_edit)
	public_btn = CheckButton.new()
	public_btn.text = "Public"
	public_btn.button_pressed = true
	make.add_child(public_btn)
	make.add_child(Ui.label("Max", 16, Color("#8a8a9c")))
	make.add_child(Ui.button("−", func() -> void: _set_max(max_players - 1), 18))
	max_label = Ui.label("8", 18, Color("#f2f2f7"))
	make.add_child(max_label)
	make.add_child(Ui.button("+", func() -> void: _set_max(max_players + 1), 18))
	var back := Ui.button("Back", func() -> void: _close(), 20)
	list_view.add_child(back)


func _edit(text: String, w: float) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.custom_minimum_size = Vector2(w, 40)
	return e


func _set_name(t: String) -> void:
	my_name = t.strip_edges().left(16) if t.strip_edges() != "" else "Player"
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("online", "name", my_name)
	cfg.save(SETTINGS)


func _set_max(n: int) -> void:
	max_players = clampi(n, 2, 16)
	max_label.text = str(max_players)


## Online or Nearby. Nearby: no server - the lobbies are phones on this Wi-Fi (or one phone's hotspot) hosting.
func set_nearby(on: bool) -> void:
	nearby = on
	if not on:
		LobbyNet.url = LobbyNet.online_url
		finder.stop()
	else:
		finder.start()
	finder.set_process(on)
	code_edit.visible = not on   # (Nearby: nothing to type - the list finds them)
	(list_view.find_child("JoinCode", true, false) as Button).visible = not on
	public_btn.visible = not on
	(list_view.find_child("ModeNearby", true, false) as Button).set_pressed_no_signal(on)
	(list_view.find_child("ModeOnline", true, false) as Button).set_pressed_no_signal(not on)
	lobbies = []
	refresh()


func _process(delta: float) -> void:
	if not visible or not nearby or view != "list":
		return
	_list_t -= delta
	if _list_t <= 0.0:   # (the nearby list keeps itself up to date)
		_list_t = 1.0
		lobbies = finder.list()
		_fill_list()


func refresh() -> void:
	if nearby:
		lobbies = finder.list()
		_fill_list()
		return
	note.text = "Looking for lobbies..."
	net.fetch_list(func(found: Array) -> void:
		lobbies = found
		_fill_list())


func _fill_list() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	var shown := 0
	for l: Dictionary in lobbies:
		if same_ver.button_pressed and str(l.get("version", "")) != Version.TAG:
			continue
		var code := str(l["code"])
		var row := Button.new()
		row.name = "Lobby" + code
		row.custom_minimum_size = Vector2(0, 48)
		row.pressed.connect(func() -> void: join_lobby(l))
		var cols := HBoxContainer.new()   # (the columns, under their headings)
		cols.set_anchors_preset(Control.PRESET_FULL_RECT)
		cols.offset_left = 16
		cols.add_theme_constant_override("separation", 0)
		cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cols)
		var cells := [str(l["name"]).left(34), str(l["version"]), "%d / %d" % [int(l["players"]), int(l["max"])]]
		for i in cells.size():
			var cl := Ui.label(cells[i], 18, Color("#e2e2ea"))
			cl.custom_minimum_size = Vector2(float(LIST_COLS[i]), 0)
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cl.clip_text = true
			cols.add_child(cl)
		list_box.add_child(row)
		shown += 1
	if nearby:
		note.text = "" if shown > 0 else ("No lobbies nearby yet - create one (your phone hosts it). Everyone on the "
				+ "same Wi-Fi, or on the host's hotspot.")
		return
	note.text = "" if shown > 0 else ("No lobbies yet - create one" if net.reached else "Can't reach the lobby server")


func create_lobby() -> void:
	note.text = "Creating..."
	var lname := lname_edit.text.strip_edges()
	var code := LobbyNet.new_code()
	if nearby:   # (this phone hosts it: the server runs here, and this phone joins it like anyone else)
		_stop_host()
		host = LanHost.new()
		host.name = "LanHost"
		add_child(host)
		if not host.start(code):
			_stop_host()
			note.text = "Couldn't host here - is Standoff already hosting on this phone?"
			return
		LobbyNet.url = "ws://127.0.0.1:%d" % LanHost.WS_PORT
	net.create(code, my_name, lname if lname != "" else my_name + "'s Lobby", public_btn.button_pressed or nearby,
			max_players)


func _stop_host() -> void:
	if host != null:
		host.stop()   # (it says goodbye, then frees itself)
		host = null


## A row in the list: online by its code; nearby at its host's address.
func join_lobby(l: Dictionary) -> void:
	if nearby:
		LobbyNet.url = "ws://%s:%d" % [str(l["ip"]), int(l.get("port", LanHost.WS_PORT))]
	join(str(l["code"]))


func join(code: String) -> void:
	if code.strip_edges() == "":
		return
	note.text = "Joining..."
	net.join(code, my_name)


func _on_status(state: String, detail: String) -> void:
	match state:
		"open":
			note.text = ""
			_tries = 0
			net.set_member({"status": "idle", "colour": my_colour, "match": ""})
			_show("room")
		"ended":   # (the nearby host closed it: off the list, and why)
			finder.found.erase(net.last_code)
			if view == "room":
				_show("list")
				refresh()
			note.text = detail
		"reconnecting":
			code_label.text = "Reconnecting to lobby %s..." % net.last_code
		"closed" when net.want_back and _tries < 8:   # (the line dropped / the phone was put aside: back in, 00:11)
			_tries += 1
			code_label.text = "Reconnecting to lobby %s..." % net.last_code
			get_tree().create_timer(0.3 if _tries == 1 else 1.5).timeout.connect(_retry)
		"error", "closed":
			if net.want_back and view == "room":   # (it couldn't get back in - the lobby's gone)
				net.want_back = false
				detail = "That lobby closed while you were away"
			note.text = detail
			if view == "room":
				_show("list")


func _retry() -> void:
	if not net.in_lobby() and net.want_back:
		net.rejoin()


func _close() -> void:
	visible = false
	if nearby and not net.in_lobby():
		finder.set_process(false)
	closed.emit()


# ---------- a lobby ----------

func _build_room() -> void:
	room_view = HBoxContainer.new()
	(room_view as HBoxContainer).add_theme_constant_override("separation", 14)
	add_child(room_view)
	var left := _column(240)
	room_view.add_child(left)
	left.add_child(Ui.label("MEMBERS", 15, Color("#8a8a9c")))
	members_box = _scroll_list(left)
	var leave := Ui.button("Leave lobby", func() -> void: leave_lobby(), 16)   # (under the members - the rules
	leave.name = "Leave"                                                        # column runs off a short screen)
	leave.custom_minimum_size = Vector2(0, 44)
	left.add_child(leave)
	var mid := _column(300)
	room_view.add_child(mid)
	title = Ui.label("", 26, Color("#f2f2f7"))
	mid.add_child(title)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	mid.add_child(code_row)
	code_label = Ui.label("", 16, Color("#a7a7b8"))
	code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (the hosting line wraps - the chat stays on screen)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_label)
	var copy := Ui.button("Copy code", func() -> void: _copy_code(), 15)   # (send it without the lobby going - 00:11)
	copy.name = "CopyCode"
	copy.custom_minimum_size = Vector2(0, 38)
	code_row.add_child(copy)
	mid.add_child(Ui.label("MATCHES", 15, Color("#8a8a9c")))
	matches_box = _scroll_list(mid)
	var new_match := _main(Ui.button("New match...", func() -> void: _new_match(), 20))
	new_match.name = "NewMatch"
	mid.add_child(new_match)
	var right := _column(330)
	room_view.add_child(right)
	right.add_child(Ui.label("RULES", 15, Color("#8a8a9c")))
	var rules_scroll := ScrollContainer.new()   # (more rules than a short screen holds - they scroll, the chat stays)
	rules_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_scroll.size_flags_stretch_ratio = 3.0
	rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rules_scroll)
	rules_box = VBoxContainer.new()
	rules_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_box.add_theme_constant_override("separation", 2)
	rules_scroll.add_child(rules_box)
	right.add_child(Ui.label("CHAT", 15, Color("#8a8a9c")))
	chat_log = RichTextLabel.new()
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.scroll_following = true
	chat_log.bbcode_enabled = true
	chat_log.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(chat_log)
	var say := HBoxContainer.new()
	right.add_child(say)
	chat_edit = _edit("", 300)
	chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_edit.text_submitted.connect(func(_t: String) -> void: _send_chat())
	say.add_child(chat_edit)
	say.add_child(Ui.button("Send", func() -> void: _send_chat(), 16))



func _column(w: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(w, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # (they share whatever width there is)
	v.size_flags_stretch_ratio = w
	v.add_theme_constant_override("separation", 6)
	return v


func _scroll_list(parent: Control) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	s.add_child(v)
	return v


func _copy_code() -> void:
	var code := str(net.lobby.get("code", ""))
	if code == "":
		return
	DisplayServer.clipboard_set(code)
	var b := room_view.find_child("CopyCode", true, false) as Button
	b.text = "Copied %s" % code
	get_tree().create_timer(2.0).timeout.connect(_copy_label)   # (a method: gone with the screen, no dangling lambda)


func _copy_label() -> void:
	(room_view.find_child("CopyCode", true, false) as Button).text = "Copy code"


func _send_chat() -> void:
	net.say(chat_edit.text)
	chat_edit.text = ""


func leave_lobby() -> void:
	net.leave()
	_stop_host()   # (hosting: the lobby goes with you)
	_show("list")
	refresh()


func _refresh_room() -> void:
	if not net.in_lobby() or view != "room":
		return
	title.text = str(net.lobby.get("name", ""))
	code_label.text = "Lobby code %s  ·  %s  ·  %d / %d" % [str(net.lobby.get("code", "")),
		"public" if net.lobby.get("public", true) else "private", net.members.size(), int(net.lobby.get("max", 8))]
	if nearby:   # (no code to share: the others see it in their Nearby list)
		code_label.text = "Nearby lobby  ·  %d / %d%s" % [net.members.size(), int(net.lobby.get("max", 8)),
			"  ·  you're hosting - keep Standoff open" if host != null else ""]
	var copy := room_view.find_child("CopyCode", true, false) as Button
	copy.visible = not nearby
	if not copy.text.begins_with("Copied"):
		_copy_label()
	for c in members_box.get_children():
		members_box.remove_child(c)
		c.queue_free()
	for id: int in net.members:
		members_box.add_child(_member_row(id, net.members[id]))
	for c in matches_box.get_children():
		matches_box.remove_child(c)
		c.queue_free()
	for m: Dictionary in matches():
		matches_box.add_child(_match_row(m))
	if matches().is_empty():
		matches_box.add_child(Ui.label("No matches yet", 15, Color("#6b6b78")))
	_fill_rules()
	var lines := PackedStringArray()
	for e: Array in net.log:
		lines.append("[color=#8a8a9c]%s[/color]" % str(e[1]) if str(e[0]) == "" else "[b]%s:[/b] %s" % [str(e[0]),
				str(e[1])])
	chat_log.text = "\n".join(lines)


func _member_row(id: int, m: Dictionary) -> Control:
	var data: Dictionary = m.get("data", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.color = StageView.COLOURS[int(data.get("colour", 0)) % StageView.COLOURS.size()]
	row.add_child(dot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var who := str(m["name"]) + (" (you)" if id == net.id else "") + ("  👑" if id == net.owner_id else "")
	v.add_child(Ui.label(who, 17, Color("#f2f2f7")))
	v.add_child(Ui.label(str(data.get("status", "")), 13, Color("#8a8a9c")))
	if id != net.id and str(data.get("status", "idle")) == "idle" and _out.is_empty():
		var ch := Ui.button("Challenge", func() -> void: challenge([id], 0, "ffa"), 15)
		ch.name = "Challenge%d" % id
		row.add_child(ch)
	return row


## The matches going on: members grouped by the match they're in.
func matches() -> Array:
	var by := {}
	for id: int in net.members:
		var data: Dictionary = net.members[id].get("data", {})
		var ch := str(data.get("match", ""))
		if ch == "":
			continue
		if not by.has(ch):
			by[ch] = {"ch": ch, "names": [], "host": int(data.get("host", 0)), "bots": int(data.get("bots", 0))}
		(by[ch]["names"] as Array).append(str(net.members[id]["name"]))
	return by.values()


func _match_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var names: Array = m["names"]
	var text := " vs ".join(PackedStringArray(names))
	if int(m["bots"]) > 0:
		text += " + %d bot%s" % [int(m["bots"]), "" if int(m["bots"]) == 1 else "s"]
	var l := Ui.label(text, 16, Color("#e2e2ea"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var mine := str(net.members.get(net.id, {}).get("data", {}).get("match", "")) == str(m["ch"])
	if not mine:
		var sp := Ui.button("Spectate", func() -> void: spectate(str(m["ch"]), int(m["host"])), 15)
		sp.name = "Spectate"
		row.add_child(sp)
	return row


func _fill_rules() -> void:
	for c in rules_box.get_children():
		rules_box.remove_child(c)
		c.queue_free()
	var rules := rules_now()
	var owner := net.is_owner()
	if owner:   # (the presets first - the rules below scroll on a short screen)
		var pre := HFlowContainer.new()   # (the presets wrap on a narrow column)
		pre.add_theme_constant_override("h_separation", 6)
		pre.add_theme_constant_override("v_separation", 4)
		pre.add_child(Ui.label("Presets", 15, Color("#8a8a9c")))
		for p: String in PRESETS:
			var preset: Dictionary = PRESETS[p]
			var pb := Ui.button(p, func() -> void: _set_rules(preset), 14)
			pb.custom_minimum_size = Vector2(0, 40)
			pre.add_child(pb)
		rules_box.add_child(pre)
	else:
		rules_box.add_child(Ui.label("(the lobby's owner sets these)", 13, Color("#6b6b78")))
	for r: Array in RULE_ROWS:
		var key := str(r[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var l := Ui.label(str(r[1]), 15, Color("#c9c9d6"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var val: float = float(rules[key]) / (60.0 if key == "round" else 1.0)
		var shown := str(r[5]) % (int(val) if str(r[5]).contains("%d") else val)
		if key == "start" and val == 0.0:
			shown = "spread out"
		if owner:
			var less := Ui.button("−", func() -> void: _bump(key, -1), 16)
			less.custom_minimum_size = Vector2(46, 34)
			row.add_child(less)
		var vl := Ui.label(shown, 15, Color("#f2f2f7"))
		vl.custom_minimum_size = Vector2(96, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(vl)
		if owner:
			var more := Ui.button("+", func() -> void: _bump(key, 1), 16)
			more.custom_minimum_size = Vector2(46, 34)
			row.add_child(more)
		rules_box.add_child(row)


## The lobby's rules now (the owner's, on top of the defaults).
func rules_now() -> Dictionary:
	var r := Sim.RULES.duplicate()
	r.merge(net.lobby.get("rules", {}), true)
	return r


func _bump(key: String, dir: int) -> void:
	for r: Array in RULE_ROWS:
		if str(r[0]) == key:
			var rules := rules_now()
			var k := 60.0 if key == "round" else 1.0   # (the round is shown in seconds, kept in ticks)
			rules[key] = clampf(float(rules[key]) + float(r[4]) * k * dir, float(r[2]) * k, float(r[3]) * k)
			_set_rules(rules)


func _toggle_xf(k: String) -> void:
	var rules := rules_now()
	var on := Sim.xf_set(str(rules.get("xf", "")))
	if on.has(k):
		on.erase(k)
	else:
		on[k] = true
	rules["xf"] = ",".join(PackedStringArray(Sim.XF.filter(func(x: String) -> bool: return on.has(x))))
	_set_rules(rules)


func _set_rules(rules: Dictionary) -> void:
	var r := Sim.RULES.duplicate()
	r.merge(rules, true)
	net.set_lobby({"rules": r})


# ---------- challenges and matches ----------

func _build_modal() -> void:
	modal = PanelContainer.new()
	var st := Ui.box(Color("#15161ef4"), 16)
	st.set_content_margin_all(20)
	st.border_color = Color("#3a3d4d")
	st.set_border_width_all(2)
	modal.add_theme_stylebox_override("panel", st)
	var shade := ColorRect.new()   # (the lobby dimmed behind a box, and no taps through to it)
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	add_child(modal)
	modal.visibility_changed.connect(func() -> void: shade.visible = modal.visible)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 12)
	modal.add_child(modal_body)
	modal.visible = false


func _modal(build: Callable) -> void:
	for c in modal_body.get_children():
		modal_body.remove_child(c)
		c.queue_free()
	build.call(modal_body)
	modal.visible = true
	_layout()


## New match: pick who to invite (idle members), bots for the empty seats, the mode.
func _new_match() -> void:
	var picked := {}
	var bots := [0]
	var mode := ["ffa"]
	_modal(func(b: VBoxContainer) -> void:
		b.add_child(Ui.label("New match - up to 6", 22, Color("#f2f2f7")))
		for id: int in net.members:
			if id == net.id or str(net.members[id].get("data", {}).get("status", "idle")) != "idle":
				continue
			var cb := Ui.button(str(net.members[id]["name"]), func() -> void: pass, 17)   # (on = blue = invited)
			cb.toggle_mode = true
			cb.name = "Pick%d" % id
			cb.toggled.connect(func(on: bool) -> void:
				if on: picked[id] = true
				else: picked.erase(id))
			b.add_child(cb)
		var bl := Ui.label("Bots: 0", 17, Color("#f2f2f7"))
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 10)
		var fewer := func() -> void:
			bots[0] = maxi(0, bots[0] - 1)
			bl.text = "Bots: %d" % bots[0]
		var more := func() -> void:
			bots[0] = mini(5, bots[0] + 1)
			bl.text = "Bots: %d" % bots[0]
		brow.add_child(Ui.button("−", fewer, 16))
		brow.add_child(bl)
		var plus := Ui.button("+", more, 16)
		plus.name = "MoreBots"
		brow.add_child(plus)
		b.add_child(brow)
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for m: Array in [["Free-for-all", "ffa"], ["Teams", "teams"]]:
			var mid: String = m[1]
			var mb := Ui.button(str(m[0]), func() -> void: mode[0] = mid, 16)
			mb.toggle_mode = true
			mb.button_group = group
			mb.button_pressed = mid == "ffa"
			mrow.add_child(mb)
		b.add_child(mrow)
		var go := HBoxContainer.new()
		go.add_theme_constant_override("separation", 8)
		var invite := func() -> void:
			var ids := picked.keys()
			if ids.size() + bots[0] >= 1 and ids.size() + bots[0] <= 5:
				challenge(ids, bots[0], mode[0])
		var send := _main(Ui.button("Send invites", invite, 18))
		send.name = "SendInvites"
		go.add_child(send)
		go.add_child(Ui.button("Cancel", func() -> void: modal.visible = false, 18))
		b.add_child(go))


## Invite these members (and bots for more seats) to a match this phone runs.
func challenge(ids: Array, bots: int, mode: String) -> void:
	var ch := "m%d-%d" % [net.id, randi() % 100000]
	_out = {"ch": ch, "invited": ids, "answers": {}, "bots": bots, "mode": mode}
	var size := 1 + ids.size() + bots
	for id in ids:
		net.to(int(id), {"k": "invite", "ch": ch, "name": my_name, "size": size, "mode": mode, "bots": bots})
	net.set_member({"status": "inviting"})
	if ids.is_empty():
		start_match()
		return
	_show_waiting()


func _show_waiting() -> void:
	_modal(func(b: VBoxContainer) -> void:
		b.add_child(Ui.label("Waiting for answers...", 22, Color("#f2f2f7")))
		for id in _out["invited"]:
			var a: Variant = (_out["answers"] as Dictionary).get(int(id))
			var state := "..." if a == null else ("in" if a else "no")
			b.add_child(Ui.label("%s  -  %s" % [str(net.members.get(int(id), {}).get("name", "?")), state], 17,
					Color("#e2e2ea")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var now := _main(Ui.button("Start now", func() -> void: start_match(), 18))
		now.name = "StartNow"
		row.add_child(now)
		row.add_child(Ui.button("Cancel", func() -> void: _cancel_out(), 18))
		b.add_child(row))


func _cancel_out() -> void:
	for id in _out.get("invited", []):
		net.to(int(id), {"k": "cancel", "ch": _out["ch"]})
	_out = {}
	modal.visible = false
	net.set_member({"status": "idle"})


## The one inviting: everyone who said yes, then bots - the match starts on this phone.
func start_match() -> void:
	if _out.is_empty():
		return
	var seats: Array = [{"peer": net.id, "name": my_name, "colour": my_colour, "team": 0}]
	for id in _out["invited"]:
		if (_out["answers"] as Dictionary).get(int(id), false) and net.members.has(int(id)):
			var data: Dictionary = net.members[int(id)].get("data", {})
			seats.append({"peer": int(id), "name": str(net.members[int(id)]["name"]), "colour": int(data.get("colour", 0)),
				"team": seats.size() % 2})
	for i in int(_out["bots"]):
		seats.append({"peer": 0, "name": "Bot %d" % (i + 1), "colour": 0, "team": seats.size() % 2})
	if seats.size() < 2:   # (nobody said yes and no bots: one bot, so there's a match)
		seats.append({"peer": 0, "name": "Bot 1", "colour": 0, "team": 1})
	var used := {}
	for s: Dictionary in seats:   # (every colour different - a clash takes the next free one)
		var c := int(s["colour"]) % StageView.COLOURS.size()
		while used.has(c):
			c = (c + 1) % StageView.COLOURS.size()
		used[c] = true
		s["colour"] = c
	var nm := NetMatch.new()
	var ch := str(_out["ch"])
	var mode := str(_out["mode"]) if seats.size() >= 3 or str(_out["mode"]) == "ffa" else "ffa"
	for id in _out["invited"]:   # (the ones who weren't quick enough are let off)
		if not (_out["answers"] as Dictionary).get(int(id), false):
			net.to(int(id), {"k": "cancel", "ch": ch})
	_out = {}
	modal.visible = false
	net.set_member({"status": "in a match", "match": ch, "host": net.id,
		"bots": seats.filter(func(s: Dictionary) -> bool: return int(s["peer"]) == 0).size()})
	nm.host_start(net, ch, seats, mode, rules_now())
	visible = false
	play.emit(nm)


func _on_direct(from: int, msg: Dictionary) -> void:
	match str(msg.get("k", "")):
		"invite":
			if not _in.is_empty() or not _out.is_empty() or _waiting != null:
				net.to(from, {"k": "answer", "ch": msg["ch"], "yes": false})
				return
			_in = msg.duplicate()
			_in["from"] = from
			if not visible:   # (an invite while on the home screen: the lobby comes up with it)
				visible = true
				_show("room")
			_modal(func(b: VBoxContainer) -> void:
				var who := str(net.members.get(from, {}).get("name", msg.get("name", "?")))
				b.add_child(Ui.label("%s invites you to a %d-player %s" % [who, int(msg["size"]),
					"free-for-all" if str(msg["mode"]) == "ffa" else "team match"], 20, Color("#f2f2f7")))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				var yes := _main(Ui.button("Accept", func() -> void: answer(true), 18))
				yes.name = "Accept"
				row.add_child(yes)
				var no := Ui.button("Decline", func() -> void: answer(false), 18)
				no.name = "Decline"
				row.add_child(no)
				b.add_child(row))
		"answer":
			if not _out.is_empty() and str(msg["ch"]) == str(_out["ch"]):
				(_out["answers"] as Dictionary)[from] = bool(msg["yes"])
				if (_out["answers"] as Dictionary).size() >= (_out["invited"] as Array).size():
					start_match()
				else:
					_show_waiting()
		"cancel":
			if _waiting != null and _waiting.ch == str(msg["ch"]):
				_waiting.finish()
				_waiting.queue_free()
				_waiting = null
				net.set_member({"status": "idle", "match": ""})
			if not _in.is_empty() and str(_in["ch"]) == str(msg["ch"]):
				_in = {}
				modal.visible = false


## Answer the invite on screen; yes = wait on its channel for the start.
func answer(yes: bool) -> void:
	if _in.is_empty():
		return
	var host := int(_in["from"])
	var ch := str(_in["ch"])
	_in = {}
	modal.visible = false
	if yes:
		_waiting = NetMatch.new()
		add_child(_waiting)
		_waiting.begun.connect(_on_begun)
		_waiting.join_start(net, ch, host)
		net.set_member({"status": "in a match", "match": ch, "host": host})
	net.to(host, {"k": "answer", "ch": ch, "yes": yes})


func _on_begun() -> void:
	var nm := _waiting
	_waiting = null
	nm.begun.disconnect(_on_begun)
	nm.get_parent().remove_child(nm)
	visible = false
	play.emit(nm)


func _on_channel(_ch: String, _from: int, _msg: Dictionary) -> void:
	pass


## Watch a match: its state from the host, then each turn as it's played.
func spectate(ch: String, host: int) -> void:
	var nm := NetMatch.new()
	add_child(nm)
	_waiting = nm
	nm.begun.connect(_on_begun)
	nm.watch(net, ch, host)


## Back from a match (played or watched): idle again.
func back_from_match() -> void:
	net.set_member({"status": "idle", "match": "", "host": 0, "bots": 0})
	visible = true
	_show("room" if net.in_lobby() else "list")
