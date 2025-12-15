# res://data/recipe_data.gd
extends Resource
class_name RecipeData

# =================================================
# IDENTIDAD
# =================================================
@export var id: String
@export var nombre: String
@export var icono: Texture2D

# =================================================
# COSTO
# =================================================
@export var ingredientes: Dictionary[String, int]
# ejemplo: { "madera": 3, "piedra": 1 }

@export var tiempo_craft: float = 0.0  # futuro (colas, workers, etc.)

# =================================================
# RESULTADO (ID, NO ItemData)
# =================================================
@export var resultado_id: String       # ej: "hacha", "piedra", "lanza"
@export var cantidad_resultado: int = 1

# =================================================
# REQUISITOS
# =================================================
@export var requiere_herramienta: String = ""   # ej: "banco_trabajo"
@export var requiere_worker: bool = false
