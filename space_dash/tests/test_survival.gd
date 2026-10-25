extends SceneTree
const R = preload("res://scripts/reference_rules.gd")
const Model = preload("res://scripts/survival_state.gd")
const HUD = preload("res://scripts/survival_hud.gd")
var checks := 0
var failures: Array[String] = []
var category := "reference_constants"
var categories: Dictionary = {}

func check(condition: bool, description: String) -> void:
	checks += 1
	if not categories.has(category):
		categories[category] = {"passed": 0, "failed": 0}
	categories[category]["passed" if condition else "failed"] += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func near(actual: float, expected: float, description: String, tolerance: float = 0.00001) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.8f, expected %.8f)" % [description, actual, expected])

func fixture():
	var s = Model.new(12345)
	s.maintenance_enabled = false
	s.enemy_updates_enabled = false
	s.save_path = "res://artifacts/survival-test-save.ini"
	s.reset_run()
	s.enemies.clear()
	s.camera_pos = s.player
	s.timer = 20.0
	return s

func orb(s, word: String = "ash", offset: Vector2 = Vector2(200, 0), reward: float = 0.9792) -> Dictionary:
	var o := {"id": s.next_orb_id, "word": word, "pos": s.player + offset, "reward": reward, "tier": 0}
	s.next_orb_id += 1
	s.orbs.append(o)
	return o

func write_word(s, word: String) -> void:
	for c in word:
		s.queue_character(c)
	s.tick()

func lock_word(s, o: Dictionary) -> void:
	s.buffer = o.word
	s.active_id = o.id

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Engine.physics_ticks_per_second == 60, "Godot physics configured at 60Hz")
	check(R.word_pool(0).size() == 48, "Easy pool has 48 source entries")
	check(R.word_pool(1).size() == 90, "Normal pool has 90 source entries")
	check(R.word_pool(2).size() == 208, "Hard pool has 208 source entries")
	check(R.word_pool(2).count("meadow") == 2 and R.word_pool(2).count("stream") == 2, "Hard preserves duplicate entries across pools")
	check(R.word_pool(1).has("Atlas") and R.word_pool(1).has("you're") and R.word_pool(1).has("co-op"), "capitalization apostrophes and hyphens preserved")
	check(R.WORLD == Vector2(16384, 10240) and R.ARENA_CENTER == Vector2(8192, 5324.8), "reference world and center")
	check(R.ARENA_RADII == Vector2(7480, 4120) and R.VIEW == Vector2(960, 540), "reference radii and viewport")
	near(R.reward("ash", 0).reward, 0.9792, "near orb reward")
	check(R.reward("ash", 1271.59).tier == 0 and R.reward("ash", 1271.6).tier == 1, "first distance tier strict boundary")
	check(R.reward("ash", 2842.39).tier == 1 and R.reward("ash", 2842.4).tier == 2, "second distance tier strict boundary")
	near(R.reward("ash", 4000).reward, 2.72, "distant reward full scale")
	check(R.words_conflict("Ash", "ash") and R.words_conflict("ash", "ashen") and R.words_conflict("ashen", "ash"), "case-insensitive whole-word prefix conflicts rejected")
	check(not R.words_conflict("amber", "anchor"), "shared initial prefix alone allowed")

	category = "selection_and_space_confirmation"
	var s = fixture()
	orb(s)
	orb(s, "amber", Vector2(-200, 0))
	s.queue_space()
	s.tick()
	check(not s.dash_active and s.total_keys == 0, "empty Space does nothing and is not a keystroke")
	write_word(s, "a")
	check(s.buffer == "a" and s.active_id == -1, "ambiguous prefix accepted without lock")
	write_word(s, "s")
	check(s.buffer == "as" and s.active_id == s.orbs[0].id, "unique prefix locks target")
	s.queue_space()
	s.tick()
	check(not s.dash_active and s.completed_words == 0, "incomplete Space does nothing")
	write_word(s, "h")
	check(s.buffer == "ash" and not s.dash_active and s.orbs.size() == 2, "completing word alone never dashes or collects")
	s.queue_space()
	s.tick()
	check(s.dash_active and s.completed_words == 1 and s.completed_characters == 3, "Space on completed word initiates dash and counts completion")
	check(s.total_keys == 3 and s.correct_keys == 3 and s.buffer == "", "Space excludes stats and clears accepted input")
	check(s.orbs.size() == 2, "target orb remains until arrival")
	s.queue_space()
	s.tick()
	check(s.completed_words == 1, "repeated Space during dash does nothing")
	s = fixture()
	orb(s, "Atlas")
	write_word(s, "atlas")
	check(s.total_keys == 5 and s.incorrect_keys == 5 and s.buffer == "", "matching is case-sensitive")
	write_word(s, "Atlas")
	check(s.buffer == "Atlas", "exact capitalized source word can be selected")
	s = fixture()
	orb(s, "don't")
	orb(s, "co-op", Vector2(-200, 0))
	write_word(s, "don't")
	check(s.buffer == "don't" and s.correct_keys == 5, "apostrophe is accepted and counted")
	s.buffer = ""
	s.active_id = -1
	write_word(s, "co-op")
	check(s.buffer == "co-op" and s.correct_keys == 10, "hyphen is accepted and counted")
	s = fixture()
	var inside := orb(s, "ash", Vector2(-455, 0))
	var outside := orb(s, "beam", Vector2(-457, 0))
	check(s.selectable(inside) and not s.selectable(outside), "24px viewport inset determines selectability")
	write_word(s, "b")
	check(s.buffer == "" and s.incorrect_keys == 1, "off-viewport orb prefix cannot be selected")

	category = "mistakes_and_backspace"
	s = fixture()
	orb(s)
	write_word(s, "as")
	s.combo = 5
	s.word_streak = 4
	var before: float = s.timer
	write_word(s, "z")
	near(s.timer, before - 0.75 - R.DT, "invalid character deducts .75 plus normal drain")
	check(s.buffer == "as" and s.total_keys == 3 and s.correct_keys == 2 and s.incorrect_keys == 1, "invalid character rejected without erasing accepted prefix")
	check(s.combo == 0 and s.word_streak == 0 and s.miss_flash == 0.18, "invalid character resets both streaks and flashes for .18 seconds")
	before = s.timer
	s.queue_backspace()
	s.tick()
	check(s.buffer == "a" and s.active_id >= 0, "Backspace deletes and recomputes unique match")
	check(s.total_keys == 3 and s.incorrect_keys == 1, "Backspace does not change accuracy counts")
	near(s.timer, before - R.DT, "Backspace has no time penalty")
	s.queue_backspace()
	s.tick()
	s.queue_backspace()
	s.tick()
	check(s.buffer == "" and s.active_id == -1, "empty Backspace remains safe and clears selection")
	var keys_before: int = s.total_keys
	for whitespace in [" ", "\r", "\n"]:
		s.queue_character(whitespace)
	s.tick()
	check(s.total_keys == keys_before, "spaces and newlines excluded from keystrokes")

	category = "dash_buffering_and_timing"
	s = fixture()
	var first := orb(s)
	orb(s, "beam", Vector2(150, -70))
	write_word(s, "ash")
	s.queue_space()
	s.tick()
	var origin: Vector2 = s.dash_from
	near(s.player.x - origin.x, 42.0979770, "200px dash first tick moves42.098px using .22-second cubic ease-out", 0.002)
	s.queue_character("b")
	s.queue_character("e")
	s.queue_character("a")
	s.queue_character("x")
	s.queue_backspace()
	s.queue_character("m")
	s.queue_space()
	var time_before: float = s.timer
	s.tick()
	check(s.queued_text == "beam" and s.total_keys == 3 and s.buffer == "", "mid-dash text retained without processing; Backspace edits queued text")
	near(s.timer, time_before - R.DT, "buffered text creates no mid-dash mistake penalty")
	var frames := 2
	while s.dash_active and frames < 30:
		s.tick()
		frames += 1
	check(frames == 14 and s.player == first.pos, "dash arrives after 14 fixed ticks, not distance-dependent")
	check(s.find_orb(first.id).is_empty() and s.orbs.size() == 1, "arrival collects exactly the selected orb")
	check(s.queued_text == "beam" and s.total_keys == 3, "arrival frame still leaves queued typing unprocessed")
	s.tick()
	check(s.buffer == "beam" and s.total_keys == 7 and not s.dash_active, "buffered word processes on following tick; mid-dash Space edge is not replayed")
	s.queue_space()
	s.tick()
	check(s.dash_active and s.completed_words == 2, "fresh Space confirms the buffered complete word")
	s = fixture()
	var far := orb(s, "ash", Vector2(400, 0), 10.0)
	s.timer = 29
	lock_word(s, far)
	s.confirm_word()
	for ignored in 14:
		s.tick()
	near(s.timer, 30.0, "arrival reward capped at30")
	s = fixture()
	orb(s)
	s.hit_stop = 0.075
	write_word(s, "ash")
	s.queue_space()
	s.tick()
	check(s.queued_text == "ash" and s.total_keys == 0, "hit-stop also retains keyboard text")
	for ignored in 6:
		s.tick()
	check(s.buffer == "ash" and not s.dash_active, "hit-stop Space edge is discarded while text is replayed")

	category = "combat_source_expression_and_order"
	check(R.directional_hit(0, PI), "opposite facing difference180 hits kind1")
	check(not R.directional_hit(0, 0), "same direction difference0 blocked")
	check(not R.directional_hit(0, PI / 2), "exact90 is blocked because expression is strict")
	check(R.directional_hit(0, PI / 2 + 0.001), "just beyond90 hits")
	check(not R.directional_hit(deg_to_rad(179), deg_to_rad(-179)), "angle wrapping preserves small absolute difference")
	s = fixture()
	var target := orb(s)
	s.timer = 10
	s.enemies.append(s.make_enemy(0, s.player + Vector2(100, 0)))
	lock_word(s, target)
	s.confirm_word()
	check(s.enemies.is_empty() and s.score == 14 and s.combo == 1, "one HP enemy dies immediately at dash initiation")
	check(s.player == s.dash_from, "damage resolves before movement")
	near(s.timer, 12.15, "hit .65 and kill1.5 both grant time")
	near(s.hit_stop, 0.075, "kill hit-stop .075")
	for ignored in 25:
		s.tick()
	check(s.score == 14 and s.combo == 1, "same dash never damages or scores twice")
	s = fixture()
	target = orb(s)
	s.timer = 10
	var armored: Dictionary = s.make_enemy(1, s.player + Vector2(100, 0))
	armored.facing = PI
	s.enemies.append(armored)
	var enemy_origin: Vector2 = armored.pos
	lock_word(s, target)
	s.confirm_word()
	check(armored.hp == 2 and s.combo == 1 and s.score == 0, "successful kind1 hit deals exactly1 HP without kill score")
	near(s.timer, 10.65, "surviving hit grants .65")
	check(armored.pos == enemy_origin + Vector2(18, 0) and armored.hurt == Vector2(16, 0), "source X push and visual offset applied")
	near(s.hit_stop, 0.045, "surviving hit-stop .045")
	s = fixture()
	target = orb(s)
	s.timer = 10
	s.combo = 8
	s.word_streak = 5
	armored = s.make_enemy(1, s.player + Vector2(100, 0))
	armored.facing = 0
	s.enemies.append(armored)
	lock_word(s, target)
	s.confirm_word()
	check(armored.hp == 3 and s.combo == 0 and s.word_streak == 6, "blocked hit preserves HP, resets combat combo only")
	near(s.timer, 8.9, "blocked hit deducts1.1")
	near(s.hit_stop, 0.03, "blocked hit-stop .03")
	s = fixture()
	target = orb(s)
	s.timer = 10
	for x in [50, 100, 150]:
		s.enemies.append(s.make_enemy(0, s.player + Vector2(x, 0)))
	lock_word(s, target)
	s.confirm_word()
	check(s.score == 84 and s.combo == 3 and s.enemies.is_empty(), "three kills score14+28+42 in a single segment")
	s = fixture()
	target = orb(s)
	s.enemies.append(s.make_enemy(0, s.player + Vector2(50, 0)))
	s.enemies.append(s.make_enemy(2, s.player + Vector2(150, 0)))
	lock_word(s, target)
	s.confirm_word()
	check(s.score == 28 and s.combo == 2 and s.enemies.size() == 1, "reverse-order surviving hit increments combo before earlier-index kill; forward order would score14")
	s = fixture()
	target = orb(s)
	s.enemies.append(s.make_enemy(0, s.player + Vector2(50, 0)))
	armored = s.make_enemy(1, s.player + Vector2(100, 0))
	armored.facing = 0
	s.enemies.append(armored)
	s.enemies.append(s.make_enemy(0, s.player + Vector2(150, 0)))
	lock_word(s, target)
	s.confirm_word()
	check(s.score == 28 and s.combo == 1 and s.enemies.size() == 1, "reverse index order applies middle block between two kills")
	near(R.segment_distance(Vector2(100, 33.5), Vector2.ZERO, Vector2(200, 0)), 33.5, "source hit threshold enemy radius28 plus5.5")
	s = fixture()
	target = orb(s)
	s.enemies.append(s.make_enemy(0, s.player + Vector2(100, 34)))
	lock_word(s, target)
	s.confirm_word()
	check(s.enemies.size() == 1 and s.score == 0, "segment outside radius plus5.5 misses")

	category = "enemy_rates_contact_and_hitstop"
	s = fixture()
	for kind in 3:
		s.enemies.append(s.make_enemy(kind, s.player))
	s.combo = 5
	s.dash_active = true
	var before_contact: float = s.timer
	s.update_enemies()
	near(s.timer, before_contact - 11.0 / 60.0, "overlapping kinds0/1/2 add3+3+5 seconds per second even during dash")
	check(s.combo == 0, "contact resets combat combo without cooldown")
	s = fixture()
	s.enemies.append(s.make_enemy(0, s.player - Vector2(200, 0)))
	var start: Vector2 = s.enemies[0].pos
	for ignored in 60:
		s.update_enemies()
	near(s.enemies[0].pos.x - start.x, 39.6, "kind0 chases .55*1.2 per60Hz frame", 0.04)
	s = fixture()
	s.enemies.append(s.make_enemy(1, s.player - Vector2(200, 0)))
	start = s.enemies[0].pos
	s.update_enemies()
	near(s.enemies[0].pos.x - start.x, 0.36 * 0.95, "kind1 chase multiplier .95", 0.001)
	s = fixture()
	s.enemies.append(s.make_enemy(2, s.player - Vector2(0, 200)))
	start = s.enemies[0].pos
	s.update_enemies()
	near(s.enemies[0].pos.y - start.y, 0.9 * 0.72, "chase Y multiplier .72", 0.001)
	s = fixture()
	s.enemies.append(s.make_enemy(0, s.player - Vector2(600, 0)))
	s.enemies[0].heading = 0.0
	start = s.enemies[0].pos
	s.update_enemies()
	check(s.enemies[0].pos.x - start.x > 0.54 and s.enemies[0].pos.x - start.x <= 0.551, "kind0 outside chase range wanders at base speed")
	check(absf(s.enemies[0].heading) <= deg_to_rad(3), "wander heading jitter bounded to3 degrees per frame")
	s = fixture()
	s.enemy_updates_enabled = true
	s.enemies.append(s.make_enemy(2, s.player - Vector2(100, 0)))
	s.hit_stop = 0.045
	s.queue_character("a")
	start = s.enemies[0].pos
	var before_stop: float = s.timer
	s.tick()
	check(s.enemies[0].pos == start and s.queued_text == "a", "hit-stop freezes enemies and input processing")
	near(s.timer, before_stop, "hit-stop freezes timer drain")
	near(s.elapsed, R.DT, "elapsed statistics continue through hit-stop")

	category = "population_and_reset"
	for difficulty in 3:
		s = Model.new(480 + difficulty)
		s.save_path = "res://artifacts/survival-test-save.ini"
		s.difficulty = difficulty
		s.reset_run()
		check(s.orbs.size() >= 42 and s.orbs.size() <= 180, "global orb42..180 bound difficulty%d" % difficulty)
		check(s.seeded_cells.size() == 9, "reset seeds surrounding3x3 cells")
		check(s.enemies.size() == 4 and s.enemies[0].kind == 0 and s.enemies[1].kind == 0 and s.enemies[2].kind == 1 and s.enemies[3].kind == 2, "reset enemy kinds exactly[0,0,1,2]")
		near(s.timer, 30, "difficulty does not alter starting timer")
		var in_view := 0
		var nearby := 0
		var region: Rect2 = s.viewport(Vector2(56, 42))
		for current in s.orbs:
			if region.has_point(current.pos):
				in_view += 1
			if ((Vector2(current.pos) - s.player) / R.NEAR_RADII).length_squared() <= 1:
				nearby += 1
			check(R.word_pool(difficulty).has(current.word), "spawned word belongs to selected pool")
			if region.has_point(current.pos):
				for other in s.orbs:
					if current.id != other.id and region.has_point(other.pos):
						check(not R.words_conflict(current.word, other.word), "visible words reject duplicate and whole-word prefix conflicts")
		check(in_view >= 18 and nearby >= 6, "coverage targets18 in inset view and6 in local ellipse")
		s.maintain_enemies()
		check(s.enemies.size() >= R.ENEMY_TARGET[difficulty] and s.enemies.size() <= R.ENEMY_TARGET[difficulty] + 2, "enemy maintenance difficulty target with bounded local supplement")
		var seeded_before: int = s.seeded_cells.size()
		s.seed_surrounding()
		check(s.seeded_cells.size() == seeded_before, "same cell is seeded only once")
		s.orbs.append({"id": 99999, "pos": s.player + Vector2(2200, 0), "word": "zzfar", "reward": 1, "tier": 1})
		s.maintain_orbs()
		check(s.find_orb(99999).is_empty(), "orbs beyond2112 pruned")
		var old_camera: Vector2 = s.camera_pos
		s.player += Vector2(100, 0)
		s.maintenance_enabled = false
		s.enemy_updates_enabled = false
		s.tick()
		check(s.camera_pos.distance_to(old_camera.lerp(s.player, 0.085)) < 0.01, "camera lerps .085 each fixed frame")
		s.camera_pos += Vector2(100, 0)
		old_camera = s.camera_pos
		s.score = 42
		s.queued_text = "pending"
		s.sparks.append({"life": 0.2})
		s.reset_run()
		check(s.camera_pos == old_camera, "reset does not snap camera")
		check(s.player == R.ARENA_CENTER + Vector2(0, 60) and s.timer == 30 and s.score == 0, "reset player center+60 timer and score")
		check(s.buffer == "" and s.queued_text == "" and s.total_keys == 0 and s.sparks.is_empty() and s.combo == 0, "reset clears input statistics sparks combo")

	category = "stats_pause_gameover_save"
	s = fixture()
	s.elapsed = 60.0
	s.total_keys = 100
	s.correct_keys = 75
	near(s.accuracy(), 0.75, "accuracy correct/total")
	near(s.gross_wpm(), 20, "gross WPM keystrokes per five-character minute")
	near(s.wpm(), 15, "display WPM gross times accuracy")
	s.combo = 3
	s.buffer = "ash"
	s.queued_text = "pending"
	s.toggle_pause()
	var frozen_elapsed: float = s.elapsed
	var frozen_timer: float = s.timer
	s.tick()
	check(s.phase == "paused" and s.buffer == "" and s.queued_text == "", "Escape pause clears typing")
	check(s.elapsed == frozen_elapsed and s.timer == frozen_timer, "pause freezes timer and stats")
	s.toggle_pause()
	check(s.phase == "playing", "Escape resumes")
	s.high_score = 999
	s.end_run()
	s.tick()
	check(s.elapsed == frozen_elapsed and s.timer == frozen_timer, "deliberate bug fix freezes statistics after gameover")
	check(HUD.resume_rect().position.y == 0.50 * 540, "resume draw and input share original drawn50-percent rectangle")
	s = fixture()
	s.timer = 0.001
	s.queue_character("a")
	s.tick()
	check(s.phase == "gameover" and s.total_keys == 0, "timer death check precedes typing")
	s = fixture()
	s.score = 84
	s.high_score = 0
	s.end_run()
	var loaded = Model.new(999)
	loaded.save_path = s.save_path
	loaded.load_high_score()
	check(loaded.high_score == 84, "high score persists INI run/high_score")
	DirAccess.remove_absolute(s.save_path)

	category = "terrain_hash_and_repeatability"
	check(R.tile_index(Vector2i(0, 0)) == 0, "mostly plain00 tile selection")
	var terrain_examples := {Vector2i(7, 0): 2, Vector2i(14, 0): 1, Vector2i(-7, 0): 2, Vector2i(-14, 0): 1, Vector2i(1, 0): 0, Vector2i(0, 1): 0, Vector2i(0, 9): 2, Vector2i(0, -9): 2}
	for cell in terrain_examples:
		check(R.tile_index(cell) == terrain_examples[cell], "precomputed source terrain example%s" % cell)
	var terrain_counts := [0, 0, 0]
	for x in 100:
		terrain_counts[R.tile_index(Vector2i(x, 0))] += 1
	check(terrain_counts == [86, 7, 7], "complete hash period is86percent plain and7percent each variant")
	var a = Model.new(1776)
	var b = Model.new(1776)
	a.reset_run()
	b.reset_run()
	check(a.orbs == b.orbs and a.enemies == b.enemies, "same seed reproduces world reset")
	for ignored in 120:
		a.tick()
		b.tick()
	check(a.enemies == b.enemies and a.orbs == b.orbs and a.timer == b.timer and a.camera_pos == b.camera_pos, "fixed60Hz deterministic replay")
	for repetition in 3:
		s = fixture()
		for ignored in 1810:
			s.tick()
		check(s.phase == "gameover" and s.elapsed < 30.1 and s.timer == 0, "idle30-second survival ends run%d" % repetition)
		s.reset_run()
		check(s.phase == "playing" and s.elapsed == 0 and s.timer == 30, "survival restarts cleanly run%d" % repetition)
	print("SURVIVAL CHECKS: %d PASSED: %d FAILED: %d" % [checks, checks - failures.size(), failures.size()])
	var file := FileAccess.open("res://artifacts/test-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures, "categories": categories, "reference": "inspected grass Space-to-dash snapshot", "grass_assets_materialized": false, "windows_exported": false}, "  "))
	quit(0 if failures.is_empty() else 1)
