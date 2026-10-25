extends Node2D
## All movement and combat run here; HUD is a separate screen-space canvas.
const Combat = preload("res://scripts/combat.gd")
const Hud = preload("res://scripts/hud.gd")
const ARENA := Rect2(120, 120, 1440, 1000)
const WORDS := ["ash", "bay", "cup", "dew", "elm", "fox", "gem", "hue", "ink", "jet", "key", "lot", "map", "net", "oak", "pea", "ray", "sun", "tea", "urn", "vat", "wax", "yam", "zip"]
const TEAL := Color("72f1ce")
const GOLD := Color("efb66d")
const RED := Color("ff7d86")
const INK := Color("10232d")
const WHITE := Color("e4eee8")
const DASH_TIME := 0.30
const MAX_ORBS := 8

var player := Vector2(480, 620)
var orbs: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var phase := "intro"
var prefix := ""
var wave := 1
var health := 3
var strikes := 0
var blocks := 0
var mistakes := 0
var dashes := 0
var elapsed := 0.0
var invulnerable := 0.0
var dash_left := 0.0
var dash_from := Vector2.ZERO
var dash_to := Vector2.ZERO
var dash_hits: Array[int] = []
var wave_wait := 0.0
var word_cursor := 0
var notice := ""
var notice_time := 0.0
var notice_color := TEAL
var help_open := false
var camera: Camera2D
var font: Font
var hud: Node2D

func _ready() -> void:
	font = ThemeDB.fallback_font
	camera = Camera2D.new()
	camera.position = player
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(0.78, 0.78)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Node2D.new()
	hud.set_script(Hud)
	hud.game = self
	layer.add_child(hud)
	reset_run(false)
	if OS.get_cmdline_user_args().has("--playtest"):
		var driver := Node.new()
		driver.set_script(load("res://tests/render_playtest.gd"))
		driver.game = self
		add_child(driver)

func reset_run(start: bool = true) -> void:
	phase = "playing" if start else "intro"
	prefix = ""
	wave = 1
	health = 3
	strikes = 0
	blocks = 0
	mistakes = 0
	dashes = 0
	elapsed = 0.0
	invulnerable = 0.0
	dash_left = 0.0
	wave_wait = 0.0
	word_cursor = 0
	trails.clear()
	effects.clear()
	notice = ""
	notice_time = 0.0
	help_open = false
	player = Vector2(480, 620)
	setup_wave()
	camera.position = camera_focus()
	camera.reset_smoothing()
	queue_redraw()

func setup_wave() -> void:
	prefix = ""
	enemies.clear()
	orbs.clear()
	var center := Vector2(850, 620)
	var weak := Vector2.LEFT
	if wave == 2:
		center = Vector2(1000, 490)
		weak = Vector2.DOWN
	elif wave == 3:
		center = Vector2(700, 670)
		weak = Vector2.RIGHT
	enemies.append({"pos": center, "weak": weak, "hp": 2, "timer": 0.0, "flash": 0.0, "blocked": 0.0})
	spawn_orbs()
	camera.position = camera_focus()
	camera.reset_smoothing()
	announce("WAVE %02d  /  APPROACH FROM THE MINT SIDE" % wave, TEAL, 3.0)

func camera_focus() -> Vector2:
	# Follow the player with encounter look-ahead so every target label stays visible.
	return Vector2(enemies[0].pos).lerp(player, 0.18) if not enemies.is_empty() else player

func spawn_orbs(preserve: bool = false) -> void:
	if enemies.is_empty():
		return
	var center: Vector2 = enemies[0].pos
	# Opposite pairs give both a safe setup point and a line through the sentinel.
	var offsets := [Vector2(230, 0), Vector2(-230, 0), Vector2(0, -230), Vector2(0, 230), Vector2(280, -220), Vector2(-280, -220), Vector2(280, 220), Vector2(-280, 220)]
	if not preserve:
		orbs.clear()
	var used_initials := ""
	for existing in orbs:
		used_initials += String(existing.word)[0]
	for offset in offsets:
		if orbs.size() >= MAX_ORBS:
			break
		var pos: Vector2 = center + offset
		if not ARENA.grow(-75).has_point(pos) or pos.distance_to(player) < 60.0:
			continue
		var safe := true
		for other in orbs:
			if pos.distance_to(other.pos) < 125.0:
				safe = false
		if not safe:
			continue
		var word := next_word(used_initials)
		used_initials += word[0]
		orbs.append({"pos": pos, "word": word})
		if orbs.size() == MAX_ORBS:
			break

func next_word(used_initials: String) -> String:
	for ignored in WORDS.size():
		var word: String = WORDS[word_cursor % WORDS.size()]
		word_cursor += 1
		if not used_initials.contains(word[0]):
			return word
	return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_F5:
		reset_run()
	elif event.keycode == KEY_F1:
		help_open = not help_open
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if phase in ["intro", "won", "lost"]:
			reset_run()
	elif event.keycode == KEY_TAB:
		if phase == "playing":
			phase = "paused"
		elif phase == "paused":
			phase = "playing"
	elif event.keycode == KEY_ESCAPE:
		prefix = ""
		help_open = false
	elif event.keycode == KEY_BACKSPACE:
		prefix = prefix.left(maxi(0, prefix.length() - 1))
	elif event.unicode >= 65 and event.unicode <= 122:
		accept_letter(String.chr(event.unicode).to_lower())
	queue_redraw()

func accept_letter(letter: String) -> bool:
	if phase != "playing" or dash_left > 0.0 or wave_wait > 0.0 or help_open:
		return false
	if letter.length() != 1 or letter < "a" or letter > "z":
		return false
	var attempt := prefix + letter
	for orb in orbs:
		if String(orb.word).begins_with(attempt):
			prefix = attempt
			if prefix == orb.word:
				begin_dash(orb.pos)
				orbs.erase(orb)
				prefix = ""
			return true
	mistakes += 1
	announce("NO MATCH  /  PREFIX KEPT — BACKSPACE TO CORRECT", RED, 1.4)
	return false

func begin_dash(destination: Vector2) -> void:
	dash_from = player
	dash_to = destination
	dash_left = DASH_TIME
	dash_hits.clear()
	dashes += 1
	trails.append({"from": player, "to": destination, "life": 0.65})

func _physics_process(delta: float) -> void:
	simulate(delta)

func simulate(delta: float) -> void:
	if phase != "playing" or help_open:
		return
	elapsed += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	notice_time = maxf(0.0, notice_time - delta)
	for trail in trails:
		trail.life -= delta
	trails = trails.filter(func(t: Dictionary) -> bool: return t.life > 0)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life > 0)
	if wave_wait > 0.0:
		wave_wait -= delta
		if wave_wait <= 0.0:
			if wave == 3:
				phase = "won"
			else:
				wave += 1
				setup_wave()
		return
	if dash_left > 0.0:
		var previous := player
		dash_left = maxf(0.0, dash_left - delta)
		var progress := 1.0 - dash_left / DASH_TIME
		player = dash_from.lerp(dash_to, 1.0 - pow(1.0 - progress, 2.0))
		for i in enemies.size():
			var enemy: Dictionary = enemies[i]
			if enemy.hp <= 0 or i in dash_hits:
				continue
			if Combat.segment_distance(enemy.pos, previous, player) <= 48.0:
				dash_hits.append(i)
				if Combat.vulnerable(dash_from, enemy.pos, enemy.weak):
					enemy.hp -= 1
					enemy.flash = 0.5
					strikes += 1
					announce("CLEAN STRIKE  /  %d OF 2" % (2 - int(enemy.hp)), TEAL, 1.8)
					effects.append({"pos": enemy.pos, "life": 0.5, "color": TEAL})
				else:
					blocks += 1
					enemy.blocked = 0.5
					announce("ARMORED SIDE  /  ROUTE TO THE MINT ARC", GOLD, 2.2)
					effects.append({"pos": enemy.pos, "life": 0.5, "color": GOLD})
		if dash_left == 0.0:
			# Refresh a consumed route only on landing; labels stay stable during flight.
			spawn_orbs(true)
			if enemies.all(func(e: Dictionary) -> bool: return e.hp <= 0):
				wave_wait = 1.0
				orbs.clear()
				announce("SENTINEL RELEASED", TEAL, 1.0)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		enemy.flash = maxf(0.0, enemy.flash - delta)
		enemy.blocked = maxf(0.0, enemy.blocked - delta)
		enemy.timer += delta
		if enemy.timer >= 4.8:
			enemy.timer = 0.0
			effects.append({"pos": enemy.pos, "life": 0.5, "color": RED})
			if dash_left <= 0.0 and player.distance_to(enemy.pos) < 285.0 and invulnerable <= 0.0:
				health -= 1
				invulnerable = 1.2
				announce("PULSE HIT  /  DASH OUT OF THE RED RING", RED, 2.0)
				if health <= 0:
					phase = "lost"
	camera.position = camera_focus()
	queue_redraw()

func announce(message: String, color: Color, duration: float) -> void:
	notice = message
	notice_color = color
	notice_time = duration

func selected_orb() -> Dictionary:
	if prefix.is_empty():
		return {}
	for orb in orbs:
		if String(orb.word).begins_with(prefix):
			return orb
	return {}

func _process(_delta: float) -> void:
	queue_redraw()
	if is_instance_valid(hud):
		hud.queue_redraw()

func text_at(text: String, pos: Vector2, size: int, color: Color, centered: bool = false) -> void:
	var origin := pos
	if centered:
		origin.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if font == null:
		return
	draw_rect(ARENA.grow(1000), Color("09141d"))
	draw_style_box(floor_style(), ARENA)
	for x in range(160, 1560, 80):
		draw_line(Vector2(x, 140), Vector2(x, 1100), Color(0.20, 0.34, 0.37, 0.13), 1.0)
	for y in range(160, 1120, 80):
		draw_line(Vector2(140, y), Vector2(1540, y), Color(0.20, 0.34, 0.37, 0.13), 1.0)
	for radius in [320, 450, 580]:
		draw_arc(Vector2(840, 620), radius, 0, TAU, 100, Color(0.25, 0.43, 0.42, 0.10), 2.0, true)
	for corner in [Vector2(150, 150), Vector2(1530, 150), Vector2(150, 1090), Vector2(1530, 1090)]:
		draw_circle(corner, 7, Color("42635e"))
	text_at("C H I   /   P R A C T I C E   G R O U N D", Vector2(840, 220), 17, Color("48665f"), true)
	for trail in trails:
		var opacity: float = clampf(trail.life / 0.65, 0, 1)
		draw_line(trail.from, trail.to, Color(TEAL, opacity * 0.10), 22, true)
		draw_line(trail.from, trail.to, Color(TEAL, opacity * 0.6), 3, true)
	var selected := selected_orb()
	if not selected.is_empty():
		draw_line(player, selected.pos, Color(TEAL, 0.20), 2, true)
	for enemy in enemies:
		draw_enemy(enemy)
	for orb in orbs:
		draw_orb(orb)
	for effect in effects:
		var life: float = effect.life / 0.5
		draw_arc(effect.pos, lerpf(95, 28, life), 0, TAU, 48, Color(effect.color, life), 3, true)
	draw_player()

func floor_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10232b")
	style.border_color = Color("36534f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	return style

func draw_orb(orb: Dictionary) -> void:
	var p: Vector2 = orb.pos
	var active: bool = prefix.is_empty() or String(orb.word).begins_with(prefix)
	var chosen: bool = not prefix.is_empty() and active
	var tint := TEAL if active else Color("527271")
	var bob := sin(elapsed * 2.0 + p.x) * 3.0
	draw_circle(p + Vector2(0, 15), 19, Color(0, 0, 0, 0.18))
	draw_circle(p + Vector2(0, bob), 23, Color(tint, 0.07))
	draw_arc(p + Vector2(0, bob), 16, -PI * 0.15, PI * 1.7, 32, Color(tint, 0.6), 1.5, true)
	draw_polygon(PackedVector2Array([p + Vector2(0, -8 + bob), p + Vector2(6, bob), p + Vector2(0, 8 + bob), p + Vector2(-6, bob)]), PackedColorArray([tint]))
	var box := Rect2(p + Vector2(-42, 30), Vector2(84, 34))
	draw_rect(box, Color("0b1920"))
	draw_rect(box, Color(tint, 0.85 if chosen else 0.3), false, 1.5)
	var word: String = String(orb.word).to_upper()
	text_at(word, p + Vector2(0, 55), 24, tint, true)
	if chosen:
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var part := word.left(prefix.length())
		text_at(part, p + Vector2(-width * 0.5, 55), 24, WHITE)
		draw_line(p + Vector2(-width * 0.5, 60), p + Vector2(-width * 0.5 + font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, 60), WHITE, 2)

func draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	if enemy.hp <= 0:
		draw_arc(p, 35, 0, TAU, 32, Color(TEAL, 0.2), 2, true)
		return
	var weak: Vector2 = enemy.weak
	var angle := weak.angle()
	var warning: float = clampf((enemy.timer - 3.4) / 1.4, 0, 1)
	if warning > 0:
		draw_circle(p, 285, Color(RED, warning * 0.09))
		draw_arc(p, 285, -PI / 2, -PI / 2 + TAU * warning, 72, Color(RED, 0.8), 3, true)
		text_at("PULSE", p + Vector2(0, -305), 15, RED, true)
	draw_circle(p + Vector2(0, 13), 40, Color(0, 0, 0, 0.2))
	var body := PackedVector2Array()
	for i in 8:
		body.append(p + Vector2.from_angle(PI / 8 + i * TAU / 8) * 35)
	draw_colored_polygon(body, Color("293b3c"))
	var rim := PackedVector2Array(body)
	rim.append(body[0])
	draw_polyline(rim, GOLD if enemy.blocked <= 0 else WHITE, 3, true)
	draw_arc(p, 47, angle - deg_to_rad(48), angle + deg_to_rad(48), 24, TEAL, 6, true)
	draw_line(p + weak * 54, p + weak * 84, Color(TEAL, 0.65), 2, true)
	var arrow := p + weak * 58
	draw_line(arrow, arrow + weak.rotated(0.65) * 12, TEAL, 2, true)
	draw_line(arrow, arrow + weak.rotated(-0.65) * 12, TEAL, 2, true)
	draw_circle(p, 12, TEAL if enemy.flash > 0 else GOLD)
	draw_line(p - weak * 10, p - weak * 27, Color("101b24"), 8, true)
	text_at("SENTINEL", p + Vector2(0, 88), 13, Color("8ba29e"), true)
	for i in 2:
		draw_rect(Rect2(p + Vector2(-15 + i * 18, -65), Vector2(12, 5)), GOLD if i < enemy.hp else Color("31413f"))

func draw_player() -> void:
	if invulnerable > 0 and int(elapsed * 14) % 2 == 0:
		return
	draw_circle(player + Vector2(0, 15), 19, Color(0, 0, 0, 0.35))
	draw_circle(player, 28, Color(TEAL, 0.07))
	draw_arc(player, 23, 0.4, 5.2, 30, Color(TEAL, 0.55), 2, true)
	var body := PackedVector2Array([player + Vector2(0, -16), player + Vector2(13, 13), player + Vector2(0, 7), player + Vector2(-13, 13)])
	draw_colored_polygon(body, Color("d6eee1"))
	draw_line(player + Vector2(-5, 5), player + Vector2(-12, 25), TEAL, 4, true)
	draw_circle(player + Vector2(0, -8), 5, Color("153c3c"))
	text_at("YOU", player + Vector2(0, -35), 12, TEAL, true)
