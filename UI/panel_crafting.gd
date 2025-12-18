extends Panel
class_name PanelCrafting

# =========================================================
# TABS
# =========================================================
enum CraftingView {
	PLANOS,
	RECURSOS,
	HERRAMIENTAS
}

var current_view: CraftingView = CraftingView.PLANOS
var active_worker: CharacterBody2D = null

# =========================================================
# LEFT TABS
# =========================================================
@onready var btn_planos: Button = $MarginContainer/HBoxContainer/Left/TopTabs/BtnPlanos
@onready var btn_recursos: Button = $MarginContainer/HBoxContainer/Left/TopTabs/BtnRecursos
@onready var btn_herramientas: Button = $MarginContainer/HBoxContainer/Left/TopTabs/BtnHerramientas

# =========================================================
# RIGHT PANELS
# =========================================================
@onready var craft_detail: VBoxContainer = \
	$MarginContainer/HBoxContainer/Right/CraftDetails

@onready var worker_equip_panel: HBoxContainer = \
	$MarginContainer/HBoxContainer/Right/WorkerEquipPanel

@onready var label_selected: Label = \
	$MarginContainer/HBoxContainer/Right/CraftDetails/LabelSelected
@onready var icon_big: TextureRect = \
	$MarginContainer/HBoxContainer/Right/CraftDetails/IconBig
@onready var label_desc: Label = \
	$MarginContainer/HBoxContainer/Right/CraftDetails/LabelDesc
@onready var vbox_ingredients: VBoxContainer = \
	$MarginContainer/HBoxContainer/Right/CraftDetails/VBoxIngredients
@onready var btn_craft: Button = \
	$MarginContainer/HBoxContainer/Right/CraftDetails/BtnCraft

@onready var btn_close: Button = \
	$MarginContainer/HBoxContainer/ButtonClose

# =========================================================
# EQUIP SLOTS
# =========================================================
@onready var equip_slot_hand: WorkerEquipSlot = $MarginContainer/HBoxContainer/Right/WorkerEquipPanel/SlotHand
@onready var equip_slot_off_hand: WorkerEquipSlot = $MarginContainer/HBoxContainer/Right/WorkerEquipPanel/SlotOffHand
@onready var equip_slot_body: WorkerEquipSlot = $MarginContainer/HBoxContainer/Right/WorkerEquipPanel/SlotBody
@onready var equip_slot_extra: WorkerEquipSlot = $MarginContainer/HBoxContainer/Right/WorkerEquipPanel/SlotExtra

# =========================================================
# CONFIG
# =========================================================
@export var recipe_slot_scene: PackedScene
@export var inventory_manager: InventoryManager

# =========================================================
# LEFT GRID
# =========================================================
@onready var grid_recipes: GridContainer = \
	$MarginContainer/HBoxContainer/Left/ScrollRecipes/GridRecipes

# =========================================================
# STATE
# =========================================================
var recipes: Array[RecipeData] = []
var selected_recipe: RecipeData = null

# =========================================================
# READY
# =========================================================
func _ready() -> void:

	worker_equip_panel.visible = false
	craft_detail.visible = true
	btn_planos.pressed.connect(func(): _set_tab(CraftingView.PLANOS))
	btn_recursos.pressed.connect(func(): _set_tab(CraftingView.RECURSOS))
	btn_herramientas.pressed.connect(func(): _set_tab(CraftingView.HERRAMIENTAS))

	btn_close.pressed.connect(_on_close_pressed)
	btn_craft.pressed.connect(_on_craft_pressed)

	if inventory_manager:
		inventory_manager.inventory_changed.connect(_on_inventory_changed)

	_load_recipes()
	_set_tab(CraftingView.PLANOS)

# =========================================================
# TAB SWITCH
# =========================================================
func _set_tab(view: CraftingView) -> void:
	current_view = view
	_clear_detail()

	for c in grid_recipes.get_children():
		c.queue_free()

	if current_view == CraftingView.HERRAMIENTAS and active_worker != null:
		_show_worker_equip_view()
		_update_worker_equip_view()
		_build_tool_list()
	else:
		_show_craft_view()
		match current_view:
			CraftingView.PLANOS:
				_build_recipe_list()
			CraftingView.RECURSOS:
				_build_resource_list()
			CraftingView.HERRAMIENTAS:
				_build_tool_list()

# =========================================================
# VIEW MODES
# =========================================================
func _show_craft_view() -> void:
	craft_detail.visible = true
	worker_equip_panel.visible = false
	btn_craft.visible = true

func _show_worker_equip_view() -> void:
	if active_worker == null:
		return

	craft_detail.visible = false
	worker_equip_panel.visible = true
	btn_craft.visible = false

	label_selected.text = "Worker: %s" % active_worker.name
	icon_big.texture = null
	label_desc.text = "Equipamiento del trabajador"

	_update_worker_equip_view() # 🔥 CLAVE
# =========================================================
# WORKER CONTROL
# =========================================================
func set_active_worker(w: CharacterBody2D) -> void:
	active_worker = w
	print("[CRAFT] Worker activo:", w.name)
	_set_tab(CraftingView.HERRAMIENTAS)

func clear_active_worker() -> void:
	active_worker = null
	print("[CRAFT] Worker deseleccionado")
	_set_tab(CraftingView.PLANOS)

# =========================================================
# RECIPES
# =========================================================
func _load_recipes() -> void:
	recipes.clear()
	var dir := DirAccess.open("res://data/recipes")
	if dir == null:
		return

	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r: RecipeData = load("res://data/recipes/" + f)
			if r:
				recipes.append(r)

func _build_recipe_list() -> void:
	for recipe in recipes:
		var slot: RecipeSlot = recipe_slot_scene.instantiate()
		grid_recipes.add_child(slot)
		slot.set_recipe(recipe)
		slot.pressed.connect(func(): _on_recipe_selected(recipe))

func _on_recipe_selected(recipe: RecipeData) -> void:
	selected_recipe = recipe
	label_selected.text = recipe.nombre
	icon_big.texture = recipe.icono
	label_desc.text = recipe.id
	_build_ingredients(recipe)
	_update_craft_button()

# =========================================================
# INGREDIENTS
# =========================================================
func _build_ingredients(recipe: RecipeData) -> void:
	for c in vbox_ingredients.get_children():
		c.queue_free()

	for id in recipe.ingredientes.keys():
		var need := int(recipe.ingredientes[id])
		var have := inventory_manager.get_amount(id)

		var label := Label.new()
		label.text = "%s  %d / %d" % [id, have, need]
		label.modulate = Color(0.8,1,0.8) if have >= need else Color(1,0.4,0.4)
		vbox_ingredients.add_child(label)

func _update_craft_button() -> void:
	if selected_recipe == null:
		btn_craft.disabled = true
		return

	for id in selected_recipe.ingredientes.keys():
		if inventory_manager.get_amount(id) < selected_recipe.ingredientes[id]:
			btn_craft.disabled = true
			return

	btn_craft.disabled = false

# =========================================================
# CRAFT
# =========================================================
func _on_craft_pressed() -> void:
	if selected_recipe == null:
		return

	for id in selected_recipe.ingredientes.keys():
		inventory_manager.remove(id, selected_recipe.ingredientes[id])

	inventory_manager.add(
		selected_recipe.resultado_id,
		selected_recipe.cantidad_resultado
	)

# =========================================================
# RESOURCES
# =========================================================
func _build_resource_list() -> void:
	for id in inventory_manager.get_all().keys():
		var item := inventory_manager.get_item_data(id)
		if item and item.is_resource():
			var slot := recipe_slot_scene.instantiate()
			grid_recipes.add_child(slot)
			slot.set_resource(item, inventory_manager.get_amount(id))
			slot.pressed.connect(func(): _show_resource_detail(item))

func _show_resource_detail(item: ItemData) -> void:
	label_selected.text = item.nombre
	icon_big.texture = item.icono
	label_desc.text = item.descripcion
	btn_craft.disabled = true

# =========================================================
# TOOLS
# =========================================================
func _build_tool_list() -> void:
	for c in grid_recipes.get_children():
		c.queue_free()

	for id in inventory_manager.get_all().keys():
		var item := inventory_manager.get_item_data(id)
		if item == null:
			continue

		if item.item_type != ItemData.ItemType.HERRAMIENTA:
			continue

		var slot := recipe_slot_scene.instantiate()
		grid_recipes.add_child(slot)
		slot.set_resource(item, 1)

		# 🔥 CLICK → EQUIPAR
		slot.pressed.connect(func():
			_on_tool_selected(item)
		)
# =========================================================
# WORKER EQUIPMENT VIEW
# =========================================================
func _update_worker_equip_view() -> void:
	if active_worker == null:
		return

	var eq :Dictionary= active_worker.equipment

	equip_slot_hand.set_item(eq.get("hand"))
	equip_slot_off_hand.set_item(eq.get("off_hand"))
	equip_slot_body.set_item(eq.get("body"))
	equip_slot_extra.set_item(eq.get("extra"))

# =========================================================
# UTILS
# =========================================================
func _on_inventory_changed(_id, _amount) -> void:
	if selected_recipe:
		_build_ingredients(selected_recipe)
		_update_craft_button()

func _clear_detail() -> void:
	selected_recipe = null
	label_selected.text = "Selecciona"
	icon_big.texture = null
	label_desc.text = ""
	btn_craft.disabled = true
	for c in vbox_ingredients.get_children():
		c.queue_free()

func _on_close_pressed() -> void:
	visible = false
func _on_tool_selected(item: ItemData) -> void:
	if active_worker == null:
		print("[CRAFT] ❌ No hay worker activo")
		return

	print("[CRAFT] 🔧 Equipar:", item.nombre)

	var success: bool = active_worker.equip_item(item)

	if not success:
		print("[CRAFT] ❌ No se pudo equipar")
		return

	_update_worker_equip_view()
