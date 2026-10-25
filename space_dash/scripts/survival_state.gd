extends RefCounted
## Fixed-60-Hz gameplay model. Rendering/input adapters never own game rules.
const R = preload("res://scripts/reference_rules.gd")
var rng := RandomNumberGenerator.new()
var phase := "title"
var difficulty := 1
var player := R.ARENA_CENTER + Vector2(0, 60)
var camera_pos := R.ARENA_CENTER
var timer := R.TIMER_MAX
var elapsed := 0.0
var score := 0
var high_score := 0
var save_path := "user://typergame_save.ini"
var total_keys := 0
var correct_keys := 0
var incorrect_keys := 0
var completed_words := 0
var completed_characters := 0
var word_streak := 0
var best_streak := 0
var combo := 0
var best_wpm := 0.0
var buffer := ""
var active_id := -1
var queued_text := ""
var backspaces := 0
var space_pressed := false
var dash_active := false
var dash_t := 0.0
var dash_from := Vector2.ZERO
var dash_to := Vector2.ZERO
var dash_orb_id := -1
var hit_stop := 0.0
var miss_flash := 0.0
var notice := ""
var notice_left := 0.0
var orbs: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var seeded_cells: Dictionary = {}
var next_orb_id := 0
var next_enemy_id := 0
var last_cell := Vector2i(-99999, -99999)
var maintenance_enabled := true
var enemy_updates_enabled := true
var skip_resume_tick := false
var last_spawn_failure := ""
const RESTOCK_BUDGET := 256 # Deliberate guard replacing legacy unbounded loops.
var orb_revision := 0
var eligible_cache_region := Rect2()
var eligible_cache_difficulty := -1
var eligible_cache_revision := -1
var eligible_cache_size := -1
var eligible_cache_words := PackedStringArray()
var eligible_set_cache: Dictionary = {}
var bank_entries_cache: Dictionary = {}
var spacing_grid: Dictionary = {}
var spacing_grid_revision := -1
var spacing_grid_size := -1
const SPACING_CELL := 104.0
const AGGRO_ENTER := 240.0
const AGGRO_EXIT := 340.0

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func viewport(inset: Vector2 = Vector2.ZERO) -> Rect2:
	return Rect2(camera_pos - R.VIEW * 0.5 + inset, R.VIEW - inset * 2.0)

func selectable(orb: Dictionary) -> bool:
	return R.contains_inclusive(viewport(Vector2(24, 24)), orb.pos)

func find_orb(id: int) -> Dictionary:
	for orb in orbs:
		if orb.id == id:
			return orb
	return {}

func matches(prefix: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for orb in orbs:
		if selectable(orb) and String(orb.word).begins_with(prefix):
			result.append(orb)
	return result

func typing_feedback() -> Dictionary:
	# One candidate pass per draw, not one full matching scan per orb.
	var feedback := {"prefix": buffer, "candidates": {}, "selected_id": -1}
	if buffer.is_empty():
		return feedback
	var found := matches(buffer)
	for orb in found:
		feedback.candidates[orb.id] = true
	if found.size() == 1:
		feedback.selected_id = found[0].id
	else:
		for orb in found:
			if orb.word == buffer:
				feedback.selected_id = orb.id
				break
	return feedback

func orb_feedback(orb: Dictionary, feedback: Dictionary) -> Dictionary:
	var matches_prefix: bool = feedback.candidates.has(orb.id)
	var lit: bool = matches_prefix and (feedback.selected_id < 0 or feedback.selected_id == orb.id)
	return {"prefix_length": buffer.length() if matches_prefix else 0, "lit": lit, "body_alpha": 0.95 if lit else 0.08}

func recompute_target(prefer_exact: bool = false) -> void:
	var previous := active_id
	active_id = -1
	if buffer.is_empty():
		return
	var found := matches(buffer)
	if prefer_exact:
		for orb in found:
			if orb.word == buffer:
				active_id = orb.id
				return
		for orb in found:
			if orb.id == previous:
				active_id = previous
				return
	if found.size() == 1:
		active_id = found[0].id

func queue_character(character: String) -> void:
	if phase in ["playing", "paused"] and character.length() == 1:
		queued_text += character

func queue_backspace(press_edge: bool = true) -> void:
	if phase not in ["playing", "paused"]:
		return
	# GameMaker keyboard_string itself accumulates/edits while process_typing returns.
	# A dash-frame Backspace edits pending text, never a discarded-input shortcut.
	if not queued_text.is_empty():
		queued_text = queued_text.left(queued_text.length() - 1)
	if press_edge:
		backspaces = 1 # keyboard_check_pressed is one edge, not a held-key loop.

func queue_space() -> void:
	if phase == "playing":
		space_pressed = true

func accept_character(character: String) -> bool:
	if phase != "playing" or dash_active or hit_stop > 0:
		return false
	if character in [" ", "\r", "\n"] or character.length() != 1:
		return false
	total_keys += 1
	var found := matches(buffer + character)
	if not found.is_empty():
		correct_keys += 1
		buffer += character
		recompute_target(true)
		return true
	incorrect_keys += 1
	timer -= R.MISTYPE_PENALTY
	combo = 0
	word_streak = 0
	miss_flash = 0.18
	notice = "MISS  -0.75s"
	notice_left = 0.6
	return false

func process_typing(confirm: bool, edit: int = 0) -> void:
	if dash_active:
		return
	var text := queued_text
	queued_text = ""
	for character in text:
		accept_character(character)
	if confirm:
		confirm_word()
	# Source drains keyboard_string before Space and Backspace edge handling.
	for ignored in edit:
		buffer = buffer.left(maxi(0, buffer.length() - 1))
		recompute_target(false)

func confirm_word() -> bool:
	if phase != "playing" or dash_active or hit_stop > 0:
		return false
	var orb := find_orb(active_id)
	if orb.is_empty() or orb.word != buffer:
		return false
	completed_words += 1
	completed_characters += buffer.length()
	word_streak += 1
	best_streak = maxi(best_streak, word_streak)
	dash_active = true
	dash_t = 0.0
	dash_from = player
	dash_to = orb.pos
	dash_orb_id = orb.id
	trails.append({"from": player, "to": dash_to, "life": 0.3})
	resolve_dash_damage()
	buffer = ""
	queued_text = ""
	backspaces = 0
	active_id = -1
	return true

func resolve_dash_damage() -> void:
	var direction := (dash_to - dash_from).angle()
	# Source iterates backwards; a block resets combo before earlier-index kills.
	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		if R.segment_distance(enemy.pos, dash_from, dash_to) > float(enemy.radius) + R.PLAYER_RADIUS * 0.55:
			continue
		if enemy.kind == 1 and not R.directional_hit(direction, enemy.facing):
			timer -= 1.1
			combo = 0
			hit_stop = maxf(hit_stop, 0.03)
			sparks.append({"pos": enemy.pos, "color": Color("ffcc62"), "life": 0.22})
			notice = "BLOCKED  -1.1s"
			notice_left = 0.6
			continue
		enemy.hp -= 1
		combo += 1
		add_time(0.65)
		enemy.pos += Vector2(cos(direction) * 18.0, sin(direction) * 12.0)
		enemy.hurt = Vector2(cos(direction) * 16.0, sin(direction) * 11.0)
		sparks.append({"pos": enemy.pos, "color": Color("fff1ae"), "life": 0.3})
		if enemy.hp <= 0:
			add_time(1.5)
			score += 14 * combo
			hit_stop = maxf(hit_stop, 0.075)
			enemies.remove_at(index)
		else:
			hit_stop = maxf(hit_stop, 0.045)

func add_time(seconds: float) -> void:
	timer = minf(R.TIMER_MAX, timer + seconds)

func step_dash() -> void:
	if not dash_active:
		return
	dash_t += R.DT / R.DASH_TIME
	player = R.dash_position(dash_from, dash_to, dash_t)
	if dash_t >= 1.0:
		player = dash_to
		dash_active = false
		var orb := find_orb(dash_orb_id)
		if not orb.is_empty():
			add_time(orb.reward)
			orbs.erase(orb)
			orb_revision += 1
		dash_orb_id = -1
		# Coverage is consolidated into the single maintenance pass in tick().

func accuracy() -> float:
	return float(correct_keys) / total_keys if total_keys > 0 else 1.0

func gross_wpm() -> float:
	return total_keys * 12.0 / elapsed if elapsed > 0 else 0.0

func wpm() -> float:
	return gross_wpm() * accuracy()

func toggle_pause() -> void:
	if phase == "playing":
		phase = "paused"
		buffer = ""
		active_id = -1
		queued_text = ""
		backspaces = 0
		space_pressed = false
	elif phase == "paused":
		phase = "playing"

func tick() -> void:
	var confirm := space_pressed
	var edit := backspaces
	space_pressed = false
	backspaces = 0
	if skip_resume_tick:
		skip_resume_tick = false
		return
	if phase != "playing":
		return
	# Deliberate fix: gameover is checked before stats; paused/gameover stats freeze.
	elapsed += R.DT
	miss_flash = maxf(0, miss_flash - R.DT)
	notice_left = maxf(0, notice_left - R.DT)
	for effect in sparks:
		effect.life -= R.DT
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s.life > 0)
	for trail in trails:
		trail.life -= R.DT
	trails = trails.filter(func(t: Dictionary) -> bool: return t.life > 0)
	if elapsed >= 1.5 and total_keys >= 5:
		best_wpm = maxf(best_wpm, wpm())
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - R.DT)
		return
	timer -= R.DT
	if timer <= 0:
		end_run()
		return
	process_typing(confirm, edit)
	step_dash()
	if maintenance_enabled:
		seed_surrounding()
		maintain_orbs()
	if enemy_updates_enabled:
		update_enemies()
		if maintenance_enabled:
			maintain_enemies()
	var camera_target := player.clamp(R.VIEW * 0.5, R.WORLD - R.VIEW * 0.5)
	camera_pos = camera_pos.lerp(camera_target, R.CAMERA_LERP)

func reset_run() -> void:
	phase = "playing"
	player = R.ARENA_CENTER + Vector2(0, 60)
	timer = R.TIMER_MAX
	elapsed = 0.0
	score = 0
	total_keys = 0
	correct_keys = 0
	incorrect_keys = 0
	completed_words = 0
	completed_characters = 0
	word_streak = 0
	best_streak = 0
	combo = 0
	best_wpm = 0.0
	buffer = ""
	active_id = -1
	queued_text = ""
	backspaces = 0
	space_pressed = false
	dash_active = false
	dash_t = 0.0
	dash_orb_id = -1
	hit_stop = 0.0
	miss_flash = 0.0
	notice = ""
	notice_left = 0.0
	orbs.clear()
	orb_revision += 1
	enemies.clear()
	sparks.clear()
	trails.clear()
	seeded_cells.clear()
	next_orb_id = 0
	next_enemy_id = 0
	last_cell = Vector2i(-99999, -99999)
	skip_resume_tick = false
	if maintenance_enabled:
		seed_surrounding()
		restock_minimum(Rect2(player - Vector2(1100, 850), Vector2(2200, 1700)).intersection(R.ORB_BOUNDS))
	for kind in [0, 0, 1, 2]:
		spawn_enemy(kind)
	# Source reset deliberately does not snap the camera to the player.

func end_run() -> void:
	if phase == "gameover":
		return
	phase = "gameover"
	timer = maxf(0, timer)
	queued_text = ""
	space_pressed = false
	if score > high_score:
		high_score = score
		var config := ConfigFile.new()
		config.set_value("run", "high_score", high_score)
		config.save(save_path)

func load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		high_score = maxi(0, int(config.get_value("run", "high_score", 0)))

func make_enemy(kind: int, pos: Vector2) -> Dictionary:
	var heading := rng.randf_range(0, TAU)
	var enemy := {"id": next_enemy_id, "kind": kind, "pos": pos, "hp": R.ENEMY_HP[kind], "speed": R.ENEMY_SPEED[kind], "radius": R.ENEMY_RADIUS[kind], "facing": heading, "heading": heading, "aggro": false, "hurt": Vector2.ZERO}
	next_enemy_id += 1
	return enemy

func spawn_enemy(kind: int = -1) -> void:
	if kind < 0:
		kind = rng.randi_range(0, 2)
	var angle := rng.randf_range(0, TAU)
	var radius := rng.randi_range(280, 620)
	var pos := player + Vector2(cos(angle) * radius, sin(angle) * radius * 0.72)
	enemies.append(make_enemy(kind, R.arena_clamp(pos)))

func update_enemies() -> void:
	for enemy in enemies:
		var offset: Vector2 = player - enemy.pos
		var distance := offset.length()
		var speed: float = enemy.speed
		var chase: bool = enemy.get("aggro", false)
		if chase and distance > AGGRO_EXIT:
			chase = false
		elif not chase and distance <= AGGRO_ENTER:
			chase = true
		enemy.aggro = chase
		var direction: float = offset.angle()
		if chase:
			if enemy.kind == 0:
				speed *= 1.2
			elif enemy.kind == 1:
				speed *= 0.95
			enemy.pos += Vector2(cos(direction) * speed, sin(direction) * speed * 0.72)
		else:
			enemy.heading += deg_to_rad(rng.randf_range(-3, 3))
			direction = enemy.heading
			enemy.pos += Vector2(cos(direction) * speed, sin(direction) * speed * 0.55)
		enemy.facing = direction
		enemy.pos = R.arena_clamp(enemy.pos, 35)
		enemy.hurt = Vector2(enemy.hurt).lerp(Vector2.ZERO, 0.22)
		if player.distance_to(enemy.pos) <= float(enemy.radius) + R.PLAYER_RADIUS:
			timer -= (5.0 if enemy.kind == 2 else 3.0) * R.DT
			combo = 0

func maintain_enemies() -> void:
	var target: int = R.ENEMY_TARGET[difficulty]
	var nearby := 0
	for enemy in enemies:
		if R.contains_inclusive(viewport().grow(40), enemy.pos):
			nearby += 1
	while enemies.size() < target:
		spawn_enemy()
	# Source counter is measured before filling and blindly increments on supplement.
	while nearby < 3 and enemies.size() < target + 2:
		spawn_enemy()
		nearby += 1

func cell_for(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / R.CELL.x), floori(pos.y / R.CELL.y))

func word_available(word: String, region: Rect2) -> bool:
	var conflict_region := region.merge(viewport())
	for orb in orbs:
		if R.contains_inclusive(conflict_region, orb.pos) and R.words_conflict(word, orb.word):
			return false
	return true

func eligible_words(region: Rect2) -> PackedStringArray:
	var bounds := region.merge(viewport())
	if bounds == eligible_cache_region and difficulty == eligible_cache_difficulty and orb_revision == eligible_cache_revision and orbs.size() == eligible_cache_size:
		return eligible_cache_words
	# Cache by relevant WORD SET, not fractional camera coordinates. Build prefix
	# dictionaries once so pool eligibility is O(pool*word_length), not pool*orbs.
	var blocked := {}
	for orb in orbs:
		if R.contains_inclusive(bounds, orb.pos):
			blocked[String(orb.word).to_lower()] = true
	var names := PackedStringArray(blocked.keys())
	names.sort()
	var signature := str(difficulty) + ":" + "|".join(names)
	var result := PackedStringArray()
	if eligible_set_cache.has(signature):
		result = eligible_set_cache[signature]
	else:
		var prefixes := {}
		for word in names:
			for length in range(1, word.length() + 1):
				prefixes[word.left(length)] = true
		if not bank_entries_cache.has(difficulty):
			var entries: Array[Dictionary] = []
			for word in R.word_pool(difficulty):
				var lower := word.to_lower()
				var word_prefixes := PackedStringArray()
				for length in range(1, lower.length() + 1):
					word_prefixes.append(lower.left(length))
				entries.append({"word": word, "lower": lower, "prefixes": word_prefixes})
			bank_entries_cache[difficulty] = entries
		for entry in bank_entries_cache[difficulty]:
			var conflict: bool = prefixes.has(entry.lower)
			if not conflict:
				for prefix in entry.prefixes:
					if blocked.has(prefix):
						conflict = true
						break
			if not conflict:
				result.append(entry.word) # Duplicate bank entries retain weighting.
		if eligible_set_cache.size() >= 64:
			eligible_set_cache.clear()
		eligible_set_cache[signature] = result
	eligible_cache_region = bounds
	eligible_cache_difficulty = difficulty
	eligible_cache_revision = orb_revision
	eligible_cache_size = orbs.size()
	eligible_cache_words = result
	return result

func place_orb(region: Rect2) -> bool:
	last_spawn_failure = ""
	if orbs.size() >= R.ORB_MAX:
		last_spawn_failure = "maximum"
		return false
	if region.size.x <= 0 or region.size.y <= 0:
		last_spawn_failure = "empty_region"
		return false
	var pool := eligible_words(region)
	if pool.is_empty():
		last_spawn_failure = "no_eligible_word"
		return false # No positional sampling can fix an exhausted word set.
	if spacing_grid_revision != orb_revision or spacing_grid_size != orbs.size():
		spacing_grid.clear()
		for other in orbs:
			var cell := Vector2i(floori(other.pos.x / SPACING_CELL), floori(other.pos.y / SPACING_CELL))
			if not spacing_grid.has(cell):
				spacing_grid[cell] = []
			spacing_grid[cell].append(other.pos)
		spacing_grid_revision = orb_revision
		spacing_grid_size = orbs.size()
	# Keep the source's two overwritten initial X/Y draws (RNG algorithm differs).
	var pos := Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y))
	var found := false
	var spacings := [104.0, 68.0, 36.0]
	var attempts := [96, 64, 64]
	for phase_index in 3:
		var spacing: float = spacings[phase_index]
		for ignored in attempts[phase_index]:
			pos = Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y))
			found = true
			var cell := Vector2i(floori(pos.x / SPACING_CELL), floori(pos.y / SPACING_CELL))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var neighbor := cell + Vector2i(dx, dy)
					if not spacing_grid.has(neighbor):
						continue
					for other in spacing_grid[neighbor]:
						if pos.distance_squared_to(other) < spacing * spacing:
							found = false
							break
					if not found:
						break
				if not found:
					break
			if found:
				break
		if found:
			break
	if not found:
		pos = Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y))
	var word: String = pool[rng.randi_range(0, pool.size() - 1)]
	var details := R.reward(word, player.distance_to(pos))
	orbs.append({"id": next_orb_id, "pos": pos, "word": word, "reward": details.reward, "tier": details.tier})
	orb_revision += 1
	next_orb_id += 1
	return true

func seed_surrounding() -> bool:
	var cell := cell_for(player)
	if cell == last_cell:
		return false
	last_cell = cell
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var key := Vector2i(clampi(x, 0, ceili(R.WORLD.x / R.CELL.x) - 1), clampi(y, 0, ceili(R.WORLD.y / R.CELL.y) - 1))
			if seeded_cells.has(key):
				continue
			seeded_cells[key] = true
			var cell_region := Rect2(Vector2(key) * R.CELL, R.CELL)
			var region := cell_region.grow(-24).intersection(R.ORB_BOUNDS)
			if region.size.x <= 30:
				var retry := cell_region.grow_individual(-12, -24, -12, -24).intersection(R.ORB_BOUNDS)
				region.position.x = retry.position.x
				region.size.x = retry.size.x
			if region.size.y <= 30:
				var retry := cell_region.grow_individual(-24, -12, -24, -12).intersection(R.ORB_BOUNDS)
				region.position.y = retry.position.y
				region.size.y = retry.size.y
			var placed := 0
			for ignored in 220:
				if placed >= 10 or orbs.size() >= R.ORB_MAX or region.size.x <= 0 or region.size.y <= 0:
					break
				if place_orb(region):
					placed += 1
				elif last_spawn_failure == "no_eligible_word":
					break
	return true

func restock_minimum(region: Rect2) -> int:
	var calls := 0
	while orbs.size() < R.ORB_MIN and calls < RESTOCK_BUDGET:
		calls += 1
		if not place_orb(region) and last_spawn_failure in ["no_eligible_word", "empty_region", "maximum"]:
			# No state can improve inside this loop: avoid the original infinite retry.
			break
	return calls

func maintain_orbs() -> void:
	restock_minimum(R.ORB_BOUNDS)
	ensure_local_coverage()

func ensure_local_coverage() -> void:
	var old_size := orbs.size()
	orbs = orbs.filter(func(o: Dictionary) -> bool: return player.distance_to(o.pos) <= R.PRUNE_DISTANCE)
	if orbs.size() != old_size:
		orb_revision += 1
	if active_id >= 0 and find_orb(active_id).is_empty():
		active_id = -1 # Stable identity: pruning must not silently retarget another orb.
	var near_region := Rect2(player - R.NEAR_RADII, R.NEAR_RADII * 2.0).intersection(R.ORB_BOUNDS)
	var near_count := 0
	for orb in orbs:
		if ((Vector2(orb.pos) - player) / R.NEAR_RADII).length_squared() <= 1.0:
			near_count += 1
	for ignored in 32:
		if near_count >= R.NEAR_TARGET or orbs.size() >= R.ORB_MAX:
			break
		if place_orb(near_region):
			if ((Vector2(orbs[-1].pos) - player) / R.NEAR_RADII).length_squared() <= 1.0:
				near_count += 1
		elif last_spawn_failure == "no_eligible_word":
			break
	var region := viewport(Vector2(56, 42)).intersection(R.ORB_BOUNDS)
	var visible_count := 0
	for orb in orbs:
		if R.contains_inclusive(region, orb.pos):
			visible_count += 1
	for ignored in 80:
		if visible_count >= R.VIEW_TARGET or orbs.size() >= R.ORB_MAX:
			break
		if place_orb(region):
			visible_count += 1
		elif last_spawn_failure == "no_eligible_word":
			break
