extends SceneTree
## Dev: share a saved replay on the live lobby server and fetch it back by its code (19 Oct 02:36).
##   godot --headless --path . -s scripts/dev/share_check.gd

func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var paths := Replays.paths()
	if paths.is_empty():
		print("no saved replays to share")
		quit(1)
		return
	var list := ReplayList.new()
	root.add_child(list)
	await process_frame
	list.open()
	list.share(str(paths[0]))
	var code := ""
	for _i in 600:
		await process_frame
		var t: String = list._note.text
		if t.begins_with("Replay code "):
			code = t.get_slice(" ", 2)
			break
		if not t.begins_with("Sharing") and t != "":
			break
	print("shared: ", list._note.text)
	if code == "":
		quit(1)
		return
	var got := [""]
	list.picked.connect(func(p: String) -> void: got[0] = p)
	list.watch_code(code)
	for _i in 600:
		await process_frame
		if got[0] != "":
			break
	var rec := Replays.load_rec(got[0]) if got[0] != "" else {}
	var orig := Replays.load_rec(str(paths[0]))
	var same: bool = not rec.is_empty() and (rec["turns"] as Array).size() == (orig["turns"] as Array).size()
	print("fetched back by code %s: %s (%d turns)" % [code, "the same" if same else "DIFFERENT", (rec.get("turns", []) as Array).size()])
	if got[0] != "":
		DirAccess.remove_absolute(got[0])
	quit(0 if same else 1)
