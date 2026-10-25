extends Node2D
const Model = preload("res://scripts/survival_state.gd")
const R = preload("res://scripts/reference_rules.gd")
const Hud = preload("res://scripts/survival_hud.gd")
const TILE_NAMES := ["env_grass_plain_00.png", "env_grass_plain_01.png", "env_grass_plain_04.png"]
const TILE_HASHES := ["d317fd92267a6d5fde8e135034caf3471e5532a292f44edae678af441bf0a941", "205f875be0ff4cc4b939a2c2fcf08f50537a384b9faa6ff93cfaff39c70e6982", "cef5788e5d35ec1c7895f9567a95993b6d89b6ec19f759a1ff7679a32b77a2ee"]
var state = Model.new()
var camera: Camera2D
var hud: Node2D
var font: Font
var tiles: Array[Texture2D] = []
var assets_status := "ORIGINAL GRASS ASSETS PENDING — SOURCE CHECKERBOARD FALLBACK"

func _ready() -> void:
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
	if OS.get_cmdline_user_args().has("--playtest"):
		var driver := Node.new()
		driver.set_script(load("res://tests/render_playtest.gd"))
		driver.game = self
		add_child(driver)

func load_tiles() -> void:
	tiles.clear()
	for i in TILE_NAMES.size():
		var path: String = "res://assets/env_tiles/" + TILE_NAMES[i]
		if not FileAccess.file_exists(path):
			return
		if FileAccess.get_sha256(path) != TILE_HASHES[i]:
			assets_status = "GRASS ASSET HASH MISMATCH — FALLBACK; VISUAL PARITY BLOCKED"
			return
		var image := Image.load_from_file(path)
		if image == null or image.get_size() != Vector2i(16, 16):
			assets_status = "GRASS ASSET DIMENSIONS INVALID — FALLBACK"
			return
		tiles.append(ImageTexture.create_from_image(image))
	if tiles.size() == 3:
		assets_status = "ORIGINAL GRASS TILES VERIFIED / ACTOR ART PLACEHOLDERS"

func _physics_process(_delta: float) -> void:
	state.tick()
	camera.position = state.camera_pos
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
	if state.phase != "playing":
		return
	if event.shift_pressed and event.keycode == KEY_Q:
		state.end_run()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_BACKSPACE:
		state.queue_backspace()
	elif event.keycode == KEY_SPACE:
		if not event.echo:
			state.queue_space()
	elif event.unicode >= 33:
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
		elif Hud.exit_rect("paused").has_point(pos):
			get_tree().quit()
	elif state.phase == "gameover" and Hud.exit_rect("gameover").has_point(pos):
		get_tree().quit()

func text(text_value: String, pos: Vector2, size: int, color: Color, center: bool = true) -> void:
	if center:
		pos.x -= font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("173622"))
	draw_string(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if font == null:
		return
	var view: Rect2 = state.viewport()
	for y in range(floori(view.position.y / 32) - 1, ceili(view.end.y / 32) + 1):
		for x in range(floori(view.position.x / 32) - 1, ceili(view.end.x / 32) + 1):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * 32, Vector2(32, 32))
			if tiles.size() == 3:
				draw_texture_rect(tiles[R.tile_index(cell)], rect, false, Color8(178, 236, 136))
			else:
				draw_rect(rect, Color8(78, 152, 88) if (x + y) % 2 == 0 else Color8(98, 176, 102))
	var active: Dictionary = state.find_orb(state.active_id)
	if not active.is_empty():
		draw_line(state.player, active.pos, Color(1, 0.85, 0.3, 0.55), 2, true)
	for trail in state.trails:
		draw_line(trail.from, trail.to, Color(0.7, 1, 1, float(trail.life) / 0.3 * 0.4), 5, true)
	for orb in state.orbs:
		if not view.grow(140).has_point(orb.pos):
			continue
		var pos: Vector2 = orb.pos
		var locked: bool = orb.id == state.active_id
		var color := Color("ffdf70") if locked else Color("9cffff")
		var bob := sin(state.elapsed * 2.0 + float(orb.id)) * 2.0
		draw_circle(pos + Vector2(0, 7), 8, Color(0, 0, 0, 0.15))
		draw_circle(pos + Vector2(0, bob), 10 if locked else 7, Color(color, 0.25))
		draw_circle(pos + Vector2(0, bob), 4, color)
		text(orb.word, pos + Vector2(0, 25), 16, color)
		if not state.buffer.is_empty() and String(orb.word).begins_with(state.buffer) and state.selectable(orb):
			text(state.buffer, pos + Vector2(0, 42), 12, Color.WHITE)
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
