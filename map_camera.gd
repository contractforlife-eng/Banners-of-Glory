extends Camera2D
class_name MapCamera2D

@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.5
@export var zoom_factor: float = 0.12
@export var zoom_smoothness: float = 16.0
@export var pan_smoothness: float = 20.0

var target_zoom: Vector2 = Vector2.ONE
var target_position: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_target_pos: Vector2 = Vector2.ZERO

var map_bounds: Rect2 = Rect2()

func _ready() -> void:
	target_zoom = zoom
	target_position = position

func set_map_bounds(rect: Rect2) -> void:
	map_bounds = rect
	_clamp_target_position()
	position = target_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_mouse_pos = event.position
				drag_start_target_pos = target_position
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_mouse(1.0 + zoom_factor, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_mouse(1.0 - zoom_factor, event.position)

	elif event is InputEventMouseMotion:
		if is_dragging:
			var mouse_delta: Vector2 = (event.position - drag_start_mouse_pos) / zoom
			target_position = drag_start_target_pos - mouse_delta
			_clamp_target_position()

func _process(delta: float) -> void:
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, clampf(zoom_smoothness * delta, 0.0, 1.0))
	if position != target_position:
		position = position.lerp(target_position, clampf(pan_smoothness * delta, 0.0, 1.0))

func _zoom_at_mouse(factor: float, mouse_screen_pos: Vector2) -> void:
	var old_zoom: Vector2 = target_zoom
	var new_zoom_val: float = clampf(old_zoom.x * factor, min_zoom, max_zoom)
	var new_zoom: Vector2 = Vector2(new_zoom_val, new_zoom_val)
	
	if old_zoom == new_zoom:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_viewport_offset: Vector2 = mouse_screen_pos - (viewport_size * 0.5)
	
	# Adjust target position so the point under the mouse stays stable
	target_position += mouse_viewport_offset * ((1.0 / old_zoom.x) - (1.0 / new_zoom.x))
	target_zoom = new_zoom
	_clamp_target_position()

func _clamp_target_position() -> void:
	if map_bounds.size == Vector2.ZERO:
		return
	
	var viewport_size: Vector2 = get_viewport_rect().size
	var current_view_size: Vector2 = viewport_size / target_zoom
	var half_view: Vector2 = current_view_size * 0.5

	# Allow panning within map bounds with a reasonable edge margin
	var min_x: float = map_bounds.position.x
	var max_x: float = map_bounds.end.x
	var min_y: float = map_bounds.position.y
	var max_y: float = map_bounds.end.y

	# If the viewport is larger than map bounds at low zoom, center it on the map axis
	if current_view_size.x >= map_bounds.size.x:
		target_position.x = map_bounds.get_center().x
	else:
		target_position.x = clampf(target_position.x, min_x + half_view.x, max_x - half_view.x)

	if current_view_size.y >= map_bounds.size.y:
		target_position.y = map_bounds.get_center().y
	else:
		target_position.y = clampf(target_position.y, min_y + half_view.y, max_y - half_view.y)
