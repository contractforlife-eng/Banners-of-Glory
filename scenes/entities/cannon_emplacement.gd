extends Node2D
class_name CannonEmplacement

signal clicked(cannon: CannonEmplacement)

@export var cannon_id: String = ""
@export var display_name: String = "Cannon"
@export var compass_position: String = "NW"
@export var status: String = "Neutral"
@export var controlling_alliance: String = "None"
@export var target_reference: String = "Great Palace"

@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea

func _ready() -> void:
	if click_area:
		click_area.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
		get_viewport().set_input_as_handled()
