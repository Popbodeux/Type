extends Node
## Fixed physics-tick stress route shared by v0.3 baseline and v0.4 grass modes.
var game
var tick_count := 0
var previous_us := 0
var frame_ms: Array[float] = []
var draw_ms: Array[float] = []
var model_ms: Array[float] = []
var calls: Array[float] = []
var catchup := 0
var route: Array[Vector2] = []
var commanded: Array[Vector2] = []
var output := "res://artifacts/performance/v0.4.0/fixed.json"
var quality := "off"
var finished := false
var started_us := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--grass="):
			quality = arg.trim_prefix("--grass=")
	if game.has_method("set_grass_quality"):
		game.set_grass_quality(["off", "low", "high"].find(quality), false)
	if game.has_method("set_audio_muted"):
		game.set_audio_muted(true, false)
	var s = game.state
	s.rng.seed = 1764
	s.difficulty = 2
	s.reset_run()
	s.save_path = "res://artifacts/performance/v0.4.0/unused-save.ini"
	for ignored in 300:
		if s.orbs.size() >= 180:
			break
		s.place_orb(s.viewport().grow(400).intersection(s.R.ORB_BOUNDS))
	for i in 16:
		var x := (i + 1) * 360 if i < 8 else (16 - i) * 360
		route.append(s.player + Vector2(x, 140 * sin(i * PI / 2.0)))
	started_us = Time.get_ticks_usec()
	previous_us = started_us

func _physics_process(_dt: float) -> void:
	if finished:
		return
	tick_count += 1
	var s = game.state
	s.timer = 30.0 # Profiling only, not a survival result.
	if tick_count % 60 == 0 and tick_count < 900:
		var destination: Vector2 = route[(tick_count / 60 - 1) % route.size()]
		# Synthetic fixed route, not keyboard correctness. Retain a real bank word/ID.
		var orb: Dictionary = s.orbs[0]
		orb.pos = destination
		s.orb_revision += 1
		s.buffer = orb.word
		s.active_id = orb.id
		if not s.confirm_word():
			push_error("Fixed stress dash could not start")
			get_tree().quit(1)
		commanded.append(destination)
	if tick_count >= 900:
		finish()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if tick_count >= 180 and not finished:
		frame_ms.append((now - previous_us) / 1000.0)
		draw_ms.append(game.last_draw_cpu_us / 1000.0)
		model_ms.append(game.last_tick_cpu_us / 1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if game.physics_since_frame > 1:
			catchup += 1
	game.physics_since_frame = 0
	previous_us = now
	if now - started_us > 90000000:
		push_error("Fixed profile exceeded90seconds")
		get_tree().quit(1)

func stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for v in values:
		total += v
	return {"mean": total / max(1, values.size()), "p95": values[int((values.size()-1)*0.95)] if not values.is_empty() else 0, "p99": values[int((values.size()-1)*0.99)] if not values.is_empty() else 0, "max": values[-1] if not values.is_empty() else 0}

func finish() -> void:
	finished = true
	var s = game.state
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes({"player": s.player, "orbs": s.orbs, "enemies": s.enemies, "rng": s.rng.state, "commands": commanded}))
	var result := {"quality": quality, "physics_ticks": tick_count, "commanded_dashes": commanded.size(), "commands": commanded, "state_fingerprint": hash.finish().hex_encode(), "frame_interval_ms": stats(frame_ms), "draw_submission_cpu_ms": stats(draw_ms), "model_cpu_ms": stats(model_ms), "draw_calls": stats(calls), "catchup_frames": catchup, "renderer": RenderingServer.get_video_adapter_name(), "audio_muted_for_profile": true, "synthetic_timer_refill": true, "samples": frame_ms.size()}
	if game.get("grass") != null:
		result["grass_visible_cards"] = game.grass.visible_instances
		result["grass_cached_chunks"] = game.grass.chunks.size()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("FIXED DENSE PROFILE ", quality, " ", result.frame_interval_ms, " fingerprint=", result.state_fingerprint)
	get_tree().quit()
