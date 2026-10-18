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
	s.apply({0: {"move": "wait"}, 1: {"move": "guard"}, 2: {"move": "guard"}})
	var seg := s.run_segment()
	_check("a 10-frame wait stops the run after 10 ticks; the two guarding may pick again or Hold - guard gives way (%d ticks, %s)"
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
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "guard", "x": 30}})
	_check("guard blocks it - only chip damage (%s, hp %d)" % [_types(evs), s.fighters[1].hp],
			_types(evs).has("block") and s.fighters[1].hp == 449)
	s = _duel("dancer", "dancer", 50.0)
	evs = _play(s, {0: {"move": "grab"}, 1: {"move": "guard", "x": 30}})
	_check("a grab goes through guard (%s)" % [_types(evs)], _types(evs).has("throw"))
	s = _duel("dancer", "dancer", 50.0)
	evs = _play(s, {0: {"move": "grab"}, 1: {"move": "jab"}})
	_check("a strike beats a grab (%s)" % [_types(evs)], _types(evs).has("hit") and not _types(evs).has("throw")
			and s.fighters[0].hp < 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "parry_early"}})
	_check("Parry Early (frames 1-6) stops a jab landing on frame 6 and stuns the jabber (%s)" % [_types(evs)],
			_types(evs).has("parry") and s.fighters[1].hp == 450)
	s = _duel()
	evs = _play(s, {0: {"move": "jab"}, 1: {"move": "parry_late"}})
	_check("...Parry Late (frames 7-13) is too late for it (%s)" % [_types(evs)], _types(evs).has("hit"))
	s = _duel("dancer", "dancer", 80.0)
	evs = _play(s, {0: {"move": "straight"}, 1: {"move": "parry_late"}})
	_check("...but catches a straight landing on frame 7 (%s)" % [_types(evs)], _types(evs).has("parry"))
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
	t.apply({0: {"move": "taunt"}, 1: {"move": "guard"}})
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
	evs = _play(s, {0: {"move": "guard"}, 1: {"move": "burst"}})
	_check("guarding blocks a Burst - safe, a short push (%s)" % [_types(evs)], _types(evs).has("block")
			and not _types(evs).has("parry") and s.fighters[0].pos.x > -200.0)
	s = _duel()
	s.fighters[1].burst = Sim.BURST_FULL
	s.apply({0: {"move": "jab"}, 1: {"move": "wait"}})
	s.run_segment()
	evs = _play(s, {0: {"move": "parry_early"}, 1: {"move": "burst"}})
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
			and not s.legal_moves(0).has("dash") and not s.legal_moves(0).has("guard"))
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
			and not s.legal_moves(0).has("guard") and not s.legal_moves(0).has("parry_early"))
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
