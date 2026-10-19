extends SceneTree
## Dev: one bot level against another, 1v1 - who wins, and how long a pick of the first takes.
##   godot --headless --path . -s scripts/dev/bot_duel.gd [-- matches [level level]]   (0 Easy, 1 Normal, 2 Hard)

func _init() -> void:
	var n := 6
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		n = int(args[0])
	var la := int(args[1]) if args.size() > 2 else 2
	var lb := int(args[2]) if args.size() > 2 else 0
	var wins := 0
	var draws := 0
	var think_us := 0
	var thinks := 0
	for m in n:
		var smart_side := m % 2
		var s := Sim.create([{"name": "A", "character": "dancer", "team": 0}, {"name": "B", "character": "dancer", "team": 1}], "ffa")
		var bots := [Bot.new(m * 13 + 1, la if smart_side == 0 else lb), Bot.new(m * 13 + 2, la if smart_side == 1 else lb)]
		var guard := 0
		while not s.over() and guard < 2000:
			guard += 1
			var picks := {}
			for id in s.deciders():
				var t0 := Time.get_ticks_usec()
				picks[id] = (bots[id] as Bot).choose(s, id)
				if id == smart_side:
					think_us += Time.get_ticks_usec() - t0
					thinks += 1
			s.apply(picks)
			s.run_segment()
		var w := s.winners()
		if w.size() == 1 and int(w[0]) == smart_side:
			wins += 1
		elif w.size() != 1:
			draws += 1
		print("match %d: thinking bot was %d, winners %s, hp %d / %d, tick %d" % [m, smart_side, w, s.fighters[0].hp, s.fighters[1].hp, s.tick])
	print("%s won %d of %d against %s (%d draws); its pick took %.1f ms on average" % [Bot.LEVELS[la], wins, n,
			Bot.LEVELS[lb], draws, think_us / 1000.0 / maxf(1.0, thinks)])
	quit()
