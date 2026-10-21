class_name NetMatch
extends Node
## One online match in a lobby. The phone that sent the challenge runs it (the host). Every phone in it - and anyone
## spectating - keeps its own copy of the match, plays each turn from the picks the host sends, then takes the host's
## state as the truth. The sim is deterministic and every phone starts each turn from the same state (the host's,
## sent as JSON), so the copies match. Picks go to the host alone (they're secret until the turn plays).
##   on the match's channel:  start {seats, mode, rules, snap} · seg {t, picks, snap} · end {reason}
##                             sync {f, name} (a phone back after a drop - whoever runs the match answers: state)
##                             again {t, f, snap} (the host back after its line dropped: where it is, picks again)
##   direct:                   pick {ch, t, f, c} (to the host) · hello {ch} (a spectator) -> state {ch, host, seats,
##                             ..., snap} · refused
##
## A line that drops (20 Oct 18:13 "in the match I minimised it to text someone and it killed the match"): the lobby keeps
## the place (LobbyNet "away"). A player away: a bot plays their seat until they're back. The HOST away: the match moves
## to the next player's phone - every phone works out the same one (the seats in order, the first player here) and it
## goes on from where it is, as every phone has the same state; the old host comes back as a player. Nobody to take it
## on (the others are bots): the match waits for the host.

signal begun                                                ## seats and start_snap are ready
signal turn(t: int, picks: Dictionary, snap: Dictionary)    ## play these picks from the current state; then it's snap
signal ended(reason: String)
signal resync(snap: Dictionary)                             ## back after a drop: carry on from the host's state now
signal host_changed(host: int)                              ## the match moved to another phone (this one: is_host())
signal host_away(name: String)                              ## the host's line dropped and nobody can take it on

const GRACE := 5.0           ## seconds past the turn clock the host waits before a missing pick becomes Hold
static var ask_every := 4.0  ## back after a drop: ask again this often for where the match is (the tests: less)
const ASKS := 3              ## ...this many times; then it's settled (_settle): who runs it, or wait for the host
const ROUNDS := 4            ## (asks rounds with the one running it here and not answering: then it's taken as gone)

var net: LobbyNet
var ch := ""
var host := 0                ## the lobby id of the phone running the match
var seats: Array = []        ## per fighter: {peer (0 = a bot), name, colour, team, away?, left?}
var mode := "ffa"
var rules := {}
var start_snap := {}
var mine := -1               ## this phone's fighter (-1 = watching)
var live := false
# the host's
var sim: Sim                 ## (kept by the host's GameScreen - the match as it is now)
var turn_t := -1
var picks := {}
var bots := {}               ## fighter -> Bot (empty seats, and anyone away or gone)
var _wait := 0.0
var _early := {}             ## (the host) fighter -> [t, pick] that came before the host opened turn t
# anyone's
var _mine_pick: Array = []   ## [t, choice]: this phone's pick for the open turn - sent again to a new host
var _asking := 0.0           ## back after a drop: time to the next ask (0 = not asking)
var _asks := 0
var _rounds := 0
var _heard := {}             ## back after a drop, nobody answering: the others asking too - peer -> [tick, seat]
var _my_name := ""
var _reclaiming := false     ## asked where the match is (back after a drop), not answered yet
var aside := false           ## the app put aside mid-match (20 Oct 18:13) - when it's back, it asks where the match is


## JSON there and back - what every phone gets (full precision, numbers as floats, keys as strings).
static func wire(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", false, true))


func is_host() -> bool:
	return net != null and net.id == host and not _reclaiming


func _bind(lobby_net: LobbyNet, channel_name: String) -> void:
	net = lobby_net
	ch = channel_name
	net.sub(ch)
	net.channel.connect(_on_channel)
	net.direct.connect(_on_direct)
	net.member_left.connect(_on_left)
	net.member_away.connect(_on_away)


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
		players.append({"name": s["name"], "character": str(s.get("character", "dancer")), "team": int(s.get("team", i))})
		if int(s["peer"]) == net.id:
			mine = i
	_seat_bots()
	start_snap = wire(Sim.create(players, mode, rules).to_dict())
	net.on_channel(ch, {"k": "start", "seats": seats, "mode": mode, "rules": rules, "snap": start_snap})
	live = true
	begun.emit()


## A player who accepted: waiting for the host's start on the channel.
func join_start(lobby_net: LobbyNet, channel_name: String, host_id: int) -> void:
	_bind(lobby_net, channel_name)
	host = host_id


## The app started again after Android closed it mid-match: back to its seat - whoever runs the match now sends where it
## is (`begun`), or `ended` if nobody does.
func rejoin(lobby_net: LobbyNet, channel_name: String, host_id: int, seat: int, my_name: String) -> void:
	_bind(lobby_net, channel_name)
	host = host_id
	mine = seat
	_my_name = my_name
	_reclaiming = true
	_asks = 0
	_rounds = 0
	_heard.clear()
	_ask(my_name)


## A spectator: ask the host for where the match is now.
func watch(lobby_net: LobbyNet, channel_name: String, host_id: int) -> void:
	_bind(lobby_net, channel_name)
	host = host_id
	net.to(host, {"k": "hello", "ch": ch})


## (the host) a bot for every seat no phone is playing: empty seats, and anyone away or gone (marked so - theirs to
## take back when they're here again).
func _seat_bots() -> void:
	for i in seats.size():
		var s: Dictionary = seats[i]
		var peer := int(s["peer"])
		if peer != 0 and peer != net.id and not bool(s.get("left", false)):
			if not net.members.has(peer) or net.is_away(peer):
				s["away"] = true
			else:   # (here: their own seat)
				s.erase("away")
				bots.erase(i)
		if (peer == 0 or bool(s.get("away", false)) or bool(s.get("left", false))) and not bots.has(i):
			bots[i] = Bot.new(i * 7 + 3, Bot.chosen)


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


func _state_msg() -> Dictionary:
	return {"k": "state", "ch": ch, "host": host, "seats": seats, "mode": mode, "rules": rules,
		"snap": wire(sim.to_dict())}


func _on_channel(c: String, from: int, msg: Dictionary) -> void:
	if c != ch:
		return
	match str(msg.get("k", "")):
		"start":
			if not live:
				_take_start(msg)
		"seg":
			if live and not is_host():
				_mine_pick = []
				turn.emit(int(msg["t"]), msg["picks"], msg["snap"])
		"end":
			live = false
			ended.emit(str(msg.get("reason", "")))
		"sync":   # (whoever runs the match: a phone back after a drop - its seat back, and where it is now)
			if _reclaiming and live:   # (another phone back and asking too: if nobody answers, it's settled between us)
				_heard[from] = [int(msg.get("tick", -1)), int(msg.get("f", 99))]
				return
			if not is_host() or sim == null or not live:
				return
			var f := int(msg.get("f", -1))
			if f >= 0 and f < seats.size():
				var s: Dictionary = seats[f]
				var same := int(s["peer"]) == from
				var named := str(s["name"]) == str(msg.get("name", "")) and int(s["peer"]) != 0 \
						and (bool(s.get("away", false)) or bool(s.get("left", false)) or not net.members.has(int(s["peer"])))
				if not same and not named:
					net.to(from, {"k": "refused", "ch": ch})
					return
				s["peer"] = from
				s.erase("away")
				s.erase("left")
				bots.erase(f)
				if turn_t >= 0 and sim.deciders().has(f):   # (mid-turn: their own pick this turn, with the time to make it)
					picks.erase(f)
					_wait = maxf(_wait, float(rules.get("turn", Sim.RULES["turn"])))
			net.to(from, _state_msg())
		"again":   # (the host back after its own line dropped: where it is now; picks for its open turn again)
			if not live:
				return
			if is_host():   # (two phones running it: the one furthest on keeps it - the other gives way)
				if not _ahead(int(msg.get("t", -1)), int(msg.get("f", 99)), sim.tick if sim != null else -1, mine):
					_say_again()
					return
				turn_t = -1
				picks.clear()
			_reclaiming = false
			_asking = 0.0
			_heard.clear()
			if host != from:
				host = from
				host_changed.emit(host)
			if sim == null or sim.tick != int(msg.get("t", -2)):   # (missed a turn meanwhile: from its state)
				resync.emit(msg["snap"])
			elif not _mine_pick.is_empty() and int(_mine_pick[0]) == int(msg.get("t", -2)):
				net.to(host, {"k": "pick", "ch": ch, "t": _mine_pick[0], "f": mine, "c": _mine_pick[1]})


func _on_direct(from: int, msg: Dictionary) -> void:
	if str(msg.get("ch", "")) != ch:
		return
	match str(msg.get("k", "")):
		"pick":   # (the host: a player's pick for this turn - only for their own fighter)
			var f := int(msg["f"])
			if not is_host() or f >= seats.size() or int(seats[f]["peer"]) != from:
				return
			if int(msg["t"]) == turn_t:
				picks[f] = msg["c"]
				_check()
			elif turn_t < 0 or int(msg["t"]) > turn_t:   # (before the host opened that turn: kept for it)
				_early[f] = [int(msg["t"]), msg["c"]]
		"hello":   # (the host: someone wants to watch - where it is now)
			if is_host() and sim != null:
				net.to(from, _state_msg())
		"state":
			if msg.has("host") and int(msg["host"]) != host:
				host = int(msg["host"])
				turn_t = -1   # (this phone isn't running it now)
				picks.clear()
				host_changed.emit(host)
			if msg.has("seats"):
				seats = msg["seats"]
			if not live:
				_reclaiming = false
				_asking = 0.0
				_take_start(msg)
			elif _reclaiming:   # (back after a drop: from here)
				_reclaiming = false
				_asking = 0.0
				resync.emit(msg["snap"])
		"refused":
			if _reclaiming:
				_reclaiming = false
				_asking = 0.0
				live = false
				ended.emit("Couldn't get back into the match")


## A line dropped (the lobby keeps their place): the host's - the match moves on to the next phone; a player's - the
## host gives their seat to a bot until they're back.
func _on_away(id: int) -> void:
	if not live or id == net.id or _reclaiming:   # (back and asking: it's worked out then - _settle)
		return
	if id == host:
		_move_host(id)
	elif is_host():
		_seat_off(id, "away")


## Someone gone for good: their seat a bot's (the host); the host gone - the match moves on, if anyone can take it.
func _on_left(id: int) -> void:
	if not live:
		return
	if _reclaiming:   # (back and asking: who runs it is worked out then - the host gone for good isn't waited for)
		for st: Dictionary in seats:
			if int(st["peer"]) == id:
				st["left"] = true
		return
	if id == host:
		if not _move_host(id, "left"):
			live = false
			ended.emit("The host left")
		return
	if is_host():
		_seat_off(id, "left")


## (the host) a seat whose phone is away or gone: a bot plays it - at once, if this turn's waiting on it.
func _seat_off(id: int, how: String) -> void:
	for i in seats.size():
		if int(seats[i]["peer"]) == id:
			seats[i][how] = true   # (theirs to take back if they return - sync)
			if how == "left":
				seats[i]["peer"] = 0
			bots[i] = Bot.new(i * 7 + 3, Bot.chosen)
			if turn_t >= 0 and sim != null and sim.deciders().has(i) and not picks.has(i):
				picks[i] = (bots[i] as Bot).choose(sim, i)   # (the bot picks for them now, not at the clock)
	if turn_t >= 0:
		_check()


## The host's line dropped: the match moves to the first seat (in order) whose phone is here - every phone works out the
## same one. False = nobody to take it on (the match waits for the host - it's on their phone).
func _move_host(old: int, how := "away") -> bool:
	var next := 0
	for s: Dictionary in seats:
		var peer := int(s["peer"])
		if peer != 0 and peer != old and not bool(s.get("left", false)) and not bool(s.get("away", false)) \
				and net.members.has(peer) and not net.is_away(peer):
			next = peer
			break
	if next == 0:
		var who := "the host"
		for s: Dictionary in seats:
			if int(s["peer"]) == old:
				who = str(s["name"])
		host_away.emit(who)
		return false
	host = next
	for s: Dictionary in seats:   # (the old host's seat: a bot plays it - until they're back, if it's only away)
		if int(s["peer"]) == old:
			s[how] = true
			if how == "left":
				s["peer"] = 0
	if is_host():   # (this phone runs it now: bots for every seat no phone plays; the turn opens - GameScreen)
		bots.clear()
		_seat_bots()
		turn_t = -1
		picks.clear()
	elif not _mine_pick.is_empty():   # (my pick went to the old host: to the new one)
		net.to(host, {"k": "pick", "ch": ch, "t": _mine_pick[0], "f": mine, "c": _mine_pick[1]})
	host_changed.emit(host)
	return true


## Back in the lobby after the line dropped: listening again, and asking whoever runs the match now for where it is
## (and this phone's seat) - `resync` when it answers. The host back: if nobody took it on, it carries on running it.
func reclaim(my_name: String) -> void:
	aside = false
	if not live:
		return
	net.sub(ch)   # (a new place in the lobby forgets it - the same place keeps it)
	if host == net.id and (not net.was_away or not _others_play()):   # (the host, and nobody noticed it was gone - or
		_resume_hosting()                                              # nobody else could run it: on it goes)
		return
	_reclaiming = true
	_my_name = my_name
	_asks = 0
	_rounds = 0
	_heard.clear()
	_ask(my_name)


## The app put aside (Android: in the background) - the lobby's told; this phone stops running the match until it's
## back and has asked where it is (another phone may have taken it on).
func put_aside() -> void:
	if live:
		aside = true
		_reclaiming = true


## Another phone plays in this match (one that could run it while this one's away).
func _others_play() -> bool:
	for s: Dictionary in seats:
		if int(s["peer"]) != 0 and int(s["peer"]) != net.id and not bool(s.get("left", false)):
			return true
	return false


func _ask(my_name := "") -> void:
	_asks += 1
	_asking = ask_every
	if mine >= 0:
		var who := my_name if my_name != "" else _my_name
		if who == "" and mine < seats.size():
			who = str(seats[mine]["name"])
		net.on_channel(ch, {"k": "sync", "f": mine, "name": who, "tick": sim.tick if sim != null else -1})
	else:
		net.to(host, {"k": "hello", "ch": ch})


## Nobody running the match answered (20 Oct 18:50 "If we both leave the game"): the one running it is here but quiet -
## ask again (a while, then it's taken as gone); it's away (its place kept) and has the match - wait for it; this phone
## ran it, or it's gone - of the phones asking (this one too), the one furthest on runs it (then the first seat).
func _settle() -> void:
	_rounds += 1
	_asks = 0
	if mine < 0:   # (watching: nothing to run)
		_give_up()
		return
	if sim == null:   # (started again - no copy of the match here: wait for the one that has it, while it's kept)
		if net.is_away(host) and _rounds < 50:
			host_away.emit(str(net.members[host]["name"]))
			_ask()
		elif net.members.has(host) and _rounds < ROUNDS:
			_ask()
		else:
			_give_up()
		return
	var host_seated := false
	for st: Dictionary in seats:
		if int(st["peer"]) == host and not bool(st.get("left", false)):
			host_seated = true
	var others := host != net.id and host_seated and not _heard.has(host)
	if others and net.members.has(host) and not net.is_away(host) and _rounds < ROUNDS:
		_ask()
		return
	if others and net.is_away(host):   # (the match is on its phone: wait for it - its place is kept)
		host_away.emit(str(net.members[host]["name"]))
		_ask()
		return
	var best := net.id
	var best_t: int = sim.tick if sim != null else -1
	var best_f := mine
	for p: int in _heard:
		var h: Array = _heard[p]
		if _ahead(int(h[0]), int(h[1]), best_t, best_f):
			best = p
			best_t = int(h[0])
			best_f = int(h[1])
	if best == net.id:
		host = net.id
		_resume_hosting()
	else:   # (that phone runs it once it's done asking - its "again" ends this)
		if host != best:
			host = best
			host_changed.emit(host)
		_ask()


## Is (tick t, seat f) further on than (t2, f2)? The match furthest on wins; level - the first seat.
func _ahead(t: int, f: int, t2: int, f2: int) -> bool:
	return t > t2 or (t == t2 and f < f2)


func _give_up() -> void:
	_reclaiming = false
	_asking = 0.0
	live = false
	ended.emit("Couldn't get back into the match")


## The host back with nobody having taken it on: where it is now to everyone (they may have missed a turn), and the
## open turn's picks again.
func _resume_hosting() -> void:
	_reclaiming = false
	_asking = 0.0
	if sim == null:
		return
	_heard.clear()
	_seat_bots()
	_say_again()
	host_changed.emit(host)   # (the GameScreen opens the turn again - the picks sent meanwhile were lost)


func _say_again() -> void:
	net.on_channel(ch, {"k": "again", "t": sim.tick, "f": mine, "snap": wire(sim.to_dict())})


## The host: a new turn from this state - the bots pick now, the others' picks are awaited.
func open_turn(s: Sim) -> void:
	sim = s
	turn_t = s.tick
	picks.clear()
	_wait = float(rules.get("turn", Sim.RULES["turn"])) + GRACE
	for f in s.deciders():
		if bots.has(f):
			picks[f] = (bots[f] as Bot).choose(s, f)
	for f: int in _early.keys():   # (picks that came early for this turn)
		var e: Array = _early[f]
		if int(e[0]) == turn_t and s.deciders().has(f) and not bots.has(f):
			picks[f] = e[1]
		if int(e[0]) <= turn_t:
			_early.erase(f)
	if mine >= 0 and not _mine_pick.is_empty() and int(_mine_pick[0]) == turn_t and s.deciders().has(mine):
		picks[mine] = _mine_pick[1]   # (this phone picked before the match moved to it)
	_check()


## A pick for fighter f on turn t: the host keeps it; anyone else sends it to the host.
func submit(f: int, choice: Dictionary, t: int) -> void:
	if f == mine:
		_mine_pick = [t, choice]
	if is_host():
		if t == turn_t:
			picks[f] = choice
			_check()
	else:
		net.to(host, {"k": "pick", "ch": ch, "t": t, "f": f, "c": choice})


func _check() -> void:
	if sim == null or turn_t < 0 or not is_host():
		return
	for f in sim.deciders():
		if not picks.has(f):
			return
	_resolve()


func _resolve() -> void:
	var t := turn_t
	var p := picks.duplicate()
	turn_t = -1
	_mine_pick = []
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
		for s in [[net.channel, _on_channel], [net.direct, _on_direct], [net.member_left, _on_left],
				[net.member_away, _on_away]]:
			if (s[0] as Signal).is_connected(s[1]):
				(s[0] as Signal).disconnect(s[1])


func _process(delta: float) -> void:
	if _asking > 0.0 and net != null and net.in_lobby():   # (back after a drop, no answer yet: ask again)
		_asking -= delta
		if _asking <= 0.0:
			if _asks < ASKS:
				_ask()
			else:
				_settle()
	if is_host() and turn_t >= 0 and sim != null:   # (the turn clock ran out: whoever hasn't picked holds)
		_wait -= minf(delta, 0.5)   # (back from another app: the clock goes on from where it was, not to 0)
		if _wait <= 0.0:
			for f in sim.deciders():
				if not picks.has(f):
					picks[f] = {"move": "hold"}
			_resolve()
