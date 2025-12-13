extends Panel

@export var world: Node2D

# ============================================================
# REFERENCIAS A NODOS
# ============================================================
@onready var label_title: Label = $LabelNombre

@onready var slot_hand: Panel     = $HBoxSlots/SlotHand
@onready var slot_chest: Panel    = $HBoxSlots/SlotChest
@onready var slot_off_hand: Panel = $HBoxSlots/SlotOffHand
@onready var slot_extra: Panel    = $HBoxSlots/SlotExtra

@onready var label_hand: Label     = $HBoxSlots/SlotHand/LabelItemName
@onready var label_chest: Label    = $HBoxSlots/SlotChest/LabelItemName
@onready var label_off_hand: Label = $HBoxSlots/SlotOffHand/LabelItemName
@onready var label_extra: Label    = $HBoxSlots/SlotExtra/LabelItemName

@onready var btn_test_hacha: Button = $ButtonEquiparHacha
@onready var btn_deselect: Button  = $ButtonDeseleccionar

# ============================================================
# WORKER SELECCIONADO
# ============================================================
var worker_ref: CharacterBody2D = null

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	if btn_test_hacha:
		btn_test_hacha.pressed.connect(_on_test_hacha)

	if btn_deselect:
		btn_deselect.pressed.connect(_on_btn_deselect_pressed)

	visible = false

# ============================================================
# ASIGNAR WORKER
# ============================================================
func set_worker(worker: CharacterBody2D) -> void:
	_clear_worker_connection()

	worker_ref = worker
	if worker_ref == null:
		visible = false
		return

	label_title.text = "Worker seleccionado"
	visible = true

	worker_ref.cargo_changed.connect(_on_cargo_changed)

	_update_slots()

# ============================================================
# BOTÓN DESELECCIONAR (CLAVE)
# ============================================================
func _on_btn_deselect_pressed() -> void:
	if world == null or world.world_workers == null:
		return

	# 🔑 deselección REAL (lógica)
	world.world_workers.deselect_worker()

	# 🔒 limpieza LOCAL del panel
	_clear_worker_connection()
	visible = false

# ============================================================
# LIMPIEZA SEGURA
# ============================================================
func _clear_worker_connection() -> void:
	if worker_ref != null and is_instance_valid(worker_ref):
		if worker_ref.cargo_changed.is_connected(_on_cargo_changed):
			worker_ref.cargo_changed.disconnect(_on_cargo_changed)

	worker_ref = null

# ============================================================
# BOTÓN TEST – EQUIPAR HACHA
# ============================================================
func _on_test_hacha() -> void:
	if worker_ref == null:
		return

	var path: String = "res://items/hacha.tres"
	if not ResourceLoader.exists(path):
		push_error("PanelWorker: no existe hacha.tres")
		return

	var hacha: ItemData = load(path)
	if hacha == null:
		return

	var ok: bool = worker_ref.equip_item(hacha, "hand")
	print("PanelWorker: equipar hacha →", ok)

	_update_slots()

# ============================================================
# ACTUALIZAR SLOTS
# ============================================================
func _update_slots() -> void:
	if worker_ref == null:
		return

	var eq: Dictionary = worker_ref.equipment

	# HAND
	var it_hand: ItemData = eq.get("hand")
	if it_hand:
		slot_hand.modulate = Color(0.6, 1.0, 0.6)
		label_hand.text = it_hand.nombre
	else:
		slot_hand.modulate = Color(0.25, 0.25, 0.25)
		label_hand.text = "mano"

	# CHEST
	var it_chest: ItemData = eq.get("chest")
	if it_chest:
		slot_chest.modulate = Color(0.7, 0.7, 1.0)
		label_chest.text = it_chest.nombre
	else:
		slot_chest.modulate = Color(0.25, 0.25, 0.25)
		label_chest.text = "pecho"

	# OFF HAND
	var it_off: ItemData = eq.get("off_hand")
	if it_off:
		slot_off_hand.modulate = Color(0.7, 0.9, 1.0)
		label_off_hand.text = it_off.nombre
	else:
		slot_off_hand.modulate = Color(0.25, 0.25, 0.25)
		label_off_hand.text = "mano 2"

	# CARGO (slot único)
	var cargo: Array[ItemData] = worker_ref.cargo
	if cargo.is_empty():
		label_extra.text = "vacío"
		slot_extra.modulate = Color(0.25, 0.25, 0.25)
	else:
		label_extra.text = cargo[0].nombre
		slot_extra.modulate = Color(1.0, 0.9, 0.4)

# ============================================================
# SEÑAL DE CARGO
# ============================================================
func _on_cargo_changed() -> void:
	_update_slots()
