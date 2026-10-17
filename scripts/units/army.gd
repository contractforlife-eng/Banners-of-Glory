class_name Army
extends Node3D
## A hero-led army on the world map. Moves over terrain toward a target,
## marches with a procedural step bob, and reports arrival.

signal arrived(army: Army)

const SCALE := 2.4  # strategy-map exaggeration so troops read from afar

@export var army_id := "army_hero"
@export var hero_name := "Sir Kareem"
@export var owner_id := "p_local"
@export var strength := 1200
@export var speed := 55.0
@export var soldier_count := 16

var world: WorldBuilder
var target: Variant = null
var patrol: Array[Vector3] = []
var _patrol_i := 0
var _soldiers: Array[Node3D] = []
var _time := 0.0
var _ring: MeshInstance3D
var _label: Label3D
var _banner: Node3D


func setup(w: WorldBuilder, team_color: Color, start: Vector3) -> void:
	world = w
	add_to_group("army")
	position = Vector3(start.x, w.ground_y(start.x, start.z), start.z)
	var soldier := _soldier_mesh(team_color)
	var cols := 4
	for i in soldier_count:
		var s := MeshInstance3D.new()
		s.mesh = soldier
		s.scale = Vector3.ONE * SCALE
		s.position = Vector3((i % cols - (cols - 1) * 0.5) * 2.6, 0, 3.0 + floor(i / float(cols)) * 2.8)
		add_child(s)
		_soldiers.append(s)
	var hero := MeshInstance3D.new()
	hero.mesh = _hero_mesh(team_color)
	hero.scale = Vector3.ONE * SCALE
	hero.position = Vector3(0, 0, -2.5)
	add_child(hero)
	_soldiers.append(hero)
	var g := Geo.new()
	g.cyl(0.12, 9.0, Vector3.ZERO, "wood")
	g.box(Vector3(0.08, 2.2, 3.2), Vector3(0, 6.6, 1.6), Geo.team_mat(team_color))
	_banner = g.build()
	_banner.scale = Vector3.ONE * 1.4
	_banner.position = Vector3(1.8, 0, -1.0)
	add_child(_banner)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 11.0
	torus.outer_radius = 12.0
	_ring.mesh = torus
	_ring.material_override = Geo.mat("glow")
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position = Vector3(0, 0.5, 3.0)
	_ring.visible = false
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.font_size = 26
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.modulate = team_color.lightened(0.4)
	_label.text = "%s (%d)" % [hero_name, strength]
	_label.position.y = 18.0
	add_child(_label)


func set_selected(on: bool) -> void:
	_ring.visible = on


func move_to(p: Vector3) -> void:
	target = Vector3(p.x, 0, p.z)


func is_moving() -> bool:
	return target != null


func _process(delta: float) -> void:
	_time += delta
	if target == null and not patrol.is_empty():
		move_to(patrol[_patrol_i])
		_patrol_i = (_patrol_i + 1) % patrol.size()
	if target != null:
		var to: Vector3 = target - Vector3(position.x, 0, position.z)
		var dist := to.length()
		if dist < 2.0:
			target = null
			arrived.emit(self)
		else:
			var dir := to / dist
			var step: float = min(speed * delta, dist)
			position.x += dir.x * step
			position.z += dir.z * step
			var want := atan2(-dir.x, -dir.z)  # model forward is -Z
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-8.0 * delta))
	position.y = lerp(position.y, world.ground_y(position.x, position.z), 1.0 - exp(-10.0 * delta))
	var moving := target != null
	for i in _soldiers.size():
		var s := _soldiers[i]
		var bob: float = abs(sin(_time * 9.0 + i * 1.3)) * 0.5 if moving else sin(_time * 1.5 + i) * 0.05
		s.position.y = bob
		s.rotation.z = sin(_time * 9.0 + i * 1.3) * 0.06 if moving else 0.0
	_banner.rotation.y = sin(_time * 2.0) * 0.3
	if _ring.visible:
		_ring.rotation.y += delta


static func _soldier_mesh(team: Color) -> Mesh:
	var g := Geo.new()
	g.box(Vector3(0.18, 0.8, 0.22), Vector3(-0.13, 0, 0), "wood")       # legs
	g.box(Vector3(0.18, 0.8, 0.22), Vector3(0.13, 0, 0), "wood")
	g.box(Vector3(0.55, 0.75, 0.32), Vector3(0, 0.8, 0), Geo.team_mat(team))  # tabard
	g.sphere(0.17, Vector3(0, 1.75, 0), "skin")
	g.cone(0.2, 0.25, Vector3(0, 1.82, 0), "metal")                  # helmet
	g.box(Vector3(0.08, 0.7, 0.55), Vector3(-0.36, 0.75, -0.05), Geo.team_mat(team.darkened(0.3)))  # shield
	g.cyl(0.03, 2.4, Vector3(0.36, 0.2, -0.1), "wood")               # spear
	g.cone(0.07, 0.3, Vector3(0.36, 2.6, -0.1), "metal")
	return g.build().mesh


static func _hero_mesh(team: Color) -> Mesh:
	var g := Geo.new()
	g.box(Vector3(0.6, 0.75, 1.9), Vector3(0, 0.75, 0), "horse")      # horse body
	for p in [Vector3(-0.22, 0, -0.7), Vector3(0.22, 0, -0.7), Vector3(-0.22, 0, 0.7), Vector3(0.22, 0, 0.7)]:
		g.box(Vector3(0.15, 0.8, 0.15), p, "horse")
	g.box(Vector3(0.3, 0.7, 0.35), Vector3(0, 1.3, -1.0), "horse")   # neck/head
	g.box(Vector3(0.66, 0.4, 1.0), Vector3(0, 1.1, 0), Geo.team_mat(team))  # caparison
	g.box(Vector3(0.5, 0.7, 0.32), Vector3(0, 1.5, 0.1), "metal")     # rider
	g.sphere(0.17, Vector3(0, 2.4, 0.1), "metal")
	g.cyl(0.04, 1.2, Vector3(0.0, 2.3, 0.1), "gold", 0.0)             # plume
	return g.build().mesh
