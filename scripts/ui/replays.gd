class_name Replays
extends RefCounted
## Saved replays (Timmy 19 Oct 02:15: "When can I save replays??"): every finished match is kept, YOMI's way - the
## match as it started and every turn's picks (the sim is deterministic, so playing the picks again plays the match
## again), small enough to keep the last KEEP. user://replays/<when>.json.

const DIR := "user://replays"
const KEEP := 30


static var device_dir := ""   ## where "Save to phone" puts a copy ("" = the phone's Download/Standoff Replays)


## The phone's own folder for replays: Download/Standoff Replays (02:19 "Would love to save them to device").
static func device_folder() -> String:
	if device_dir != "":
		return device_dir
	return OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join("Standoff Replays")


## A copy of a saved replay on the phone, named by when it was played; its path, or "" if it couldn't.
static func export_to_device(path: String) -> String:
	if OS.get_name() == "Android":
		OS.request_permissions()   # (older Androids ask before anything goes in Download)
	var rec := load_rec(path)
	if rec.is_empty():
		return ""
	var dir := device_folder()
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(int(rec.get("when", 0)))
	var out := dir.path_join("standoff_%04d-%02d-%02d_%02d%02d%02d.json" % [int(dt["year"]), int(dt["month"]),
		int(dt["day"]), int(dt["hour"]), int(dt["minute"]), int(dt["second"])])
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(rec, "", false, true))
	f.close()
	return out


## Save a finished match's record: {v, when, names, colours, me, mode, result, start, turns}.
static func save(rec: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join("%d_%03d.json" % [int(rec["when"]), randi() % 1000])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(rec, "", false, true))
	f.close()
	var all := paths()
	while all.size() > KEEP:   # (the oldest go)
		DirAccess.remove_absolute(all.pop_back())
	return path


## The saved replays, newest first.
static func paths() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for n in d.get_files():
		if n.ends_with(".json"):
			out.append(DIR.path_join(n))
	out.sort()
	out.reverse()
	return out


static func load_rec(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## A line for the list: when, who, how it ended (and if it's from another version - it may play out differently).
static func describe(rec: Dictionary) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var dt := Time.get_datetime_dict_from_unix_time(int(rec.get("when", 0)) + bias * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var when := "%d %s %02d:%02d" % [int(dt["day"]), months[int(dt["month"]) - 1], int(dt["hour"]), int(dt["minute"])]
	var names: Array = rec.get("names", [])
	var who := " vs ".join(PackedStringArray(names)) if names.size() <= 2 else "%s + %d" % [str(names[0]), names.size() - 1]
	var line := "%s  ·  %s  ·  %s" % [when, who, str(rec.get("result", ""))]
	if str(rec.get("v", "")) != Version.TAG:
		line += "  ·  v" + str(rec.get("v", "?"))
	return line


## Play the record's turns again: the turns as the replay shows them [{frames, events, shots, first}] and the sim at
## the end.
static func rebuild(rec: Dictionary) -> Array:
	var s := Sim.from_dict(rec["start"])
	var segs: Array = []
	for turn: Dictionary in rec.get("turns", []):
		if turn.has("s"):   # (online, a jump to the host's state - a phone back after a drop)
			s = Sim.from_dict(turn["s"])
			continue
		var picks := {}
		var p: Dictionary = turn["p"]
		for k in p:
			picks[int(k)] = p[k]
		s.apply(picks)
		var seg := s.run_segment()
		var frames: Array = seg["frames"]
		segs.append({"frames": frames, "events": seg["events"], "shots": seg.get("shots", []),
			"first": int(seg["end_tick"]) - frames.size() + 1})
	return [segs, s]
