extends Node
## Actual normal-scene input playback; no alternate combat/movement animation.
const R = preload("res://scripts/reference_rules.gd")
const HUD = preload("res://scripts/survival_hud.gd")
var game
var clock := 0.0
var next_key := 1.0
var pending := ""
var need_space := false
var run_number := 0
var pause_started := -1.0
var pause_finished := false
var frozen_elapsed := 0.0
var frozen_timer := 0.0
var gameover_at := -1.0
var frozen_wpm := 0.0
var injected_mid_dash := false
var queue_observed := false
var queued_at_keys := 0
var queued_character := ""
var saw_space_required := false
var title_selected_easy := false
var resume_top_clicked := false
var failures: Array[String] = []
var captured: Dictionary = {}
var capture_metadata: Dictionary = {}
var finished := false
var actions: Array[Dictionary] = []
var audio_started_unix := 0.0

func _ready() -> void:
	game.state.save_path = output_path("render-test-save.ini")
	game.settings_path = output_path("render-test-settings.ini")
	game.set_grass_quality(1, false)
	game.set_audio_muted(false, false)
	game.set_audio_volume(0.6, false)
	audio_started_unix = Time.get_unix_time_from_system()
	game.sound.start_capture()
	game.state.rng.seed = 1764

func key(code: Key, unicode: int = 0, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.unicode = unicode
	event.shift_pressed = shift
	Input.parse_input_event(event)
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func letter(value: String) -> void:
	var unicode := value.unicode_at(0)
	var code: Key = KEY_NONE
	if unicode >= 97 and unicode <= 122:
		code = KEY_A + unicode - 97
	elif unicode >= 65 and unicode <= 90:
		code = KEY_A + unicode - 65
	key(code, unicode, value != value.to_lower())

func click(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	var release := event.duplicate()
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func output_path(name: String) -> String:
	var folder := OS.get_environment("CHI_ARTIFACT_DIR")
	if folder.is_empty():
		folder = "res://artifacts"
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)

func screenshot(name: String) -> void:
	if captured.has(name):
		return
	captured[name] = true
	# Input is injected in _process; let its CanvasItems redraw after the state change.
	await get_tree().process_frame
	game.queue_redraw()
	game.hud.queue_redraw()
	game.entities.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_path(name + ".png"))
	capture_metadata[name] = {"camera": [game.camera.position.x, game.camera.position.y], "phase": game.state.phase, "timer": game.state.timer, "prefix": game.state.buffer, "candidates": game.state.typing_feedback().candidates.size(), "selected_id": game.state.typing_feedback().selected_id}

func choose_orb(near_destination: bool = false) -> Dictionary:
	var s = game.state
	var best: Dictionary = {}
	var best_value := -INF
	for orb in s.orbs:
		if not s.selectable(orb) or orb.id == s.dash_orb_id:
			continue
		var distance: float = s.player.distance_to(orb.pos)
		if distance < 75:
			continue
		var value: float = distance * 0.2
		if not near_destination and not captured.has("06-shared-prefix") and s.matches(String(orb.word).left(1)).size() > 1:
			value += 10000
		if near_destination:
			if not s.viewport(Vector2(60, 60)).has_point(orb.pos):
				continue
			value = -Vector2(orb.pos).distance_to(s.dash_to)
		else:
			for enemy in s.enemies:
				if R.segment_distance(enemy.pos, s.player, orb.pos) < enemy.radius + 5.5:
					value += 300
		if value > best_value:
			best_value = value
			best = orb
	return best

func _process(delta: float) -> void:
	clock += delta
	if finished:
		return
	if clock > 68:
		failures.append("rendered play timed out")
		finish()
		return
	var s = game.state
	if s.phase == "title":
		screenshot("01-title")
		if clock > 0.8:
			click(HUD.difficulty_rect(0).get_center())
			title_selected_easy = s.difficulty == 0
			click(HUD.new_game_rect().get_center())
			run_number = 1
			next_key = clock + 0.6
		return
	if s.phase == "paused":
		screenshot("03-paused")
		if clock - pause_started >= 0.65:
			if s.elapsed != frozen_elapsed or s.timer != frozen_timer:
				failures.append("pause did not freeze state")
			click(HUD.resume_rect().position + Vector2(130, 1))
			resume_top_clicked = s.phase == "playing"
			pause_finished = true
			pending = ""
			need_space = false
			next_key = clock + 0.3
		return
	if s.phase == "gameover":
		screenshot("04-gameover" if run_number == 1 else "05-second-gameover")
		if gameover_at < 0:
			gameover_at = clock
			frozen_elapsed = s.elapsed
			frozen_wpm = s.wpm()
		if clock - gameover_at > 0.7:
			if s.elapsed != frozen_elapsed or s.wpm() != frozen_wpm:
				failures.append("statistics continued after gameover")
			if run_number == 1:
				if s.elapsed < 11.5:
					failures.append("first run ended before debug gameover checkpoint")
				key(KEY_R, 114)
				run_number = 2
				gameover_at = -1
				pending = ""
				need_space = false
				next_key = clock + 0.4
			else:
				key(KEY_ENTER)
				if s.phase != "playing" or s.total_keys != 0 or s.score != 0:
					failures.append("Enter did not reset after second gameover")
				finish()
		return
	if run_number == 1:
		screenshot("02-survival")
		var feedback: Dictionary = s.typing_feedback()
		if not s.buffer.is_empty():
			if feedback.candidates.size() > 1 and feedback.selected_id < 0 and not captured.has("06-shared-prefix"):
				screenshot("06-shared-prefix")
				next_key = clock + 0.16
				return
			var selected: Dictionary = s.find_orb(feedback.selected_id)
			if not selected.is_empty():
				if s.buffer == selected.word and not captured.has("08-completed-word"):
					screenshot("08-completed-word")
					next_key = clock + 0.16
					return
				if s.buffer != selected.word and not captured.has("07-unique-prefix"):
					screenshot("07-unique-prefix")
					next_key = clock + 0.16
					return
		if s.elapsed > 6 and not pause_finished and pause_started < 0:
			key(KEY_ESCAPE)
			pause_started = clock
			frozen_elapsed = s.elapsed
			frozen_timer = s.timer
			return
		if s.elapsed > 12:
			key(KEY_Q, 81, true)
			return
	elif s.elapsed > 5:
		# Let normal timer/contact rules end run2; no debug state mutation.
		return
	if s.dash_active:
		if not injected_mid_dash and run_number == 1:
			var next := choose_orb(true)
			if not next.is_empty():
				queued_character = String(next.word).left(1)
				queued_at_keys = s.total_keys
				letter(queued_character)
				pending = String(next.word).substr(1)
				need_space = false
				injected_mid_dash = true
				next_key = clock + 0.35
		elif injected_mid_dash and s.queued_text == queued_character and s.total_keys == queued_at_keys:
			queue_observed = true
		return
	if s.hit_stop > 0 or clock < next_key:
		return
	if need_space:
		var active: Dictionary = s.find_orb(s.active_id)
		if not active.is_empty() and active.word == s.buffer:
			saw_space_required = true
			key(KEY_SPACE, 32)
		else:
			while not s.buffer.is_empty():
				# Send one Backspace per physics tick, avoiding an artificial tight loop.
				key(KEY_BACKSPACE)
				next_key = clock + 0.05
				return
		need_space = false
		next_key = clock + 0.08
		return
	if pending.is_empty():
		var target := choose_orb()
		if target.is_empty():
			return
		pending = target.word
		actions.append({"time": clock, "run": run_number, "word": pending, "score": s.score, "timer": s.timer})
	letter(pending.left(1))
	pending = pending.substr(1)
	need_space = pending.is_empty()
	next_key = clock + 0.065

func finish() -> void:
	if finished:
		return
	finished = true
	if not title_selected_easy:
		failures.append("mouse difficulty selection not verified")
	if not saw_space_required:
		failures.append("completed word plus Space not verified")
	if not queue_observed:
		failures.append("mid-dash queued text not observed")
	if not resume_top_clicked:
		failures.append("top edge of shared resume hitbox failed")
	if game.tiles.size() != 3:
		failures.append("original grass tiles did not load")
	for required in ["06-shared-prefix", "07-unique-prefix", "08-completed-word"]:
		if not captured.has(required):
			failures.append("missing progressive feedback capture:" + required)
	var audio_bytes: int = game.sound.finish_capture(output_path("gameplay-audio.wav"))
	var file := FileAccess.open(output_path("render-playtest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"audio_started_unix": audio_started_unix, "video_started_unix": float(OS.get_environment("TYPE_VIDEO_STARTED_UNIX")), "audio_bytes": audio_bytes, "audio_events": game.sound.played_log, "grass_technique": "chunked MultiMeshInstance3D alpha-cutout cards in orthographic SubViewport", "passed": failures.is_empty(), "failures": failures, "runs": run_number, "mid_dash_queue_observed": queue_observed, "space_required": saw_space_required, "resume_top_edge_verified": resume_top_clicked, "grass_tiles_loaded": game.tiles.size(), "tile_verification": game.tile_verification, "captures": capture_metadata, "assets_status": game.assets_status, "seconds": clock, "actions": actions}, "  "))
	print("SURVIVAL RENDER: ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
