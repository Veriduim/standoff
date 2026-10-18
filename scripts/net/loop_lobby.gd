class_name LoopLobby
extends RefCounted
## An in-process lobby server - the same rules as relay/src/index.js (one per code; the public list) - for the tests and
## for trying the lobby screens without the network. Each member is a LobbyNet; messages arrive on its next poll, as
## they would over the wire.

static var lobbies := {}     ## code -> LoopLobby (the public list reads these)

var code := ""
var meta := {}
var members: Array = []      ## [{id, name, data, subs: [], net: LobbyNet}]
var _next := 0


const GRACE_MS := 120000   ## an empty lobby waits this long for someone to come back (Timmy 00:11)


static func list() -> Array:
	var out: Array = []
	for c in lobbies:
		var l: LoopLobby = lobbies[c]
		if bool(l.meta.get("public", true)) and not l.members.is_empty():
			out.append({"code": c, "name": l.meta["name"], "version": l.meta["version"], "players": l.members.size(),
				"max": l.meta["max"]})
	return out


static func reset() -> void:
	lobbies.clear()


## A LobbyNet joining (or creating) `room`; false = refused (its error is already in its inbox).
static func connect_net(net: LobbyNet, room: String, q: Dictionary) -> bool:
	var l: LoopLobby = lobbies.get(room)
	var create := bool(q.get("create", false))
	var err := ""
	if create:
		if l != null and not l.members.is_empty():
			err = "That lobby code is taken - try again"
		else:
			l = LoopLobby.new()
			l.code = room
			l.meta = {"code": room, "name": str(q.get("lname", str(q.get("name", "?")) + "'s Lobby")).left(28),
				"public": bool(q.get("public", true)), "max": clampi(int(q.get("max", 8)), 2, 16),
				"version": str(q.get("v", "?")), "owner": 0, "rules": {}}
			lobbies[room] = l
	elif l == null or (l.members.is_empty() and Time.get_ticks_msec() - int(l.meta.get("empty_at", -999999)) > GRACE_MS):
		err = "No lobby with that code"
	elif l.members.size() >= int(l.meta["max"]):
		err = "That lobby is full"
	if err != "":
		net.deliver(NetMatch.wire({"t": "error", "msg": err}))
		return false
	l._next += 1
	var id := l._next
	if int(l.meta["owner"]) == 0 or l.members.is_empty():
		l.meta["owner"] = id
	l.members.append({"id": id, "name": str(q.get("name", "Player")).left(16), "data": {}, "subs": [], "net": net})
	net.loop = l
	net.deliver(NetMatch.wire({"t": "welcome", "id": id, "owner": l.meta["owner"], "lobby": l.meta.duplicate(true),
		"members": l._roster()}))
	l._all({"t": "joined", "id": id, "name": str(q.get("name", "Player")).left(16)}, net)
	return true


func _roster() -> Array:
	return members.map(func(m: Dictionary) -> Dictionary: return {"id": m["id"], "name": m["name"],
			"data": (m["data"] as Dictionary).duplicate(true)})


func _all(d: Dictionary, except: LobbyNet = null) -> void:
	for m: Dictionary in members:
		if m["net"] != except:
			(m["net"] as LobbyNet).deliver(NetMatch.wire(d))


func _me(net: LobbyNet) -> Dictionary:
	for m: Dictionary in members:
		if m["net"] == net:
			return m
	return {}


## A message from a member (the same switch as the server's webSocketMessage).
func receive(net: LobbyNet, d: Dictionary) -> void:
	var me := _me(net)
	if me.is_empty():
		return
	match str(d.get("t", "")):
		"chat":
			_all({"t": "chat", "from": me["id"], "name": me["name"], "text": str(d.get("text", "")).left(200)})
		"member":
			(me["data"] as Dictionary).merge(d.get("data", {}), true)
			_all({"t": "member", "id": me["id"], "data": (me["data"] as Dictionary).duplicate(true)})
		"lobby":
			if int(meta["owner"]) != int(me["id"]):
				return
			var nd: Dictionary = d.get("data", {})
			for k in ["name", "public", "max", "rules"]:
				if nd.has(k):
					meta[k] = nd[k]
			_all({"t": "lobby", "data": meta.duplicate(true)})
		"to":
			for m: Dictionary in members:
				if int(m["id"]) == int(d.get("to", -1)):
					(m["net"] as LobbyNet).deliver(NetMatch.wire({"t": "from", "from": me["id"], "msg": d.get("msg", {})}))
		"sub":
			if not (me["subs"] as Array).has(str(d["ch"])):
				(me["subs"] as Array).append(str(d["ch"]))
		"unsub":
			(me["subs"] as Array).erase(str(d["ch"]))
		"chan":
			for m: Dictionary in members:
				if m["net"] != net and (m["subs"] as Array).has(str(d["ch"])):
					(m["net"] as LobbyNet).deliver(NetMatch.wire({"t": "chan", "ch": str(d["ch"]), "from": me["id"], "msg": d.get("msg", {})}))


func leave(net: LobbyNet) -> void:
	var me := _me(net)
	if me.is_empty():
		return
	members.erase(me)
	_all({"t": "left", "id": me["id"]})
	if members.is_empty():   # (it waits GRACE_MS for them to come back, off the list - as the server does)
		meta["empty_at"] = Time.get_ticks_msec()
	elif int(meta["owner"]) == int(me["id"]):
		var ids: Array = members.map(func(m: Dictionary) -> int: return int(m["id"]))
		meta["owner"] = ids.min()
		_all({"t": "owner", "id": meta["owner"]})
