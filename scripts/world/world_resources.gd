extends Node2D

@export var world: Node2D

# =========================================================
# DEFINICIÓN DE RECURSOS (source|atlas)
# =========================================================
const RESOURCE_DEFS := {
	"0|(0, 0)": {
		"nombre": "Árbol",
		"descripcion": "Un árbol que puedes talar.",
		"item_id": "madera",
		"tool_required": "hacha",
		"amount": 3
	}
}

const SMALL_RESOURCE_DEFS := {
	"1|(0, 0)": {
		"nombre": "Rama",
		"descripcion": "Una rama en el suelo.",
		"item_id": "madera"
	},
	"2|(0, 0)": {
		"nombre": "Piedra pequeña",
		"descripcion": "Una piedra suelta.",
		"item_id": "piedra"
	}
}

# =========================================================
# ESTADO DE RECURSOS GRANDES
# =========================================================
var resource_amounts: Dictionary[Vector2i, int] = {}

# =========================================================
# INIT
# =========================================================
func init_resources(resources_tilemap: TileMapLayer) -> void:
	resource_amounts.clear()

	for cell: Vector2i in resources_tilemap.get_used_cells():
		var src: int = resources_tilemap.get_cell_source_id(cell)
		var atlas: Vector2i = resources_tilemap.get_cell_atlas_coords(cell)
		var key := "%d|%s" % [src, atlas]

		var def: Dictionary = RESOURCE_DEFS.get(key, {})
		resource_amounts[cell] = int(def.get("amount", 1))

		print("[RESOURCES] init cell:", cell, "key:", key, "amount:", resource_amounts[cell])

# =========================================================
# DEFINICIONES
# =========================================================
func get_big_def(source_id: int, atlas: Vector2i) -> Dictionary:
	var key := "%d|%s" % [source_id, atlas]
	return RESOURCE_DEFS.get(key, {})

func get_small_def(source_id: int, atlas: Vector2i) -> Dictionary:
	var key := "%d|%s" % [source_id, atlas]
	return SMALL_RESOURCE_DEFS.get(key, {})

# =========================================================
# CONSUMO DE RECURSOS
# =========================================================
func has_resource(cell: Vector2i) -> bool:
	return resource_amounts.has(cell)

func consume_resource(cell: Vector2i) -> bool:
	if not resource_amounts.has(cell):
		return false

	resource_amounts[cell] -= 1
	return resource_amounts[cell] > 0

# =========================================================
# BUSCAR SIGUIENTE RECURSO GRANDE
# =========================================================
func find_nearest_big_resource(
	from_pos: Vector2,
	tilemap: TileMapLayer
) -> Vector2i:

	var best_cell := Vector2i(-1, -1)
	var best_dist := INF

	for cell: Vector2i in resource_amounts.keys():

		# 🔒 VALIDACIÓN CRÍTICA
		if tilemap.get_cell_source_id(cell) == -1:
			continue

		var world_pos := tilemap.map_to_local(cell)
		var d := from_pos.distance_to(world_pos)

		if d < best_dist:
			best_dist = d
			best_cell = cell

	return best_cell
# =========================================================
# POSICIÓN ÓPTIMA PARA TALAR (EDGE)
# =========================================================
func get_best_edge_target_for_cell(
	w: CharacterBody2D,
	cell: Vector2i,
	tilemap: TileMapLayer
) -> Vector2:
	var world_pos: Vector2 = tilemap.to_global(
		tilemap.map_to_local(cell)
	)

	var s: Vector2 = Vector2(tilemap.tile_set.tile_size)

	var options: Array[Vector2] = [
		world_pos + Vector2(0, -s.y * 0.5),
		world_pos + Vector2(0,  s.y * 0.5),
		world_pos + Vector2(-s.x * 0.5, 0),
		world_pos + Vector2( s.x * 0.5, 0)
	]

	var best: Vector2 = options[0]
	for p: Vector2 in options:
		if w.global_position.distance_to(p) < w.global_position.distance_to(best):
			best = p

	return best

# =========================================================
# ITEM DATA
# =========================================================
func get_item_data(item_id: String) -> ItemData:
	var path := "res://items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		push_error("[RESOURCES] ItemData no existe: " + path)
		return null

	return load(path) as ItemData

# =========================================================
# PANEL DE RECURSO (UI)
# =========================================================
func update_resource_panel(
	panel: Panel,
	label_name: Label,
	label_desc: Label,
	label_loot: Label,
	label_req: Label,
	btn_collect: Button,
	active_worker: CharacterBody2D,
	pressed_cell: Vector2i,
	pressed_source_id: int,
	pressed_atlas: Vector2i
) -> void:
	var def: Dictionary = get_big_def(pressed_source_id, pressed_atlas)
	if def.is_empty():
		panel.visible = false
		return

	var remaining: int = resource_amounts.get(pressed_cell, 0)
	var item: ItemData = get_item_data(def["item_id"])
	if item == null:
		panel.visible = false
		return

	label_name.text = def["nombre"]
	label_desc.text = def["descripcion"]
	label_loot.text = "%s x%d" % [item.nombre, remaining]

	if active_worker == null:
		btn_collect.disabled = true
		label_req.text = "Selecciona un worker"
	else:
		var req: String = String(def.get("tool_required", ""))
		btn_collect.disabled = (req != "" and not active_worker.has_tool(req))
		label_req.text = req

	panel.visible = true
