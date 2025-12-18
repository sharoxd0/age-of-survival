extends Button
class_name RecipeSlot

@onready var icon_rect: TextureRect = $Icono
@onready var label: Label = $Label

var recipe: RecipeData = null

func _ready() -> void:
	print("[RECIPE SLOT READY]", self)

	# Tamaño del slot
	custom_minimum_size = Vector2(112, 112)

	# Estilo visual
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18)
	style.border_color = Color(0.6, 0.6, 0.6)

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)

	# Icono
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# =================================================
# RECETA
# =================================================
func set_recipe(recipe_data: RecipeData) -> void:
	recipe = recipe_data
	label.text = recipe.nombre
	icon_rect.texture = recipe.icono
	modulate = Color.WHITE

# =================================================
# RECURSO (modo inventario)
# =================================================
func set_resource(item: ItemData, amount: int) -> void:
	label.text = "%s x%d" % [item.nombre, amount]
	icon_rect.texture = item.icono
	modulate = Color(0.8, 0.9, 1.0)
