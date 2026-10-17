extends Node3D
## World map controller: builds the world, spawns locations and armies,
## and turns mouse/keyboard input into camera moves, selection and commands.

const DRAG_THRESHOLD := 6.0
const PICK_PX := 34.0

@onready var state: GameState = $GameState
@onready var world: WorldBuilder = $World
@onready var cam: StrategyCamera = $StrategyCamera
@onready var hud: GameHUD = $HUD

var locations := {}          # id -> MapLocation
var hero: Army
var selected_location: MapLocation
var selected_army: Army
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _march_target_loc: LocationData


func _ready() -> void:
	world.build(state.locations.values())
	for loc: LocationData in state.locations.values():
		var ml := MapLocation.new()
		$Locations.add_child(ml)
		ml.setup(loc, state, world)
		locations[loc.id] = ml
	_spawn_armies()
	cam.setup(world)
	hud.setup(state, world, cam)
	hud.overview_requested.connect(_on_overview)
	hud.minimap_clicked.connect(func(p): cam.fly_to(p, cam.close_distance * 1.6))
	hud.upgrade_requested.connect(_on_upgrade)
	hud.march_requested.connect(_on_march_to_location)
	state.location_changed.connect(func(l): locations[l.id].refresh())
	state.march_ordered.connect(_on_march_ordered)
	hud.toast("Welcome, lord of House Al-Nasr. Click a castle to inspect it.")


func _spawn_armies() -> void:
	var home: LocationData = state.locations["c_home"]
	hero = Army.new()
	hero.name = "HeroArmy"
	$Armies.add_child(hero)
	hero.setup(world, state.local_player().banner_color, Vector3(home.map_position.x + 70, 0, home.map_position.y + 20))
	hero.arrived.connect(_on_army_arrived)
	var red: LocationData = state.locations["c_varn"]
	var fort: LocationData = state.locations["fort_1"]
	var enemy := Army.new()
	enemy.name = "VarnPatrol"
	enemy.army_id = "army_varn"
	enemy.hero_name = "Lord Varn"
	enemy.owner_id = "p_red"
	enemy.strength = 1500
	enemy.speed = 35.0
	$Armies.add_child(enemy)
	enemy.setup(world, state.players["p_red"].banner_color, Vector3(red.map_position.x - 60, 0, red.map_position.y))
	enemy.patrol = [Vector3(fort.map_position.x, 0, fort.map_position.y + 60), Vector3(red.map_position.x - 70, 0, red.map_position.y + 40), Vector3(220, 0, -260)]


func _process(delta: float) -> void:
	var dir := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
	if dir != Vector2.ZERO:
		cam.pan_screen(dir.normalized(), delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
				_last_pos = mb.position
			elif _pressing:
				_pressing = false
				if not _dragging:
					_on_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_on_right_click(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom(0.85, _ground_at(mb.position))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom(1.18, null)
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			cam.drag(_last_pos, mm.position)
			_last_pos = mm.position
	elif event.is_action_pressed("cam_overview"):
		_on_overview()
	elif event.is_action_pressed("ui_cancel"):
		_clear_selection()
		hud.hide_panel()


func _ground_at(px: Vector2) -> Variant:
	return world.ray_ground(cam.project_ray_origin(px), cam.project_ray_normal(px))


func _screen_dist(px: Vector2, p: Vector3) -> float:
	if cam.is_position_behind(p):
		return INF
	return cam.unproject_position(p).distance_to(px)


func _pick_army(px: Vector2) -> Army:
	var best: Army = null
	var best_d := PICK_PX
	for a: Army in get_tree().get_nodes_in_group("army"):
		var d := _screen_dist(px, a.global_position + Vector3(0, 3, 3))
		if d < best_d:
			best_d = d
			best = a
	return best


func _pick_location(px: Vector2) -> MapLocation:
	var best: MapLocation = null
	var best_d := INF
	for ml: MapLocation in locations.values():
		var center := ml.global_position + Vector3(0, 8, 0)
		var d := _screen_dist(px, center)
		var edge := _screen_dist(px, center + cam.global_basis.x * ml.pick_radius)
		var radius_px: float = max(PICK_PX, abs(edge - d) if edge < INF else PICK_PX)
		radius_px = max(radius_px, cam.unproject_position(center).distance_to(cam.unproject_position(center + cam.global_basis.x * ml.pick_radius)))
		if d < radius_px and d < best_d:
			best_d = d
			best = ml
	return best


func _on_click(px: Vector2) -> void:
	var army := _pick_army(px)
	if army:
		_clear_selection()
		selected_army = army
		army.set_selected(true)
		hud.show_army(army)
		return
	var ml := _pick_location(px)
	if ml:
		_select_location(ml)
		return
	var g: Variant = _ground_at(px)
	if g != null:
		_clear_selection(true)
		hud.hide_panel()
		cam.fly_to(g, min(cam.distance * 0.45, cam.close_distance * 1.4) if not cam.is_overview() else cam.close_distance * 1.4)


func _select_location(ml: MapLocation) -> void:
	_clear_selection()
	selected_location = ml
	ml.set_selected(true)
	hud.show_location(ml.data)
	cam.fly_to(ml.global_position, cam.close_distance)


func _clear_selection(keep_army := false) -> void:
	if selected_location:
		selected_location.set_selected(false)
		selected_location = null
	if selected_army and not keep_army:
		selected_army.set_selected(false)
		selected_army = null


func _on_right_click(px: Vector2) -> void:
	var army: Army = selected_army
	if army == null or army.owner_id != state.local_player_id:
		hud.toast("Select your hero army first (left-click it), then right-click to march.")
		return
	var ml := _pick_location(px)
	if ml:
		_march_target_loc = ml.data
		state.submit_command({"type": "march", "army_id": army.army_id, "target": ml.global_position})
		return
	var g: Variant = _ground_at(px)
	if g != null:
		_march_target_loc = null
		state.submit_command({"type": "march", "army_id": army.army_id, "target": g})


func _on_march_ordered(army_id: String, target: Vector3) -> void:
	if army_id == hero.army_id:
		hero.move_to(target + Vector3(0, 0, 0))
		hud.toast("%s marches out!" % hero.hero_name)


func _on_march_to_location(loc: LocationData) -> void:
	_march_target_loc = loc
	var ml: MapLocation = locations[loc.id]
	state.submit_command({"type": "march", "army_id": hero.army_id, "target": ml.global_position})


func _on_army_arrived(army: Army) -> void:
	if army != hero or _march_target_loc == null:
		return
	var loc := _march_target_loc
	_march_target_loc = null
	if loc.owner_id == state.local_player_id or state.is_allied(loc):
		hud.toast("%s reinforced %s." % [hero.hero_name, loc.display_name])
	elif state.submit_command({"type": "capture", "location_id": loc.id, "strength": hero.strength}):
		hud.toast("Victory! %s now flies your banner." % loc.display_name, Color(0.6, 1, 0.6))


func _on_upgrade(loc: LocationData) -> void:
	if state.submit_command({"type": "upgrade", "location_id": loc.id}):
		hud.toast("%s upgraded to level %d!" % [loc.display_name, loc.level], Color(0.6, 1, 0.6))


func _on_overview() -> void:
	_clear_selection(true)
	hud.hide_panel()
	cam.show_overview()
