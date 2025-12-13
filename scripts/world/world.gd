extends Node2D

# =========================================================
# NODOS
# =========================================================
@onready var resources: TileMapLayer = $Resources_TileMapLayer
@onready var resources_small: TileMapLayer = $SmallResources_TileMapLayer
@onready var ground: TileMapLayer = $Ground_TileMapLayer

@onready var btn_inv: Button = $UI/VBoxContainer/Button2
@onready var panel_inv: Panel = $UI/PanelInventario

@onready var panel_resource: Panel = $UI/PanelRecurso
@onready var label_res_name: Label = $UI/PanelRecurso/LabelNombre
@onready var label_res_desc: Label = $UI/PanelRecurso/LabelDescripcion
@onready var label_res_loot: Label = $UI/PanelRecurso/LabelLoot
@onready var label_res_req: Label = $UI/PanelRecurso/LabelRequisito
@onready var btn_collect: Button = $UI/PanelRecurso/BotonRecolectar

@onready var btn_spawn_worker: Button = $UI/VBoxContainer/ButtonSpawnWorker
@onready var panel_worker: Panel = $UI/PanelWorker
const TOUCH_RADIUS_PX := 20.0   # ajusta a gusto (16–32 recomendado)

# =========================================================
# INVENTARIO GLOBAL
# =========================================================
var inventory: Dictionary[String, int] = {}
var worker_task_is_small: Dictionary[CharacterBody2D, bool] = {}

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
# WORKERS
# =========================================================
var active_worker: CharacterBody2D = null
var worker_active_cell: Dictionary[CharacterBody2D, Vector2i] = {}
var worker_active_source: Dictionary[CharacterBody2D, int] = {}
var worker_active_atlas: Dictionary[CharacterBody2D, Vector2i] = {}

# =========================================================
# INPUT STATE
# =========================================================
const LONG_PRESS_TIME := 0.35
const LONG_PRESS_MOVE_TOLERANCE := 10.0

var is_pressing := false
var press_start_pos := Vector2.ZERO
var pressed_on_resource := false
var pressed_is_small := false
var pressed_cell := Vector2i(-1, -1)
var pressed_source_id := -1
var pressed_atlas: Vector2i = Vector2i.ZERO
var long_press_fired := false

@onready var long_press_timer: Timer = Timer.new()

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	panel_inv.visible = false
	panel_resource.visible = false
	panel_worker.visible = false

	btn_inv.pressed.connect(_on_btn_inv_pressed)
	btn_collect.pressed.connect(_on_collect_pressed)
	btn_spawn_worker.pressed.connect(_on_spawn_worker_pressed)

	# Inicializar recursos grandes
	for cell: Vector2i in resources.get_used_cells():
		var src: int = resources.get_cell_source_id(cell)
		var atlas: Vector2i = resources.get_cell_atlas_coords(cell)
		var key := "%d|%s" % [src, atlas]
		var def: Dictionary = RESOURCE_DEFS.get(key, {})
		resource_amounts[cell] = int(def.get("amount", 1))
		print("[READY] init resource cell:", cell, "key:", key, "amount:", resource_amounts[cell])

	if has_node("Worker"):
		_register_worker($Worker)

	add_child(long_press_timer)
	long_press_timer.one_shot = true
	long_press_timer.wait_time = LONG_PRESS_TIME
	long_press_timer.timeout.connect(_on_long_press_timeout)

# =========================================================
# REGISTRAR WORKER
# =========================================================
func _register_worker(w: CharacterBody2D) -> void:
	if not is_instance_valid(w):
		return

	w.add_to_group("workers")

	worker_active_cell[w] = Vector2i(-1, -1)
	worker_active_source[w] = -1
	worker_active_atlas[w] = Vector2i.ZERO
	worker_task_is_small[w] = false

	w.arrived_to_resource.connect(_on_worker_arrived)
	w.arrived_home.connect(_on_worker_arrived_home)

	print("[WORLD] worker registrado:", w)
# =========================================================
# INPUT (DEBUG)
# =========================================================
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()

	# ================= MOUSE DOWN =================
	if mb.pressed:
		# ---------- selección worker (con radio simple) ----------
		for node in get_tree().get_nodes_in_group("workers"):
			if not is_instance_valid(node) or not (node is CharacterBody2D):
				continue

			var w: CharacterBody2D = node
			var rect := Rect2(
				w.global_position - Vector2(16, 16),
				Vector2(32, 32)
			)

			# pequeño margen extra tipo dedo
			if rect.grow(TOUCH_RADIUS_PX * 0.5).has_point(mouse_pos):
				print("[INPUT] Click en WORKER")
				_select_worker(w)
				return

		is_pressing = true
		press_start_pos = mouse_pos
		long_press_fired = false

		pressed_on_resource = false
		pressed_is_small = false
		pressed_cell = Vector2i(-1, -1)
		pressed_source_id = -1
		pressed_atlas = Vector2i.ZERO

		# ---------- SMALL RESOURCE (con radio) ----------
		var hit_small: Dictionary = _get_tile_in_radius(
			resources_small,
			mouse_pos,
			TOUCH_RADIUS_PX
		)

		if not hit_small.is_empty():
			pressed_on_resource = true
			pressed_is_small = true
			pressed_cell = hit_small["cell"]
			pressed_source_id = hit_small["source"]
			pressed_atlas = hit_small["atlas"]

			print(
				"[INPUT] Mouse DOWN SMALL (radius)",
				"cell:", pressed_cell,
				"id:", pressed_source_id,
				"atlas:", pressed_atlas
			)
			return

		# ---------- BIG RESOURCE (con radio) ----------
		var hit_big: Dictionary = _get_tile_in_radius(
			resources,
			mouse_pos,
			TOUCH_RADIUS_PX
		)

		if not hit_big.is_empty():
			pressed_on_resource = true
			pressed_is_small = false
			pressed_cell = hit_big["cell"]
			pressed_source_id = hit_big["source"]
			pressed_atlas = hit_big["atlas"]

			print(
				"[INPUT] Mouse DOWN BIG (radius)",
				"cell:", pressed_cell,
				"id:", pressed_source_id,
				"atlas:", pressed_atlas
			)

			long_press_timer.start()
			return

		panel_resource.visible = false
		return

	# ================= MOUSE UP =================
	else:
		if not is_pressing:
			return

		is_pressing = false

		if long_press_timer.time_left > 0:
			long_press_timer.stop()

		if mouse_pos.distance_to(press_start_pos) > LONG_PRESS_MOVE_TOLERANCE:
			print("[INPUT] Move tolerance exceeded")
			return

		if long_press_fired:
			print("[INPUT] Long press fired")
			return

		if pressed_on_resource:
			print("[DEBUG] Mouse UP sobre recurso")
			print("  pressed_is_small:", pressed_is_small)
			print("  pressed_cell:", pressed_cell)
			print("  pressed_source_id:", pressed_source_id)
			print("  pressed_atlas:", pressed_atlas)
			print("  active_worker:", active_worker)

			if active_worker != null and is_instance_valid(active_worker):
				print("[DEBUG] Llamando a _try_collect_with_active_worker()")
				_try_collect_with_active_worker()
			else:
				print("[DEBUG] NO hay worker activo")
				if not pressed_is_small:
					_update_resource_panel()
			return

		# ---------- movimiento manual ----------
		if active_worker != null and is_instance_valid(active_worker):
			print("[INPUT] Movimiento manual a:", mouse_pos)
			active_worker.move_to_position(mouse_pos)
			return

# =========================================================
# PANEL RECURSO
# =========================================================
func _update_resource_panel() -> void:
	var key := "%d|%s" % [pressed_source_id, pressed_atlas]
	var def: Dictionary = RESOURCE_DEFS.get(key, {})
	print("[PANEL] update key:", key, "def:", def)
	if def.is_empty():
		panel_resource.visible = false
		return

	var remaining: int = resource_amounts.get(pressed_cell, 0)
	var item := _get_item_data_for_tile(def["item_id"])
	if item == null:
		panel_resource.visible = false
		return

	label_res_name.text = def["nombre"]
	label_res_desc.text = def["descripcion"]
	label_res_loot.text = "%s x%d" % [item.nombre, remaining]

	if active_worker == null:
		btn_collect.disabled = true
		label_res_req.text = "Selecciona un worker"
	else:
		var req := String(def.get("tool_required", ""))
		btn_collect.disabled = (req != "" and not active_worker.has_tool(req))
		label_res_req.text = req

	panel_resource.visible = true

# =========================================================
# RECOLECTAR (DEBUG)
# =========================================================
func _try_collect_with_active_worker() -> void:
	print("\n[DEBUG] _try_collect_with_active_worker")
	print("  active_worker:", active_worker)

	if active_worker == null or not is_instance_valid(active_worker):
		print("  ❌ worker inválido")
		return

	if active_worker.is_cargo_full():
		print("  ❌ cargo lleno")
		return

	# =========================
	# SMALL -> AHORA CAMINA
	# =========================
	if pressed_is_small:
		var key_s := "%d|%s" % [pressed_source_id, pressed_atlas]
		print("  SMALL key:", key_s)

		var def_s: Dictionary = SMALL_RESOURCE_DEFS.get(key_s, {})
		print("  def_s:", def_s)
		if def_s.is_empty():
			print("  ❌ def_s vacío")
			return

		# Guardamos tarea
		worker_task_is_small[active_worker] = true
		worker_active_cell[active_worker] = pressed_cell
		worker_active_source[active_worker] = pressed_source_id
		worker_active_atlas[active_worker] = pressed_atlas

		# Mandar al worker a la celda del recurso pequeño
		var target: Vector2 = resources_small.to_global(resources_small.map_to_local(pressed_cell))
		print("  [DEBUG] move_to_edge (SMALL) target:", target, "cell:", pressed_cell)
		active_worker.move_to_edge(target, pressed_cell)
		return

	# =========================
	# BIG -> IGUAL QUE ANTES
	# =========================
	print("[DEBUG] Intentando recolectar BIG")
	var key := "%d|%s" % [pressed_source_id, pressed_atlas]
	print("  key:", key)

	var def: Dictionary = RESOURCE_DEFS.get(key, {})
	print("  def:", def)
	if def.is_empty():
		print("  ❌ def vacío (key no coincide)")
		return

	var req := String(def.get("tool_required", ""))
	print("  tool_required:", req)
	if req != "" and not active_worker.has_tool(req):
		print("  ❌ no tiene herramienta")
		return

	worker_task_is_small[active_worker] = false
	worker_active_cell[active_worker] = pressed_cell
	worker_active_source[active_worker] = pressed_source_id
	worker_active_atlas[active_worker] = pressed_atlas

	var target_big: Vector2 = _get_best_edge_target_for_cell(active_worker, pressed_cell)
	print("[DEBUG] move_to_edge (BIG) target:", target_big, "cell:", pressed_cell)
	active_worker.move_to_edge(target_big, pressed_cell)

	panel_resource.visible = false
# =========================================================
# WORKER CALLBACKS (DEBUG)
# =========================================================
func _on_worker_arrived(w: CharacterBody2D, cell: Vector2i) -> void:
	print("\n[WORLD] arrived_to_resource worker:", w, "cell:", cell)

	if w == null or not is_instance_valid(w):
		return

	# =================================================
	# SMALL RESOURCE (una sola vez)
	# =================================================
	var is_small: bool = worker_task_is_small.get(w, false)
	if is_small:
		var current_id: int = resources_small.get_cell_source_id(cell)
		if current_id == -1:
			return

		var key_s := "%d|%s" % [worker_active_source[w], worker_active_atlas[w]]
		var def_s: Dictionary = SMALL_RESOURCE_DEFS.get(key_s, {})
		if def_s.is_empty():
			return

		var item_s := _get_item_data_for_tile(def_s["item_id"])
		if item_s == null:
			return

		w.cargo.clear()
		w.cargo.append(item_s)
		w.emit_signal("cargo_changed")
		resources_small.set_cell(cell, -1)

		print("  ✔ SMALL recolectado")
		return   # SMALL termina aquí

	# =================================================
	# BIG RESOURCE (ORDEN PERSISTENTE)
	# =================================================
	if not resource_amounts.has(cell):
		print("  ❌ BIG cell no registrada")
		return

	var key := "%d|%s" % [worker_active_source[w], worker_active_atlas[w]]
	var def: Dictionary = RESOURCE_DEFS.get(key, {})
	if def.is_empty():
		return

	var item := _get_item_data_for_tile(def["item_id"])
	if item == null:
		return

	# 1️⃣ Cargar 1 ítem (slot único)
	w.cargo.clear()
	w.cargo.append(item)
	w.emit_signal("cargo_changed")
	print("  ✔ BIG loot cargado (slot lleno)")

	# 2️⃣ Reducir recurso
	resource_amounts[cell] -= 1
	print("  remaining:", resource_amounts[cell])

	# 3️⃣ Árbol agotado → ir a HOME una última vez si hay carga
	if resource_amounts[cell] <= 0:
		resources.set_cell(cell, -1)
		resource_amounts.erase(cell)
		ground.notify_runtime_tile_data_update()

		print("  🌲 árbol agotado")

		if w.cargo.size() > 0:
			print("  📦 árbol agotado pero hay carga → ir a home")
			w.go_home()
		else:
			print("  🧍 sin carga → idle")

		return

	# 4️⃣ Árbol aún existe → slot lleno → ir a HOME
	print("  📦 slot lleno → ir a home")
	w.go_home()
func _on_worker_arrived_home(w: CharacterBody2D) -> void:
	print("[WORLD] arrived_home:", w)

	if w == null or not is_instance_valid(w):
		return

	# 1️⃣ Depositar en inventario
	for item in w.cargo:
		inventory[item.id] = inventory.get(item.id, 0) + 1

	w.cargo.clear()
	w.emit_signal("cargo_changed")
	print("  ✔ inventario actualizado")

	# 2️⃣ Buscar nuevo árbol
	var next_cell: Vector2i = _find_nearest_big_resource(w.global_position)

	if next_cell == Vector2i(-1, -1):
		print("  🧍 no hay más árboles → idle")
		return

	print("  🌲 nuevo árbol encontrado:", next_cell)

	# 3️⃣ Registrar nueva tarea
	worker_task_is_small[w] = false
	worker_active_cell[w] = next_cell
	worker_active_source[w] = resources.get_cell_source_id(next_cell)
	worker_active_atlas[w] = resources.get_cell_atlas_coords(next_cell)

	# 4️⃣ Enviar al nuevo árbol
	var target := _get_best_edge_target_for_cell(w, next_cell)
	w.move_to_edge(target, next_cell)
# =========================================================
# UTIL
# =========================================================
func _get_best_edge_target_for_cell(w: CharacterBody2D, cell: Vector2i) -> Vector2:
	if w == null or not is_instance_valid(w):
		return resources.to_global(resources.map_to_local(cell))

	var world: Vector2 = resources.to_global(resources.map_to_local(cell))
	var s: Vector2 = Vector2(resources.tile_set.tile_size)

	var opts: Array[Vector2] = [
		world + Vector2(0, -s.y * 0.5),
		world + Vector2(0,  s.y * 0.5),
		world + Vector2(-s.x * 0.5, 0),
		world + Vector2( s.x * 0.5, 0)
	]

	var best: Vector2 = opts[0]
	for p: Vector2 in opts:
		if w.global_position.distance_to(p) < w.global_position.distance_to(best):
			best = p
	return best

func _get_item_data_for_tile(item_id: String) -> ItemData:
	var path := "res://items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		push_error("ItemData no existe: " + path)
		return null
	return load(path) as ItemData

# =========================================================
# UI
# =========================================================
func _on_btn_inv_pressed() -> void:
	panel_inv.visible = not panel_inv.visible
	if panel_inv.visible:
		panel_inv.set_inventory(inventory)

func _on_collect_pressed() -> void:
	print("[UI] Botón recolectar")
	_try_collect_with_active_worker()

func _on_spawn_worker_pressed() -> void:
	var w := preload("res://scenes/Worker.tscn").instantiate()
	w.global_position = Vector2(64, 0)
	add_child(w)
	_register_worker(w)

func _select_worker(w: CharacterBody2D) -> void:
	for node in get_tree().get_nodes_in_group("workers"):
		if node is CharacterBody2D and is_instance_valid(node):
			node.set_selected(false)
	active_worker = w
	w.set_selected(true)
	panel_worker.set_worker(w)
	panel_worker.visible = true
	print("[WORLD] Worker seleccionado:", w)

func _on_long_press_timeout() -> void:
	if not is_pressing or pressed_is_small:
		return
	long_press_fired = true
	print("[INPUT] Long press -> panel recurso")
	_update_resource_panel()

func _find_nearest_big_resource(from_pos: Vector2) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF

	for cell: Vector2i in resources.get_used_cells():
		if not resource_amounts.has(cell):
			continue

		var src: int = resources.get_cell_source_id(cell)
		var atlas: Vector2i = resources.get_cell_atlas_coords(cell)
		var key := "%d|%s" % [src, atlas]

		if not RESOURCE_DEFS.has(key):
			continue

		var world_pos: Vector2 = resources.to_global(
			resources.map_to_local(cell)
		)

		var d := from_pos.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best_cell = cell

	return best_cell

func _get_tile_in_radius(
	tilemap: TileMapLayer,
	global_pos: Vector2,
	radius_px: float
) -> Dictionary:
	# Resultado:
	# { "cell": Vector2i, "source": int, "atlas": Vector2i }

	var center_cell: Vector2i = tilemap.local_to_map(
		tilemap.to_local(global_pos)
	)

	var tile_size: Vector2 = Vector2(tilemap.tile_set.tile_size)
	var range_x: int = int(ceil(radius_px / tile_size.x))
	var range_y: int = int(ceil(radius_px / tile_size.y))

	var best_dist: float = INF
	var result: Dictionary = {}

	for x in range(-range_x, range_x + 1):
		for y in range(-range_y, range_y + 1):
			var cell := center_cell + Vector2i(x, y)

			var src: int = tilemap.get_cell_source_id(cell)
			if src == -1:
				continue

			var world_pos: Vector2 = tilemap.to_global(
				tilemap.map_to_local(cell)
			)

			var d := global_pos.distance_to(world_pos)
			if d <= radius_px and d < best_dist:
				best_dist = d
				result = {
					"cell": cell,
					"source": src,
					"atlas": tilemap.get_cell_atlas_coords(cell)
				}

	return result
