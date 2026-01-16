extends Control

@export var radius := 20.0
@export var color := Color(1, 1, 1, 0.9)

func _ready():
	custom_minimum_size = Vector2(radius * 2, radius * 2)

func _draw():
	draw_circle(size * 0.5, radius, color)
