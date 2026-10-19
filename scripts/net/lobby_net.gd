class_name LobbyNet
extends Node
## This phone in a lobby (relay/src/index.js - Timmy, 18 Oct 20:19: "Can we work on the lobby system? Look at the steam
## lobby your only move is hustle has"): who's in it and their status, the owner and the rules, the chat, and the
## messages that carry challenges and matches. `use_loop` puts it on the in-process server (LoopLobby: the tests, and
## trying the screens with no network); otherwise a WebSocket to the lobby server.

signal changed                                   ## anything in the lobby changed (members, rules, owner)
signal chat(who: String, text: String)
signal direct(from: int, msg: Dictionary)        ## a message to this phone alone (an invite, an answer, a pick)
signal channel(ch: String, from: int, msg: Dictionary)   ## a match's channel
signal member_left(id: int)
signal status(state: String, detail: String)     ## "open" | "closed" | "error"

## The lobby server: relay/ on Timmy's Cloudflare (deployed 18 Oct 20:57); --lobbies=<url> picks another (main.gd).
const DEFAULT_URL := "wss://standoff-relay.blissfulzephyr.workers.dev"
static var url := DEFAULT_URL          ## where this phone's lobby is (the server, or a nearby host phone)
static var online_url := DEFAULT_URL   ## the online server (url goes back to it from Nearby)
static var use_loop := false
var reached := true          ## the last list fetch got an answer from the server
var last_code := ""          ## the lobby this phone was in, and the name it used - to get back in (00:11)
var last_name := ""
var want_back := false       ## in a lobby, not left on purpose: rejoin when the phone comes back / the line drops

var id := 0                  ## this phone's number in the lobby
var owner_id := 0
var lobby := {}              ## {code, name, public, max, version, rules}
var members := {}            ## id -> {name, data: {status, colour, match, ...}}
var log: Array = []          ## the chat: [who, text]
var loop: LoopLobby          ## (loop mode: the in-process server)
var inbox: Array = []        ## (loop mode: messages waiting for the next poll)
var ws: WebSocketPeer
var _opened := false
var _http: HTTPRequest


## A lobby code: 4 digits (YOMI's are numbers too).
static func new_code() -> String:
	return str(randi_range(1000, 9999))


func create(code: String, my_name: String, lobby_name: String, public := true, max_players := 8) -> void:
	_open(code, {"name": my_name, "create": true, "lname": lobby_name, "public": public, "max": max_players,
		"v": Version.TAG})


func join(code: String, my_name: String) -> void:
	_open(code.strip_edges(), {"name": my_name, "v": Version.TAG})


func _open(code: String, q: Dictionary) -> void:
	last_code = code
	last_name = str(q["name"])
	id = 0
	members.clear()
	log.clear()
	_opened = false
	if use_loop:
		LoopLobby.connect_net(self, code, q)
		return
	ws = WebSocketPeer.new()
	var u := "%s/lobby/%s?name=%s%s" % [url, code, str(q["name"]).uri_encode(), ("&create=1&lname=%s&public=%d&max=%d&v=%s"
			% [str(q["lname"]).uri_encode(), 1 if q["public"] else 0, int(q["max"]), Version.TAG]) if q.get("create", false)
			else "&v=" + Version.TAG]
	if ws.connect_to_url(u) != OK:
		ws = null
		status.emit("error", "Can't reach the lobby server")


func is_owner() -> bool:
	return id != 0 and id == owner_id


func in_lobby() -> bool:
	return id != 0


func send(d: Dictionary) -> void:
	if loop != null:
		loop.receive(self, d)
	elif ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(d, "", false, true))


func say(text: String) -> void:
	if text.strip_edges() != "":
		send({"t": "chat", "text": text.strip_edges()})


func set_member(data: Dictionary) -> void:
	send({"t": "member", "data": data})


func set_lobby(data: Dictionary) -> void:
	send({"t": "lobby", "data": data})


func to(peer: int, msg: Dictionary) -> void:
	send({"t": "to", "to": peer, "msg": msg})


func sub(ch: String) -> void:
	send({"t": "sub", "ch": ch})


func unsub(ch: String) -> void:
	send({"t": "unsub", "ch": ch})


func on_channel(ch: String, msg: Dictionary) -> void:
	send({"t": "chan", "ch": ch, "msg": msg})


## Back into the lobby this phone was in (the same code and name) - after the app was put aside or the line dropped.
func rejoin() -> void:
	if last_code != "" and not in_lobby():
		join(last_code, last_name)


## The phone back from another app: if the lobby was lost meanwhile, straight back in.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and want_back and ws == null \
			and not in_lobby() and not use_loop:
		status.emit("reconnecting", "")
		rejoin()


func leave() -> void:
	want_back = false
	if loop != null:
		loop.leave(self)
		loop = null
	elif ws != null:
		ws.close()
	ws = null
	id = 0
	members.clear()
	inbox.clear()
	changed.emit()


## (loop mode) the in-process server handing this phone a message.
func deliver(d: Dictionary) -> void:
	inbox.append(d)


## The public lobbies -> cb([{code, name, version, players, max}]).
func fetch_list(cb: Callable) -> void:
	if use_loop:
		reached = true
		cb.call_deferred(LoopLobby.list())
		return
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:   # (one still going: this one instead)
		_http.cancel_request()
	if _http.request_completed.is_connected(_on_list):
		_http.request_completed.disconnect(_on_list)
	_http.request_completed.connect(_on_list.bind(cb))
	if _http.request(online_url.replace("wss://", "https://").replace("ws://", "http://") + "/lobbies") != OK:
		reached = false
		cb.call([])


func _on_list(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, cb: Callable) -> void:
	var d: Variant = JSON.parse_string(body.get_string_from_utf8()) if code == 200 else null
	reached = d is Array
	cb.call(d if d is Array else [])


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	if ws != null:
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			_opened = true
		while ws != null and ws.get_available_packet_count() > 0:   # (read what came, even with the close - a goodbye)
			var d: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if d is Dictionary:
				_handle(d)
		if ws == null:   # (a goodbye: left already)
			pass
		elif st == WebSocketPeer.STATE_CLOSED:
			ws = null
			if id != 0 or not _opened:
				status.emit("closed", "Lost the lobby server" if _opened else "Can't reach the lobby server")
			id = 0
			changed.emit()
	while not inbox.is_empty():
		_handle(inbox.pop_front())


func _handle(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"welcome":
			id = int(d["id"])
			owner_id = int(d["owner"])
			lobby = d["lobby"]
			members.clear()
			for m: Dictionary in d["members"]:
				members[int(m["id"])] = {"name": str(m["name"]), "data": m.get("data", {})}
			want_back = true
			status.emit("open", "")
		"joined":
			members[int(d["id"])] = {"name": str(d["name"]), "data": {}}
			log.append(["", "%s joined" % str(d["name"])])
		"left":
			var who := int(d["id"])
			if members.has(who):
				log.append(["", "%s left" % str(members[who]["name"])])
			members.erase(who)
			member_left.emit(who)
		"owner":
			owner_id = int(d["id"])
		"member":
			if members.has(int(d["id"])):
				members[int(d["id"])]["data"] = d["data"]
		"lobby":
			lobby = d["data"]
		"chat":
			log.append([str(d["name"]), str(d["text"])])
			chat.emit(str(d["name"]), str(d["text"]))
		"from":
			direct.emit(int(d["from"]), d.get("msg", {}))
			return
		"chan":
			channel.emit(str(d["ch"]), int(d["from"]), d.get("msg", {}))
			return
		"error":
			status.emit("error", str(d.get("msg", "")))
			return
		"bye":   # (a nearby host closing its lobby: no point trying to get back in)
			var why := str(d.get("msg", "The lobby closed"))
			leave()
			status.emit("ended", why)
			return
	changed.emit()
