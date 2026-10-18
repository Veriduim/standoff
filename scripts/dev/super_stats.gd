extends SceneTree
## Dev: supers a match with bots (2, 4, 6 fighters).   godot --headless --path . --script res://scripts/dev/super_stats.gd


func _init() -> void:
	for n in [2, 4, 6]:
		var supers := 0
		var ticks := 0
		for sd in 6:
			var players := []
			for i in n:
				players.append({"character": "dancer"})
			var s := Sim.create(players, "ffa")
			var bots := []
			for i in n:
				bots.append(Bot.new(sd * 31 + i))
			var t := 0
			while not s.over() and t < 4000:
				var picks := {}
				for id in s.deciders():
					picks[id] = (bots[id] as Bot).choose(s, id)
					if str(Moves.move("dancer", str(picks[id].get("move", ""))).get("kind", "")) == "super" \
							and s.fighters[id].actionable():
						supers += 1
				s.apply(picks)
				s.run_segment()
				t += 1
			ticks += s.tick
		print("%d fighters: %.1f supers a match (%.2f each), match %.0f s" % [n, supers / 6.0, supers / 6.0 / n,
				ticks / 6.0 / 60.0])
	quit()
