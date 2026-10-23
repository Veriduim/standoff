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
	# step 5 (23 Oct): his own drawings for the moves that borrowed - Nakmuay (study only) the inspiration
	"b_celb_shove": {"head": [-3, -91], "neck": [-3, -79], "hip": [0, -46], "elbow_f": [-5, -61], "hand_f": [-1, -76], "elbow_b": [14, -75], "hand_b": [30, -75], "knee_f": [17, -26], "foot_f": [21, -2], "knee_b": [-13, -23], "foot_b": [-19, 0], "bend": [1, 2, 1]},
	"b_celb_up": {"head": [11, -91], "neck": [10, -79], "hip": [0, -47], "elbow_f": [36, -88], "hand_f": [24, -78], "elbow_b": [15, -61], "hand_b": [13, -77], "knee_f": [11, -24], "foot_f": [13, 0], "knee_b": [-15, -26], "foot_b": [-29, -7], "bend": [-2, -4, -2], "shoulder_f": [22, -77]},
	"b_dump_pull": {"head": [20, -86], "neck": [12, -77], "hip": [0, -47], "elbow_f": [29, -70], "hand_f": [22, -55], "elbow_b": [26, -66], "hand_b": [17, -53], "knee_f": [17, -27], "foot_f": [15, -3], "knee_b": [-12, -24], "foot_b": [-16, 0], "bend": [3, 5, 3]},
	"b_dump_throw": {"head": [-16, -90], "neck": [-8, -81], "hip": [0, -49], "elbow_f": [-24, -72], "hand_f": [-39, -68], "elbow_b": [-22, -69], "hand_b": [-30, -56], "knee_f": [18, -31], "foot_f": [27, -8], "knee_b": [-7, -24], "foot_b": [-9, 0], "bend": [-3, -6, -3]},
	"b_catch_load": {"head": [-1, -91], "neck": [-2, -80], "hip": [0, -47], "elbow_f": [7, -64], "hand_f": [10, -80], "elbow_b": [1, -62], "hand_b": [2, -78], "knee_f": [12, -24], "foot_f": [16, 0], "knee_b": [-12, -24], "foot_b": [-20, -1], "bend": [2, 3, 2]},
	"b_catch_trap": {"head": [-2, -91], "neck": [-1, -79], "hip": [0, -46], "elbow_f": [5, -62], "hand_f": [-11, -65], "elbow_b": [17, -78], "hand_b": [33, -81], "knee_f": [14, -24], "foot_f": [19, -1], "knee_b": [-11, -23], "foot_b": [-18, 0], "bend": [1, 2, 1]},
	"b_ahook_load": {"head": [-3, -95], "neck": [-3, -83], "hip": [0, -50], "elbow_f": [-20, -77], "hand_f": [-15, -92], "elbow_b": [6, -67], "hand_b": [4, -83], "knee_f": [24, -41], "foot_f": [14, -19], "knee_b": [7, -25], "foot_b": [-12, -9], "bend": [1, 3, 1]},
	"b_ahook": {"head": [9, -94], "neck": [7, -82], "hip": [0, -50], "elbow_f": [23, -90], "hand_f": [35, -80], "elbow_b": [13, -65], "hand_b": [10, -81], "knee_f": [23, -37], "foot_f": [11, -16], "knee_b": [0, -24], "foot_b": [-21, -12], "bend": [2, 4, 2]},
	"b_edrop_rise": {"head": [-10, -94], "neck": [-6, -82], "hip": [0, -50], "elbow_f": [13, -100], "hand_f": [-2, -95], "elbow_b": [3, -67], "hand_b": [3, -83], "knee_f": [23, -37], "foot_f": [11, -16], "knee_b": [5, -24], "foot_b": [-14, -9], "bend": [-2, -4, -2], "shoulder_f": [4, -84]},
	"b_edrop_dive": {"head": [28, -71], "neck": [17, -64], "hip": [0, -36], "elbow_f": [21, -46], "hand_f": [18, -62], "elbow_b": [8, -48], "hand_b": [16, -62], "knee_f": [-13, -13], "foot_f": [-36, -22], "knee_b": [-23, -23], "foot_b": [-43, -35], "bend": [3, 6, 3]},
	"b_rush_2": {"head": [26, -77], "neck": [19, -68], "hip": [0, -41], "elbow_f": [34, -58], "hand_f": [38, -73], "elbow_b": [24, -50], "hand_b": [30, -65], "knee_f": [-11, -17], "foot_f": [-29, -2], "knee_b": [20, -24], "foot_b": [18, 0], "bend": [3, 5, 3]},
	"b_rush_stop": {"head": [-6, -93], "neck": [-6, -81], "hip": [0, -49], "elbow_f": [6, -67], "hand_f": [9, -83], "elbow_b": [0, -64], "hand_b": [3, -80], "knee_f": [23, -36], "foot_f": [33, -14], "knee_b": [-7, -24], "foot_b": [-11, 0], "bend": [-1, -2, -1]},
	"b_fl_a": {"head": [9, -86], "neck": [6, -75], "hip": [0, -42], "elbow_f": [26, -87], "hand_f": [42, -91], "elbow_b": [6, -58], "hand_b": [4, -74], "knee_f": [18, -24], "foot_f": [23, 0], "knee_b": [-17, -22], "foot_b": [-35, -7], "bend": [1, 2, 1], "shoulder_f": [14, -75], "shoulder_b": [0, -75]},
	"b_fl_wb": {"head": [15, -82], "neck": [10, -71], "hip": [0, -39], "elbow_f": [15, -55], "hand_f": [17, -71], "elbow_b": [-13, -62], "hand_b": [0, -54], "knee_f": [-15, -18], "foot_f": [-33, -3], "knee_b": [20, -23], "foot_b": [12, 0], "bend": [2, 3, 2], "shoulder_f": [6, -71], "shoulder_b": [2, -71]},
	"b_fl_b": {"head": [20, -82], "neck": [13, -72], "hip": [0, -42], "elbow_f": [14, -55], "hand_f": [13, -71], "elbow_b": [41, -76], "hand_b": [56, -81], "knee_f": [-17, -22], "foot_f": [-35, -7], "knee_b": [18, -24], "foot_b": [23, 0], "bend": [3, 5, 3], "shoulder_f": [9, -72], "shoulder_b": [23, -72]},
	"b_fl_wa": {"head": [15, -82], "neck": [10, -71], "hip": [0, -39], "elbow_f": [-15, -75], "hand_f": [-7, -89], "elbow_b": [21, -55], "hand_b": [21, -71], "knee_f": [20, -23], "foot_f": [12, 0], "knee_b": [-15, -18], "foot_b": [-33, -3], "bend": [2, 3, 2], "shoulder_f": [2, -71], "shoulder_b": [12, -71]},
	"b_fknee_load": {"head": [-1, -95], "neck": [-1, -83], "hip": [0, -50], "elbow_f": [8, -67], "hand_f": [11, -83], "elbow_b": [5, -66], "hand_b": [5, -82], "knee_f": [23, -37], "foot_f": [11, -16], "knee_b": [-5, -24], "foot_b": [-13, -2], "bend": [1, 2, 1]},
	"b_fknee": {"head": [-6, -94], "neck": [-6, -82], "hip": [0, -50], "elbow_f": [12, -79], "hand_f": [20, -66], "elbow_b": [11, -76], "hand_b": [17, -61], "knee_f": [24, -59], "foot_f": [20, -35], "knee_b": [-13, -27], "foot_b": [-34, -15], "bend": [-1, -2, -1]},
	"b_clinch_knee": {"head": [-1, -95], "neck": [-3, -83], "hip": [0, -50], "elbow_f": [15, -81], "hand_f": [25, -69], "elbow_b": [15, -78], "hand_b": [23, -64], "knee_f": [25, -57], "foot_f": [17, -34], "knee_b": [-2, -24], "foot_b": [-4, 0], "bend": [-1, -2, -1]},
	"b_over_load": {"head": [-4, -93], "neck": [-3, -81], "hip": [0, -48], "elbow_f": [-21, -77], "hand_f": [-15, -93], "elbow_b": [15, -84], "hand_b": [31, -84], "knee_f": [17, -28], "foot_f": [26, -6], "knee_b": [-10, -24], "foot_b": [-14, 0], "bend": [-3, -6, -3]},
	"b_over_top": {"head": [-3, -90], "neck": [-3, -78], "hip": [0, -45], "elbow_f": [9, -103], "hand_f": [-7, -103], "elbow_b": [13, -69], "hand_b": [21, -55], "knee_f": [17, -25], "foot_f": [21, -2], "knee_b": [-13, -23], "foot_b": [-21, 0], "bend": [1, 2, 1], "shoulder_f": [3, -86]},
	"b_overhand": {"head": [27, -77], "neck": [18, -69], "hip": [0, -42], "elbow_f": [36, -73], "hand_f": [40, -57], "elbow_b": [17, -51], "hand_b": [14, -36], "knee_f": [18, -24], "foot_f": [23, 0], "knee_b": [-17, -22], "foot_b": [-27, 0], "bend": [4, 7, 4]},
	# hit reactions by how it landed (06:22 "Lets try 1 and 2"): they face whoever hit them (+x toward them). Doubled
	# over at the body; the front leg taken from under them, pitching forward; crushed down under an overhead, arms over
	# the head; flung - thrown back, arms and feet trailing; sent up - arched, everything flung out
	"hurt_body": {"head": [24, -74], "neck": [14, -72], "hip": [-6, -44], "elbow_f": [16, -54], "hand_f": [4, -56],
		"elbow_b": [12, -54], "hand_b": [0, -52], "knee_f": [6, -22], "foot_f": [12, 0], "knee_b": [-16, -22],
		"foot_b": [-22, 0], "bend": [6, 11, 7]},
	"hurt_low": {"head": [20, -82], "neck": [14, -71], "hip": [0, -40], "elbow_f": [28, -80], "hand_f": [40, -86],
		"elbow_b": [0, -82], "hand_b": [-12, -90], "knee_f": [-4, -18], "foot_f": [-22, -8], "knee_b": [12, -20],
		"foot_b": [16, 0], "bend": [3, 5, 3]},
	"hurt_crush": {"head": [12, -77], "neck": [6, -67], "hip": [0, -34], "elbow_f": [18, -74], "hand_f": [12, -86],
		"elbow_b": [-6, -74], "hand_b": [2, -86], "knee_f": [16, -20], "foot_f": [24, 0], "knee_b": [-16, -20],
		"foot_b": [-24, 0], "bend": [7, 12, 8]},
	"hurt_slide": {"head": [-27, -78], "neck": [-19, -69], "hip": [-2, -40], "elbow_f": [-3, -75], "hand_f": [11, -80],
		"elbow_b": [-7, -81], "hand_b": [5, -90], "knee_f": [14, -24], "foot_f": [30, -12], "knee_b": [8, -18],
		"foot_b": [24, -4], "bend": [-3, -6, -4]},
	"hurt_air": {"head": [-20, -90], "neck": [-10, -82], "hip": [0, -50], "elbow_f": [6, -94], "hand_f": [18, -104],
		"elbow_b": [-24, -92], "hand_b": [-36, -100], "knee_f": [14, -34], "foot_f": [10, -12], "knee_b": [-10, -30],
		"foot_b": [-22, -14], "bend": [-6, -11, -7]},
	# (23 Oct 14:02 "I like the sp[i]ne hits": getting hit bends through the spine - a head hit arches back, a body
	# hit hunches round it, a crush folds into a C, a launch arches)
	"hurt": {"head": [-24, -82], "neck": [-14, -74], "hip": [-2, -44], "elbow_f": [-2, -90], "hand_f": [6, -104], "elbow_b": [-30, -84], "hand_b": [-40, -96], "knee_f": [10, -22], "foot_f": [16, 0], "knee_b": [-12, -22], "foot_b": [-24, -4], "bend": [-4, -8, -5]},
	# (23 Oct, Timmy: "Lets fill the gaps in our two" - YOMI's fighters have these, ours didn't. Built by Standoff
	# Workshop/tools/gap_poses.py.) tuck: a ball, knees to the chest - turned a quarter at a time ("tuck@90") it's every
	# roll and flip; grabbed: held in a throw or the clinch, doubled over, the head pulled down, grabbing at the arm; splat: upright
	# against the wall behind, one arm up it, one down it, the head knocked back, a knee buckling.
	"tuck": {"head": [19, -92], "neck": [12, -82], "hip": [0, -50], "elbow_f": [31, -78], "hand_f": [46, -84], "elbow_b": [31, -85], "hand_b": [44, -96], "knee_f": [25, -57], "foot_f": [48, -44], "knee_b": [26, -50], "foot_b": [44, -32], "bend": [4, 7, 4]},
	"grabbed": {"head": [38, -68], "neck": [27, -71], "hip": [0, -50], "elbow_f": [46, -64], "hand_f": [61, -70], "elbow_b": [41, -57], "hand_b": [57, -56], "knee_f": [8, -26], "foot_f": [4, 0], "knee_b": [-16, -30], "foot_b": [-26, -6], "bend": [6, 10, 6]},
	"splat": {"head": [-10, -94], "neck": [-4, -84], "hip": [0, -50], "elbow_f": [-16, -100], "hand_f": [-30, -108], "elbow_b": [-18, -70], "hand_b": [-34, -65], "knee_f": [12, -27], "foot_f": [0, -4], "knee_b": [-3, -24], "foot_b": [-6, 2], "bend": [-4, -8, -5]},
	# (13:05 "I should see that back bend": YOMI turns one ball for every tumble - ours open into the move first) arch: a
	# back flip's take-off, the back bent, head thrown back, arms reaching back over; sitback: a backward roll's start.
	"arch": {"head": [-29, -83], "neck": [-18, -79], "hip": [0, -50], "elbow_f": [-35, -89], "hand_f": [-51, -90], "elbow_b": [-33, -92], "hand_b": [-49, -96], "knee_f": [-8, -25], "foot_f": [-24, -5], "knee_b": [-4, -24], "foot_b": [-17, -2], "bend": [-5, -10, -6]},
	"sitback": {"head": [-16, -64], "neck": [-16, -52], "hip": [0, -22], "elbow_f": [4, -51], "hand_f": [19, -55], "elbow_b": [4, -55], "hand_b": [18, -63], "knee_f": [25, -30], "foot_f": [28, -5], "knee_b": [26, -26], "foot_b": [27, 0]},
	# (23 Oct: his taunt as a routine, YOMI-long - gloves tapped, a beckon, a flex, a chest pound)
	"b_tap": {"head": [2, -92], "neck": [1, -80], "hip": [0, -47], "elbow_f": [17, -71], "hand_f": [32, -74], "elbow_b": [19, -79], "hand_b": [28, -92], "knee_f": [12, -24], "foot_f": [16, -1], "knee_b": [-10, -23], "foot_b": [-16, 0]},
	"b_flex": {"head": [-3, -92], "neck": [-1, -80], "hip": [0, -47], "elbow_f": [17, -83], "hand_f": [14, -99], "elbow_b": [-19, -83], "hand_b": [-16, -99], "knee_f": [11, -24], "foot_f": [12, 0], "knee_b": [-11, -24], "foot_b": [-12, 0]},
	"b_beckon": {"head": [5, -92], "neck": [6, -80], "hip": [0, -47], "elbow_f": [24, -78], "hand_f": [40, -80], "elbow_b": [-2, -63], "hand_b": [10, -53], "knee_f": [13, -25], "foot_f": [19, -1], "knee_b": [-10, -23], "foot_b": [-16, 0]},
	"b_curl": {"head": [5, -92], "neck": [6, -80], "hip": [0, -47], "elbow_f": [24, -78], "hand_f": [21, -94], "elbow_b": [-2, -63], "hand_b": [10, -53], "knee_f": [13, -25], "foot_f": [19, -1], "knee_b": [-10, -23], "foot_b": [-16, 0]},
	"b_pound": {"head": [-9, -91], "neck": [-5, -80], "hip": [0, -48], "elbow_f": [0, -63], "hand_f": [-15, -67], "elbow_b": [10, -70], "hand_b": [16, -55], "knee_f": [12, -25], "foot_f": [15, -1], "knee_b": [-11, -24], "foot_b": [-14, 0]},
	# (23 Oct 13:25: Fan Step's own drawings - the spin out, catching the fan in the air, the landing)
	"fs_vanish": {"head": [-5, -98], "neck": [-2, -86], "hip": [0, -52], "elbow_f": [2, -105], "hand_f": [-5, -120], "elbow_b": [-6, -105], "hand_b": [1, -120], "knee_f": [19, -35], "foot_f": [-3, -22], "knee_b": [0, -26], "foot_b": [-1, 0]},
	"fs_catch": {"head": [-8, -95], "neck": [-4, -84], "hip": [0, -50], "elbow_f": [3, -103], "hand_f": [4, -119], "elbow_b": [-23, -88], "hand_b": [-39, -87], "knee_f": [19, -33], "foot_f": [14, -7], "knee_b": [-20, -34], "foot_b": [-43, -22]},
	"fs_land": {"head": [6, -92], "neck": [4, -81], "hip": [0, -47], "elbow_f": [22, -73], "hand_f": [35, -83], "elbow_b": [-10, -66], "hand_b": [-13, -50], "knee_f": [15, -25], "foot_f": [7, -1], "knee_b": [-15, -25], "foot_b": [-8, 0]},
	# (23 Oct 13:33, step 2: the movement moves' own drawings)
	"dash_off": {"head": [17, -84], "neck": [14, -73], "hip": [0, -42], "elbow_f": [-3, -63], "hand_f": [-19, -59], "elbow_b": [-5, -66], "hand_b": [-21, -65], "knee_f": [20, -26], "foot_f": [16, 0], "knee_b": [-23, -29], "foot_b": [-47, -21]},
	"dash_2": {"head": [7, -96], "neck": [6, -84], "hip": [0, -51], "elbow_f": [25, -88], "hand_f": [41, -89], "elbow_b": [-14, -88], "hand_b": [-30, -89], "knee_f": [8, -26], "foot_f": [7, 0], "knee_b": [-8, -26], "foot_b": [-11, 0]},
	"jump_off": {"head": [-3, -96], "neck": [-1, -84], "hip": [0, -50], "elbow_f": [-3, -104], "hand_f": [-5, -120], "elbow_b": [-6, -103], "hand_b": [-11, -118], "knee_f": [1, -24], "foot_f": [0, 2], "knee_b": [-2, -24], "foot_b": [-6, 2]},
	"crouch_deep": {"head": [22, -69], "neck": [19, -57], "hip": [0, -29], "elbow_f": [2, -47], "hand_f": [-13, -42], "elbow_b": [1, -49], "hand_b": [-15, -45], "knee_f": [26, -30], "foot_f": [23, -4], "knee_b": [26, -25], "foot_b": [20, 0]},
	"airdash": {"head": [44, -62], "neck": [33, -58], "hip": [0, -50], "elbow_f": [53, -62], "hand_f": [68, -65], "elbow_b": [13, -55], "hand_b": [-3, -54], "knee_f": [-26, -45], "foot_f": [-52, -44], "knee_b": [-25, -43], "foot_b": [-51, -39]},
	"fastfall": {"head": [0, -96], "neck": [0, -84], "hip": [0, -50], "elbow_f": [1, -104], "hand_f": [1, -120], "elbow_b": [-1, -104], "hand_b": [-3, -120], "knee_f": [0, -24], "foot_f": [0, 2], "knee_b": [-1, -24], "foot_b": [-3, 2]},
	"backstep_hop": {"head": [-8, -97], "neck": [-7, -85], "hip": [0, -51], "elbow_f": [13, -88], "hand_f": [27, -95], "elbow_b": [11, -75], "hand_b": [27, -76], "knee_f": [25, -43], "foot_f": [33, -19], "knee_b": [-3, -26], "foot_b": [-7, 0]},
	"b_dash_off": {"head": [17, -81], "neck": [14, -69], "hip": [0, -39], "elbow_f": [30, -60], "hand_f": [36, -75], "elbow_b": [23, -53], "hand_b": [26, -69], "knee_f": [21, -24], "foot_f": [19, 0], "knee_b": [-23, -27], "foot_b": [-46, -19]},
	# (23 Oct 14:02, step 4: her moves that borrowed get their own drawings - Standoff Workshop/tools/her_poses.py)
	"fsl_wind": {"head": [-5, -96], "neck": [-5, -84], "hip": [0, -50], "elbow_f": [-24, -77], "hand_f": [-29, -62], "elbow_b": [5, -66], "hand_b": [20, -61], "knee_f": [12, -27], "foot_f": [9, -1], "knee_b": [-10, -26], "foot_b": [-11, 0], "bend": [-2, -3, -2]},
	"fsl_cut": {"head": [16, -85], "neck": [13, -73], "hip": [0, -42], "elbow_f": [33, -76], "hand_f": [49, -77], "elbow_b": [-7, -76], "hand_b": [-23, -76], "knee_f": [20, -26], "foot_f": [18, 0], "knee_b": [-23, -30], "foot_b": [-48, -23], "bend": [3, 5, 3]},
	"recall_reach": {"head": [-8, -97], "neck": [-4, -86], "hip": [0, -52], "elbow_f": [15, -94], "hand_f": [30, -99], "elbow_b": [-22, -93], "hand_b": [-37, -98], "knee_f": [3, -26], "foot_f": [1, 0], "knee_b": [-5, -26], "foot_b": [-3, 0], "bend": [-3, -6, -4]},
	"recall_catch": {"head": [5, -95], "neck": [2, -83], "hip": [0, -49], "elbow_f": [13, -66], "hand_f": [-1, -74], "elbow_b": [7, -63], "hand_b": [-2, -77], "knee_f": [11, -25], "foot_f": [4, 0], "knee_b": [-11, -26], "foot_b": [-8, 0], "bend": [3, 5, 3]},
	"fst_a": {"head": [1, -98], "neck": [1, -86], "hip": [0, -52], "elbow_f": [21, -88], "hand_f": [37, -87], "elbow_b": [-19, -87], "hand_b": [-35, -86], "knee_f": [25, -44], "foot_f": [48, -33], "knee_b": [-1, -26], "foot_b": [-1, 0], "bend": [-1, -2, -1]},
	"fst_b": {"head": [-3, -98], "neck": [-1, -86], "hip": [0, -52], "elbow_f": [2, -106], "hand_f": [-3, -121], "elbow_b": [-5, -106], "hand_b": [1, -121], "knee_f": [20, -35], "foot_f": [-3, -23], "knee_b": [0, -26], "foot_b": [-1, 0], "bend": [0, -1, 0]},
	"gale_rise": {"head": [-22, -91], "neck": [-13, -83], "hip": [0, -52], "elbow_f": [-22, -101], "hand_f": [-34, -111], "elbow_b": [-25, -99], "hand_b": [-39, -106], "knee_f": [4, -26], "foot_f": [1, 0], "knee_b": [-4, -26], "foot_b": [-1, 0], "bend": [-6, -11, -7]},
	"mirror_hold": {"head": [-5, -95], "neck": [-5, -83], "hip": [0, -50], "elbow_f": [15, -80], "hand_f": [16, -96], "elbow_b": [-18, -69], "hand_b": [-24, -54], "knee_f": [11, -26], "foot_f": [10, 0], "knee_b": [-12, -27], "foot_b": [-15, -1], "bend": [-2, -4, -2]},
	"mstrike_cut": {"head": [6, -96], "neck": [6, -84], "hip": [0, -50], "elbow_f": [18, -100], "hand_f": [27, -113], "elbow_b": [-11, -74], "hand_b": [-27, -71], "knee_f": [9, -26], "foot_f": [10, 0], "knee_b": [-16, -30], "foot_b": [-36, -13], "bend": [2, 4, 2]},
	"stomp_up": {"head": [-3, -98], "neck": [-4, -86], "hip": [0, -52], "elbow_f": [12, -99], "hand_f": [12, -115], "elbow_b": [-21, -96], "hand_b": [-26, -111], "knee_f": [14, -74], "foot_f": [13, -48], "knee_b": [0, -26], "foot_b": [-1, 0], "bend": [2, 3, 2]},
	"stomp_down": {"head": [16, -92], "neck": [9, -82], "hip": [0, -49], "elbow_f": [-3, -66], "hand_f": [-17, -58], "elbow_b": [-9, -75], "hand_b": [-25, -72], "knee_f": [16, -28], "foot_f": [23, -3], "knee_b": [-11, -26], "foot_b": [-16, 0], "bend": [4, 7, 4]},
	"air_grab": {"head": [4, -96], "neck": [4, -84], "hip": [0, -50], "elbow_f": [23, -87], "hand_f": [39, -88], "elbow_b": [23, -80], "hand_b": [39, -79], "knee_f": [-20, -33], "foot_f": [-7, -11], "knee_b": [-23, -37], "foot_b": [-18, -11], "bend": [-2, -4, -2]},
	"air_throw": {"head": [27, -86], "neck": [18, -79], "hip": [0, -50], "elbow_f": [28, -62], "hand_f": [31, -46], "elbow_b": [25, -60], "hand_b": [23, -44], "knee_f": [-9, -26], "foot_f": [-33, -17], "knee_b": [-15, -29], "foot_b": [-41, -24], "bend": [5, 9, 5]},
	"pushblock": {"head": [10, -91], "neck": [7, -79], "hip": [0, -46], "elbow_f": [27, -81], "hand_f": [43, -81], "elbow_b": [27, -78], "hand_b": [43, -77], "knee_f": [17, -26], "foot_f": [17, 0], "knee_b": [-17, -26], "foot_b": [-37, -9], "bend": [2, 3, 2]},
	# (15:11 "splatter them into the ground": slammed flat on their front, arms flung out past the head, a heel kicked up)
	"floor_splat": {"head": [-46, -7], "neck": [-34, -6], "hip": [2, -6], "elbow_f": [-50, -2], "hand_f": [-64, -2],
		"elbow_b": [-22, -2], "hand_b": [-10, -1], "knee_f": [20, -3], "foot_f": [36, -2], "knee_b": [18, -8],
		"foot_b": [30, -16], "bend": [0, -1, 0]},
	"down": {"head": [-44, -8], "neck": [-32, -8], "hip": [0, -8], "elbow_f": [-20, -18], "hand_f": [-8, -24],
		"elbow_b": [-28, -2], "hand_b": [-16, 0], "knee_f": [18, -14], "foot_f": [36, -6], "knee_b": [18, -4],
		"foot_b": [38, 0]},
	# the Dancer's dance moves (20 Oct 16:17 "All sounds good to me" - a melee spacer, her strikes as dance): built
	# from joint angles with her bone lengths kept (the study's dance_poses.py); drawn as they are - no exaggeration
	"tap_wind": {"head": [-3, -96], "neck": [-1, -84], "hip": [4, -50], "elbow_f": [-10, -66], "hand_f": [6, -64],
		"elbow_b": [-13, -100], "hand_b": [-15, -116], "knee_f": [12, -26], "foot_f": [8, 0],
		"knee_b": [-6, -26], "foot_b": [-8, 0]},
	"tap_hit": {"head": [17, -92], "neck": [16, -80], "hip": [8, -47], "elbow_f": [36, -82], "hand_f": [52, -82],
		"elbow_b": [-3, -85], "hand_b": [-19, -86], "knee_f": [23, -26], "foot_f": [25, 0],
		"knee_b": [-9, -28], "foot_b": [-25, -7]},
	"arab_wind": {"head": [4, -92], "neck": [3, -80], "hip": [1, -47], "elbow_f": [13, -63], "hand_f": [27, -57],
		"elbow_b": [-7, -64], "hand_b": [-22, -58], "knee_f": [14, -24], "foot_f": [4, 0],
		"knee_b": [-13, -25], "foot_b": [-4, 0]},
	"arab_hit": {"head": [20, -91], "neck": [19, -79], "hip": [-2, -52], "elbow_f": [39, -81], "hand_f": [55, -82],
		"elbow_b": [1, -86], "hand_b": [-13, -95], "knee_f": [0, -26], "foot_f": [0, 0],
		"knee_b": [-27, -56], "foot_b": [-53, -63]},
	"pir_prep": {"head": [2, -95], "neck": [2, -83], "hip": [2, -49], "elbow_f": [20, -75], "hand_f": [25, -90],
		"elbow_b": [18, -70], "hand_b": [27, -83], "knee_f": [13, -25], "foot_f": [6, 0],
		"knee_b": [-10, -26], "foot_b": [-6, 0]},
	"pir_spin": {"head": [-1, -98], "neck": [0, -86], "hip": [1, -52], "elbow_f": [15, -73], "hand_f": [0, -79],
		"elbow_b": [9, -68], "hand_b": [23, -76], "knee_f": [1, -26], "foot_f": [0, 0],
		"knee_b": [27, -48], "foot_b": [4, -36]},
	"pir_cut": {"head": [-1, -98], "neck": [0, -86], "hip": [1, -52], "elbow_f": [20, -87], "hand_f": [36, -87],
		"elbow_b": [-20, -87], "hand_b": [-36, -86], "knee_f": [1, -26], "foot_f": [0, 0],
		"knee_b": [27, -48], "foot_b": [4, -36]},
	"fou_chamber": {"head": [-4, -98], "neck": [-3, -86], "hip": [1, -52], "elbow_f": [8, -103], "hand_f": [5, -118],
		"elbow_b": [-22, -89], "hand_b": [-38, -94], "knee_f": [26, -57], "foot_f": [13, -35],
		"knee_b": [0, -26], "foot_b": [0, 0]},
	"fou_kick": {"head": [-7, -97], "neck": [-5, -85], "hip": [2, -52], "elbow_f": [-11, -104], "hand_f": [-8, -120],
		"elbow_b": [-25, -83], "hand_b": [-40, -80], "knee_f": [28, -55], "foot_f": [54, -56],
		"knee_b": [0, -26], "foot_b": [0, 0]},
	"jete_prep": {"head": [20, -90], "neck": [17, -78], "hip": [10, -45], "elbow_f": [7, -61], "hand_f": [-6, -51],
		"elbow_b": [4, -63], "hand_b": [-10, -56], "knee_f": [27, -25], "foot_f": [20, 0],
		"knee_b": [-8, -27], "foot_b": [-20, -4]},
	"jete_air": {"head": [2, -96], "neck": [2, -84], "hip": [0, -50], "elbow_f": [14, -100], "hand_f": [26, -111],
		"elbow_b": [-9, -100], "hand_b": [-22, -110], "knee_f": [26, -52], "foot_f": [52, -52],
		"knee_b": [-26, -51], "foot_b": [-52, -53]},
	"jete_land": {"head": [31, -87], "neck": [26, -76], "hip": [11, -46], "elbow_f": [43, -67], "hand_f": [54, -56],
		"elbow_b": [8, -86], "hand_b": [-7, -91], "knee_f": [27, -26], "foot_f": [25, 0],
		"knee_b": [-10, -30], "foot_b": [-25, -9]},
	"plie_wind": {"head": [-3, -87], "neck": [-2, -75], "hip": [0, -41], "elbow_f": [-19, -85], "hand_f": [-27, -100],
		"elbow_b": [-21, -68], "hand_b": [-35, -60], "knee_f": [21, -26], "foot_f": [17, 0],
		"knee_b": [-21, -26], "foot_b": [-17, -1]},
	"plie_cut": {"head": [19, -75], "neck": [17, -63], "hip": [-1, -34], "elbow_f": [24, -44], "hand_f": [33, -31],
		"elbow_b": [6, -80], "hand_b": [2, -95], "knee_f": [23, -26], "foot_f": [19, 0],
		"knee_b": [-26, -26], "foot_b": [-19, 0]},
	"pdb_wind": {"head": [4, -96], "neck": [4, -84], "hip": [1, -50], "elbow_f": [7, -64], "hand_f": [16, -51],
		"elbow_b": [0, -64], "hand_b": [5, -49], "knee_f": [10, -26], "foot_f": [3, -1],
		"knee_b": [-8, -26], "foot_b": [-3, 0]},
	"pdb_hit": {"head": [-14, -96], "neck": [-9, -85], "hip": [-1, -52], "elbow_f": [-6, -105], "hand_f": [-7, -121],
		"elbow_b": [-13, -105], "hand_b": [-20, -119], "knee_f": [0, -26], "foot_f": [0, 0],
		"knee_b": [-15, -30], "foot_b": [-24, -6]},
	"bat_kick": {"head": [-6, -97], "neck": [-4, -85], "hip": [2, -52], "elbow_f": [15, -93], "hand_f": [31, -94],
		"elbow_b": [-23, -89], "hand_b": [-39, -90], "knee_f": [16, -74], "foot_f": [28, -97],
		"knee_b": [0, -26], "foot_b": [0, 0]},
	"bat_chop": {"head": [26, -89], "neck": [20, -78], "hip": [6, -48], "elbow_f": [36, -91], "hand_f": [46, -79],
		"elbow_b": [2, -85], "hand_b": [-14, -88], "knee_f": [19, -26], "foot_f": [17, 0],
		"knee_b": [-8, -26], "foot_b": [-17, -2]},
	"tour_wrap": {"head": [-2, -96], "neck": [-1, -84], "hip": [0, -50], "elbow_f": [14, -71], "hand_f": [-1, -77],
		"elbow_b": [8, -66], "hand_b": [22, -74], "knee_f": [-1, -24], "foot_f": [-1, 2],
		"knee_b": [-3, -24], "foot_b": [-4, 2]},
	"tour_cut": {"head": [-2, -96], "neck": [-1, -84], "hip": [0, -50], "elbow_f": [18, -88], "hand_f": [34, -89],
		"elbow_b": [-21, -87], "hand_b": [-37, -88], "knee_f": [13, -28], "foot_f": [25, -4],
		"knee_b": [-14, -28], "foot_b": [-6, -4]},
	"saute_kick": {"head": [-11, -95], "neck": [-8, -83], "hip": [0, -50], "elbow_f": [-19, -100], "hand_f": [-22, -116],
		"elbow_b": [-26, -93], "hand_b": [-36, -105], "knee_f": [20, -33], "foot_f": [40, -17],
		"knee_b": [-22, -37], "foot_b": [-18, -11]},
	"bow": {"head": [58, -71], "neck": [49, -63], "hip": [18, -49], "elbow_f": [66, -52], "hand_f": [81, -46],
		"elbow_b": [32, -52], "hand_b": [18, -46], "knee_f": [31, -26], "foot_f": [31, 0],
		"knee_b": [-5, -37], "foot_b": [-31, -37]},
	# the Bruiser's strikes (20 Oct 17:50 "Lets keep going" - full-body Muay Thai / boxing shapes: the hips and back
	# heel turned into the punch, the other glove at his chin, kicks leaning back): from joint angles, his bone lengths kept
	"mt_jab_load": {"head": [0, -93], "neck": [0, -81], "hip": [-2, -48], "elbow_f": [8, -65], "hand_f": [10, -81],
		"elbow_b": [2, -63], "hand_b": [8, -78], "knee_f": [10, -24], "foot_f": [16, -1],
		"knee_b": [-10, -23], "foot_b": [-16, 0]},
	"mt_jab": {"head": [15, -88], "neck": [13, -76], "hip": [4, -45], "elbow_f": [31, -77], "hand_f": [47, -78],
		"elbow_b": [17, -59], "hand_b": [22, -74], "knee_f": [19, -24], "foot_f": [23, 0],
		"knee_b": [-11, -24], "foot_b": [-23, -3]},
	"mt_cross_load": {"head": [-7, -94], "neck": [-6, -82], "hip": [-4, -49], "elbow_f": [10, -75], "hand_f": [18, -89],
		"elbow_b": [-10, -64], "hand_b": [-10, -80], "knee_f": [8, -26], "foot_f": [14, -3],
		"knee_b": [-10, -24], "foot_b": [-14, 0]},
	"mt_cross": {"head": [27, -82], "neck": [24, -70], "hip": [7, -42], "elbow_f": [29, -53], "hand_f": [31, -69],
		"elbow_b": [42, -72], "hand_b": [58, -73], "knee_f": [26, -24], "foot_f": [30, 0],
		"knee_b": [-13, -25], "foot_b": [-30, -8]},
	"mt_hook_load": {"head": [4, -92], "neck": [2, -80], "hip": [-1, -47], "elbow_f": [11, -64], "hand_f": [25, -71],
		"elbow_b": [4, -62], "hand_b": [10, -76], "knee_f": [14, -26], "foot_f": [16, -2],
		"knee_b": [-13, -24], "foot_b": [-16, 0]},
	"mt_hook": {"head": [25, -86], "neck": [22, -75], "hip": [6, -46], "elbow_f": [37, -85], "hand_f": [50, -76],
		"elbow_b": [24, -57], "hand_b": [30, -72], "knee_f": [20, -24], "foot_f": [24, 0],
		"knee_b": [-8, -24], "foot_b": [-24, -6]},
	"mt_body_load": {"head": [8, -86], "neck": [6, -74], "hip": [0, -42], "elbow_f": [17, -61], "hand_f": [22, -76],
		"elbow_b": [-3, -59], "hand_b": [11, -50], "knee_f": [20, -25], "foot_f": [17, -1],
		"knee_b": [-19, -24], "foot_b": [-17, 0]},
	"mt_body": {"head": [32, -76], "neck": [29, -64], "hip": [8, -38], "elbow_f": [43, -53], "hand_f": [45, -69],
		"elbow_b": [46, -60], "hand_b": [62, -58], "knee_f": [30, -24], "foot_f": [29, 0],
		"knee_b": [-13, -24], "foot_b": [-29, -6]},
	"mt_legkick_load": {"head": [-4, -90], "neck": [-3, -78], "hip": [-1, -45], "elbow_f": [9, -65], "hand_f": [13, -80],
		"elbow_b": [-13, -63], "hand_b": [-25, -53], "knee_f": [12, -23], "foot_f": [20, 0],
		"knee_b": [-5, -20], "foot_b": [-20, 0]},
	"mt_legkick": {"head": [-12, -92], "neck": [-9, -80], "hip": [4, -50], "elbow_f": [5, -69], "hand_f": [6, -85],
		"elbow_b": [-25, -72], "hand_b": [-40, -70], "knee_f": [28, -42], "foot_f": [50, -31],
		"knee_b": [1, -24], "foot_b": [0, 0]},
	"mt_teep_chamber": {"head": [-5, -94], "neck": [-3, -82], "hip": [3, -50], "elbow_f": [9, -69], "hand_f": [13, -84],
		"elbow_b": [-1, -64], "hand_b": [6, -79], "knee_f": [27, -60], "foot_f": [31, -36],
		"knee_b": [1, -24], "foot_b": [0, 0]},
	"mt_teep": {"head": [-14, -91], "neck": [-11, -80], "hip": [4, -50], "elbow_f": [5, -70], "hand_f": [13, -84],
		"elbow_b": [-9, -62], "hand_b": [-3, -76], "knee_f": [30, -51], "foot_f": [54, -52],
		"knee_b": [1, -24], "foot_b": [0, 0]},
	"mt_elbow_load": {"head": [-3, -92], "neck": [-2, -80], "hip": [-1, -47], "elbow_f": [-8, -63], "hand_f": [0, -77],
		"elbow_b": [0, -62], "hand_b": [6, -77], "knee_f": [12, -24], "foot_f": [18, -1],
		"knee_b": [-11, -23], "foot_b": [-18, 0]},
	# (23 Oct 13:18 Timmy's pick C - "we can cheat a little and disconnect the shoulder so the elbow can go forward":
	# the lead shoulder 16 forward of his neck, the elbow level, the fist folded back - the point clear of his head)
	"mt_elbow": {"head": [21, -87], "neck": [17, -76], "hip": [6, -44], "elbow_f": [50, -77], "hand_f": [35, -76], "elbow_b": [18, -58], "hand_b": [25, -72], "knee_f": [22, -24], "foot_f": [26, 0], "knee_b": [-10, -24], "foot_b": [-26, -6], "shoulder_f": [33, -76]},
	"mt_round_load": {"head": [-6, -91], "neck": [-5, -79], "hip": [-1, -46], "elbow_f": [9, -68], "hand_f": [11, -84],
		"elbow_b": [-14, -64], "hand_b": [-28, -56], "knee_f": [11, -23], "foot_f": [17, 0],
		"knee_b": [-14, -24], "foot_b": [-17, 0]},
	"mt_round": {"head": [-23, -85], "neck": [-18, -74], "hip": [4, -50], "elbow_f": [-2, -65], "hand_f": [-3, -81],
		"elbow_b": [-32, -63], "hand_b": [-46, -56], "knee_f": [24, -66], "foot_f": [44, -80],
		"knee_b": [1, -24], "foot_b": [0, 0]},
	"mt_hay_load": {"head": [-23, -91], "neck": [-19, -80], "hip": [-6, -49], "elbow_f": [-1, -80], "hand_f": [15, -82],
		"elbow_b": [-37, -82], "hand_b": [-52, -88], "knee_f": [7, -27], "foot_f": [17, -5],
		"knee_b": [-13, -24], "foot_b": [-17, 0]},
	"mt_hay": {"head": [36, -74], "neck": [32, -63], "hip": [10, -38], "elbow_f": [16, -54], "hand_f": [1, -49],
		"elbow_b": [50, -64], "hand_b": [66, -64], "knee_f": [32, -24], "foot_f": [33, 0],
		"knee_b": [-12, -26], "foot_b": [-33, -14]},
	"mt_upper_load": {"head": [10, -84], "neck": [7, -72], "hip": [-1, -40], "elbow_f": [18, -59], "hand_f": [23, -74],
		"elbow_b": [2, -55], "hand_b": [15, -45], "knee_f": [21, -27], "foot_f": [17, -4],
		"knee_b": [-21, -24], "foot_b": [-17, 0]},
	"mt_upper": {"head": [-5, -93], "neck": [-1, -82], "hip": [5, -50], "elbow_f": [12, -70], "hand_f": [13, -86],
		"elbow_b": [3, -100], "hand_b": [3, -116], "knee_f": [9, -24], "foot_f": [8, 0],
		"knee_b": [-2, -25], "foot_b": [-8, -1]},
	"mt_superman": {"head": [12, -91], "neck": [10, -79], "hip": [0, -48], "elbow_f": [-7, -73], "hand_f": [-22, -70],
		"elbow_b": [28, -82], "hand_b": [44, -83], "knee_f": [20, -31], "foot_f": [16, -8],
		"knee_b": [-26, -52], "foot_b": [-50, -54]},
	"mt_ko_load": {"head": [-23, -85], "neck": [-17, -74], "hip": [-2, -45], "elbow_f": [0, -71], "hand_f": [13, -81],
		"elbow_b": [-35, -70], "hand_b": [-51, -72], "knee_f": [17, -27], "foot_f": [20, -3],
		"knee_b": [-17, -24], "foot_b": [-20, 0]},
	"mt_ko": {"head": [38, -71], "neck": [33, -60], "hip": [9, -37], "elbow_f": [18, -51], "hand_f": [2, -48],
		"elbow_b": [51, -57], "hand_b": [65, -50], "knee_f": [32, -24], "foot_f": [34, 0],
		"knee_b": [-13, -24], "foot_b": [-34, -11]},
}


## The joints for a pose name (unknown -> idle), as Vector2s.
static func get_pose(pose_name: String) -> Dictionary:
	if pose_name.contains("@"):   # ("tuck@90": the pose turned 90 degrees forward round its middle; "@90g" on the floor)
		return _turned(pose_name)
	var src: Dictionary = P.get(pose_name, P["idle"])
	var out := {}
	for j: String in JOINTS:
		var v: Array = src[j]
		out[j] = Vector2(float(v[0]), float(v[1]))
	if src.has("bend"):
		var b: Array = src["bend"]
		out["bend"] = Vector3(float(b[0]), float(b[1]), float(b[2]))
	for s: String in SHOULDERS:
		if src.has(s):
			var v: Array = src[s]
			out[s] = Vector2(float(v[0]), float(v[1]))
	return out


## A pose's loose shoulders (23 Oct, the Elbow): an arm may hang from a shoulder off the neck - kept as an offset from
## the neck through blends, overshoots and the stretch; without one the arm starts at the neck.
const SHOULDERS := ["shoulder_f", "shoulder_b"]


static func _shoulders(out: Dictionary, a: Dictionary, b: Dictionary, t: float) -> void:
	for s: String in SHOULDERS:
		if a.has(s) or b.has(s):
			var oa: Vector2 = (a.get(s, a["neck"]) as Vector2) - (a["neck"] as Vector2)
			var ob: Vector2 = (b.get(s, b["neck"]) as Vector2) - (b["neck"] as Vector2)
			out[s] = (out["neck"] as Vector2) + oa.lerp(ob, t)


## (23 Oct 13:14 Timmy: "His body needs to be able to bend in the middle and at the 3/4 and 1/4 mark for tumble to
## work") a pose's spine: how far the back is pushed out at a quarter, half and three quarters of the way from the neck
## to the hips (pose units; + rounds the back, - arches it). Without one the torso is straight, as it always was.
static func bend_of(p: Dictionary) -> Vector3:
	return p.get("bend", Vector3.ZERO)


## A pose turned (23 Oct - the rolls and flips YOMI draws as four drawings): "name@deg" turns it deg degrees forward (the
## head going over the way they face) round the middle of its joints; "@degg" then sets its lowest point on the floor.
static func _turned(spec: String) -> Dictionary:
	var arg := spec.get_slice("@", 1)
	var ground := arg.ends_with("g")
	var p := get_pose(spec.get_slice("@", 0))
	var mid := Vector2.ZERO
	for j: String in JOINTS:
		mid += p[j]
	mid /= float(JOINTS.size())
	var a := deg_to_rad(float(arg.trim_suffix("g")))
	var out := {}
	if p.has("bend"):
		out["bend"] = p["bend"]
	var low := -INF
	for j: String in JOINTS:
		out[j] = mid + ((p[j] as Vector2) - mid).rotated(a)
		low = maxf(low, (out[j] as Vector2).y)
	for s: String in SHOULDERS:
		if p.has(s):
			out[s] = mid + ((p[s] as Vector2) - mid).rotated(a)
	if ground:
		for j: String in JOINTS + SHOULDERS:
			if out.has(j):
				out[j] = (out[j] as Vector2) + Vector2(0.0, -low)
	return out


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for j: String in JOINTS:
		out[j] = (a[j] as Vector2).lerp(b[j], t)
	if a.has("bend") or b.has("bend"):
		out["bend"] = bend_of(a).lerp(bend_of(b), t)
	_shoulders(out, a, b, t)
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


## A pose pushed on past b, away from a: every bone turned on further the way it turned from a to b (k of that turn
## again, at most PUSH_MAX), the hips moved on the same way, the bones' lengths kept - so push(hit, wind, k) is a wind-up
## pulled further back, push(wind, hit, k) a strike that overshoots.
const PUSH_MAX := 0.7


static func push(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	out["hip"] = (b["hip"] as Vector2) + ((b["hip"] as Vector2) - (a["hip"] as Vector2)) * k
	for bone: Array in TREE:
		var va: Vector2 = (a[bone[1]] as Vector2) - (a[bone[0]] as Vector2)
		var vb: Vector2 = (b[bone[1]] as Vector2) - (b[bone[0]] as Vector2)
		var turn := clampf(wrapf(vb.angle() - va.angle(), -PI, PI) * k, -PUSH_MAX, PUSH_MAX)
		out[bone[1]] = (out[bone[0]] as Vector2) + Vector2.from_angle(vb.angle() + turn) * vb.length()
	if a.has("bend") or b.has("bend"):   # (the spine past its drawing too)
		out["bend"] = bend_of(b) + (bend_of(b) - bend_of(a)) * k
	_shoulders(out, b, b, 1.0)
	return out


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Hit reactions (06:22): the pose for how the hit landed - snapped past it for the first frames (the blow landing), then
## held through the hitstun (20 Oct, YOMI's held drawings: it used to ease off toward a reeling guard). In the air: the
## launch pose, unless they were flung.
const HURT := {"head": "hurt", "body": "hurt_body", "low": "hurt_low", "crush": "hurt_crush", "slide": "hurt_slide",
	"air": "hurt_air", "throw": "grabbed", "hold": "grabbed", "wall": "splat", "floor": "floor_splat"}
const GRIPPED := 6       ## ticks a thrown fighter shows the grip before they fly (23 Oct)
const IMPACT := 3        ## frames the reaction snaps past its pose


static func _hurt_pose(character: String, r: Array, air: bool) -> Dictionary:
	var look: String = Sim.LOOKS[clampi(int(r[18]), 0, Sim.LOOKS.size() - 1)] if r.size() > 19 else "head"
	var t := int(r[19]) if r.size() > 19 else 99
	if look == "throw" and t >= GRIPPED:   # (the grip shown, then they fly like any launch)
		look = "head"
	if air and not look in ["slide", "hold", "wall", "throw"]:
		look = "air"
	var hit := get_pose(str(HURT[look]))
	var reel := blend(hit, get_pose("guard"), 0.45)   # (where it eases off to - and what the blow snaps past it from)
	if t < IMPACT:   # (the blow: past the pose, coming back to it)
		return push(reel, hit, 0.6 * (1.0 - float(t) / float(IMPACT)))
	return hit


## A strike's timeline (06:22 "Lets try 1 and 2"; 20 Oct held like YOMI's drawings - "lets get these all in"): it snaps
## into its wind-up coiled further back and HOLDS it still, snaps through to the strike in one in-between (the smear
## fills it) a frame before it lands, overshoots a touch, holds the strike while it's out and HOLD_ON past it, then
## snaps to a recovery pose (RECOVER of the way back) and holds that until it snaps to the next key. Null when the
## move's keys don't fit that (no key before the strike).
const COIL := 0.32       ## the wind-up pulled this much further back
const OVERSHOOT := 0.22  ## the strike landing this much past its pose
const HOLD_ON := 4       ## frames the strike stays out after its hit's over (YOMI holds the drawing on)
const RECOVER := 0.45    ## the recovery pose: this much of the way from the strike back to the next key
## Between any two keys a pose holds, then snaps to the next over SNAP frames, arriving on its key (YOMI: no in-betweens
## at all - each drawing held). It used to ease the whole way.
const SNAP := 2


static func _strike(m: Dictionary, keys: Array, f: int) -> Variant:
	var act := Moves.startup(m)
	var hk := -1
	for i in keys.size():
		if int(keys[i][0]) <= act:
			hk = i
	if hk <= 0 or int(keys[hk][0]) < act - 6:   # (no wind-up key, or the strike's pose came long before it acts)
		return null
	var wk := hk - 1
	var f_w := int(keys[wk][0])
	var f_h := int(keys[hk][0])
	var hits: Array = m.get("hits", [])
	var f_hold := maxi(f_h + 2, int(hits[0]["to"]) if not hits.is_empty() else f_h + 3)
	var f_n := int(keys[hk + 1][0]) if hk + 1 < keys.size() else f_hold + 8
	if f < f_w or f > f_n:
		return null
	var wind := get_pose(str(keys[wk][1]))
	var hit := get_pose(str(keys[hk][1]))
	if f < f_h:   # (the wind-up: snapped into, coiled, held - then one in-between through to the strike)
		var coil := wind if bool(m.get("drawn", false)) else push(hit, wind, COIL)   # (her dance moves: as drawn)
		if f == f_h - 1 and f > f_w:
			return blend(coil, hit, 0.5)
		return coil
	if f <= f_h + 1:   # (landing past it)
		return push(wind, hit, OVERSHOOT * (1.0 if f == f_h else 0.5))
	if f <= mini(f_hold + HOLD_ON, f_n - SNAP):   # (held - but not past the next key: a second spin still shows)
		return hit
	var nxt := get_pose(str(keys[hk + 1][1])) if hk + 1 < keys.size() else get_pose("idle")
	var back := blend(hit, nxt, RECOVER)
	if f > f_n - SNAP:   # (the snap on to the next key)
		return blend(back, nxt, float(f - (f_n - SNAP)) / float(SNAP))
	return back


static func exaggerate(pose: Dictionary) -> Dictionary:
	var base := get_pose("idle")
	var out := {}
	if pose.has("bend"):
		out["bend"] = pose["bend"]
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
	_shoulders(out, pose, pose, 1.0)
	var grounded := -INF   # (a foot that was on the floor is on it still)
	for j: String in ["foot_f", "foot_b"]:
		if (pose[j] as Vector2).y >= -2.0:
			grounded = maxf(grounded, (out[j] as Vector2).y)
	if grounded > -INF:
		var dy := 0.0 - grounded
		for j: String in out:
			if out[j] is Vector2:   # (not the spine's bend - 23 Oct, a Vector3 cast here broke every bent pose on the floor)
				out[j] = (out[j] as Vector2) + Vector2(0.0, dy)
	return out


## A character's standing pose (the Dancer's fan stance; the Bruiser's guard).
static func idle_of(character: String) -> String:
	return str(Moves.stats(character).get("idle", "idle")) if Moves.ROSTER.has(character) else "idle"


## back: they're moving away from the way they face (the view knows) - a move's "pose_back" keys if it has them (the
## back flip, the backward roll - 23 Oct).
static func for_record(character: String, r: Array, back := false) -> Dictionary:
	var pose := _for_record(character, r, back)
	var state := int(r[5])
	if state == 4 or state == 5 or (str(r[3]) in ["", "wait"] and state == 0):   # (lying down and standing: as drawn)
		return pose
	if state in [0, 3] and str(r[3]) != "" and bool(Moves.move(character, str(r[3])).get("drawn", false)):
		return _hell(character, str(r[3]), int(r[4]), pose)   # (her dance moves are posed at full stretch already -
		# 20 Oct; a special or super still goes past it - _hell)
	if state in [0, 3] and str(r[3]) != "" and _turns(character, str(r[3]), back):
		return pose   # (a roll or flip's turned ball: stretched, its limbs flew out - 23 Oct)
	if state in [0, 3]:
		return _hell(character, str(r[3]), int(r[4]), exaggerate(pose))
	return exaggerate(pose)


## 23 Oct 14:49 Timmy: "Their moves arent exaggerated enough! In normal attacks thats fine but special and supers
## should be exaggerated to hell!" - a special's or super's pose pushed on past its drawing: the body leaning further
## off upright, the legs further off straight down (a wider, lower stance), the spine bending more, and the striking
## limb stretched while its hit is out (a cartoon stretch - the hit box doesn't change). `hell`: how far (0 = as drawn).
static var hell := 2.0
const HELL_TORSO := 0.5      ## the lean off upright: this much more for each 1 of hell
const HELL_LEGS := 0.45      ## the legs off straight down
const HELL_TURN := 0.22      ## ...but either turned at most this many radians more for each 1 of hell
const HELL_BEND := 0.5       ## the spine's bend (each point at most HELL_BEND_MAX)
const HELL_BEND_MAX := 16.0
const HELL_STRETCH := 0.15   ## the striking limb's length
const HELL_LEAN_MAX := 1.05  ## radians off upright the body goes at most (legs: HELL_SPLIT_MAX off straight down) -
const HELL_SPLIT_MAX := 1.25 ## (14:55: past these he lay flat on the floor)
const HELL_SETTLE := 6       ## frames it takes to ease off after the last hit
static var _hell_tips := {}


static func _hell(character: String, mv: String, f: int, pose: Dictionary) -> Dictionary:
	if hell <= 0.0 or mv == "" or not Moves.ROSTER.has(character):
		return pose
	var m := Moves.move(character, mv)
	if not (str(m.get("tab", "")) in ["special", "super"] or str(m.get("kind", "")) == "super") 			or str(m.get("kind", "")) == "move":   # (her Forms are stances, not strikes)
		return pose
	if _turns(character, mv, false):   # (a turned ball: as it is)
		return pose
	var h := hell   # (15:10: after the last hit it eases back to the drawing over HELL_SETTLE frames - the follow-through
	var hits: Array = m.get("hits", [])   # and the finish (the Grand Finale's bow) as drawn, not dragged to the floor)
	if not hits.is_empty():
		var settle := int(hits[hits.size() - 1]["to"]) + HOLD_ON + 4
		h *= clampf(1.0 - float(f - settle) / float(HELL_SETTLE), 0.0, 1.0)
	if h <= 0.0:
		return pose
	var tip := _hell_tip(character, mv, m, f)
	var out := {"hip": pose["hip"]}
	var lean := 0.0
	var splay := {}
	for b: Array in TREE:
		var v: Vector2 = (pose[b[1]] as Vector2) - (pose[b[0]] as Vector2)
		var a := v.angle()
		var n := v.length()
		match str(b[1]):
			"neck":   # (the body: further off upright; the head and arms ride along on it, the arms keep their aim)
				var a2 := -PI / 2.0 + _more(wrapf(a + PI / 2.0, -PI, PI), 1.0 + HELL_TORSO * h, HELL_LEAN_MAX,
						HELL_TURN * h)
				lean = a2 - a
				a = a2
			"head":
				a += lean
			"knee_f", "knee_b":   # (the legs: further off straight down - the shins keep the knee's bend)
				var a3 := PI / 2.0 + _more(wrapf(a - PI / 2.0, -PI, PI), 1.0 + HELL_LEGS * h, HELL_SPLIT_MAX,
						HELL_TURN * h)
				splay[b[1]] = a3 - a
				a = a3
			"foot_f", "foot_b":
				a += float(splay.get("knee" + str(b[1]).trim_prefix("foot"), 0.0))
		if tip != "" and _on_limb(tip, str(b[1])):
			n *= 1.0 + HELL_STRETCH * h
		out[b[1]] = (out[b[0]] as Vector2) + Vector2.from_angle(a) * n
	if pose.has("bend"):
		var bd := bend_of(pose) * (1.0 + HELL_BEND * h)
		out["bend"] = bd.clamp(-Vector3.ONE * HELL_BEND_MAX, Vector3.ONE * HELL_BEND_MAX)
	_shoulders(out, pose, pose, 1.0)
	var grounded := -INF   # (a foot that was on the floor is on it still)
	for j: String in ["foot_f", "foot_b"]:
		if (pose[j] as Vector2).y >= -2.0:
			grounded = maxf(grounded, (out[j] as Vector2).y)
	if grounded > -INF:
		for j: String in out:
			if out[j] is Vector2:
				out[j] = (out[j] as Vector2) + Vector2(0.0, -grounded)
	return out


## An angle off its rest pushed by `mult`, up to `limit` and at most `extra` more (one already past the limit stays).
static func _more(dev: float, mult: float, limit: float, extra: float) -> float:
	if absf(dev) >= limit:
		return dev
	return dev + clampf(clampf(dev * mult, -limit, limit) - dev, -extra, extra)


## The bone ending at `joint` is part of the striking limb `tip`.
static func _on_limb(tip: String, joint: String) -> bool:
	if joint == tip:
		return true
	if tip.begins_with("hand"):
		return joint == "elbow" + tip.trim_prefix("hand")
	if tip.begins_with("foot"):
		return joint == "knee" + tip.trim_prefix("foot")
	return false


## The limb a special strikes with while its hits are out (the move's "tip", else the hand or foot thrown furthest
## forward and up on its first hit's frame); "" outside them.
static func _hell_tip(character: String, mv: String, m: Dictionary, f: int) -> String:
	var hits: Array = m.get("hits", [])
	if hits.is_empty() or f < int(hits[0]["from"]) - 1 or f > int(hits[hits.size() - 1]["to"]) + HOLD_ON:
		return ""
	var k := 0   # (the hit that's out or last out - Barrage's hooks swap hands)
	for i in hits.size():
		if f >= int(hits[i]["from"]) - 1:
			k = i
	if (hits[k] as Dictionary).has("tip"):   # (a hit may name its own - Clinch Fury's knees, then its elbow)
		return str(hits[k]["tip"])
	if m.has("tip"):   # ("" - nothing to stretch: Bull Rush leads with his shoulder)
		return str(m["tip"])
	var key := "%s:%s:%d" % [character, mv, k]
	if not _hell_tips.has(key):
		var hp := _for_record(character, [0.0, 0.0, 1, mv, int(hits[k]["from"]), 0, 0, 0])
		var best := "hand_f"
		var top := -INF
		for t: String in ["hand_f", "hand_b", "foot_f", "foot_b"]:
			var d: Vector2 = (hp[t] as Vector2) - (hp["neck" if t.begins_with("hand") else "hip"] as Vector2)
			var sc := (d.x - 0.5 * d.y) / (34.0 if t.begins_with("hand") else 50.0)
			if sc > top:
				top = sc
				best = t
		_hell_tips[key] = best
	return str(_hell_tips[key])


## The move's keys (back ones when moving back) have turned drawings - "tuck@90".
static func _turns(character: String, mv: String, back: bool) -> bool:
	var m := Moves.move(character, mv)
	var keys: Array = m.get("pose_back" if back and m.has("pose_back") else "pose", [])
	return keys.any(func(k: Array) -> bool: return str(k[1]).contains("@"))


static func _for_record(character: String, r: Array, back := false) -> Dictionary:
	var state := int(r[5])
	var air := float(r[1]) < -2.0
	var mv := str(r[3])
	if state == 4 or state == 5:   # (KO'd, or knocked down)
		return get_pose("down")
	if state == 1:
		return _hurt_pose(character, r, air)
	var low := r.size() > 13 and int(r[13]) == 1
	if state == 2 or (mv == "block" and state == 0):
		return get_pose("guard_low" if low else "guard")
	var form := int(r[14]) if r.size() > 14 else 0   # (Forms: standing free in Snap / Floor shows its stance)
	if (mv == "" or mv == "wait") and not air and state == 0 and form > 0:
		return get_pose("snap" if form == 1 else "floor")
	if mv == "":
		return get_pose("fall" if air else ("crouch" if state == 3 else idle_of(character)))
	var keys: Array = Moves.move(character, mv).get("pose_back" if back and Moves.move(character, mv).has("pose_back") 			else "pose", [[0, "idle"]])
	var f := int(r[4])
	var mk := str(Moves.move(character, mv).get("kind", ""))
	if mk in ["attack", "super", "grab", "special"] and keys.size() >= 2:   # (a strike: wind-up, overshoot, follow-through)
		var sp: Variant = _strike(Moves.move(character, mv), keys, f)
		if sp != null:
			return sp
	var cur: Array = keys[0]
	var nxt: Array = []
	for k: Array in keys:
		if int(k[0]) >= 0 and int(k[0]) <= f:
			cur = k
		elif int(k[0]) > f and nxt.is_empty():
			nxt = k
	if nxt.is_empty() or int(nxt[0]) <= int(cur[0]):
		return get_pose(str(cur[1]))
	# (every key held, then a snap to the next over SNAP frames - 20 Oct, YOMI's held drawings; strikes used to snap
	# over their last 40% and everything else eased the whole way)
	var gap := int(nxt[0]) - int(cur[0])
	var t := clampf(float(f - (int(nxt[0]) - mini(SNAP, gap))) / float(mini(SNAP, gap)), 0.0, 1.0)
	return blend(get_pose(str(cur[1])), get_pose(str(nxt[1])), t * t * (3.0 - 2.0 * t))
