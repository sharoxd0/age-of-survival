extends Panel
class_name WorkerEquipSlot

@export var slot_id: String = ""   # "hand", "off_hand", etc.

var worker: CharacterBody2D = null
var inventory_manager: InventoryManager = null

@onready var label: Label = $LabelSlot
@onready var icon: TextureRect = $Icon

# =========================================================
func _ready() -> void:
	# 🔥 CLAVE ABSOLUTA
	mouse_filter = Control.MOUSE_FILTER_STOP

	if label == null:
		push_warning("[EQUIP SLOT] Falta LabelSlot en " + str(get_path()))
	if icon == null:
		push_warning("[EQUIP SLOT] Falta Icon en " + str(get_path()))

# =========================================================
func setup(w: CharacterBody2D, inv: InventoryManager) -> void:
	worker = w
	inventory_manager = inv

# =========================================================
func set_item(item: ItemData) -> void:
	if item == null:
		label.text = slot_id.capitalize()
		icon.texture = null
		modulate = Color(0.5, 0.5, 0.5)
	else:
		label.text = item.nombre
		icon.texture = item.icono
		modulate = Color.WHITE

# =========================================================
# CLICK → DESEQUIPAR
# =========================================================
func _gui_input(event: InputEvent) -> void:
	if slot_id == "extra":
		return # ❌ cargo no es equipamiento
	if event is InputEventMouseButton and event.pressed:
		print("[EQUIP SLOT] CLICK:", slot_id)
		_try_unequip()

# =========================================================
func _try_unequip() -> void:
	if worker == null or inventory_manager == null:
		print("[EQUIP SLOT] ❌ sin referencias")
		return

	var item: ItemData = worker.equipment.get(slot_id)
	if item == null:
		print("[EQUIP SLOT] slot vacío")
		return

	print("[EQUIP] ❎ Desequipar:", item.nombre)

	# 1️⃣ quitar del worker
	worker.equipment[slot_id] = null
	worker.emit_signal("cargo_changed")

	# 2️⃣ devolver al inventario
	inventory_manager.add_item(item, 1)

	# 3️⃣ refrescar UI
	set_item(null)
