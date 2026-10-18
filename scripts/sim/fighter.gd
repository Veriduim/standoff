class_name Fighter
extends RefCounted
## One fighter's state in the sim - plain data, copied whole for snapshots (the host sends them to every phone) and for
## the ghost previews. Nothing here draws or knows about the network.

var id := 0
var team := 0            ## free-for-all: every fighter its own team; teams: shared numbers, no friendly fire
var character := "bruiser"
var name := ""
var pos := Vector2.ZERO  ## between the feet; y down, the ground at 0
var vel := Vector2.ZERO
var facing := 1          ## +1 right, -1 left
var hp := 100
var max_hp := 100
var meter := 0
var target := -1         ## who they're facing / aiming at (-1 = the nearest enemy)

var move := ""           ## the move running ("" = free)
var frame := 0           ## frames into it
var length := 0          ## its length this time (a param can stretch it)
var param := Vector2.ZERO  ## what was picked with it (direction / distance / frame number)
var instance := 0        ## counts up each move started - hits are once per target per instance and group
var hit_done := {}       ## "group:target" -> true for the running move

var stun := 0            ## hitstun frames left (can't act, knocked about)
var blockstun := 0       ## frames left reeling from a blocked hit
var lock := 0            ## other frames they can't act (landing lag, a clash's recoil)
var combo := 0           ## hits taken in a row (damage scales down)
var air_moves := 0       ## air dashes used since leaving the ground
var ko := false


func grounded() -> bool:
	return pos.y >= 0.0 and vel.y >= 0.0


## Free to choose: alive, not reeling, not in a move.
func actionable() -> bool:
	return not ko and stun == 0 and blockstun == 0 and lock == 0 and move == ""


func to_dict() -> Dictionary:
	return {"id": id, "team": team, "character": character, "name": name, "pos": [pos.x, pos.y],
		"vel": [vel.x, vel.y], "facing": facing, "hp": hp, "max_hp": max_hp, "meter": meter, "target": target,
		"move": move, "frame": frame, "length": length, "param": [param.x, param.y], "instance": instance,
		"hit_done": hit_done.keys(), "stun": stun, "blockstun": blockstun, "lock": lock, "combo": combo,
		"air_moves": air_moves, "ko": ko}


static func from_dict(d: Dictionary) -> Fighter:
	var f := Fighter.new()
	f.id = int(d["id"])
	f.team = int(d["team"])
	f.character = str(d["character"])
	f.name = str(d.get("name", ""))
	f.pos = Vector2(float(d["pos"][0]), float(d["pos"][1]))
	f.vel = Vector2(float(d["vel"][0]), float(d["vel"][1]))
	f.facing = int(d["facing"])
	f.hp = int(d["hp"])
	f.max_hp = int(d["max_hp"])
	f.meter = int(d["meter"])
	f.target = int(d["target"])
	f.move = str(d["move"])
	f.frame = int(d["frame"])
	f.length = int(d["length"])
	f.param = Vector2(float(d["param"][0]), float(d["param"][1]))
	f.instance = int(d["instance"])
	for k in d["hit_done"]:
		f.hit_done[str(k)] = true
	f.stun = int(d["stun"])
	f.blockstun = int(d["blockstun"])
	f.lock = int(d["lock"])
	f.combo = int(d["combo"])
	f.air_moves = int(d["air_moves"])
	f.ko = bool(d["ko"])
	return f
