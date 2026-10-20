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
signal member_left(id: int)                      ## gone for good (left, or away too long)
signal member_away(id: int)                      ## their line dropped - their place is kept (20 Oct 18:13)
signal member_back(id: int)                      ## back in their place
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
var last_id := 0             ## this phone's place in that lobby, and its key - back to the same place (20 Oct 18:13)
var key := ""
var resumed := false         ## the last welcome: back in the same place (was_away: the others were told it was away)
var was_away := false

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
var _rx := 0                 ## (ms) the last thing heard on the line
var _pinged := 0.0           ## (s) since the last ping
var _unanswered := 0         ## (ms) when a ping went out with nothing heard since (0 = none waiting)

const PING_EVERY := 15.0     ## a ping this often keeps a quiet line open (and the server knows it's alive)
const DEAD_AFTER := 8000     ## (ms) a ping unanswered this long: the line's dead - back in from scratch


## A lobby code: 4 digits (YOMI's are numbers too).
static func new_code() -> String:
	return str(randi_range(1000, 9999))


func create(code: String, my_name: String, lobby_name: String, public := true, max_players := 8) -> void:
	_open(code, {"name": my_name, "create": true, "lname": lobby_name, "public": public, "max": max_players,
		"v": Version.TAG})


func join(code: String, my_name: String) -> void:
	_open(code.strip_edges(), {"name": my_name, "v": Version.TAG})


func _open(code: String, q: Dictionary) -> void:
	if code != last_code:   # (another lobby: no place to go back to)
		last_id = 0
		key = ""
	last_code = code
	last_name = str(q["name"])
	id = 0
	members.clear()
	if int(q.get("resume", 0)) == 0:
		log.clear()
	_opened = false
	_unanswered = 0
	_pinged = 0.0
	q["r"] = true   # (this phone comes back to its place when its line drops)
	if use_loop:
		LoopLobby.connect_net(self, code, q)
		return
	ws = WebSocketPeer.new()
	var u := "%s/lobby/%s?name=%s%s&r=1%s" % [url, code, str(q["name"]).uri_encode(),
			("&create=1&lname=%s&public=%d&max=%d&v=%s" % [str(q["lname"]).uri_encode(), 1 if q["public"] else 0,
			int(q["max"]), Version.TAG]) if q.get("create", false) else "&v=" + Version.TAG,
			("&resume=%d&key=%s" % [int(q["resume"]), str(q["key"]).uri_encode()]) if int(q.get("resume", 0)) > 0 else ""]
	if ws.connect_to_url(u) != OK:
		ws = null
		status.emit("error", "Can't reach the lobby server")


func is_owner() -> bool:
	return id != 0 and id == owner_id


func in_lobby() -> bool:
	return id != 0


## A member whose line dropped - their place kept for them (20 Oct 18:13).
func is_away(who: int) -> bool:
	return bool(members.get(who, {}).get("away", false))


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


## Back into the lobby this phone was in (the same code and name) - after the app was put aside or the line dropped:
## to its own place (its id and key) while the lobby keeps it, else in as someone new.
func rejoin() -> void:
	if last_code != "" and not in_lobby():
		_open(last_code, {"name": last_name, "v": Version.TAG, "resume": last_id, "key": key})


## The phone back from another app (20 Oct 18:13 "I minimised it to text someone and it killed the match"): the line
## may have died while it was away without saying so - a ping now, and if nothing answers, back in from scratch; a line
## known lost - straight back in.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:   # (put aside: the others are told at once - they go on without it)
		if in_lobby():
			send({"t": "away"})
			was_away = true
			if ws != null:
				ws.poll()   # (out now - nothing runs once the app's in the background)
		return
	if what not in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		return
	if in_lobby() and was_away and (loop != null or (ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN)):
		send({"t": "here"})
	if use_loop:
		return
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ping(true)
	elif want_back and ws == null and not in_lobby():
		status.emit("reconnecting", "")
		rejoin()


## A ping down the line (a bare "ping" - the server answers "pong" without waking the lobby). `fresh`: back from
## another app - the wait for its answer starts now, not when the app was put aside.
func _ping(fresh := false) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text("ping")
	_pinged = 0.0
	if _unanswered == 0 or fresh:
		_unanswered = Time.get_ticks_msec()


func leave() -> void:
	want_back = false
	last_id = 0
	key = ""
	if loop != null:
		loop.leave(self)
		loop = null
	elif ws != null:
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(JSON.stringify({"t": "leave"}))   # (on purpose: gone now - a line that drops keeps its place)
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


func _process(delta: float) -> void:
	poll(delta)


func poll(delta := 0.0) -> void:
	if ws != null:
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			_opened = true
		while ws != null and ws.get_available_packet_count() > 0:   # (read what came, even with the close - a goodbye)
			var text := ws.get_packet().get_string_from_utf8()
			_rx = Time.get_ticks_msec()
			_unanswered = 0
			if text == "pong":
				continue
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary:
				_handle(d)
		if ws == null:   # (a goodbye: left already)
			pass
		elif st == WebSocketPeer.STATE_CLOSED:
			_lost()
		elif st == WebSocketPeer.STATE_OPEN:
			_pinged += minf(delta, 1.0)
			if _pinged >= PING_EVERY:
				_ping()
			if _unanswered > 0 and Time.get_ticks_msec() - _unanswered > DEAD_AFTER:   # (a dead line that never closed)
				ws.close()
				_lost()
	while not inbox.is_empty():
		_handle(inbox.pop_front())


## The line's gone (closed, or dead): out of the lobby here - the screens get it back in (want_back).
func _lost() -> void:
	ws = null
	_unanswered = 0
	if id != 0 or not _opened:
		status.emit("closed", "Lost the lobby server" if _opened else "Can't reach the lobby server")
	id = 0
	changed.emit()


func _handle(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"welcome":
			id = int(d["id"])
			last_id = id
			key = str(d.get("key", ""))
			resumed = bool(d.get("resumed", false))
			was_away = bool(d.get("was_away", false))
			owner_id = int(d["owner"])
			lobby = d["lobby"]
			members.clear()
			for m: Dictionary in d["members"]:
				members[int(m["id"])] = {"name": str(m["name"]), "data": m.get("data", {}), "away": bool(m.get("away", false))}
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
		"away":   # (their line dropped: their place is kept)
			var who := int(d["id"])
			if members.has(who):
				members[who]["away"] = true
			member_away.emit(who)
		"back":
			var who := int(d["id"])
			members[who] = {"name": str(d.get("name", members.get(who, {}).get("name", "?"))), "data": d.get("data", {}),
				"away": false}
			member_back.emit(who)
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
