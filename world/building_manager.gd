extends Node
class_name BuildingManager

@export var building_scene: PackedScene

var world: World = null
var buildings: Array[Building] = []

func setup(_world: World) -> void:
	world = _world

func spawn_building(data: BuildingData, world_pos: Vector2) -> Building:
	if building_scene == null or data == null or world == null:
		return null

	var b := building_scene.instantiate() as Building
	b.global_position = world_pos
	world.add_child(b)

	b.setup(world, data)
	buildings.append(b)
	return b
