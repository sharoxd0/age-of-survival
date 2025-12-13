extends CharacterBody2D

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

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var selection_circle: Sprite2D = $SelectionCircle

# =========================================================
# EQUIPAMIENTO
# =========================================================
var equipment: Dictionary = {
	"hand": null,
	"chest": null,
	"off_hand": null,
	"extra": null
}

# Cada ítem ocupa 1 slot
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
	print("[Worker READY] Home:", home_position)

# =========================================================
# EQUIPAMIENTO
# =========================================================
func equip_item(item: ItemData, preferred_slot := "") -> bool:
	if item == null:
		return false

	var slot := preferred_slot
	if slot == "":
		match item.slot_kind:
			"hand": slot = "hand"
			"chest": slot = "chest"
			"off_hand": slot = "off_hand"
			"extra": slot = "extra"
			_: return false

	# liberar off-hand si mano es 2H
	if slot == "hand" and item.two_handed and equipment["off_hand"] != null:
		equipment["off_hand"] = null

	# bloquear off-hand si mano es 2H
	if slot == "off_hand" and equipment["hand"] != null and equipment["hand"].two_handed:
		return false

	equipment[slot] = item
	emit_signal("cargo_changed")

	print("Worker EQUIP:", item.nombre, "en", slot)
	return true

func has_tool(tool_id: String) -> bool:
	for slot in ["hand", "off_hand"]:
		var it: ItemData = equipment.get(slot, null)
		if it != null and it.id == tool_id:
			return true
	return false

# =========================================================
# CARGO
# =========================================================
func get_cargo_slots() -> int:
	return 1

func is_cargo_full() -> bool:
	return cargo.size() >= get_cargo_slots()

# =========================================================
# ÓRDENES DE MOVIMIENTO
# =========================================================
func move_to_edge(pos: Vector2, cell: Vector2i) -> void:
	print("\n[WORKER DEBUG] move_to_edge")
	print("  target:", pos)
	print("  cell:", cell)

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

	print("[WORKER] → go_home")

func move_to_position(pos: Vector2) -> void:
	state = "moving"
	current_cell = Vector2i(-1, -1)
	current_target = pos

	agent.target_position = pos

	stuck_time = 0.0
	last_pos = global_position

	print("[WORKER] Move manual:", pos)

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

# =========================================================
# PROCESOS
# =========================================================
func _process_harvesting(delta: float) -> void:
	print("[WORKER DEBUG] harvesting pos:", global_position, "target:", current_target)

	var moved := global_position.distance_to(last_pos)
	if moved < STUCK_MIN_MOVE:
		stuck_time += delta
	else:
		stuck_time = 0.0
		last_pos = global_position

	if stuck_time > STUCK_THRESHOLD:
		print("[WORKER DEBUG] UNSTUCK -> emit arrived")
		stuck_time = 0.0
		state = "idle"
		emit_signal("arrived_to_resource", self, current_cell)
		return

	var next := agent.get_next_path_position()
	var dir := (next - global_position).normalized()
	velocity = dir * speed

	if global_position.distance_to(current_target) <= reach_radius:
		print("[WORKER DEBUG] LLEGÓ -> emit arrived")
		state = "idle"
		stuck_time = 0.0
		emit_signal("arrived_to_resource", self, current_cell)
		return

	move_and_slide()
func _process_returning_home(delta: float) -> void:
	var next := agent.get_next_path_position()
	var dir := (next - global_position).normalized()
	velocity = dir * speed

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
	velocity = dir * speed

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
