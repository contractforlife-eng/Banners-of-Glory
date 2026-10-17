class_name MapLocation
extends Node3D
## Visual + selection for one LocationData on the world map.
## Visuals are procedural (Geo); swap _build_* for imported models later.

var data: LocationData
var state: GameState
var pick_radius := 40.0

var _label: Label3D
var _ring: MeshInstance3D
var _banner: MeshInstance3D
var _visual: MeshInstance3D
var _time := 0.0


func setup(loc: LocationData, game_state: GameState, world: WorldBuilder) -> void:
	data = loc
	state = game_state
	name = loc.id
	position = Vector3(loc.map_position.x, world.ground_y(loc.map_position.x, loc.map_position.y), loc.map_position.y)
	add_to_group("map_location")
	_rebuild()
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = pick_radius * 0.92
	torus.outer_radius = pick_radius
	torus.rings = 48
	_ring.mesh = torus
	_ring.material_override = Geo.mat("glow")
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.6
	_ring.visible = false
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0009
	_label.font_size = 30
	_label.outline_size = 10
	_label.no_depth_test = true
	_label.position.y = 38.0
	add_child(_label)
	refresh()


func owner_color() -> Color:
	var o := state.owner_of(data)
	return o.banner_color if o else Color(0.75, 0.75, 0.75)


func refresh() -> void:
	_label.text = "%s  [%d]" % [data.display_name, data.level]
	_label.modulate = owner_color().lightened(0.35)
	_build_banner()


func set_selected(on: bool) -> void:
	_ring.visible = on


func _process(delta: float) -> void:
	_time += delta
	if _ring.visible:
		var s := 1.0 + sin(_time * 4.0) * 0.04
		_ring.scale = Vector3(s, 0.05, s)
	if _banner:
		_banner.rotation.y = sin(_time * 1.7 + position.x) * 0.25


func _rebuild() -> void:
	if _visual:
		_visual.queue_free()
	var g := Geo.new()
	match data.kind:
		LocationData.Kind.CASTLE: _build_castle(g)
		LocationData.Kind.CITY: _build_city(g)
		LocationData.Kind.VILLAGE: _build_village(g)
		LocationData.Kind.FORTRESS: _build_fortress(g)
		LocationData.Kind.BATTLEFIELD: _build_battlefield(g)
	_visual = g.build()
	add_child(_visual)


func _build_castle(g: Geo) -> void:
	pick_radius = 45.0
	var s := 22.0
	var h := 10.0
	var corners := [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]
	for i in 4:
		g.wall(corners[i], corners[(i + 1) % 4], h, 3.0)
		g.tower(corners[i], 5.0, h + 6.0, "roof_slate")
	# Gatehouse on the south (+Z) side
	g.box(Vector3(12, h + 4, 7), Vector3(0, 0, s), "dark_stone")
	g.box(Vector3(5, 5, 7.4), Vector3(0, 0, s), "wood")
	# Keep
	g.box(Vector3(16, 22, 16), Vector3(0, 0, -2), "stone")
	for c in [Vector3(-8, 0, -10), Vector3(8, 0, -10), Vector3(-8, 0, 6), Vector3(8, 0, 6)]:
		g.tower(c, 3.0, 28.0, "roof_slate")
	g.prism(Vector3(17, 8, 17), Vector3(0, 22, -2), "roof_slate")
	# Courtyard buildings and a moat-like ditch ring of dark stone
	g.house(Vector3(-13, 0, 12), 8, 5, 5, 0.0, "roof_red")
	g.house(Vector3(13, 0, 12), 8, 5, 5, 0.0, "roof_red")
	g.box(Vector3(2 * s + 16, 0.4, 2 * s + 16), Vector3(0, -0.2, 0), "dark_stone")


func _build_city(g: Geo) -> void:
	pick_radius = 50.0
	var r := 40.0
	var segs := 10
	for i in segs:
		var a := TAU * i / segs
		var b := TAU * (i + 1) / segs
		g.wall(Vector3(cos(a) * r, 0, sin(a) * r), Vector3(cos(b) * r, 0, sin(b) * r), 7.0, 2.4)
		g.tower(Vector3(cos(a) * r, 0, sin(a) * r), 3.4, 11.0, "roof_red")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.id)
	for i in 34:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, r - 7.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		g.house(p, rng.randf_range(5, 8), rng.randf_range(5, 9), rng.randf_range(4, 8), a, ["roof_red", "roof_slate"][i % 2])
	# Cathedral
	g.box(Vector3(10, 14, 22), Vector3(0, 0, 0), "stone")
	g.prism(Vector3(11, 7, 23), Vector3(0, 14, 0), "roof_slate")
	g.box(Vector3(6, 30, 6), Vector3(0, 0, -12), "stone")
	g.cone(4.5, 12, Vector3(0, 30, -12), "roof_slate")


func _build_village(g: Geo) -> void:
	pick_radius = 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.id)
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, 20.0)
		g.house(Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(4, 6), rng.randf_range(5, 8), 3.5, a, "roof_thatch", "plaster")
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		g.box(Vector3(16, 0.3, 24), Vector3(cos(a) * 36, 0, sin(a) * 36), "field" if i % 2 == 0 else "field_green", a)
	g.cyl(1.6, 2.0, Vector3(0, 0, 0), "stone")  # well


func _build_fortress(g: Geo) -> void:
	pick_radius = 34.0
	var s := 15.0
	var corners := [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]
	for i in 4:
		g.wall(corners[i], corners[(i + 1) % 4], 9.0, 3.0)
		g.tower(corners[i], 4.0, 13.0)
	g.tower(Vector3.ZERO, 7.0, 26.0, "roof_slate")
	g.box(Vector3(9, 4, 4), Vector3(0, 0, s), "wood")


func _build_battlefield(g: Geo) -> void:
	pick_radius = 45.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.id)
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(22, 38), 0, rng.randf_range(-30, 30))
		g.prism(Vector3(5, 4, 6), p, "tent", rng.randf() * 0.4)
	for i in 30:  # broken spears / stakes
		var p := Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-25, 25))
		g.box(Vector3(0.25, 3.0, 0.25), p, "wood", rng.randf() * TAU)
	g.box(Vector3(30, 0.15, 56), Vector3.ZERO, "dark_stone")


func _build_banner() -> void:
	if _banner:
		_banner.queue_free()
	var g := Geo.new()
	var top := 30.0 if data.kind == LocationData.Kind.CASTLE else 20.0
	if data.kind == LocationData.Kind.VILLAGE:
		top = 10.0
	g.cyl(0.35, top + 8.0, Vector3.ZERO, "wood")
	g.box(Vector3(0.2, 4.5, 7.0), Vector3(0, top + 3.0, 3.6), Geo.team_mat(owner_color()))
	g.sphere(0.7, Vector3(0, top + 8.3, 0), "gold")
	_banner = g.build()
	add_child(_banner)
