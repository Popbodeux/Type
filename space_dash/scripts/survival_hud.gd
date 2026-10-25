extends Node2D
var game
var font: Font
const WHITE := Color("f5f5dc")
const MINT := Color("a3fff3")
const GOLD := Color("ffe08a")

static func difficulty_rect(index: int) -> Rect2:
	return Rect2(185 + index * 200, 228, 190, 44)

static func new_game_rect() -> Rect2:
	return Rect2(350, 314, 260, 52)

static func resume_rect() -> Rect2:
	return Rect2(350, 540 * 0.50, 260, 48)

static func exit_rect(phase: String) -> Rect2:
	return Rect2(390, 385 if phase == "title" else (340 if phase == "paused" else 440), 180, 38)

static func mute_rect() -> Rect2:
	return Rect2(20, 408, 235, 28)

static func volume_rect() -> Rect2:
	return Rect2(20, 449, 235, 10)

static func grass_rect(index: int) -> Rect2:
	return Rect2(20 + index * 81, 482, 73, 28)

func _ready() -> void:
	font = ThemeDB.fallback_font

func label(value: String, pos: Vector2, size: int = 17, color: Color = WHITE, centered: bool = false) -> void:
	if centered:
		pos.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color("173022"))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func button(rect: Rect2, value: String, selected: bool = false) -> void:
	draw_rect(rect, Color("254638"))
	draw_rect(rect, GOLD if selected else Color("9eb5a0"), false, 2)
	label(value, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 6), 18, GOLD if selected else WHITE, true)

func backdrop() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.04, 0.1, 0.06, 0.86))

func _draw() -> void:
	if game == null or font == null:
		return
	var s = game.state
	if s.phase != "title":
		label("POINTS  %d" % s.score, Vector2(14, 25), 20)
		label("WPM %.1f   ACC %.1f%%" % [s.wpm(), s.accuracy() * 100], Vector2(14, 48), 14)
		label("BEST %.1f   STREAK %d" % [s.best_wpm, s.word_streak], Vector2(14, 69), 13)
		var timer_color := Color("ff8c85") if s.timer < 8.0 else WHITE
		label("%.1f" % maxf(0, s.timer), Vector2(480, 39), 31, timer_color, true)
		draw_rect(Rect2(360, 49, 240, 10), Color(0.07, 0.16, 0.1, 0.75))
		draw_rect(Rect2(360, 49, 240 * clampf(s.timer / 30.0, 0, 1), 10), timer_color)
		label("ESC SETTINGS", Vector2(830, 25), 12)
		if s.notice_left > 0:
			label(s.notice, Vector2(480, 86), 14, Color("ffccc0"), true)
		var active: Dictionary = s.find_orb(s.active_id)
		label(s.buffer + "_", Vector2(480, 484), 25, GOLD if not active.is_empty() else WHITE, true)
		var complete: bool = not active.is_empty() and active.word == s.buffer
		label("[ SPACE ] DASH" if complete else "TYPE A WORD, THEN PRESS SPACE", Vector2(480, 510), 13, GOLD if complete else WHITE, true)
		if s.miss_flash > 0:
			draw_rect(Rect2(0, 0, 960, 540), Color(1, 0.1, 0.05, float(s.miss_flash) / 0.18 * 0.19))
	if s.phase == "title":
		backdrop()
		label("TYPE", Vector2(480, 138), 48, WHITE, true)
		label("GRASS / SPACE-TO-DASH SURVIVAL", Vector2(480, 176), 16, MINT, true)
		label("Type a floating word. Press Space. Dash through enemies.", Vector2(480, 204), 15, WHITE, true)
		for i in 3:
			button(difficulty_rect(i), ["EASY", "NORMAL", "HARD"][i], s.difficulty == i)
		button(new_game_rect(), "NEW GAME")
		button(exit_rect("title"), "EXIT")
		label("HIGH SCORE  %d" % s.high_score, Vector2(480, 460), 17, GOLD, true)
	elif s.phase == "paused":
		backdrop()
		label("PAUSED", Vector2(480, 205), 38, WHITE, true)
		label("Escape resumes. Typing was cleared when paused.", Vector2(480, 239), 16, WHITE, true)
		button(resume_rect(), "RESUME")
		button(exit_rect("paused"), "EXIT")
	elif s.phase == "gameover":
		backdrop()
		label("TIME'S UP", Vector2(480, 117), 37, WHITE, true)
		label("POINTS  %d    HIGH SCORE  %d" % [s.score, s.high_score], Vector2(480, 173), 22, GOLD, true)
		label("WPM %.1f   GROSS WPM %.1f" % [s.wpm(), s.gross_wpm()], Vector2(480, 216), 20, WHITE, true)
		label("ACCURACY %.1f%%   BEST WPM %.1f" % [s.accuracy() * 100, s.best_wpm], Vector2(480, 254), 18, WHITE, true)
		label("WORDS %d   BEST STREAK %d" % [s.completed_words, s.best_streak], Vector2(480, 291), 18, WHITE, true)
		label("SURVIVED %.1f SECONDS" % s.elapsed, Vector2(480, 327), 15, WHITE, true)
		label("[ R / ENTER ]  PLAY AGAIN", Vector2(480, 390), 21, MINT, true)
		button(exit_rect("gameover"), "EXIT")
	if s.phase in ["title", "paused", "gameover"] and game.sound:
		button(mute_rect(), "MUTED" if game.sound.muted else "SOUND ON", game.sound.muted)
		label("VOLUME %d%%" % int(game.sound.master_volume * 100), Vector2(20, 446), 11)
		draw_rect(volume_rect(), Color("334a39"))
		draw_rect(Rect2(volume_rect().position, Vector2(volume_rect().size.x * game.sound.master_volume, 10)), MINT)
		label("GRASS", Vector2(20, 477), 11)
		for i in 3:
			button(grass_rect(i), ["OFF", "LOW", "HIGH"][i], game.grass_quality == i)
	draw_rect(Rect2(0, 524, 960, 16), Color(0.04, 0.1, 0.06, 0.85))
	label("v0.4.2   F8 GRASS: %s   F10 SOUND: %s" % [["OFF", "LOW", "HIGH"][game.grass_quality], "MUTED" if game.sound and game.sound.muted else "ON"], Vector2(8, 536), 10, GOLD)
