extends Node
class_name InventoryManager

var items: Dictionary[String, int] = {}

signal inventory_changed(item_id: String, new_amount: int)

func add(item_id: String, amount: int = 1) -> void:
	items[item_id] = items.get(item_id, 0) + amount
	inventory_changed.emit(item_id, items[item_id])

func remove(item_id: String, amount: int = 1) -> bool:
	if not items.has(item_id):
		return false
	if items[item_id] < amount:
		return false

	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)

	inventory_changed.emit(item_id, items.get(item_id, 0))
	return true

func get_all() -> Dictionary:
	return items.duplicate()
