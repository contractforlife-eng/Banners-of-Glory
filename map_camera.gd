extends Camera2D
class_name MapCamera2D

signal terrain_clicked(world_position: Vector2)

@export var max_zoom: float = 2.5
@export var min_zoom: float = 0.5
@export var zoom_factor: float = 0.12
@export var zoom_smoothness: float = 16.0
@export var pan_smoothness: float = 20.0
@export var drag_threshold_pixels: float = 8.0

var target_zoom: Vector2 = Vector2.ONE
var target_position: Vector2 = Vector2.ZERO

# Mouse drag state
var is_mouse_dragging: bool = false
var mouse_press_pos: Vector2 = Vector2.ZERO
var drag_start_target_pos: Vector2 = Vector2.ZERO

# Touch tracking for mobile (touch_index -> Vector2 screen_pos)
var active_touches: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: Vector2 = Vector2.ONE
var is_touch_panning: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var had_multi_touch: bool = false

var map_bounds: Rect2 = Rect2()
var overview_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	target_zoom = zoom
	target_position = position
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func set_map_bounds(rect: Rect2) -> void:
	map_bounds = rect
	_update_overview_zoom()
	# Automatically show the entire map centered on initial load
	zoom = overview_zoom
	target_zoom = overview_zoom
	position = map_bounds.get_center()
	target_position = position

func _on_viewport_size_changed() -> void:
	_update_overview_zoom()
	_clamp_target_position()

func _update_overview_zoom() -> void:
	if map_bounds.size == Vector2.ZERO:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	# Overview zoom ensures the entire map fits inside the viewport without cutting edges
	var fit_x: float = viewport_size.x / map_bounds.size.x
	var fit_y: float = viewport_size.y / map_bounds.size.y
	var fit_zoom_val: float = minf(fit_x, fit_y)
	overview_zoom = Vector2(fit_zoom_val, fit_zoom_val)
	min_zoom = fit_zoom_val

func focus_on_location(world_pos: Vector2, focus_zoom: float = 1.8) -> void:
	var clamped_zoom_val: float = clampf(focus_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(clamped_zoom_val, clamped_zoom_val)
	target_position = world_pos
	_clamp_target_position()

func return_to_overview() -> void:
	_update_overview_zoom()
	target_zoom = overview_zoom
	target_position = map_bounds.get_center()

func _unhandled_input(event: InputEvent) -> void:
	# --- MOUSE INPUT ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_mouse_dragging = true
				mouse_press_pos = event.position
				drag_start_target_pos = target_position
			else:
				if is_mouse_dragging:
					var total_drag: float = (event.position - mouse_press_pos).length()
					is_mouse_dragging = false
					# If mouse was released within drag threshold, treat as terrain click
					if total_drag < drag_threshold_pixels:
						var clicked_world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
						terrain_clicked.emit(clicked_world_pos)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_screen_pos(1.0 + zoom_factor, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_screen_pos(1.0 - zoom_factor, event.position)

	elif event is InputEventMouseMotion:
		if is_mouse_dragging:
			var mouse_delta: Vector2 = (event.position - mouse_press_pos) / zoom
			target_position = drag_start_target_pos - mouse_delta
			_clamp_target_position()

	# --- TOUCH INPUT (MOBILE / WEB) ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			if active_touches.size() == 1:
				touch_start_pos = event.position
				drag_start_target_pos = target_position
				is_touch_panning = true
				had_multi_touch = false
			elif active_touches.size() >= 2:
				is_touch_panning = false
				had_multi_touch = true
				var touches: Array = active_touches.values()
				initial_pinch_distance = (touches[0] as Vector2).distance_to(touches[1] as Vector2)
				initial_pinch_zoom = target_zoom
		else:
			var touch_dist: float = (event.position - touch_start_pos).length()
			# Only emit tap if single touch never escalated to multi-touch and did not drag
			if active_touches.size() == 1 and is_touch_panning and not had_multi_touch and touch_dist < drag_threshold_pixels:
				var clicked_world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
				terrain_clicked.emit(clicked_world_pos)

			active_touches.erase(event.index)
			if active_touches.size() == 1:
				# Drop down from pinch to 1 remaining finger
				var remaining_idx: int = active_touches.keys()[0]
				touch_start_pos = active_touches[remaining_idx]
				drag_start_target_pos = target_position
				is_touch_panning = true
			else:
				is_touch_panning = false
				if active_touches.is_empty():
					had_multi_touch = false

	elif event is InputEventScreenDrag:
		if active_touches.has(event.index):
			active_touches[event.index] = event.position

		if active_touches.size() == 1 and is_touch_panning:
			var touch_delta: Vector2 = (event.position - touch_start_pos) / zoom
			target_position = drag_start_target_pos - touch_delta
			_clamp_target_position()
		elif active_touches.size() == 2:
			var touches: Array = active_touches.values()
			var current_pinch_dist: float = (touches[0] as Vector2).distance_to(touches[1] as Vector2)
			if initial_pinch_distance > 10.0:
				var pinch_ratio: float = current_pinch_dist / initial_pinch_distance
				var midpoint: Vector2 = ((touches[0] as Vector2) + (touches[1] as Vector2)) * 0.5
				var desired_zoom_val: float = clampf(initial_pinch_zoom.x * pinch_ratio, min_zoom, max_zoom)
				var factor: float = desired_zoom_val / target_zoom.x
				_zoom_at_screen_pos(factor, midpoint)

func _process(delta: float) -> void:
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, clampf(zoom_smoothness * delta, 0.0, 1.0))
	if position != target_position:
		position = position.lerp(target_position, clampf(pan_smoothness * delta, 0.0, 1.0))

func _zoom_at_screen_pos(factor: float, screen_pos: Vector2) -> void:
	var old_zoom: Vector2 = target_zoom
	var new_zoom_val: float = clampf(old_zoom.x * factor, min_zoom, max_zoom)
	var new_zoom: Vector2 = Vector2(new_zoom_val, new_zoom_val)
	
	if old_zoom == new_zoom:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_viewport_offset: Vector2 = screen_pos - (viewport_size * 0.5)
	
	# Adjust target position so the point under the cursor/pinch stays fixed
	target_position += mouse_viewport_offset * ((1.0 / old_zoom.x) - (1.0 / new_zoom.x))
	target_zoom = new_zoom
	_clamp_target_position()

func _clamp_target_position() -> void:
	if map_bounds.size == Vector2.ZERO:
		return
	
	var viewport_size: Vector2 = get_viewport_rect().size
	var current_view_size: Vector2 = viewport_size / target_zoom
	var half_view: Vector2 = current_view_size * 0.5

	var min_x: float = map_bounds.position.x
	var max_x: float = map_bounds.end.x
	var min_y: float = map_bounds.position.y
	var max_y: float = map_bounds.end.y

	# If the viewport is larger than the map on either axis, center the map on that axis
	if current_view_size.x >= map_bounds.size.x:
		target_position.x = map_bounds.get_center().x
	else:
		target_position.x = clampf(target_position.x, min_x + half_view.x, max_x - half_view.x)

	if current_view_size.y >= map_bounds.size.y:
		target_position.y = map_bounds.get_center().y
	else:
		target_position.y = clampf(target_position.y, min_y + half_view.y, max_y - half_view.y)
