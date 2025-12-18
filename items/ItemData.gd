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
@export var slot_kind: String = ""      # "hand", "head", "chest", etc.
@export var two_handed: bool = false

# =========================================================
# HERRAMIENTAS
# =========================================================
@export var tool_tags: Array[String] = []            # ["hacha","pico"]
@export var tool_efficiency: Dictionary = {}         # {"madera":1.2}

# =========================================================
# COMBATE
# =========================================================
@export var daño: int = 0
@export var velocidad_ataque: float = 1.0

# =========================================================
# DURABILIDAD
# =========================================================
@export var durability_max: int = 0                  # 0 = indestructible
@export var durability_loss_per_use: int = 1

# =========================================================
# FLAGS (libre uso)
# =========================================================
@export var flags: Array[String] = []                 # ["no_drop","quest"]

# =========================================================
# UTILIDADES (CLAVE)
# =========================================================

# 🔹 Herramienta genérica (para tabs / UI)
func is_any_tool() -> bool:
	return item_type == ItemType.HERRAMIENTA

# 🔹 Herramienta por tipo (hacha, pico, etc.)
func is_tool(tag: String) -> bool:
	return item_type == ItemType.HERRAMIENTA and tag in tool_tags

func is_weapon() -> bool:
	return item_type == ItemType.ARMA

func is_resource() -> bool:
	return item_type == ItemType.RECURSO

func is_consumable() -> bool:
	return item_type == ItemType.CONSUMIBLE

func is_equippable() -> bool:
	return slot_kind != ""

# 🔹 Reglas de stack
func can_stack() -> bool:
	if not apilable:
		return false
	if is_any_tool() or is_weapon():
		return false
	return true

# 🔹 Usa durabilidad
func uses_durability() -> bool:
	return durability_max > 0
