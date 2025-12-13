extends TileMapLayer

@onready var resources: TileMapLayer = $"../Resources_TileMapLayer"

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	# Queremos que TODAS las celdas puedan actualizar su TileData en tiempo real
	return true

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	# Si HAY recurso en esa celda → crear hueco (sin navegación)
	if resources.get_cell_source_id(coords) != -1:
		tile_data.set_navigation_polygon(0, null)
	# Si NO hay recurso → no tocamos nada, se usa la navegación normal del TileSet
