class_name LoopLobby
extends RefCounted
## An in-process lobby server - the same rules as relay/src/index.js (one per code; the public list) - for the tests and
## for trying the lobby screens without the network. Each member is a LobbyNet; messages arrive on its next poll, as
## they would over the wire. Kept places as the server's (20 Oct 18:13): a line that drops (drop) keeps its place
## AWAY_MS - "away", and "back" when it returns with its id and key; leave = gone at once.

static var lobbies := {}     ## code -> LoopLobby (the public list reads these)

var code := ""
var meta := {}
var members: Array = []      ## [{id, name, data, subs: [], key, r, net: LobbyNet}]
var away: Array = []         ## the places kept for dropped lines: [{id, name, data, subs, key, since}]
var _next := 0


const GRACE_MS := 600000   ## an empty lobby waits this long for someone to come back (Timmy 00:11; 10 min since 20 Oct)
static var away_ms := 600000   ## a dropped line's place is kept this long (the tests shorten it)


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
	if l != null:
		l.expire()
	var create := bool(q.get("create", false))
	var resume := int(q.get("resume", 0))
	if l != null and resume > 0 and str(q.get("key", "")) != "" and l._resume(net, resume, str(q["key"])):
		return true
	var err := ""
	if create:
		if l != null and (not l.members.is_empty() or not l.away.is_empty()):
			err = "That lobby code is taken - try again"
		else:
			l = LoopLobby.new()
			l.code = room
			l.meta = {"code": room, "name": str(q.get("lname", str(q.get("name", "?")) + "'s Lobby")).left(28),
				"public": bool(q.get("public", true)), "max": clampi(int(q.get("max", 8)), 2, 16),
				"version": str(q.get("v", "?")), "owner": 0, "rules": {}}
			lobbies[room] = l
	elif l == null or (l.members.is_empty() and l.away.is_empty()
			and Time.get_ticks_msec() - int(l.meta.get("empty_at", -999999)) > GRACE_MS):
		err = "No lobby with that code"
	elif l.members.size() + l.away.size() >= int(l.meta["max"]):
		err = "That lobby is full"
	if err != "":
		net.deliver(NetMatch.wire({"t": "error", "msg": err}))
		return false
	l._next += 1
	var id := l._next
	if int(l.meta["owner"]) == 0 or (l.members.is_empty() and l.away.is_empty()):
		l.meta["owner"] = id
	l.meta.erase("empty_at")
	var key := "%08x%08x" % [randi(), randi()]
	l.members.append({"id": id, "name": str(q.get("name", "Player")).left(16), "data": {}, "subs": [], "key": key,
		"r": bool(q.get("r", false)), "net": net})
	net.loop = l
	net.deliver(NetMatch.wire({"t": "welcome", "id": id, "owner": l.meta["owner"], "lobby": l.meta.duplicate(true),
		"members": l._roster(), "key": key, "resumed": false, "was_away": false}))
	l._all({"t": "joined", "id": id, "name": str(q.get("name", "Player")).left(16)}, net)
	return true


## Back to its place with its id and key: from away, or replacing a line that's dead but never closed (a ghost).
func _resume(net: LobbyNet, id: int, key: String) -> bool:
	for a: Dictionary in away:
		if int(a["id"]) == id and str(a["key"]) == key:
			away.erase(a)
			var m := {"id": id, "name": a["name"], "data": a["data"], "subs": a["subs"], "key": key, "r": true, "net": net}
			members.append(m)
			meta.erase("empty_at")
			net.loop = self
			net.deliver(NetMatch.wire({"t": "welcome", "id": id, "owner": meta["owner"], "lobby": meta.duplicate(true),
				"members": _roster(), "key": key, "resumed": true, "was_away": true}))
			_all({"t": "back", "id": id, "name": a["name"], "data": (a["data"] as Dictionary).duplicate(true)}, net)
			return true
	for m: Dictionary in members:
		if int(m["id"]) == id and str(m["key"]) == key:
			var ghost: LobbyNet = m["net"]
			if ghost != null and ghost != net and ghost.loop == self:
				ghost.loop = null   # (the old line: nothing more reaches it)
			m["net"] = net
			net.loop = self
			var was := bool(m.get("away", false))   # (put aside on purpose, then its line died unseen)
			m.erase("away")
			net.deliver(NetMatch.wire({"t": "welcome", "id": id, "owner": meta["owner"], "lobby": meta.duplicate(true),
				"members": _roster(), "key": key, "resumed": true, "was_away": was}))
			if was:
				_all({"t": "back", "id": id, "name": m["name"], "data": (m["data"] as Dictionary).duplicate(true)}, net)
			return true
	return false


func _roster() -> Array:
	var out: Array = members.map(func(m: Dictionary) -> Dictionary: return {"id": m["id"], "name": m["name"],
			"data": (m["data"] as Dictionary).duplicate(true), "away": bool(m.get("away", false))})
	for a: Dictionary in away:
		out.append({"id": a["id"], "name": a["name"], "data": (a["data"] as Dictionary).duplicate(true), "away": true})
	return out


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
		"leave":   # (on purpose: gone now, not kept)
			leave(net)
		"away":   # (the app put aside: the others go on at once)
			if not bool(me.get("away", false)):
				me["away"] = true
				_all({"t": "away", "id": me["id"]}, net)
		"here":
			if bool(me.get("away", false)):
				me.erase("away")
				_all({"t": "back", "id": me["id"], "name": me["name"], "data": (me["data"] as Dictionary).duplicate(true)}, net)


## Leaving on purpose: gone at once.
func leave(net: LobbyNet) -> void:
	var me := _me(net)
	if me.is_empty():
		return
	members.erase(me)
	net.loop = null
	_out(int(me["id"]))


## The line dropped: its place kept away_ms ("away"); a phone that can't come back (no r) is gone at once.
func drop(net: LobbyNet) -> void:
	var me := _me(net)
	if me.is_empty():
		return
	members.erase(me)
	net.loop = null
	if not bool(me.get("r", false)):
		_out(int(me["id"]))
		return
	away.append({"id": me["id"], "name": me["name"], "data": me["data"], "subs": me["subs"], "key": me["key"],
		"since": Time.get_ticks_msec()})
	if not bool(me.get("away", false)):   # (put aside on purpose: they know already)
		_all({"t": "away", "id": me["id"]})


## Places kept too long: gone for good.
func expire() -> void:
	for a: Dictionary in away.duplicate():
		if Time.get_ticks_msec() - int(a["since"]) >= away_ms:
			away.erase(a)
			_out(int(a["id"]))


## Someone gone for good: everyone's told; the owner gone - the next one in; the last - it waits GRACE_MS, off the list.
func _out(id: int) -> void:
	_all({"t": "left", "id": id})
	var ids: Array = members.map(func(m: Dictionary) -> int: return int(m["id"]))
	ids.append_array(away.map(func(a: Dictionary) -> int: return int(a["id"])))
	if ids.is_empty():
		meta["empty_at"] = Time.get_ticks_msec()
	elif int(meta["owner"]) == id:
		meta["owner"] = ids.min()
		_all({"t": "owner", "id": meta["owner"]})
