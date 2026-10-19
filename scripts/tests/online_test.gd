extends TestSuite
## Online (Timmy 20:19 - the lobby system, YOMI's Steam lobby): three phones on the in-process lobby server (LoopLobby -
## the same rules as relay/src/index.js, every message through JSON as on the wire). A lobby made and listed, joined,
## chat, the owner's rules; a challenge with a bot in the third seat played to the end on all of them, one phone
## watching; the host leaving.

const SCREEN := preload("res://scripts/ui/game_screen.gd")


func _screen() -> Control:
	PickPanel.forget()   # (no remembered pick from earlier play; nothing written)
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
	var bp: PickPanel = b.pick
	_check("the other phone sees itself on the left (its tabs, its card in its colour) and its enemy on the right",
			bp.visible and bp.me == 1 and bp.foe == 0 and bp.tabs_box.position.x < 200.0
			and ((bp.cards["me"]["panel"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color
				== b.stage.colour_of(1))
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


## The line dropping (the phone put aside to send the code - Timmy 00:11): what the lobby server would do, then the
## screen gets it back.
func _drop(g: Control) -> void:
	var n: LobbyNet = g.lobby.net
	n.loop.leave(n)
	n.loop = null
	n.id = 0
	n.status.emit("closed", "Lost the lobby server")


func _test_rejoin() -> void:
	_section("Put aside and back (Timmy 00:11): the lobby waits, the phone gets back in by itself; Copy code")
	LobbyNet.use_loop = true
	LoopLobby.reset()
	var a := _screen()
	var b := _screen()
	a.lobby.open(0)
	a.lobby.create_lobby()
	_poll([a, b])
	var code := str(a.lobby.net.lobby["code"])
	_drop(a)   # (alone in it, and gone)
	for _i in 4:
		_poll([a, b])
		await get_tree().create_timer(0.35).timeout
	_check("alone, dropped: the lobby waited and the phone's back in it (view %s, code %s)" % [a.lobby.view,
			a.lobby.net.lobby.get("code", "")], a.lobby.view == "room" and a.lobby.net.in_lobby()
			and str(a.lobby.net.lobby.get("code", "")) == code)
	b.lobby.open(1)
	b.lobby.join(code)
	_poll([a, b])
	_drop(b)
	for _i in 4:
		_poll([a, b])
		await get_tree().create_timer(0.35).timeout
	_check("a friend dropped and back: both in it again", b.lobby.net.in_lobby() and a.lobby.net.members.size() == 2
			and b.lobby.net.members.size() == 2)
	a.lobby._copy_code()
	var copy := a.lobby.room_view.find_child("CopyCode", true, false) as Button
	_check("Copy code copies it and says so (%s)" % copy.text, copy.text == "Copied %s" % code
			and (DisplayServer.get_name() == "headless" or DisplayServer.clipboard_get() == code))
	b.lobby.leave_lobby()
	_poll([a, b])
	_check("leaving on purpose doesn't come back", not b.lobby.net.in_lobby() and not b.lobby.net.want_back)
	a.queue_free()
	b.queue_free()
	LobbyNet.use_loop = false


## Frames until `cond` holds (or `secs` pass) - real sockets need real time.
func _until(cond: Callable, secs := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _test_nearby() -> void:
	_section("Nearby play (00:43 \"1 sounds like a pretty good soultion\"): a phone hosts, another finds it and joins")
	LobbyNet.use_loop = false
	LoopLobby.reset()
	LanHost.bind_to = "127.0.0.1"   # (this PC only)
	var keep := LobbyNet.url
	var a := _screen()
	var b := _screen()
	a.lobby.open(0)
	a.lobby.set_nearby(true)
	a.lobby.lname_edit.text = "Nearby Test"
	a.lobby.create_lobby()
	var hosting: bool = await _until(func() -> bool: return a.lobby.view == "room")
	_check("Create on Nearby: this phone hosts the lobby and is in it, its owner", hosting and a.lobby.host != null
			and LanHost.active != null and a.lobby.net.is_owner() and a.lobby.title.text == "Nearby Test")
	b.lobby.open(1)
	b.lobby.set_nearby(true)
	var seen: bool = await _until(func() -> bool: return b.lobby.lobbies.size() == 1)   # (no address: it's just there)
	if seen:
		b.lobby.join_lobby(b.lobby.lobbies[0])
	var joined: bool = await _until(func() -> bool: return b.lobby.view == "room" and a.lobby.net.members.size() == 2)
	_check("the other phone's Nearby list finds it by itself, and it joins (%s)" % [b.lobby.finder.list()], seen
			and joined
			and b.lobby.title.text == "Nearby Test" and b.lobby.code_label.text.begins_with("Nearby lobby"))
	b.lobby.net.say("hello from nearby")
	var heard: bool = await _until(func() -> bool: return a.lobby.net.log.any(func(e: Array) -> bool:
			return str(e[1]) == "hello from nearby"))
	_check("chat goes through the host phone", heard)
	a.lobby.challenge([b.lobby.net.id], 0, "ffa")
	var asked: bool = await _until(func() -> bool: return b.lobby.modal.visible and not b.lobby._in.is_empty())
	b.lobby.answer(true)
	var started: bool = await _until(func() -> bool: return a.net_match != null and b.net_match != null)
	_check("a challenge over the Wi-Fi: the match starts on both", asked and started)
	if started:
		a.auto_me = true   # (bots play for both - the picks go phone to phone through the host phone)
		b.auto_me = true
		a._next()
		b._next()
		var end := Time.get_ticks_msec() + 90000
		while Time.get_ticks_msec() < end and not (a.phase == "over" and b.phase == "over"):
			for g: Control in [a, b]:
				g.finish_playback()
			await get_tree().process_frame
		_check("...played to the end, the same on both (tick %d / %d, %s / %s)" % [a.sim.tick, b.sim.tick, a.phase,
				b.phase], a.phase == "over" and b.phase == "over" and a.sim.tick == b.sim.tick
				and a.sim.winners() == b.sim.winners())
		for g: Control in [a, b]:
			g._leave_match()
		await _until(func() -> bool: return a.lobby.view == "room" and b.lobby.view == "room")
	a.lobby.leave_lobby()
	var dropped: bool = await _until(func() -> bool: return b.lobby.view == "list", 6.0)
	_check("the host leaving takes the lobby with it: the other phone is back at the list, told why (%s)"
			% b.lobby.note.text, LanHost.active == null and dropped and b.lobby.note.text == "The host closed the lobby")
	b.lobby.set_nearby(false)
	LobbyNet.url = keep
	LanHost.bind_to = "*"
	a.queue_free()
	b.queue_free()



func _test_match_rejoin() -> void:
	_section("Back into a match after a drop (01:32 \"3 makes sense\"): the bot hands the seat back, and on it goes")
	LobbyNet.use_loop = true
	LoopLobby.reset()
	var a := _screen()
	var b := _screen()
	a.lobby.open(0)
	a.lobby.create_lobby()
	_poll([a, b])
	b.lobby.open(1)
	b.lobby.join(str(LoopLobby.list()[0]["code"]))
	_poll([a, b])
	a.lobby.challenge([b.lobby.net.id], 0, "ffa")
	_poll([a, b])
	b.lobby.answer(true)
	_poll([a, b], 6)
	a.auto_me = true
	b.auto_me = true
	a._next()
	b._next()
	for _i in 60:   # (a few turns in)
		_poll([a, b], 2)
		for g: Control in [a, b]:
			g.finish_playback()
		if a.sim.tick > 120:
			break
	_drop(b)
	_poll([a, b], 3)
	var bot_seat: bool = int(a.net_match.seats[1]["peer"]) == 0 and bool(a.net_match.seats[1].get("left", false))
	var said: String = b.banner.text
	for _i in 30:   # (the match goes on without them meanwhile - their bot plays)
		_poll([a, b], 2)
		a.finish_playback()
	var went_on: int = a.sim.tick
	for _i in 4:
		_poll([a, b])
		await get_tree().create_timer(0.35).timeout
	_poll([a, b], 6)
	_check("dropped mid-match: the host's bot takes the seat; their screen says so (\"%s\")" % said, bot_seat
			and said.begins_with("Connection lost"))
	_check("back in the lobby, they get the seat back and the host's state (host tick %d, theirs %d)" % [a.sim.tick,
			b.sim.tick], b.lobby.net.in_lobby() and int(a.net_match.seats[1]["peer"]) == b.lobby.net.id
			and not b.net_match._reclaiming and b.net_match.live and b.sim.tick >= went_on)
	var steps := 0
	while steps < 3000 and not (a.phase == "over" and b.phase == "over"):
		_poll([a, b], 2)
		for g: Control in [a, b]:
			g.finish_playback()
		steps += 1
	_check("...and the match plays out to the same end on both (%s / %s, tick %d / %d)" % [a.phase, b.phase,
			a.sim.tick, b.sim.tick], a.phase == "over" and b.phase == "over" and a.sim.tick == b.sim.tick
			and a.sim.winners() == b.sim.winners())
	for g: Control in [a, b]:
		g.queue_free()
	LobbyNet.use_loop = false
