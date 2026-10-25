extends Node2D
const Model = preload("res://scripts/survival_state.gd")
const R = preload("res://scripts/reference_rules.gd")
const Hud = preload("res://scripts/survival_hud.gd")
const Sound = preload("res://scripts/sound_effects.gd")
const Grass = preload("res://scripts/grass_layer.gd")
const Entities = preload("res://scripts/entity_layer.gd")
var sound
var grass
var entities
var settings_path := "user://playtest_settings.ini"
var grass_quality := 1
var last_ground_cpu_us := 0
const WORD_SIZE := 18
const TILE_NAMES := ["env_grass_plain_00.png", "env_grass_plain_01.png", "env_grass_plain_04.png"]
const TILE_HASHES := ["d317fd92267a6d5fde8e135034caf3471e5532a292f44edae678af441bf0a941", "205f875be0ff4cc4b939a2c2fcf08f50537a384b9faa6ff93cfaff39c70e6982", "cef5788e5d35ec1c7895f9567a95993b6d89b6ec19f759a1ff7679a32b77a2ee"]
var state = Model.new()
var camera: Camera2D
var hud: Node2D
var font: Font
const GROUND_COLOR := Color("567842")
const GROUND_TECHNIQUE := "single solid-color CanvasItem rectangle"
var profiling_enabled := false
var last_tick_cpu_us := 0
var last_draw_cpu_us := 0
var physics_since_frame := 0
var label_widths: Dictionary = {}
const NEUTRAL_WORD := Color("e0e5d5")
const TYPED_PREFIX := Color("fff29b")

func _ready() -> void:
	profiling_enabled = OS.get_cmdline_user_args().has("--profile")
	if profiling_enabled:
		state = load("res://tests/profiled_state.gd").new(1764)
	font = ThemeDB.fallback_font
	prepare_plates()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	sound = Node.new()
	sound.set_script(Sound)
	add_child(sound)
	grass = Node2D.new()
	grass.set_script(Grass)
	grass.game = self
	add_child(grass)
	entities = Node2D.new()
	entities.set_script(Entities)
	entities.game = self
	entities.z_index = 1
	add_child(entities)
	load_settings()
	if profiling_enabled:
		var driver := Node.new()
		driver.set_script(load("res://tests/profile_visuals.gd" if OS.get_cmdline_user_args().has("--fixed-dense") else "res://tests/profile_render.gd"))
		driver.game = self
		add_child(driver)
	elif OS.get_cmdline_user_args().has("--playtest"):
		var driver := Node.new()
		driver.set_script(load("res://tests/render_playtest.gd"))
		driver.game = self
		add_child(driver)

func _physics_process(_delta: float) -> void:
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	state.tick()
	if sound:
		sound.consume(state.drain_audio_events())
	if profiling_enabled:
		last_tick_cpu_us = Time.get_ticks_usec() - started
		physics_since_frame += 1
	camera.position = state.camera_pos.round()
	queue_redraw()
	if entities:
		entities.queue_redraw()
	if is_instance_valid(hud):
		hud.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_click(event.position)
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_F10 and not event.echo:
		set_audio_muted(not sound.muted)
		return
	if event.keycode == KEY_F8 and not event.echo:
		set_grass_quality((grass_quality + 1) % 3)
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
	if state.phase in ["title", "paused", "gameover"]:
		if Hud.mute_rect().has_point(pos):
			set_audio_muted(not sound.muted)
			return
		if Hud.volume_rect().grow(6).has_point(pos):
			set_audio_volume((pos.x - Hud.volume_rect().position.x) / Hud.volume_rect().size.x)
			return
		for i in 3:
			if Hud.grass_rect(i).has_point(pos):
				set_grass_quality(i)
				return
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

func text(text_value: String, pos: Vector2, size: int, color: Color, center: bool = true, canvas: CanvasItem = null) -> void:
	if canvas == null:
		canvas = self
	if center:
		pos.x -= text_width(text_value, size) * 0.5
	canvas.draw_string_outline(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("173622"))
	canvas.draw_string(font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_width(value: String, size: int) -> float:
	var key := str(size) + "/" + value
	if not label_widths.has(key):
		label_widths[key] = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return label_widths[key]

func draw_ground(view: Rect2) -> void:
	# One untextured canvas primitive; no tile sampling, upload or chunk cache.
	draw_rect(view.grow(32), GROUND_COLOR)

func _draw() -> void:
	if font == null:
		return
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	var view: Rect2 = state.viewport()
	draw_ground(view)
	if profiling_enabled:
		last_ground_cpu_us = Time.get_ticks_usec() - started

func draw_entities(canvas: CanvasItem) -> void:
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	var view: Rect2 = state.viewport()
	var feedback: Dictionary = state.typing_feedback()
	var active: Dictionary = state.find_orb(feedback.selected_id)
	if not active.is_empty():
		canvas.draw_line(state.player, active.pos, Color(1, 0.85, 0.3, 0.20), 1, true)
	for trail in state.trails:
		canvas.draw_line(trail.from, trail.to, Color(0.7, 1, 1, float(trail.life) / 0.3 * 0.4), 5, true)
	for orb in state.orbs:
		if not view.grow(140).has_point(orb.pos):
			continue
		var pos: Vector2 = orb.pos
		var style: Dictionary = state.orb_feedback(orb, feedback)
		var color := Color("ffdf70") if orb.id == feedback.selected_id else Color("9cffff")
		var bob := sin(state.elapsed * 2.0 + float(orb.id)) * 2.0
		canvas.draw_circle(pos + Vector2(0, bob), 8 if style.lit else 7, Color(color, 0.24 if style.lit else 0.11))
		canvas.draw_circle(pos + Vector2(0, bob), 5, Color(color, style.body_alpha))
		var word_pos := word_origin(orb)
		canvas.draw_style_box(label_plate(style.matching), Rect2(word_pos + Vector2(-6, -18), Vector2(text_width(orb.word, WORD_SIZE) + 12, 26)))
		text(orb.word, word_pos, WORD_SIZE, NEUTRAL_WORD, false, canvas)
		if style.prefix_length > 0:
			canvas.draw_string(font, word_pos, String(orb.word).left(style.prefix_length), HORIZONTAL_ALIGNMENT_LEFT, -1, WORD_SIZE, TYPED_PREFIX)
	for enemy in state.enemies:
		if not view.grow(100).has_point(enemy.pos):
			continue
		var pos: Vector2 = enemy.pos + enemy.hurt
		var radius: float = enemy.radius * 0.6
		var color: Color = [Color("dc7165"), Color("dfbd64"), Color("af7cad")][enemy.kind]
		canvas.draw_circle(pos + Vector2(0, 10), radius, Color(0, 0, 0, 0.18))
		if enemy.kind == 2:
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0)]), color)
		else:
			canvas.draw_circle(pos, radius, color)
		if enemy.kind == 1:
			canvas.draw_arc(pos, radius + 4, enemy.facing - 0.8, enemy.facing + 0.8, 16, Color("fff1ae"), 4, true)
		text(str(enemy.hp), pos + Vector2(0, 5), 13, Color("25352a"), true, canvas)
	for spark in state.sparks:
		canvas.draw_arc(spark.pos, 30 * (1 - float(spark.life) / 0.3), 0, TAU, 24, Color(spark.color, minf(1, spark.life / 0.2)), 2, true)
	var p: Vector2 = state.player
	canvas.draw_circle(p + Vector2(0, 10), 12, Color(0, 0, 0, 0.3))
	canvas.draw_circle(p, 11, Color("204f49"))
	canvas.draw_circle(p + Vector2(0, -2), 8, Color("f4f0d0"))
	canvas.draw_line(p + Vector2(-5, 4), p + Vector2(-12, 17), Color("71f5e3"), 4, true)
	if profiling_enabled:
		last_draw_cpu_us = last_ground_cpu_us + Time.get_ticks_usec() - started + int(grass.last_cpu_us)

func label_plate(matching: bool) -> StyleBoxFlat:
	# Cached styles keep label geometry fixed as typing changes contrast.
	return matching_plate if matching else neutral_plate

func word_origin(orb: Dictionary) -> Vector2:
	return Vector2(orb.pos) + Vector2(-text_width(orb.word, WORD_SIZE) * 0.5, 25)

var matching_plate: StyleBoxFlat
var neutral_plate: StyleBoxFlat

func prepare_plates() -> void:
	neutral_plate = StyleBoxFlat.new()
	neutral_plate.bg_color = Color(0.025, 0.06, 0.035, 0.52)
	neutral_plate.set_corner_radius_all(4)
	matching_plate = StyleBoxFlat.new()
	matching_plate.bg_color = Color(0.02, 0.045, 0.025, 0.95)
	matching_plate.border_color = Color(0.9, 0.82, 0.45, 0.4)
	matching_plate.set_border_width_all(1)
	matching_plate.set_corner_radius_all(4)

func set_grass_quality(value: int, persist: bool = true) -> void:
	grass_quality = clampi(value, 0, 2)
	grass.set_quality(grass_quality)
	if persist:
		save_settings()

func set_audio_muted(value: bool, persist: bool = true) -> void:
	sound.set_muted(value)
	if persist:
		save_settings()

func set_audio_volume(value: float, persist: bool = true) -> void:
	sound.set_volume(value)
	if persist:
		save_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		grass_quality = clampi(int(config.get_value("graphics", "grass", 1)), 0, 2)
		sound.set_volume(float(config.get_value("audio", "volume", 0.6)))
		sound.set_muted(bool(config.get_value("audio", "muted", false)))
	grass.set_quality(grass_quality)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "grass", grass_quality)
	config.set_value("audio", "volume", sound.master_volume)
	config.set_value("audio", "muted", sound.muted)
	config.save(settings_path)
