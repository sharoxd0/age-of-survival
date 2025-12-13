extends Panel

@onready var grid: GridContainer = $MarginContainer/Grid

var inventory: Dictionary = {}

func set_inventory(inv: Dictionary) -> void:
	inventory = inv
	_update_ui()


func _update_ui():
	print(">>> DEBUG INVENTARIO <<<")

	for c in grid.get_children():
		c.queue_free()

	var slot_style := preload("res://ui/slot_style.tres")

	for id in inventory.keys():
		var value = inventory[id]

		var item_data: ItemData

		if typeof(value) == TYPE_INT:
			item_data = load("res://items/%s.tres" % id)
		else:
			item_data = value

		# ====== CREAR CELDA (PANEL) ======
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(100, 100)

		# ✔ CORRECTO PARA GODOT 4:
		cell.add_theme_stylebox_override("panel", slot_style)

		# Contenedor interno
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(box)

		# Icono
		var icon := TextureRect.new()
		icon.texture = item_data.icono
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		box.add_child(icon)

		# Texto
		var label := Label.new()

		if typeof(value) == TYPE_INT:
			label.text = "%s x%d" % [item_data.nombre, value]
		else:
			label.text = item_data.nombre

		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)

		grid.add_child(cell)
