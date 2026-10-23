class_name Fighter
extends RefCounted
## One fighter's state in the sim - plain data, copied whole for snapshots (the host sends them to every phone) and for
## the ghost previews. Nothing here draws or knows about the network.

var id := 0
var team := 0            ## free-for-all: every fighter its own team; teams: shared numbers, no friendly fire
var character := "dancer"
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
var burst := 0           ## the Burst gauge - fills with time (and hits taken); Sim.BURST_FULL = ready
var di := Vector2.ZERO   ## the way they lean while reeling (picked on their reeling turns) - nudges their knockback
var combo_used := {}     ## this combo, move id -> [times it's been used on them, that move's instance] (reuse = less stun)
var cancelled := ""      ## the move they just hit-cancelled out of (not pickable again until they start another)
var cancel_frame := 0    ## ...the frame it was on (they're drawn holding it until they pick)
var fc := 2              ## Free Cancels left (Sim.FC_MAX)
var freed := false       ## the attack running was Free Cancelled - it gives way when anyone else can act
var whiffed := false     ## just Whiff Cancelled: attacks only on this pick
var down := 0            ## knocked down: ticks until they get up by themselves (0 = not down)
var down_pick := false   ## just hit the floor - the match stops for their getting-up pick
var kd := false          ## the hit that has them reeling knocks down when they land
var sad := 0             ## Sadness (Sim.SAD_MAX = SADNESS!) - builds while they hang back
var sadness := 0         ## ticks of SADNESS! left
var sad_warned := false  ## SAD! shown for this build-up
var dist := 1.0          ## how far the running dash / jump goes (0-1, the Distance slider)
var parry_at := 0        ## the Block's parry frame (0 = just blocking)
var pushed := 0          ## ticks a Push Block's shove keeps their own move from pushing them
var prorate := 0         ## the combo on them started this many hits in (the starter's proration)
var bounce_due := false  ## the hit on them bounces them off the ground when they land
var bounced := false     ## ...used up for this combo
var bounce_up := 0.0     ## ...how hard it sends them up (0 = Sim.BOUNCE_UP)
var pinned := 0          ## ticks left held flat on the floor before that bounce (Barrage's finish - 23 Oct)
var splat_due := false   ## the hit on them sticks them to the wall if they reach it
var splats := 0          ## wall splats this combo (3 at most)
var splat := 0           ## ticks left stuck to the wall
var launched := false    ## the combo on them is in the air (sent up, or hit up there) - landing ends it (Sim.RESTAND)
var restand := 0         ## ticks left in which a hit as they land keeps the combo going
var stance := ""         ## the stance they're in ("" = none) - its moves are open while it lasts
var initiative := false  ## started their move while the nearest enemy was choosing too (some moves get more for it)
## the x-factors on trial (Sim.xf)
var fans := 2            ## Fans: fans in hand (Sim.FANS_MAX) - a thrown one comes back
var tempo := 0           ## Tempo: beats (Sim.TEMPO_MAX)
var tempo_key := ""      ## ...what gave the last one (a move / a fan / a dodge gives one beat, once)
var tempo_idle := 0      ## ...ticks since then (a beat fades every Sim.TEMPO_FADE)
var form := "flow"       ## Forms: "flow" | "snap" | "floor"
var grit := 0            ## the Bruiser's Grit (Sim.GRIT_MAX = the K.O. Punch is there)
var armor_left := 0      ## hits the running move's Super Armor can still take (one, as a rule)
var hit_look := "head"   ## how the last hit landed on them - their reaction (Sim.LOOKS: head, body, low, crush, slide, air)
var hit_t := 0           ## ...ticks since it landed (the reaction snaps, then eases off)
var slide := 0           ## ticks a fling keeps them sliding (Sim.FLING_FRICTION)
var repeats := 0         ## times in a row they've gone again into a move that repeats (the clinch knee)
var ko := false


func grounded() -> bool:
	return pos.y >= 0.0 and vel.y >= 0.0


## Free to choose: alive, not reeling, not in a move.
## The combo on them is over: everything it was counting starts again.
func combo_over() -> void:
	combo = 0
	combo_used.clear()
	di = Vector2.ZERO
	prorate = 0
	bounce_due = false
	bounced = false
	bounce_up = 0.0
	pinned = 0
	splat_due = false
	splats = 0
	launched = false
	restand = 0


func actionable() -> bool:
	return not ko and stun == 0 and blockstun == 0 and lock == 0 and down == 0 and move == ""


## Ticks until they can act (reeling, blocking, locked, lying down, then what's left of their move) - the frame
## advantage a free fighter has on them. A move that ends on landing counts its full length.
func busy() -> int:
	if ko:
		return 0
	return stun + blockstun + lock + down + (maxi(0, length - frame) if move != "" else 0)


func to_dict() -> Dictionary:
	return {"id": id, "team": team, "character": character, "name": name, "pos": [pos.x, pos.y],
		"vel": [vel.x, vel.y], "facing": facing, "hp": hp, "max_hp": max_hp, "meter": meter, "target": target,
		"move": move, "frame": frame, "length": length, "param": [param.x, param.y], "instance": instance,
		"hit_done": hit_done.keys(), "stun": stun, "blockstun": blockstun, "lock": lock, "combo": combo,
		"air_moves": air_moves, "burst": burst, "di": [di.x, di.y], "combo_used": combo_used.duplicate(true),
		"cancelled": cancelled, "cancel_frame": cancel_frame, "fc": fc, "freed": freed, "whiffed": whiffed, "down": down, "down_pick": down_pick,
		"kd": kd, "sad": sad, "sadness": sadness, "sad_warned": sad_warned, "dist": dist, "parry_at": parry_at, "pushed": pushed, "prorate": prorate, "bounce_due": bounce_due, "bounced": bounced, "bounce_up": bounce_up, "pinned": pinned,
		"splat_due": splat_due, "splats": splats, "splat": splat, "launched": launched, "restand": restand, "stance": stance, "initiative": initiative, "fans": fans, "tempo": tempo,
		"tempo_key": tempo_key, "tempo_idle": tempo_idle, "form": form, "grit": grit, "armor_left": armor_left,
		"repeats": repeats, "slide": slide, "hit_look": hit_look, "hit_t": hit_t, "ko": ko}


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
	f.burst = int(d.get("burst", 0))
	var lean: Array = d.get("di", [0.0, 0.0])
	f.di = Vector2(float(lean[0]), float(lean[1]))
	f.combo_used = (d.get("combo_used", {}) as Dictionary).duplicate(true)
	f.cancelled = str(d.get("cancelled", ""))
	f.cancel_frame = int(d.get("cancel_frame", 0))
	f.fc = int(d.get("fc", 2))
	f.freed = bool(d.get("freed", false))
	f.whiffed = bool(d.get("whiffed", false))
	f.down = int(d.get("down", 0))
	f.down_pick = bool(d.get("down_pick", false))
	f.kd = bool(d.get("kd", false))
	f.sad = int(d.get("sad", 0))
	f.sadness = int(d.get("sadness", 0))
	f.sad_warned = bool(d.get("sad_warned", false))
	f.dist = float(d.get("dist", 1.0))
	f.parry_at = int(d.get("parry_at", 0))
	f.pushed = int(d.get("pushed", 0))
	f.prorate = int(d.get("prorate", 0))
	f.bounce_due = bool(d.get("bounce_due", false))
	f.bounced = bool(d.get("bounced", false))
	f.bounce_up = float(d.get("bounce_up", 0.0))
	f.pinned = int(d.get("pinned", 0))
	f.splat_due = bool(d.get("splat_due", false))
	f.splats = int(d.get("splats", 0))
	f.splat = int(d.get("splat", 0))
	f.launched = bool(d.get("launched", false))
	f.restand = int(d.get("restand", 0))
	f.stance = str(d.get("stance", ""))
	f.initiative = bool(d.get("initiative", false))
	f.fans = int(d.get("fans", 2))
	f.tempo = int(d.get("tempo", 0))
	f.tempo_key = str(d.get("tempo_key", ""))
	f.tempo_idle = int(d.get("tempo_idle", 0))
	f.form = str(d.get("form", "flow"))
	f.grit = int(d.get("grit", 0))
	f.armor_left = int(d.get("armor_left", 0))
	f.repeats = int(d.get("repeats", 0))
	f.slide = int(d.get("slide", 0))
	f.hit_look = str(d.get("hit_look", "head"))
	f.hit_t = int(d.get("hit_t", 0))
	f.ko = bool(d["ko"])
	return f
