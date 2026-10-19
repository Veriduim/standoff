class_name Sfx
extends Node
## The game's sounds (19 Oct 00:38, list item 2 "Sound"): all made in code by tools/sfx_make.py (assets/sfx/<name>.wav;
## tools/sfx_board.py plays them numbered). A pool of players so they overlap; the same sound twice within GAP plays
## once (the fast speeds); quiet behind the home screen. On / off is saved, from the home screen and the ☰ menu.

const SETTINGS := "user://settings.cfg"
const VOICES := 12
const GAP := 0.045                ## seconds before the same sound plays again
const HEAVY := 30                 ## a hit this hard (after scaling) gets the big thump
const LEVEL := -2.5               ## every sound this much down (the first reel clipped when sounds piled up)
const NAMES := ["hit_light", "hit_heavy", "hit_counter", "slash", "edge", "block", "push", "parry", "clash", "grab",
	"fan_throw", "catch", "recall", "sweep", "gust", "blink", "down", "bounce", "wall", "ko", "burst", "super", "sad",
	"beat", "onbeat", "snap", "countered", "time", "swing", "land", "ui_click", "ui_turn", "ui_tick"]

static var main: Sfx              ## the one the game made (Ui.button's click reaches it)
static var on := true

var quiet := false                ## (the home screen's demo match plays silently)
var played: Array[String] = []    ## the last sounds played, newest last (the tests read it)
var _players: Array[AudioStreamPlayer] = []
var _streams := {}             ## name -> its variants (03:07 - a repeat doesn't sound stamped)
var _pick := {}                ## name -> the variant played last
var _last := {}
var _next := 0
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	main = self
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		on = bool(cfg.get_value("audio", "on", true))
	for n: String in NAMES:
		var all: Array = []
		for k in 4:   # (<name>.wav, <name>_2.wav, ...)
			var path := "res://assets/sfx/%s.wav" % (n if k == 0 else "%s_%d" % [n, k + 1])
			if ResourceLoader.exists(path):
				all.append(load(path))
		if not all.is_empty():
			_streams[n] = all
	if AudioServer.get_bus_effect_count(0) == 0:   # (a limiter on the master bus: piled-up hits never crackle)
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _exit_tree() -> void:   # (stopped, so nothing is left playing - headless, nothing ever finishes)
	for p in _players:
		p.stop()
		p.stream = null
	if main == self:
		main = null


func play(sound: String, db := 0.0, pitch := 1.0) -> void:
	if not on or quiet or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < GAP:
		return
	_last[sound] = now
	played.append(sound)
	if played.size() > 40:
		played.remove_at(0)
	if _headless:   # (the tests: noted, not played - the dummy audio never finishes a sound)
		return
	var all: Array = _streams[sound]
	var k := randi() % all.size()
	if all.size() > 1 and k == int(_pick.get(sound, -1)):   # (never the same one twice running)
		k = (k + 1) % all.size()
	_pick[sound] = k
	var p := _voice()
	p.stream = all[k]
	p.volume_db = db + LEVEL
	p.pitch_scale = pitch
	p.play()


## A free player, else the one used longest ago.
func _voice() -> AudioStreamPlayer:
	for k in VOICES:
		var p := _players[(_next + k) % VOICES]
		if not p.playing:
			_next = (_next + k + 1) % VOICES
			return p
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	return p


## A menu sound, from anywhere.
static func ui(sound: String, db := 0.0) -> void:
	if main != null:
		main.play(sound, db)


static func set_on(v: bool) -> void:
	on = v
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "on", v)
	cfg.save(SETTINGS)


static func icon() -> String:
	return "🔊" if on else "🔇"


static func label() -> String:
	return "Sound: on" if on else "Sound: off"


## One sim event as it's shown -> its sound.
func event(e: Dictionary, style := "") -> void:
	var vary := randf_range(0.94, 1.06)   # (the same hit twice doesn't sound stamped)
	match str(e["type"]):
		"hit", "armor":
			if bool(e.get("counter", false)) or bool(e.get("worse", false)):
				play("hit_counter")
				if style == "slash":
					play("slash", -2.0, vary)
			elif style == "slash":   # (her fans cut - 03:07)
				play("slash", 0.0, vary)
				if int(e.get("dmg", 0)) >= HEAVY:
					play("hit_light", -4.0, vary)
			elif int(e.get("dmg", 0)) >= HEAVY:
				play("hit_heavy", 0.0, vary)
			else:
				play("hit_light", 0.0, vary)
			if int(e.get("spot", 0)) == 1:   # (the fan's edge)
				play("edge", -3.0)
		"throw":
			play("grab")
		"block":
			play("push" if bool(e.get("push", false)) else "block", 0.0, vary)
		"parry":
			play("parry")
		"clash":
			play("clash")
		"tech":
			play("swing", 0.0, 0.8)
		"countered":
			play("countered")
		"shot":
			play("gust" if str(e.get("kind", "")) in ["ripple", "cyclone"] else "fan_throw", -2.0, vary)
		"galering":
			play("gust", 2.0)
		"catch":
			play("catch", -2.0)
		"ward":   # (a fan left hanging)
			play("catch", -5.0, 0.85)
		"reflect":
			play("parry")
			play("slash", -4.0, vary)
		"gustfwd":
			play("gust", 1.0, 0.9)
		"recall":
			play("recall")
		"sweep", "sweep_up":
			play("sweep")
		"gust":
			play("gust")
		"blink":
			play("blink")
		"down":
			play("down")
		"bounce":
			play("bounce")
		"wall", "splat":
			play("wall")
		"ko":
			play("ko")
		"burst":
			play("burst")
		"sad":
			play("sad", -6.0)
		"sadness":
			play("sad")
		"beat":
			play("beat")
		"onbeat":
			play("onbeat")
		"ic", "whiff":
			play("snap")
		"time":
			play("time")
