extends SceneTree
const Model = preload("res://scripts/survival_state.gd")
const R = preload("res://scripts/reference_rules.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func fixture():
	var s = Model.new(337)
	s.maintenance_enabled = false
	s.enemy_updates_enabled = false
	s.reset_run()
	s.enemies.clear()
	s.camera_pos = s.player
	return s

func orb(s, word: String, offset: Vector2) -> Dictionary:
	var result := {"id": s.next_orb_id, "word": word, "pos": s.player + offset, "reward": 1.0, "tier": 0}
	s.next_orb_id += 1
	s.orbs.append(result)
	s.orb_revision += 1
	return result

func type(s, value: String) -> void:
	for c in value:
		s.queue_character(c)
	s.tick()

func style(s, o: Dictionary) -> Dictionary:
	return s.orb_feedback(o, s.typing_feedback())

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s = fixture()
	var ash := orb(s, "ash", Vector2(180, 0))
	var amber := orb(s, "amber", Vector2(-180, 0))
	var beam := orb(s, "beam", Vector2(0, 180))
	for o in s.orbs:
		check(style(s, o).prefix_length == 0 and not style(s, o).lit and style(s, o).body_alpha == 0.5, "empty input: readable neutral word, visible half-opaque untouched body")
	type(s, "a")
	check(style(s, ash).prefix_length == 1 and style(s, amber).prefix_length == 1, "shared prefix highlights only one accepted character on both words")
	check(style(s, ash).lit and style(s, amber).lit and not style(s, beam).lit, "shared prefix lights matching candidate bodies only")
	type(s, "s")
	check(style(s, ash).prefix_length == 2 and style(s, ash).prefix_length < String(ash.word).length(), "unique prefix does not highlight untyped final character")
	check(style(s, ash).lit and not style(s, amber).lit and s.typing_feedback().selected_id == ash.id, "unique target alone stays lit")
	type(s, "z")
	check(s.buffer == "as" and style(s, ash).prefix_length == 2 and style(s, ash).lit, "rejected typo preserves accepted prefix and body activation")
	s.queue_backspace()
	s.tick()
	check(s.buffer == "a" and style(s, amber).lit and style(s, ash).prefix_length == 1, "Backspace restores shared candidates and shrinks text highlight")
	type(s, "sh")
	check(style(s, ash).prefix_length == 3 and style(s, ash).lit and not s.dash_active, "whole word highlights only after completion; still requires Space")
	s.queue_space()
	s.tick()
	for o in s.orbs:
		check(style(s, o).prefix_length == 0 and not style(s, o).lit, "dash clears text/body activation without touching other targets")
	s.reset_run()
	check(s.typing_feedback().prefix == "" and s.typing_feedback().candidates.is_empty(), "reset clears feedback state")
	s = fixture()
	ash = orb(s, "ash", Vector2(180, 0))
	amber = orb(s, "ash", Vector2(-180, 0))
	type(s, "ash")
	check(style(s, ash).lit and not style(s, amber).lit, "duplicate exact words light only the actual selected body")
	check(style(s, ash).prefix_length == 3 and style(s, amber).prefix_length == 3, "letter feedback remains independent from target-body selection")
	for kind in 3:
		s = fixture()
		var enemy: Dictionary = s.make_enemy(kind, s.player + Vector2(1200, 0))
		enemy.heading = 0.0
		s.enemies.append(enemy)
		var before: Vector2 = enemy.pos
		s.update_enemies()
		check(not enemy.aggro and enemy.pos.x > before.x, "every kind, including kind2, wanders away rather than pursuing from far away")
		s.player = enemy.pos + Vector2(139, 0)
		s.update_enemies()
		check(enemy.aggro, "approaching within 140 activates proximity aggro")
		for distance in [141, 139, 141, 165, 190]:
			s.player = enemy.pos + Vector2(distance, 0)
			s.update_enemies()
			check(enemy.aggro, "hysteresis prevents boundary flicker and retains chase through 190")
		s.player = enemy.pos + Vector2(191, 0)
		s.update_enemies()
		check(not enemy.aggro, "leaving 190 disengages to wandering")
		s.player = enemy.pos + Vector2(165, 0)
		s.update_enemies()
		check(not enemy.aggro, "disengaged enemy does not reacquire at 165")
		s.player = enemy.pos + Vector2(100, 0)
		s.update_enemies()
		check(enemy.aggro, "player passing nearby can reactivate aggro")
		s.player += Vector2(2000, 0)
		s.update_enemies()
		check(not enemy.aggro, "dash far away never causes whole-map pursuit")
	# Optimized eligibility must equal the original naive predicate, including
	# capitalization, full-prefix conflicts and duplicated bank-entry weighting.
	for difficulty in 3:
		s = fixture()
		s.difficulty = difficulty
		orb(s, "meadow", Vector2(100, 0))
		orb(s, "sun", Vector2(-200, 0))
		orb(s, "Ash", Vector2(700, 0))
		for shift in [Vector2.ZERO, Vector2(400, 0), Vector2(0, 400)]:
			var region: Rect2 = s.viewport()
			region.position += shift
			var expected := PackedStringArray()
			for word in R.word_pool(difficulty):
				if s.word_available(word, region):
					expected.append(word)
			check(s.eligible_words(region) == expected, "fast prefix-set eligibility equals naive source predicate")
			s.camera_pos += Vector2(17, 3)
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.NEUTRAL_WORD != game.TYPED_PREFIX, "typed glyph color is separate from neutral base labels")
	var key := Vector2i(14, 10)
	var first = game.ground_chunk(key)
	var built: int = game.terrain_build_count
	check(game.ground_chunk(key) == first and game.terrain_build_count == built, "stationary terrain cache reuses uploaded texture")
	for x in range(30):
		game.ground_chunk(Vector2i(x, 10))
	check(game.ground_chunks.size() <= 24 and game.ground_chunk_order.size() <= 24, "terrain cache is bounded rather than growing with whole-map travel")
	game.queue_free()
	var file := FileAccess.open("res://artifacts/playtest-fixes-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures, "aggro_enter": 140, "aggro_exit": 190}, "  "))
	print("PLAYTEST FIX CHECKS: %d PASSED: %d FAILED: %d" % [checks, checks - failures.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
