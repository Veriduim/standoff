extends TestSuite
## The fighting rules, without any screen.


## A two-fighter match set up at a distance, both free.
func _duel(a := "dancer", b := "dancer", gap := 60.0) -> Sim:
	var s := Sim.create([{"character": a}, {"character": b}])
	s.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	s.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	s.fighters[0].facing = 1
	s.fighters[1].facing = -1
	return s


## Play picks until both are free again; returns the segment's events.
func _play(s: Sim, picks: Dictionary) -> Array:
	s.apply(picks)
	var evs: Array = []
	for _i in 20:
		var seg := s.run_segment()
		evs.append_array(seg["events"])
		if s.over():
			break
		var free := s.deciders()
		if s.alive().all(func(f: Fighter) -> bool: return f.actionable()):
			break
		var hold := {}
		for id in free:
			hold[id] = {"move": "hold"}   # (free: a wait; mid-move: carry on; reeling: ride it out)
		s.apply(hold)
	return evs


func _types(evs: Array) -> Array:
	return evs.map(func(e: Dictionary) -> String: return str(e["type"]))


func _test_turns() -> void:
	_section("Turns: everyone free picks, it runs to the next pick")
	var s := Sim.create([{"character": "dancer"}, {"character": "dancer"}, {"character": "dancer"}])
	_check("three fighters, spread out and facing the middle", s.fighters.size() == 3
			and s.fighters[0].pos.x < s.fighters[1].pos.x and s.fighters[2].pos.x > s.fighters[1].pos.x
			and s.fighters[0].facing == 1 and s.fighters[2].facing == -1)
	_check("at the start everyone picks", s.deciders() == [0, 1, 2])
	s.apply({0: {"move": "wait"}, 1: {"move": "block"}, 2: {"move": "block"}})
	var seg := s.run_segment()
	_check("a 10-frame wait stops the run after 10 ticks; the two blocking may pick again or Hold - a Block gives way (%d ticks, %s)"
			% [seg["frames"].size(), s.deciders()], seg["frames"].size() == 10 and s.deciders() == [0, 1, 2]
			and s.legal_moves(1).has("hold") and s.legal_moves(1).has("jab") and not s.legal_moves(0).has("hold"))
	var fresh := Sim.create([{"character": "dancer"}, {"character": "dancer"}])
	_check("ground and air menus differ: a jump on the ground, an air kick only in the air",
			fresh.legal_moves(1).has("jump") and not fresh.legal_moves(1).has("airkick"))
	fresh.fighters[1].pos.y = -100.0
	_check("...in the air: the air kick, no jump", fresh.legal_moves(1).has("airkick")
			and not fresh.legal_moves(1).has("jump"))
	fresh.fighters[1].pos.y = 0.0
	_check("a super needs meter", not fresh.legal_moves(1).has("fanstorm"))
	fresh.fighters[1].meter = Sim.BAR
	_check("...and with a bar it's there", fresh.legal_moves(1).has("fanstorm") and not fresh.legal_moves(1).has("cyclone"))
	var busy := _duel()
	busy.fighters[0].burst = 0
	busy.apply({0: {"move": "sidekick"}, 1: {"move": "wait"}})
	busy.step()
	_check("someone mid-attack has nothing to pick (without 3/4 of a Burst gauge to Whiff Cancel)",
			busy.legal_moves(0).is_empty())


func _test_rules() -> void:
	_section("Who beats what")
	var s := _duel()
	var evs := _play(s, {0: {"move": "jab"}, 1: {"move": "wait", "x": 30}})
	_check("a jab hits someone standing still (%s)" % [_types(evs)], _types(evs).has("hit") and s.fighters[1].hp < 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "block"}})
	_check("a Block takes it - only chip damage (%s, hp %d)" % [_types(evs), s.fighters[1].hp],
			_types(evs).has("block") and s.fighters[1].hp == 449)
	s = _duel("dancer", "dancer", 50.0)
	evs = _play(s, {0: {"move": "grab"}, 1: {"move": "block"}})
	_check("a grab goes through a Block (%s)" % [_types(evs)], _types(evs).has("throw"))
	s = _duel("dancer", "dancer", 50.0)
	evs = _play(s, {0: {"move": "grab"}, 1: {"move": "jab"}})
	_check("a strike beats a grab (%s)" % [_types(evs)], _types(evs).has("hit") and not _types(evs).has("throw")
			and s.fighters[0].hp < 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "block", "pf": 3}})
	_check("a Block set to the frame the jab lands on (3) parries it - no damage (%s)" % [_types(evs)],
			_types(evs).has("parry") and s.fighters[1].hp == 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "block", "pf": 5}})
	_check("...a frame off is just a block (%s)" % [_types(evs)], _types(evs).has("block") and not _types(evs).has("parry"))
	s = _duel("dancer", "dancer", 80.0)
	evs = _play(s, {0: {"move": "straight"}, 1: {"move": "block", "pf": 7}})
	_check("...and a straight landing on frame 7 is parried on 7 (%s)" % [_types(evs)], _types(evs).has("parry"))
	s = _duel("dancer", "dancer", 70.0)
	evs = _play(s, {0: {"move": "lowkick"}, 1: {"move": "block", "y": -1.0}})
	var worse := evs.filter(func(e: Dictionary) -> bool: return e["type"] == "block" and e.get("worse", false))
	_check("a low kick blocked high is blocked worse - double chip (hp %d)" % s.fighters[1].hp, not worse.is_empty()
			and s.fighters[1].hp == 448)
	s = _duel("dancer", "dancer", 70.0)
	evs = _play(s, {0: {"move": "lowkick"}, 1: {"move": "block", "y": 1.0}})
	_check("...blocked low it's clean (hp %d)" % s.fighters[1].hp, _types(evs).has("block") and s.fighters[1].hp == 449)
	s = _duel("dancer", "dancer", 80.0)
	var x0 := s.fighters[0].pos.x
	evs = _play(s, {0: {"move": "straight"}, 1: {"move": "pushblock"}})
	_check("a Push Block: no chip, and the striker's shoved back (hp %d, x %.0f -> %.0f)" % [s.fighters[1].hp, x0,
			s.fighters[0].pos.x], _types(evs).has("block") and s.fighters[1].hp == 450 and s.fighters[0].pos.x < x0 - 20.0)
	s = _duel("dancer", "dancer", 90.0)   # (the rule stays - the zoner has no guard break of her own since 03:32)
	s.apply({0: {"move": "wait"}, 1: {"move": "block"}})
	s.step()
	var bm := Moves.move("dancer", "block")
	var plain := {"dmg": 30, "stun": 10, "kb": [1.0, 0.0], "block": 8, "chip": 1}
	var held := s._block(s.fighters[0], s.fighters[1], plain, bm, 4, false)
	var in_stun := s.fighters[1].blockstun > 0
	plain["guardbreak"] = true
	var still := s._block(s.fighters[0], s.fighters[1], plain, bm, 4, false)   # (already in blockstun from the first)
	s.fighters[1].blockstun = 0
	var broke := not s._block(s.fighters[0], s.fighters[1], plain, bm, 4, false)
	s.fighters[1].blockstun = 0
	s.fighters[1].parry_at = 4
	s.events.clear()
	var parried := s._block(s.fighters[0], s.fighters[1], plain, bm, 4, false) and _types(s.events).has("parry")
	_check("a Guard Break goes straight through a Block - but not someone already in blockstun, and it can be parried "
			+ "on its frame (the wiki's Basics) (plain %s, in blockstun %s, through %s, parried %s)" % [held, still, broke,
			parried], held and in_stun and still and broke and parried)
	s = _duel("dancer", "dancer", 80.0)
	evs = _play(s, {0: {"move": "roll", "x": 1.0}, 1: {"move": "jab"}})
	_check("a roll's invulnerable frames let the jab pass through (%s, hp %d)" % [_types(evs), s.fighters[0].hp],
			not _types(evs).has("hit") and s.fighters[0].hp == 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "jab"}})
	_check("two jabs meeting clash (%s)" % [_types(evs)], _types(evs).has("clash") and s.fighters[0].hp == 450)


func _test_directions_and_kit() -> void:
	_section("A direction is the only pick; the Dancer's full kit")
	_check("Sim.aim fits a direction to the move: facing -> left or right, up / down halves, dir8 as is, none = nothing",
			Sim.aim("facing", Vector2(-1, -1), 1) == Vector2(-1, 0) and Sim.aim("facing", Vector2(0, -1), -1) == Vector2(-1, 0)
			and Sim.aim("up", Vector2(1, 1), 1).y < 0.0 and Sim.aim("down", Vector2(0, -1), 1).y > 0.0
			and Sim.aim("dir8", Vector2(0, 1), 1) == Vector2(0, 1) and Sim.aim("none", Vector2(1, 0), 1) == Vector2.ZERO)
	var s := _duel("dancer", "dancer", 200.0)
	s.apply({0: {"move": "dash", "x": -1.0}, 1: {"move": "wait"}})
	s.run_segment()
	_check("picking ← turns you round and dashes that way (x %.0f, facing %d)" % [s.fighters[0].pos.x, s.fighters[0].facing],
			s.fighters[0].pos.x < -150.0 and s.fighters[0].facing == -1)
	var t := _duel("dancer", "dancer", 300.0)
	t.apply({0: {"move": "taunt"}, 1: {"move": "block"}})
	_play(t, {})
	_check("a taunt gives a bar of meter when it finishes (%d)" % t.fighters[0].meter, t.fighters[0].meter >= Sim.BAR - 10)
	var kit := Moves.of("dancer")
	var tabs := {}
	for mid: String in kit:
		tabs[str(kit[mid].get("tab", "?"))] = int(tabs.get(str(kit[mid].get("tab", "?")), 0)) + 1
	_check("the Dancer has a full kit (%d moves: %s), every move in a tab and with an aim" % [kit.size(), tabs],
			kit.size() >= 28 and not tabs.has("?") and kit.values().all(func(m: Dictionary) -> bool: return m.has("aim")))


func _test_combos_and_ko() -> void:
	_section("Combos, knockouts and the winner")
	var s := _duel()
	s.fighters[1].burst = 0   # (their Burst used up)
	s.apply({0: {"move": "jab"}, 1: {"move": "wait", "x": 40}})
	s.run_segment()
	var first := 450 - s.fighters[1].hp
	_check("a landed jab frees the hitter at once (a hit cancel) while the other reels and only gets to lean (free: %s, %s)"
			% [s.deciders(), s.legal_moves(1)], s.deciders() == [0, 1] and s.fighters[0].actionable()
			and s.legal_moves(1) == ["hold"] and not s.legal_moves(0).has("jab"))
	s.fighters[1].hp = 10
	s.fighters[0].pos.x = s.fighters[1].pos.x - 70.0
	_play(s, {0: {"move": "straight"}})
	_check("damage scales down in a combo, and a fighter at 0 is out (first %d)" % first,
			first == 18 and s.fighters[1].ko and s.over() and s.winners() == [0])
	var t := Sim.create([{"character": "dancer", "team": 0}, {"character": "dancer", "team": 0},
			{"character": "dancer", "team": 1}], "teams")
	t.fighters[0].pos = Vector2(-40, 0)
	t.fighters[1].pos = Vector2(40, 0)
	t.fighters[0].facing = 1
	t.apply({0: {"move": "jab", "target": 1}, 1: {"move": "wait", "x": 30}, 2: {"move": "wait", "x": 30}})
	t.run_segment()
	_check("teams: no hitting your own side", t.fighters[1].hp == t.fighters[1].max_hp)
	t.fighters[2].ko = true
	_check("teams: one side left = it's over, both of them win", t.over() and t.winners() == [0, 1])


## The YOMI wiki's rules for combos (Combo Mechanics / Blocking pages - Timmy 18:42 / 18:44: "Use that page more").
func _test_escaping_combos() -> void:
	_section("Combos and getting out of them: Burst, leaning, hit cancels, giving way, scaling, counters, walls")
	var s := _duel()
	_check("everyone starts with one Burst (a full gauge)", s.fighters.all(func(f: Fighter) -> bool: return f.burst == Sim.BURST_FULL))
	for f in s.fighters:
		f.burst = 0
	_play(s, {0: {"move": "jab"}, 1: {"move": "wait"}})
	_check("...and fills with time, faster while reeling in a combo (%d / %d)" % [s.fighters[1].burst, s.fighters[0].burst],
			s.fighters[1].burst > s.fighters[0].burst and s.fighters[0].burst > 0)
	s = _duel()
	s.fighters[1].burst = Sim.BURST_FULL
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("reeling with a full gauge: Burst or Hold (%s)" % [s.legal_moves(1)], s.legal_moves(1) == ["burst", "hold"])
	var hp := s.fighters[0].hp
	var evs := _play(s, {0: {"move": "straight"}, 1: {"move": "burst"}})
	var on_burster := evs.filter(func(e: Dictionary) -> bool: return e["type"] == "hit" and int(e["d"]) == 1)
	_check("a Burst ends their stun, spends the gauge, does no damage, can't be hit and blows the attacker away (%s, x %.0f)"
			% [_types(evs), s.fighters[0].pos.x], _types(evs).has("burst") and s.fighters[1].burst < Sim.BURST_FULL
			and s.fighters[0].hp == hp and s.fighters[0].pos.x < -150.0 and on_burster.is_empty())
	s = _duel()
	s.fighters[1].burst = Sim.BURST_FULL
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	evs = _play(s, {0: {"move": "block"}, 1: {"move": "burst"}})
	_check("guarding blocks a Burst - safe, a short push (%s)" % [_types(evs)], _types(evs).has("block")
			and not _types(evs).has("parry") and s.fighters[0].pos.x > -200.0)
	s = _duel()
	s.fighters[1].burst = Sim.BURST_FULL
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	evs = _play(s, {0: {"move": "block", "pf": 2}, 1: {"move": "burst"}})
	_check("...and a Parry on its frame parries it: the burster is left stuck (%s)" % [_types(evs)],
			_types(evs).has("parry"))
	var leans := []
	for lean: float in [0.0, -1.0]:
		var d := _duel()
		d.apply({0: {"move": "sidekick"}, 1: {"move": "wait"}})
		d.run_segment()
		d.apply({1: {"move": "hold", "x": lean}})
		d.fighters[1].vel = Vector2.ZERO
		d.fighters[0].pos.x = d.fighters[1].pos.x - 70.0
		d.apply({0: {"move": "straight"}})
		d.run_segment()   # (it stops on the hit - a hit cancel)
		leans.append(d.fighters[1].vel.x)
	_check("leaning while reeling bends the knockback (no lean %.1f, leaning back %.1f)" % [leans[0], leans[1]],
			absf(float(leans[0]) - float(leans[1])) > 1.0)
	s = _duel()
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	var first_stun := s.fighters[1].stun
	for mv: String in ["straight", "jab"]:
		s.fighters[1].vel = Vector2.ZERO
		s.fighters[0].pos.x = s.fighters[1].pos.x - 60.0
		s.apply({0: {"move": mv}})
		s.run_segment()
	_check("a combo goes on, but the same move used again in it stuns for less (jab %d, then again %d)"
			% [first_stun, s.fighters[1].stun], s.fighters[1].combo == 3 and s.fighters[1].stun < first_stun - 2)
	s = _duel("dancer", "dancer", 50.0)
	s.apply({0: {"move": "windmill", "x": 1.0}, 1: {"move": "wait"}})
	var landed := false
	for _i in 30:   # (to the tick it lands)
		s.step()
		if _types(s.events).has("hit"):
			landed = true
			break
	_check("...not every move frees you on a hit: Windmill doesn't (still in it as its first hit lands)",
			landed and s.fighters[0].move == "windmill")
	s = _duel()
	s.apply({0: {"move": "jab"}, 1: {"move": "sidekick"}})
	evs = _play(s, {})
	var counter := evs.filter(func(e: Dictionary) -> bool: return e["type"] == "hit" and e.get("counter", false))
	var spot_k := {1: Sim.EDGE_DMG, -1: Sim.CLOSE_DMG, 0: 1.0}   # (where it landed - the spacer's edge / point blank)
	_check("hitting someone mid-attack is a counter hit for 10%% more (%s)" % [counter],
			not counter.is_empty() and int(counter[0]["dmg"]) == int(round(round(18.0 * float(spot_k[int(counter[0].get(
				"spot", 0))])) * 1.1)))
	s = _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "dash", "x": 1.0}, 1: {"move": "wait"}})
	s.run_segment()
	_check("a dash gives way when the other can act: pick again or Hold (%s)" % [s.deciders()],
			s.deciders().has(0) and s.legal_moves(0).has("hold"))
	s = _duel()
	s.fighters[1].pos.x = s.half - 60.0
	s.fighters[0].pos.x = s.half - 120.0
	s.fighters[1].pos.y = -60.0
	s.fighters[1].stun = 30
	s.fighters[1].vel = Vector2(14.0, -2.0)
	var walls := false
	for _i in 20:
		s.step()
		walls = walls or s.events.any(func(e: Dictionary) -> bool: return e["type"] == "wall")
	_check("launched into the wall, they bounce off it", walls and s.fighters[1].vel.x <= 0.0)


## The wiki's next list (0.5.0 - Timmy 19:10 "Continue on with the other features. Same as before wiki for mechanics").
func _test_wiki_more() -> void:
	_section("Free / Whiff Cancels, knockdowns, bars of meter, the round, Sadness, air options, distance")
	var s := _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "sidekick", "free": true}, 1: {"move": "wait"}})
	var seg := s.run_segment()
	_check("a Free Cancelled attack gives way when the other can act - a charge spent (%d ticks, FC %d, %s)"
			% [seg["frames"].size(), s.fighters[0].fc, s.legal_moves(0).slice(0, 3)],
			seg["frames"].size() == 10 and s.fighters[0].fc == Sim.FC_MAX - 1 and s.legal_moves(0).has("hold")
			and s.legal_moves(0).has("jab"))
	s.fighters[0].fc = 0
	s.fighters[0].meter = Sim.BAR + 10
	s.apply({0: {"move": "jab", "free": true}, 1: {"move": "wait"}})
	_check("...out of charges it costs a bar", s.fighters[0].freed and s.fighters[0].meter == 10)
	s = _duel()
	s.fighters[0].fc = 0
	s.fighters[1].fc = 0
	_play(s, {0: {"move": "jab"}, 1: {"move": "wait"}})
	_check("...and a melee hit gives both of them their charges back", s.fighters[0].fc == Sim.FC_MAX
			and s.fighters[1].fc == Sim.FC_MAX)
	s = _duel("dancer", "dancer", 200.0)
	s.apply({0: {"move": "axekick"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("stuck in a committed move when someone close can act, with 3/4 of a Burst: Whiff Cancel or Hold (%s)"
			% [s.legal_moves(0)], s.deciders().has(0) and s.legal_moves(0) == ["whiff", "hold"])
	s.apply({0: {"move": "whiff"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("...it cuts the move, costs 3/4 of the gauge, and that pick is attacks only (%s)" % [s.legal_moves(0).slice(0, 4)],
			s.fighters[0].actionable() and s.fighters[0].burst < Sim.WHIFF_COST and s.legal_moves(0).has("jab")
			and not s.legal_moves(0).has("dash") and not s.legal_moves(0).has("block"))
	s = _duel("dancer", "dancer", 70.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "sweep"}, 1: {"move": "wait"}})
	var evs: Array = s.run_segment()["events"]
	for _i in 6:
		if s.fighters[1].down > 0:
			break
		s.apply({0: {"move": "wait"}, 1: {"move": "hold"}})
		evs.append_array(s.run_segment()["events"])
	_check("a sweep floors them when they land: lying down, untouchable, picking how to get up (%s, %s)"
			% [_types(evs), s.legal_moves(1)], _types(evs).has("down") and s.fighters[1].down > 0
			and s.invulnerable(s.fighters[1]) and s.legal_moves(1) == ["getup", "techroll", "hold"])
	s.apply({1: {"move": "hold"}})
	for _i in Sim.DOWN_TICKS + 2:
		s.step()
	_check("...staying down, they get up by themselves after a moment", s.fighters[1].down == 0
			and s.fighters[1].move == "getup")
	s = _duel("dancer", "dancer", 70.0)
	var m0 := s.fighters[0].meter
	s.apply({0: {"move": "walk", "x": 1.0}, 1: {"move": "wait"}})
	s.step()
	s.step()
	_check("meter: moving in on someone gives some every tick (%d -> %d)" % [m0, s.fighters[0].meter],
			s.fighters[0].meter > m0)
	s = _duel()
	_play(s, {0: {"move": "straight"}, 1: {"move": "wait"}})
	_check("...landing a hit gives the hitter more than the one hit (%d / %d)" % [s.fighters[0].meter, s.fighters[1].meter],
			s.fighters[0].meter > s.fighters[1].meter and s.fighters[1].meter > 0)
	s = _duel("dancer", "dancer", 400.0)
	s.fighters[1].hp = 300
	s.tick = Sim.ROUND_TICKS - 5
	_play(s, {0: {"move": "wait"}, 1: {"move": "wait"}})
	_check("the round runs out at %d ticks: the best share of HP left wins (%s)" % [Sim.ROUND_TICKS, s.winners()],
			s.over() and s.timed_out() and s.winners() == [0])
	s = _duel("dancer", "dancer", 400.0)
	s.fighters[0].sad = Sim.SAD_MAX - 30
	s.fighters[0].meter = 200
	evs = []
	for _i in 15:
		s.apply({0: {"move": "dash", "x": -1.0}, 1: {"move": "wait"}})
		evs.append_array(s.run_segment()["events"])
		if _types(evs).has("sadness"):
			break
	_check("Sadness: hanging back too long - SADNESS!: meter gone, no guard or parry (%s)" % [_types(evs)],
			_types(evs).has("sadness") and s.fighters[0].sadness > 0 and s.fighters[0].meter == 0
			and not s.legal_moves(0).has("block") and not s.legal_moves(0).has("pushblock"))
	s = _duel("dancer", "dancer", 400.0)
	s.fighters[0].pos.y = -150.0
	_check("two air options: an air jump and an air dash, then no more until they land",
			s.legal_moves(0).has("airjump") and s.legal_moves(0).has("airdash"))
	s.fighters[0].air_moves = Sim.AIR_OPTIONS
	_check("...used up: neither", not s.legal_moves(0).has("airjump") and not s.legal_moves(0).has("airdash"))
	var far := []
	for dist: float in [15.0, 100.0]:
		var d := _duel("dancer", "dancer", 600.0)
		d.apply({0: {"move": "dash", "x": 1.0, "dist": dist}, 1: {"move": "wait"}})
		for _i in 40:
			d.step()
		far.append(d.fighters[0].pos.x - (-300.0))
	_check("a dash goes as far as its distance says (15: %.0f px, 100: %.0f px)" % [far[0], far[1]],
			float(far[0]) > 10.0 and float(far[1]) > float(far[0]) * 2.0)


## Step 2 of "as like for like as we can" (Timmy 19:46 / 19:48): the wiki's combo depth.
func _test_combo_depth() -> void:
	_section("Combo depth: proration, OTG, ground bounce, wall splat, Instant and Burst Cancels")
	var second := []
	for starter: String in ["jab", "sweep"]:   # (a jab starter scales the rest more than a sweep starter)
		var s := _duel("dancer", "dancer", 70.0)
		s.fighters[1].burst = 0
		s.apply({0: {"move": starter}, 1: {"move": "wait"}})
		s.run_segment()
		var hp := s.fighters[1].hp
		s.fighters[1].vel = Vector2.ZERO
		s.fighters[0].pos.x = s.fighters[1].pos.x - 70.0
		s.apply({0: {"move": "straight"}, 1: {"move": "hold"}})
		s.run_segment()
		second.append(hp - s.fighters[1].hp)
	_check("proration: a straight after a jab starter does less than after a sweep starter (%d / %d)" % second,
			int(second[0]) < int(second[1]))
	var s := _duel("dancer", "dancer", 70.0)
	s.fighters[1].burst = 0
	s.fighters[1].down = 15
	s.apply({0: {"move": "stomp"}})
	var evs: Array = s.run_segment()["events"]
	_check("a Stomp hits someone lying down (OTG) and picks them up into the combo (%s)" % [_types(evs)],
			_types(evs).has("hit") and s.fighters[1].down == 0 and s.fighters[1].stun > 0)
	s = _duel("dancer", "dancer", 80.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "axekick"}, 1: {"move": "wait"}})
	evs = []
	for _i in 4:
		evs.append_array(s.run_segment()["events"])
		if _types(evs).has("bounce"):
			break
		s.apply({1: {"move": "hold"}})
	_check("the axe kick bounces them off the ground (once a combo) (%s)" % [_types(evs)],
			_types(evs).has("bounce") and s.fighters[1].bounced and s.fighters[1].vel.y < 0.0)
	s = _duel("dancer", "dancer", 70.0)
	s.fighters[0].pos.x = s.half - 110.0
	s.fighters[1].pos.x = s.half - 40.0
	s.fighters[1].burst = 0
	s.apply({0: {"move": "sidekick"}, 1: {"move": "wait"}})
	evs = []
	for _i in 4:
		evs.append_array(s.run_segment()["events"])
		if _types(evs).has("splat"):
			break
		s.apply({1: {"move": "hold"}})
	_check("a side kick into the wall splats them there (%s)" % [_types(evs)], _types(evs).has("splat"))
	s = _duel()
	s.fighters[1].burst = 0
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("an Instant Cancel: the move just landed is there again only with a bar", not s.legal_moves(0).has("jab"))
	s.fighters[0].meter = Sim.BAR
	_check("...with a bar it is", s.legal_moves(0).has("jab"))
	s.apply({0: {"move": "jab"}, 1: {"move": "hold"}})
	_check("...and it costs the bar", s.fighters[0].meter == 0 and s.fighters[0].move == "jab")
	s = _duel()
	s.fighters[1].burst = 0
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("with a full Burst gauge mid-combo the attacker may Burst Cancel", s.legal_moves(0).has("burstcancel"))
	s.apply({0: {"move": "burstcancel"}, 1: {"move": "hold"}})
	s.run_segment()
	_check("...it spends the gauge and leaves them well ahead (+%d)" % (s.fighters[1].busy() - s.fighters[0].busy()),
			s.fighters[0].burst < Sim.BURST_FULL and s.fighters[1].busy() - s.fighters[0].busy() > 10)


## Step 3 - cooler moves (Timmy 20:05 "continue on please").
func _test_cooler_moves() -> void:
	_section("Cooler moves: fans and ripples, the Sway, a chain, Mirror, air throws, initiative, a third super")
	var s := _duel("dancer", "dancer", 300.0)
	s.fighters[1].burst = 0
	var evs := _play(s, {0: {"move": "fan"}, 1: {"move": "wait"}})
	_check("a Fan Throw flies across and hits from range (%s, hp %d)" % [_types(evs), s.fighters[1].hp],
			_types(evs).has("shot") and _types(evs).has("hit") and s.fighters[1].hp < 450)
	for kind: Array in [["fan", -1.0, "parry"], ["ripple", 1.0, "block"]]:
		s = _duel("dancer", "dancer", 300.0)
		s.apply({0: {"move": str(kind[0])}, 1: {"move": "wait"}})
		for _i in 90:   # (to just before it lands)
			s.step()
			if not s.shots.is_empty() and s.hurtbox(s.fighters[1]).position.x - float((s.shots[0]["pos"] as Vector2).x) < 30.0:
				break
		s.events.clear()
		s.apply({1: {"move": "block", "y": float(kind[1])}})
		for _i in 10:
			s.step()
		_check("a %s met by a Block just started: %s (%s)" % [kind[0], kind[2], _types(s.events)],
				_types(s.events).has(str(kind[2])) and (str(kind[2]) == "parry" or not _types(s.events).has("parry")))
	s = _duel("dancer", "dancer", 70.0)
	s.fighters[1].burst = 0
	_check("Fan Flick only right after landing a Fan Slash", not s.legal_moves(0).has("fanflick"))
	s.apply({0: {"move": "fanslash"}, 1: {"move": "wait"}})
	s.run_segment()
	var gap0 := s.fighters[1].pos.x - s.fighters[0].pos.x
	_check("...landed: Fan Flick is there (gap %.0f)" % gap0, s.legal_moves(0).has("fanflick"))
	s.events.clear()
	s.apply({0: {"move": "fanflick"}, 1: {"move": "hold"}})
	var flicked := Sim.FANS_MAX
	for _i in 14:
		s.step()
		flicked = mini(flicked, s.fighters[0].fans)
	_check("...the flick: the fan leaves her hand, hits and knocks them back out to her range (gap %.0f -> %.0f, %s)"
			% [gap0, s.fighters[1].pos.x - s.fighters[0].pos.x, _types(s.events)], _types(s.events).has("hit")
			and s.fighters[1].pos.x - s.fighters[0].pos.x > gap0 + 40.0 and flicked == 1)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "mirror"}})
	_check("Mirror catches a jab in its window and strikes back (%s, the jabber's hp %d)" % [_types(evs),
			s.fighters[0].hp], _types(evs).has("countered") and s.fighters[0].hp < 450 and s.fighters[1].hp == 450)
	s = _duel("dancer", "dancer", 40.0)
	s.fighters[0].pos.y = -120.0
	s.fighters[1].pos.y = -120.0
	s.fighters[0].vel.y = -4.0
	s.fighters[1].vel.y = -4.0
	s.apply({0: {"move": "airthrow"}, 1: {"move": "wait"}})
	evs = []
	for _i in 12:
		s.step()
	_check("an Air Throw takes them out of the air (%s)" % [_types(s.events)], _types(s.events).has("throw"))
	s = _duel("dancer", "dancer", 50.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "uppercut"}, 1: {"move": "wait"}})
	for _i in 6:
		s.run_segment()
		if s.fighters[0].actionable():
			break
		s.apply({1: {"move": "hold"}})
	_check("Uppercut launches and cancels only into jumps (%s)" % [s.legal_moves(0)], s.fighters[1].stun > 0
			and s.legal_moves(0).has("superjump") and not s.legal_moves(0).has("jab"))
	s = _duel()
	evs = _play(s, {0: {"move": "uppercut"}, 1: {"move": "jab"}})
	_check("initiative: an uppercut picked while they pick too goes through their jab (%s, hp %d / %d)" % [_types(evs),
			s.fighters[0].hp, s.fighters[1].hp], s.fighters[0].hp == 450 and s.fighters[1].hp < 450)
	s = _duel()
	s.fighters[0].meter = Sim.METER_MAX
	_check("Grand Finale, the third super, takes all 3 bars", s.legal_moves(0).has("finale"))


func _test_fan_dancer() -> void:
	_section("The fan dancer (Timmy 21:59, Jade-flavoured): Updraft lifts them, Silk Glide slides through projectiles, fans aimed")
	var s := _duel("dancer", "dancer", 90.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "updraft", "x": 1.0}, 1: {"move": "wait"}})
	var up := false
	for _i in 30:
		s.step()
		if s.fighters[1].pos.y < -40.0 and s.fighters[1].stun > 0:
			up = true
	_check("Updraft: a gust off both fans lifts them into the air, reeling", up)
	s = _duel("dancer", "dancer", 360.0)
	s.fighters[0].burst = 0
	s.apply({1: {"move": "fan", "x": -1.0}, 0: {"move": "wait"}})
	for _i in 9:   # (their fan's out, coming at her)
		s.step()
	var hp0 := s.fighters[0].hp
	s.apply({0: {"move": "glide", "x": 1.0}})
	var through := false
	for _i in 24:
		s.step()
		if s.shots.is_empty() or float((s.shots[0]["pos"] as Vector2).x) < s.fighters[0].pos.x - 30.0:
			through = true
	_check("Silk Glide: their fan passes by her (hp %d -> %d)" % [hp0, s.fighters[0].hp], through and s.fighters[0].hp == hp0)
	s = _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "fan", "x": 1.0, "y": -1.0}, 1: {"move": "wait"}})
	for _i in 10:
		s.step()
	_check("Fan Throw takes any direction - thrown up and out it climbs", not s.shots.is_empty()
			and float((s.shots[0]["vel"] as Vector2).y) < -1.0 and float((s.shots[0]["vel"] as Vector2).x) > 1.0)


func _test_movement() -> void:
	_section("Better movement (Timmy 23:23): momentum into attacks, how far you lunge, each style's movement tool")
	var still := _duel("dancer", "dancer", 600.0)
	still.apply({0: {"move": "jab", "x": 1.0}, 1: {"move": "wait"}})
	var moving := _duel("dancer", "dancer", 600.0)
	moving.fighters[0].vel.x = 16.0   # (coming out of a dash)
	moving.apply({0: {"move": "jab", "x": 1.0}, 1: {"move": "wait"}})
	for _i in 12:
		still.step()
		moving.step()
	var d0 := still.fighters[0].pos.x + 300.0
	var d1 := moving.fighters[0].pos.x + 300.0
	_check("an attack started on the move keeps the momentum (jab from still %.0f px, from a dash %.0f px)" % [d0, d1],
			d1 > d0 + 40.0)
	var near := _duel("dancer", "dancer", 600.0)
	near.apply({0: {"move": "straight", "x": 1.0, "dist": 0.0}, 1: {"move": "wait"}})
	var far := _duel("dancer", "dancer", 600.0)
	far.apply({0: {"move": "straight", "x": 1.0, "dist": 100.0}, 1: {"move": "wait"}})
	for _i in 16:
		near.step()
		far.step()
	_check("lunging attacks take a Distance: a Straight at 0 stays put (%.0f), at 100 lunges (%.0f)"
			% [near.fighters[0].pos.x + 300.0, far.fighters[0].pos.x + 300.0],
			absf(near.fighters[0].pos.x + 300.0) < 6.0 and far.fighters[0].pos.x + 300.0 > 30.0
			and Moves.move("dancer", "straight").has("dist"))
	var s := _xf("fans", 700.0)
	s.apply({0: {"move": "fan", "x": 1.0}, 1: {"move": "wait"}})
	_steps(s, 30, func() -> bool: return s.fighters[0].actionable())
	var can := s.legal_moves(0).has("fanstep")
	var from := s.fighters[0].pos.x
	s.apply({0: {"move": "fanstep"}})
	var fan_x := 0.0
	for _i in 8:
		if not s.shots.is_empty():
			fan_x = float((s.shots[0]["pos"] as Vector2).x) + float((s.shots[0]["vel"] as Vector2).x)   # (where it'll be)
		s.step()
	_check("Fans: Fan Step blinks her to her thrown fan and she catches it (from %.0f to %.0f, the fan at %.0f, fans %d)"
			% [from, s.fighters[0].pos.x, fan_x, s.fighters[0].fans], can and absf(s.fighters[0].pos.x - fan_x) < 30.0
			and s.fighters[0].pos.x - from > 100.0 and s.fighters[0].fans == 2 and s.shots.is_empty())
	s = _xf("fans,tempo", 600.0)
	_check("Snap Step's gone from her kit (05:03 - a rushdown's step; the Bruiser has Bob & Weave)",
			not s.legal_moves(0).has("snapstep") and Moves.move("dancer", "snapstep").is_empty())
	var slow := _xf("tempo", 900.0)
	var fast := _xf("tempo", 900.0)
	fast.fighters[0].tempo = 4
	for t: Sim in [slow, fast]:
		t.apply({0: {"move": "dash", "x": 1.0}, 1: {"move": "wait"}})
		for _i in 14:
			t.step()
	_check("Tempo: on the beat she moves faster (a dash: %.0f px, at four beats %.0f px)"
			% [slow.fighters[0].pos.x + 450.0, fast.fighters[0].pos.x + 450.0],
			fast.fighters[0].pos.x > slow.fighters[0].pos.x + 15.0)


func _test_wiki_mechanics_2() -> void:
	_section("More of the wiki (23:34): Air Fan is an air option, the Ceiling, Land Cancel, Low Profile")
	var s := _duel("dancer", "dancer", 600.0)
	s.fighters[0].pos.y = -300.0
	s.fighters[0].fans = 2
	var fans_thrown := 0
	for _i in 6:   # (throw Air Fans as often as she's allowed before she lands)
		if s.legal_moves(0).has("airfan"):
			s.apply({0: {"move": "airfan", "x": 1.0, "y": 1.0}})
			fans_thrown += 1
		for _t in 22:
			s.step()
	_check("Air Fan: she keeps falling as she throws, two fans at most before she lands (%d thrown, y %.0f)"
			% [fans_thrown, s.fighters[0].pos.y], fans_thrown <= 2 and s.fighters[0].pos.y > -300.0)
	s = _duel("dancer", "dancer", 600.0)
	var top := 0.0
	s.apply({0: {"move": "superjump", "x": 0.0, "y": -1.0}, 1: {"move": "wait"}})
	for _i in 30:
		s.step()
		if s.fighters[0].air_moves < Sim.AIR_OPTIONS and s.legal_moves(0).has("airjump"):
			s.apply({0: {"move": "airjump", "x": 0.0, "y": -1.0}})
		top = minf(top, s.fighters[0].pos.y)
	s.fighters[0].vel.y = -60.0   # (a launch far too strong)
	for _i in 5:
		s.step()
		top = minf(top, s.fighters[0].pos.y)
	_check("the Ceiling (the wiki's rules): nobody goes above it (highest %.0f, ceiling %.0f)" % [-top, s.ceiling],
			-top <= s.ceiling + 0.5)
	s = _duel("dancer", "dancer", 600.0)
	s.fighters[0].pos.y = -20.0
	s.fighters[0].vel.y = 4.0
	s.apply({0: {"move": "airknee", "x": 1.0}, 1: {"move": "wait"}})
	for _i in 8:
		s.step()
	_check("Land Cancel: an air attack ends as she lands, a little landing lag instead (move '%s', lock %d)"
			% [s.fighters[0].move, s.fighters[0].lock], s.fighters[0].grounded() and s.fighters[0].move == ""
			and s.fighters[0].lock > 0 or s.fighters[0].move == "" and s.fighters[0].grounded())
	s = _duel("dancer", "dancer", 70.0)
	s.fighters[0].burst = 0
	s.apply({0: {"move": "glide", "x": 1.0, "dist": 0.0}, 1: {"move": "straight", "x": -1.0}})
	var evs: Array = s.run_segment()["events"]
	var hit_on_me: bool = evs.any(func(e: Dictionary) -> bool: return str(e["type"]) == "hit" and int(e["d"]) == 0)
	_check("Low Profile: Silk Glide ducks under a Straight (%s)" % [_types(evs)], not hit_on_me)


func _test_spacer() -> void:
	_section("The Dancer, a spacer (Timmy 23:59): the fan's edge, point blank weaker, her limits")
	var far := _duel("dancer", "dancer", 95.0)
	far.fighters[1].burst = 0
	far.apply({0: {"move": "sidekick", "x": 1.0, "dist": 0.0}, 1: {"move": "wait"}})
	var ef: Array = far.run_segment()["events"]
	var near := _duel("dancer", "dancer", 30.0)
	near.fighters[1].burst = 0
	near.apply({0: {"move": "sidekick", "x": 1.0, "dist": 0.0}, 1: {"move": "wait"}})
	var en: Array = near.run_segment()["events"]
	var hf: Array = ef.filter(func(e: Dictionary) -> bool: return str(e["type"]) == "hit")
	var hn: Array = en.filter(func(e: Dictionary) -> bool: return str(e["type"]) == "hit")
	_check("a Side Kick at the fan's edge hits harder than point blank (%s vs %s)" % [hf, hn], not hf.is_empty()
			and not hn.is_empty() and int(hf[0].get("spot", 0)) == 1 and int(hn[0].get("spot", 0)) == -1
			and int(hf[0]["dmg"]) > int(hn[0]["dmg"]))
	var t := _duel("dancer", "dancer", 600.0)
	var most := 0          # (the most fans of hers out at once)
	var empty_throw := false
	for _i in 6:
		if t.legal_moves(0).has("fan"):
			empty_throw = empty_throw or t.fighters[0].fans == 0
			t.apply({0: {"move": "fan", "x": 1.0}, 1: {"move": "wait"}})
		for _k in 10:
			t.step()
			var out := 0
			for sh: Dictionary in t.shots:
				if int(sh["owner"]) == 0 and str(sh["kind"]) == "fan":
					out += 1
			most = maxi(most, out)
	_check("two fans: never more than two out at once (%d), never a throw with none in hand" % most, most == 2
			and not empty_throw and Sim.FANS_MAX == 2)
	var b1 := _duel("dancer", "dancer", 60.0)
	var b2 := _duel("dancer", "dancer", 60.0)
	b2.fighters[1].fans = 0
	for b: Sim in [b1, b2]:
		b.apply({0: {"move": "straight", "x": 1.0, "dist": 0.0}, 1: {"move": "block", "y": -1.0}})
		b.run_segment()
	_check("her limit: with no fan in hand she blocks worse (chip %d vs %d)" % [450 - b1.fighters[1].hp,
			450 - b2.fighters[1].hp], 450 - b2.fighters[1].hp > 450 - b1.fighters[1].hp)


func _test_beating_backdash() -> void:
	_section("Beating Backdash (the wiki): backing off while they dash in, you're stuck in it until they can act")
	var s := _duel("dancer", "dancer", 400.0)
	s.apply({0: {"move": "walk", "x": -1.0}, 1: {"move": "dash", "x": -1.0}})
	for _i in 4:
		s.step()
	var chased := not s.interruptible(s.fighters[0])
	var t := _duel("dancer", "dancer", 400.0)
	t.apply({0: {"move": "walk", "x": -1.0}, 1: {"move": "wait"}})
	for _i in 4:
		t.step()
	_check("walking away from a dash in can't be interrupted; from someone standing it can", chased
			and t.interruptible(t.fighters[0]))


func _test_steer_fans() -> void:
	_section("Steerable fans (the research: Cowboy's bullets take DI): Recall with a direction flings them that way")
	var s := _duel("dancer", "dancer", 700.0)
	s.apply({0: {"move": "fan", "x": 1.0}, 1: {"move": "wait"}})
	_steps(s, 40, func() -> bool: return s.fighters[0].actionable())
	s.apply({0: {"move": "recall", "x": 0.0, "y": -1.0}})
	for _i in 6:
		s.step()
	var v: Vector2 = s.shots[0]["vel"] if not s.shots.is_empty() else Vector2.ZERO
	var t := _duel("dancer", "dancer", 700.0)
	t.apply({0: {"move": "fan", "x": 1.0}, 1: {"move": "wait"}})
	_steps(t, 40, func() -> bool: return t.fighters[0].actionable())
	t.apply({0: {"move": "recall"}})
	for _i in 6:
		t.step()
	var w: Vector2 = t.shots[0]["vel"] if not t.shots.is_empty() else Vector2.ZERO
	_check("flung up it flies up (%s); with no direction it heads home (%s)" % [v, w], v.y < -5.0 and absf(v.x) < 1.0
			and w.x < -5.0)


## Someone launched and coming down, in hitstun, this far up: (sim, the one falling).
func _falling(s: Sim) -> Fighter:
	var d: Fighter = s.fighters[1]
	d.pos.y = -30.0
	d.vel = Vector2(0.0, 6.0)
	d.stun = 40
	d.combo = 3
	d.launched = true
	return d


func _test_restand() -> void:
	_section("Restands (the wiki): an air combo landing ends it - unless they're hit in the 5 frames as they land")
	var s := _duel("dancer", "dancer", 300.0)
	var d := _falling(s)
	for _i in 12:
		if d.pos.y >= 0.0:
			break
		s.step()
	var landed: bool = d.stun == 0 and d.lock == Sim.RESTAND_LAG - 0 or d.lock == Sim.RESTAND_LAG - 1
	var kept: int = d.combo
	for _i in Sim.RESTAND + 1:
		s.step()
	_check("launched, landing without a knockdown: out of the stun (lock %d), then the combo's over (%d -> %d)"
			% [d.lock, kept, d.combo], landed and kept == 3 and d.combo == 0 and d.actionable())
	var t := _duel("dancer", "dancer", 60.0)
	var e := _falling(t)
	for _i in 12:
		if e.pos.y >= 0.0:
			break
		t.step()
	var a: Fighter = t.fighters[0]
	t._start(a, {"move": "jab", "x": 1.0})
	a.frame = 2   # (its hit comes out on the next frame - inside the window)
	var events: Array = []
	for _i in 3:
		t.step()
		events.append_array(t.events.map(func(ev: Dictionary) -> String: return str(ev["type"])))
	_check("hit as they land: RESTAND - back in a ground combo, the count carrying on (%s, combo %d)" % [events,
			e.combo], events.has("restand") and e.combo == 4 and e.stun > 0)


func _test_initiative_faster() -> void:
	_section("Initiative (the wiki): Side Kick starts 2 frames sooner when the enemy was choosing too")
	var s := _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "sidekick", "x": 1.0}, 1: {"move": "wait"}})
	var with: int = s.fighters[0].frame
	var t := _duel("dancer", "dancer", 300.0)
	t._start(t.fighters[1], {"move": "spin", "x": -1.0})   # (already committed to a move)
	t.apply({0: {"move": "sidekick", "x": 1.0}})
	var without: int = t.fighters[0].frame
	_check("with initiative it starts at frame %d; against someone already committed, at %d" % [with, without],
			with == 2 and without == 0)


func _test_thinking_bot() -> void:
	_section("Smarter bots (01:32): a thinking bot punishes an enemy stuck in a move's recovery, in reach")
	var hits := 0
	for k in 4:   # (a few seeds - it isn't always the same pick, but it should land)
		var s := _duel("dancer", "dancer", 80.0)
		var t: Fighter = s.fighters[1]
		s._start(t, {"move": "sidekick", "x": -1.0})
		t.frame = 15   # (its hit's gone by - in recovery)
		var pick := Bot.new(k * 5 + 1, 2).choose(s, 0)
		var evs: Array = s.preview({0: pick}, 30)["events"]
		if evs.any(func(e: Dictionary) -> bool: return str(e["type"]) == "hit" and int(e["a"]) == 0):
			hits += 1
	_check("it lands a punish %d times in 4 (it's not reading their pick - only the state anyone can see)" % hits,
			hits >= 3)


func _test_zoner_kit() -> void:
	_section("The zoner's kit (03:32): Fan Ward hangs a trap, Recall's pincer, Fan Gust's wind, Mirror turns shots, "
			+ "the rushdown moves gone")
	var kit := Moves.of("dancer")
	var gone := ["kneedash", "flashkick", "onetwo", "spinfinish", "divekick", "airspin", "hiptoss", "spinthrow", "sway",
		"swaykick", "risingheel", "swaystep"]
	_check("the rushdown moves are gone (Knee Dash, Flash Kick, the jab chain, Dive Kick, Air Spin, the command grabs, "
			+ "the Sway); in their place Fan Ward, Fan Gust, Fan Flick", gone.all(func(m: String) -> bool:
				return not kit.has(m)) and kit.has("fanward") and kit.has("fangust") and kit.has("fanflick"))
	# Fan Ward: out as far as the Distance says, then it hangs there
	var spots := []
	for dist: float in [0.0, 100.0]:
		var w := _duel("dancer", "dancer", 700.0)
		w.apply({0: {"move": "fanward", "x": 1.0, "dist": dist}, 1: {"move": "wait"}})
		for _i in 40:
			w.step()
		var hung: Array = w.shots.filter(func(x: Dictionary) -> bool: return int(x.get("leg", 0)) == 2)
		spots.append((hung[0]["pos"] as Vector2).x - w.fighters[0].pos.x if hung.size() == 1 else -1.0)
	_check("Fan Ward: the fan stops where the Distance says and hangs there (Distance 0: %.0f px out, 100: %.0f px)"
			% spots, float(spots[0]) > 30.0 and float(spots[1]) > float(spots[0]) + 120.0)
	var s := _duel("dancer", "dancer", 500.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "fanward", "x": 1.0, "dist": 60.0}, 1: {"move": "wait"}})
	for _i in 30:
		s.step()
	var ward: Dictionary = s.shots[0] if s.shots.size() == 1 else {}
	var at: Vector2 = ward.get("pos", Vector2.ZERO)
	for _i in 120:
		s.step()
	var shown: Array = s.record_shots()
	_check("...still hanging 2 s later, in the replay as a ward; one fan in hand (%s, fans %d)" % [shown,
			s.fighters[0].fans], s.shots.size() == 1 and (s.shots[0]["pos"] as Vector2).is_equal_approx(at)
			and str(shown[0][2]) == "ward" and s.fighters[0].fans == 1)
	s.events.clear()
	s.fighters[1].pos.x = at.x + 20.0
	for _i in 4:
		s.step()
	_check("...whoever walks into it is hit, and it heads home (%s, hp %d)" % [_types(s.events), s.fighters[1].hp],
			_types(s.events).has("hit") and s.fighters[1].hp < 450 and int(s.shots[0]["leg"]) == 1)
	s = _duel("dancer", "dancer", 500.0)
	s.fighters[1].burst = 0
	s.apply({0: {"move": "fanward", "x": 1.0, "dist": 100.0}, 1: {"move": "wait"}})
	for _i in 40:
		s.step()
	s.fighters[1].pos.x = s.fighters[0].pos.x + 110.0   # (between her and her ward)
	s.events.clear()
	s.apply({0: {"move": "recall"}, 1: {"move": "wait"}})
	for _i in 30:
		s.step()
	_check("...Recall pulls it home through whoever's between - a pincer (%s, hp %d, fans %d)" % [_types(s.events),
			s.fighters[1].hp, s.fighters[0].fans], _types(s.events).has("hit") and s.fighters[1].hp < 450)
	s = _duel("dancer", "dancer", 600.0)
	s.apply({0: {"move": "fanward", "x": 1.0, "y": -1.0, "dist": 100.0}, 1: {"move": "wait"}})
	for _i in 40:
		s.step()
	var high: Vector2 = s.shots[0]["pos"] if s.shots.size() == 1 else Vector2.ZERO
	s.apply({0: {"move": "fanstep"}, 1: {"move": "wait"}})
	for _i in 8:
		s.step()
	_check("...sent up and forward it hangs in the air (%.0f, %.0f); Fan Step blinks her to it (her x %.0f)" % [high.x,
			high.y, s.fighters[0].pos.x], high.y < -150.0 and absf(s.fighters[0].pos.x - high.x) < 30.0
			and s.fighters[0].fans == 2)
	s = _duel("dancer", "dancer", 700.0)
	s.fighters[1].pos.y = 0.0
	s.apply({0: {"move": "fanward", "x": 1.0, "y": 1.0, "dist": 100.0}, 1: {"move": "wait"}})
	for _i in 40:
		s.step()
	_check("...sent down into the floor it hangs low there - a mine (y %.0f)" % (float((s.shots[0]["pos"] as Vector2).y)
			if s.shots.size() == 1 else 0.0), s.shots.size() == 1 and int(s.shots[0]["leg"]) == 2
			and (s.shots[0]["pos"] as Vector2).y > -40.0)
	# Fan Gust: wind - shoves them off, no damage; their shots blown back
	s = _duel("dancer", "dancer", 110.0)
	var gap0 := s.fighters[1].pos.x - s.fighters[0].pos.x
	var evs := _play(s, {0: {"move": "fangust"}, 1: {"move": "wait"}})
	_check("Fan Gust shoves them off, no damage (gap %.0f -> %.0f, hp %d, %s)" % [gap0, s.fighters[1].pos.x
			- s.fighters[0].pos.x, s.fighters[1].hp, _types(evs)], s.fighters[1].pos.x - s.fighters[0].pos.x > gap0 + 70.0
			and s.fighters[1].hp == 450 and _types(evs).has("gusted"))
	s = _duel("dancer", "dancer", 400.0)
	s.apply({0: {"move": "wait"}, 1: {"move": "ripple"}})
	var gusted := false
	var away := false
	for _i in 90:
		s.step()
		if not gusted and not s.shots.is_empty() and s.fighters[0].actionable() \
				and (s.shots[0]["pos"] as Vector2).x - s.fighters[0].pos.x < 160.0:
			s.apply({0: {"move": "fangust"}})
			gusted = true
		if gusted and not s.shots.is_empty() and float((s.shots[0]["vel"] as Vector2).x) > 0.0:
			away = true
	_check("...and blows their shot back the way it came (a Ground Ripple - blown back: %s, her hp %d)" % [away,
			s.fighters[0].hp], gusted and away and s.fighters[0].hp == 450)
	s = _duel("dancer", "dancer", 700.0)
	s.apply({0: {"move": "fanward", "x": 1.0, "dist": 40.0}, 1: {"move": "wait"}})
	for _i in 30:
		s.step()
	var x0 := float((s.shots[0]["pos"] as Vector2).x)
	s.apply({0: {"move": "fangust"}, 1: {"move": "wait"}})
	for _i in 30:
		s.step()
	_check("...and carries her own on: a hanging ward drifts toward them (x %.0f -> %.0f)" % [x0,
			float((s.shots[0]["pos"] as Vector2).x)], float((s.shots[0]["pos"] as Vector2).x) > x0 + 30.0)
	# Mirror: a shot turned round
	s = _duel("dancer", "dancer", 300.0)
	s.fighters[0].burst = 0
	s.apply({0: {"move": "ripple"}, 1: {"move": "wait"}})
	var mirrored := false
	for _i in 120:
		s.step()
		if not mirrored and not s.shots.is_empty() and s.fighters[1].actionable() \
				and s.fighters[1].pos.x - (s.shots[0]["pos"] as Vector2).x < 90.0:
			s.apply({1: {"move": "mirror"}})
			mirrored = true
	_check("Mirror turns a shot round: the Ground Ripple goes back and hits its thrower (%s, hp %d / %d)"
			% [_types(s.events).filter(func(t: String) -> bool: return t in ["reflect", "hit"]), s.fighters[0].hp,
			s.fighters[1].hp], _types(s.events).has("reflect") and s.fighters[0].hp < 450 and s.fighters[1].hp == 450)
	s = _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "fan", "x": 1.0}, 1: {"move": "wait"}})
	mirrored = false
	for _i in 160:
		s.step()
		if not mirrored and not s.shots.is_empty() and s.fighters[1].actionable() \
				and s.fighters[1].pos.x - (s.shots[0]["pos"] as Vector2).x < 90.0:
			s.apply({1: {"move": "mirror"}})
			mirrored = true
	_check("...a thrown fan is sent home instead - it's hers to keep (%s, hp %d, her fans %d, the Mirror's %d)"
			% [_types(s.events).filter(func(t: String) -> bool: return t in ["reflect", "hit", "catch"]),
			s.fighters[1].hp, s.fighters[0].fans, s.fighters[1].fans], _types(s.events).has("reflect")
			and s.fighters[1].hp == 450 and s.fighters[0].fans == 2 and s.fighters[1].fans == 2)
	var bot_moves: Array = Bot.GROUND_HITS + Bot.FROM_AFAR + Bot.AIR + Bot.GRABS + Bot.CLOSE_IN + Bot.KEEP_OUT + Bot.MID
	var known := func(m: String) -> bool: return kit.has(m)
	_check("the bots only reach for moves she still has", bot_moves.all(known))


func _test_zoner_supers() -> void:
	_section("Her supers, a zoner's (03:03): Fan Storm's volley, Gale's wind, the Cyclone holding the space, fans from the sky")
	var s := _duel("dancer", "dancer", 380.0)
	s.fighters[0].meter = Sim.METER_MAX
	s.fighters[1].burst = 0
	s.apply({0: {"move": "fanstorm", "x": 1.0}, 1: {"move": "wait"}})
	var most := 0
	var hit := false
	for _i in 60:
		s.step()
		most = maxi(most, s.shots.size())
		hit = hit or s.events.any(func(e: Dictionary) -> bool: return str(e["type"]) == "hit" and int(e["a"]) == 0)
	_check("Fan Storm: five fans in a spread from range (most out %d), it lands, her own two still in hand (%d)" % [most,
			s.fighters[0].fans], most == 5 and hit and s.fighters[0].fans == Sim.FANS_MAX)
	var g := _duel("dancer", "dancer", 60.0)
	g.fighters[0].meter = Sim.METER_MAX
	g.apply({0: {"move": "gale"}, 1: {"move": "straight", "x": -1.0}})
	for _i in 20:
		g.step()
	_check("Gale: wind all round her blows a rusher off (gap %.0f, she's untouched %d)" % [absf(g.fighters[1].pos.x
			- g.fighters[0].pos.x), g.fighters[0].hp], absf(g.fighters[1].pos.x - g.fighters[0].pos.x) > 140.0
			and g.fighters[0].hp == g.fighters[0].max_hp)
	var c := _duel("dancer", "dancer", 260.0)
	c.fighters[0].meter = Sim.METER_MAX
	c.fighters[1].burst = 0
	c.apply({0: {"move": "cyclone", "x": 1.0}, 1: {"move": "wait"}})
	var hits := 0
	for _i in 120:
		c.step()
		hits += c.events.filter(func(e: Dictionary) -> bool: return str(e["type"]) == "hit" and int(e["a"]) == 0).size()
		if not c.deciders().is_empty():
			var hold := {}
			for id in c.deciders():
				hold[id] = {"move": "hold"} if not c.fighters[id].actionable() else {"move": "wait"}
			c.apply(hold)
	_check("Cyclone: a whirlwind that keeps hitting whoever's in it (%d hits)" % hits, hits >= 3)
	var r := _duel("dancer", "dancer", 300.0)
	r.fighters[0].meter = Sim.METER_MAX
	r.fighters[1].burst = 0
	r.apply({0: {"move": "finale", "x": 1.0}, 1: {"move": "wait"}})
	var from_sky := false
	var rain_hit := false
	for _i in 90:
		r.step()
		from_sky = from_sky or r.shots.any(func(sh: Dictionary) -> bool: return (sh["pos"] as Vector2).y < -400.0)
		rain_hit = rain_hit or r.events.any(func(e: Dictionary) -> bool: return str(e["type"]) == "hit" and int(e["a"]) == 0)
	_check("Grand Finale: fans from the sky across the stage, and they land", from_sky and rain_hit)


## Two Dancers with these x-factors on (Sim RULES "xf"), gap apart, facing each other.
func _xf(rule: String, gap := 300.0) -> Sim:
	var s := Sim.create([{"character": "dancer"}, {"character": "dancer"}], "ffa", {"xf": rule})
	s.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	s.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	s.fighters[0].facing = 1
	s.fighters[1].facing = -1
	return s


## Step tick by tick (everyone who comes free waits / rides it out) until `done` or `ticks` run out.
func _steps(s: Sim, ticks: int, done := Callable()) -> bool:
	for _i in ticks:
		s.step()
		if done.is_valid() and done.call():
			return true
		var hold := {}
		for id in s.deciders():
			hold[id] = {"move": "hold"}
		if not hold.is_empty():
			s.apply(hold)
	return false


func _test_xfactors() -> void:
	_section("The Dancer's x-factors on trial (Timmy 21:14): Fans, Tempo, Forms - each a rule, two together")
	var plain := _xf("")
	var trial := ["fanslash", "recall", "encore", "snapform", "floorform", "pop", "snapkick", "kipup", "floorslide"]
	_check("with none on: none of their moves are there", trial.all(func(m: String) -> bool:
			return not plain.legal_moves(0).has(m)))
	var dancer := _duel()
	_check("the Dancer's own: Fans + Tempo on by default (23:31), Forms off", dancer.xf.has("fans")
			and dancer.xf.has("tempo") and not dancer.xf.has("forms"))
	# ---- Fans
	var s := _xf("fans", 260.0)
	s.fighters[1].burst = 0
	_check("Fans: two in hand - Fan Throw and Fan Slash there, Recall not (none out)", s.fighters[0].fans == 2
			and s.legal_moves(0).has("fan") and s.legal_moves(0).has("fanslash") and not s.legal_moves(0).has("recall"))
	s.apply({0: {"move": "fan"}, 1: {"move": "wait"}})
	var one_out := [false]
	var hp0 := s.fighters[1].hp
	var caught := _steps(s, 260, func() -> bool:
		if s.fighters[0].fans == 1 and s.shots.size() == 1:
			one_out[0] = true
		return one_out[0] and s.fighters[0].fans == 2 and s.shots.is_empty())
	_check("...thrown: one left in hand; it hits (%d), turns and comes back to her hand" % (hp0 - s.fighters[1].hp),
			one_out[0] and caught and s.fighters[1].hp < hp0)
	s = _xf("fans")
	s.fighters[0].fans = 0
	_check("...none in hand: no Fan Throw, no Fan Slash", not s.legal_moves(0).has("fan")
			and not s.legal_moves(0).has("fanslash"))
	s = _xf("fans", 600.0)
	s.apply({0: {"move": "fan"}, 1: {"move": "wait"}})
	_steps(s, 60, func() -> bool: return s.fighters[0].actionable())
	var can_recall := s.legal_moves(0).has("recall")
	s.events.clear()
	s.apply({0: {"move": "recall"}})
	for _i in 6:
		s.step()
	_check("...a fan out: Recall turns it for home at once, fast", can_recall and _types(s.events).has("recall")
			and not s.shots.is_empty() and int(s.shots[0]["leg"]) == 1 and float(s.shots[0]["spd"]) == Sim.FAN_RECALL)
	# ---- Tempo
	s = _xf("tempo", 60.0)
	s.fighters[1].burst = 0
	var evs := _play(s, {0: {"move": "jab"}, 1: {"move": "wait"}})
	_check("Tempo: a landed jab is a beat (%d)" % s.fighters[0].tempo, s.fighters[0].tempo == 1 and _types(evs).has("beat"))
	var d0 := 450 - s.fighters[1].hp
	s = _xf("tempo", 60.0)
	s.fighters[1].burst = 0
	s.fighters[0].tempo = 4
	s.fighters[1].tempo = 3
	_check("...four beats: Encore's there (not with three)", s.legal_moves(0).has("encore")
			and not s.legal_moves(1).has("encore"))
	_play(s, {0: {"move": "jab"}, 1: {"move": "wait"}})
	var d4 := 450 - s.fighters[1].hp
	_check("...each beat hits harder (a jab: %d -> %d at four), and getting hit loses them all" % [d0, d4],
			d4 > d0 and s.fighters[1].tempo == 0)
	s = _xf("tempo", 60.0)
	s.fighters[0].tempo = 4
	s.apply({0: {"move": "encore"}, 1: {"move": "wait"}})
	_check("...Encore spends them", s.fighters[0].tempo == 0 and s.fighters[0].move == "encore")
	s = _xf("tempo", 60.0)
	s.apply({0: {"move": "roll", "x": 1.0}, 1: {"move": "jab"}})
	s.run_segment()
	_check("...dodging through a hit is a beat (%d)" % s.fighters[0].tempo, s.fighters[0].tempo == 1)
	s = _xf("tempo")
	s.fighters[0].tempo = 2
	s.fighters[0].tempo_idle = 0
	for _i in Sim.TEMPO_FADE:
		s.step()
	_check("...and one fades with no new beat for %d ticks (%d)" % [Sim.TEMPO_FADE, s.fighters[0].tempo],
			s.fighters[0].tempo == 1)
	# ---- Forms
	s = _xf("forms", 60.0)
	_check("Forms: Snap / Floor Form there, Flow Form not (in it), their moves not yet", s.legal_moves(0).has("snapform")
			and s.legal_moves(0).has("floorform") and not s.legal_moves(0).has("flowform")
			and not s.legal_moves(0).has("pop") and not s.legal_moves(0).has("kipup"))
	s.apply({0: {"move": "floorform"}, 1: {"move": "wait"}})
	s.run_segment()
	var lm := s.legal_moves(0)
	_check("...Floor: Windmill, Kip-Up, Floor Slide, sweeps and defence - no jumps, no jab (%d moves)" % lm.size(),
			s.fighters[0].form == "floor" and lm.has("windmill") and lm.has("kipup") and lm.has("floorslide")
			and lm.has("sweep") and lm.has("block") and lm.has("flowform") and not lm.has("jump") and not lm.has("jab"))
	s.fighters[1].burst = 0
	evs = _play(s, {0: {"move": "wait"}, 1: {"move": "jab"}})
	_check("...high strikes pass over her on the floor (%s)" % [_types(evs)], not _types(evs).has("hit")
			and s.fighters[0].hp == 450)
	s.apply({0: {"move": "kipup"}, 1: {"move": "wait"}})
	_check("...Kip-Up takes her back to Flow", s.fighters[0].form == "flow")
	s = _xf("forms", 60.0)
	s.apply({0: {"move": "snapform"}, 1: {"move": "wait"}})
	s.run_segment()
	s.fighters[1].burst = 0
	var snap_ok := s.legal_moves(0).has("pop") and s.legal_moves(0).has("snapkick")
	_play(s, {0: {"move": "jab"}, 1: {"move": "wait"}})
	_check("...Snap: Pop and Snap Kick, and her strikes hit harder (jab %d vs %d)" % [450 - s.fighters[1].hp, d0],
			snap_ok and 450 - s.fighters[1].hp > d0)
	# ---- two together, online-safe
	s = _xf("fans,tempo", 400.0)
	s.fighters[0].tempo = 4
	_check("two together: Fans + Tempo - Fan Slash and Encore both there", s.legal_moves(0).has("fanslash")
			and s.legal_moves(0).has("encore") and not s.legal_moves(0).has("snapform"))
	s = _xf("fans,tempo,forms", 400.0)
	s.apply({0: {"move": "fan"}, 1: {"move": "floorform"}})
	for _i in 20:
		s.step()
	var w := Sim.from_dict(JSON.parse_string(JSON.stringify(s.to_dict(), "", false, true)))
	for _i in 80:
		s.step()
		w.step()
	_check("through JSON (as online) it plays on the same: fans, the fan in the air, the form (%d / %d fans)"
			% [s.fighters[0].fans, w.fighters[0].fans], w.xf.size() == 3 and w.fighters[0].fans == s.fighters[0].fans
			and w.shots.size() == s.shots.size() and w.fighters[1].form == "floor"
			and w.fighters[0].pos == s.fighters[0].pos and w.tick == s.tick)
	var saved := Fighter.new().to_dict()
	var missing: Array[String] = []
	for prop: Dictionary in Fighter.new().get_property_list():   # (every fighter variable goes in the saved state -
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not saved.has(str(prop["name"])):   # online starts
			missing.append(str(prop["name"]))                                                         # every turn from it)
	_check("every fighter variable is in the saved state (missing: %s)" % [missing], missing.is_empty())
	var turns_all := []
	var ended := 0
	for rule in ["fans", "tempo", "forms", "fans,tempo", "fans,forms", "tempo,forms"]:
		var m := Sim.create([{"character": "dancer"}, {"character": "dancer"}, {"character": "dancer"}], "ffa",
				{"xf": rule})
		var bots := [Bot.new(5), Bot.new(9), Bot.new(13)]
		var turns := 0
		while not m.over() and turns < 4000:
			var picks := {}
			for id in m.deciders():
				picks[id] = (bots[id] as Bot).choose(m, id)
			m.apply(picks)
			m.run_segment()
			turns += 1
		if m.over():
			ended += 1
		turns_all.append("%s:%d" % [rule, turns])
	_check("bot matches with each one and each pair always end (%s)" % " ".join(turns_all), ended == 6)


func _test_bruiser() -> void:
	_section("The Bruiser (05:03 - Muay Thai + Little Mac, the rushdown): his strings, Super Armor, the clinch, Grit and the K.O. Punch, three ways in")
	var s := _duel("bruiser", "dancer", 60.0)
	var b := s.fighters[0]
	_check("he's on the roster: %d HP, weight %.2f, a rushdown with Grit - no fans, no beats (and she has no Grit)"
			% [b.max_hp, float(Moves.stats("bruiser")["weight"])], Moves.ORDER.has("bruiser") and b.max_hp == 470
			and s.has_xf(b, "grit") and not s.has_xf(b, "fans") and not s.has_xf(b, "tempo")
			and not s.has_xf(s.fighters[1], "grit") and not s.legal_moves(0).has("fan") and s.legal_moves(0).has("clinch"))
	var kit := Moves.of("bruiser")
	var bot_moves: Array = Bot.B_IN + Bot.B_HITS + Bot.B_AIR + Bot.B_GRABS + Bot.B_SUPERS + Bot.B_FOLLOW
	_check("...his bots only reach for his own moves", bot_moves.all(func(m: String) -> bool: return kit.has(m)))
	# Jab -> Cross -> Hook
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	var after_jab := s.legal_moves(0)
	s.apply({0: {"move": "cross"}, 1: {"move": "hold"}})
	s.run_segment()
	var after_cross := s.legal_moves(0)
	s.apply({0: {"move": "hook"}, 1: {"move": "hold"}})
	s.run_segment()
	_check("Jab (f%d - hers is f%d) -> Cross -> Hook: each there only right after the one before (combo %d)"
			% [Moves.startup(kit["jab"]), Moves.startup(Moves.move("dancer", "jab")), s.fighters[1].combo],
			Moves.startup(kit["jab"]) < Moves.startup(Moves.move("dancer", "jab")) and after_jab.has("cross")
			and not after_jab.has("hook") and after_cross.has("hook") and s.fighters[1].combo == 3)
	var near := _duel("bruiser", "dancer", 50.0)
	var e := {"dmg": 20, "stun": 14, "kb": [2.0, 0.0], "block": 6, "chip": 1, "box": [8, -88, 48, 18]}
	var close: Dictionary = near._spaced(near.fighters[0], near.fighters[1], e)
	near.fighters[1].pos.x = 200.0
	var far: Dictionary = near._spaced(near.fighters[0], near.fighters[1], e)
	_check("a rushdown on top of them hits harder (point blank %d dmg / %d stun; further off %d / %d)" % [int(close["dmg"]),
			int(close["stun"]), int(far["dmg"]), int(far["stun"])], int(close["dmg"]) > 20 and int(close["stun"]) > 14
			and int(far["dmg"]) == 20 and bool(close.get("press", false)))
	# Super Armor
	var a := _duel("bruiser", "dancer", 60.0)
	var evs := _play(a, {0: {"move": "roundhouse"}, 1: {"move": "jab"}})
	var armored := evs.filter(func(x: Dictionary) -> bool: return x["type"] == "armor")
	var kicked := evs.filter(func(x: Dictionary) -> bool: return x["type"] == "hit" and int(x["a"]) == 0)
	_check("Super Armor: her jab lands in the Roundhouse's armour - he takes it and kicks on (%s; he %d, she %d)"
			% [_types(evs), a.fighters[0].hp, a.fighters[1].hp], not armored.is_empty() and not kicked.is_empty()
			and a.fighters[0].hp < 470 and a.fighters[1].hp < 450)
	a = _duel("bruiser", "dancer", 300.0)
	a.apply({0: {"move": "roundhouse"}, 1: {"move": "wait"}})
	for _i in 5:
		a.step()
	var plain := {"dmg": 20, "stun": 14, "kb": [2.0, 0.0], "block": 6, "chip": 1}
	a._strike(a.fighters[1], a.fighters[0], plain, "attack", a.fighters[0].frame)
	var tanked := a.fighters[0].stun == 0 and a.fighters[0].move == "roundhouse" and a.fighters[0].hp == 450
	a._strike(a.fighters[1], a.fighters[0], plain, "attack", a.fighters[0].frame)
	_check("...one hit only (the wiki): a second in the window gets him (first tanked %s, then reeling %s)" % [tanked,
			a.fighters[0].stun > 0], tanked and a.fighters[0].stun > 0)
	a = _duel("bruiser", "dancer", 300.0)
	a.fighters[0].meter = Sim.BAR
	a.apply({0: {"move": "bullrush"}, 1: {"move": "wait"}})
	for _i in 6:
		a.step()
	for _i in 3:
		a._strike(a.fighters[1], a.fighters[0], plain, "attack", a.fighters[0].frame)
	var three := a.fighters[0].stun == 0 and a.fighters[0].move == "bullrush"
	a._strike(a.fighters[1], a.fighters[0], plain, "attack", a.fighters[0].frame)
	_check("...Bull Rush (a bar) takes three, the fourth gets him (%s, %s)" % [three, a.fighters[0].stun > 0],
			three and a.fighters[0].stun > 0)
	a = _duel("bruiser", "dancer", 60.0)
	evs = _play(a, {0: {"move": "roundhouse"}, 1: {"move": "grab"}})
	_check("...a grab goes straight through armour (%s)" % [_types(evs)], _types(evs).has("throw")
			and not _types(evs).has("armor") and a.fighters[0].hp < 470)
	a = _duel("bruiser", "dancer", 300.0)
	a.apply({0: {"move": "wait"}, 1: {"move": "fan"}})
	var swung := false
	for _i in 60:
		a.step()
		if not swung and not a.shots.is_empty() and absf((a.shots[0]["pos"] as Vector2).x - a.fighters[0].pos.x) < 100.0:
			a.apply({0: {"move": "haymaker", "dist": 0.0}})
			swung = true
	_check("...and takes a thrown fan as it takes a strike: the Haymaker walks through it (%s, his move %s)"
			% [_types(a.events).filter(func(t: String) -> bool: return t in ["armor", "hit"]), a.fighters[0].move],
			swung and _types(a.events).has("armor") and a.fighters[0].hp < 470)
	# the clinch
	var c := _duel("bruiser", "dancer", 50.0)
	c.apply({0: {"move": "clinch"}, 1: {"move": "wait"}})
	var ce: Array = c.run_segment()["events"]
	var lm := c.legal_moves(0)
	var gap := absf(c.fighters[1].pos.x - c.fighters[0].pos.x)
	_check("the Clinch holds her right in front of him (%.0f px), and he's free into a knee, an elbow or a dump"
			% gap, _types(ce).has("throw") and c.fighters[1].stun > 0 and gap < 50.0 and lm.has("clinchknee")
			and lm.has("clinchelbow") and lm.has("dump") and not lm.has("cross"))
	var knees := 0
	for _k in 3:
		if not c.legal_moves(0).has("clinchknee"):
			break
		c.apply({0: {"move": "clinchknee"}, 1: {"move": "hold"}})
		c.run_segment()
		knees += 1
	gap = absf(c.fighters[1].pos.x - c.fighters[0].pos.x)
	c.fighters[0].meter = 0
	_check("...knees, up to three in a row with no bar for it, and she's still held (%d knees, %.0f px, combo %d; a fourth: %s)"
			% [knees, gap, c.fighters[1].combo, c.legal_moves(0).has("clinchknee")], knees == 3 and gap < 50.0
			and c.fighters[1].combo == 4 and not c.legal_moves(0).has("clinchknee") and c.legal_moves(0).has("dump"))
	var x0 := c.fighters[0].pos.x
	var side0 := signf(c.fighters[1].pos.x - x0)
	c.apply({0: {"move": "dump"}, 1: {"move": "hold"}})
	evs = c.run_segment()["events"]
	for _i in 80:
		if c.fighters[1].down > 0:
			break
		c.step()
	_check("...the Dump throws her down behind him (side %+.0f -> %+.0f, down %s)" % [side0,
			signf(c.fighters[1].pos.x - c.fighters[0].pos.x), c.fighters[1].down > 0], c.fighters[1].down > 0
			and signf(c.fighters[1].pos.x - c.fighters[0].pos.x) != side0)
	var fury := _duel("bruiser", "dancer", 50.0)
	fury.fighters[0].meter = 3 * Sim.BAR
	fury.apply({0: {"move": "clinchfury"}, 1: {"move": "wait"}})
	var spent := fury.fighters[0].meter == 0
	evs = _play(fury, {})
	var fury_hits := evs.filter(func(x: Dictionary) -> bool: return x["type"] in ["hit", "throw"] and int(x["a"]) == 0)
	_check("Clinch Fury (3 bars): a clinch that won't let go - %d hits, %d damage, and she's floored" % [fury_hits.size(),
			450 - fury.fighters[1].hp], fury_hits.size() == 5 and 450 - fury.fighters[1].hp >= 100
			and spent and _types(evs).has("down"))
	var miss := _duel("bruiser", "dancer", 300.0)
	miss.fighters[0].meter = 3 * Sim.BAR
	evs = _play(miss, {0: {"move": "clinchfury"}, 1: {"move": "wait"}})
	_check("...missed, its knees hit nothing (%s)" % [_types(evs)], not _types(evs).has("hit") and miss.fighters[1].hp == 450)
	# Grit and the K.O. Punch
	var g := _duel("bruiser", "dancer", 60.0)
	g._hurt(g.fighters[0], g.fighters[1], {"dmg": 50, "stun": 10, "kb": [1.0, 0.0]}, "hit", "jab")
	var dealt := g.fighters[0].grit
	g.fighters[0].grit = 0
	g._hurt(g.fighters[1], g.fighters[0], {"dmg": 50, "stun": 10, "kb": [1.0, 0.0]}, "hit", "jab")
	var taken := g.fighters[0].grit
	_check("Grit builds both ways - faster for what he takes (50 dealt: %d, 50 taken: %d)" % [dealt, taken],
			dealt > 0 and taken > dealt * 2)
	g = _duel("bruiser", "dancer", 60.0)
	g.fighters[0].grit = Sim.GRIT_MAX - 1
	var shut := not g.legal_moves(0).has("kopunch")
	g.fighters[0].grit = Sim.GRIT_MAX
	var open := g.legal_moves(0).has("kopunch")
	evs = _play(g, {0: {"move": "kopunch"}, 1: {"move": "block"}})
	var ko_hit := evs.filter(func(x: Dictionary) -> bool: return x["type"] == "hit" and int(x["a"]) == 0)
	_check("the K.O. Punch: only at full Grit (%s / %s), spends it, goes through her block and floors her (%d dmg, %s)"
			% [shut, open, int(ko_hit[0]["dmg"]) if not ko_hit.is_empty() else 0, _types(evs)], shut and open
			and g.fighters[0].grit < 20 and _types(evs).has("guardbreak") and not ko_hit.is_empty()
			and int(ko_hit[0]["dmg"]) >= 90 and _types(evs).has("down"))
	g.fighters[0].grit = 80
	g._floor(g.fighters[0])
	_check("...floored, he loses half his Grit (80 -> %d)" % g.fighters[0].grit, g.fighters[0].grit == 40)
	# three ways in
	var w := _duel("bruiser", "dancer", 300.0)
	w.apply({0: {"move": "bob", "x": 1.0}, 1: {"move": "wait"}})
	for _i in 5:
		w.step()
	_check("Bob & Weave: ducks high hits and slips a shot that isn't low - but not the Ripple (high %s, mid shot %s, low %s)"
			% [w.hurtbox(w.fighters[0]).size.y < 80.0, w._shot_proof(w.fighters[0], {"height": "mid"}),
			w._shot_proof(w.fighters[0], {"height": "low"})], w.hurtbox(w.fighters[0]).size.y < 80.0
			and w._shot_proof(w.fighters[0], {"height": "mid"}) and not w._shot_proof(w.fighters[0], {"height": "low"}))
	w = _duel("bruiser", "dancer", 120.0)
	evs = _play(w, {0: {"move": "flyknee", "x": 1.0}, 1: {"move": "block"}})
	_check("the Flying Knee leaps in and breaks her guard (%s)" % [_types(evs)], _types(evs).has("guardbreak")
			and _types(evs).has("hit"))
	w = _duel("bruiser", "dancer", 120.0)
	evs = _play(w, {0: {"move": "superman", "x": 1.0}, 1: {"move": "block", "y": 1.0}})
	var worse := evs.filter(func(x: Dictionary) -> bool: return x["type"] == "block" and bool(x.get("worse", false)))
	_check("the Superman Punch is an overhead: blocked low, it's blocked worse (%s)" % [_types(evs)], not worse.is_empty())
	w = _duel("bruiser", "dancer", 300.0)
	w.fighters[1].pos.x = w.fighters[0].pos.x + 150.0
	w.shots.clear()
	w.apply({0: {"move": "flyknee", "x": 1.0}, 1: {"move": "wait"}})
	var peak := 0.0
	for _i in 12:
		w.step()
		peak = minf(peak, w.fighters[0].pos.y)
	_check("...and it's off the floor - over the Ripple (%.0f px up)" % -peak, peak < -26.0)
	# the catch
	var k := _duel("bruiser", "dancer", 70.0)
	evs = _play(k, {0: {"move": "catch"}, 1: {"move": "straight"}})
	_check("Catch: her Straight caught and she's dumped (%s)" % [_types(evs)], _types(evs).has("countered")
			and _types(evs).has("down") and k.fighters[1].hp < 450 and k.fighters[0].hp == 470)
	# 05:27 "slapping an enemy accross map and being able to rush them down"
	var fl := _duel("bruiser", "dancer", 70.0)
	var x_hit := fl.fighters[1].pos.x
	fl.apply({0: {"move": "haymaker", "dist": 0.0}, 1: {"move": "wait"}})
	var fe: Array = []
	for _i in 6:   # (until he's free again - she stands waiting)
		fe.append_array(fl.run_segment()["events"])
		if fl.fighters[0].actionable():
			break
		var hw := {}
		for id in fl.deciders():
			hw[id] = {"move": "hold"}
		fl.apply(hw)
	var flung := fe.filter(func(x: Dictionary) -> bool: return x["type"] == "hit" and bool(x.get("fling", false)))
	var chase_ok := fl.legal_moves(0).has("chase")
	fl.apply({0: {"move": "chase", "x": 1.0}, 1: {"move": "hold"}})
	fl.run_segment()
	var away := fl.fighters[1].pos.x - x_hit
	var gap2 := fl.fighters[1].pos.x - fl.fighters[0].pos.x
	fl.apply({0: {"move": "jab"}, 1: {"move": "hold"}})
	fl.run_segment()
	_check("a fling: the Haymaker sends her sliding across the stage (%.0f px), Chase runs her down (%.0f px apart) "
			% [away, gap2] + "and the combo goes on (combo %d)" % fl.fighters[1].combo, not flung.is_empty() and chase_ok
			and away > 400.0 and gap2 < 90.0 and fl.fighters[1].combo == 2)
	var q := _duel("bruiser", "dancer", 60.0)
	q.fighters[1].down = 10
	evs = _play(q, {0: {"move": "quake"}})
	_check("Quake Stomp: a shockwave along the floor that picks her up off it (%s)" % [_types(evs)],
			_types(evs).has("hit") and q.fighters[1].hp < 450)
	var wide := Sim.create([{"character": "bruiser"}, {"character": "dancer"}])
	_check("the stage is wider (05:27 \"I feel our map is small\"): %.0f px, one on one still starting %.0f apart"
			% [wide.half * 2.0, wide.fighters[1].pos.x - wide.fighters[0].pos.x], wide.half * 2.0 == 2800.0
			and is_equal_approx(wide.fighters[1].pos.x - wide.fighters[0].pos.x, 600.0))
	# the universal blocking rule he leans on
	var bl := _duel("bruiser", "dancer", 60.0)
	bl.apply({0: {"move": "jab"}, 1: {"move": "block"}})
	for _i in 4:
		bl.step()
	var stunned := bl.fighters[1].blockstun > 0
	bl.fighters[1].blockstun = 6
	var gb := {"dmg": 30, "stun": 10, "kb": [1.0, 0.0], "block": 8, "chip": 1, "guardbreak": true}
	_check("in blockstun from his jab, a guard break after it is just blocked (the wiki) (%s, %s)" % [stunned,
			bl._block(bl.fighters[0], bl.fighters[1], gb, Moves.move("dancer", "block"), 9, false)], stunned
			and bl._block(bl.fighters[0], bl.fighters[1], gb, Moves.move("dancer", "block"), 9, false))


func _test_snapshots() -> void:
	_section("Snapshots and previews")
	var s := Sim.create([{"character": "dancer"}, {"character": "dancer"}])
	s.fighters[0].pos.x = -60
	s.fighters[1].pos.x = 60
	var copy := Sim.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var picks := {0: {"move": "sidekick"}, 1: {"move": "dash", "x": 1.0}}
	s.apply(picks)
	copy.apply(picks)
	var a := s.run_segment()
	var b := copy.run_segment()
	_check("a snapshot through JSON (as the network sends it) plays out exactly the same",
			JSON.stringify(a["frames"]) == JSON.stringify(b["frames"]) and JSON.stringify(s.to_dict()) == JSON.stringify(copy.to_dict()))
	var p := Sim.create([{"character": "dancer"}, {"character": "dancer"}])
	var before := JSON.stringify(p.to_dict())
	var ghost: Array = p.preview({0: {"move": "walk", "x": 1.0}}, 30)["frames"]
	_check("a preview shows the move (30 frames, it walks forward) and leaves the match untouched",
			ghost.size() == 30 and float(ghost[-1][0][0]) > float(p.fighters[0].pos.x) + 20.0
			and JSON.stringify(p.to_dict()) == before)
	var d := _duel()
	d.apply({1: {"move": "jab"}})   # (they're already swinging; you're still free to pick)
	var pv: Dictionary = d.preview({0: {"move": "wait", "x": 20}}, 30)
	var hit_me: Array = pv["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "hit" and int(e["d"]) == 0)
	_check("a preview reports what lands on you: standing still in front of a jab gets you hit (%s)" % [pv["events"]],
			not hit_me.is_empty())


func _test_bot_matches() -> void:
	_section("Bot matches: 2 to 6 fighters, free-for-all and teams, always end")
	var ok := 0
	var runs := 0
	var stats := []
	for n in range(2, 7):
		for mode in ["ffa", "teams"]:
			if mode == "teams" and n < 4:
				continue
			for sd in 3:
				var players := []
				for i in n:   # (both characters, mixed - 05:03 the Bruiser)
					players.append({"character": Moves.ORDER[(i + sd) % Moves.ORDER.size()], "team": i % 2})
				var s := Sim.create(players, mode)
				var bots := []
				for i in n:
					bots.append(Bot.new(sd * 31 + i))
				var turns := 0
				while not s.over() and turns < 4000:
					var picks := {}
					for id in s.deciders():
						picks[id] = (bots[id] as Bot).choose(s, id)
					s.apply(picks)
					s.run_segment()
					turns += 1
				runs += 1
				if s.over():
					ok += 1
				stats.append("%d%s:%d" % [n, mode[0], turns])
	print("   bot matches (players+mode:turns): " + " ".join(stats))
	_check("every bot match finishes (%d of %d)" % [ok, runs], ok == runs)
