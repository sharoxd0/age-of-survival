extends Resource
class_name BuildingData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

# costo de construcción (id -> cantidad)
@export var build_cost: Dictionary = {}

# módulos de comportamiento (ej: población, almacén, producción, etc.)
@export var modules: Array[BuildingModule] = []
