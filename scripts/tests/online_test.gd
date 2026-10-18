extends TestSuite
## Online (Timmy 20:19 - the lobby system, YOMI's Steam lobby): three phones on the in-process lobby server (LoopLobby -
## the same rules as relay/src/index.js, every message through JSON as on the wire). A lobby made and listed, joined,
## chat, the owner's rules; a challenge with a bot in the third seat played to the end on all of them, one phone
## watching; the host leaving.

const SCREEN := preload("res://scripts/ui/game_screen.gd")


func _screen() -> Control:
	var g: Control = SCREEN.new()
	add_child(g)
	return g


func _poll(gs: Array, times := 3) -> void:
	for _i in times:
		for g: Control in gs:
			(g.lobby.net as LobbyNet).poll()


func _test_lobby() -> void:
	_section("A lobby: made, listed, joined, chat, the owner's rules")
	LobbyNet.use_loop = true
	LoopLobby.reset()
	var a := _screen()
	var b := _screen()
	a.lobby.open(0)
	a.lobby.lname_edit.text = "Test Lobby"
	a.lobby.create_lobby()
	_poll([a, b])
	_check("making a lobby puts you in it, as its owner", a.lobby.view == "room" and a.lobby.net.is_owner()
			and a.lobby.title.text == "Test Lobby")
	var listed := LoopLobby.list()
	_check("it's on the public list (%s)" % [listed], listed.size() == 1 and int(listed[0]["players"]) == 1
			and str(listed[0]["version"]) == Version.TAG)
	b.lobby.open(1)
	b.lobby.join(str(listed[0]["code"]))
	_poll([a, b])
	_check("joining it by its code: both see both", b.lobby.view == "room" and a.lobby.net.members.size() == 2
			and b.lobby.net.members.size() == 2 and not b.lobby.net.is_owner())
	b.lobby.chat_edit.text = "hello there"
	b.lobby._send_chat()
	_poll([a, b])
	_check("chat reaches the lobby", a.lobby.chat_log.text.contains("hello there"))
	a.lobby._bump("turn", 1)
	_poll([a, b])
	_check("the owner's rules reach everyone (turn clock %s)" % b.lobby.rules_now()["turn"],
			int(b.lobby.rules_now()["turn"]) == 35)
	a.queue_free()
	b.queue_free()
	_poll([])


func _test_online_match() -> void:
	_section("A challenge played to the end on every phone (one watching); the host leaving")
	LobbyNet.use_loop = true
	LoopLobby.reset()
	var a := _screen()
	var b := _screen()
	var c := _screen()
	a.lobby.open(0)
	a.lobby.create_lobby()
	_poll([a, b, c])
	var code := str(LoopLobby.list()[0]["code"])
	b.lobby.open(1)
	b.lobby.join(code)
	c.lobby.open(2)
	c.lobby.join(code)
	_poll([a, b, c])
	var b_id: int = b.lobby.net.id
	a.lobby.challenge([b_id], 1, "ffa")
	_poll([a, b, c])
	_check("the challenge comes up on theirs", b.lobby.modal.visible and not b.lobby._in.is_empty())
	b.lobby.answer(true)
	_poll([a, b, c], 6)
	_check("accepted: the match starts on both - three fighters, one a bot (%s / %s)" % [a.phase, b.phase],
			a.net_match != null and b.net_match != null and a.sim.fighters.size() == 3
			and b.sim.fighters.size() == 3 and a.me == 0 and b.me == 1)
	_check("...the lobby lists it", c.lobby.matches().size() == 1)
	c.lobby.spectate(str(c.lobby.matches()[0]["ch"]), a.lobby.net.id)
	a.auto_me = true   # (bots play for both from here - their turns already up go in now)
	b.auto_me = true
	a._next()
	b._next()
	var steps := 0
	while steps < 3000 and not (a.phase == "over" and b.phase == "over" and c.phase == "over"):
		_poll([a, b, c], 2)
		for g: Control in [a, b, c]:
			g.finish_playback()
		steps += 1
	_check("watching: the third phone follows it", c.net_match != null and c.me == -1)
	_check("it's played to the end on all three (%s / %s / %s after %d rounds)" % [a.phase, b.phase, c.phase, steps],
			a.phase == "over" and b.phase == "over" and c.phase == "over")
	var same: bool = a.sim.tick == b.sim.tick and a.sim.tick == c.sim.tick
	for i in 3:
		same = same and a.sim.fighters[i].hp == b.sim.fighters[i].hp and a.sim.fighters[i].hp == c.sim.fighters[i].hp
	_check("...and ends the same everywhere (tick %d, winners %s / %s / %s)" % [a.sim.tick, a.sim.winners(),
			b.sim.winners(), c.sim.winners()], same and a.sim.winners() == b.sim.winners())
	for g: Control in [a, b, c]:
		g._leave_match()
	_poll([a, b, c])
	_check("back in the lobby after", a.lobby.visible and a.lobby.view == "room" and b.lobby.view == "room")
	b.lobby.challenge([a.lobby.net.id], 0, "ffa")
	_poll([a, b, c])
	a.lobby.answer(true)
	_poll([a, b, c], 6)
	_check("a second match (they host it this time)", a.net_match != null and b.net_match != null and b.net_match.is_host())
	b.lobby.leave_lobby()
	_poll([a, b, c], 4)
	_check("the host leaving ends it for the other (%s)" % (a.over_panel.find_child("Result", true, false) as Label).text,
			a.phase == "over" and (a.over_panel.find_child("Result", true, false) as Label).text.contains("host left"))
	for g: Control in [a, b, c]:
		g.queue_free()
	LobbyNet.use_loop = false
