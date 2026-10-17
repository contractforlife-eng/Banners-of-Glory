class_name Geo
extends RefCounted
## Procedural geometry batcher + shared material library.
## Usage: var g := Geo.new(); g.box(size, pos, "stone"); ...; node.add_child(g.build())
## All primitives sharing a material merge into one surface (few draw calls).

static var _mats := {}

var _parts := {}  # mat_key -> Array of [Mesh, Transform3D]


static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	match key:
		"stone":
			m.albedo_color = Color(0.72, 0.68, 0.6)
			m.albedo_texture = _noise_tex(0.08, 0.55)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
		"dark_stone":
			m.albedo_color = Color(0.45, 0.43, 0.4)
			m.albedo_texture = _noise_tex(0.12, 0.6)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.3, 0.3, 0.3)
		"roof_red": m.albedo_color = Color(0.55, 0.18, 0.12)
		"roof_slate": m.albedo_color = Color(0.22, 0.25, 0.3)
		"roof_thatch": m.albedo_color = Color(0.62, 0.5, 0.28)
		"plaster": m.albedo_color = Color(0.86, 0.8, 0.68)
		"wood": m.albedo_color = Color(0.36, 0.24, 0.14)
		"field": m.albedo_color = Color(0.75, 0.62, 0.25)
		"field_green": m.albedo_color = Color(0.35, 0.5, 0.18)
		"tent": m.albedo_color = Color(0.85, 0.8, 0.7)
		"skin": m.albedo_color = Color(0.85, 0.65, 0.5)
		"metal":
			m.albedo_color = Color(0.6, 0.62, 0.66)
			m.metallic = 0.8
			m.roughness = 0.35
		"horse": m.albedo_color = Color(0.32, 0.2, 0.12)
		"gold":
			m.albedo_color = Color(1, 0.8, 0.3)
			m.metallic = 1.0
			m.roughness = 0.3
		"glow":
			m.albedo_color = Color(1, 0.75, 0.25)
			m.emission_enabled = true
			m.emission = Color(1, 0.7, 0.2)
			m.emission_energy_multiplier = 3.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_: m.albedo_color = Color.MAGENTA
	_mats[key] = m
	return m


static func team_mat(color: Color) -> StandardMaterial3D:
	var key := "team_" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.7
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func _noise_tex(freq: float, contrast: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(contrast, contrast, contrast))
	ramp.set_color(1, Color(1, 1, 1))
	t.color_ramp = ramp
	return t


func add(mesh: Mesh, xf: Transform3D, key) -> void:
	# key: material key String, or a Material instance (team colours).
	if not _parts.has(key):
		_parts[key] = []
	_parts[key].append([mesh, xf])


func box(size: Vector3, pos: Vector3, key, rot_y := 0.0) -> void:
	var m := BoxMesh.new()
	m.size = size
	add(m, Transform3D(Basis(Vector3.UP, rot_y), pos + Vector3(0, size.y * 0.5, 0)), key)


func cyl(radius: float, height: float, pos: Vector3, key, top := -1.0, sides := 12) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top < 0.0 else top
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	add(m, Transform3D(Basis(), pos + Vector3(0, height * 0.5, 0)), key)


func cone(radius: float, height: float, pos: Vector3, key) -> void:
	cyl(radius, height, pos, key, 0.0)


func prism(size: Vector3, pos: Vector3, key, rot_y := 0.0) -> void:
	var m := PrismMesh.new()
	m.size = size
	add(m, Transform3D(Basis(Vector3.UP, rot_y), pos + Vector3(0, size.y * 0.5, 0)), key)


func sphere(radius: float, pos: Vector3, key) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 10
	m.rings = 6
	add(m, Transform3D(Basis(), pos), key)


## A house: walls + gabled roof.
func house(pos: Vector3, w: float, d: float, h: float, rot: float, roof_key: String, wall_key := "plaster") -> void:
	box(Vector3(w, h, d), pos, wall_key, rot)
	prism(Vector3(w * 1.15, h * 0.7, d * 1.1), pos + Vector3(0, h, 0), roof_key, rot)


## A round tower with crenels and an optional conical roof.
func tower(pos: Vector3, r: float, h: float, roof_key := "") -> void:
	cyl(r, h, pos, "stone", r * 0.92)
	var crenels := 8
	for i in crenels:
		var a := TAU * i / crenels
		box(Vector3(r * 0.45, r * 0.4, r * 0.3), pos + Vector3(cos(a) * r * 0.85, h, sin(a) * r * 0.85), "stone", -a)
	if roof_key != "":
		cone(r * 1.1, r * 1.8, pos + Vector3(0, h, 0), roof_key)


## A straight crenellated wall between two points (on flat ground at y = pos.y).
func wall(a: Vector3, b: Vector3, h: float, thick: float) -> void:
	var mid := (a + b) * 0.5
	var dir := b - a
	var length := dir.length()
	var rot := atan2(dir.x, dir.z)
	box(Vector3(thick, h, length), mid, "stone", rot)
	var n := int(length / (thick * 1.4))
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t)
		box(Vector3(thick * 1.05, thick * 0.6, thick * 0.6), p + Vector3(0, h, 0), "stone", rot)


func build() -> MeshInstance3D:
	var am := ArrayMesh.new()
	for key in _parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in _parts[key]:
			st.append_from(part[0], 0, part[1])
		st.commit(am)
		var material: Material = key if key is Material else Geo.mat(key)
		am.surface_set_material(am.get_surface_count() - 1, material)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi
