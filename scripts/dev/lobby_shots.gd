extends Node
## Dev: screenshots of the lobby screens on the in-process lobby server - the list, a lobby (members, a match going on,
## the rules, chat), an invite.   godot --path . -- --lobbyshots=<dir>


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func run(game: Control, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	LobbyNet.use_loop = true
	LoopLobby.reset()
	var others: Array = []
	for n: Array in [["Ana", "Friday fights", 6], ["Ben", "Ben's Lobby", 8]]:   # (two lobbies already up)
		var o := LobbyNet.new()
		add_child(o)
		o.create(LobbyNet.new_code(), str(n[0]), str(n[1]), true, int(n[2]))
		others.append(o)
	await _wait(5)
	game.home.visible = false
	game.lobby.open(0)
	game.lobby.name_edit.text = "Timmy"
	game.lobby._set_name("Timmy")
	await _wait(20)
	await _snap(out.path_join("L1_list.png"))
	game.lobby.lname_edit.text = "Timmy's Standoff"
	game.lobby.create_lobby()
	await _wait(5)
	var code := str(game.lobby.net.lobby["code"])
	for n: Array in [["Ana", 1], ["Ben", 3], ["Cass", 4]]:
		var o := LobbyNet.new()
		add_child(o)
		o.join(code, str(n[0]))
		await _wait(3)
		o.set_member({"status": "idle", "colour": int(n[1]), "match": ""})
		others.append(o)
	await _wait(5)
	var ben: LobbyNet = others[3]
	var cass: LobbyNet = others[4]
	for o: LobbyNet in [ben, cass]:   # (Ben and Cass in a match)
		o.set_member({"status": "in a match", "match": "m9-1", "host": ben.id, "bots": 1})
	(others[2] as LobbyNet).say("anyone up for a 4-way?")
	ben.say("gg")
	game.lobby._bump("turn", 1)
	await _wait(20)
	await _snap(out.path_join("L2_room.png"))
	(others[2] as LobbyNet).to(game.lobby.net.id, {"k": "invite", "ch": "m2-5", "name": "Ana", "size": 3, "mode": "ffa",
		"bots": 1})
	await _wait(20)
	await _snap(out.path_join("L3_invite.png"))
	game.lobby.modal.visible = false
	game.lobby._in = {}
	game.lobby._new_match()
	await _wait(2)
	(game.lobby.modal.find_child("Pick%d" % (others[2] as LobbyNet).id, true, false) as Button).button_pressed = true
	await _wait(20)
	await _snap(out.path_join("L4_new_match.png"))
	get_tree().quit()
