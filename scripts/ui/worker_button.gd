extends Button
class_name WorkerButton

var worker: CharacterBody2D

@onready var circle: ColorRect = $Circle

const SIZE := 64.0
const RADIUS := 32.0

func _ready() -> void:
	# 🔒 TAMAÑO REAL DEL BOTÓN (HITBOX)
	size = Vector2(SIZE, SIZE)
	custom_minimum_size = size

	# Evitar que VBoxContainer lo estire
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""  # ❌ nada de texto feo

	# 🔵 Configurar el círculo
	circle.size = size
	circle.position = Vector2.ZERO
	circle.color = Color(0.3, 0.6, 0.8)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	pressed.connect(_on_pressed)

	print("[WorkerButton READY] size:", size, "min:", custom_minimum_size)

func setup(w: CharacterBody2D) -> void:
	worker = w

func set_selected(value: bool) -> void:
	if value:
		circle.color = Color(0.3, 1.0, 0.3) # 🟢 seleccionado
	else:
		circle.color = Color(0.3, 0.6, 0.8) # 🔵 normal

func _on_pressed() -> void:
	print("[WorkerButton] PRESSED:", worker)
