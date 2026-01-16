extends Resource
class_name BuildingModule

# Se llama al colocar el edificio
func on_built(_building: Node) -> void:
	pass

# Se llama al subir de nivel (si luego implementas niveles)
func on_level_changed(_building: Node, _new_level: int) -> void:
	pass
