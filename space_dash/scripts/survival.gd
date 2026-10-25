extends Node2D
const Model = preload("res://scripts/survival_state.gd")
const R = preload("res://scripts/reference_rules.gd")
const Hud = preload("res://scripts/survival_hud.gd")
const TILE_NAMES := ["env_grass_plain_00.png", "env_grass_plain_01.png", "env_grass_plain_04.png"]
const TILE_HASHES := ["d317fd92267a6d5fde8e135034caf3471e5532a292f44edae678af441bf0a941", "205f875be0ff4cc4b939a2c2fcf08f50537a384b9faa6ff93cfaff39c70e6982", "cef5788e5d35ec1c7895f9567a95993b6d89b6ec19f759a1ff7679a32b77a2ee"]
const PIXEL_HASHES := ["8067d1ac4fedf542afce357b4222b61440ceee46435b4805b2a02bbb031ec640", "2cb39403921dad43781fca0bc48514d88d5b960ce24863459fc24eef407619c6", "4dc1d1ca9d0610fb9693144afc90822c24d4f903c28887f990f28462c6dd072a"]
var tile_verification: Array[Dictionary] = []
var state = Model.new()
var camera: Camera2D
var hud: Node2D
var font: Font
var tiles: Array[Texture2D] = []
var assets_status := "ORIGINAL GRASS ASSETS PENDING — SOURCE CHECKERBOARD FALLBACK"
var profiling_enabled := false
var last_tick_cpu_us := 0
var last_draw_cpu_us := 0
var physics_since_frame := 0
var ground_chunks: Dictionary = {}
var ground_chunk_order: Array[Vector2i] = []
var scaled_tiles: Array[Image] = []
var terrain_build_count := 0
var label_widths: Dictionary = {}
const CHUNK_TILES := 16
const CHUNK_SIZE := 512
const CHUNK_CACHE_LIMIT := 24
const NEUTRAL_WORD := Color("e0e5d5")
const TYPED_PREFIX := Color("ffe08a")

func _ready() -> void:
	profiling_enabled = OS.get_cmdline_user_args().has("--profile")
	if profiling_enabled:
		state = load("res://tests/profiled_state.gd").new(1764)
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_tiles()
	state.load_high_score()
	camera = Camera2D.new()
	camera.position = state.camera_pos
	camera.position_smoothing_enabled = false
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Node2D.new()
	hud.set_script(Hud)
	hud.game = self
	layer.add_child(hud)
	if profiling_enabled:
		var driver := Node.new()
		driver.set_script(load("res://tests/profile_render.gd"))
		driver.game = self
		add_child(driver)
	elif OS.get_cmdline_user_args().has("--playtest"):
		var driver := Node.new()
		driver.set_script(load("res://tests/render_playtest.gd"))
		driver.game = self
		add_child(driver)

func load_tiles() -> void:
	tiles.clear()
	tile_verification.clear()
	scaled_tiles.clear()
	ground_chunks.clear()
	ground_chunk_order.clear()
	for i in TILE_NAMES.size():
		var path: String = "res://assets/env_tiles/" + TILE_NAMES[i]
		var image: Image
		var file_verified := false
		if FileAccess.file_exists(path):
			if FileAccess.get_sha256(path) != TILE_HASHES[i]:
				assets_status = "GRASS ASSET HASH MISMATCH — FALLBACK"
				return
			file_verified = true
			image = Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
				assets_status = "GRASS PNG DECODE FAILED — FALLBACK"
				return
		elif ResourceLoader.exists(path):
			# Godot exports may remap PNGs to imported textures; verify decoded pixels.
			var texture := load(path) as Texture2D
			if texture:
				image = texture.get_image()
		else:
			return
		if image == null or image.get_size() != Vector2i(16, 16):
			assets_status = "GRASS ASSET DIMENSIONS INVALID — FALLBACK"
			return
		image.convert(Image.FORMAT_RGBA8)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(image.get_data())
		var pixel_hash := hashing.finish().hex_encode()
		if pixel_hash != PIXEL_HASHES[i]:
			assets_status = "GRASS PIXEL HASH MISMATCH — FALLBACK"
			return
		tiles.append(ImageTexture.create_from_image(image))
		tile_verification.append({"name": TILE_NAMES[i], "original_file_sha256": TILE_HASHES[i], "file_bytes_verified": file_verified, "pixel_sha256": pixel_hash, "width": 16, "height": 16, "verified": true})
	if tiles.size() == 3:
		assets_status = "ORIGINAL GRASS TILES VERIFIED / ACTOR ART PLACEHOLDERS"
		for tile in tiles:
			var scaled := tile.get_image()
			scaled.resize(32, 32, Image.INTERPOLATE_NEAREST)
			scaled_tiles.append(scaled)

func _physics_process(_delta: float) -> void:
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	state.tick()
	if profiling_enabled:
		last_tick_cpu_us = Time.get_ticks_usec() - started
		physics_since_frame += 1
	camera.position = state.camera_pos.round()
	queue_redraw()
	if is_instance_valid(hud):
		hud.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_click(event.position)
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE and not event.echo:
		state.toggle_pause()
		return
	if state.phase == "gameover":
		if event.keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER] and not event.echo:
			state.reset_run()
		return
	if state.phase not in ["playing", "paused"]:
		return
	if state.phase == "playing" and event.shift_pressed and event.keycode == KEY_Q:
		state.end_run()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_BACKSPACE:
		state.queue_backspace(not event.echo)
	elif event.keycode == KEY_SPACE:
		state.queue_character(" ")
		if not event.echo:
			state.queue_space()
	elif event.unicode >= 33 or event.unicode in [10, 13]:
		state.queue_character(String.chr(event.unicode))

func handle_click(pos: Vector2) -> void:
	if state.phase == "title":
		for i in 3:
			if Hud.difficulty_rect(i).has_point(pos):
				state.difficulty = i
		if Hud.new_game_rect().has_point(pos):
			state.reset_run()
		elif Hud.exit_rect("title").has_point(pos):
			get_tree().quit()
	elif state.phase == "paused":
		# Same shared rectangle for drawing and clicking: fixes original .50/.52 bug.
		if Hud.resume_rect().has_point(pos):
			state.toggle_pause()
			state.skip_resume_tick = true
		elif Hud.exit_rect("paused").has_point(pos):
			get_tree().quit()
	elif state.phase == "gameover" and Hud.exit_rect("gameover").has_point(pos):
		get_tree().quit()

func text(text_value: String, pos: Vector2, size: int, color: Color, center: bool = true) -> void:
	if center:
		pos.x -= text_width(text_value, size) * 0.5
	draw_string_outline(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("173622"))
	draw_string(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_width(value: String, size: int) -> float:
	var key := str(size) + "/" + value
	if not label_widths.has(key):
		label_widths[key] = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return label_widths[key]

func ground_chunk(key: Vector2i) -> Texture2D:
	if ground_chunks.has(key):
		ground_chunk_order.erase(key)
		ground_chunk_order.append(key)
		return ground_chunks[key]
	var image := Image.create(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	for y in CHUNK_TILES:
		for x in CHUNK_TILES:
			var cell := key * CHUNK_TILES + Vector2i(x, y)
			image.blit_rect(scaled_tiles[R.tile_index(cell)], Rect2i(0, 0, 32, 32), Vector2i(x * 32, y * 32))
	var texture := ImageTexture.create_from_image(image)
	if ground_chunk_order.size() >= CHUNK_CACHE_LIMIT:
		ground_chunks.erase(ground_chunk_order.pop_front())
	ground_chunks[key] = texture
	ground_chunk_order.append(key)
	terrain_build_count += 1
	return texture

func draw_ground(view: Rect2) -> void:
	if scaled_tiles.size() == 3:
		# Cache exact source pixels per512px chunk; tint once at draw, preserving NN.
		var area := view.grow(32)
		for y in range(floori(area.position.y / CHUNK_SIZE), ceili(area.end.y / CHUNK_SIZE)):
			for x in range(floori(area.position.x / CHUNK_SIZE), ceili(area.end.x / CHUNK_SIZE)):
				var key := Vector2i(x, y)
				draw_texture(ground_chunk(key), Vector2(key) * CHUNK_SIZE, Color8(178, 236, 136))
	else:
		for y in range(floori(view.position.y / 32) - 1, ceili(view.end.y / 32) + 1):
			for x in range(floori(view.position.x / 32) - 1, ceili(view.end.x / 32) + 1):
				draw_rect(Rect2(x * 32, y * 32, 32, 32), Color8(78, 152, 88) if (x + y) % 2 == 0 else Color8(98, 176, 102))

func _draw() -> void:
	if font == null:
		return
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	var view: Rect2 = state.viewport()
	draw_ground(view)
	var feedback: Dictionary = state.typing_feedback()
	var active: Dictionary = state.find_orb(feedback.selected_id)
	if not active.is_empty():
		draw_line(state.player, active.pos, Color(1, 0.85, 0.3, 0.20), 1, true)
	for trail in state.trails:
		draw_line(trail.from, trail.to, Color(0.7, 1, 1, float(trail.life) / 0.3 * 0.4), 5, true)
	for orb in state.orbs:
		if not view.grow(140).has_point(orb.pos):
			continue
		var pos: Vector2 = orb.pos
		var style: Dictionary = state.orb_feedback(orb, feedback)
		var color := Color("ffdf70") if orb.id == feedback.selected_id else Color("9cffff")
		var bob := sin(state.elapsed * 2.0 + float(orb.id)) * 2.0
		draw_circle(pos + Vector2(0, bob), 8 if style.lit else 7, Color(color, 0.14 if style.lit else 0.015))
		draw_circle(pos + Vector2(0, bob), 4, Color(color, style.body_alpha))
		var word_pos := pos + Vector2(-text_width(orb.word, 16) * 0.5, 25)
		text(orb.word, word_pos, 16, NEUTRAL_WORD, false)
		if style.prefix_length > 0:
			draw_string(font, word_pos, String(orb.word).left(style.prefix_length), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TYPED_PREFIX)
	for enemy in state.enemies:
		if not view.grow(100).has_point(enemy.pos):
			continue
		var pos: Vector2 = enemy.pos + enemy.hurt
		var radius: float = enemy.radius * 0.6
		var color: Color = [Color("dc7165"), Color("dfbd64"), Color("af7cad")][enemy.kind]
		draw_circle(pos + Vector2(0, 10), radius, Color(0, 0, 0, 0.18))
		if enemy.kind == 2:
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0)]), color)
		else:
			draw_circle(pos, radius, color)
		if enemy.kind == 1:
			draw_arc(pos, radius + 4, enemy.facing - 0.8, enemy.facing + 0.8, 16, Color("fff1ae"), 4, true)
		text(str(enemy.hp), pos + Vector2(0, 5), 13, Color("25352a"))
	for spark in state.sparks:
		draw_arc(spark.pos, 30 * (1 - float(spark.life) / 0.3), 0, TAU, 24, Color(spark.color, minf(1, spark.life / 0.2)), 2, true)
	var p: Vector2 = state.player
	draw_circle(p + Vector2(0, 10), 12, Color(0, 0, 0, 0.3))
	draw_circle(p, 11, Color("204f49"))
	draw_circle(p + Vector2(0, -2), 8, Color("f4f0d0"))
	draw_line(p + Vector2(-5, 4), p + Vector2(-12, 17), Color("71f5e3"), 4, true)
	if profiling_enabled:
		last_draw_cpu_us = Time.get_ticks_usec() - started
