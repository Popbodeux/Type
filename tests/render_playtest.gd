extends Node
## Keyboard-driven live gameplay. No alternate game state or staged animation.
## Run a real rendering backend with `godot --path . -- --playtest`.
var game
var clock := 0.0
var next_key := 1.5
var pending := ""
var screenshots: Dictionary = {}
var sent_intro := false
var won_at := -1.0
var finished := false
var route_log: Array[Dictionary] = []
var run_number := 1
var screenshot_busy := false
const Combat = preload("res://scripts/combat.gd")

func output_path(name: String) -> String:
	var folder := OS.get_environment("CHI_ARTIFACT_DIR")
	if folder.is_empty():
		folder = "res://artifacts"
	DirAccess.make_dir_recursive_absolute(folder)
	return folder.path_join(name)

func key(code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.unicode = unicode
	Input.parse_input_event(event)
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)

func screenshot(name: String) -> void:
	if screenshots.has(name) or screenshot_busy:
		return
	screenshots[name] = true
	screenshot_busy = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(output_path(name + ".png"))
	screenshot_busy = false

func choose_route() -> Dictionary:
	var enemy: Dictionary = game.enemies[0]
	# Deliberately demonstrate one blocked hit, then route around the armor.
	if game.strikes == 1 and game.blocks == 0:
		for orb in game.orbs:
			if Combat.classify(game.player, orb.pos, enemy.pos, enemy.weak) == "blocked":
				return orb
	for orb in game.orbs:
		if Combat.classify(game.player, orb.pos, enemy.pos, enemy.weak) == "hit":
			return orb
	var best: Dictionary = {}
	var score := -INF
	for orb in game.orbs:
		if Combat.classify(game.player, orb.pos, enemy.pos, enemy.weak) == "blocked":
			continue
		var direction: Vector2 = (orb.pos - enemy.pos).normalized()
		var value: float = direction.dot(enemy.weak)
		if value > score:
			score = value
			best = orb
	return best

func _process(delta: float) -> void:
	clock += delta
	if finished:
		return
	if clock > 65.0:
		finish(false, "Timed out without completing two keyboard-driven runs")
		return
	if not sent_intro:
		screenshot("01-title")
		if clock > 1.5:
			key(KEY_ENTER)
			sent_intro = true
			next_key = clock + 1.3
		return
	if game.phase == "lost":
		finish(false, "Lost during scripted keyboard play")
		return
	if game.phase == "won":
		if run_number == 1:
			screenshot("06-victory")
		if won_at < 0:
			won_at = clock
		if clock - won_at > 2.0:
			if run_number == 1:
				run_number = 2
				key(KEY_ENTER)
				pending = ""
				next_key = clock + 1.0
				won_at = -1.0
			else:
				finish(true, "Completed two full runs using Input.parse_input_event")
		return
	if clock > 2.0 and run_number == 1:
		screenshot("02-arena")
	if game.prefix.length() == 2 and game.wave == 1 and run_number == 1:
		screenshot("03-target-selection")
	if game.notice.begins_with("ARMORED") and run_number == 1:
		screenshot("04-blocked-hit")
	if game.wave == 2 and game.dash_left == 0.0 and game.notice_time < 2.3 and run_number == 1:
		screenshot("05-wave-two")
	if game.dash_left > 0 or game.wave_wait > 0 or clock < next_key:
		return
	if pending.is_empty():
		var route := choose_route()
		if route.is_empty():
			finish(false, "No available route")
			return
		pending = route.word
		route_log.append({"time": clock, "run": run_number, "wave": game.wave, "word": pending, "from": [game.player.x, game.player.y], "to": [route.pos.x, route.pos.y], "strikes": game.strikes, "blocks": game.blocks})
	var letter := pending.left(1)
	pending = pending.substr(1)
	key(KEY_A + letter.unicode_at(0) - 97, letter.unicode_at(0))
	next_key = clock + (0.15 if not pending.is_empty() else 0.85)

func finish(passed: bool, message: String) -> void:
	finished = true
	var file := FileAccess.open(output_path("render-playtest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "message": message, "runs": run_number, "strikes": game.strikes, "blocks": game.blocks, "health": game.health, "seconds": clock, "renderer": RenderingServer.get_video_adapter_name(), "route_log": route_log}, "  "))
	print("RENDER PLAYTEST: ", "PASS" if passed else "FAIL", " — ", message)
	get_tree().quit(0 if passed else 1)
