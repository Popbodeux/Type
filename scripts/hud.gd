extends Node2D
## Fixed canvas coordinates: the gameplay camera never moves the interface.
var game
var font: Font
const MINT := Color("72f1ce")
const PAPER := Color("e4eee8")
const MUTED := Color("8ba6a1")

func _ready() -> void:
	font = ThemeDB.fallback_font

func label(text: String, p: Vector2, size: int = 18, color: Color = PAPER, center: bool = false) -> void:
	if center:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color = Color("0c1b23")) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("2b4647")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)

func _draw() -> void:
	if font == null or game == null:
		return
	panel(Rect2(24, 20, 1232, 80))
	label("CHI CIRCUIT", Vector2(46, 55), 25)
	label("TYPE A WORD. BECOME THE STRIKE.", Vector2(47, 79), 11, MUTED)
	label("WAVE  %02d / 03" % game.wave, Vector2(514, 53), 17, MINT)
	label("%02d  CLEAN STRIKES" % game.strikes, Vector2(514, 78), 12, MUTED)
	label("VITALITY", Vector2(1042, 51), 11, MUTED)
	for i in 3:
		draw_circle(Vector2(1053 + i * 27, 73), 6, MINT if i < game.health else Color("2b4345"))
	label("F1  HELP", Vector2(1151, 66), 12, MUTED)
	panel(Rect2(370, 696, 540, 80))
	label("TYPE AN ORB'S WORD TO DASH", Vector2(640, 721), 12, MUTED, true)
	var typed: String = game.prefix.to_upper()
	label(typed + "_".repeat(3 - typed.length()), Vector2(640, 758), 30, MINT, true)
	label("BACKSPACE  correct    ESC  clear", Vector2(30, 735), 12, MUTED)
	label("TAB  pause    F5  restart", Vector2(1008, 735), 12, MUTED)
	label("MINT ARC = VULNERABLE SIDE  /  DASH THROUGH TO STRIKE", Vector2(640, 674), 12, MUTED, true)
	if game.notice_time > 0 and game.phase == "playing":
		panel(Rect2(310, 114, 660, 38))
		label(game.notice, Vector2(640, 139), 13, game.notice_color, true)
	if game.phase == "intro":
		draw_rect(Rect2(0, 0, 1280, 800), Color(0.02, 0.05, 0.07, 0.78))
		panel(Rect2(300, 180, 680, 432))
		label("A TYPING COMBAT STUDY", Vector2(640, 227), 12, MINT, true)
		label("Chi Circuit", Vector2(640, 287), 48, PAPER, true)
		label("Choose your route. Find their opening.", Vector2(640, 324), 20, MUTED, true)
		label("01   TYPE a glowing orb's three-letter word.", Vector2(351, 381), 18)
		label("02   DASH through a sentinel from its mint side.", Vector2(351, 419), 18)
		label("03   Land two clean strikes. Clear three waves.", Vector2(351, 457), 18)
		label("Red pulse? Dash away. Armored angle? Reposition.", Vector2(640, 502), 15, MUTED, true)
		label("[ ENTER ]  BEGIN", Vector2(640, 558), 22, MINT, true)
		label("GODOT RECONSTRUCTION PROTOTYPE  /  NOT A SOURCE PORT", Vector2(640, 638), 11, MUTED, true)
	elif game.phase in ["won", "lost", "paused"] or game.help_open:
		draw_rect(Rect2(0, 0, 1280, 800), Color(0.02, 0.05, 0.07, 0.83))
		panel(Rect2(300, 225, 680, 350))
		if game.help_open:
			label("Find the opening", Vector2(640, 284), 32, PAPER, true)
			label("Complete an orb word to dash through it.", Vector2(640, 334), 18, MINT, true)
			label("Cross a sentinel from its mint arc to deal damage.", Vector2(640, 371), 17, PAPER, true)
			label("Other angles are blocked. Dash through to the far side.", Vector2(640, 407), 16, MUTED, true)
			label("Wrong letter keeps your prefix. Backspace corrects; Esc clears.", Vector2(640, 449), 15, MUTED, true)
			label("Words refresh after landing. Red rings warn of a pulse.", Vector2(640, 483), 15, MUTED, true)
			label("[ F1 / ESC ]  RETURN", Vector2(640, 536), 20, MINT, true)
		elif game.phase == "paused":
			label("Take a breath.", Vector2(640, 350), 40, PAPER, true)
			label("[ TAB ]  RESUME", Vector2(640, 450), 20, MINT, true)
		else:
			label("Circuit complete." if game.phase == "won" else "The circuit fades.", Vector2(640, 312), 38, PAPER, true)
			label("%d strikes   /   %d dashes   /   %.1f seconds" % [game.strikes, game.dashes, game.elapsed], Vector2(640, 372), 19, MINT, true)
			label("%d armored hits   /   %d typing corrections" % [game.blocks, game.mistakes], Vector2(640, 412), 15, MUTED, true)
			label("Try another route. Every restart resets the encounter.", Vector2(640, 464), 16, MUTED, true)
			label("[ ENTER ]  PLAY AGAIN", Vector2(640, 528), 22, MINT, true)
