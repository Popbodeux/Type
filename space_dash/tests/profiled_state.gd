extends "res://scripts/survival_state.gd"
## Non-additive nested CPU timings; used identically before/after optimization.
var timings: Dictionary = {}
var calls: Dictionary = {}

func note(name: String, started: int) -> void:
	if not timings.has(name):
		timings[name] = []
		calls[name] = 0
	timings[name].append(Time.get_ticks_usec() - started)
	calls[name] += 1

func tick() -> void:
	var started := Time.get_ticks_usec()
	super.tick()
	note("tick", started)

func reset_run() -> void:
	var started := Time.get_ticks_usec()
	super.reset_run()
	note("reset", started)

func seed_surrounding() -> bool:
	var started := Time.get_ticks_usec()
	var result := super.seed_surrounding()
	note("seed_cells", started)
	return result

func ensure_local_coverage() -> void:
	var started := Time.get_ticks_usec()
	super.ensure_local_coverage()
	note("coverage", started)

func eligible_words(region: Rect2) -> PackedStringArray:
	var started := Time.get_ticks_usec()
	var result := super.eligible_words(region)
	note("eligible_words", started)
	return result

func place_orb(region: Rect2) -> bool:
	var started := Time.get_ticks_usec()
	var result := super.place_orb(region)
	note("place_orb", started)
	return result

func update_enemies() -> void:
	var started := Time.get_ticks_usec()
	super.update_enemies()
	note("enemies", started)

func summary() -> Dictionary:
	var result := {}
	for name in timings:
		var values: Array = timings[name].duplicate()
		values.sort()
		var total := 0.0
		for value in values:
			total += float(value)
		result[name] = {"calls": values.size(), "total_ms": total / 1000.0, "mean_ms": total / values.size() / 1000.0, "p50_ms": values[int((values.size() - 1) * 0.5)] / 1000.0, "p95_ms": values[int((values.size() - 1) * 0.95)] / 1000.0, "p99_ms": values[int((values.size() - 1) * 0.99)] / 1000.0, "max_ms": values[-1] / 1000.0}
	return result
