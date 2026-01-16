extends Node2D

@export var world: World   # 🔥 ahora tipado correctamente

# =========================================================
# INPUT
# =========================================================
func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return

	# Bloquear input si el mouse está sobre UI
	if get_viewport().gui_get_hovered_control() != null:
		return

	if not event is InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos := world.get_global_mouse_position()

	if mb.pressed:
		_handle_mouse_down(mouse_pos)
	else:
		_handle_mouse_up(mouse_pos)

# =========================================================
# MOUSE DOWN
# =========================================================
func _handle_mouse_down(mouse_pos: Vector2) -> void:
	# =================================================
	# 1️⃣ SELECCIÓN DE WORKER
	# =================================================
	for node in get_tree().get_nodes_in_group("workers"):
		if not is_instance_valid(node) or not (node is CharacterBody2D):
			continue

		var w := node as CharacterBody2D
		var rect := Rect2(w.global_position - Vector2(16, 16), Vector2(32, 32))

		if rect.grow(world.TOUCH_RADIUS_PX * 0.5).has_point(mouse_pos):
			print("[INPUT] Click en WORKER:", w.name)
			world.select_worker(w)
			return

	# =================================================
	# 2️⃣ INICIAR ESTADO DE PRESIÓN
	# =================================================
	world.is_pressing = true
	world.press_start_pos = mouse_pos
	world.long_press_fired = false

	world.pressed_on_resource = false
	world.pressed_is_small = false
	world.pressed_cell = Vector2i(-1, -1)
	world.pressed_source_id = -1
	world.pressed_atlas = Vector2i.ZERO

	# =================================================
	# 3️⃣ SMALL RESOURCE
	# =================================================
	var hit_small := get_tile_in_radius(
		world.resources_small,
		mouse_pos,
		world.TOUCH_RADIUS_PX
	)

	if not hit_small.is_empty():
		print("[INPUT] SMALL RESOURCE DETECTADO")
		print(" cell:", hit_small["cell"])
		print(" source:", hit_small["source"])
		print(" atlas:", hit_small["atlas"])

		world.pressed_on_resource = true
		world.pressed_is_small = true
		world.pressed_cell = hit_small["cell"]
		world.pressed_source_id = hit_small["source"]
		world.pressed_atlas = hit_small["atlas"]
		return

	# =================================================
	# 4️⃣ BIG RESOURCE (ÁRBOLES, ROCAS, ETC)
	# =================================================
	var hit_big := get_tile_in_radius(
		world.resources,
		mouse_pos,
		world.TOUCH_RADIUS_PX
	)

	if not hit_big.is_empty():
		print("[INPUT] BIG RESOURCE DETECTADO")
		print(" cell:", hit_big["cell"])
		print(" source:", hit_big["source"])
		print(" atlas:", hit_big["atlas"])

		world.pressed_on_resource = true
		world.pressed_is_small = false
		world.pressed_cell = hit_big["cell"]
		world.pressed_source_id = hit_big["source"]
		world.pressed_atlas = hit_big["atlas"]

		# ⏱️ long press para panel de recurso
		world.long_press_timer.start()
		return

	# =================================================
	# 5️⃣ CLICK EN VACÍO
	# =================================================
	print("[INPUT] Click en vacío")
	world.panel_resource.visible = false
# =========================================================
# MOUSE UP
# =========================================================
func _handle_mouse_up(mouse_pos: Vector2) -> void:
	print("[INPUT] MOUSE UP")

	if not world.is_pressing:
		return

	world.is_pressing = false

	if world.long_press_timer.time_left > 0:
		world.long_press_timer.stop()

	var moved := mouse_pos.distance_to(world.press_start_pos) > world.LONG_PRESS_MOVE_TOLERANCE

	print("[DEBUG] moved:", moved)
	print("[DEBUG] pressed_on_resource:", world.pressed_on_resource)
	print("[DEBUG] active_worker:", world.world_workers.active_worker)

	# ❌ Si se movió PERO no es un recurso → cancelar
	if moved and not world.pressed_on_resource:
		print("[DEBUG] cancelado por movimiento")
		return

	# ❌ long press ya consumió el evento
	if world.long_press_fired:
		return

	# 🌲 RECOLECCIÓN (ESTE ES EL BLOQUE CLAVE)
	if world.pressed_on_resource:
		if world.world_workers.active_worker != null:
			print("[DEBUG] try_collect_with_active_worker")
			world.world_workers.try_collect_with_active_worker()
		else:
			if not world.pressed_is_small:
				world.panel_resource.visible = false
		return

	# 🚶 Movimiento manual (solo suelo)
	if world.world_workers.active_worker != null:
		world.world_workers.active_worker.move_to_position(mouse_pos)
# =========================================================
# LONG PRESS
# =========================================================
func _on_long_press_timeout() -> void:
	if not world.is_pressing or world.pressed_is_small:
		return

	world.long_press_fired = true

	world.world_resources.update_resource_panel(
		world.panel_resource,
		world.label_res_name,
		world.label_res_desc,
		world.label_res_loot,
		world.label_res_req,
		world.btn_collect,
		world.world_workers.active_worker,
		world.pressed_cell,
		world.pressed_source_id,
		world.pressed_atlas
	)

# =========================================================
# TILE HIT TEST
# =========================================================
func get_tile_in_radius(
	tilemap: TileMapLayer,
	global_pos: Vector2,
	radius_px: float
) -> Dictionary:
	var center_cell := tilemap.local_to_map(
		tilemap.to_local(global_pos)
	)

	var tile_size := Vector2(tilemap.tile_set.tile_size)
	var range_x := int(ceil(radius_px / tile_size.x))
	var range_y := int(ceil(radius_px / tile_size.y))

	var best_dist := INF
	var result := {}

	for x in range(-range_x, range_x + 1):
		for y in range(-range_y, range_y + 1):
			var cell := center_cell + Vector2i(x, y)
			var src := tilemap.get_cell_source_id(cell)
			if src == -1:
				continue

			var world_pos := tilemap.to_global(tilemap.map_to_local(cell))
			var d := global_pos.distance_to(world_pos)

			if d <= radius_px and d < best_dist:
				best_dist = d
				result = {
					"cell": cell,
					"source": src,
					"atlas": tilemap.get_cell_atlas_coords(cell)
				}

	return result
