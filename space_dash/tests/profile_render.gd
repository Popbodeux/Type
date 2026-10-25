extends Node
## Normal rendering plus timed real-input repeat dashes. No FFmpeg contention.
var game
var started := 0
var previous := 0
var frames: Array[float] = []
var draw_cpu: Array[float] = []
var tick_cpu: Array[float] = []
var draw_calls: Array[float] = []
var catchup_frames := 0
var pending := ""
var confirm := false
var next_input := 0.0
var output := "res://artifacts/performance/render-baseline.json"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	game.state.difficulty = 1
	game.state.reset_run()
	game.state.save_path = "res://artifacts/performance/unused-render-save.ini"
	started = Time.get_ticks_usec()
	previous = started

func key(character: String, code: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = character.unicode_at(0) if not character.is_empty() else 0
	event.keycode = code
	Input.parse_input_event(event)
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - started) / 1000000.0
	var s = game.state
	s.timer = 30.0 # Timing workload, not a survival/correctness result.
	if elapsed > 3:
		frames.append((now - previous) / 1000.0)
		draw_cpu.append(game.last_draw_cpu_us / 1000.0)
		tick_cpu.append(game.last_tick_cpu_us / 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if game.physics_since_frame > 1:
			catchup_frames += 1
	game.physics_since_frame = 0
	previous = now
	if elapsed >= 18 or elapsed > 32:
		finish()
		return
	if s.dash_active or s.hit_stop > 0 or elapsed < next_input:
		return
	if confirm:
		key(" ", KEY_SPACE)
		confirm = false
		if not s.dash_active:
			while not s.buffer.is_empty():
				key("", KEY_BACKSPACE)
				next_input = elapsed + 0.05
				return
	elif not pending.is_empty():
		key(pending.left(1))
		pending = pending.substr(1)
		confirm = pending.is_empty()
	else:
		var best := -INF
		for orb in s.orbs:
			if s.selectable(orb):
				var score: float = (Vector2(orb.pos) - s.player).dot(Vector2.RIGHT)
				if score > best:
					best = score
					pending = orb.word
		if not s.buffer.is_empty():
			key("", KEY_BACKSPACE)
	next_input = elapsed + 0.05

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / values.size(), "p50": values[int((values.size() - 1) * 0.5)], "p95": values[int((values.size() - 1) * 0.95)], "p99": values[int((values.size() - 1) * 0.99)], "max": values[-1]}

func finish() -> void:
	var result := {"samples": frames.size(), "frame_interval_ms": stats(frames), "tick_cpu_ms": stats(tick_cpu), "draw_submission_cpu_ms": stats(draw_cpu), "draw_calls": stats(draw_calls), "catchup_frames": catchup_frames, "completed_dashes": game.state.completed_words, "seeded_cells": game.state.seeded_cells.size(), "terrain_chunks_built": game.terrain_build_count, "terrain_chunks_retained": game.ground_chunks.size(), "nested_model_cpu": game.state.summary(), "renderer": RenderingServer.get_video_adapter_name(), "ffmpeg_running": false, "timer_refilled_for_timing": true}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("RENDER PROFILE ", JSON.stringify({"frames": result.frame_interval_ms, "draw_cpu": result.draw_submission_cpu_ms, "model": result.tick_cpu_ms, "dashes": result.completed_dashes}))
	get_tree().quit()
