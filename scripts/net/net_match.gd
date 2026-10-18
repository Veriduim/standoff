class_name NetMatch
extends Node
## One online match in a lobby. The phone that sent the challenge runs it (the host). Every phone in it - and anyone
## spectating - keeps its own copy of the match, plays each turn from the picks the host sends, then takes the host's
## state as the truth. The sim is deterministic and every phone starts each turn from the same state (the host's,
## sent as JSON), so the copies match. Picks go to the host alone (they're secret until the turn plays).
##   on the match's channel:  start {seats, mode, rules, snap} · seg {t, picks, snap} · end {reason}
##   direct:                   pick {ch, t, f, c} (to the host) · hello {ch} (a spectator) -> state {ch, seats, ..., snap}

signal begun                                                ## seats and start_snap are ready
signal turn(t: int, picks: Dictionary, snap: Dictionary)    ## play these picks from the current state; then it's snap
signal ended(reason: String)

const GRACE := 5.0           ## seconds past the turn clock the host waits before a missing pick becomes Hold

var net: LobbyNet
var ch := ""
var host := 0                ## the lobby id of the phone running the match
var seats: Array = []        ## per fighter: {peer (0 = a bot), name, colour, team}
var mode := "ffa"
var rules := {}
var start_snap := {}
var mine := -1               ## this phone's fighter (-1 = watching)
var live := false
# the host's
var sim: Sim                 ## (set by the host's GameScreen each turn - the state the turn starts from)
var turn_t := -1
var picks := {}
var bots := {}               ## fighter -> Bot (empty seats, and anyone who left)
var _wait := 0.0


## JSON there and back - what every phone gets (full precision, numbers as floats, keys as strings).
static func wire(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", false, true))


func is_host() -> bool:
	return net != null and net.id == host


func _bind(lobby_net: LobbyNet, channel_name: String) -> void:
	net = lobby_net
	ch = channel_name
	net.sub(ch)
	net.channel.connect(_on_channel)
	net.direct.connect(_on_direct)
	net.member_left.connect(_on_left)


## The host starting it: seats [{peer, name, colour, team}] (this phone first), the lobby's rules.
func host_start(lobby_net: LobbyNet, channel_name: String, the_seats: Array, the_mode: String, the_rules: Dictionary) -> void:
	_bind(lobby_net, channel_name)
	host = net.id
	seats = the_seats
	mode = the_mode
	rules = the_rules
	var players: Array = []
	for i in seats.size():
		var s: Dictionary = seats[i]
		players.append({"name": s["name"], "character": "dancer", "team": int(s.get("team", i))})
		if int(s["peer"]) == 0:
			bots[i] = Bot.new(i * 7 + 3)
		if int(s["peer"]) == net.id:
			mine = i
	start_snap = wire(Sim.create(players, mode, rules).to_dict())
	net.on_channel(ch, {"k": "start", "seats": seats, "mode": mode, "rules": rules, "snap": start_snap})
	live = true
	begun.emit()


## A player who accepted: waiting for the host's start on the channel.
func join_start(lobby_net: LobbyNet, channel_name: String, host_id: int) -> void:
	_bind(lobby_net, channel_name)
	host = host_id


## A spectator: ask the host for where the match is now.
func watch(lobby_net: LobbyNet, channel_name: String, host_id: int) -> void:
	_bind(lobby_net, channel_name)
	host = host_id
	net.to(host, {"k": "hello", "ch": ch})


func _take_start(msg: Dictionary) -> void:
	seats = msg["seats"]
	mode = str(msg["mode"])
	rules = msg["rules"]
	start_snap = msg["snap"]
	mine = -1
	for i in seats.size():
		if int(seats[i]["peer"]) == net.id:
			mine = i
	live = true
	begun.emit()


func _on_channel(c: String, _from: int, msg: Dictionary) -> void:
	if c != ch:
		return
	match str(msg.get("k", "")):
		"start":
			if not live:
				_take_start(msg)
		"seg":
			if live and not is_host():
				turn.emit(int(msg["t"]), msg["picks"], msg["snap"])
		"end":
			live = false
			ended.emit(str(msg.get("reason", "")))


func _on_direct(from: int, msg: Dictionary) -> void:
	if str(msg.get("ch", "")) != ch:
		return
	match str(msg.get("k", "")):
		"pick":   # (the host: a player's pick for this turn - only for their own fighter)
			var f := int(msg["f"])
			if is_host() and int(msg["t"]) == turn_t and f < seats.size() and int(seats[f]["peer"]) == from:
				picks[f] = msg["c"]
				_check()
		"hello":   # (the host: someone wants to watch - where it is now)
			if is_host() and sim != null:
				net.to(from, {"k": "state", "ch": ch, "seats": seats, "mode": mode, "rules": rules,
					"snap": wire(sim.to_dict())})
		"state":
			if not live:
				_take_start(msg)


## Someone left the lobby: their fighter becomes a bot (the host); the host gone ends it (everyone else).
func _on_left(id: int) -> void:
	if not live:
		return
	if id == host:
		live = false
		ended.emit("The host left")
		return
	if is_host():
		for i in seats.size():
			if int(seats[i]["peer"]) == id:
				seats[i]["peer"] = 0
				bots[i] = Bot.new(i * 7 + 3)
		if turn_t >= 0:
			_check()


## The host: a new turn from this state - the bots pick now, the others' picks are awaited.
func open_turn(s: Sim) -> void:
	sim = s
	turn_t = s.tick
	picks.clear()
	_wait = float(rules.get("turn", Sim.RULES["turn"])) + GRACE
	for f in s.deciders():
		if bots.has(f):
			picks[f] = (bots[f] as Bot).choose(s, f)
	_check()


## A pick for fighter f on turn t: the host keeps it; anyone else sends it to the host.
func submit(f: int, choice: Dictionary, t: int) -> void:
	if is_host():
		if t == turn_t:
			picks[f] = choice
			_check()
	else:
		net.to(host, {"k": "pick", "ch": ch, "t": t, "f": f, "c": choice})


func _check() -> void:
	if sim == null or turn_t < 0:
		return
	for f in sim.deciders():
		if not picks.has(f):
			return
	_resolve()


func _resolve() -> void:
	var t := turn_t
	var p := picks.duplicate()
	turn_t = -1
	turn.emit(t, p, {})   # (the host's GameScreen plays it and hands back the state - publish())


## The host, after playing turn t: everyone gets the picks and the state it ended on.
func publish(t: int, the_picks: Dictionary, snap: Dictionary) -> void:
	net.on_channel(ch, {"k": "seg", "t": t, "picks": the_picks, "snap": snap})


func finish(reason := "") -> void:
	if live and is_host():
		net.on_channel(ch, {"k": "end", "reason": reason})
	live = false
	if net != null:
		net.unsub(ch)
		for s in [[net.channel, _on_channel], [net.direct, _on_direct], [net.member_left, _on_left]]:
			if (s[0] as Signal).is_connected(s[1]):
				(s[0] as Signal).disconnect(s[1])


func _process(delta: float) -> void:
	if is_host() and turn_t >= 0 and sim != null:   # (the turn clock ran out: whoever hasn't picked holds)
		_wait -= delta
		if _wait <= 0.0:
			for f in sim.deciders():
				if not picks.has(f):
					picks[f] = {"move": "hold"}
			_resolve()
