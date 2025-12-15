extends Node2D

# =========================================================
# SUBSISTEMAS
# =========================================================
@onready var world_input      = $WorldInput
@onready var world_resources  = $WorldResources
@onready var world_workers    = $WorldWorkers

# =========================================================
# NODOS DEL MUNDO
# =========================================================
@onready var resources: TileMapLayer       = $Resources_TileMapLayer
@onready var resources_small: TileMapLayer = $SmallResources_TileMapLayer
@onready var ground: TileMapLayer          = $Ground_TileMapLayer

# =========================================================
# INVENTARIO (ÚNICA FUENTE DE VERDAD)
# =========================================================
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var panel_inventory = $UI/PanelInventario
@onready var panel_crafting: PanelCrafting = $UI/PanelCrafting

# =========================================================
# UI
# =========================================================
@onready var btn_inv: Button = $UI/VBoxContainer/Button2

@onready var panel_resource: Panel = $UI/PanelRecurso
@onready var label_res_name: Label = $UI/PanelRecurso/LabelNombre
@onready var label_res_desc: Label = $UI/PanelRecurso/LabelDescripcion
@onready var label_res_loot: Label = $UI/PanelRecurso/LabelLoot
@onready var label_res_req: Label = $UI/PanelRecurso/LabelRequisito
@onready var btn_collect: Button = $UI/PanelRecurso/BotonRecolectar

@onready var btn_spawn_worker: Button = $UI/VBoxContainer/ButtonSpawnWorker
@onready var panel_worker: Panel = $UI/PanelWorker
@onready var btn_craft: Button = $UI/VBoxContainer/ButtonCraft

# =========================================================
# INPUT STATE (solo datos compartidos)
# =========================================================
const TOUCH_RADIUS_PX := 20.0
const LONG_PRESS_TIME := 0.35
const LONG_PRESS_MOVE_TOLERANCE := 10.0

var is_pressing := false
var press_start_pos := Vector2.ZERO
var pressed_on_resource := false
var pressed_is_small := false
var pressed_cell := Vector2i(-1, -1)
var pressed_source_id := -1
var pressed_atlas: Vector2i = Vector2i.ZERO
var long_press_fired := false

@onready var long_press_timer: Timer = Timer.new()

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	# Inyección de referencias
	world_input.world = self
	world_resources.world = self
	world_workers.world = self
	world_workers.resources_manager = world_resources
	panel_worker.world = self

	# 🔥 Conectar inventario global a los paneles
	panel_inventory.set_inventory_manager(inventory_manager)
	panel_crafting.inventory_manager = inventory_manager

	# UI inicial
	panel_inventory.visible = false
	panel_resource.visible = false
	panel_worker.visible = false
	panel_crafting.visible = false

	# Conexiones UI
	btn_inv.pressed.connect(_on_btn_inv_pressed)
	btn_collect.pressed.connect(_on_collect_pressed)
	btn_spawn_worker.pressed.connect(_on_spawn_worker_pressed)
	btn_craft.pressed.connect(_on_btn_craft_pressed)

	# Inicializar recursos grandes
	world_resources.init_resources(resources)

	# Worker inicial (si existe)
	if has_node("Worker"):
		world_workers.register_worker($Worker)

	# Timer long press
	add_child(long_press_timer)
	long_press_timer.one_shot = true
	long_press_timer.wait_time = LONG_PRESS_TIME
	long_press_timer.timeout.connect(world_input._on_long_press_timeout)

# =========================================================
# UI CALLBACKS
# =========================================================
func _on_btn_inv_pressed() -> void:
	panel_inventory.visible = not panel_inventory.visible
	if panel_inventory.visible:
		panel_crafting.visible = false

func _on_collect_pressed() -> void:
	world_workers.try_collect_with_active_worker()

func _on_spawn_worker_pressed() -> void:
	var w := preload("res://scenes/Worker.tscn").instantiate()
	w.global_position = Vector2(64, 0)
	add_child(w)
	world_workers.register_worker(w)

func _on_btn_craft_pressed() -> void:
	panel_crafting.visible = not panel_crafting.visible
	if panel_crafting.visible:
		panel_inventory.visible = false

# =========================================================
# API PÚBLICA
# =========================================================
func select_worker(w: CharacterBody2D) -> void:
	world_workers.select_worker(w)
