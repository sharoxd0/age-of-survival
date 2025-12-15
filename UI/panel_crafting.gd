extends Panel
class_name PanelCrafting

@onready var grid_recipes: GridContainer = $MarginContainer/HBoxContainer/Left/ScrollRecipes/GridRecipes
@onready var icon_big: TextureRect = $MarginContainer/HBoxContainer/Right/IconBig
@onready var vbox_ingredients: VBoxContainer = $MarginContainer/HBoxContainer/Right/VBoxIngredients
@onready var btn_craft: Button = $MarginContainer/HBoxContainer/Right/BtnCraft
@onready var label_selected: Label = $MarginContainer/HBoxContainer/Right/LabelSelected
@onready var btn_close:Button= $MarginContainer/HBoxContainer/ButtonClose
func _ready() -> void:
	print("[CRAFT UI] ready")
	btn_craft.disabled = true
	label_selected.text = "Selecciona una receta"
	btn_close.pressed.connect(_on_close_pressed)
	_clear_ingredients()

func _clear_ingredients() -> void:
	for c in vbox_ingredients.get_children():
		c.queue_free()
		
func _on_close_pressed() -> void:
	print("[CRAFTING] cerrar panel")
	visible = false
