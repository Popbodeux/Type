extends SceneTree
const Profile = preload("res://tests/profiled_state.gd")
const R = preload("res://scripts/reference_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := "res://artifacts/performance/model-baseline.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var results := {}
	for scenario in ["stationary", "repeat_dash", "dense_repeat_dash"]:
		var s = Profile.new(1764)
		s.difficulty = 2 if scenario == "dense_repeat_dash" else 1
		s.save_path = "res://artifacts/performance/unused-save.ini"
		s.reset_run()
		if scenario == "dense_repeat_dash":
			for ignored in 240:
				if s.orbs.size() >= 180:
					break
				s.place_orb(s.viewport().grow(400).intersection(R.ORB_BOUNDS))
		var initial_orbs: int = s.orbs.size()
		var pending := ""
		var confirm := false
		var frames := 180 if scenario == "stationary" else 720
		var crossing_ticks: Array[int] = []
		var previous_cell: Vector2i = s.cell_for(s.player)
		for frame in frames:
			# Timing workload only: prevent death so later cell crossings remain measured.
			s.timer = 30.0
			if scenario != "stationary" and not s.dash_active and s.hit_stop <= 0 and frame % 3 == 0:
				if confirm:
					s.queue_space()
					confirm = false
					if not s.buffer.is_empty() and not s.dash_active and s.find_orb(s.active_id).is_empty():
						s.buffer = ""
				elif not pending.is_empty():
					s.queue_character(pending.left(1))
					pending = pending.substr(1)
					confirm = pending.is_empty()
				else:
					var best := -INF
					for orb in s.orbs:
						if s.selectable(orb):
							var value: float = (Vector2(orb.pos) - s.player).dot(Vector2.RIGHT)
							if value > best:
								best = value
								pending = orb.word
					if not s.buffer.is_empty():
						s.buffer = ""
						s.active_id = -1
			var started := Time.get_ticks_usec()
			s.tick()
			var cell: Vector2i = s.cell_for(s.player)
			if cell != previous_cell:
				crossing_ticks.append(Time.get_ticks_usec() - started)
				previous_cell = cell
		results[scenario] = {"initial_orbs": initial_orbs, "final_orbs": s.orbs.size(), "simulated_ticks": frames, "completed_dashes": s.completed_words, "cell_crossings": crossing_ticks.size(), "cell_crossing_us": crossing_ticks, "timings": s.summary()}
		print(scenario, " dashes=", s.completed_words, " crossings=", crossing_ticks.size(), " ", s.summary().get("tick"))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "nested CPU timings; synthetic survival timer refill for sustained load", "scenarios": results}, "  "))
	quit()
