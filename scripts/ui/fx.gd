class_name Fx
extends RefCounted
## The stage's hit effects - the first style pass (Timmy, 18 Oct 18:07: "Your suggestion looks good" - picks 4, 5, 6, 9
## from the YOMI study; our own drawing, the study is reference only):
##   sparks    a spiky burst where a hit lands, rings and squares flying on along the hit, chips, a white shockwave on
##             big hits; a guard arc on a block, a glint on a parry, an orange flash on a clash, a big double ring on a KO
##   freeze    the playback holds still a moment on contact (hitstop) - longer for harder hits; the one hit shakes in
##             place; a small screen shake (kept small - in Life After Dark he found a big shake "way too much")
##   arcs      the striking hand or foot leaves a pale arc while its hit is out
## The second, flashier pass (18:35: "Im excited to see the flashy animations and burst effects"; scenery and the floor
## reflection left out, "those are mods"):
##   impacts   a hard hit flashes the one hit white for a few frames and throws out impact lines (the speed streaks
##             across the stage went at 19:41: "They kind of look like rain. Remove those")
##   supers    the stage dims round the one starting it, light rays and rings burst out of them, everything holds a
##             moment and the picture splits into colours (pick 13); KOs split too
##   after     fast movers leave fading copies of themselves (pick 8)
## The YOMI source study (20 Oct 14:22 "Dont keep the words and damage numbers and lets get these all in"): no words or
## combo counts on the stage, and no push-in; smoke behind anyone knocked back fast, debris off a wall slam
## (Standoff Workshop/references/yomi_source_notes.md). Its speed lines came and went (15:10 "Remove the speed lines").
## An effect stays in the area its move reaches (15:10 "The animation should only be in the are it effects") - a move
## that reaches the whole stage shows near the one doing it and shakes the stage lightly.
##   smoke     puffs left behind anyone knocked back fast, every tick
##   debris    a wall slam throws big chunks off the wall, a third of the screen
## Positions are world px (StageView draws them through its camera). The screens read frozen() before playing on.

const YELLOW := Color("#ffd23f")
const HOT := Color("#fff6cf")
const BLOCK := Color("#a6dcff")
const ORANGE := Color("#ff9f1c")
const TRAIL_KEEP := 10       ## ticks of a limb's path kept for its arc (a longer sweep)
const TRAIL_FADE := 0.12     ## seconds an arc takes to fade once the hit's over
const INNER := 0.38          ## a swoosh's inner edge, as a share of the way from the joint to the tip (a fuller crescent)

var parts: Array = []        ## {k: kind, p: world pos, v: px/s, age, life, c: colour, s: size, r: angle, w: spin, sp}
var hitstop := 0.0           ## seconds the playback holds (frozen())
var jitter: Array = []       ## ids shaking in place during the freeze
var shake := 0.0             ## screen px, fading
var offset := Vector2.ZERO   ## this frame's shake (StageView adds it to the camera)
var trails := {}             ## fighter id -> {pts: [[tip, pivot], ...], c: colour, fade: -1 live / seconds}
var flash := {}              ## fighter id -> seconds they're drawn white (the impact frame)
var afters: Array = []       ## afterimages: {id, rec: Sim.record row, age, life}
const BIG := 1.3              ## every effect this much bigger (22:40 "elevate this a lot")
const AFTER_EACH := 2        ## afterimages a fighter at most, and in all (each is a whole figure to draw)
const AFTER_ALL := 8
const INK := Color("#3b3f52")    ## the dark starburst behind a hit (23:05)
var dim := 0.0               ## how dark the stage goes round a super (0-1); `dim_id` is drawn over it
var dim_id := -1
var split := 0.0             ## the colour split (0-1, fading) - the screens' post shader reads it
var split_at := Vector2.ZERO ## (world) where it splits from
var style := ""              ## the next hit's look (StageView sets it): "slash" her fans, "wave" the ripple, else blunt
var impact := 1.0            ## the next hit's freeze and shake, this many times over (a move's hit can ask - Barrage's)
var cutin := {}              ## a super's cut-in: {id, col, title, pose, face, age, life} (screen space - draw_cutin)
var _rng := RandomNumberGenerator.new()
static var _bold: FontVariation
## The screen (StageView sets these each frame). The big moments are sized by the SCREEN, not the world (19 Oct 14:09
## "our attacks anf effects domt use the full width and height of the field", with two YOMI mod fights - small fighters,
## effects filling the screen): a world-sized effect shrinks whenever the camera pulls back for a wide stage or six
## fighters. A screen-sized part ("scr") has its size `s` as a share of the stage band's height.
var band := 460.0            ## the stage band's height (screen px)
var view_zoom := 1.0         ## the camera's zoom
var span := 2000.0           ## how much of the stage is in view (world px across)
var walls := 1400.0          ## the stage's half width (world px)
const BIG_HIT := 45          ## a hit this hard (after scaling) gets Nakmuay's breaking ring
const HUGE_HIT := 70         ## ...and this hard the giant screen-sized starburst (23 Oct: it was every 45+, "way too much")
                             ## (06:17 "The only thing i didnt like the circle for was every hit")
## Quake Stomp's shockwave reaches QUAKE_REACH either side of his foot (its hit box: 90), so its spikes and debris stay
## there - YOMI's ground pound throws a curtain of debris up off the strip it hits and bumps the camera, no screen-wide
## wall (15:10 "the ground shake is way too much"). QUAKE_SPIKES of them, QUAKE_DEBRIS bits.
const QUAKE_REACH := 100.0
const QUAKE_SPIKES := 14
const QUAKE_DEBRIS := 36
## Smoke behind knockback (YOMI: a puff every tick someone hit moves faster than 6.5 px a tick - about its ordinary
## hits' speed). Ours since 0.37.0's launch pace: an ordinary hit sends them 7-10 px a tick, a Haymaker 48, a Roundhouse
## 41, the K.O. Punch 21 - so the big ones smoke.
const SMOKE_PX := 11.0
const SOLID := Color("#8f93a1")   ## the Bruiser's rush copies: solid grey (the red brawler in the 14:09 video)
const AFTER_SOLID := 2       ## solid copies a fighter at most (15:37 "not as many after images. Like half them")


func frozen() -> bool:
	return hitstop > 0.0


func clear() -> void:
	parts.clear()
	jitter.clear()
	trails.clear()
	flash.clear()
	afters.clear()
	hitstop = 0.0
	shake = 0.0
	dim = 0.0
	dim_id = -1
	split = 0.0
	offset = Vector2.ZERO


## One sim event at a world point. `face` = the hitter's facing (sparks fly on along the hit), `reeling` = the one hit
## was already reeling (the combo goes on).
func on_event(type: String, at: Vector2, face: float, dmg: int, by: Color, victim: int, victim_col: Color,
		reeling: bool, seed_n: int, counter := false, push := false) -> void:
	_rng.seed = seed_n
	match type:
		"down":   # (floored: dust both ways along the ground)
			for i in 10:
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("chip", at, Vector2(side * _rng.randf_range(120.0, 320.0), _rng.randf_range(-160.0, -40.0)),
						_rng.randf_range(0.25, 0.45), Color("#9a9daa"), _rng.randf_range(3.0, 6.0))
			_add("shock", at, Vector2.ZERO, 0.2, Color("#c9ccd8"), 40.0)
			kick(2.0)
		"shot":   # (a throw: a quick flash at the hand)
			_add("shock", at, Vector2.ZERO, 0.14, by.lightened(0.5), 26.0)
		"countered":   # (Mirror: a big white flash)
			_add("glint", at, Vector2.ZERO, 0.3, Color.WHITE, 80.0)
			_add("shock", at, Vector2.ZERO, 0.32, by.lightened(0.4), 110.0)
			splash(0.5, at)
			freeze(0.18, victim)
			kick(4.0)
		"bounce":   # (off the ground: a flat shockwave and dust - small and grey, 22:57 no massive white circles)
			_add("shock", at, Vector2.ZERO, 0.22, Color("#9a9daa"), 38.0)
			for i in 10:
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("chip", at, Vector2(side * _rng.randf_range(150.0, 360.0), _rng.randf_range(-260.0, -80.0)),
						_rng.randf_range(0.3, 0.5), Color("#b9bcc8"), _rng.randf_range(3.0, 6.0))
			freeze(0.07, victim)
			kick(4.0)
		"splat":   # (stuck to the wall: a big impact on it)
			_add("spokes", at, Vector2.ZERO, 0.22, Color.WHITE, 70.0)
			_add("shock", at, Vector2.ZERO, 0.3, victim_col.lightened(0.4), 90.0)
			_debris(at, -face, 32)
			splash(0.4, at)
			freeze(0.12, victim)
			kick(6.0)
		"restand":   # (hit as they land from an air combo: back in a ground combo)
			pass   # (no word - 20 Oct 14:22 "Dont keep the words")
		"ic":   # (an Instant Cancel: a purple snap)
			_add("shock", at, Vector2.ZERO, 0.18, Color("#c58bff"), 50.0)
		"whiff":   # (a Whiff Cancel: a quick white ring off them)
			_add("shock", at, Vector2.ZERO, 0.18, Color.WHITE, 46.0)
		# the Bruiser (05:27 "his effects of slapping an enemy accross map" - the Nakmuay mod, studied; our own drawing)
		"fling":   # (a big hit sending them off: a tall ring of air bursting out the way they fly, cracks - and streaks
			# trailing BEHIND the impact, the momentum of his strike (15:21 "Put them behind the impact to try and show the
			# momentum of his punch" - they used to fly off across the screen the way she went; sized by the fighters,
			# 15:10: only where the move reaches))
			_add_scr("boom", at + Vector2(face * 10.0, 0.0), Vector2.ZERO, 0.48, by.lightened(0.7), 0.36, 0.0, face)
			_add_scr("boom", at + Vector2(face * 34.0, 0.0), Vector2.ZERO, 0.4, by.lightened(0.45), 0.24, 0.0, face)
			for i in 9:   # (momentum lines in his colour: each thick by the impact, thinning back toward him, easing on
				# into it - over the starburst, under the fighters)
				var off := Vector2(-face * _rng.randf_range(4.0, 34.0), _rng.randf_range(-36.0, 36.0))
				_add("mline", at + off, Vector2(face * _rng.randf_range(120.0, 320.0), 0.0), _rng.randf_range(0.26, 0.38),
						by.lightened(0.35), _rng.randf_range(80.0, 170.0), face)
				parts[-1]["w"] = 0.0
			if at.y > -140.0:
				_add("crack", Vector2(at.x, 0.0), Vector2.ZERO, 1.4, Color("#c9ccd8"), 120.0, face)
			splash(0.45, at)
			freeze(0.12, victim)
			kick(7.0)
		"quake":   # (Quake Stomp: spikes bursting up out of the floor and a curtain of debris thrown up, only over the
			# strip its shockwave hits - QUAKE_REACH either way from his foot (15:10); the floor cracking; the stage
			# shaken lightly - YOMI's ground pound)
			_add("floorring", Vector2(at.x, 0.0), Vector2.ZERO, 0.45, Color("#e6e9f2"), QUAKE_REACH * 0.85)
			_add("crack", Vector2(at.x, 0.0), Vector2.ZERO, 1.1, Color("#c9ccd8"), QUAKE_REACH, 0.0)
			_quake_spikes(at.x)
			for i in QUAKE_DEBRIS:   # (thrown straight up off the strip, the middle highest)
				var u := _rng.randf_range(-1.0, 1.0)
				_add("chip", Vector2(at.x + u * QUAKE_REACH, -4.0), Vector2(u * _rng.randf_range(20.0, 90.0),
						-_rng.randf_range(380.0, 900.0) * (1.0 - 0.45 * absf(u))), _rng.randf_range(0.35, 0.6),
						Color("#a9acb8") if i % 3 else Color("#d6d9e3"), _rng.randf_range(3.0, 7.0))
			kick(2.5)
		"rush":   # (Bull Rush / Chase setting off: dust kicked back, a streak behind)
			for i in 8:
				var off := Vector2(0.0, _rng.randf_range(-0.1, 0.07) * band / maxf(view_zoom, 0.05))
				_add_scr("hwind", at + off, Vector2(-face * _rng.randf_range(1000.0, 1600.0), 0.0), 0.3, Color("#dfe6f5"),
						_rng.randf_range(0.14, 0.3))
			kick(2.0)
		"kopunch":   # (the K.O. Punch coming up: a hard flash at his fist)
			_add("glint", at + Vector2(face * 20.0, -30.0), Vector2.ZERO, 0.3, Color.WHITE, 70.0)
			_add("rays", at, Vector2.ZERO, 0.3, by.lightened(0.5), 120.0)
			kick(3.0)
		"grit":   # (his Grit full - the K.O. Punch is there: a hot flare round him)
			_add("glow", at, Vector2.ZERO, 0.45, Color("#ff9a3c"), 80.0)
			_add("shock", at, Vector2.ZERO, 0.3, Color("#ffb766"), 70.0)
		"guardbreak":   # (straight through a guard: the guard arc in pieces)
			for i in 8:
				_add("chip", at, _fan(face, 1.6) * _rng.randf_range(200.0, 420.0), _rng.randf_range(0.25, 0.4), BLOCK,
						_rng.randf_range(4.0, 7.0))
		"armored":   # (Super Armor taking it: a hard metal glint on him, no hitstun)
			_add("glint", at, Vector2.ZERO, 0.24, Color("#ffe7b0"), 46.0)
			flash[victim] = 0.06
		"edge":   # (a spacer's hit at the fan's edge: a gold glint)
			_add("glint", at, Vector2.ZERO, 0.32, Color("#ffd23f"), 34.0)
		"blink":   # (Fan Step: a flash where she lands, a ring of her colour)
			_add("glow", at, Vector2.ZERO, 0.25, by.lightened(0.4), 60.0)
			_add("sweep", at, Vector2.ZERO, 0.25, by, 70.0, 0.0)
		"sweep", "sweep_up":   # (a giant fan swept out in her colour - Violet's arc in the mod study; up for Updraft)
			_add("sweep", at, Vector2.ZERO, 0.3, by, 92.0, face if type == "sweep" else 0.0)
		"galering":   # (Gale: a ring of short wind arcs racing out all round her - arcs, not a white circle)
			for k in 3:
				_add("windring", at, Vector2.ZERO, 0.32 + 0.06 * k, by.lightened(0.55), 40.0 + 34.0 * k)
				parts[-1]["w"] = 0.0
			kick(3.0)
		"gust":   # (Updraft: wind off both fans, rushing up in front of her)
			for k in 9:
				var off := Vector2(face * _rng.randf_range(-20.0, 60.0), _rng.randf_range(-20.0, 30.0))
				_add("wind", at + off, Vector2(face * _rng.randf_range(0.0, 80.0), -_rng.randf_range(650.0, 950.0)),
						_rng.randf_range(0.35, 0.5), Color("#dff3ff"), _rng.randf_range(26.0, 44.0))
		"beat":   # (Tempo: a beat - a small pink flick off her, no word: Tempo's always on now, it'd be noise)
			_add("glint", at + Vector2(0, -40), Vector2(0, -60), 0.3, Color("#ff7ab6"), 14.0)
		"onbeat":   # (Tempo full: a pink ring)
			_add("shock", at, Vector2.ZERO, 0.3, Color("#ff7ab6"), 70.0)
		"ward":   # (Fan Ward: the fan stops and hangs - a small ring of her colour where it waits)
			_add("ring", at, Vector2.ZERO, 0.3, by.lightened(0.3), 30.0)
			_add("glint", at, Vector2.ZERO, 0.22, by.lightened(0.6), 22.0)
		"reflect":   # (Mirror turns a shot round: a quick glint - no big circle)
			_add("glint", at, Vector2.ZERO, 0.26, Color.WHITE, 40.0)
			_add("shock", at, Vector2.ZERO, 0.22, by.lightened(0.4), 46.0)
		"gustfwd":   # (Fan Gust: wind off her fans, rushing out along the way she faces)
			for k in 12:
				var off := Vector2(face * _rng.randf_range(0.0, 50.0), _rng.randf_range(-80.0, 50.0))
				_add("hwind", at + off, Vector2(face * _rng.randf_range(700.0, 1000.0), _rng.randf_range(-30.0, 30.0)),
						_rng.randf_range(0.3, 0.45), Color("#dff3ff"), _rng.randf_range(30.0, 56.0))
		"gusted":   # (caught in the gust: a few streaks past them)
			for k in 4:
				var off := Vector2(0.0, _rng.randf_range(-40.0, 40.0))
				_add("hwind", at + off, Vector2(face * _rng.randf_range(500.0, 800.0), 0.0), 0.3, Color("#dff3ff"), 34.0)
		"catch", "recall":   # (Fans: one back in hand / called home - a gold ring)
			_add("shock", at, Vector2.ZERO, 0.18, Color("#ffd23f"), 34.0 if type == "catch" else 64.0)
		"form_snap":   # (Forms, each its own - 23 Oct: the snap: a sharp little cone of petals out the way she faces)
			petal_slap(at, face, by, seed_n, 14)
		"form_floor":   # (the floor: a ring of her colour opening on the floor under her)
			_add("floorring", Vector2(at.x, 0.0), Vector2.ZERO, 0.5, by, 46.0)
		"form_flow":   # (the flow: her petals circling her)
			petal_dance(at, by, seed_n, 12)
		"sad":   # (Sadness building)
			pass   # (no word - 20 Oct 14:22 "Dont keep the words")
		"sadness":   # (SADNESS: a blue wash)
			_add("shock", at, Vector2.ZERO, 0.4, Color("#5d7bd6"), 120.0)
		"time":   # (the round's out)
			splash(0.6, at)
			freeze(0.4, -1)
		"wall":   # (launched into the wall and off it)
			_add("shock", at, Vector2.ZERO, 0.2, Color("#9a9daa"), 34.0)
			_add("spokes", at, Vector2.ZERO, 0.14, Color.WHITE, 40.0)
			_debris(at, -face, 20)
			freeze(0.06, victim)
			kick(3.0)
		"hit", "throw", "armor":
			var s := clampf(float(dmg) / 32.0, 0.5, 1.8)
			if type == "throw":   # (a dark sphere closes round the two of them - the mods' grabs - and wide rings open out)
				_add("bubble", at, Vector2.ZERO, 0.5, Color("#05060a"), 72.0)
				_wide_rings(at, Color("#c9ccd8"), 2)
			# (23:05 "This is an example of the normal hit effect": a dark jagged starburst behind it, longest along
			# the hit - the YOMI mods' look; low contrast, so the fighters and sparks read on top)
			_add("ink", at, Vector2.ZERO, 0.42, INK, 60.0 + 26.0 * s, face)
			var look := style
			style = ""
			if look == "fan" and type == "hit":   # (her fan's cut: the crescents, and her petals thrown out - Umbra's)
				petal_burst(at, by, int(at.x * 7.0 + at.y * 3.0) + dmg)
				look = "slash"
			if look == "slash" and type == "hit":   # (step 4: a fan's cut - two thin crescents across it, no star)
				_add("slash", at, Vector2.ZERO, 0.24, by.lightened(0.3), 62.0 + 18.0 * s, face)
				parts[-1]["w"] = 0.0
				_add("slash", at + Vector2(0, 6), Vector2.ZERO, 0.2, by.lightened(0.55), 44.0 + 12.0 * s, -face * 0.5)
				parts[-1]["w"] = 0.0
			elif look == "kick" and type == "hit":   # (step 3, Nakmuay's angle hit: a cone of spikes along the blow and
				# a side-on shock wave pushed out ahead of it)
				_add("cone", at, Vector2.ZERO, 0.17, Color.WHITE, 40.0 * s, face)
				_add("pring", at + Vector2(face * 10.0, 0.0), Vector2(face * 180.0, 0.0), 0.18, Color.WHITE, 30.0 * s, face)
			elif look == "overhead" and type == "hit":   # (step 3, Nakmuay's overhead: a thin crescent sweeping down
				# over the hit, and a small bloom where it lands)
				_add("crescent", at + Vector2(-face * 6.0, -10.0), Vector2.ZERO, 0.2, Color.WHITE, 42.0 * s, face)
				_add("bloom", at, Vector2.ZERO, 0.15, Color.WHITE, 18.0 * s)
			elif look == "wave" and type == "hit":   # (the ground ripple: dust thrown up round their feet)
				var feet := Vector2(at.x, maxf(at.y, -20.0))
				for i in 10:
					var side := 1.0 if i % 2 == 0 else -1.0
					_add("chip", feet, Vector2(side * _rng.randf_range(60.0, 220.0), -_rng.randf_range(260.0, 520.0)),
							_rng.randf_range(0.3, 0.5), Color("#a9acb8"), _rng.randf_range(3.0, 6.0))
				_add("star", at, Vector2.ZERO, 0.14, YELLOW, 20.0 * s)
			else:   # (blunt: a kick, a knee - the spark on the dark starburst)
				_burst(at, face, s, by, victim_col)
			if counter:   # (they were mid-attack: a harder flash)
				flash[victim] = 0.08
			if dmg >= 45:   # (a hard one: impact lines in the hitter's colour, the one hit flashes white - no big white
				# ring any more: 22:57 "I dont love the massive white circle thing")
				_add("spokes", at, Vector2.ZERO, 0.14, by.lightened(0.55), 34.0 * s)
				flash[victim] = 0.06
			if dmg >= 45:
				splash(0.35, at)
			if dmg >= BIG_HIT and type != "armor":   # (step 3: Nakmuay's ring, thinning, breaking)
				_add("rring", at, Vector2.ZERO, 0.26, Color.WHITE, 48.0 * s)
			if dmg >= HUGE_HIT and type != "armor":   # (14:09 19 Oct: a giant starburst and rings, sized by the screen -
				_big(at, by)                           # 23 Oct "way too much": the knockout-size hits only)
			freeze(clampf(0.04 + float(dmg) * 0.0018, 0.05, 0.14) * impact, victim)
			kick(clampf(float(dmg) * 0.1, 1.5, 5.0) * impact)
			impact = 1.0
		"block":   # (a guard arc - red when blocked at the wrong height; a big one for a Push Block)
			_add("guard", at, Vector2.ZERO, 0.2 if not push else 0.3, Color("#ff7a7a") if counter else BLOCK,
					30.0 if not push else 48.0, -face)
			for i in 4:
				_add("chip", at, _fan(-face, 1.3) * _rng.randf_range(160.0, 320.0), _rng.randf_range(0.2, 0.32),
						Color.WHITE, _rng.randf_range(2.5, 4.0))
			freeze(0.04, victim)
			kick(1.0)
		"parry":
			_add("glint", at, Vector2.ZERO, 0.26, Color.WHITE, 58.0)
			_add("shock", at, Vector2.ZERO, 0.2, BLOCK, 44.0)
			freeze(0.12, -1)
			kick(2.0)
		"clash", "tech":
			var big := type == "clash"
			_add("star", at, Vector2.ZERO, 0.16, ORANGE, 30.0 if big else 20.0)
			for i in (8 if big else 4):
				var side := 1.0 if i % 2 == 0 else -1.0
				_add("box" if i % 3 else "ring", at, _fan(side, 1.0) * _rng.randf_range(220.0, 480.0),
						_rng.randf_range(0.25, 0.4), ORANGE if i % 2 else YELLOW, _rng.randf_range(3.0, 6.0))
			if big:   # (two strikes meeting: wide rings round them - 14:09)
				_wide_rings(at, Color("#ffd8a8"), 2)
			freeze(0.08 if big else 0.05, -1)
			kick(2.5 if big else 1.5)
		"ko":
			_add("shock", at, Vector2.ZERO, 0.42, victim_col.lightened(0.35), 150.0)
			_add("shock", at, Vector2.ZERO, 0.3, Color.WHITE, 96.0)
			for i in 14:
				_add("chip", at, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(200.0, 560.0),
						_rng.randf_range(0.4, 0.7), victim_col if i % 3 else Color.WHITE, _rng.randf_range(3.0, 6.0))
			_add("spokes", at, Vector2.ZERO, 0.2, Color.WHITE, 90.0)
			_big(at, victim_col.lightened(0.5), 0.55)
			flash[victim] = 0.12
			splash(0.8, at)
			freeze(0.22, victim)
			kick(6.0)


## A part sized by the screen (see `band`): `share` of the stage band's height, `vel` in screen px/s, starting after
## `delay` seconds.
func _add_scr(kind: String, at: Vector2, vel: Vector2, life: float, c: Color, share: float, delay := 0.0,
		extra := 0.0) -> Dictionary:
	var p := {"k": kind, "p": at, "v": vel / maxf(view_zoom, 0.05), "age": -delay, "life": life, "c": c, "s": share,
		"r": _rng.randf() * TAU, "w": 0.0, "x": extra, "scr": true}
	parts.append(p)
	return p


## A big hit (BIG_HIT and over, a K.O.): a giant white starburst behind everyone - the fighters dark against it - and
## rings opening out wide (14:09, the mod video's big hits: half the screen across).
func _big(at: Vector2, by: Color, share := 0.42) -> void:
	var p := _add_scr("bigstar", at, Vector2.ZERO, 0.42, Color.WHITE, share)
	var sp: Array = []
	for i in 36:   # (spikes long and uneven, a few longer still; short valleys between)
		sp.append(_rng.randf_range(0.16, 0.24) if i % 2 == 1 else _rng.randf_range(0.55, 1.0) * (1.3 if i % 10 == 0 else 1.0))
	p["sp"] = sp
	for k in 3:
		_add_scr("wring", at, Vector2.ZERO, 0.5, Color("#eef0f6") if k != 1 else by.lightened(0.6), share * (0.8 + 0.5 * k),
				0.04 * k, 0.6 - 0.14 * k)


## Wide thin rings round a grab or a clash: wider than the two of them together at any zoom.
func _wide_rings(at: Vector2, c: Color, n: int) -> void:
	var share := maxf(0.36, 190.0 * view_zoom / band)
	for k in n:
		_add_scr("wring", at, Vector2.ZERO, 0.5, c, share * (1.0 + 0.4 * k), 0.07 * k, 0.45 - 0.1 * k)


## Quake Stomp's spikes: grey shards bursting up out of the floor over the strip it hits, from his foot outwards (world
## sizes - they stay where they are, whatever the camera does).
func _quake_spikes(x0: float) -> void:
	var sp: Array = []
	for k in QUAKE_SPIKES:
		var u := (float(k) + _rng.randf_range(0.1, 0.9)) / float(QUAKE_SPIKES) * 2.0 - 1.0   # (spread evenly, -1 to 1)
		var x := x0 + u * QUAKE_REACH
		if absf(x) > walls - 10.0:   # (not through the walls)
			continue
		var tall := _rng.randf_range(34.0, 70.0) * (1.25 - 0.6 * absf(u))   # (tallest by his foot)
		sp.append([x, tall, _rng.randf_range(9.0, 17.0), _rng.randf_range(-0.1, 0.1) + 0.22 * u, absf(u) * 0.06,
			_rng.randf()])
	sp.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))   # (the tall ones behind)
	_add("spikes", Vector2(x0, 0.0), Vector2.ZERO, 0.75, Color("#8e92a2"), 1.0)
	parts[-1]["sp"] = sp


## Someone bursts out of a combo: a white flash bursts out of them, shards and rings fly, everything nearby is blown
## back (the sim), it holds a moment and splits.
func burst_out(id: int, at: Vector2, col: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	# (23 Oct 13:49 "way too much": about half the size, fewer shards, a shorter hold - the Nakmuay fight's scale)
	_add("flash", at, Vector2.ZERO, 0.24, Color.WHITE, 85.0)
	_add("shock", at, Vector2.ZERO, 0.3, col.lightened(0.5), 120.0)
	_add("rays", at, Vector2.ZERO, 0.24, Color.WHITE, 95.0)
	for i in 10:
		var dir := Vector2.from_angle(TAU * float(i) / 10.0 + _rng.randf_range(-0.15, 0.15))
		_add("shard", at + dir * 24.0, dir * _rng.randf_range(260.0, 480.0), _rng.randf_range(0.25, 0.4),
				Color("#9fe8ff") if i % 3 else col.lightened(0.5), _rng.randf_range(8.0, 14.0))
	flash[id] = 0.1   # (no confetti rings or white ring - 23:11, 00:22)
	splash(0.5, at)
	freeze(0.2, -1)
	kick(3.0)


## Someone starts a super: the stage dims round them, rays and rings burst out, it all holds a moment and splits.
func super_start(id: int, at: Vector2, col: Color, seed_n: int, title := "", pose := "idle", face := 1.0) -> void:
	_rng.seed = seed_n
	pass   # (no banner or name - 03:03 "I dont like the big on screen super banner ... they definitely do not have those")
	dim = 0.62
	dim_id = id
	# (23 Oct 13:49 "way too much": the rays and ring about half, a lighter colour split - the dim and the hold carry it)
	_add("rays", at, Vector2.ZERO, 0.3, col.lightened(0.45), 100.0)
	_add("glow", at, Vector2.ZERO, 0.4, col, 70.0)
	_add("shock", at, Vector2.ZERO, 0.3, col.lightened(0.3), 95.0)
	_add("floorring", Vector2(at.x, 0.0), Vector2.ZERO, 1.1, col, 100.0)   # (a ring of her colour glowing on the floor -
	# Yharim's; no confetti shapes - 23:11)
	splash(0.45, at)
	freeze(0.3, -1)
	kick(2.0)


## A stretch of ribbon along the floor (Silk Glide), from a to b (world), fading from where it was laid.
func ribbon(a: Vector2, b: Vector2, c: Color) -> void:
	parts.append({"k": "ribbon", "p": a, "b": b, "v": Vector2.ZERO, "age": 0.0, "life": 0.45, "c": c, "s": 9.0,
		"r": 0.0, "w": 0.0, "x": 0.0})


## YOMI's movement particles (23 Oct 13:36 Timmy: "Just use YOMI and its Char Mods as inspiration"): round dots in the
## fighter's colour shot out and slowing to a stop - its JumpParticle, DashFloorParticle, DashParticle, LandingParticle
## (study only: their counts, spreads, speeds, lifetimes, damping), scaled from YOMI's 32-tall fighters to ours.
const YS := 3.3


func _dots(at: Vector2, dir: Vector2, spread_deg: float, n: int, speed: float, life: float, size: float, c: Color,
		rect := 0.0, sphere := 0.0) -> void:
	for i in n:
		var a := dir.angle() + deg_to_rad(_rng.randf_range(-spread_deg, spread_deg))
		var off := Vector2(_rng.randf_range(-rect, rect), 0.0) * YS
		if sphere > 0.0:
			off = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * sphere * YS
		_add("dot", at + off, Vector2.from_angle(a) * speed * YS * _rng.randf_range(0.15, 1.0),
				life * _rng.randf_range(0.25, 1.0), c, size * YS * _rng.randf_range(0.45, 1.0), 35.8 * YS * BIG)


## Her petals, after the Umbra mod (study only - its petal hit, slap and dance; Timmy 13:45 "With the petals matching
## her colour"): in her colour, a little lighter and darker so they read as petals, each spinning.
func _petal_col(c: Color) -> Color:
	return c.lightened(_rng.randf_range(0.0, 0.35)) if _rng.randf() < 0.7 else c.darkened(_rng.randf_range(0.0, 0.2))


## A fan hit: petals thrown out every way, spinning fast, slowing, gone in under a second.
func petal_burst(at: Vector2, c: Color, seed_n: int, n := 14) -> void:
	_rng.seed = seed_n
	for i in n:
		var v := Vector2.from_angle(_rng.randf() * TAU) * 162.0 * YS * _rng.randf_range(0.2, 1.0)
		_add("upetal", at, v, _rng.randf_range(0.3, 0.7), _petal_col(c), _rng.randf_range(9.0, 15.0), 260.0 * YS * BIG)
		parts[-1]["w"] = _rng.randf_range(-12.0, 12.0)


## A throw / a fan's slash: a dense cone of petals flung out the way she faces that stops almost at once and hangs.
func petal_slap(at: Vector2, face: float, c: Color, seed_n: int, n := 34) -> void:
	_rng.seed = seed_n
	for i in n:
		var a := Vector2(face, 0.0).angle() + deg_to_rad(_rng.randf_range(-30.0, 30.0))
		var v := Vector2.from_angle(a) * 1000.0 * YS * 0.18 * _rng.randf_range(0.2, 1.0)
		_add("upetal", at, v, _rng.randf_range(0.45, 0.9), _petal_col(c), _rng.randf_range(8.0, 13.0), 2600.0 * BIG)
		parts[-1]["w"] = _rng.randf_range(-5.0, 5.0)


## A spin: petals circling round her, drifting outward as they go.
func petal_dance(center: Vector2, c: Color, seed_n: int, n := 18) -> void:
	_rng.seed = seed_n
	for i in n:
		var th := _rng.randf() * TAU
		var rad := _rng.randf_range(30.0, 60.0)
		_add("opetal", center + Vector2.from_angle(th) * rad, Vector2.ZERO, _rng.randf_range(0.5, 1.0), _petal_col(c),
				_rng.randf_range(8.0, 12.0))
		parts[-1]["th"] = th
		parts[-1]["rad"] = rad
		parts[-1]["om"] = _rng.randf_range(5.0, 8.0) * (1.0 if _rng.randf() < 0.8 else -1.0)
		parts[-1]["c0"] = center
		parts[-1]["w"] = _rng.randf_range(-6.0, 6.0)


## A jump leaving the floor: a burst straight down off the feet, a little spray along the floor both ways.
func takeoff(feet: Vector2, c: Color, s: float, seed_n: int) -> void:
	_rng.seed = seed_n
	_dots(feet, Vector2.DOWN, 6.55, int(21 * s), 84.6, 0.4, 6.9, c)
	for side: float in [1.0, -1.0]:
		_dots(feet, Vector2(side, -0.787).normalized(), 10.4, int(10 * s), 144.0, 0.29, 5.5, c, 16.0)


## An air jump: the burst down off the feet, in the air.
func airjump(feet: Vector2, c: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	_dots(feet, Vector2.DOWN, 6.55, 21, 84.6, 0.4, 6.9, c)


## A dash setting off (dir: the way they go): dots kicked up off the floor behind, a short cone off the body.
func dash_off(feet: Vector2, dir: float, c: Color, seed_n: int, air := false) -> void:
	_rng.seed = seed_n
	if not air:
		_dots(Vector2(feet.x, 0.0), Vector2(-dir, -0.787).normalized(), 10.4, 24, 144.0, 0.29, 5.5, c, 16.0)
	_dots(feet + Vector2(0.0, -50.0), Vector2(-dir, 0.0), 6.55, 21, 73.9, 0.42, 5.2, c, 0.0, 9.4)


## Step 5 (23 Oct): his Bull Rush running - Nakmuay's Rhino's Charge: a few speed lines off his back, thick at
## him, thinning behind.
func charge(at: Vector2, face: float, c: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	for i in 2:
		var off := Vector2(-face * _rng.randf_range(8.0, 26.0), _rng.randf_range(-40.0, 34.0))
		_add("mline", at + off, Vector2(-face * _rng.randf_range(60.0, 140.0), 0.0), _rng.randf_range(0.16, 0.22),
				c.lightened(0.5), _rng.randf_range(50.0, 90.0), face)
		parts[-1]["w"] = 0.0


## His Elbow Drop meeting the floor: a ring in his colour, a few cracks, dust and a jolt (Quake's, much smaller).
func slam(at: Vector2, c: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	_add("floorring", Vector2(at.x, 0.0), Vector2.ZERO, 0.4, c.lightened(0.4), 60.0)
	_add("crack", Vector2(at.x, 0.0), Vector2.ZERO, 1.8, Color("#c9ccd8"), 72.0, 0.0)   # (the floor's damage stays a
	# while, then fades - 15:32 "leave a temp damage effect")
	dust(Vector2(at.x, 0.0), 0.8, seed_n)


## Touching down: dots sprayed along the floor both ways.
func landing(feet: Vector2, c: Color, s: float, seed_n: int) -> void:
	_rng.seed = seed_n
	for side: float in [1.0, -1.0]:
		_dots(Vector2(feet.x, 0.0), Vector2(side, -0.787).normalized(), 10.4, int(14 * s), 144.0, 0.29, 5.5, c, 16.0)


## Dust off the ground (a landing, feet sliding): grey bits kicked out both ways, low.
func dust(at: Vector2, s: float, seed_n: int) -> void:
	_rng.seed = seed_n
	for i in int(4 + 6 * s):
		var side := 1.0 if i % 2 == 0 else -1.0
		_add("chip", at + Vector2(side * _rng.randf_range(4.0, 14.0), -2.0),
				Vector2(side * _rng.randf_range(80.0, 260.0) * s, -_rng.randf_range(40.0, 160.0) * s),
				_rng.randf_range(0.2, 0.38), Color("#8d909c"), _rng.randf_range(2.5, 5.0))
	if s > 0.7:
		kick(1.0 + s)


## The colour split (the post shader): `amount` 0-1, from a world point.
func splash(amount: float, at: Vector2) -> void:
	if amount >= split:
		split_at = at
	split = maxf(split, amount)


## A fading copy of a fast mover (StageView calls it every couple of ticks they're quick).
## `solid`: a solid grey copy that hangs a while (the Bruiser rushing in - 14:09 "The red guy could help with bruiser").
func afterimage(id: int, rec: Array, solid := false) -> void:
	var mine := afters.filter(func(a: Dictionary) -> bool: return int(a["id"]) == id)
	if mine.size() >= (AFTER_SOLID if solid else AFTER_EACH):   # (capped - each copy is a whole figure to draw; 02:39
		afters.erase(mine[0])                                    # "choppy ... with 4")
	if afters.size() >= AFTER_ALL:
		afters.pop_front()
	afters.append({"id": id, "rec": rec.duplicate(), "age": 0.0, "life": 0.5 if solid else 0.32, "solid": solid})


## Smoke: a puff or two left where someone knocked back fast is (each tick they're that fast).
func smoke(at: Vector2, seed_n: int) -> void:
	_rng.seed = seed_n
	for i in 2:
		_add("puff", at + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-16.0, 16.0)),
				Vector2(_rng.randf_range(-20.0, 20.0), -_rng.randf_range(10.0, 40.0)), _rng.randf_range(0.3, 0.5),
				Color("#c9ccd8"), _rng.randf_range(10.0, 17.0))


## Debris off a wall slam: big chunks flying back off the wall into the stage (`inward` = the way that is), sized by
## the screen - a third of it (YOMI's wall slam: 32 large pieces).
func _debris(at: Vector2, inward: float, n: int) -> void:
	for i in n:
		var v := Vector2(inward * _rng.randf_range(350.0, 1300.0), _rng.randf_range(-950.0, 250.0))
		var c := Color("#c9ccd8") if i % 3 else Color("#eef0f6")
		_add_scr("chip", at + Vector2(0.0, _rng.randf_range(-0.08, 0.08) * band / maxf(view_zoom, 0.05)), v,
				_rng.randf_range(0.35, 0.7), c, _rng.randf_range(0.012, 0.032))


func freeze(seconds: float, who: int) -> void:
	hitstop = maxf(hitstop, seconds * 1.35)   # (a hit holds a little longer - it lands harder)
	if who >= 0 and not jitter.has(who):
		jitter.append(who)


func kick(px: float) -> void:
	px *= 1.3
	shake = maxf(shake, px)


## The burst where a hit lands: a spiky star (the dark starburst goes behind it - on_event).
## (23:11 "remove the random shapes on hit as well": no flying rings, squares or chips - the spark and the dark
## starburst behind it carry the hit)
func _burst(at: Vector2, _face: float, s: float, _by: Color, _victim_col: Color) -> void:
	# (step 3, 23 Oct - Nakmuay's hit sheet as the model: a white spiky burst that blooms and hollows out into streaks;
	# the yellow star kept small at its heart)
	_add("bloom", at, Vector2.ZERO, 0.17, Color.WHITE, 26.0 * s)   # (13:49 "way too much": one small spark, no star)


## A direction fanned round the way a hit goes (a little upward).
func _fan(face: float, spread: float) -> Vector2:
	var ang := Vector2(face, -0.35).angle() + _rng.randf_range(-spread, spread)
	return Vector2.from_angle(ang)


func _add(kind: String, at: Vector2, vel: Vector2, life: float, c: Color, size: float, extra := 0.0) -> void:
	size *= BIG   # (22:40 "We dont do things big enough": every effect bigger)
	life *= 1.15
	vel *= BIG
	var p := {"k": kind, "p": at, "v": vel, "age": 0.0, "life": life, "c": c, "s": size, "r": _rng.randf() * TAU,
		"w": _rng.randf_range(-9.0, 9.0), "x": extra}
	if kind in ["bloom", "cone"]:   # (their spikes' lengths)
		var sp2: Array = []
		for i in 22:
			sp2.append(_rng.randf_range(0.45, 1.0))
		p["sp"] = sp2
	if kind == "rring":   # (where the ring breaks as it thins)
		p["gaps"] = [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	if kind == "star":
		var sp: Array = []
		for i in 12:
			sp.append(_rng.randf_range(0.65, 1.0) if i % 2 == 0 else 0.34)
		p["sp"] = sp
	if kind == "crack":   # (a few jagged lines along the floor, a little above and below it, out one way or both)
		var lines: Array = []
		for i in 5:
			var dir := signf(extra) if absf(extra) > 0.1 else (1.0 if i % 2 == 0 else -1.0)
			var line: Array = [Vector2.ZERO]
			var x := 0.0
			var y := 0.0
			var reach := size * _rng.randf_range(0.5, 1.0)
			while x < reach:
				x += _rng.randf_range(8.0, 22.0)
				y = clampf(y + _rng.randf_range(-5.0, 5.0), -6.0, 7.0)
				line.append(Vector2(dir * x, y))
			lines.append(line)
		p["sp"] = lines
	if kind == "ink":   # (spikes: long and uneven, the longest along the hit's way (extra = facing) and up / down)
		var sp: Array = []
		var n := 18
		for i in n * 2:
			var ang := float(p["r"]) + i * PI / n
			if i % 2 == 1:
				sp.append(_rng.randf_range(0.22, 0.38))
				continue
			var along := absf(cos(ang - (0.0 if extra >= 0.0 else PI)))
			sp.append(_rng.randf_range(0.45, 0.8) + 0.35 * along * (1.0 if cos(ang) * extra > 0.0 else 0.6))
		p["sp"] = sp
	parts.append(p)


## A striking limb's tip and the joint it swings from (world), each tick its hit is out.
func trail_point(id: int, tip: Vector2, pivot: Vector2, c: Color) -> void:
	var t: Dictionary = trails.get(id, {})
	if t.is_empty() or float(t["fade"]) >= 0.0:
		t = {"pts": [], "c": c, "fade": -1.0}
		trails[id] = t
	var pts: Array = t["pts"]
	pts.append([tip, pivot])
	if pts.size() > TRAIL_KEEP:
		pts.pop_front()


func trail_end(id: int) -> void:
	if trails.has(id) and float(trails[id]["fade"]) < 0.0:
		trails[id]["fade"] = 0.0


func update(delta: float) -> void:
	hitstop = maxf(0.0, hitstop - delta)
	if not cutin.is_empty():
		cutin["age"] = float(cutin["age"]) + delta
		if float(cutin["age"]) >= float(cutin["life"]):
			cutin = {}
	if hitstop <= 0.0:
		jitter.clear()
	for p: Dictionary in parts:
		p["age"] = float(p["age"]) + delta
		var v: Vector2 = p["v"]
		if p["k"] == "chip":
			v.y += 1100.0 * delta
			v *= pow(0.3, delta)
		elif p["k"] == "upetal":   # (Umbra's petals: slowed steadily to a stop, still spinning - x = the damping)
			var sp2 := v.length()
			v = v / sp2 * maxf(0.0, sp2 - float(p["x"]) * delta) if sp2 > 0.0 else v
		elif p["k"] == "opetal":   # (a dance petal: circling her, drifting out - theta, radius, its centre)
			p["th"] = float(p["th"]) + float(p["om"]) * delta
			p["rad"] = float(p["rad"]) + 26.0 * delta
			var to: Vector2 = (p["c0"] as Vector2) + Vector2.from_angle(float(p["th"])) * float(p["rad"]) * Vector2(1.0, 0.45)
			v = (to - (p["p"] as Vector2)) / maxf(delta, 0.001)
		elif p["k"] == "dot":   # (YOMI's particles: no gravity, slowed steadily to a stop - x = the damping)
			var sp := v.length()
			v = v / sp * maxf(0.0, sp - float(p["x"]) * delta) if sp > 0.0 else v
		elif p["k"] in ["petal", "ember"]:
			v = _bit_motion(p, v, delta)
		else:
			v *= pow(0.02, delta)
		p["v"] = v
		p["p"] = (p["p"] as Vector2) + v * delta
		p["r"] = float(p["r"]) + float(p["w"]) * delta
	parts = parts.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	shake *= pow(0.5, delta / 0.05)
	if shake < 0.3:
		shake = 0.0
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shake
	for id: int in trails.keys():
		if float(trails[id]["fade"]) >= 0.0:
			trails[id]["fade"] = float(trails[id]["fade"]) + delta
			if float(trails[id]["fade"]) > TRAIL_FADE:
				trails.erase(id)
	for a: Dictionary in afters:
		a["age"] = float(a["age"]) + delta
	afters = afters.filter(func(a: Dictionary) -> bool: return float(a["age"]) < float(a["life"]))
	for id: int in flash.keys():
		flash[id] = float(flash[id]) - delta
		if float(flash[id]) <= 0.0:
			flash.erase(id)
	if hitstop <= 0.0:   # (the dim holds through a super's freeze, then lifts)
		dim = maxf(0.0, dim - delta * 2.2)
		if dim <= 0.0:
			dim_id = -1
	split = maxf(0.0, split - delta * 2.6)


# ---------- drawing (through the stage's camera) ----------

## The arcs: pale, see-through, thin at the tail and widest at the limb's tip.
func draw_trails(st: StageView) -> void:
	for id: int in trails:
		var t: Dictionary = trails[id]
		var raw: Array = t["pts"]
		if raw.size() < 2:
			continue
		# (between two ticks the tip swings round its joint - an arc, not a straight cut). The swoosh fills what the
		# lower limb swept: from the tip in to a little past halfway to the joint.
		var outer: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for k in raw.size():
			var a: Array = raw[k]
			var b: Array = raw[mini(k + 1, raw.size() - 1)]
			var ra := ((a[0] as Vector2) - (a[1] as Vector2))
			var rb := ((b[0] as Vector2) - (b[1] as Vector2))
			for s in (4 if k < raw.size() - 1 else 1):
				var u := float(s) / 4.0
				var pivot := (a[1] as Vector2).lerp(b[1], u)
				var arm := Vector2.from_angle(lerp_angle(ra.angle(), rb.angle(), u)) * lerpf(ra.length(), rb.length(), u)
				outer.append(st.w2s(pivot + arm))
				inner.append(st.w2s(pivot + arm * INNER))
		var span := 0.0
		for k in outer.size() - 1:
			span += outer[k].distance_to(outer[k + 1])
		if span < 12.0:
			continue
		var fade := 1.0 if float(t["fade"]) < 0.0 else 1.0 - float(t["fade"]) / TRAIL_FADE
		var col := (t["c"] as Color).lerp(Color.WHITE, 0.55)
		var n := outer.size()
		var cols: Array[Color] = []
		for k in n:
			var c := col
			c.a = 0.85 * smoothstep(0.0, 0.55, float(k) / float(n - 1)) * fade
			cols.append(c)
		for k in n - 1:   # (raw triangles - a thin tail would fail draw_polygon's triangulation)
			st.draw_primitive(PackedVector2Array([outer[k], outer[k + 1], inner[k + 1]]),
					PackedColorArray([cols[k], cols[k + 1], cols[k + 1]]), PackedVector2Array())
			st.draw_primitive(PackedVector2Array([outer[k], inner[k + 1], inner[k]]),
					PackedColorArray([cols[k], cols[k + 1], cols[k]]), PackedVector2Array())
		# a bright rim along the tip's path
		var rim := PackedVector2Array()
		var rim_cols := PackedColorArray()
		for k in n:
			rim.append(outer[k])
			var c := Color(1, 1, 1, cols[k].a)
			rim_cols.append(c)
		st.draw_polyline_colors(rim, rim_cols, maxf(1.5, 3.0 * st.zoom), true)


## Behind the fighters: the dark starbursts of hits - quick to full size, holding, then fading; drawn as a fan of
## triangles (a star isn't convex).
func draw_back(st: StageView) -> void:
	for p: Dictionary in parts:
		var k := str(p["k"])
		if float(p["age"]) < 0.0:   # (not started yet - a delayed part)
			continue
		if k in ["bubble", "floorring", "ribbon", "crack", "spikes", "bigstar", "puff", "mline"]:
			_draw_back_part(st, p)
			continue
		if k != "ink":
			continue
		var t := float(p["age"]) / float(p["life"])
		var grow := minf(1.0, t / 0.12)
		var c: Color = p["c"]
		c.a = 0.95 * (1.0 - maxf(0.0, (t - 0.5) / 0.5))
		var at := st.w2s(p["p"])
		var s := float(p["s"]) * st.zoom * (0.6 + 0.4 * grow) * (1.0 + 0.08 * t)
		var sp: Array = p["sp"]
		var n := sp.size()
		var pts: Array[Vector2] = []
		for i in n:
			pts.append(at + Vector2.from_angle(float(p["r"]) + i * TAU / n) * s * float(sp[i]))
		var tri := PackedVector2Array()   # (one batched draw, not 36 - 02:39 "choppy ... with 4")
		var cols := PackedColorArray()
		for i in n:
			for q: Vector2 in [at, pts[i], pts[(i + 1) % n]]:
				tri.append(q)
				cols.append(c)
		Stick.tris(st, tri, cols)


## The mod-study pieces drawn behind the fighters: a throw's dark sphere, a super's ring on the floor, a glide's ribbon.
func _draw_back_part(st: StageView, p: Dictionary) -> void:
	var t := float(p["age"]) / float(p["life"])
	var c: Color = p["c"]
	var at := st.w2s(p["p"])
	var z := band if p.has("scr") else st.zoom   # (a screen-sized part: its size is a share of the band)
	match str(p["k"]):
		"mline":   # (a momentum line behind a big strike: a long wedge, thick at the impact end, thin back toward him)
			var ln := float(p["s"]) * z * (1.0 - 0.45 * t)
			var wd := maxf(2.0, 7.0 * z) * (1.0 - 0.6 * t)
			var back := Vector2(-float(p["x"]), 0.0)
			c.a = 0.95 * (1.0 - t * t)
			st.draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -wd / 2.0), at + Vector2(0.0, wd / 2.0),
					at + back * ln]), c)
		"puff":   # (smoke behind knockback: a soft grey puff swelling and thinning)
			c.a = 0.42 * (1.0 - t) * (1.0 - t)
			st.draw_circle(at, float(p["s"]) * z * (0.6 + 0.9 * t), c, true, -1.0, true)
		"spikes":   # (Quake Stomp's spikes: each shard shoots up fast when the wave reaches it, holds, sinks and fades - two
			# shades split down the middle, like a facet, and a pale edge)
			var floor_y := st.w2s(Vector2.ZERO).y
			var tri := PackedVector2Array()
			var cols := PackedColorArray()
			var rims: Array = []
			for q: Array in p["sp"]:
				var lt := float(p["age"]) - float(q[4])
				if lt <= 0.0:
					continue
				var rise := 1.0 - pow(1.0 - minf(1.0, lt / 0.07), 3.0)
				var fall := clampf((lt - 0.24) / 0.42, 0.0, 1.0)
				var zz := band if p.has("scr") else st.zoom   # (Quake Stomp's are world sizes - 15:10, local)
				var h := float(q[1]) * zz * rise * (1.0 - 0.45 * fall * fall)
				var w := float(q[2]) * zz * (1.0 - 0.3 * fall)
				var a := 0.9 * (1.0 - fall)
				if h < 2.0 or a < 0.02:
					continue
				var base := Vector2(st.w2s(Vector2(float(q[0]), 0.0)).x, floor_y)
				var tip := base + Vector2(float(q[3]) * h, -h)
				var l := base - Vector2(w / 2.0, 0.0)
				var r := base + Vector2(w / 2.0, 0.0)
				var m := base + Vector2(w * 0.1 * signf(float(q[3])), 0.0)
				var shade := float(q[5])
				var dark := Color("#585c6c").lerp(Color("#6f7385"), shade)
				var light := Color("#aeb2c0").lerp(Color("#cdd0db"), shade)
				dark.a = a
				light.a = a
				for v: Vector2 in [l, tip, m]:
					tri.append(v)
					cols.append(dark)
				for v: Vector2 in [m, tip, r]:
					tri.append(v)
					cols.append(light)
				rims.append([l, tip, Color(0.93, 0.94, 0.97, a)])
			Stick.tris(st, tri, cols)
			for rim: Array in rims:
				st.draw_line(rim[0], rim[1], rim[2], 1.5, true)
		"bigstar":   # (a giant white starburst: quick to full size, holding, fading - behind the fighters)
			var grow := 1.0 - pow(1.0 - minf(1.0, t / 0.14), 3.0)
			var fade := 1.0 - maxf(0.0, (t - 0.3) / 0.7)
			var rad := float(p["s"]) * z * (0.5 + 0.5 * grow) * (1.0 + 0.06 * t)
			var sp: Array = p["sp"]
			var n := sp.size()
			for layer in 2:   # (white, then a hot core)
				var cc := Color(1, 1, 1, 0.82 * fade) if layer == 0 else Color(HOT, 0.95 * fade)
				var rr := rad * (1.0 if layer == 0 else 0.5)
				var tri := PackedVector2Array()
				var cols := PackedColorArray()
				for i in n:
					var a0 := float(p["r"]) + i * TAU / n
					var a1 := float(p["r"]) + (i + 1) * TAU / n
					for v: Vector2 in [at, at + Vector2.from_angle(a0) * rr * float(sp[i]),
							at + Vector2.from_angle(a1) * rr * float(sp[(i + 1) % n])]:
						tri.append(v)
						cols.append(cc)
				Stick.tris(st, tri, cols)
		"bubble":   # (closing in fast, holding, fading - a pale rim)
			var r := float(p["s"]) * z * (1.3 - 0.3 * minf(1.0, t / 0.15))
			var a := 0.8 * (1.0 - maxf(0.0, (t - 0.55) / 0.45))
			for layer in 4:   # (soft-edged: darker toward the middle, no white rim - 23:11 no big white circles)
				c.a = a * 0.32
				st.draw_circle(at, r * (1.0 - layer * 0.16), c, true, -1.0, true)
		"floorring":   # (a flat glowing ring on the floor, opening out)
			var rx := float(p["s"]) * z * (0.5 + 0.5 * minf(1.0, t / 0.3))
			for layer in 3:
				var cc := c.lightened(0.3 * layer)
				cc.a = (0.5 - layer * 0.12) * (1.0 - t)
				var pts := PackedVector2Array()
				for n in 49:
					var a := TAU * n / 48.0
					pts.append(at + Vector2(cos(a) * rx * (1.0 + layer * 0.12), sin(a) * rx * 0.16 * (1.0 + layer * 0.12)))
				st.draw_polyline(pts, cc, maxf(1.5, (5.0 - layer) * st.zoom), true)
		"crack":   # (the floor cracked: jagged lines out along it from where it landed - one way (x = facing) or both)
			var sp: Array = p["sp"]
			c.a = 0.8 * (1.0 - maxf(0.0, (t - 0.45) / 0.55))
			for line: Array in sp:
				var pts := PackedVector2Array()
				for q: Vector2 in line:
					pts.append(at + q * z * minf(1.0, t / 0.08))
				st.draw_polyline(pts, c, maxf(1.0, 2.2 * z), true)
		"ribbon":   # (a flat band of her colour along the floor, thinning as it fades)
			var b := st.w2s(p["b"])
			c.a = 0.75 * (1.0 - t)
			st.draw_line(at, b, c, maxf(2.0, float(p["s"]) * z * (1.0 - 0.6 * t)), true)
			var hi := c.lightened(0.5)
			hi.a = c.a * 0.8
			st.draw_line(at, b, hi, maxf(1.0, 2.0 * z), true)


## Sparks, rings, shockwaves - over the fighters.
func draw_parts(st: StageView) -> void:
	var z := st.zoom
	for p: Dictionary in parts:
		if float(p["age"]) < 0.0:   # (not started yet - a delayed part)
			continue
		var t := float(p["age"]) / float(p["life"])
		var at := st.w2s(p["p"])
		var c: Color = p["c"]
		var s := float(p["s"]) * (band if p.has("scr") else z)   # (screen-sized parts: a share of the band)
		match str(p["k"]):
			"ink", "bubble", "floorring", "ribbon", "crack", "spikes", "bigstar", "puff", "mline":   # (behind the fighters - draw_back)
				pass
			"upetal", "opetal":   # (Umbra's petal in her colour: a pointed oval, spinning, fading - 23 Oct)
				var fade := 1.0 - maxf(0.0, (t - 0.55) / 0.45)
				c.a = fade
				var r := float(p["r"])
				var pts := PackedVector2Array()
				for k in 10:
					var a := TAU * k / 10.0
					var w := 0.42 * (1.0 - 0.55 * absf(cos(a)) * (1.0 if cos(a) > 0.0 else 0.0))   # (pointed at one end)
					pts.append(at + Vector2(cos(a) * s * 0.5, sin(a) * s * w).rotated(r))
				st.draw_colored_polygon(pts, c)
				var hi := c.lightened(0.45)
				hi.a = fade * 0.7
				st.draw_line(at - Vector2(s * 0.3, 0.0).rotated(r), at + Vector2(s * 0.3, 0.0).rotated(r), hi,
						maxf(1.0, s * 0.08), true)
			"dot":   # (YOMI's round particle in their colour, shrinking away)
				st.draw_circle(at, maxf(0.6, s * 0.5 * (1.0 - t)), c, true, -1.0, true)
			"wring":   # (a wide thin ring opening out round a big moment; x = how strong)
				var e := 1.0 - pow(1.0 - t, 2.0)
				c.a = float(p["x"]) * (1.0 - t)
				st.draw_arc(at, s * (0.6 + 0.4 * e), 0.0, TAU, 72, c, 1.0 + 2.5 * (1.0 - t), true)
			"sweep":   # (a giant fan sweeping open: from up behind her round to the way she faces (x = facing; 0 = up))
				var face := float(p["x"])
				var e := 1.0 - pow(1.0 - minf(1.0, t / 0.45), 3.0)
				if e < 0.02:   # (not open yet - nothing to draw, and no zero-size shapes)
					continue
				var a0 := -PI / 2.0 - 0.9 if face != 0.0 else -PI / 2.0 - 1.2   # (worked out facing right, then mirrored)
				var a1 := 0.25 if face != 0.0 else -PI / 2.0 + 1.2
				var mx := face if face != 0.0 else 1.0
				var reach := s * (0.85 + 0.15 * e)
				var ins := reach * 0.28
				var n := 14
				var fill := c
				fill.a = 0.32 * (1.0 - t)
				var rib := c.lightened(0.5)
				rib.a = 0.55 * (1.0 - t)
				var rimc := Color(1, 1, 1, 0.85 * (1.0 - t))
				var rim := PackedVector2Array()
				var dirs: Array[Vector2] = []
				for i in n + 1:
					var d := Vector2.from_angle(lerpf(a0, a0 + (a1 - a0) * e, float(i) / n))
					dirs.append(Vector2(d.x * mx, d.y))
				for i in n:
					var cc := fill if i % 2 == 0 else fill.lightened(0.15)
					st.draw_colored_polygon(PackedVector2Array([at + dirs[i] * reach, at + dirs[i + 1] * reach,
						at + dirs[i + 1] * ins, at + dirs[i] * ins]), cc)
					if i % 3 == 0:
						st.draw_line(at + dirs[i] * ins, at + dirs[i] * reach, rib, maxf(1.0, 2.0 * z), true)
				for i in n + 1:
					rim.append(at + dirs[i] * reach)
				st.draw_polyline(rim, rimc, maxf(2.0, 4.0 * z * (1.0 - t)), true)
			"slash":   # (a fan's cut across the hit: a thin crescent drawn out fast, white at its core; x = the way)
				var e := 1.0 - pow(1.0 - minf(1.0, t / 0.3), 2.0)
				var fade := 1.0 - maxf(0.0, (t - 0.35) / 0.65)
				if fade < 0.03:   # (gone - no zero-width shape)
					continue
				var way := 1.0 if float(p["x"]) >= 0.0 else -1.0
				var dir := Vector2.from_angle(-0.55 * absf(float(p["x"])) * way) * way
				var nrm := Vector2(-dir.y, dir.x)
				var half := s * (0.3 + 0.7 * e)
				for layer in 2:   # (the colour, then the white core)
					var w := s * (0.13 if layer == 0 else 0.05) * fade
					var top := PackedVector2Array()
					var bot := PackedVector2Array()
					for k in 11:
						var u := -1.0 + 2.0 * float(k) / 10.0
						var bend := 1.0 - u * u
						var mid := at + dir * half * u + nrm * s * 0.16 * bend
						top.append(mid + nrm * w * bend)
						bot.append(mid - nrm * w * bend)
					bot.reverse()
					bot = bot.slice(1, bot.size() - 1)   # (the tips are already in top - no repeated points)
					var cc := c if layer == 0 else Color(1, 1, 1, 1)
					cc.a = (0.95 if layer == 0 else 1.0) * fade
					st.draw_colored_polygon(top + bot, cc)
			"windring":   # (Gale's wind: twelve short arcs opening out round her, fading)
				var e := 1.0 - pow(1.0 - t, 2.0)
				c.a = 0.85 * (1.0 - t)
				var rad := s * (0.5 + 1.6 * e)
				for k in 12:
					var a0 := float(p["r"]) + TAU * k / 12.0
					st.draw_arc(at, rad, a0, a0 + 0.32, 6, c, maxf(1.5, 4.0 * z * (1.0 - t)), true)
			"tglint", "ember", "petal", "wisp":   # (a trail's bits - Style, 02:28)
				draw_trail(st, at, p, z)
			"star":   # (near full size the moment it lands - the freeze shows it - then it shrinks away)
				var grow := (0.75 + 0.25 * minf(1.0, t / 0.2)) * (1.0 - maxf(0.0, (t - 0.5) / 0.5))
				_star(st, at, s * grow, float(p["r"]), p["sp"], c)
				_star(st, at, s * grow * 0.55, float(p["r"]) + 0.3, p["sp"], HOT)
				st.draw_circle(at, s * grow * 0.22, Color.WHITE, true, -1.0, true)
			"ring":
				c.a = 1.0 - t * t
				st.draw_arc(at, s, 0.0, TAU, 14, c, maxf(1.5, 3.0 * z), true)
			"bloom", "cone":   # (step 3: spikes out of the hit - bloomed out solid in the first third, then hollowing:
				# their inner ends race out after the tips, thinning; a cone keeps to 40 degrees round the way it went)
				var sp: Array = p["sp"]
				var cone := str(p["k"]) == "cone"
				var grow := minf(1.0, t / 0.3)
				var hollow := maxf(0.0, (t - 0.25) / 0.75)
				c.a = 1.0 - hollow * hollow
				var n := 14 if cone else 22
				for k in n:
					var ang := float(p["r"]) + TAU * k / float(n)
					if cone:
						ang = Vector2(float(p["x"]), 0.0).angle() + lerpf(-0.7, 0.7, float(k) / float(n - 1))
					var dir := Vector2.from_angle(ang)
					var ln := s * float(sp[k]) * (0.45 + 0.55 * grow) * (1.0 + 0.35 * hollow)
					var inner := ln * hollow * 0.85
					var side := Vector2(-dir.y, dir.x) * maxf(0.8, s * (0.05 if cone else 0.07)) * (1.0 - 0.7 * hollow)
					var o := at + dir * (s * 0.35 * hollow if cone else 0.0)
					st.draw_colored_polygon(PackedVector2Array([o + dir * inner + side, o + dir * ln, o + dir * inner - side]),
							c)
			"pring":   # (step 3: a side-on shock wave - an upright ellipse, thick at first, thinning as it goes)
				var rx := s * (0.22 + 0.25 * t)
				var ry := s * (0.75 + 0.45 * t)
				c.a = 1.0 - t * t
				var pts := PackedVector2Array()
				for k in 33:
					var a := TAU * k / 32.0
					pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
				st.draw_polyline(pts, c, maxf(1.0, s * 0.16 * (1.0 - t)), true)
			"crescent":   # (step 3: an overhead's thin crescent sweeping down round the hit; x = the way they face)
				var face := float(p["x"])
				var e := 1.0 - pow(1.0 - t, 3.0)
				var mid := lerpf(-1.9, 0.5, e)   # (the arc's middle swinging from up over to the front-down)
				c.a = 1.0 - maxf(0.0, (t - 0.5) / 0.5)
				var pts := PackedVector2Array()
				for k in 13:
					var a := mid + lerpf(-0.55, 0.55, k / 12.0)
					pts.append(at + Vector2(cos(a) * face, sin(a)) * s)
				for k in 12:   # (thick in the middle, thin at both tips)
					var w := maxf(1.0, s * 0.11 * sin(PI * (k + 0.5) / 12.0) * (1.0 - 0.6 * t))
					st.draw_line(pts[k], pts[k + 1], c, w, true)
			"rring":   # (step 3: a big hit's thick rough ring - thinning, then breaking into pieces as it fades)
				var gaps: Array = p["gaps"]
				var rad := s * (0.7 + 0.45 * (1.0 - pow(1.0 - t, 2.0)))
				c.a = 1.0 - t * t
				var w := maxf(1.0, s * 0.2 * (1.0 - t))
				var gap := 0.15 + 1.2 * t   # (each break widening)
				var gs: Array = gaps.duplicate()
				gs.sort()
				for g in 3:
					var a0 := float(gs[g]) + gap / 2.0
					var a1 := float(gs[(g + 1) % 3]) - gap / 2.0
					if a1 < a0:
						a1 += TAU
					if a1 - a0 > 0.05:
						st.draw_arc(at, rad, a0, a1, 24, c, w, true)
			"box":
				c.a = 1.0 - t * t
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(at + Vector2.from_angle(float(p["r"]) + PI / 4.0 + k * PI / 2.0) * s * 1.3)
				st.draw_polyline(pts, c, maxf(1.5, 3.0 * z), true)
			"chip":
				c.a = 1.0 - t * t
				st.draw_rect(Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s)), c)
			"boom":   # (a fling's ring of air: a tall ellipse seen side on, opening out the way they're sent - thin, quick)
				var e := 1.0 - pow(1.0 - t, 3.0)
				c.a = 0.85 * (1.0 - t)
				var ry := s * (0.55 + 0.45 * e)
				var rx := ry * 0.26
				var mid := at + Vector2(float(p["x"]) * s * 0.5 * e, 0.0)
				var pts := PackedVector2Array()
				for n in 41:
					var a := TAU * n / 40.0
					pts.append(mid + Vector2(cos(a) * rx, sin(a) * ry))
				st.draw_polyline(pts, c, maxf(1.5, 6.0 * z * (1.0 - t)), true)
			"hwind":   # (Fan Gust's wind: a streak rushing out the way she faces, thinning)
				c.a = 0.85 * (1.0 - t)
				var back := Vector2(-signf((p["v"] as Vector2).x), 0.0)
				st.draw_line(at, at + back * s * (1.0 - 0.5 * t) + Vector2(0.0, sin(float(p["r"])) * 4.0 * z), c,
						maxf(1.5, 3.0 * z), true)
			"wind":   # (a streak of wind, rushing up and thinning)
				c.a = 0.85 * (1.0 - t)
				st.draw_line(at, at + Vector2(sin(float(p["r"])) * 5.0 * z, s * (1.0 - 0.5 * t)), c, maxf(1.5, 3.0 * z), true)
			"shock":
				var e := 1.0 - pow(1.0 - t, 3.0)
				c.a = 0.9 * (1.0 - t)
				st.draw_arc(at, s * (0.35 + 0.65 * e), 0.0, TAU, 40, c, maxf(1.0, 4.5 * z * (1.0 - t)), true)
			"guard":
				c.a = 1.0 - t
				var mid := 0.0 if float(p["x"]) > 0.0 else PI
				st.draw_arc(at, s * (1.0 + 0.3 * t), mid - 1.0, mid + 1.0, 16, c, maxf(1.5, 6.0 * z * (1.0 - t)), true)
			"glint":
				c.a = 1.0 - t
				var len := s * (0.6 + 0.4 * minf(1.0, t / 0.2))
				for k in 4:
					var dir := Vector2.from_angle(PI / 4.0 + k * PI / 2.0)
					var side := Vector2(-dir.y, dir.x) * maxf(1.5, 4.0 * z) * (1.0 - t)
					st.draw_colored_polygon(PackedVector2Array([at + side, at + dir * len, at - side]), c)
				st.draw_circle(at, maxf(2.0, 7.0 * z * (1.0 - t)), c, true, -1.0, true)
			"spokes":   # (impact lines: thin wedges round the hit, pointing in)
				c.a = 1.0 - t
				for k in 14:
					var u := float(k) / 14.0
					var dir := Vector2.from_angle(float(p["r"]) + u * TAU)
					var inner := s * (0.55 + 0.3 * t) * (0.8 + 0.4 * float(k % 3) / 2.0)
					var outer := inner + s * (0.9 + 0.5 * float((k * 7) % 5) / 4.0)
					var side := Vector2(-dir.y, dir.x) * maxf(1.0, 3.2 * z) * (1.0 - t)
					st.draw_colored_polygon(PackedVector2Array([at + dir * inner, at + dir * outer + side,
							at + dir * outer - side]), c)
			"rays":   # (a super's light rays: long wedges turning slowly, out of the one starting it)
				c.a = 0.75 * (1.0 - t * t)
				for k in 16:
					var dir := Vector2.from_angle(float(p["r"]) + t * 0.6 + float(k) / 16.0 * TAU)
					var reach := s * (0.6 + 0.4 * minf(1.0, t / 0.15)) * (0.7 + 0.6 * float((k * 5) % 7) / 6.0)
					var side := Vector2(-dir.y, dir.x) * s * 0.07
					st.draw_colored_polygon(PackedVector2Array([at + dir * s * 0.25, at + dir * reach + side,
							at + dir * reach - side]), c)
			"glow":   # (a soft light round them - stacked see-through discs)
				for k in 4:
					var g := c
					g.a = 0.12 * (1.0 - t)
					st.draw_circle(at, s * (0.5 + 0.17 * k) * (0.9 + 0.2 * t), g, true, -1.0, true)
			"flash":   # (a burst's white disc: full at once, then it opens out and thins away)
				var e := 1.0 - pow(1.0 - t, 2.0)
				c.a = 0.95 * (1.0 - t)
				st.draw_circle(at, s * (0.45 + 0.55 * e), c, true, -1.0, true)
			"shard":   # (a long triangle flying out, point first)
				c.a = 1.0 - t * t
				var dir := (p["v"] as Vector2).normalized() if (p["v"] as Vector2).length() > 1.0 else Vector2.RIGHT
				var side := Vector2(-dir.y, dir.x) * s * 0.28
				st.draw_colored_polygon(PackedVector2Array([at + dir * s, at - dir * s * 0.4 + side,
						at - dir * s * 0.4 - side]), c)


## A trail bit off someone moving (their Style's trail): world `at`.
func trail_bit(trail: String, at: Vector2, col: Color, seed_n: int) -> void:
	_rng.seed = seed_n
	trail_bit_into(parts, trail, at, col, _rng)


## Trails (02:28 "3"): small bits off a moving fighter - Glints (white-gold sparkles), Embers (rising sparks),
## Petals (drifting down), Wisps (short streaks in their colour).
static func trail_bit_into(list: Array, trail: String, at: Vector2, col: Color, rng: RandomNumberGenerator) -> void:
	var p := {"p": at + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-22.0, 12.0)), "age": 0.0,
		"r": rng.randf() * TAU, "w": 0.0, "x": rng.randf_range(-0.5, 0.5), "c": col, "v": Vector2.ZERO}
	match trail:
		"Glints":
			p.merge({"k": "tglint", "life": 0.45, "s": rng.randf_range(5.0, 8.0),
				"c": Color("#fff3c4") if rng.randf() < 0.5 else Color.WHITE,
				"v": Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-30.0, 0.0))}, true)
		"Embers":
			p.merge({"k": "ember", "life": 0.6, "s": rng.randf_range(3.0, 4.5), "c": Color("#ffb347"),
				"v": Vector2(rng.randf_range(-25.0, 25.0), -85.0)}, true)
		"Petals":
			p.merge({"k": "petal", "life": 0.9, "s": rng.randf_range(5.0, 7.0),
				"c": Color("#ffb3d1") if rng.randf() < 0.6 else Color("#ff8fbf"), "w": rng.randf_range(-5.0, 5.0)}, true)
		"Wisps":
			p.merge({"k": "wisp", "life": 0.35, "s": 16.0, "c": col.lightened(0.45)}, true)
		_:
			return
	list.append(p)


## A trail bit's drift: petals sway down, embers keep rising.
static func _bit_motion(p: Dictionary, v: Vector2, delta: float) -> Vector2:
	if p["k"] == "petal":
		return Vector2(sin(float(p["age"]) * 6.0 + float(p["r"])) * 35.0, 45.0)
	return Vector2(v.x * pow(0.3, delta), -85.0)


## (The Style preview's own bits.)
static func age_bits(list: Array, delta: float) -> void:
	for p: Dictionary in list:
		p["age"] = float(p["age"]) + delta
		var v: Vector2 = p["v"]
		if p["k"] in ["petal", "ember"]:
			v = _bit_motion(p, v, delta)
		else:
			v *= pow(0.02, delta)
		p["v"] = v
		p["p"] = (p["p"] as Vector2) + v * delta
		p["r"] = float(p["r"]) + float(p["w"]) * delta
	var keep := list.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	list.clear()
	list.append_array(keep)


## One trail bit, at a screen point, at zoom z.
static func draw_trail(ci: CanvasItem, at: Vector2, p: Dictionary, z: float) -> void:
	var t := float(p["age"]) / float(p["life"])
	var c: Color = p["c"]
	var s := float(p["s"]) * z
	match str(p["k"]):
		"tglint":
			c.a = 1.0 - t
			var l := s * (1.0 - 0.4 * t)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -l), at + Vector2(l * 0.25, 0), at + Vector2(0, l),
				at + Vector2(-l * 0.25, 0)]), c)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-l, 0), at + Vector2(0, -l * 0.25), at + Vector2(l, 0),
				at + Vector2(0, l * 0.25)]), c)
		"ember":
			c = c.lerp(Color("#ff3b1f"), t)
			c.a = 1.0 - t
			ci.draw_circle(at, maxf(0.8, s * (1.0 - 0.6 * t)), c, true, -1.0, true)
		"petal":
			c.a = 1.0 - t * t
			var pts := PackedVector2Array()
			for k in 8:
				var a := TAU * k / 8.0
				pts.append(at + Vector2(cos(a) * s, sin(a) * s * 0.55).rotated(float(p["r"])))
			ci.draw_colored_polygon(pts, c)
		"wisp":
			c.a = 0.8 * (1.0 - t)
			var dir := Vector2.from_angle(float(p["x"]))
			ci.draw_line(at - dir * s * 0.5, at + dir * s * 0.5, c, maxf(1.5, 2.5 * z), true)


## A super's cut-in (step 4): a dark slanted band across the screen, edged in their colour, speed lines running
## through it, them big in the move's pose sliding in, and the move's name - over everything, in screen space.
func draw_cutin(st: StageView) -> void:
	if cutin.is_empty():
		return
	var t := float(cutin["age"]) / float(cutin["life"])
	var vp := st.get_viewport_rect().size
	var col: Color = cutin["col"]
	var slide := 1.0 - pow(1.0 - minf(1.0, t / 0.16), 3.0)   # (in fast)
	var out := maxf(0.0, (t - 0.82) / 0.18)                  # (and out)
	var h := vp.y * 0.3
	var cy := vp.y * 0.44
	var tilt := h * 0.35
	var x0 := -vp.x * (1.0 - slide) + vp.x * out * 1.2
	var band := PackedVector2Array([Vector2(x0, cy - h / 2.0 + tilt * 0.5), Vector2(x0 + vp.x, cy - h / 2.0 - tilt * 0.5),
		Vector2(x0 + vp.x, cy + h / 2.0 - tilt * 0.5), Vector2(x0, cy + h / 2.0 + tilt * 0.5)])
	var fill := col.darkened(0.72)   # (her colour, deep - the band reads against the dark stage)
	fill.a = 0.95
	st.draw_colored_polygon(band, fill)
	var edge := col.lightened(0.25)
	st.draw_line(band[0], band[1], edge, 6.0, true)
	st.draw_line(band[3], band[2], edge, 6.0, true)
	var lines := col.lightened(0.5)
	for k in 9:   # (speed lines racing through the band)
		var yy := cy - h * 0.38 + h * 0.76 * float(k) / 8.0
		var run := fmod(float(k) * 173.0 + t * vp.x * 2.6, vp.x * 1.4) - vp.x * 0.2
		lines.a = 0.22
		st.draw_line(Vector2(x0 + run, yy), Vector2(x0 + run + vp.x * 0.25, yy - tilt * 0.12), lines, 3.0, true)
	var sc := h * 0.78 / 100.0   # (her whole figure inside the band)
	var face := float(cutin["face"])
	var origin := Vector2(x0 + vp.x * 0.28, cy + h * 0.36)
	var pose := Poses.get_pose(str(cutin["pose"]))
	Stick.fan_at(st, Stick._place(pose, origin, sc, face), "b", face, sc, 1.0, col)
	var pts := Stick.draw(st, pose, origin, sc, face, col, Stick.limb(sc), Stick.head(sc))
	Stick.fan_at(st, pts, "f", face, sc, 1.0, col)
	var title := str(cutin["title"])
	if title != "":
		if _bold == null:
			_bold = FontVariation.new()
			_bold.base_font = ThemeDB.fallback_font
			_bold.variation_embolden = 1.1
		var size := int(h * 0.3)
		var at := Vector2(x0 + vp.x * 0.5, cy + size * 0.35)
		st.draw_string_outline(_bold, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.02, 0.02, 0.03))
		st.draw_string(_bold, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col.lightened(0.6))


func _star(st: StageView, at: Vector2, s: float, rot: float, sp: Array, c: Color) -> void:
	if s < 1.0:
		return
	var pts := PackedVector2Array()
	for i in sp.size():
		pts.append(at + Vector2.from_angle(rot + TAU * float(i) / float(sp.size())) * s * float(sp[i]))
	st.draw_colored_polygon(pts, c)
