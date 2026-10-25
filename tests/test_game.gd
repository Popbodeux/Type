extends SceneTree
const Game = preload("res://scripts/game.gd")
const Combat = preload("res://scripts/combat.gd")
var game
var checks := 0
var failures: Array[String] = []
var category := "startup"
var categories: Dictionary = {}

func check(condition: bool, description: String, group: String = "") -> void:
	checks += 1
	var bucket := category if group.is_empty() else group
	if not categories.has(bucket):
		categories[bucket] = {"checks": 0, "passed": 0, "failed": 0}
	categories[bucket].checks += 1
	categories[bucket].passed += 1 if condition else 0
	categories[bucket].failed += 0 if condition else 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func key(code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.unicode = unicode
	game._unhandled_key_input(event)

func type_word(word: String) -> void:
	for letter in word:
		game.accept_letter(letter)

func land() -> void:
	for i in 30:
		game.simulate(1.0 / 60)
	for orb in game.orbs:
		var screen: Vector2 = (Vector2(orb.pos) - game.camera_focus()) * game.camera.zoom + Vector2(640, 400)
		check(screen.x > 65 and screen.x < 1215 and screen.y > 165 and screen.y + 55 * game.camera.zoom.y < 660, "camera frames target label clear of HUD", "camera_label_framing")

func choose_route() -> Dictionary:
	var enemy: Dictionary = game.enemies[0]
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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(game.phase == "intro", "start screen gates play")
	key(KEY_ENTER)
	check(game.phase == "playing", "Enter begins")
	# Geometry: wide valid cone, armored opposite, inclusive edge, and misses.
	category = "combat_geometry"
	check(Combat.classify(Vector2(-200, 0), Vector2(200, 0), Vector2.ZERO, Vector2.LEFT) == "hit", "vulnerable crossing")
	check(Combat.classify(Vector2(200, 0), Vector2(-200, 0), Vector2.ZERO, Vector2.LEFT) == "blocked", "opposite crossing blocked")
	check(Combat.classify(Vector2(-200, 100), Vector2(200, 100), Vector2.ZERO, Vector2.LEFT) == "miss", "no hit outside radius")
	check(Combat.vulnerable(Vector2.from_angle(PI + deg_to_rad(47)) * 200, Vector2.ZERO, Vector2.LEFT), "inside 48 degree cone")
	check(not Combat.vulnerable(Vector2.from_angle(PI + deg_to_rad(49)) * 200, Vector2.ZERO, Vector2.LEFT), "outside 48 degree cone")
	category = "orb_layout_and_unique_words"
	for wave in range(1, 4):
		game.wave = wave
		game.setup_wave()
		check(game.orbs.size() >= 6 and game.orbs.size() <= 8, "bounded target count wave %d" % wave)
		var seen: Array[String] = []
		var initials := ""
		for orb in game.orbs:
			check(String(orb.word).length() == 3 and not orb.word in seen, "unique three letter word")
			check(not initials.contains(String(orb.word)[0]), "unique initial means deterministic selection")
			check(Game.ARENA.grow(-75).has_point(orb.pos), "orb inside arena")
			check(orb.pos.distance_to(game.enemies[0].pos) > 65, "orb outside enemy body")
			check(orb.pos.distance_to(game.player) >= 60, "orb outside player")
			seen.append(orb.word)
			initials += String(orb.word)[0]
			for other in game.orbs:
				if other.word != orb.word:
					check(orb.pos.distance_to(other.pos) >= 125, "labels are spaced")
	category = "typing_selection_and_correction"
	game.reset_run()
	var target: Dictionary = game.orbs[0].duplicate()
	var word: String = target.word
	key(KEY_A, word.to_upper().unicode_at(0))
	check(game.prefix == word[0], "uppercase Unicode selects target")
	check(game.selected_orb().word == word, "prefix selects exactly one target")
	game.accept_letter("z")
	check(game.prefix == word[0] and game.mistakes == 1, "wrong letter preserves prefix and increments mistakes")
	key(KEY_BACKSPACE)
	check(game.prefix.is_empty(), "Backspace clears first letter")
	key(KEY_BACKSPACE)
	check(game.prefix.is_empty(), "Backspace safe at empty")
	game.accept_letter(word[0])
	key(KEY_ESCAPE)
	check(game.prefix.is_empty(), "Escape cancels selection")
	check(not game.accept_letter(" "), "space is not an attack")
	category = "dash_motion_and_live_hit"
	var before: Vector2 = game.player
	var stable_word: String = game.orbs[1].word
	type_word(word)
	check(game.dash_left > 0 and game.dashes == 1, "complete word triggers dash")
	check(game.player == before, "dash starts without teleporting")
	check(not game.accept_letter("b"), "letters ignored during dash")
	game.simulate(0.08)
	check(game.player != before and game.player != target.pos, "dash interpolates movement")
	land()
	check(game.player.distance_to(target.pos) < 0.01, "dash lands at selected orb")
	check(game.strikes == 1 and game.enemies[0].hp == 1, "live collision delivers one strike per dash")
	check(game.orbs.any(func(o: Dictionary) -> bool: return o.word == stable_word), "surviving target labels stay stable")
	# Cross back through armor: no health loss and explicit blocked feedback.
	category = "live_blocked_hit"
	for orb in game.orbs:
		if Combat.classify(game.player, orb.pos, game.enemies[0].pos, game.enemies[0].weak) == "blocked":
			type_word(orb.word)
			break
	land()
	check(game.blocks == 1 and game.enemies[0].hp == 1, "live armored crossing deals no damage")
	check(game.notice.begins_with("ARMORED"), "blocked feedback is explicit")
	category = "pause_and_help"
	key(KEY_TAB)
	var frozen: float = game.elapsed
	game.simulate(2.0)
	check(game.elapsed == frozen and game.phase == "paused", "pause freezes simulation")
	key(KEY_TAB)
	key(KEY_F1)
	game.simulate(2.0)
	check(game.elapsed == frozen, "help freezes hazards")
	key(KEY_ESCAPE)
	check(not game.help_open, "Escape closes help")
	# Hazard, invulnerability, and loss are tested without replacing gameplay logic.
	category = "pulse_damage_loss_and_restart"
	game.player = game.enemies[0].pos
	game.enemies[0].timer = 4.79
	game.simulate(0.02)
	check(game.health == 2 and game.invulnerable > 0, "pulse damages grounded player")
	game.enemies[0].timer = 4.79
	game.simulate(0.02)
	check(game.health == 2, "damage cooldown prevents repeat damage")
	game.invulnerable = 0.0
	game.health = 1
	game.enemies[0].timer = 4.79
	game.simulate(0.02)
	check(game.phase == "lost", "zero vitality ends encounter")
	key(KEY_ENTER)
	check(game.health == 3 and game.phase == "playing" and game.strikes == 0, "Enter restarts after loss")
	# Complete the actual live loop three times, choosing words from current orbs.
	category = "repeated_full_encounters"
	for repetition in 3:
		game.reset_run()
		var moves := 0
		while game.phase == "playing" and moves < 60:
			if game.wave_wait > 0:
				game.simulate(1.01)
				continue
			var route := choose_route()
			check(not route.is_empty(), "a safe route exists in repeated play")
			if route.is_empty():
				break
			type_word(route.word)
			land()
			moves += 1
		check(game.phase == "won" and game.strikes == 6, "three waves completed run %d" % repetition)
		check(game.health == 3, "routing avoids pulse damage")
		key(KEY_ENTER)
		check(game.wave == 1 and game.elapsed == 0 and game.dashes == 0 and game.prefix == "", "victory restart clears all state")
	category = "manual_reset"
	game.accept_letter(String(game.orbs[0].word)[0])
	key(KEY_F5)
	check(game.prefix == "" and game.mistakes == 0 and game.health == 3 and game.wave == 1, "F5 clears active input and run counters")
	print("CHECKS: %d  PASSED: %d  FAILED: %d" % [checks, checks - failures.size(), failures.size()])
	var file := FileAccess.open("res://artifacts/test-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures, "categories": categories, "godot": Engine.get_version_info().string}, "  "))
	quit(0 if failures.is_empty() else 1)
