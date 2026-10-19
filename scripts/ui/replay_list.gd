class_name ReplayList
extends Control
## The saved replays, newest first (02:15 "When can I save replays??") - tap one to watch it; Share puts it on the
## lobby server under a 6-digit code to send a friend, and a code typed in at the top fetches theirs (02:36 "I cant
## share those with my friends?").

signal picked(path: String)

var _box: VBoxContainer
var _note: Label             ## where a "Save to phone" / Share / a code says how it went
var _code: LineEdit          ## a friend's replay code
var _http: HTTPRequest
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
	_code = LineEdit.new()
	_code.placeholder_text = "a friend's code"
	_code.custom_minimum_size = Vector2(190, 48)
	_code.add_theme_font_size_override("font_size", 20)
	top.add_child(_code)
	var watch := Ui.button("Watch code", func() -> void: watch_code(_code.text), 18)
	watch.name = "WatchCode"
	watch.custom_minimum_size = Vector2(150, 48)
	top.add_child(watch)
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_box.add_child(row)
		var b := Ui.button(Replays.describe(rec), func() -> void:
			visible = false
			picked.emit(p), 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
		var share := Ui.button("Share", func() -> void: share(p), 16)   # (02:36 - a code to send a friend)
		share.name = "Share"
		share.custom_minimum_size = Vector2(100, 54)
		row.add_child(share)
		var keep := Ui.button("Download" if Ui.web else "Save to phone", func() -> void: _export(p), 16)   # (02:19)
		keep.name = "Export"
		keep.custom_minimum_size = Vector2(150, 54)
		row.add_child(keep)
	_note = Ui.label("", 18, Color("#a7e8b8"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_note)
	_box.move_child(_note, 0)   # (at the top, where it's seen)
	if _box.get_child_count() == 1:
		_box.add_child(Ui.label("No replays yet - every match you finish is kept here (the last %d)." % Replays.KEEP,
				19, Color("#a7a7b8")))
	visible = true
	_layout()


## Share: put it on the lobby server, show its code and copy it.
func share(path: String) -> void:
	var rec := Replays.load_rec(path)
	if rec.is_empty():
		return
	_say("Sharing...", true)
	_request(Replays.share_url(), HTTPClient.METHOD_POST, JSON.stringify({"data": Replays.pack(rec), "v": Version.TAG}),
			func(code: int, d: Dictionary) -> void:
				if code == 200 and str(d.get("code", "")) != "":
					DisplayServer.clipboard_set(str(d["code"]))
					_say("Replay code %s%s. Send it to a friend: Replays -> type the code -> Watch code."   # (a browser
							% [str(d["code"]), "" if Ui.web else " - copied"], true)   # may not let it copy after a wait)
				else:
					_say(str(d.get("error", "Couldn't share it - no internet?")), false))


## A friend's code: fetch it, keep it with the rest, watch it.
func watch_code(text: String) -> void:
	var code := text.strip_edges().replace(" ", "")
	if code.length() != 6 or not code.is_valid_int():
		_say("A replay code is 6 numbers", false)
		return
	_say("Getting replay %s..." % code, true)
	_request(Replays.share_url() + "/" + code, HTTPClient.METHOD_GET, "", func(status: int, d: Dictionary) -> void:
		var rec := Replays.unpack(str(d.get("data", ""))) if status == 200 else {}
		if rec.is_empty():
			_say(str(d.get("error", "No replay with that code")), false)
			return
		rec["result"] = str(rec.get("result", "")) + "  (code %s)" % code
		rec["when"] = int(Time.get_unix_time_from_system())   # (kept as just got, so it's at the top)
		var path := Replays.save(rec)
		visible = false
		picked.emit(path))


func _request(url: String, method: int, body: String, done: Callable) -> void:
	_http.cancel_request()
	for c in _http.request_completed.get_connections():
		_http.request_completed.disconnect(c["callable"])
	_http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
		done.call(code, d if d is Dictionary else {}), CONNECT_ONE_SHOT)
	if _http.request(url, ["Content-Type: application/json"], method, body) != OK:
		_say("Couldn't reach the server - no internet?", false)


func _say(text: String, good: bool) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", Color("#a7e8b8") if good else Color("#ffb86b"))


func _export(path: String) -> void:
	var out := Replays.export_to_device(path)
	var where := "Downloaded" if Ui.web else "Saved to your phone"
	_note.text = ("%s: %s" % [where, out]) if out != "" else "Couldn't save it"
	_note.add_theme_color_override("font_color", Color("#a7e8b8") if out != "" else Color("#ffb86b"))


func _layout() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_panel.size = Vector2(minf(820.0, vp.x - 40.0), vp.y - 40.0)
	_panel.position = (vp - _panel.size) / 2.0
