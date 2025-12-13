extends Panel

# ============================================================
#        REFERENCIAS A NODOS (TIPADAS)
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
#        WORKER SELECCIONADO
# ============================================================
var worker_ref: CharacterBody2D = null

signal deselect_requested

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	if btn_test_hacha:
		btn_test_hacha.pressed.connect(_on_test_hacha)

	if btn_deselect:
		btn_deselect.pressed.connect(_on_deselect_pressed)

	visible = false

# ============================================================
# ASIGNAR WORKER
# ============================================================
func set_worker(worker: CharacterBody2D) -> void:
	# desconectar del anterior
	if worker_ref != null:
		if worker_ref.is_connected("cargo_changed", Callable(self, "_on_cargo_changed")):
			worker_ref.disconnect("cargo_changed", Callable(self, "_on_cargo_changed"))

	worker_ref = worker
	label_title.text = "Worker seleccionado"
	visible = true

	if worker_ref != null:
		worker_ref.connect("cargo_changed", Callable(self, "_on_cargo_changed"))

	_update_slots()

# ============================================================
# BOTÓN DESELECCIONAR
# ============================================================
func _on_deselect_pressed() -> void:
	deselect_requested.emit()

# ============================================================
# BOTÓN TEST – EQUIPAR HACHA
# ============================================================
func _on_test_hacha() -> void:
	if worker_ref == null:
		return

	var path := "res://items/hacha.tres"
	if not ResourceLoader.exists(path):
		push_error("PanelWorker: no existe hacha.tres")
		return

	var hacha := load(path) as ItemData
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

	# ---------------- HAND ----------------
	var it_hand: ItemData = eq.get("hand", null)
	if it_hand != null:
		slot_hand.modulate = Color(0.6, 1.0, 0.6)
		label_hand.text = it_hand.nombre
	else:
		slot_hand.modulate = Color(0.25, 0.25, 0.25)
		label_hand.text = "mano"

	# ---------------- CHEST ----------------
	var it_chest: ItemData = eq.get("chest", null)
	if it_chest != null:
		slot_chest.modulate = Color(0.7, 0.7, 1.0)
		label_chest.text = it_chest.nombre
	else:
		slot_chest.modulate = Color(0.25, 0.25, 0.25)
		label_chest.text = "pecho"

	# ---------------- OFF-HAND ----------------
	var it_off: ItemData = eq.get("off_hand", null)
	if it_off != null:
		slot_off_hand.modulate = Color(0.7, 0.9, 1.0)
		label_off_hand.text = it_off.nombre
	else:
		slot_off_hand.modulate = Color(0.25, 0.25, 0.25)
		label_off_hand.text = "mano 2"

	# ---------------- CARGO ----------------
	var cargo: Array[ItemData] = worker_ref.cargo
	if cargo.is_empty():
		label_extra.text = "vacío"
		slot_extra.modulate = Color(0.25, 0.25, 0.25)
	else:
		var it_extra: ItemData = cargo[0]
		label_extra.text = it_extra.nombre
		slot_extra.modulate = Color(1.0, 0.9, 0.4)

# ============================================================
# SEÑAL CARGO
# ============================================================
func _on_cargo_changed() -> void:
	_update_slots()
