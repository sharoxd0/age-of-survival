extends BuildingModule
class_name PopulationModule

@export var population_bonus: int = 2

func on_built(building: Node) -> void:
	# building debe tener .world
	if building == null or not building.has_method("get_world"):
		return

	var world = building.get_world()
	if world == null:
		return

	# Necesitas estas variables en World (te las agrego abajo)
	world.add_population_cap(population_bonus)
