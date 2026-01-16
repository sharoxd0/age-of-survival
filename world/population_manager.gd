extends Node
class_name PopulationManager

var capacity: int = 0

func add_capacity(amount: int) -> void:
	capacity += amount
	print("[POP] +", amount, " -> capacidad:", capacity)

func remove_capacity(amount: int) -> void:
	capacity -= amount
	print("[POP] -", amount, " -> capacidad:", capacity)
