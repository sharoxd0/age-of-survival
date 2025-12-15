extends Panel
class_name InventorySlot

@onready var icon: TextureRect = $Icon
@onready var label: Label = $LabelCantidad

var item_id: String = ""

func _ready() -> void:
	clear()

func clear() -> void:
	item_id = ""
	icon.texture = null
	label.text = ""
	visible = true   # slot vacío visible

func set_item(item: ItemData, amount: int) -> void:
	item_id = item.id
	icon.texture = item.icono
	label.text = "x%d" % amount
	visible = true
