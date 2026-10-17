extends Node2D
## Overview map. Tapping anywhere zooms in and opens the close-up ground map at that spot.

const GROUND_SCENE := "res://ground_map.tscn"
const ENTER_ZOOM := 2.5
const ENTER_DELAY := 0.35

@onready var world_map: Sprite2D = $KingdomMap2
@onready var great_palace: Sprite2D = $Sprite2D
@onready var camera: MapCamera2D = $MapCamera2D
@onready var overview_button: Button = $UI/OverviewButton

var map_rect: Rect2
var _entering: bool = false

func _ready() -> void:
	# Keep the world map behind all other game objects.
	world_map.z_index = -1

	# Place the Great Palace at the center of the world map.
	great_palace.position = world_map.position
	great_palace.scale = Vector2(0.04, 0.04)

	map_rect = _calculate_map_bounds()
	camera.set_map_bounds(map_rect)
	camera.terrain_clicked.connect(_on_terrain_clicked)
	overview_button.pressed.connect(camera.return_to_overview)

func _calculate_map_bounds() -> Rect2:
	var tex_size: Vector2 = world_map.texture.get_size()
	var scaled_size: Vector2 = tex_size * world_map.scale.abs()
	return Rect2(world_map.position - scaled_size * 0.5, scaled_size)

func _on_terrain_clicked(world_position: Vector2) -> void:
	if _entering or not map_rect.has_point(world_position):
		return
	_entering = true
	# Remember where the player tapped (0..1 across the map image).
	GameState.focus_uv = (world_position - map_rect.position) / map_rect.size
	# Little "dive into the land" effect, then switch to the ground map.
	camera.focus_on_location(world_position, ENTER_ZOOM)
	await get_tree().create_timer(ENTER_DELAY).timeout
	get_tree().change_scene_to_file(GROUND_SCENE)
