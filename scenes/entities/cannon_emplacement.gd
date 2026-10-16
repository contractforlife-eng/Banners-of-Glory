extends Node2D
class_name CannonEmplacement

signal clicked(cannon: CannonEmplacement)

# The native barrel direction of cannon.png points towards top-right: Vector2(333, -443)
# In radians, atan2(-443, 333) is approximately -0.9262 rad (-53.07 deg).
const NATIVE_BARREL_ANGLE_RAD: float = -0.9262

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

## Rotates the sprite so its barrel points directly toward target_world_pos.
func aim_at_target(target_world_pos: Vector2) -> void:
	if not sprite:
		return
	var aim_dir: Vector2 = target_world_pos - global_position
	if aim_dir.length_squared() > 0.001:
		var target_angle_rad: float = aim_dir.angle()
		# Sprite rotation offsets from the native barrel angle
		sprite.rotation = target_angle_rad - NATIVE_BARREL_ANGLE_RAD

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
		get_viewport().set_input_as_handled()
