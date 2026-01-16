extends Node2D
class_name World


@onready var building_manager: BuildingManager = $BuildingManager
# =========================================================
# WORKER LIST
# =========================================================
@onready var worker_list: VBoxContainer = $UI/WorkerListPanel/MarginContainer/VBoxContainer
@onready var worker_list_panel: Control = $UI/WorkerListPanel
@export var worker_button_scene: PackedScene

# =========================================================
# INPUT CONFIG (FUENTE ÚNICA DE VERDAD)
# =========================================================
const TOUCH_RADIUS_PX := 20.0
const LONG_PRESS_TIME := 0.35
const LONG_PRESS_MOVE_TOLERANCE := 10.0

# =========================================================
# INPUT STATE (usado por WorldInput)
# =========================================================
var is_pressing := false
var press_start_pos := Vector2.ZERO
var pressed_on_resource := false
var pressed_is_small := false
var pressed_cell := Vector2i(-1, -1)
var pressed_source_id := -1
var pressed_atlas := Vector2i.ZERO
var long_press_fired := false

# =========================================================
# SUBSISTEMAS
# =========================================================
@onready var world_input     = $WorldInput
@onready var world_resources = $WorldResources
@onready var world_workers   = $WorldWorkers

# =========================================================
# MAPA
# =========================================================
@onready var resources: TileMapLayer       = $Resources_TileMapLayer
@onready var resources_small: TileMapLayer = $SmallResources_TileMapLayer
@onready var ground: TileMapLayer          = $Ground_TileMapLayer

# =========================================================
# UI
# =========================================================
@onready var joystick: VirtualJoystick = $UI/Joystick

@onready var btn_inv: Button = $UI/VBoxContainer/Button2
@onready var btn_spawn_worker: Button = $UI/VBoxContainer/ButtonSpawnWorker
@onready var btn_craft: Button = $UI/VBoxContainer/ButtonCraft

@onready var panel_resource: Panel = $UI/PanelRecurso
@onready var btn_collect: Button = $UI/PanelRecurso/BotonRecolectar

@onready var label_res_name: Label = $UI/PanelRecurso/LabelNombre
@onready var label_res_desc: Label = $UI/PanelRecurso/LabelDescripcion
@onready var label_res_loot: Label = $UI/PanelRecurso/LabelLoot
@onready var label_res_req: Label  = $UI/PanelRecurso/LabelRequisito

@onready var panel_worker: Panel = $UI/PanelWorker

# =========================================================
# INVENTARIO
# =========================================================
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var panel_inventory: Panel = $UI/PanelInventario
@onready var panel_crafting: PanelCrafting = $UI/PanelCrafting

# =========================================================
# TIMER long press
# =========================================================
@onready var long_press_timer: Timer = Timer.new()

# =========================================================
# POBLACIÓN
# =========================================================
@export var population_cap_base: int = 2
var population_cap_bonus: int = 0

func get_population_cap() -> int:
	return population_cap_base + population_cap_bonus

func add_population_cap(amount: int) -> void:
	population_cap_bonus += amount
	print("[POP] Cap aumentado en +%d → total:%d" % [amount, get_population_cap()])

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	# Referencias cruzadas
	building_manager.setup(self)
	world_input.world = self
	world_resources.world = self
	world_workers.world = self
	world_workers.resources_manager = world_resources
	panel_worker.world = self

	# Señales de selección
	world_workers.worker_selected.connect(_on_worker_selected)
	world_workers.worker_deselected.connect(_on_worker_deselected)

	# Inventario
	panel_inventory.set_inventory_manager(inventory_manager)
	panel_crafting.inventory_manager = inventory_manager

	# UI inicial
	panel_inventory.visible = false
	panel_resource.visible = false
	panel_worker.visible = false
	panel_crafting.visible = false

	# Botones
	btn_inv.pressed.connect(_on_btn_inv_pressed)
	btn_collect.pressed.connect(_on_collect_pressed)
	btn_spawn_worker.pressed.connect(_on_spawn_worker_pressed)
	btn_craft.pressed.connect(_on_btn_craft_pressed)
	
	# Joystick
	joystick.joystick_moved.connect(_on_joystick_moved)
	joystick.joystick_released.connect(_on_joystick_released)

	# Recursos
	world_resources.init_resources(resources)
	panel_crafting.panel_opened.connect(_on_crafting_opened)
	panel_crafting.panel_closed.connect(_on_crafting_closed)
	# Worker inicial
	if has_node("Worker"):
		var w: CharacterBody2D = $Worker
		world_workers.register_worker(w)

	rebuild_worker_list()
	_show_controls()

	# Timer long press
	add_child(long_press_timer)
	long_press_timer.one_shot = true
	long_press_timer.wait_time = LONG_PRESS_TIME
	long_press_timer.timeout.connect(world_input._on_long_press_timeout)

# =========================================================
# CONTROLES VISUALES
# =========================================================
func _show_controls() -> void:
	worker_list_panel.visible = true
	joystick.visible = true

func _hide_controls() -> void:
	worker_list_panel.visible = false
	joystick.visible = false

# =========================================================
# WORKER SELECTION CALLBACKS
# =========================================================
func _on_worker_selected(w: CharacterBody2D) -> void:
	panel_crafting.set_active_worker(w)
	_update_worker_buttons()
	_show_controls()

func _on_worker_deselected() -> void:
	panel_crafting.clear_active_worker()
	_update_worker_buttons()

# =========================================================
# JOYSTICK → WORKER
# =========================================================
func _on_joystick_moved(dir: Vector2) -> void:
	var w: CharacterBody2D = world_workers.active_worker
	if w:
		w.set_joystick_direction(dir)

func _on_joystick_released() -> void:
	var w: CharacterBody2D = world_workers.active_worker
	if w:
		w.release_joystick()

# =========================================================
# UI CALLBACKS
# =========================================================
func _on_btn_inv_pressed() -> void:
	panel_inventory.visible = !panel_inventory.visible
	if panel_inventory.visible:
		panel_crafting.visible = false
		_hide_controls()
	else:
		_show_controls()

func _on_collect_pressed() -> void:
	world_workers.try_collect_with_active_worker()

func _on_spawn_worker_pressed() -> void:
	var w := preload("res://scenes/Worker.tscn").instantiate()
	w.global_position = Vector2(64, 0)
	add_child(w)
	world_workers.register_worker(w)
	rebuild_worker_list()

func _on_btn_craft_pressed() -> void:
	panel_crafting.visible = !panel_crafting.visible
	if panel_crafting.visible:
		panel_inventory.visible = false
		_hide_controls()
	else:
		_show_controls()

# =========================================================
# API PÚBLICA (USADA POR WorldInput)
# =========================================================
func select_worker(w: CharacterBody2D) -> void:
	world_workers.select_worker(w)
	_update_worker_buttons()

# =========================================================
# WORKER LIST PANEL
# =========================================================
func rebuild_worker_list() -> void:
	if worker_button_scene == null:
		push_error("worker_button_scene no asignado")
		return

	for c in worker_list.get_children():
		c.queue_free()

	for w in get_tree().get_nodes_in_group("workers"):
		if not (w is CharacterBody2D):
			continue

		var btn := worker_button_scene.instantiate() as WorkerButton
		worker_list.add_child(btn)
		btn.setup(w)

		btn.pressed.connect(func():
			select_worker(w)
		)

func _update_worker_buttons() -> void:
	for btn in worker_list.get_children():
		if btn is WorkerButton:
			btn.set_selected(btn.worker == world_workers.active_worker)
			
func _on_crafting_opened() -> void:
	_hide_controls()

func _on_crafting_closed() -> void:
	_show_controls()
