extends CharacterBody2D

# =========================================================
# NODOS
# =========================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var selection_circle: Sprite2D = $SelectionCircle

# =========================================================
# SEÑALES
# =========================================================
signal arrived_to_resource(worker: CharacterBody2D, cell: Vector2i)
signal arrived_home(worker: CharacterBody2D)
signal cargo_changed

# =========================================================
# PARÁMETROS
# =========================================================
@export var speed: float = 45.0
@export var reach_radius: float = 12.0

# =========================================================
# ORIENTACIÓN
# =========================================================
var last_dir: Vector2 = Vector2.DOWN

# =========================================================
# EQUIPAMIENTO
# =========================================================
var equipment: Dictionary = {
	"hand": null,
	"body": null,
	"off_hand": null,
	"extra": null
}

var cargo: Array[ItemData] = []

# =========================================================
# ESTADO
# =========================================================
var home_position: Vector2
var state: String = "idle"   # idle | harvesting | returning_home | moving
var last_resource_cell: Vector2i = Vector2i(-1, -1)

# =========================================================
# MOVIMIENTO + ANTI-ATORO
# =========================================================
var current_target: Vector2 = Vector2.ZERO
var current_cell: Vector2i = Vector2i(-1, -1)

var last_pos: Vector2 = Vector2.ZERO
var stuck_time: float = 0.0

const STUCK_THRESHOLD := 0.7
const STUCK_MIN_MOVE := 1.0

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	home_position = global_position
	last_pos = global_position
	sprite.play("idle_down")
	print("[Worker READY] Home:", home_position)

# =========================================================
# ÓRDENES DE MOVIMIENTO
# =========================================================
func move_to_edge(pos: Vector2, cell: Vector2i) -> void:
	state = "harvesting"
	current_target = pos
	current_cell = cell
	last_resource_cell = cell

	agent.target_position = pos
	stuck_time = 0.0
	last_pos = global_position

func go_home() -> void:
	state = "returning_home"
	current_cell = Vector2i(-1, -1)
	current_target = home_position

	agent.target_position = home_position
	stuck_time = 0.0
	last_pos = global_position

func move_to_position(pos: Vector2) -> void:
	state = "moving"
	current_cell = Vector2i(-1, -1)
	current_target = pos

	agent.target_position = pos
	stuck_time = 0.0
	last_pos = global_position

# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:
	match state:
		"idle":
			velocity = Vector2.ZERO
			move_and_slide()

		"harvesting":
			_process_harvesting(delta)

		"returning_home":
			_process_returning_home(delta)

		"moving":
			_process_moving(delta)

	# Guardar dirección real usada
	if velocity.length() > 1.0:
		last_dir = velocity.normalized()

	_update_idle_animation()

# =========================================================
# PROCESOS (USANDO NavigationAgent2D CORRECTAMENTE)
# =========================================================
func _process_harvesting(delta: float) -> void:
	var moved := global_position.distance_to(last_pos)
	if moved < STUCK_MIN_MOVE:
		stuck_time += delta
	else:
		stuck_time = 0.0
		last_pos = global_position

	if stuck_time > STUCK_THRESHOLD:
		state = "idle"
		stuck_time = 0.0
		emit_signal("arrived_to_resource", self, current_cell)
		return

	var next := agent.get_next_path_position()
	var dir := (next - global_position).normalized()

	agent.set_velocity(dir * speed)
	velocity = agent.get_velocity()

	if global_position.distance_to(current_target) <= reach_radius:
		state = "idle"
		stuck_time = 0.0
		emit_signal("arrived_to_resource", self, current_cell)
		return

	move_and_slide()

func _process_returning_home(delta: float) -> void:
	var next := agent.get_next_path_position()
	var dir := (next - global_position).normalized()

	agent.set_velocity(dir * speed)
	velocity = agent.get_velocity()

	if global_position.distance_to(home_position) <= reach_radius \
	or agent.is_navigation_finished():
		state = "idle"
		velocity = Vector2.ZERO
		emit_signal("arrived_home", self)
		return

	move_and_slide()

func _process_moving(delta: float) -> void:
	var next := agent.get_next_path_position()
	var dir := (next - global_position).normalized()

	agent.set_velocity(dir * speed)
	velocity = agent.get_velocity()

	if global_position.distance_to(current_target) <= reach_radius \
	or agent.is_navigation_finished():
		state = "idle"
		velocity = Vector2.ZERO
		return

	move_and_slide()

# =========================================================
# SELECCIÓN
# =========================================================
func set_selected(value: bool) -> void:
	if selection_circle:
		selection_circle.visible = value

# =========================================================
# ANIMACIÓN IDLE DIRECCIONAL
# =========================================================
func _update_idle_animation() -> void:
	var dir := last_dir

	if dir.y > 0.5:
		if dir.x > 0.3:
			sprite.play("idle_down_right")
			sprite.flip_h = false
		elif dir.x < -0.3:
			sprite.play("idle_down_right")
			sprite.flip_h = true
		else:
			sprite.play("idle_down")
			sprite.flip_h = false

	elif dir.y < -0.5:
		if dir.x > 0.3:
			sprite.play("idle_up_right")
			sprite.flip_h = false
		elif dir.x < -0.3:
			sprite.play("idle_up_right")
			sprite.flip_h = true
		else:
			sprite.play("idle_up")
			sprite.flip_h = false

	else:
		if dir.x > 0:
			sprite.play("idle_right")
			sprite.flip_h = false
		elif dir.x < 0:
			sprite.play("idle_right")
			sprite.flip_h = true
