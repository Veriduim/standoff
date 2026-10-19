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
	# standing: a fan dancer's stance (21:59 "feel like a dancer") - one fan out in front, the other up behind her head;
	# idle2 is the other end of her sway (StageView blends them while she stands)
	"idle": {"head": [3, -92], "neck": [1, -80], "hip": [0, -46], "elbow_f": [16, -68], "hand_f": [28, -76],
		"elbow_b": [-12, -82], "hand_b": [-18, -98], "knee_f": [12, -24], "foot_f": [22, 0], "knee_b": [-8, -24],
		"foot_b": [-14, 0]},
	"idle2": {"head": [5, -91], "neck": [3, -79], "hip": [1, -45], "elbow_f": [18, -62], "hand_f": [30, -60],
		"elbow_b": [-10, -86], "hand_b": [-8, -104], "knee_f": [13, -23], "foot_f": [22, 0], "knee_b": [-8, -23],
		"foot_b": [-15, 0]},
	"fan_low": {"head": [10, -70], "neck": [6, -58], "hip": [-2, -30], "elbow_f": [20, -34], "hand_f": [32, -18],
		"elbow_b": [-14, -34], "hand_b": [-26, -20], "knee_f": [16, -16], "foot_f": [24, 0], "knee_b": [-10, -14],
		"foot_b": [-20, 0]},
	"fan_up": {"head": [2, -100], "neck": [0, -88], "hip": [0, -52], "elbow_f": [14, -104], "hand_f": [24, -124],
		"elbow_b": [-10, -104], "hand_b": [-14, -124], "knee_f": [8, -26], "foot_f": [12, -4], "knee_b": [-6, -26],
		"foot_b": [-10, 0]},
	"glide": {"head": [-20, -40], "neck": [-12, -34], "hip": [0, -18], "elbow_f": [-4, -28], "hand_f": [8, -36],
		"elbow_b": [-24, -20], "hand_b": [-34, -6], "knee_f": [24, -14], "foot_f": [52, -10], "knee_b": [4, -4],
		"foot_b": [-12, 0]},
	# the x-factors on trial: the Snap form's stance, the Floor form's (low, a hand down), the Windmill's two spins
	"snap": {"head": [6, -94], "neck": [3, -82], "hip": [0, -48], "elbow_f": [18, -70], "hand_f": [24, -88],
		"elbow_b": [6, -66], "hand_b": [12, -82], "knee_f": [14, -25], "foot_f": [20, 0], "knee_b": [-8, -25],
		"foot_b": [-14, 0]},
	"floor": {"head": [12, -50], "neck": [8, -40], "hip": [-6, -18], "elbow_f": [20, -30], "hand_f": [28, -40],
		"elbow_b": [-16, -14], "hand_b": [-22, 0], "knee_f": [14, -22], "foot_f": [24, 0], "knee_b": [-2, -4],
		"foot_b": [-24, -2]},
	"windmill1": {"head": [-26, -14], "neck": [-14, -18], "hip": [4, -22], "elbow_f": [-20, -6], "hand_f": [-28, 0],
		"elbow_b": [-6, -6], "hand_b": [-12, 0], "knee_f": [24, -40], "foot_f": [46, -56], "knee_b": [26, -24],
		"foot_b": [48, -18]},
	"windmill2": {"head": [-26, -14], "neck": [-14, -18], "hip": [4, -22], "elbow_f": [-20, -6], "hand_f": [-28, 0],
		"elbow_b": [-6, -6], "hand_b": [-12, 0], "knee_f": [-4, -46], "foot_f": [-18, -66], "knee_b": [20, -44],
		"foot_b": [36, -62]},
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
	"jab_hit": {"head": [22, -85], "neck": [16, -74], "hip": [4, -44], "elbow_f": [38, -76], "hand_f": [60, -78], "elbow_b": [2, -60], "hand_b": [12, -68], "knee_f": [20, -22], "foot_f": [28, 0], "knee_b": [-12, -22], "foot_b": [-26, 0]},
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
	"kick_hit": {"head": [-24, -88], "neck": [-18, -78], "hip": [0, -50], "elbow_f": [-2, -70], "hand_f": [8, -80], "elbow_b": [-36, -70], "hand_b": [-46, -62], "knee_f": [24, -58], "foot_f": [50, -66], "knee_b": [-6, -26], "foot_b": [-10, 0]},
	"spin1": {"head": [8, -84], "neck": [6, -74], "hip": [0, -48], "elbow_f": [20, -70], "hand_f": [28, -64],
		"elbow_b": [-12, -70], "hand_b": [-20, -64], "knee_f": [8, -24], "foot_f": [10, 0], "knee_b": [-30, -62],
		"foot_b": [-58, -70]},
	"spin2": {"head": [-18, -84], "neck": [-12, -76], "hip": [0, -50], "elbow_f": [8, -72], "hand_f": [18, -66], "elbow_b": [-30, -72], "hand_b": [-42, -66], "knee_f": [26, -56], "foot_f": [52, -60], "knee_b": [-6, -26], "foot_b": [-10, 0]},
	"slam": {"head": [30, -52], "neck": [20, -46], "hip": [2, -26], "elbow_f": [34, -26], "hand_f": [44, -4], "elbow_b": [24, -28], "hand_b": [34, -4], "knee_f": [22, -14], "foot_f": [24, 0], "knee_b": [-12, -12], "foot_b": [-26, 0]},
	"straight": {"head": [28, -80], "neck": [20, -70], "hip": [4, -40], "elbow_f": [44, -74], "hand_f": [66, -74], "elbow_b": [6, -62], "hand_b": [-8, -54], "knee_f": [26, -22], "foot_f": [36, 0], "knee_b": [-14, -20], "foot_b": [-36, 0]},
	"low_kick": {"head": [-16, -80], "neck": [-12, -70], "hip": [0, -40], "elbow_f": [6, -62], "hand_f": [14, -72], "elbow_b": [-28, -58], "hand_b": [-38, -50], "knee_f": [24, -22], "foot_f": [50, -12], "knee_b": [-8, -20], "foot_b": [-16, 0]},
	"side_kick": {"head": [-36, -82], "neck": [-26, -74], "hip": [0, -52], "elbow_f": [-40, -64], "hand_f": [-50, -52], "elbow_b": [-34, -92], "hand_b": [-46, -100], "knee_f": [26, -54], "foot_f": [52, -56], "knee_b": [-6, -27], "foot_b": [-10, 0]},
	"uppercut": {"head": [12, -100], "neck": [8, -88], "hip": [2, -54], "elbow_f": [20, -106], "hand_f": [26, -128], "elbow_b": [-12, -74], "hand_b": [-20, -62], "knee_f": [12, -30], "foot_f": [16, -4], "knee_b": [-10, -30], "foot_b": [-20, -10]},
	"sweep": {"head": [-34, -50], "neck": [-26, -40], "hip": [-6, -16], "elbow_f": [-14, -30], "hand_f": [-8, -18], "elbow_b": [-34, -22], "hand_b": [-42, -2], "knee_f": [20, -8], "foot_f": [46, -2], "knee_b": [8, -4], "foot_b": [-14, -2]},
	"axe_up": {"head": [-16, -94], "neck": [-12, -82], "hip": [0, -50], "elbow_f": [4, -74], "hand_f": [14, -82], "elbow_b": [-28, -70], "hand_b": [-40, -76], "knee_f": [8, -74], "foot_f": [14, -100], "knee_b": [-4, -26], "foot_b": [-8, 0]},
	"axe_down": {"head": [20, -80], "neck": [14, -70], "hip": [0, -40], "elbow_f": [30, -58], "hand_f": [36, -46], "elbow_b": [-6, -60], "hand_b": [-20, -56], "knee_f": [24, -26], "foot_f": [46, -12], "knee_b": [-12, -20], "foot_b": [-24, 0]},
	"knee": {"head": [14, -90], "neck": [10, -78], "hip": [0, -48], "elbow_f": [22, -66], "hand_f": [16, -82],
		"elbow_b": [-6, -64], "hand_b": [4, -80], "knee_f": [28, -66], "foot_f": [12, -44], "knee_b": [-8, -26],
		"foot_b": [-22, -6]},
	"flash_kick": {"head": [-34, -90], "neck": [-22, -86], "hip": [0, -62], "elbow_f": [-30, -70], "hand_f": [-40, -58], "elbow_b": [-40, -96], "hand_b": [-52, -104], "knee_f": [16, -84], "foot_f": [26, -110], "knee_b": [-8, -38], "foot_b": [-12, -14]},
	"roll": {"head": [12, -34], "neck": [6, -38], "hip": [-12, -26], "elbow_f": [16, -22], "hand_f": [6, -14],
		"elbow_b": [-4, -18], "hand_b": [-14, -14], "knee_f": [6, -42], "foot_f": [-4, -30], "knee_b": [-4, -40],
		"foot_b": [-16, -32]},
	"taunt": {"head": [2, -94], "neck": [0, -82], "hip": [0, -48], "elbow_f": [18, -94], "hand_f": [34, -102],
		"elbow_b": [-18, -94], "hand_b": [-34, -102], "knee_f": [10, -24], "foot_f": [14, 0], "knee_b": [-10, -24],
		"foot_b": [-14, 0]},
	"burst": {"head": [0, -98], "neck": [0, -86], "hip": [0, -50], "elbow_f": [24, -98], "hand_f": [44, -112],
		"elbow_b": [-24, -98], "hand_b": [-44, -112], "knee_f": [18, -26], "foot_f": [34, -4], "knee_b": [-18, -26],
		"foot_b": [-34, -4]},
	# her supers (03:11 "Those superstars definitely need some animation improvements"): a pirouette (a passe, arms
	# overhead) and its turn (mirrored), both fans spread wide, a low gathering crouch, a throw up to the sky, a throw
	# from the back hand
	"twirl_a": {"head": [0, -98], "neck": [0, -86], "hip": [0, -52], "elbow_f": [10, -104], "hand_f": [4, -122],
		"elbow_b": [-10, -104], "hand_b": [-4, -122], "knee_f": [18, -40], "foot_f": [2, -30], "knee_b": [-2, -26],
		"foot_b": [-2, 0]},
	"twirl_b": {"head": [0, -98], "neck": [0, -86], "hip": [0, -52], "elbow_f": [-10, -104], "hand_f": [-4, -122],
		"elbow_b": [10, -104], "hand_b": [4, -122], "knee_f": [-18, -40], "foot_f": [-2, -30], "knee_b": [2, -26],
		"foot_b": [2, 0]},
	"fan_spread": {"head": [0, -94], "neck": [0, -82], "hip": [0, -48], "elbow_f": [26, -86], "hand_f": [52, -90],
		"elbow_b": [-26, -86], "hand_b": [-52, -90], "knee_f": [16, -24], "foot_f": [30, 0], "knee_b": [-16, -24],
		"foot_b": [-30, 0]},
	"gather": {"head": [8, -64], "neck": [6, -54], "hip": [0, -30], "elbow_f": [18, -42], "hand_f": [4, -50],
		"elbow_b": [-4, -44], "hand_b": [14, -58], "knee_f": [18, -14], "foot_f": [28, 0], "knee_b": [-12, -12],
		"foot_b": [-26, 0]},
	"throw_high": {"head": [4, -94], "neck": [2, -82], "hip": [0, -48], "elbow_f": [18, -102], "hand_f": [30, -126],
		"elbow_b": [-14, -74], "hand_b": [-26, -66], "knee_f": [12, -24], "foot_f": [18, 0], "knee_b": [-10, -24],
		"foot_b": [-16, 0]},
	"throw_back": {"head": [10, -88], "neck": [8, -76], "hip": [2, -44], "elbow_f": [-10, -62], "hand_f": [-22, -56],
		"elbow_b": [30, -78], "hand_b": [54, -74], "knee_f": [22, -24], "foot_f": [30, 0], "knee_b": [-10, -22],
		"foot_b": [-24, 0]},
	# the zoner's kit (03:32): Fan Ward - one arm out, setting the fan in the air; Fan Gust - both fans drawn back,
	# then swept out together in a low lunge
	"ward": {"head": [8, -90], "neck": [6, -78], "hip": [0, -44], "elbow_f": [26, -90], "hand_f": [46, -102],
		"elbow_b": [-14, -64], "hand_b": [-28, -52], "knee_f": [16, -22], "foot_f": [30, 0], "knee_b": [-10, -22],
		"foot_b": [-22, 0]},
	"gust_wind": {"head": [-4, -88], "neck": [-4, -76], "hip": [0, -44], "elbow_f": [-18, -72], "hand_f": [-30, -84],
		"elbow_b": [-20, -62], "hand_b": [-36, -68], "knee_f": [12, -24], "foot_f": [22, 0], "knee_b": [-8, -24],
		"foot_b": [-14, 0]},
	"gust": {"head": [14, -80], "neck": [10, -68], "hip": [-2, -38], "elbow_f": [32, -66], "hand_f": [56, -60],
		"elbow_b": [26, -76], "hand_b": [50, -84], "knee_f": [20, -20], "foot_f": [36, 0], "knee_b": [-14, -18],
		"foot_b": [-30, 0]},
	# the Bruiser (19 Oct 05:03 - Muay Thai + Little Mac): a boxer's guard (lead glove at his face, the rear at his
	# chin), the bounce, slips and rolls, hands, elbows, knees, the teep and the round kick, the clinch, the Wai Khru
	"b_idle": {"head": [4, -90], "neck": [2, -78], "hip": [-2, -45], "elbow_f": [14, -64], "hand_f": [18, -79], "elbow_b": [4, -60], "hand_b": [10, -74], "knee_f": [12, -23], "foot_f": [20, 0], "knee_b": [-12, -22], "foot_b": [-20, 0]},
	"b_idle2": {"head": [5, -87], "neck": [3, -75], "hip": [-1, -42], "elbow_f": [15, -61], "hand_f": [19, -76], "elbow_b": [5, -57], "hand_b": [11, -71], "knee_f": [13, -21], "foot_f": [20, 0], "knee_b": [-11, -20], "foot_b": [-20, 0]},
	"b_walk1": {"head": [6, -89], "neck": [4, -77], "hip": [0, -45], "elbow_f": [16, -63], "hand_f": [20, -78], "elbow_b": [6, -59], "hand_b": [12, -73], "knee_f": [16, -23], "foot_f": [26, 0], "knee_b": [-6, -22], "foot_b": [-20, -2]},
	"b_walk2": {"head": [6, -89], "neck": [4, -77], "hip": [0, -45], "elbow_f": [16, -63], "hand_f": [20, -78], "elbow_b": [6, -59], "hand_b": [12, -73], "knee_f": [6, -22], "foot_f": [-6, -2], "knee_b": [6, -23], "foot_b": [14, 0]},
	"b_dash": {"head": [20, -84], "neck": [14, -73], "hip": [0, -43], "elbow_f": [26, -62], "hand_f": [32, -77], "elbow_b": [16, -58], "hand_b": [24, -70], "knee_f": [20, -22], "foot_f": [30, 0], "knee_b": [-14, -20], "foot_b": [-30, -6]},
	"b_lean": {"head": [-12, -86], "neck": [-8, -75], "hip": [-2, -44], "elbow_f": [4, -62], "hand_f": [12, -76], "elbow_b": [-2, -58], "hand_b": [4, -72], "knee_f": [12, -23], "foot_f": [20, 0], "knee_b": [-12, -22], "foot_b": [-22, 0]},
	"b_bob": {"head": [16, -58], "neck": [10, -48], "hip": [-4, -30], "elbow_f": [22, -38], "hand_f": [26, -54], "elbow_b": [14, -36], "hand_b": [20, -50], "knee_f": [16, -16], "foot_f": [24, 0], "knee_b": [-14, -14], "foot_b": [-24, 0]},
	"b_weave": {"head": [6, -56], "neck": [4, -46], "hip": [-6, -30], "elbow_f": [16, -38], "hand_f": [22, -52], "elbow_b": [8, -34], "hand_b": [14, -48], "knee_f": [14, -16], "foot_f": [22, 0], "knee_b": [-16, -14], "foot_b": [-24, 0]},
	"b_jab": {"head": [8, -88], "neck": [5, -77], "hip": [-1, -45], "elbow_f": [24, -78], "hand_f": [44, -80], "elbow_b": [8, -60], "hand_b": [14, -75], "knee_f": [14, -23], "foot_f": [24, 0], "knee_b": [-12, -22], "foot_b": [-22, 0]},
	"b_hook_wind": {"head": [-2, -88], "neck": [-2, -77], "hip": [-2, -45], "elbow_f": [-8, -64], "hand_f": [-2, -80], "elbow_b": [6, -60], "hand_b": [12, -76], "knee_f": [12, -23], "foot_f": [20, 0], "knee_b": [-12, -22], "foot_b": [-20, 0]},
	"b_hook": {"head": [14, -86], "neck": [10, -75], "hip": [0, -44], "elbow_f": [28, -82], "hand_f": [44, -90], "elbow_b": [12, -58], "hand_b": [18, -72], "knee_f": [16, -23], "foot_f": [24, 0], "knee_b": [-12, -21], "foot_b": [-24, 0]},
	"b_body": {"head": [16, -72], "neck": [12, -61], "hip": [-2, -34], "elbow_f": [26, -52], "hand_f": [42, -56], "elbow_b": [12, -46], "hand_b": [18, -60], "knee_f": [18, -18], "foot_f": [28, 0], "knee_b": [-14, -16], "foot_b": [-26, 0]},
	"b_teep": {"head": [-12, -90], "neck": [-8, -79], "hip": [-2, -50], "elbow_f": [4, -66], "hand_f": [10, -82], "elbow_b": [-6, -64], "hand_b": [2, -78], "knee_f": [18, -62], "foot_f": [44, -58], "knee_b": [-6, -26], "foot_b": [-10, 0]},
	"b_elbow_wind": {"head": [2, -89], "neck": [1, -78], "hip": [-2, -45], "elbow_f": [-6, -86], "hand_f": [6, -92], "elbow_b": [6, -60], "hand_b": [12, -76], "knee_f": [12, -23], "foot_f": [20, 0], "knee_b": [-12, -22], "foot_b": [-20, 0]},
	"b_elbow": {"head": [12, -86], "neck": [8, -75], "hip": [0, -44], "elbow_f": [26, -80], "hand_f": [12, -86], "elbow_b": [10, -58], "hand_b": [16, -72], "knee_f": [16, -23], "foot_f": [26, 0], "knee_b": [-12, -21], "foot_b": [-24, 0]},
	"b_round_wind": {"head": [-6, -88], "neck": [-4, -77], "hip": [0, -47], "elbow_f": [8, -64], "hand_f": [14, -80], "elbow_b": [-18, -66], "hand_b": [-28, -58], "knee_f": [16, -60], "foot_f": [-2, -48], "knee_b": [-4, -24], "foot_b": [-6, 0]},
	"b_round": {"head": [-22, -84], "neck": [-16, -74], "hip": [0, -50], "elbow_f": [-2, -66], "hand_f": [6, -80], "elbow_b": [-32, -70], "hand_b": [-46, -64], "knee_f": [22, -66], "foot_f": [46, -78], "knee_b": [-4, -26], "foot_b": [-8, 0]},
	"b_clinch": {"head": [10, -86], "neck": [7, -75], "hip": [-2, -44], "elbow_f": [24, -70], "hand_f": [36, -82], "elbow_b": [20, -66], "hand_b": [32, -78], "knee_f": [14, -23], "foot_f": [22, 0], "knee_b": [-12, -22], "foot_b": [-20, 0]},
	"b_clinch_knee": {"head": [8, -84], "neck": [5, -73], "hip": [-4, -46], "elbow_f": [22, -66], "hand_f": [34, -72], "elbow_b": [18, -62], "hand_b": [30, -68], "knee_f": [20, -66], "foot_f": [8, -46], "knee_b": [-10, -24], "foot_b": [-16, 0]},
	"b_elbow_drop": {"head": [10, -80], "neck": [6, -70], "hip": [-4, -44], "elbow_f": [20, -50], "hand_f": [10, -64], "elbow_b": [-4, -58], "hand_b": [6, -70], "knee_f": [10, -30], "foot_f": [0, -12], "knee_b": [-14, -28], "foot_b": [-20, -10]},
	"b_flyknee": {"head": [10, -96], "neck": [6, -84], "hip": [-4, -52], "elbow_f": [20, -90], "hand_f": [30, -104], "elbow_b": [10, -90], "hand_b": [20, -104], "knee_f": [24, -70], "foot_f": [6, -56], "knee_b": [-10, -32], "foot_b": [-24, -18]},
	"b_hop": {"head": [6, -94], "neck": [4, -82], "hip": [0, -50], "elbow_f": [16, -70], "hand_f": [22, -86], "elbow_b": [-10, -66], "hand_b": [-4, -80], "knee_f": [14, -30], "foot_f": [10, -8], "knee_b": [-14, -40], "foot_b": [-36, -36]},
	"b_superman": {"head": [22, -86], "neck": [14, -78], "hip": [-6, -56], "elbow_f": [10, -64], "hand_f": [18, -78], "elbow_b": [34, -82], "hand_b": [56, -84], "knee_f": [6, -34], "foot_f": [0, -12], "knee_b": [-24, -48], "foot_b": [-44, -40]},
	"b_catch": {"head": [2, -88], "neck": [1, -77], "hip": [-4, -45], "elbow_f": [18, -58], "hand_f": [30, -50], "elbow_b": [14, -56], "hand_b": [26, -46], "knee_f": [12, -23], "foot_f": [20, 0], "knee_b": [-14, -22], "foot_b": [-22, 0]},
	"b_ko_wind": {"head": [4, -62], "neck": [2, -51], "hip": [-6, -28], "elbow_f": [10, -34], "hand_f": [-2, -22], "elbow_b": [12, -44], "hand_b": [20, -58], "knee_f": [16, -14], "foot_f": [26, 0], "knee_b": [-18, -12], "foot_b": [-28, 0]},
	"b_ko": {"head": [12, -104], "neck": [8, -92], "hip": [2, -58], "elbow_f": [20, -112], "hand_f": [26, -134], "elbow_b": [-10, -80], "hand_b": [-20, -68], "knee_f": [14, -32], "foot_f": [18, -6], "knee_b": [-10, -30], "foot_b": [-22, -8]},
	"b_taunt": {"head": [8, -62], "neck": [4, -51], "hip": [-6, -26], "elbow_f": [16, -48], "hand_f": [12, -64], "elbow_b": [12, -46], "hand_b": [10, -62], "knee_f": [14, -24], "foot_f": [16, 0], "knee_b": [-10, 0], "foot_b": [-30, 0]},
	"b_rush": {"head": [26, -74], "neck": [18, -64], "hip": [0, -38], "elbow_f": [30, -56], "hand_f": [34, -72], "elbow_b": [22, -50], "hand_b": [28, -64], "knee_f": [20, -20], "foot_f": [32, 0], "knee_b": [-16, -18], "foot_b": [-34, -4]},
	"b_stomp_up": {"head": [0, -90], "neck": [0, -78], "hip": [-2, -48], "elbow_f": [14, -80], "hand_f": [20, -96], "elbow_b": [-14, -80], "hand_b": [-20, -96], "knee_f": [16, -72], "foot_f": [12, -50], "knee_b": [-6, -24], "foot_b": [-10, 0]},
	"b_stomp": {"head": [6, -74], "neck": [4, -63], "hip": [-2, -36], "elbow_f": [18, -50], "hand_f": [26, -38], "elbow_b": [-12, -50], "hand_b": [-20, -38], "knee_f": [16, -18], "foot_f": [22, 0], "knee_b": [-16, -16], "foot_b": [-24, 0]},
	"hurt": {"head": [-24, -82], "neck": [-14, -74], "hip": [-2, -44], "elbow_f": [-2, -90], "hand_f": [6, -104], "elbow_b": [-30, -84], "hand_b": [-40, -96], "knee_f": [10, -22], "foot_f": [16, 0], "knee_b": [-12, -22], "foot_b": [-24, -4]},
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
## How much further than drawn a pose swings from the stance (22:40 "Our movements are really small and unexpressive"):
## the body and arms by AMP, the legs by AMP_LEGS (a kick's foot stays near its hit's height), each bone at most
## AMP_MAX radians more; limbs keep their lengths, a foot on the floor stays on it.
const AMP := 1.2
const AMP_LEGS := 1.06
const AMP_MAX := 0.45
const TREE := [["hip", "neck", 0], ["neck", "head", 0], ["neck", "elbow_f", 0], ["elbow_f", "hand_f", 0],
	["neck", "elbow_b", 0], ["elbow_b", "hand_b", 0], ["hip", "knee_f", 1], ["knee_f", "foot_f", 1], ["hip", "knee_b", 1],
	["knee_b", "foot_b", 1]]


static func exaggerate(pose: Dictionary) -> Dictionary:
	var base := get_pose("idle")
	var out := {}
	var hip: Vector2 = pose["hip"]
	out["hip"] = hip + Vector2(0.0, (hip.y - (base["hip"] as Vector2).y) * 0.35)   # (crouches go lower, leaps higher)
	for b: Array in TREE:
		var p0: Vector2 = pose[b[0]]
		var p1: Vector2 = pose[b[1]]
		var v := p1 - p0
		var vi := (base[b[1]] as Vector2) - (base[b[0]] as Vector2)
		var dev := wrapf(v.angle() - vi.angle(), -PI, PI)
		var k := AMP_LEGS if int(b[2]) == 1 else AMP
		var more := clampf(dev * (k - 1.0), -AMP_MAX, AMP_MAX)
		out[b[1]] = (out[b[0]] as Vector2) + Vector2.from_angle(v.angle() + more) * v.length()
	var grounded := -INF   # (a foot that was on the floor is on it still)
	for j: String in ["foot_f", "foot_b"]:
		if (pose[j] as Vector2).y >= -2.0:
			grounded = maxf(grounded, (out[j] as Vector2).y)
	if grounded > -INF:
		var dy := 0.0 - grounded
		for j: String in out:
			out[j] = (out[j] as Vector2) + Vector2(0.0, dy)
	return out


## A character's standing pose (the Dancer's fan stance; the Bruiser's guard).
static func idle_of(character: String) -> String:
	return str(Moves.stats(character).get("idle", "idle")) if Moves.ROSTER.has(character) else "idle"


static func for_record(character: String, r: Array) -> Dictionary:
	var pose := _for_record(character, r)
	var state := int(r[5])
	if state == 4 or state == 5 or (str(r[3]) in ["", "wait"] and state == 0):   # (lying down and standing: as drawn)
		return pose
	return exaggerate(pose)


static func _for_record(character: String, r: Array) -> Dictionary:
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
	var form := int(r[14]) if r.size() > 14 else 0   # (Forms: standing free in Snap / Floor shows its stance)
	if (mv == "" or mv == "wait") and not air and state == 0 and form > 0:
		return get_pose("snap" if form == 1 else "floor")
	if mv == "":
		return get_pose("fall" if air else ("crouch" if state == 3 else idle_of(character)))
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
