extends Node2D
class_name Building

@export var data: BuildingData
@export var level: int = 1

var world: World = null

func setup(_world: World, _data: BuildingData) -> void:
	world = _world
	data = _data

	_apply_modules_on_built()

func get_world() -> World:
	return world

func _apply_modules_on_built() -> void:
	if data == null:
		return
	for m in data.modules:
		if m != null:
			m.on_built(self)
