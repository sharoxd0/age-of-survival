extends Panel
class_name WorkerEquipSlot

@export var slot_id: String = ""

@onready var label: Label = get_node_or_null("LabelSlot")
@onready var icon: TextureRect = get_node_or_null("Icon")

func _ready() -> void:
	if label == null:
		push_warning("[EQUIP SLOT] Falta LabelSlot en " + str(get_path()))
	if icon == null:
		push_warning("[EQUIP SLOT] Falta Icon en " + str(get_path()))

func set_item(item: ItemData) -> void:
	if item == null:
		if label: label.text = slot_id.capitalize()
		if icon: icon.texture = null
		modulate = Color(0.5, 0.5, 0.5)
	else:
		if label: label.text = item.nombre
		if icon: icon.texture = item.icono
		modulate = Color.WHITE
