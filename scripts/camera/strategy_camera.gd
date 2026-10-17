class_name StrategyCamera
extends Camera3D
## World-map camera: full-map overview, fly-to on click, drag pan that keeps
## the grabbed ground point under the cursor, wheel zoom toward the cursor,
## and boundaries that keep the view inside the map at every zoom level.

@export var min_distance := 60.0
@export var close_distance := 170.0   # distance used when flying in to a location
@export var fly_speed := 4.0          # higher = faster smoothing
@export var key_pan_speed := 1.2      # screen-heights per second

var world: WorldBuilder
var focus := Vector3.ZERO           # current look-at point on the ground
var distance := 1000.0
var _goal_focus := Vector3.ZERO
var _goal_distance := 1000.0
var overview_distance := 2000.0


func setup(w: WorldBuilder) -> void:
	world = w
	fov = 50.0
	near = 1.0
	far = 9000.0
	_update_overview_distance()
	get_viewport().size_changed.connect(_update_overview_distance)
	show_overview(true)


func _update_overview_distance() -> void:
	var half := world.map_size * 0.5
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / max(vp.y, 1.0)
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	# Fit both the vertical and horizontal extent (pitch is near top-down at overview).
	overview_distance = max(half / tan_v, half / (tan_v * aspect)) * 1.08
	_goal_distance = min(_goal_distance, overview_distance)


func show_overview(instant := false) -> void:
	_goal_focus = Vector3.ZERO
	_goal_distance = overview_distance
	if instant:
		focus = _goal_focus
		distance = _goal_distance
		_apply()


func fly_to(point: Vector3, dist := -1.0) -> void:
	_goal_focus = Vector3(point.x, 0, point.z)
	_goal_distance = clamp(close_distance if dist < 0.0 else dist, min_distance, overview_distance)
	_clamp_goal()


func is_overview() -> bool:
	return _goal_distance >= overview_distance * 0.98


## Zoom by factor (<1 zooms in) keeping `anchor` (ground point) roughly fixed on screen.
func zoom(factor: float, anchor: Variant) -> void:
	var old := _goal_distance
	_goal_distance = clamp(_goal_distance * factor, min_distance, overview_distance)
	if anchor != null and _goal_distance < old:
		var a: Vector3 = anchor
		var t := 1.0 - _goal_distance / old
		_goal_focus += (Vector3(a.x, 0, a.z) - _goal_focus) * t
	_clamp_goal()


## Drag pan: move so the ground point under `from_px` ends up under `to_px`.
func drag(from_px: Vector2, to_px: Vector2) -> void:
	var plane := Plane(Vector3.UP, 0.0)
	var a: Variant = plane.intersects_ray(project_ray_origin(from_px), project_ray_normal(from_px))
	var b: Variant = plane.intersects_ray(project_ray_origin(to_px), project_ray_normal(to_px))
	if a == null or b == null:
		return
	var delta: Vector3 = a - b
	delta.y = 0.0
	_goal_focus += delta
	_clamp_goal()
	focus = Vector3(_goal_focus.x, focus.y, _goal_focus.z)  # drag is immediate, no lag


func pan_screen(dir: Vector2, delta: float) -> void:
	var span := distance * tan(deg_to_rad(fov) * 0.5) * 2.0
	_goal_focus += Vector3(dir.x, 0, dir.y) * span * key_pan_speed * delta
	_clamp_goal()


func _clamp_goal() -> void:
	# Allowed extent shrinks to zero at full overview so the map stays framed.
	var half := world.map_size * 0.5
	var zoom_t := clampf(1.0 - _goal_distance / overview_distance, 0.0, 1.0)
	var lim := half * sqrt(zoom_t)
	_goal_focus.x = clamp(_goal_focus.x, -lim, lim)
	_goal_focus.z = clamp(_goal_focus.z, -lim, lim)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-fly_speed * delta)
	focus.x = lerp(focus.x, _goal_focus.x, k)
	focus.z = lerp(focus.z, _goal_focus.z, k)
	distance = lerp(distance, _goal_distance, k)
	_apply()


func _apply() -> void:
	var ground: float = world.ground_y(focus.x, focus.z) if world else 0.0
	focus.y = lerp(focus.y, ground, 0.2)
	# Pitch: near top-down at overview, tilting toward the horizon when close.
	var t := clampf((distance - min_distance) / (overview_distance - min_distance), 0.0, 1.0)
	var pitch := deg_to_rad(lerp(-38.0, -82.0, pow(t, 0.55)))
	var back := Vector3(0, -sin(pitch), cos(pitch))  # camera sits south (+Z) of focus
	position = focus + back * distance
	var min_y: float = world.ground_y(position.x, position.z) + 12.0 if world else 12.0
	position.y = max(position.y, min_y)
	look_at(focus, Vector3.UP)
