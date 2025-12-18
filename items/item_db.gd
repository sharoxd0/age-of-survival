extends Node
class_name ItemDB

static func get_item(item_id: String) -> ItemData:
	var path := "res://items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		push_error("[ItemDB] No existe ItemData: " + path)
		return null
	return load(path) as ItemData
