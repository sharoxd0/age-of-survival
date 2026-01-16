extends Node2D

@export var world: Node2D
@export var resources_manager: Node2D   # world_resources.gd

signal worker_selected(worker: CharacterBody2D)
signal worker_deselected()

# =========================================================
# WORKERS
# =========================================================
var active_worker: CharacterBody2D = null

enum TaskMode {
	NONE,
	MANUAL,
	AUTO_BIG_RESOURCE
}

var worker_task_mode: Dictionary = {}
var worker_task_is_small: Dictionary = {}
var worker_active_cell: Dictionary = {}
var worker_active_source: Dictionary = {}
var worker_active_atlas: Dictionary = {}

# =========================================================
# REGISTRAR WORKER
# =========================================================
func register_worker(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	w.add_to_group("workers")

	worker_task_mode[w] = TaskMode.NONE
	worker_task_is_small[w] = false
	worker_active_cell[w] = Vector2i(-1, -1)
	worker_active_source[w] = -1
	worker_active_atlas[w] = Vector2i.ZERO

	if w.has_method("set_selected"):
		w.set_selected(false)

	w.arrived_to_resource.connect(_on_worker_arrived)
	w.arrived_home.connect(_on_worker_arrived_home)

	print("[WORKERS] worker registrado:", w.name)

# =========================================================
# SELECCIÓN
# =========================================================
func select_worker(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	if active_worker and is_instance_valid(active_worker):
		if active_worker.has_method("set_selected"):
			active_worker.set_selected(false)

	active_worker = w

	if w.has_method("set_selected"):
		w.set_selected(true)

	emit_signal("worker_selected", w)
	print("[WORKERS] Worker seleccionado:", w.name)

func deselect_worker() -> void:
	if active_worker and is_instance_valid(active_worker):
		if active_worker.has_method("set_selected"):
			active_worker.set_selected(false)

	active_worker = null
	emit_signal("worker_deselected")

# =========================================================
# CALLBACK: LLEGÓ AL RECURSO
# =========================================================
func _on_worker_arrived(w: CharacterBody2D, cell: Vector2i) -> void:
	if not is_instance_valid(w):
		return

	if worker_task_is_small.get(w, false):
		_handle_small_resource(w, cell)
	else:
		_handle_big_resource(w, cell)

# =========================================================
# SMALL RESOURCE
# =========================================================
func _handle_small_resource(w: CharacterBody2D, cell: Vector2i) -> void:
	var src_id: int = world.resources_small.get_cell_source_id(cell)
	var atlas: Vector2i = world.resources_small.get_cell_atlas_coords(cell)

	var def: Dictionary = resources_manager.get_small_def(src_id, atlas)
	if def.is_empty():
		return

	var item: ItemData = resources_manager.get_item_data(String(def["item_id"]))
	if item == null:
		return

	w.cargo.clear()
	w.cargo.append(item)
	w.emit_signal("cargo_changed")

	world.resources_small.set_cell(cell, -1)
	w.go_home()

# =========================================================
# BIG RESOURCE
# =========================================================
func _handle_big_resource(w: CharacterBody2D, cell: Vector2i) -> void:
	if not resources_manager.has_resource(cell):
		w.go_home()
		return

	var src: int = int(worker_active_source.get(w, -1))
	var atlas: Vector2i = worker_active_atlas.get(w, Vector2i.ZERO)

	var def: Dictionary = resources_manager.get_big_def(src, atlas)
	if def.is_empty():
		w.go_home()
		return

	var item: ItemData = resources_manager.get_item_data(String(def["item_id"]))
	if item == null:
		return

	w.cargo.clear()
	w.cargo.append(item)
	w.emit_signal("cargo_changed")

	var still_exists: bool = resources_manager.consume_resource(cell)

	if not still_exists:
		world.resources.set_cell(cell, -1)
		world.ground.notify_runtime_tile_data_update()

	w.go_home()

# =========================================================
# CALLBACK: LLEGÓ A CASA
# =========================================================
func _on_worker_arrived_home(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	if not w.cargo.is_empty():
		for item: ItemData in w.cargo:
			world.inventory_manager.add_item(item, 1)

		w.cargo.clear()
		w.emit_signal("cargo_changed")

	if worker_task_mode.get(w, TaskMode.NONE) == TaskMode.MANUAL:
		return

	if worker_task_mode.get(w) != TaskMode.AUTO_BIG_RESOURCE:
		return

	var next_cell: Vector2i = resources_manager.find_nearest_big_resource(
		w.global_position,
		world.resources
	)

	if next_cell == Vector2i(-1, -1):
		return

	var src: int = world.resources.get_cell_source_id(next_cell)
	if src == -1:
		return

	var atlas: Vector2i = world.resources.get_cell_atlas_coords(next_cell)
	var def: Dictionary = resources_manager.get_big_def(src, atlas)
	if def.is_empty():
		return

	var req: String = String(def.get("tool_required", ""))
	if req != "" and not w.has_tool(req):
		return

	var target: Vector2 = resources_manager.get_best_edge_target_for_cell(
		w,
		next_cell,
		world.resources
	)

	worker_task_mode[w] = TaskMode.AUTO_BIG_RESOURCE
	worker_task_is_small[w] = false
	worker_active_cell[w] = next_cell
	worker_active_source[w] = src
	worker_active_atlas[w] = atlas

	w.move_to_edge(target, next_cell)

# =========================================================
# INTENTAR RECOLECTAR (CLICK MANUAL)
# =========================================================
func try_collect_with_active_worker() -> void:
	if world == null or resources_manager == null:
		return

	var w: CharacterBody2D = active_worker
	if w == null or not is_instance_valid(w):
		return

	w.release_joystick()

	if w.is_cargo_full():
		return

	var cell: Vector2i = world.pressed_cell
	var src: int = world.pressed_source_id
	var atlas: Vector2i = world.pressed_atlas
	var is_small: bool = world.pressed_is_small

	if cell == Vector2i(-1, -1) or src == -1:
		return

	# SMALL
	if is_small:
		var def_s: Dictionary = resources_manager.get_small_def(src, atlas)
		if def_s.is_empty():
			return

		worker_task_mode[w] = TaskMode.MANUAL
		worker_task_is_small[w] = true
		worker_active_cell[w] = cell
		worker_active_source[w] = src
		worker_active_atlas[w] = atlas

		var target: Vector2 = world.resources_small.to_global(
			world.resources_small.map_to_local(cell)
		)

		w.move_to_edge(target, cell)
		return

	# BIG
	var def: Dictionary = resources_manager.get_big_def(src, atlas)
	if def.is_empty():
		return

	var req: String = String(def.get("tool_required", ""))
	if req != "" and not w.has_tool(req):
		print("[WORKERS] ❌ falta herramienta:", req)
		return

	worker_task_mode[w] = TaskMode.AUTO_BIG_RESOURCE
	worker_task_is_small[w] = false
	worker_active_cell[w] = cell
	worker_active_source[w] = src
	worker_active_atlas[w] = atlas

	var target_big: Vector2 = resources_manager.get_best_edge_target_for_cell(
		w,
		cell,
		world.resources
	)

	w.move_to_edge(target_big, cell)
	world.panel_resource.visible = false
