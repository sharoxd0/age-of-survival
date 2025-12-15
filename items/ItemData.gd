extends Resource
class_name ItemData

# =========================================================
# IDENTIDAD
# =========================================================
@export var id: String
@export var nombre: String
@export var descripcion: String
@export var icono: Texture2D

# =========================================================
# TIPO PRINCIPAL
# =========================================================
enum ItemType {
	RECURSO,
	HERRAMIENTA,
	ARMA,
	ARMADURA,
	CONSUMIBLE
}

@export var item_type: ItemType = ItemType.RECURSO

# =========================================================
# CLASIFICACIÓN
# =========================================================
@export var categorias: Array[String] = []

# =========================================================
# INVENTARIO
# =========================================================
@export var apilable: bool = true
@export var stack_max: int = 99
@export var peso: float = 1.0
@export var valor: int = 0

# =========================================================
# EQUIPAMIENTO
# =========================================================
@export var slot_kind: String = ""
@export var two_handed: bool = false

# =========================================================
# HERRAMIENTAS
# =========================================================
@export var tool_tags: Array[String] = []
@export var tool_efficiency: Dictionary = {}

# =========================================================
# COMBATE
# =========================================================
@export var daño: int = 0
@export var velocidad_ataque: float = 1.0

# =========================================================
# DURABILIDAD
# =========================================================
@export var durability_max: int = 0
@export var durability_loss_per_use: int = 1

# =========================================================
# FLAGS
# =========================================================
@export var flags: Array[String] = []

# =========================================================
# UTILIDADES
# =========================================================
func is_tool(tag: String) -> bool:
	return item_type == ItemType.HERRAMIENTA and tag in tool_tags

func is_resource() -> bool:
	return item_type == ItemType.RECURSO

func is_equippable() -> bool:
	return slot_kind != ""
