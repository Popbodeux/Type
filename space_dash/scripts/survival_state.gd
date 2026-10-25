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

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func viewport(inset: Vector2 = Vector2.ZERO) -> Rect2:
	return Rect2(camera_pos - R.VIEW * 0.5 + inset, R.VIEW - inset * 2.0)

func selectable(orb: Dictionary) -> bool:
	return viewport(Vector2(24, 24)).has_point(orb.pos)

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

func recompute_target(prefer_exact: bool = false) -> void:
	active_id = -1
	if buffer.is_empty():
		return
	var found := matches(buffer)
	if prefer_exact:
		for orb in found:
			if orb.word == buffer:
				active_id = orb.id
				return
	if found.size() == 1:
		active_id = found[0].id

func queue_character(character: String) -> void:
	if phase == "playing" and character.length() == 1 and character not in [" ", "\r", "\n"]:
		queued_text += character

func queue_backspace() -> void:
	if phase != "playing":
		return
	# GameMaker keyboard_string itself accumulates/edits while process_typing returns.
	# A dash-frame Backspace edits pending text, never a discarded-input shortcut.
	if not queued_text.is_empty():
		queued_text = queued_text.left(queued_text.length() - 1)
	elif not dash_active and hit_stop <= 0:
		backspaces += 1

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

func process_typing(confirm: bool) -> void:
	if dash_active:
		return
	for ignored in backspaces:
		buffer = buffer.left(maxi(0, buffer.length() - 1))
		recompute_target(false)
	backspaces = 0
	var text := queued_text
	queued_text = ""
	for character in text:
		accept_character(character)
	if confirm:
		confirm_word()

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
		dash_orb_id = -1
		if maintenance_enabled:
			maintain_orbs()

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
	space_pressed = false
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
	process_typing(confirm)
	step_dash()
	if maintenance_enabled:
		maintain_orbs()
	if enemy_updates_enabled:
		update_enemies()
		if maintenance_enabled:
			maintain_enemies()
	camera_pos = camera_pos.lerp(player, R.CAMERA_LERP)
	camera_pos = camera_pos.clamp(R.VIEW * 0.5, R.WORLD - R.VIEW * 0.5)

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
	enemies.clear()
	sparks.clear()
	trails.clear()
	seeded_cells.clear()
	next_orb_id = 0
	next_enemy_id = 0
	last_cell = Vector2i(-99999, -99999)
	if maintenance_enabled:
		maintain_orbs()
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
	var enemy := {"id": next_enemy_id, "kind": kind, "pos": pos, "hp": R.ENEMY_HP[kind], "speed": R.ENEMY_SPEED[kind], "radius": R.ENEMY_RADIUS[kind], "facing": (player - pos).angle(), "heading": rng.randf_range(0, TAU), "hurt": Vector2.ZERO}
	next_enemy_id += 1
	return enemy

func spawn_enemy(kind: int = -1) -> void:
	if kind < 0:
		# Kind distribution not supplied in inspection; uniform provisional choice.
		kind = rng.randi_range(0, 2)
	var angle := rng.randf_range(0, TAU)
	var radius := rng.randf_range(280, 620)
	var pos := player + Vector2(cos(angle) * radius, sin(angle) * radius * 0.72)
	enemies.append(make_enemy(kind, R.arena_clamp(pos)))

func update_enemies() -> void:
	for enemy in enemies:
		var offset: Vector2 = player - enemy.pos
		var distance := offset.length()
		enemy.facing = offset.angle()
		var speed: float = enemy.speed
		var chase: bool = enemy.kind == 2 or (enemy.kind == 0 and distance < 440) or (enemy.kind == 1 and distance < 340)
		var direction: float = enemy.facing
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
		enemy.pos = R.arena_clamp(enemy.pos)
		enemy.hurt = Vector2(enemy.hurt).move_toward(Vector2.ZERO, 1.8)
		if player.distance_to(enemy.pos) <= float(enemy.radius) + R.PLAYER_RADIUS:
			timer -= (5.0 if enemy.kind == 2 else 3.0) * R.DT
			combo = 0

func maintain_enemies() -> void:
	var target: int = R.ENEMY_TARGET[difficulty]
	while enemies.size() < target:
		spawn_enemy()
	# Expanded-view margin/cap require the original helper for exact parity.
	var nearby := 0
	for enemy in enemies:
		if viewport().grow(180).has_point(enemy.pos):
			nearby += 1
	if nearby < 3:
		for ignored in mini(2, target + 2 - enemies.size()):
			spawn_enemy()

func cell_for(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / R.CELL.x), floori(pos.y / R.CELL.y))

func word_available(word: String, region: Rect2) -> bool:
	for orb in orbs:
		if (region.has_point(orb.pos) or viewport().has_point(orb.pos)) and R.words_conflict(word, orb.word):
			return false
	return true

func place_orb(region: Rect2) -> bool:
	if orbs.size() >= R.ORB_MAX:
		return false
	var pos := Vector2.ZERO
	var found := false
	# Reference tiers are exact; attempt counts were absent from supplied excerpts.
	for spacing in [104.0, 68.0, 36.0]:
		for ignored in 16:
			pos = R.arena_clamp(Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y)))
			found = true
			for other in orbs:
				if pos.distance_to(other.pos) < spacing:
					found = false
					break
			if found:
				break
		if found:
			break
	if not found:
		pos = R.arena_clamp(Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y)))
	var pool := R.word_pool(difficulty)
	for ignored in pool.size() * 3:
		var word: String = pool[rng.randi_range(0, pool.size() - 1)]
		if word_available(word, region):
			var details := R.reward(word, player.distance_to(pos))
			orbs.append({"id": next_orb_id, "pos": pos, "word": word, "reward": details.reward, "tier": details.tier})
			next_orb_id += 1
			return true
	return false

func seed_surrounding() -> void:
	var cell := cell_for(player)
	if cell == last_cell:
		return
	last_cell = cell
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var key := Vector2i(x, y)
			if seeded_cells.has(key):
				continue
			seeded_cells[key] = true
			var region := Rect2(Vector2(key) * R.CELL, R.CELL)
			for ignored in 10:
				place_orb(region)

func maintain_orbs() -> void:
	orbs = orbs.filter(func(o: Dictionary) -> bool: return player.distance_to(o.pos) <= R.PRUNE_DISTANCE or o.id == dash_orb_id)
	seed_surrounding()
	var region := viewport(Vector2(56, 42))
	for ignored in 60:
		var count := 0
		for orb in orbs:
			if region.has_point(orb.pos):
				count += 1
		if count >= R.VIEW_TARGET or orbs.size() >= R.ORB_MAX:
			break
		place_orb(region)
	var near_region := Rect2(player - R.NEAR_RADII, R.NEAR_RADII * 2.0)
	for ignored in 40:
		var count := 0
		for orb in orbs:
			if ((Vector2(orb.pos) - player) / R.NEAR_RADII).length_squared() <= 1.0:
				count += 1
		if count >= R.NEAR_TARGET or orbs.size() >= R.ORB_MAX:
			break
		place_orb(near_region)
	for ignored in 60:
		if orbs.size() >= R.ORB_MIN:
			break
		place_orb(viewport().grow(800))
