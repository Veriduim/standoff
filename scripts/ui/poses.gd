class_name Poses
extends RefCounted
## The stick figure's poses: 11 joints for a fighter 100 tall, facing right (+x in front), the origin between the feet,
## y down. Drawn scaled to each character's height and flipped for facing (StageView). Moves name their poses by frame
## (Moves `pose`); between two keyframes the joints ease from one to the next.

const JOINTS := ["head", "neck", "hip", "elbow_f", "hand_f", "elbow_b", "hand_b", "knee_f", "foot_f", "knee_b", "foot_b"]
## The lines drawn, joint to joint (the head is a circle at "head").
const BONES := [["neck", "hip"], ["neck", "elbow_f"], ["elbow_f", "hand_f"], ["neck", "elbow_b"], ["elbow_b", "hand_b"],
	["hip", "knee_f"], ["knee_f", "foot_f"], ["hip", "knee_b"], ["knee_b", "foot_b"]]

const P := {
	"idle": {"head": [4, -92], "neck": [2, -80], "hip": [0, -46], "elbow_f": [14, -64], "hand_f": [22, -76],
		"elbow_b": [-6, -62], "hand_b": [8, -70], "knee_f": [12, -24], "foot_f": [16, 0], "knee_b": [-10, -24],
		"foot_b": [-16, 0]},
	"walk1": {"head": [6, -91], "neck": [4, -79], "hip": [0, -45], "elbow_f": [16, -63], "hand_f": [24, -74],
		"elbow_b": [-4, -61], "hand_b": [10, -68], "knee_f": [18, -24], "foot_f": [26, 0], "knee_b": [-6, -22],
		"foot_b": [-22, -2]},
	"walk2": {"head": [6, -91], "neck": [4, -79], "hip": [0, -45], "elbow_f": [16, -63], "hand_f": [24, -74],
		"elbow_b": [-4, -61], "hand_b": [10, -68], "knee_f": [4, -22], "foot_f": [-10, -2], "knee_b": [8, -24],
		"foot_b": [14, 0]},
	"dash": {"head": [22, -84], "neck": [16, -74], "hip": [0, -44], "elbow_f": [26, -62], "hand_f": [34, -70],
		"elbow_b": [2, -58], "hand_b": [-12, -62], "knee_f": [20, -22], "foot_f": [30, 0], "knee_b": [-14, -22],
		"foot_b": [-32, -6]},
	"crouch": {"head": [6, -72], "neck": [4, -60], "hip": [0, -30], "elbow_f": [16, -48], "hand_f": [24, -60],
		"elbow_b": [-4, -46], "hand_b": [10, -54], "knee_f": [18, -18], "foot_f": [14, 0], "knee_b": [-6, -16],
		"foot_b": [-16, 0]},
	"jump": {"head": [4, -96], "neck": [2, -84], "hip": [0, -50], "elbow_f": [14, -96], "hand_f": [18, -110],
		"elbow_b": [-10, -94], "hand_b": [-12, -108], "knee_f": [14, -34], "foot_f": [6, -18], "knee_b": [-8, -32],
		"foot_b": [-14, -14]},
	"fall": {"head": [2, -96], "neck": [0, -84], "hip": [0, -50], "elbow_f": [18, -78], "hand_f": [30, -84],
		"elbow_b": [-16, -78], "hand_b": [-28, -84], "knee_f": [12, -28], "foot_f": [10, -6], "knee_b": [-8, -30],
		"foot_b": [-12, -8]},
	"dive": {"head": [26, -66], "neck": [18, -60], "hip": [-6, -50], "elbow_f": [24, -48], "hand_f": [14, -40],
		"elbow_b": [6, -70], "hand_b": [-8, -78], "knee_f": [14, -34], "foot_f": [36, -14], "knee_b": [-14, -34],
		"foot_b": [-6, -20]},
	"guard": {"head": [0, -88], "neck": [0, -76], "hip": [-2, -44], "elbow_f": [10, -66], "hand_f": [14, -88],
		"elbow_b": [6, -62], "hand_b": [10, -84], "knee_f": [12, -22], "foot_f": [16, 0], "knee_b": [-12, -22],
		"foot_b": [-18, 0]},
	"throw_wind": {"head": [-2, -90], "neck": [-2, -78], "hip": [0, -46], "elbow_f": [-16, -82], "hand_f": [-28, -92],
		"elbow_b": [10, -66], "hand_b": [20, -72], "knee_f": [14, -24], "foot_f": [20, 0], "knee_b": [-12, -24],
		"foot_b": [-20, 0]},
	"throw_out": {"head": [10, -88], "neck": [8, -76], "hip": [2, -44], "elbow_f": [30, -78], "hand_f": [54, -74],
		"elbow_b": [-10, -62], "hand_b": [-22, -56], "knee_f": [22, -24], "foot_f": [30, 0], "knee_b": [-10, -22],
		"foot_b": [-24, 0]},
	"sway": {"head": [-22, -70], "neck": [-18, -60], "hip": [-2, -36], "elbow_f": [4, -54], "hand_f": [14, -62],
		"elbow_b": [-26, -46], "hand_b": [-30, -34], "knee_f": [16, -20], "foot_f": [24, 0], "knee_b": [-14, -18],
		"foot_b": [-26, 0]},
	"mirror": {"head": [0, -90], "neck": [0, -78], "hip": [-2, -46], "elbow_f": [16, -70], "hand_f": [4, -84],
		"elbow_b": [14, -78], "hand_b": [-2, -68], "knee_f": [12, -24], "foot_f": [18, 0], "knee_b": [-14, -24],
		"foot_b": [-22, 0]},
	"guard_low": {"head": [4, -70], "neck": [2, -58], "hip": [-4, -30], "elbow_f": [14, -44], "hand_f": [18, -26],
		"elbow_b": [8, -42], "hand_b": [12, -22], "knee_f": [16, -16], "foot_f": [18, 0], "knee_b": [-12, -14],
		"foot_b": [-20, 0]},
	"parry": {"head": [6, -90], "neck": [4, -78], "hip": [0, -45], "elbow_f": [24, -78], "hand_f": [40, -84],
		"elbow_b": [-6, -62], "hand_b": [6, -70], "knee_f": [14, -24], "foot_f": [20, 0], "knee_b": [-10, -24],
		"foot_b": [-16, 0]},
	"jab_wind": {"head": [2, -91], "neck": [0, -79], "hip": [0, -46], "elbow_f": [4, -66], "hand_f": [10, -76],
		"elbow_b": [-6, -62], "hand_b": [6, -72], "knee_f": [14, -24], "foot_f": [20, 0], "knee_b": [-10, -24],
		"foot_b": [-18, 0]},
	"jab_hit": {"head": [10, -90], "neck": [8, -78], "hip": [2, -45], "elbow_f": [34, -80], "hand_f": [58, -82],
		"elbow_b": [-2, -62], "hand_b": [10, -70], "knee_f": [18, -24], "foot_f": [24, 0], "knee_b": [-8, -24],
		"foot_b": [-18, 0]},
	"heavy_wind": {"head": [-6, -90], "neck": [-6, -78], "hip": [0, -46], "elbow_f": [-20, -68], "hand_f": [-30, -80],
		"elbow_b": [8, -64], "hand_b": [18, -74], "knee_f": [16, -24], "foot_f": [24, 0], "knee_b": [-10, -24],
		"foot_b": [-20, 0]},
	"heavy_hit": {"head": [20, -86], "neck": [14, -76], "hip": [2, -44], "elbow_f": [40, -84], "hand_f": [66, -92],
		"elbow_b": [0, -60], "hand_b": [-12, -66], "knee_f": [24, -24], "foot_f": [34, 0], "knee_b": [-10, -22],
		"foot_b": [-24, 0]},
	"grab_reach": {"head": [16, -86], "neck": [12, -76], "hip": [0, -44], "elbow_f": [28, -66], "hand_f": [40, -64],
		"elbow_b": [22, -62], "hand_b": [36, -56], "knee_f": [16, -24], "foot_f": [24, 0], "knee_b": [-10, -24],
		"foot_b": [-18, 0]},
	"throw": {"head": [-8, -90], "neck": [-6, -78], "hip": [0, -46], "elbow_f": [4, -98], "hand_f": [14, -112],
		"elbow_b": [-4, -96], "hand_b": [6, -110], "knee_f": [16, -24], "foot_f": [24, 0], "knee_b": [-12, -24],
		"foot_b": [-20, 0]},
	"kick_wind": {"head": [-4, -90], "neck": [-2, -78], "hip": [0, -46], "elbow_f": [10, -66], "hand_f": [18, -78],
		"elbow_b": [-12, -62], "hand_b": [-4, -72], "knee_f": [20, -54], "foot_f": [16, -32], "knee_b": [-8, -24],
		"foot_b": [-12, 0]},
	"kick_hit": {"head": [-12, -86], "neck": [-8, -76], "hip": [0, -48], "elbow_f": [4, -66], "hand_f": [12, -76],
		"elbow_b": [-20, -64], "hand_b": [-28, -72], "knee_f": [30, -58], "foot_f": [60, -62], "knee_b": [-6, -24],
		"foot_b": [-10, 0]},
	"spin1": {"head": [8, -84], "neck": [6, -74], "hip": [0, -48], "elbow_f": [20, -70], "hand_f": [28, -64],
		"elbow_b": [-12, -70], "hand_b": [-20, -64], "knee_f": [8, -24], "foot_f": [10, 0], "knee_b": [-30, -62],
		"foot_b": [-58, -70]},
	"spin2": {"head": [-8, -84], "neck": [-6, -74], "hip": [0, -48], "elbow_f": [12, -70], "hand_f": [20, -64],
		"elbow_b": [-20, -70], "hand_b": [-28, -64], "knee_f": [30, -62], "foot_f": [58, -70], "knee_b": [-8, -24],
		"foot_b": [-10, 0]},
	"slam": {"head": [14, -64], "neck": [10, -54], "hip": [0, -32], "elbow_f": [26, -34], "hand_f": [34, -6],
		"elbow_b": [16, -32], "hand_b": [22, -6], "knee_f": [20, -18], "foot_f": [24, 0], "knee_b": [-12, -16],
		"foot_b": [-22, 0]},
	"straight": {"head": [14, -88], "neck": [10, -77], "hip": [2, -45], "elbow_f": [42, -80], "hand_f": [70, -82],
		"elbow_b": [-6, -64], "hand_b": [2, -72], "knee_f": [22, -24], "foot_f": [32, 0], "knee_b": [-10, -22],
		"foot_b": [-26, 0]},
	"low_kick": {"head": [-6, -86], "neck": [-4, -75], "hip": [0, -42], "elbow_f": [10, -62], "hand_f": [18, -72],
		"elbow_b": [-14, -60], "hand_b": [-6, -70], "knee_f": [28, -24], "foot_f": [58, -18], "knee_b": [-8, -22],
		"foot_b": [-14, 0]},
	"side_kick": {"head": [-20, -80], "neck": [-14, -70], "hip": [0, -50], "elbow_f": [-2, -64], "hand_f": [6, -72],
		"elbow_b": [-26, -62], "hand_b": [-34, -70], "knee_f": [34, -56], "foot_f": [78, -56], "knee_b": [-6, -24],
		"foot_b": [-12, 0]},
	"uppercut": {"head": [10, -96], "neck": [8, -84], "hip": [2, -48], "elbow_f": [26, -96], "hand_f": [30, -122],
		"elbow_b": [-8, -66], "hand_b": [2, -74], "knee_f": [16, -26], "foot_f": [22, 0], "knee_b": [-8, -24],
		"foot_b": [-16, 0]},
	"sweep": {"head": [-20, -50], "neck": [-14, -42], "hip": [0, -20], "elbow_f": [-8, -24], "hand_f": [-16, -6],
		"elbow_b": [-24, -26], "hand_b": [-30, -6], "knee_f": [40, -12], "foot_f": [82, -8], "knee_b": [-4, -6],
		"foot_b": [-16, 0]},
	"axe_up": {"head": [-10, -86], "neck": [-8, -76], "hip": [0, -48], "elbow_f": [8, -68], "hand_f": [16, -78],
		"elbow_b": [-22, -64], "hand_b": [-28, -74], "knee_f": [18, -84], "foot_f": [30, -122], "knee_b": [-6, -24],
		"foot_b": [-12, 0]},
	"axe_down": {"head": [10, -82], "neck": [8, -72], "hip": [0, -46], "elbow_f": [22, -62], "hand_f": [26, -50],
		"elbow_b": [-10, -60], "hand_b": [-18, -50], "knee_f": [36, -40], "foot_f": [50, -6], "knee_b": [-8, -24],
		"foot_b": [-16, 0]},
	"knee": {"head": [14, -90], "neck": [10, -78], "hip": [0, -48], "elbow_f": [22, -66], "hand_f": [16, -82],
		"elbow_b": [-6, -64], "hand_b": [4, -80], "knee_f": [28, -66], "foot_f": [12, -44], "knee_b": [-8, -26],
		"foot_b": [-22, -6]},
	"flash_kick": {"head": [-18, -90], "neck": [-12, -80], "hip": [0, -56], "elbow_f": [-2, -96], "hand_f": [-8, -112],
		"elbow_b": [-30, -84], "hand_b": [-40, -96], "knee_f": [22, -96], "foot_f": [34, -140], "knee_b": [-6, -30],
		"foot_b": [-10, -4]},
	"roll": {"head": [12, -34], "neck": [6, -38], "hip": [-12, -26], "elbow_f": [16, -22], "hand_f": [6, -14],
		"elbow_b": [-4, -18], "hand_b": [-14, -14], "knee_f": [6, -42], "foot_f": [-4, -30], "knee_b": [-4, -40],
		"foot_b": [-16, -32]},
	"taunt": {"head": [2, -94], "neck": [0, -82], "hip": [0, -48], "elbow_f": [18, -94], "hand_f": [34, -102],
		"elbow_b": [-18, -94], "hand_b": [-34, -102], "knee_f": [10, -24], "foot_f": [14, 0], "knee_b": [-10, -24],
		"foot_b": [-14, 0]},
	"burst": {"head": [0, -98], "neck": [0, -86], "hip": [0, -50], "elbow_f": [24, -98], "hand_f": [44, -112],
		"elbow_b": [-24, -98], "hand_b": [-44, -112], "knee_f": [18, -26], "foot_f": [34, -4], "knee_b": [-18, -26],
		"foot_b": [-34, -4]},
	"hurt": {"head": [-14, -86], "neck": [-10, -76], "hip": [0, -46], "elbow_f": [8, -84], "hand_f": [16, -96],
		"elbow_b": [-24, -80], "hand_b": [-30, -94], "knee_f": [10, -24], "foot_f": [14, 0], "knee_b": [-12, -22],
		"foot_b": [-20, -2]},
	"down": {"head": [-44, -8], "neck": [-32, -8], "hip": [0, -8], "elbow_f": [-20, -18], "hand_f": [-8, -24],
		"elbow_b": [-28, -2], "hand_b": [-16, 0], "knee_f": [18, -14], "foot_f": [36, -6], "knee_b": [18, -4],
		"foot_b": [38, 0]},
}


## The joints for a pose name (unknown -> idle), as Vector2s.
static func get_pose(pose_name: String) -> Dictionary:
	var src: Dictionary = P.get(pose_name, P["idle"])
	var out := {}
	for j: String in JOINTS:
		var v: Array = src[j]
		out[j] = Vector2(float(v[0]), float(v[1]))
	return out


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for j: String in JOINTS:
		out[j] = (a[j] as Vector2).lerp(b[j], t)
	return out


## The pose for one recorded tick: [x, y, facing, move, frame, state, hp, meter] (Sim.record) - reeling, blocking,
## knocked out and the air come first; else the move's keyframes, eased between.
static func for_record(character: String, r: Array) -> Dictionary:
	var state := int(r[5])
	var air := float(r[1]) < -2.0
	var mv := str(r[3])
	if state == 4 or state == 5:   # (KO'd, or knocked down)
		return get_pose("down")
	if state == 1:
		return get_pose("hurt")
	var low := r.size() > 13 and int(r[13]) == 1
	if state == 2 or (mv == "block" and state == 0):
		return get_pose("guard_low" if low else "guard")
	if mv == "":
		return get_pose("fall" if air else ("crouch" if state == 3 else "idle"))
	var keys: Array = Moves.move(character, mv).get("pose", [[0, "idle"]])
	var f := int(r[4])
	var cur: Array = keys[0]
	var nxt: Array = []
	for k: Array in keys:
		if int(k[0]) >= 0 and int(k[0]) <= f:
			cur = k
		elif int(k[0]) > f and nxt.is_empty():
			nxt = k
	if nxt.is_empty() or int(nxt[0]) <= int(cur[0]):
		return get_pose(str(cur[1]))
	var t := float(f - int(cur[0])) / float(int(nxt[0]) - int(cur[0]))
	# strikes hold the pose most of the way and snap to the next near the keyframe (hits read as hits, not floaty);
	# moving, guarding, getting up and the like ease the whole way (smooth)
	var kind := str(Moves.move(character, mv).get("kind", ""))
	if kind in ["attack", "super", "grab", "burst"]:
		t = clampf((t - 0.6) / 0.4, 0.0, 1.0)
	return blend(get_pose(str(cur[1])), get_pose(str(nxt[1])), t * t * (3.0 - 2.0 * t))
