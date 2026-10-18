extends Node
## Dev: the online test on the real lobby server - three phones in one process, real WebSockets, real waits. A private
## lobby, a challenge with a bot in the third seat played to the end, one phone watching; every phone must end the same.
##   godot --headless --path . -- --livecheck [--lobbies=<wss url>]

const SCREEN := preload("res://scripts/ui/game_screen.gd")

var _fails := 0


func _say(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


## Wait (real time) until cond is true; false after `secs`.
func _until(cond: Callable, secs: float) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func run() -> void:
	LobbyNet.use_loop = false
	print("server: ", LobbyNet.url)
	var gs: Array = []
	for i in 3:
		var g: Control = SCREEN.new()
		add_child(g)
		gs.append(g)
	var a: Control = gs[0]
	var b: Control = gs[1]
	var c: Control = gs[2]
	var started := Time.get_ticks_msec()
	a.lobby.open(0)
	a.lobby.lname_edit.text = "Live check"
	a.lobby.public_btn.button_pressed = false   # (kept off the public list)
	a.lobby.create_lobby()
	_say(await _until(func() -> bool: return a.lobby.view == "room", 15.0), "a lobby made on the server")
	var code := str(a.lobby.net.lobby.get("code", ""))
	b.lobby.open(1)
	b.lobby.join(code)
	c.lobby.open(2)
	c.lobby.join(code)
	var all_in := func() -> bool:
		return a.lobby.net.members.size() == 3 and b.lobby.net.members.size() == 3 and c.lobby.net.members.size() == 3
	_say(await _until(all_in, 15.0), "two more join it by its code (%s)" % code)
	b.lobby.chat_edit.text = "live hello"
	b.lobby._send_chat()
	_say(await _until(func() -> bool: return a.lobby.chat_log.text.contains("live hello"), 10.0), "chat")
	a.lobby.challenge([b.lobby.net.id], 1, "ffa")
	_say(await _until(func() -> bool: return b.lobby.modal.visible and not b.lobby._in.is_empty(), 10.0),
		"the challenge reaches the other phone")
	b.lobby.answer(true)
	var begun := func() -> bool:
		return a.net_match != null and b.net_match != null and b.sim != null and b.sim.fighters.size() == 3
	_say(await _until(begun, 15.0), "accepted: the match starts on both, three fighters")
	_say(await _until(func() -> bool: return c.lobby.matches().size() == 1, 10.0), "the third phone sees the match")
	c.lobby.spectate(str(c.lobby.matches()[0]["ch"]), a.lobby.net.id)
	_say(await _until(func() -> bool: return c.net_match != null and c.me == -1, 15.0), "...and watches it")
	a.auto_me = true
	b.auto_me = true
	a._next()
	b._next()
	var t0 := Time.get_ticks_msec()
	var over := func() -> bool:
		for g: Control in gs:
			g.finish_playback()
		return a.phase == "over" and b.phase == "over" and c.phase == "over"
	var done := await _until(over, 300.0)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_say(done, "played to the end on all three (%.1f s, tick %d)" % [secs, a.sim.tick])
	var same: bool = a.sim.tick == b.sim.tick and a.sim.tick == c.sim.tick
	for i in 3:
		same = same and a.sim.fighters[i].hp == b.sim.fighters[i].hp and a.sim.fighters[i].hp == c.sim.fighters[i].hp
	_say(same and a.sim.winners() == b.sim.winners(), "the same ending everywhere (winners %s / %s / %s)" % [
		a.sim.winners(), b.sim.winners(), c.sim.winners()])
	for g: Control in gs:
		g._leave_match()
	for g: Control in gs:
		g.lobby.leave_lobby()
	await _until(func() -> bool: return false, 1.0)
	print("%s - %d failed, %.1f s in all" % ["ALL PASS" if _fails == 0 else "FAILED", _fails,
		(Time.get_ticks_msec() - started) / 1000.0])
	get_tree().quit(1 if _fails > 0 else 0)
