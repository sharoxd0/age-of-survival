extends Resource
class_name ItemData

@export var id: String
@export var nombre: String
@export var descripcion: String
@export var apilable := true
@export var icono: Texture2D

@export var categorias: Array[String] = []  # ["herramienta","arma"], ["recurso"], etc.
@export var slot_kind: String = ""          # "hand", "chest", "off_hand", "extra", "none"
@export var two_handed := false             # true si ocupa ambas manos (ej: hacha grande)

# OPCIONALES (combate)
@export var daño := 0
@export var velocidad_ataque := 1.0
