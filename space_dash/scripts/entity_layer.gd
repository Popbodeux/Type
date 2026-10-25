extends Node2D
var game

func _draw() -> void:
	if game:
		game.draw_entities(self)
