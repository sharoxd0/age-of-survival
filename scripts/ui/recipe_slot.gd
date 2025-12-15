extends Button
class_name RecipeSlot

@onready var icon_rect: TextureRect = $Icono

var recipe: RecipeData

func _ready() -> void:
	print("[RECIPE SLOT READY]", self)

	# 🔹 Tamaño del slot
	custom_minimum_size = Vector2(112, 112)

	# 🔹 Estilo visual
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

	# 🔹 Icono más grande
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func set_recipe(r: RecipeData) -> void:
	recipe = r
	icon_rect.texture = r.icono
