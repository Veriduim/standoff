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
	_check("ground and air menus differ: a jump on the ground, a dive kick only in the air",
			fresh.legal_moves(1).has("jump") and not fresh.legal_moves(1).has("divekick"))
	fresh.fighters[1].pos.y = -100.0
	_check("...in the air: the dive kick, no jump", fresh.legal_moves(1).has("divekick")
			and not fresh.legal_moves(1).has("jump"))
	fresh.fighters[1].pos.y = 0.0
	_check("a super needs meter", not fresh.legal_moves(1).has("flurry"))
	fresh.fighters[1].meter = Sim.BAR
	_check("...and with a bar it's there", fresh.legal_moves(1).has("flurry") and not fresh.legal_moves(1).has("cyclone"))
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
	s = _duel("dancer", "dancer", 90.0)
	evs = _play(s, {0: {"move": "kneedash"}, 1: {"move": "block"}})
	_check("a Guard Break (the knee dash) goes straight through a Block (%s)" % [_types(evs)], _types(evs).has("hit")
			and not _types(evs).has("block"))
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
	s = _duel("dancer", "dancer", 80.0)
	s.apply({0: {"move": "uppercut"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("...not every move frees you on a hit: the uppercut doesn't", s.fighters[0].move == "uppercut")
	s = _duel()
	s.apply({0: {"move": "jab"}, 1: {"move": "sidekick"}})
	evs = _play(s, {})
	var counter := evs.filter(func(e: Dictionary) -> bool: return e["type"] == "hit" and e.get("counter", false))
	_check("hitting someone mid-attack is a counter hit for 10%% more (%s)" % [counter],
			not counter.is_empty() and int(counter[0]["dmg"]) == 20)
	s = _duel("dancer", "dancer", 300.0)
	s.apply({0: {"move": "dash", "x": 1.0}, 1: {"move": "wait"}})
	s.run_segment()
	_check("a dash gives way when the other can act: pick again or Hold (%s)" % [s.deciders()],
			s.deciders().has(0) and s.legal_moves(0).has("hold"))
	s = _duel()
	s.fighters[1].pos.x = Sim.STAGE_HALF - 60.0
	s.fighters[0].pos.x = Sim.STAGE_HALF - 120.0
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
	s.fighters[0].pos.x = Sim.STAGE_HALF - 110.0
	s.fighters[1].pos.x = Sim.STAGE_HALF - 40.0
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
	s = _duel("dancer", "dancer", 300.0)
	_check("the Sway's moves aren't there outside it", not s.legal_moves(0).has("swaykick"))
	s.apply({0: {"move": "sway"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("...in the Sway: Sway Kick, Rising Heel, Sway Step (%s)" % [s.legal_moves(0).filter(func(m: String) -> bool:
			return m.begins_with("sway") or m == "risingheel")], s.legal_moves(0).has("swaykick")
			and s.legal_moves(0).has("risingheel") and s.legal_moves(0).has("swaystep"))
	s = _duel()
	s.fighters[1].burst = 0
	_check("One-Two only after landing a jab", not s.legal_moves(0).has("onetwo"))
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	_check("...landed: One-Two is there, Spin Finish not yet", s.legal_moves(0).has("onetwo")
			and not s.legal_moves(0).has("spinfinish"))
	s.fighters[0].pos.x = s.fighters[1].pos.x - 60.0
	s.fighters[1].vel = Vector2.ZERO
	s.apply({0: {"move": "onetwo"}, 1: {"move": "hold"}})
	s.run_segment()
	_check("...and after the One-Two, Spin Finish", s.legal_moves(0).has("spinfinish"))
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
	s.apply({0: {"move": "sway"}, 1: {"move": "wait"}})
	s.run_segment()
	s.apply({0: {"move": "risingheel"}, 1: {"move": "hold"}})
	for _i in 6:
		s.run_segment()
		if s.fighters[0].actionable():
			break
		s.apply({1: {"move": "hold"}})
	_check("Rising Heel launches and cancels only into jumps (%s)" % [s.legal_moves(0)], s.fighters[1].stun > 0
			and s.legal_moves(0).has("superjump") and not s.legal_moves(0).has("jab"))
	s = _duel()
	evs = _play(s, {0: {"move": "uppercut"}, 1: {"move": "jab"}})
	_check("initiative: an uppercut picked while they pick too goes through their jab (%s, hp %d / %d)" % [_types(evs),
			s.fighters[0].hp, s.fighters[1].hp], s.fighters[0].hp == 450 and s.fighters[1].hp < 450)
	s = _duel()
	s.fighters[0].meter = Sim.METER_MAX
	_check("Grand Finale, the third super, takes all 3 bars", s.legal_moves(0).has("finale"))


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
				for i in n:
					players.append({"character": "dancer", "team": i % 2})
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
