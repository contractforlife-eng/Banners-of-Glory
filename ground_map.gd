extends Node2D
## Close-up ground map: the real play area, built from the TerrainData tile grid.

const TILE := 32
const START_ZOOM := 1.0
const PALACE_SIZE_PX := 192.0
const OVERVIEW_SCENE := "res://world_map.tscn"

@onready var terrain: TileMapLayer = $Terrain
@onready var palace: Sprite2D = $Palace
@onready var camera: MapCamera2D = $MapCamera2D
@onready var palace_info_panel: PalaceInfoPanel = $UI/PalaceInfoPanel
@onready var back_button: Button = $UI/BackButton
@onready var coord_label: Label = $UI/CoordLabel

var world_size: Vector2
var _selected_text: String = ""

func _ready() -> void:
	world_size = Vector2(TerrainData.WIDTH, TerrainData.HEIGHT) * TILE

	terrain.tile_set = TerrainTiles.build_tileset(TILE)
	_paint_terrain()

	# The Great Palace sits in the middle of the world, like on the overview map.
	palace.position = world_size * 0.5
	palace.scale = Vector2.ONE * (PALACE_SIZE_PX / palace.texture.get_width())

	# Free camera over the whole world, opening where the player tapped.
	camera.fit_overview_as_min_zoom = false
	camera.min_zoom = 0.45
	camera.max_zoom = 2.5
	camera.set_map_bounds(Rect2(Vector2.ZERO, world_size), false)
	camera.set_view(world_size * GameState.focus_uv, START_ZOOM)
	camera.terrain_clicked.connect(_on_terrain_clicked)

	back_button.pressed.connect(_go_back)

func _paint_terrain() -> void:
	for y in TerrainData.HEIGHT:
		for x in TerrainData.WIDTH:
			var t: int = TerrainData.get_type(x, y)
			# Pseudo-random but stable tile variant, so the ground doesn't look repetitive.
			var variant: int = ((x * 73856093) ^ (y * 19349663)) & 3
			terrain.set_cell(Vector2i(x, y), 0, Vector2i(variant, t))

func _process(_delta: float) -> void:
	var c := Vector2i((camera.position / TILE).floor())
	coord_label.text = "X:%d  Y:%d\n%s" % [c.x, c.y, _selected_text]

func _on_terrain_clicked(world_pos: Vector2) -> void:
	palace_info_panel.hide_panel()
	if _is_point_on_palace(world_pos):
		_selected_text = "Great Palace"
		palace_info_panel.show_palace_info("Great Palace", "Neutral", "None")
		return
	var cell := Vector2i((world_pos / TILE).floor())
	var t: int = TerrainData.get_type(cell.x, cell.y)
	_selected_text = "Tile %d, %d - %s" % [cell.x, cell.y, TerrainData.NAMES[t]]

func _is_point_on_palace(world_pos: Vector2) -> bool:
	var half := Vector2.ONE * PALACE_SIZE_PX * 0.5
	return Rect2(palace.position - half, half * 2.0).has_point(world_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

func _go_back() -> void:
	get_tree().change_scene_to_file(OVERVIEW_SCENE)
