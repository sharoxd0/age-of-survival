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
@export var joystick_speed: float = 45.0
@export var reach_radius: float = 12.0
@export var joystick_target_distance: float = 48.0

# joystick optimizaciones
@export var joystick_target_min_delta: float = 6.0   # no recalcular target si no cambió
@export var nav_update_every_n_frames: int = 3        # throttle del nav (1 = cada frame)

# =========================================================
# ORIENTACIÓN
# =========================================================
var last_dir: Vector2 = Vector2.DOWN

# cache anim (evita sprite.play() repetido)
var _current_anim: String = ""
var _current_flip_h: bool = false

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
# idle | harvesting | returning_home | moving | manual
# =========================================================
var state: String = "idle"
var home_position: Vector2
var last_resource_cell: Vector2i = Vector2i(-1, -1)

# =========================================================
# MOVIMIENTO / NAVEGACIÓN
# =========================================================
var current_target: Vector2 = Vector2.ZERO
var current_cell: Vector2i = Vector2i(-1, -1)

# Anti-stuck (barato)
var last_pos: Vector2
var stuck_time: float = 0.0
const STUCK_THRESHOLD: float = 0.7
const STUCK_MIN_MOVE: float = 1.0

# =========================================================
# JOYSTICK
# =========================================================
var joystick_dir: Vector2 = Vector2.ZERO
var using_joystick: bool = false
var _last_joystick_target: Vector2 = Vector2.INF

# =========================================================
# NAV TICK (throttle)
# =========================================================
var _nav_tick: int = 0

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	home_position = global_position
	last_pos = global_position

	if sprite:
		sprite.play("idle_down")
		_current_anim = "idle_down"
		_current_flip_h = false

	if selection_circle:
		selection_circle.visible = false

	# 🔧 optimización NavigationAgent
	if agent:
		agent.path_desired_distance = 4.0
		agent.target_desired_distance = reach_radius
		agent.avoidance_enabled = false # MUCHÍSIMO menos CPU

# =========================================================
# EQUIPAMIENTO
# =========================================================
func equip_item(item: ItemData, preferred_slot := "") -> bool:
	if item == null:
		return false

	var slot: String = preferred_slot
	if slot == "":
		match item.slot_kind:
			"hand": slot = "hand"
			"chest": slot = "body"
			"off_hand": slot = "off_hand"
			"extra": slot = "extra"
			_: return false

	if slot == "hand" and item.two_handed and equipment["off_hand"] != null:
		equipment["off_hand"] = null

	if slot == "off_hand" and equipment["hand"] != null and equipment["hand"].two_handed:
		return false

	equipment[slot] = item
	emit_signal("cargo_changed")
	return true

func unequip(slot: String) -> ItemData:
	if not equipment.has(slot):
		return null

	var item: ItemData = equipment[slot]
	if item == null:
		return null

	equipment[slot] = null
	emit_signal("cargo_changed")
	return item

func has_tool(tool_id: String) -> bool:
	for s in ["hand", "off_hand"]:
		var it: ItemData = equipment.get(s)
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
	_stop_manual()
	state = "harvesting"
	current_target = pos
	current_cell = cell
	last_resource_cell = cell
	_start_nav_to(pos)

func go_home() -> void:
	_stop_manual()
	state = "returning_home"
	current_target = home_position
	current_cell = Vector2i(-1, -1)
	_start_nav_to(home_position)

func move_to_position(pos: Vector2) -> void:
	_stop_manual()
	state = "moving"
	current_target = pos
	current_cell = Vector2i(-1, -1)
	_start_nav_to(pos)

# =========================================================
# JOYSTICK (SIN ATRAVESAR OBSTÁCULOS)
# =========================================================
func set_joystick_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	using_joystick = true
	joystick_dir = dir.normalized()
	state = "manual"

func release_joystick() -> void:
	using_joystick = false
	joystick_dir = Vector2.ZERO
	state = "idle"
	velocity = Vector2.ZERO
	_stop_nav()
	_last_joystick_target = Vector2.INF

func _stop_manual() -> void:
	using_joystick = false
	joystick_dir = Vector2.ZERO
	_last_joystick_target = Vector2.INF

# =========================================================
# NAVEGACIÓN
# =========================================================
func _start_nav_to(pos: Vector2) -> void:
	if agent:
		agent.target_position = pos
	last_pos = global_position
	stuck_time = 0.0

func _stop_nav() -> void:
	# no “deshabilitamos” el agent; solo dejamos target quieto
	if agent:
		agent.target_position = global_position

# =========================================================
# PHYSICS PROCESS (OPTIMIZADO)
# =========================================================
func _physics_process(delta: float) -> void:
	_nav_tick += 1

	# --------------------------------------------------
	# JOYSTICK → NavigationAgent (NO atraviesa árboles)
	# --------------------------------------------------
	if state == "manual" and using_joystick:
		if agent:
			# throttle de target + evitar recalcular si apenas cambió
			var target_pos: Vector2 = global_position + joystick_dir * joystick_target_distance
			if _last_joystick_target == Vector2.INF or _last_joystick_target.distance_to(target_pos) >= joystick_target_min_delta:
				_last_joystick_target = target_pos
				agent.target_position = target_pos

			# throttle de lectura del path
			var next: Vector2 = global_position
			if nav_update_every_n_frames <= 1 or (_nav_tick % nav_update_every_n_frames) == 0:
				next = agent.get_next_path_position()
			else:
				next = agent.get_next_path_position() # (si quieres más agresivo, guarda 'next' en var y reúsalo)

			var dir: Vector2 = next - global_position
			if dir.length() > 0.001:
				dir = dir.normalized()
			velocity = dir * joystick_speed
		else:
			# fallback sin agent (no recomendado, pero evita crash)
			velocity = joystick_dir * joystick_speed

		move_and_slide()

		if velocity.length() > 1.0:
			last_dir = velocity.normalized()

		_update_idle_animation()
		return

	# --------------------------------------------------
	# IDLE → baratísimo
	# --------------------------------------------------
	if state == "idle":
		velocity = Vector2.ZERO
		move_and_slide()
		_update_idle_animation()
		return

	# --------------------------------------------------
	# IA / CLICK
	# --------------------------------------------------
	match state:
		"harvesting":
			_process_harvesting(delta)
		"returning_home":
			_process_returning_home()
		"moving":
			_process_moving()

	if velocity.length() > 1.0:
		last_dir = velocity.normalized()

	_update_idle_animation()

# =========================================================
# PROCESOS IA
# =========================================================
func _process_harvesting(delta: float) -> void:
	# si no hay agent, no podemos navegar
	if not agent:
		state = "idle"
		return

	var moved: float = global_position.distance_to(last_pos)
	if moved < STUCK_MIN_MOVE:
		stuck_time += delta
	else:
		stuck_time = 0.0
		last_pos = global_position

	if stuck_time > STUCK_THRESHOLD:
		state = "idle"
		emit_signal("arrived_to_resource", self, current_cell)
		return

	# si ya llegó, no calculemos más
	if global_position.distance_to(current_target) <= reach_radius:
		state = "idle"
		velocity = Vector2.ZERO
		emit_signal("arrived_to_resource", self, current_cell)
		return

	var next: Vector2 = agent.get_next_path_position()
	var dir: Vector2 = (next - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

func _process_returning_home() -> void:
	if not agent:
		state = "idle"
		return

	if global_position.distance_to(home_position) <= reach_radius:
		state = "idle"
		velocity = Vector2.ZERO
		emit_signal("arrived_home", self)
		return

	var next: Vector2 = agent.get_next_path_position()
	var dir: Vector2 = (next - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	if agent.is_navigation_finished():
		state = "idle"
		velocity = Vector2.ZERO
		emit_signal("arrived_home", self)

func _process_moving() -> void:
	if not agent:
		state = "idle"
		return

	if global_position.distance_to(current_target) <= reach_radius:
		state = "idle"
		velocity = Vector2.ZERO
		return

	var next: Vector2 = agent.get_next_path_position()
	var dir: Vector2 = (next - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	if agent.is_navigation_finished():
		state = "idle"
		velocity = Vector2.ZERO

# =========================================================
# SELECCIÓN VISUAL
# =========================================================
func set_selected(value: bool) -> void:
	if selection_circle:
		selection_circle.visible = value

# =========================================================
# ANIMACIÓN (OPTIMIZADA: NO play() cada frame)
# =========================================================
func _update_idle_animation() -> void:
	if not sprite:
		return

	var d: Vector2 = last_dir
	var anim: String = ""
	var flip_h: bool = false

	if d.y > 0.5:
		anim = "idle_down"
	elif d.y < -0.5:
		anim = "idle_up"
	else:
		# horizontal
		anim = "idle_right"
		if d.x < 0:
			flip_h = true

	if anim != _current_anim:
		_current_anim = anim
		sprite.play(anim)

	if flip_h != _current_flip_h:
		_current_flip_h = flip_h
		sprite.flip_h = flip_h
