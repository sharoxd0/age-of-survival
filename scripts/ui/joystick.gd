extends Control
class_name VirtualJoystick

@export var radius := 48.0
@export var knob_radius := 20.0

var is_dragging := false
var direction := Vector2.ZERO

signal joystick_moved(dir: Vector2)
signal joystick_released

@onready var knob: Control = $Knob

# =================================================
func _ready():
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	knob.custom_minimum_size = Vector2(knob_radius * 2, knob_radius * 2)
	
	# 📍 Posición fija: abajo izquierda
	position = Vector2(24, get_viewport_rect().size.y - radius * 2 - 24)
	# Centrar el knob
	knob.position = size * 0.5 - knob.size * 0.5

	queue_redraw()

# =================================================

		
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = true
		else:
			# 👉 SOLTÓ EL STICK
			is_dragging = false
			_reset_knob()
			emit_signal("joystick_released")
			queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		_update_knob(event.position)
		emit_signal("joystick_moved", direction)
		queue_redraw()

# =================================================
func _update_knob(mouse_pos: Vector2):
	var center := size * 0.5
	var offset := mouse_pos - center

	# Limitar dentro del radio
	if offset.length() > radius:
		offset = offset.normalized() * radius

	knob.position = center + offset - knob.size * 0.5

	# Dirección normalizada (–1 a 1)
	direction = offset / radius

	print("DIR:", direction)

# =================================================
func _reset_knob():
	var center := size * 0.5
	knob.position = center - knob.size * 0.5
	direction = Vector2.ZERO

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		position = Vector2(24, get_viewport_rect().size.y - radius * 2 - 24)
