class_name Link
extends Node
## This phone's connection to a room on the relay (relay/src/index.js - Timmy, 18 Oct 17:46: "Relay + room codes", to
## play with a friend on another Wi-Fi). The host's link reaches everyone; a player's reaches only the host. Messages
## are small JSON dictionaries; the relay adds `from` to a player's and routes the host's by `to`.
## In tests `loop` is an in-process room (LoopRoom) that behaves like the relay, so a host and a player can play a whole
## match in one run; the real one is a WebSocket.

signal got(msg: Dictionary)
signal status(state: String, detail: String)   ## "open" | "closed" | "error"

## The relay (set once it's deployed; --relay=<url> overrides it for a test).
const DEFAULT_URL := "ws://127.0.0.1:8787"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   ## (no 0/O, 1/I - easy to read out)

static var url := DEFAULT_URL

var peer := 0          ## the relay's number for this phone (the host is 1)
var is_host := false
var code := ""
var loop: LoopRoom     ## tests: an in-process room instead of the network
var inbox: Array = []  ## (loop mode: messages waiting for the next poll, as the network would)
var ws: WebSocketPeer
var _opened := false


static func new_code(rng: RandomNumberGenerator = null) -> String:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var out := ""
	for _i in 4:
		out += CODE_CHARS[r.randi() % CODE_CHARS.length()]
	return out


func host_room(room: String, player_name: String) -> void:
	_open(room, player_name, true)


func join_room(room: String, player_name: String) -> void:
	_open(room.strip_edges().to_upper(), player_name, false)


func _open(room: String, player_name: String, host: bool) -> void:
	code = room
	is_host = host
	peer = 0
	_opened = false
	if loop != null:
		loop.connect_link(self, host, player_name)
		return
	ws = WebSocketPeer.new()
	var u := "%s/room/%s?name=%s%s" % [url, room, player_name.uri_encode(), "&host=1" if host else ""]
	if ws.connect_to_url(u) != OK:
		ws = null
		status.emit("error", "Can't reach the game server")


func send(d: Dictionary) -> void:
	if loop != null:
		loop.route(self, d)
	elif ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(d))


func connected() -> bool:
	return peer > 0


func close() -> void:
	if loop != null:
		loop.leave(self)
	elif ws != null:
		ws.close()
	peer = 0


## Deliver what's arrived (called every frame; the tests call it directly).
func poll() -> void:
	if loop != null:
		while not inbox.is_empty():
			_receive(inbox.pop_front())
		return
	if ws == null:
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _opened:
				_opened = true
				status.emit("open", "")
			while ws.get_available_packet_count() > 0:
				var parsed: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if parsed is Dictionary:
					_receive(parsed)
		WebSocketPeer.STATE_CLOSED:
			var why := ws.get_close_reason()
			ws = null
			peer = 0
			status.emit("closed" if _opened else "error", why if why != "" else "Can't reach the game server")


func _receive(d: Dictionary) -> void:
	if str(d.get("t", "")) == "welcome":
		peer = int(d["peer"])
	got.emit(d)


func _process(_delta: float) -> void:
	poll()
