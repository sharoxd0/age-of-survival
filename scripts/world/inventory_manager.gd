extends Node
class_name InventoryManager

# =========================================================
# DATOS
# =========================================================
# item_id (String) -> cantidad (int)
var items: Dictionary[String, int] = {}

# =========================================================
# SEÑALES
# =========================================================
signal inventory_changed(item_id: String, new_amount: int)

# =========================================================
# AGREGAR ÍTEM
# =========================================================
func add(item_id: String, amount: int = 1) -> void:
	if item_id == "" or amount <= 0:
		return

	items[item_id] = items.get(item_id, 0) + amount
	print("[INVENTORY] +", item_id, "x", amount, "→ total:", items[item_id])

	inventory_changed.emit(item_id, items[item_id])

# =========================================================
# QUITAR ÍTEM
# =========================================================
func remove(item_id: String, amount: int = 1) -> bool:
	if not items.has(item_id):
		return false

	if items[item_id] < amount:
		return false

	items[item_id] -= amount

	if items[item_id] <= 0:
		items.erase(item_id)
		inventory_changed.emit(item_id, 0)
	else:
		inventory_changed.emit(item_id, items[item_id])

	print("[INVENTORY] -", item_id, "x", amount)
	return true

# =========================================================
# CONSULTAS
# =========================================================
func get_amount(item_id: String) -> int:
	return items.get(item_id, 0)

func has(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount

func get_all() -> Dictionary:
	# Copia segura (no devuelve la referencia original)
	return items.duplicate(true)

# =========================================================
# UTILIDADES
# =========================================================
func clear() -> void:
	items.clear()
	print("[INVENTORY] limpiado")
