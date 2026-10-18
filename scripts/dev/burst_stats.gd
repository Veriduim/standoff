extends SceneTree
## Dev: how often bots Burst - per match, per fighter, and the match time between them.
##   godot --headless --path . --script res://scripts/dev/burst_stats.gd


func _init() -> void:
	for n in [2, 4, 6]:
		var bursts := 0
		var ticks := 0
		var turns := 0
		var ready_ticks := 0
		var fighter_ticks := 0
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
				s.apply(picks)
				var seg := s.run_segment()
				for e: Dictionary in seg["events"]:
					if e["type"] == "burst":
						bursts += 1
				for f in s.fighters:
					if not f.ko:
						fighter_ticks += seg["frames"].size()
						if f.burst >= Sim.BURST_FULL:
							ready_ticks += seg["frames"].size()
				t += 1
			ticks += s.tick
			turns += t
		print("%d fighters: %.1f bursts a match (%.2f per fighter), match %.0f ticks (%.0f s), %.0f turns, gauge full %.0f%% of the time"
				% [n, bursts / 6.0, bursts / 6.0 / n, ticks / 6.0, ticks / 6.0 / 60.0, turns / 6.0,
				100.0 * ready_ticks / maxf(1.0, fighter_ticks)])
	quit()
