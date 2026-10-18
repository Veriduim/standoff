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
		if free.size() == s.alive().size():
			break
		var hold := {}
		for id in free:
			hold[id] = {"move": "wait", "x": 6.0}
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
	_check("a 10-frame wait (the others guarding for 20) stops the run after 10 ticks with only that fighter free (got %d ticks, %s)"
			% [seg["frames"].size(), s.deciders()], seg["frames"].size() == 10 and s.deciders() == [0])
	var fresh := Sim.create([{"character": "dancer"}, {"character": "dancer"}])
	_check("ground and air menus differ: a jump on the ground, a dive kick only in the air",
			fresh.legal_moves(1).has("jump") and not fresh.legal_moves(1).has("divekick"))
	fresh.fighters[1].pos.y = -100.0
	_check("...in the air: the dive kick, no jump", fresh.legal_moves(1).has("divekick")
			and not fresh.legal_moves(1).has("jump"))
	fresh.fighters[1].pos.y = 0.0
	_check("a super needs meter", not fresh.legal_moves(1).has("flurry"))
	fresh.fighters[1].meter = 60
	_check("...and with 60 it's there", fresh.legal_moves(1).has("flurry"))
	_check("someone mid-move has nothing to pick", s.legal_moves(1).is_empty())


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
	_check("a taunt gives 25 meter when it finishes (meter %d)" % t.fighters[0].meter, t.fighters[0].meter == 25)
	var kit := Moves.of("dancer")
	var tabs := {}
	for mid: String in kit:
		tabs[str(kit[mid].get("tab", "?"))] = int(tabs.get(str(kit[mid].get("tab", "?")), 0)) + 1
	_check("the Dancer has a full kit (%d moves: %s), every move in a tab and with an aim" % [kit.size(), tabs],
			kit.size() >= 28 and not tabs.has("?") and kit.values().all(func(m: Dictionary) -> bool: return m.has("aim")))


func _test_combos_and_ko() -> void:
	_section("Combos, knockouts and the winner")
	var s := _duel()
	s.apply({0: {"move": "jab"}, 1: {"move": "wait", "x": 40}})
	s.run_segment()
	var first := 450 - s.fighters[1].hp
	_check("the hitter gets free while the other still reels - a combo can follow (free: %s, stun %d)"
			% [s.deciders(), s.fighters[1].stun], s.deciders() == [0] and s.fighters[1].stun > 0)
	s.fighters[1].hp = 10
	s.fighters[0].pos.x = s.fighters[1].pos.x - 70.0
	_play(s, {0: {"move": "jab"}})
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
