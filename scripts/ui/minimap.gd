class_name Minimap
extends Control
## Bottom-right minimap. Click a spot to fly there; the "World Map" button
## (owned by the HUD) returns the camera to the full overview.

signal map_clicked(world_pos: Vector3)

var world: WorldBuilder
var cam: StrategyCamera
var state: GameState
var texture: Texture2D


func setup(w: WorldBuilder, c: StrategyCamera, s: GameState) -> void:
	world = w
	cam = c
	state = s
	texture = ImageTexture.create_from_image(w.minimap_image)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _to_px(p: Vector3) -> Vector2:
	var half := world.map_size * 0.5
	return Vector2((p.x + half) / world.map_size, (p.z + half) / world.map_size) * size


func _to_world(px: Vector2) -> Vector3:
	var half := world.map_size * 0.5
	var uv := px / size
	return Vector3(uv.x * world.map_size - half, 0, uv.y * world.map_size - half)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		map_clicked.emit(_to_world(event.position))
		accept_event()


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	for loc: LocationData in state.locations.values():
		var o := state.owner_of(loc)
		var col := o.banner_color if o else Color(0.85, 0.85, 0.85)
		var r := 5.0 if loc.kind in [LocationData.Kind.CASTLE, LocationData.Kind.CITY] else 3.0
		var p := _to_px(Vector3(loc.map_position.x, 0, loc.map_position.y))
		draw_circle(p, r + 1.5, Color.BLACK)
		draw_circle(p, r, col)
	for a in get_tree().get_nodes_in_group("army"):
		var col := Color.WHITE if (a as Army).owner_id == state.local_player_id else Color(1, 0.3, 0.2)
		draw_rect(Rect2(_to_px(a.position) - Vector2(2.5, 2.5), Vector2(5, 5)), col)
	# Camera view footprint
	var span := cam.distance * tan(deg_to_rad(cam.fov) * 0.5)
	var aspect := cam.get_viewport().get_visible_rect().size.aspect()
	var c := _to_px(cam.focus)
	var ext := Vector2(span * aspect, span) / world.map_size * size
	draw_rect(Rect2(c - ext, ext * 2.0), Color(1, 0.9, 0.5), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.3), false, 3.0)
