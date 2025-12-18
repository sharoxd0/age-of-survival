extends Node
class_name InventoryManager

# =========================================================
# DATOS
# =========================================================
# key (String) -> cantidad (int)
# - Apilables:   "madera" -> 12
# - No apilable: "hacha_123456" -> 1
var items: Dictionary[String, int] = {}

# =========================================================
# SEÑALES
# =========================================================
signal inventory_changed(item_id: String, new_amount: int)

# =========================================================
# HELPERS
# =========================================================
func _base_id(id: String) -> String:
	if id == "":
		return ""
	# 🔥 Quitar sufijo si es ID único (hacha_123456)
	# OJO: asume que el sufijo único es numérico y que el id base no usa "_"
	# (si luego quieres ids con "_" lo cambiamos)
	if "_" in id:
		return id.split("_")[0]
	return id

func _is_unique_id(id: String) -> bool:
	return "_" in id

# =========================================================
# AGREGAR ÍTEM por ID (MODELO B)
# =========================================================
func add(item_id: String, amount: int = 1) -> void:
	if item_id == "" or amount <= 0:
		return

	var base := _base_id(item_id)
	var item: ItemData = get_item_data(base)
	if item == null:
		return

	# ============================
	# APILABLE
	# ============================
	if item.apilable:
		items[base] = items.get(base, 0) + amount
		inventory_changed.emit(base, items[base])
		return

	# ============================
	# NO APILABLE (HERRAMIENTAS / ARMAS / ARMADURAS)
	# ============================
	for i in range(amount):
		var unique_id := "%s_%d" % [base, Time.get_ticks_usec()]
		items[unique_id] = 1
		inventory_changed.emit(unique_id, 1)

# =========================================================
# AGREGAR ÍTEM por ItemData (compatibilidad workers/cargo)
# =========================================================
func add_item(item: ItemData, amount: int = 1) -> void:
	if item == null or item.id == "" or amount <= 0:
		return
	add(item.id, amount)

# =========================================================
# QUITAR ÍTEM
# =========================================================
func remove(item_id: String, amount: int = 1) -> bool:
	if item_id == "" or amount <= 0:
		return false

	# Si existe tal cual (apilable o unique exacto)
	if items.has(item_id):
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

	# Si NO existe tal cual, intentamos por base_id (para no apilables)
	var base := _base_id(item_id)

	# Apilables por base
	if items.has(base):
		return remove(base, amount)

	# No apilables: eliminar N instancias únicas "base_*"
	var removed := 0
	var keys := items.keys() # copia

	for k in keys:
		if removed >= amount:
			break
		if _base_id(k) == base:
			# cada unique vale 1
			items.erase(k)
			inventory_changed.emit(k, 0)
			removed += 1

	if removed > 0:
		print("[INVENTORY] -", base, "x", removed)
		return removed == amount

	return false

# =========================================================
# CONSULTAS
# =========================================================
func get_amount(item_id: String) -> int:
	if item_id == "":
		return 0

	# Si existe tal cual, devolverlo
	if items.has(item_id):
		return items[item_id]

	# Si piden base_id, sumar todas las instancias (apilables o uniques)
	var base := _base_id(item_id)

	# apilable directo
	if items.has(base):
		return items[base]

	# sumar uniques
	var total := 0
	for k in items.keys():
		if _base_id(k) == base:
			total += items[k]
	return total

func has(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount

func get_all() -> Dictionary:
	return items.duplicate(true)

# =========================================================
# UTILIDADES
# =========================================================
func clear() -> void:
	items.clear()
	print("[INVENTORY] limpiado")

func get_item_data(item_id: String) -> ItemData:
	var base := _base_id(item_id)
	if base == "":
		return null

	var path := "res://items/%s.tres" % base
	if not ResourceLoader.exists(path):
		push_error("[INV] ItemData no existe: " + path)
		return null

	return load(path) as ItemData
