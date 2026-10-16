extends Node2D

@onready var world_map: Sprite2D = $KingdomMap2
@onready var great_palace: Sprite2D = $Sprite2D
@onready var camera: MapCamera2D = $MapCamera2D
@onready var palace_click_area: Area2D = $Sprite2D/ClickArea
@onready var palace_info_panel: PalaceInfoPanel = $UI/PalaceInfoPanel
@onready var overview_button: Button = $UI/OverviewButton

func _ready() -> void:
	# Keep the world map behind all other game objects.
	world_map.z_index = -1

	# Place the Great Palace near the center of the world map.
	great_palace.position = world_map.position

	# Give the palace a reasonable initial size.
	great_palace.scale = Vector2(0.04, 0.04)

	# Calculate and assign world map bounding box for the camera.
	var map_rect: Rect2 = _calculate_map_bounds()
	if camera:
		camera.set_map_bounds(map_rect)
		camera.terrain_clicked.connect(_on_terrain_clicked)

	# Setup palace click interaction
	if palace_click_area:
		palace_click_area.input_event.connect(_on_palace_input_event)

	# Setup overview button
	if overview_button and camera:
		overview_button.pressed.connect(camera.return_to_overview)

func _calculate_map_bounds() -> Rect2:
	if world_map and world_map.texture:
		var tex_size: Vector2 = world_map.texture.get_size()
		var scaled_size: Vector2 = tex_size * world_map.scale.abs()
		var top_left: Vector2 = world_map.position - (scaled_size * 0.5)
		return Rect2(top_left, scaled_size)
	# Fallback if texture not loaded
	return Rect2(Vector2.ZERO, Vector2(1150, 645))

func _on_terrain_clicked(world_position: Vector2) -> void:
	# Check if clicked world position falls within the Great Palace footprint
	if _is_point_on_palace(world_position):
		_select_palace()
		return

	# Move camera directly to the clicked world location and zoom in to 1.8x
	if camera:
		camera.focus_on_location(world_position, 1.8)

func _is_point_on_palace(world_pos: Vector2) -> bool:
	if not great_palace:
		return false
	# Palace collision shape is 1250x1250 scaled by 0.04 -> 50x50 px
	var half_size: Vector2 = Vector2(1250.0, 1250.0) * great_palace.scale.abs() * 0.5
	var palace_rect: Rect2 = Rect2(great_palace.global_position - half_size, half_size * 2.0)
	return palace_rect.has_point(world_pos)

func _select_palace() -> void:
	if camera and great_palace:
		camera.focus_on_location(great_palace.position, 1.8)
	if palace_info_panel:
		palace_info_panel.show_palace_info("Great Palace", "Neutral", "None")

func _on_palace_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_palace()
		get_viewport().set_input_as_handled()
