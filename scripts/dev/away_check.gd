extends Node
## Dev: phones put aside mid-match, on the real lobby server (20 Oct 18:13 "in the match I minimised it to text someone
## and it killed the match"). Two phones in one process, real WebSockets, real waits. A phone put aside stops running
## altogether - no polls, no pings - as an Android app does in the background.
##   1. a player minimised (Android says so - the app's paused): the host's bot plays their seat at once; back, the
##      seat's theirs again;
##   2. the HOST minimised: the match moves to the other phone at once, a bot in the host's seat; back, a player;
##   3. the phone running it now loses its signal (nothing said - it just stops): the server finds the line dead
##      (45-75 s), the match moves back; back, a player again;
##   4. played to the end - the same ending on both.
##   godot --headless --path . -- --awaycheck [--lobbies=<ws url>]

const SCREEN := preload("res://scripts/ui/game_screen.gd")

var _fails := 0
var started := 0


func _say(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _until(cond: Callable, secs: float) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _wait(secs: float) -> void:
	await _until(func() -> bool: return false, secs)


## A phone put aside - `said`: Android tells the app it's paused (minimised); not said: it just stops (no signal) - or
## back (resumed).
func _aside(g: Control, on: bool, said := true) -> void:
	if on:
		if said:
			g.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		g.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		g.process_mode = Node.PROCESS_MODE_INHERIT
		g.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)


func _t() -> String:
	return "%.0f s" % ((Time.get_ticks_msec() - started) / 1000.0)


func run() -> void:
	LobbyNet.use_loop = false
	print("server: ", LobbyNet.url)
	var a: Control = SCREEN.new()
	var b: Control = SCREEN.new()
	add_child(a)
	add_child(b)
	started = Time.get_ticks_msec()
	a.lobby.open(0)
	a.lobby.lname_edit.text = "Away check"
	a.lobby.public_btn.button_pressed = false
	a.lobby.create_lobby()
	_say(await _until(func() -> bool: return a.lobby.view == "room", 15.0), "a lobby made")
	b.lobby.open(1)
	b.lobby.join(str(a.lobby.net.lobby.get("code", "")))
	_say(await _until(func() -> bool: return a.lobby.net.members.size() == 2 and b.lobby.net.members.size() == 2, 15.0),
		"the other phone joins")
	var a_id: int = a.lobby.net.id
	var b_id: int = b.lobby.net.id
	a.lobby.net.set_lobby({"rules": {"damage": 0.25, "round": 10800}})   # (a long match - it outlasts all three)
	await _until(func() -> bool: return float(a.lobby.rules_now()["damage"]) < 0.3, 5.0)
	a.lobby.challenge([b_id], 0, "ffa")
	_say(await _until(func() -> bool: return b.lobby.modal.visible and not b.lobby._in.is_empty(), 10.0), "challenged")
	b.lobby.answer(true)
	_say(await _until(func() -> bool: return a.net_match != null and b.net_match != null and b.sim != null, 15.0),
		"the match starts")
	a.auto_me = true
	b.auto_me = true
	a._next()
	b._next()
	await _wait(4.0)
	# 1. a player minimised
	var t1: int = a.sim.tick
	_aside(b, true)
	var botted: bool = await _until(func() -> bool: return (a.net_match.bots.has(1)
		and bool(a.net_match.seats[1].get("away", false))), 4.0)
	await _wait(12.0)
	_say(botted and a.sim.tick > t1, "a player minimised: the host's bot plays their seat at once, on it goes (tick %d -> %d)"
		% [t1, a.sim.tick])
	_aside(b, false)
	var back: bool = await _until(func() -> bool: return (not a.net_match.bots.has(1)
		and int(a.net_match.seats[1]["peer"]) == b_id and not b.net_match._reclaiming), 10.0)
	_say(back and b.lobby.net.id == b_id, "...back: the seat's theirs again, caught up (%s)" % _t())
	await _wait(4.0)
	# 2. the host minimised
	_aside(a, true)
	var moved: bool = await _until(func() -> bool: return b.net_match.host == b_id and b.net_match.is_host(), 4.0)
	_say(moved, "the host minimised: the match moves to the other phone at once (%s)" % _t())
	var t2: int = b.sim.tick
	await _wait(10.0)
	_say(b.sim.tick > t2 and b.net_match.bots.has(0), "...and goes on there, a bot in the host's seat (tick %d -> %d)" % [
		t2, b.sim.tick])
	_aside(a, false)
	back = await _until(func() -> bool: return (a.lobby.net.id == a_id and a.net_match.host == b_id
		and not a.net_match._reclaiming and int(b.net_match.seats[0]["peer"]) == a_id and not b.net_match.bots.has(0)), 15.0)
	_say(back, "...the old host back: a player now, its seat back (host %d)" % a.net_match.host)
	await _wait(4.0)
	# 3. the phone running it loses its signal - nothing said
	_aside(b, true, false)
	print("   (the phone running it goes silent - %s)" % _t())
	moved = await _until(func() -> bool: return a.net_match.host == a_id and a.net_match.is_host(), 90.0)
	_say(moved and a.lobby.net.is_away(b_id), "it went silent: the server finds its line dead, the match moves back (%s)"
		% _t())
	var t3: int = a.sim.tick
	await _wait(8.0)
	_say(a.sim.tick > t3, "...and goes on (tick %d -> %d)" % [t3, a.sim.tick])
	_aside(b, false)
	back = await _until(func() -> bool: return (b.lobby.net.id == b_id and b.net_match.host == a_id
		and not b.net_match._reclaiming and int(a.net_match.seats[1]["peer"]) == b_id and not a.net_match.bots.has(1)), 30.0)
	_say(back, "...back from no signal: its own place, a player, its seat back (%s)" % _t())
	var over := func() -> bool:
		for g: Control in [a, b]:
			g.finish_playback()
		return a.phase == "over" and b.phase == "over"
	_say(await _until(over, 300.0) and a.sim.tick == b.sim.tick and a.sim.winners() == b.sim.winners(),
		"played to the end, the same on both (tick %d / %d, %s / %s)" % [a.sim.tick, b.sim.tick, a.sim.winners(),
		b.sim.winners()])
	for g: Control in [a, b]:
		g._leave_match()
		g.lobby.leave_lobby()
	await _wait(1.0)
	print("%s - %d failed, %s in all" % ["ALL PASS" if _fails == 0 else "FAILED", _fails, _t()])
	get_tree().quit(1 if _fails > 0 else 0)
