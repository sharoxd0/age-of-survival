extends Panel
class_name PanelCrafting

# =========================================================
# CONFIGURACIÓN
# =========================================================
@export var recipe_slot_scene: PackedScene
@export var inventory_manager: InventoryManager

# =========================================================
# LEFT – LISTA DE RECETAS
# =========================================================
@onready var grid_recipes: GridContainer = \
	$MarginContainer/HBoxContainer/Left/ScrollRecipes/GridRecipes

# =========================================================
# RIGHT – DETALLE
# =========================================================
@onready var label_selected: Label = \
	$MarginContainer/HBoxContainer/Right/LabelSelected

@onready var icon_big: TextureRect = \
	$MarginContainer/HBoxContainer/Right/IconBig

@onready var label_desc: Label = \
	$MarginContainer/HBoxContainer/Right/LabelDesc

@onready var vbox_ingredients: VBoxContainer = \
	$MarginContainer/HBoxContainer/Right/VBoxIngredients

@onready var btn_craft: Button = \
	$MarginContainer/HBoxContainer/Right/BtnCraft

# =========================================================
# BOTÓN CERRAR
# =========================================================
@onready var btn_close: Button = $MarginContainer/HBoxContainer/ButtonClose

# =========================================================
# ESTADO
# =========================================================
var recipes: Array[RecipeData] = []
var selected_recipe: RecipeData = null
var selected_slot: RecipeSlot = null

# =========================================================
# READY
# =========================================================
func _ready() -> void:
	print("=== PANEL CRAFTING READY ===")

	btn_close.pressed.connect(_on_close_pressed)
	btn_craft.pressed.connect(_on_craft_pressed)
	print("Inventory manager:", inventory_manager)

	_load_recipes()
	_build_recipe_list()
	_clear_detail()

	print("Recetas cargadas:", recipes.size())
	print("=== FIN PANEL CRAFTING ===")

# =========================================================
# CARGAR RECETAS
# =========================================================
func _load_recipes() -> void:
	recipes.clear()

	var dir := DirAccess.open("res://data/recipes")
	if dir == null:
		push_error("❌ No se pudo abrir res://data/recipes")
		return

	for file in dir.get_files():
		if file.ends_with(".tres"):
			var recipe: RecipeData = load("res://data/recipes/" + file)
			if recipe != null:
				recipes.append(recipe)

# =========================================================
# CREAR LISTA (LEFT)
# =========================================================
func _build_recipe_list() -> void:
	if recipe_slot_scene == null:
		push_error("❌ recipe_slot_scene NO asignado")
		return

	for c in grid_recipes.get_children():
		c.queue_free()

	for recipe in recipes:
		var slot: RecipeSlot = recipe_slot_scene.instantiate()
		grid_recipes.add_child(slot)

		slot.set_recipe(recipe)

		slot.pressed.connect(func():
			_on_recipe_selected(recipe)
		)

# =========================================================
# SELECCIÓN DE RECETA
# =========================================================
func _on_recipe_selected(recipe: RecipeData) -> void:
	selected_recipe = recipe

	# desmarcar slot anterior
	if selected_slot != null:
		selected_slot.button_pressed = false

	# marcar nuevo slot
	for c in grid_recipes.get_children():
		if c is RecipeSlot and c.recipe == recipe:
			selected_slot = c
			selected_slot.button_pressed = true
			break

	label_selected.text = recipe.nombre
	icon_big.texture = recipe.icono
	label_desc.text = recipe.id

	_build_ingredients(recipe)
	_update_craft_button()

# =========================================================
# INGREDIENTES
# =========================================================
func _build_ingredients(recipe: RecipeData) -> void:
	for c in vbox_ingredients.get_children():
		c.queue_free()

	for item_id in recipe.ingredientes.keys():
		var required: int = recipe.ingredientes[item_id]
		var owned: int = inventory_manager.get_amount(item_id)

		var label := Label.new()
		label.text = "%s  %d / %d" % [item_id, owned, required]

		if owned >= required:
			label.modulate = Color(0.8, 1.0, 0.8)
		else:
			label.modulate = Color(1.0, 0.4, 0.4)

		vbox_ingredients.add_child(label)

# =========================================================
# VALIDAR BOTÓN CRAFT
# =========================================================
func _update_craft_button() -> void:
	if selected_recipe == null:
		btn_craft.disabled = true
		return

	for item_id in selected_recipe.ingredientes.keys():
		if inventory_manager.get_amount(item_id) < selected_recipe.ingredientes[item_id]:
			btn_craft.disabled = true
			return

	btn_craft.disabled = false

# =========================================================
# CRAFT (AÚN NO IMPLEMENTADO)
# =========================================================
func _on_craft_pressed() -> void:
	if selected_recipe == null:
		return

	print("⚒️ CRAFT PRESIONADO:", selected_recipe.nombre)
	# siguiente paso: quitar ingredientes + agregar resultado

# =========================================================
# CERRAR PANEL
# =========================================================
func _on_close_pressed() -> void:
	visible = false

# =========================================================
# LIMPIAR DETALLE
# =========================================================
func _clear_detail() -> void:
	selected_recipe = null
	selected_slot = null

	label_selected.text = "Selecciona una receta"
	icon_big.texture = null
	label_desc.text = ""
	btn_craft.disabled = true

	for c in vbox_ingredients.get_children():
		c.queue_free()
