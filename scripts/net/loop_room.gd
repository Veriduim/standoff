class_name LoopRoom
extends RefCounted
## The relay's rules in-process (relay/src/index.js), for tests: one room, a host (peer 1) and up to 5 players; the host's
## messages go to everyone or to `to`, a player's go to the host with `from`; joins, leaves and the host leaving are
## announced. Messages wait in each Link's inbox until it polls, as they would on the network.

const MAX_PEERS := 6

var links: Array[Link] = []
var names := {}


func _post(l: Link, d: Dictionary) -> void:
	l.inbox.append(JSON.parse_string(JSON.stringify(d)))   # (a copy, as if it went over the wire)


func _host() -> Link:
	for l in links:
		if l.is_host:
			return l
	return null


func connect_link(l: Link, host: bool, player_name: String) -> void:
	var error := ""
	if host and _host() != null:
		error = "That room code is taken - try hosting again"
	elif not host and _host() == null:
		error = "No game with that code"
	elif links.size() >= MAX_PEERS:
		error = "That game is full"
	if error != "":
		_post(l, {"t": "error", "msg": error})
		return
	var used := links.map(func(x: Link) -> int: return x.peer)
	var p := 1 if host else 2
	while used.has(p):
		p += 1
	l.peer = p
	links.append(l)
	names[l] = player_name
	_post(l, {"t": "welcome", "peer": p})
	if not host:
		_post(_host(), {"t": "joined", "peer": p, "name": player_name})


func route(from: Link, d: Dictionary) -> void:
	if not links.has(from):
		return
	if from.is_host:
		for l in links:
			if not l.is_host and (not d.has("to") or int(d["to"]) == l.peer):
				_post(l, d)
	else:
		var copy := d.duplicate()
		copy["from"] = from.peer
		var h := _host()
		if h != null:
			_post(h, copy)


func leave(l: Link) -> void:
	if not links.has(l):
		return
	links.erase(l)
	if l.is_host:
		for o in links:
			_post(o, {"t": "host_left"})
		links.clear()
	else:
		var h := _host()
		if h != null:
			_post(h, {"t": "left", "peer": l.peer})
