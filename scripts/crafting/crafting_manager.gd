extends Node
class_name CraftingManager

@export var inventory: InventoryManager

var recipes: Dictionary[String, RecipeData] = {}

signal recipe_crafted(recipe_id: String)
signal craft_failed(reason: String)

# =================================================
# REGISTRAR RECETAS
# =================================================
func register_recipe(recipe: RecipeData) -> void:
	if recipe == null:
		return
	recipes[recipe.id] = recipe

# =================================================
# CONSULTAS
# =================================================
func get_all_recipes() -> Array[RecipeData]:
	return recipes.values()

func can_craft(recipe: RecipeData) -> bool:
	# ingredientes
	for item_id in recipe.ingredientes.keys():
		var need: int = recipe.ingredientes[item_id]
		if not inventory.has(item_id, need):
			return false
	return true

# =================================================
# CRAFTEAR
# =================================================
func craft(recipe_id: String) -> bool:
	if not recipes.has(recipe_id):
		craft_failed.emit("Receta no existe")
		return false

	var recipe: RecipeData = recipes[recipe_id]

	if not can_craft(recipe):
		craft_failed.emit("Faltan materiales")
		return false

	# quitar ingredientes
	for item_id in recipe.ingredientes.keys():
		inventory.remove(item_id, recipe.ingredientes[item_id])

	# agregar resultado
	inventory.add(recipe.resultado, recipe.cantidad_resultado)

	recipe_crafted.emit(recipe.id)
	return true
