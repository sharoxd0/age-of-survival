extends Panel

# =========================================================
# CONFIGURACIÓN
# =========================================================
@export var total_slots: int = 30          # capacidad inicial
@export var columns: int = 6               # columnas del grid
@export var slot_scene: PackedScene        # InventorySlot.tscn

# =========================================================
# NODOS
# =========================================================
@onready var grid: GridContainer = $CenterContainer/VBoxContainer/MarginContainer/Grid

# =========================================================
# ESTADO
# =========================================================
var inventory_manager: InventoryManager
var slots: Array[InventorySlot] = []

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	print("=== PANEL INVENTARIO READY ===")

	if slot_scene == null:
		push_error("❌ slot_scene NO asignado (InventorySlot.tscn)")
		return

	if grid == null:
		push_error("❌ GridContainer NO encontrado")
		return

	grid.columns = columns
	_create_slots()

	print("Slots creados:", slots.size())
	print("=== FIN PANEL INVENTARIO ===")

# =========================================================
# CONECTAR INVENTARIO
# =========================================================
func set_inventory_manager(im: InventoryManager) -> void:
	inventory_manager = im

	if inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
		inventory_manager.inventory_changed.disconnect(_on_inventory_changed)

	inventory_manager.inventory_changed.connect(_on_inventory_changed)
	_refresh()

# =========================================================
# CREAR SLOTS
# =========================================================
func _create_slots() -> void:
	print("=== _create_slots() ===")

	# limpiar grid
	for c in grid.get_children():
		c.queue_free()

	slots.clear()

	for i in range(total_slots):
		var slot := slot_scene.instantiate() as InventorySlot
		grid.add_child(slot)
		slots.append(slot)

		print("Slot añadido:", i, "->", slot)

	print("=== FIN _create_slots() ===")

# =========================================================
# ACTUALIZAR UI
# =========================================================
func _refresh() -> void:
	if inventory_manager == null:
		return

	var items: Dictionary = inventory_manager.get_all()

	# limpiar slots
	for s in slots:
		s.clear()

	var index := 0
	for id in items.keys():
		if index >= slots.size():
			break

		var item: ItemData = load("res://items/%s.tres" % id)
		if item == null:
			continue

		slots[index].set_item(item, items[id])
		index += 1

# =========================================================
# CALLBACK INVENTARIO
# =========================================================
func _on_inventory_changed(item_id: String, new_amount: int) -> void:
	print("[INVENTARIO] cambiado:", item_id, "->", new_amount)
	_refresh()
