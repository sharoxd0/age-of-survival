extends Node2D

@export var world: Node2D
@export var resources_manager: Node2D   # world_resources.gd

# =========================================================
# WORKERS
# =========================================================
var active_worker: CharacterBody2D = null
enum TaskMode {
	NONE,
	MANUAL,
	AUTO_BIG_RESOURCE
}
var worker_task_mode: Dictionary[CharacterBody2D, int] = {}
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

	worker_task_is_small[w] = false
	worker_active_cell[w] = Vector2i(-1, -1)
	worker_active_source[w] = -1
	worker_active_atlas[w] = Vector2i.ZERO

	w.arrived_to_resource.connect(_on_worker_arrived)
	w.arrived_home.connect(_on_worker_arrived_home)

	print("[WORKERS] worker registrado:", w)

# =========================================================
# ORDENAR RECOLECCIÓN
# =========================================================
func order_collect(
	w: CharacterBody2D,
	cell: Vector2i,
	source_id: int,
	atlas: Vector2i,
	is_small: bool,
	target_world_pos: Vector2
) -> void:
	if not is_instance_valid(w):
		return

	active_worker = w

	worker_task_is_small[w] = is_small
	worker_active_cell[w] = cell
	worker_active_source[w] = source_id
	worker_active_atlas[w] = atlas

	print("[WORKERS] orden recolectar → cell:", cell, "small:", is_small)

	w.move_to_edge(target_world_pos, cell)

# =========================================================
# CALLBACK: LLEGÓ AL RECURSO
# =========================================================
func _on_worker_arrived(w: CharacterBody2D, cell: Vector2i) -> void:
	if not is_instance_valid(w):
		return

	print("[WORKERS] arrived_to_resource:", cell)

	if worker_task_is_small.get(w, false):
		_handle_small_resource(w, cell)
	else:
		_handle_big_resource(w, cell)

# =========================================================
# SMALL RESOURCE
# =========================================================
func _handle_small_resource(w: CharacterBody2D, cell: Vector2i) -> void:
	# 🔑 leer SIEMPRE desde el TileMap
	var src_id: int = world.resources_small.get_cell_source_id(cell)
	var atlas_coords: Vector2i = world.resources_small.get_cell_atlas_coords(cell)

	print(
		"[DEBUG SMALL]",
		"cell:", cell,
		"source:", src_id,
		"atlas:", atlas_coords
	)

	var small_def: Dictionary = resources_manager.get_small_def(src_id, atlas_coords)
	if small_def.is_empty():
		print("[WORKERS] ❌ small def vacío para", src_id, atlas_coords)
		return

	var item_data: ItemData = resources_manager.get_item_data(small_def["item_id"])
	if item_data == null:
		return

	# cargar ítem
	w.cargo.clear()
	w.cargo.append(item_data)
	w.emit_signal("cargo_changed")

	# eliminar tile del mapa
	world.resources_small.set_cell(cell, -1)

	print("[WORKERS] ✔ small recolectado:", item_data.id)

	# volver a casa
	w.go_home()# =========================================================
# BIG RESOURCE
# =========================================================
func _handle_big_resource(w: CharacterBody2D, cell: Vector2i) -> void:
	if not resources_manager.has_resource(cell):
		print("[WORKERS] ❌ recurso ya no existe:", cell)
		w.go_home()
		return

	var def: Dictionary = resources_manager.get_big_def(
		worker_active_source[w],
		worker_active_atlas[w]
	)
	if def.is_empty():
		print("[WORKERS] ❌ definición vacía")
		w.go_home()
		return

	var item: ItemData = resources_manager.get_item_data(def["item_id"])
	if item == null:
		return

	# cargar 1 item
	w.cargo.clear()
	w.cargo.append(item)
	w.emit_signal("cargo_changed")

	# consumir recurso
	var still_exists: bool = resources_manager.consume_resource(cell)
	print("[WORKERS] big loot, sigue existiendo:", still_exists)

	# si se agotó → borrar tile
	if not still_exists:
		world.resources.set_cell(cell, -1)
		world.ground.notify_runtime_tile_data_update()
		worker_active_cell[w] = Vector2i(-1, -1)

	# volver a casa SIEMPRE
	w.go_home()

# =========================================================
# CALLBACK: LLEGÓ A CASA
# =========================================================
func _on_worker_arrived_home(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	print("[WORKERS] arrived_home")

	# =====================================
	# 1️⃣ DEPOSITAR CARGO EN INVENTARIO GLOBAL
	# =====================================
	if not w.cargo.is_empty():
		for item: ItemData in w.cargo:
			world.inventory_manager.add(item.id, 1)
			print("[WORKERS] 📦 depositado:", item.id)

		w.cargo.clear()
		w.emit_signal("cargo_changed")

	# =====================================
	# 2️⃣ MODO MANUAL → DETENER TODO
	# =====================================
	if worker_task_mode.get(w, TaskMode.MANUAL) == TaskMode.MANUAL:
		print("[WORKERS] modo manual → detener")

		worker_active_cell[w] = Vector2i(-1, -1)
		worker_active_source[w] = -1
		worker_active_atlas[w] = Vector2i.ZERO
		worker_task_is_small[w] = false

		return  # ⛔ NO continuar automático

	# =====================================
	# 3️⃣ SOLO AUTO_BIG_RESOURCE CONTINÚA
	# =====================================
	if worker_task_mode.get(w) != TaskMode.AUTO_BIG_RESOURCE:
		print("[WORKERS] modo no-auto → detener")
		return

	# =====================================
	# 4️⃣ BUSCAR SIGUIENTE ÁRBOL
	# =====================================
	var cell: Vector2i = resources_manager.find_nearest_big_resource(
		w.global_position,
		world.resources
	)

	if cell == Vector2i(-1, -1):
		print("[WORKERS] 🌲 no hay más recursos")
		return

	var src: int = world.resources.get_cell_source_id(cell)
	if src == -1:
		print("[WORKERS] ❌ tile inválido")
		return

	var atlas: Vector2i = world.resources.get_cell_atlas_coords(cell)
	var def: Dictionary = resources_manager.get_big_def(src, atlas)

	if def.is_empty():
		print("[WORKERS] ❌ definición inválida")
		return

	# =====================================
	# 5️⃣ VALIDAR HERRAMIENTA
	# =====================================
	var req: String = String(def.get("tool_required", ""))
	if req != "" and not w.has_tool(req):
		print("[WORKERS] ⛔ auto cancelado → falta herramienta:", req)
		return

	# =====================================
	# 6️⃣ ORDENAR SIGUIENTE RECOLECCIÓN
	# =====================================
	print("[WORKERS] 🌲 nuevo recurso:", cell)

	var target: Vector2 = resources_manager.get_best_edge_target_for_cell(
		w,
		cell,
		world.resources
	)

	order_collect(
		w,
		cell,
		src,
		atlas,
		false,
		target
	)# SELECCIÓN DE WORKER
# =========================================================
func select_worker(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	for node in get_tree().get_nodes_in_group("workers"):
		if node is CharacterBody2D and is_instance_valid(node):
			node.set_selected(false)

	active_worker = w
	w.set_selected(true)

	world.panel_worker.set_worker(w)
	world.panel_worker.visible = true

	print("[WORKERS] Worker seleccionado:", w)

# =========================================================
# INTENTAR RECOLECTAR (CLICK MANUAL)
# =========================================================
func try_collect_with_active_worker() -> void:
	if world == null or resources_manager == null:
		return

	var w: CharacterBody2D = active_worker
	if w == null or not is_instance_valid(w):
		return

	if w.is_cargo_full():
		return

	var cell: Vector2i = world.pressed_cell
	var src: int = world.pressed_source_id
	var atlas: Vector2i = world.pressed_atlas
	var is_small: bool = world.pressed_is_small

	# Validación básica
	if cell == Vector2i(-1, -1) or src == -1:
		return

	print("[WORKERS] try_collect → cell:", cell, "small:", is_small)

	# =================================================
	# 🌿 SMALL RESOURCE → MANUAL PURO (NO AUTO)
	# =================================================
	if is_small:
		var def_s: Dictionary = resources_manager.get_small_def(src, atlas)
		if def_s.is_empty():
			return

		# 🔒 FORZAR MODO MANUAL
		worker_task_mode[w] = TaskMode.MANUAL

		# 🔥 LIMPIAR CUALQUIER CONTEXTO AUTO PREVIO
		worker_task_is_small[w] = true
		worker_active_cell[w] = cell
		worker_active_source[w] = src
		worker_active_atlas[w] = atlas

		var target: Vector2 = world.resources_small.to_global(
			world.resources_small.map_to_local(cell)
		)

		w.move_to_edge(target, cell)
		return

	# =================================================
	# 🌲 BIG RESOURCE → AUTO SOLO CON HERRAMIENTA
	# =================================================
	var def: Dictionary = resources_manager.get_big_def(src, atlas)
	if def.is_empty():
		return

	var req: String = String(def.get("tool_required", ""))
	if req != "" and not w.has_tool(req):
		print("[WORKERS] ❌ falta herramienta:", req)
		return

	# ✅ AUTO PERMITIDO
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

	# UI
	world.panel_resource.visible = false
func deselect_worker() -> void:
	if active_worker != null and is_instance_valid(active_worker):
		active_worker.set_selected(false)

	active_worker = null

	# cerrar panel
	if world.panel_worker:
		world.panel_worker.visible = false

	print("[WORKERS] Worker deseleccionado")

func _search_next_big_resource(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	var cell: Vector2i = resources_manager.find_nearest_big_resource(
		w.global_position,
		world.resources
	)

	if cell == Vector2i(-1, -1):
		print("[WORKERS] 🧍 no hay más recursos → idle")
		return

	var src: int = world.resources.get_cell_source_id(cell)
	if src == -1:
		print("[WORKERS] ❌ tile inválido → abortar auto")
		return

	var atlas: Vector2i = world.resources.get_cell_atlas_coords(cell)
	var def: Dictionary = resources_manager.get_big_def(src, atlas)
	if def.is_empty():
		print("[WORKERS] ❌ definición inválida → abortar auto")
		return

	# 🔒 VALIDAR HERRAMIENTA OBLIGATORIA
	var req: String = String(def.get("tool_required", ""))
	if req != "" and not w.has_tool(req):
		print("[WORKERS] ⛔ auto cancelado → falta herramienta:", req)
		return

	# ✅ ordenar nueva recolección
	worker_task_is_small[w] = false
	worker_active_cell[w] = cell
	worker_active_source[w] = src
	worker_active_atlas[w] = atlas

	var target: Vector2 = resources_manager.get_best_edge_target_for_cell(
		w,
		cell,
		world.resources
	)

	print("[WORKERS] 🌲 auto → nuevo recurso:", cell)
	w.move_to_edge(target, cell)
