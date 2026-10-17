class_name WorldBuilder
extends Node3D
## Builds the procedural kingdom terrain, sea and forests.
## height_at() is the single source of truth for ground height (picking,
## unit movement, placement), so no physics is needed on the world map.

const RES := 200
const WATER_LEVEL := 0.0

@export var seed_value := 7

var map_size := WorldSeed.MAP_SIZE
var minimap_image: Image
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _pads: Array = []  # [Vector2 pos, radius, height]


func build(locations: Array) -> void:
	_noise.seed = seed_value
	_noise.frequency = 0.0022
	_noise.fractal_octaves = 5
	_detail.seed = seed_value + 11
	_detail.frequency = 0.02
	for loc: LocationData in locations:
		var r := 70.0 if loc.kind in [LocationData.Kind.CASTLE, LocationData.Kind.CITY] else 45.0
		_pads.append([loc.map_position, r, max(_raw_height(loc.map_position.x, loc.map_position.y), 4.0)])
	_build_terrain()
	_build_water()
	_build_forests()


func _raw_height(x: float, z: float) -> float:
	var half := map_size * 0.5
	var edge: float = max(abs(x), abs(z)) / half
	var falloff := smoothstep(0.72, 1.0, edge)
	var n := _noise.get_noise_2d(x, z)
	var h := 14.0 + n * 55.0
	if n > 0.25:
		h += pow((n - 0.25) * 2.2, 2.0) * 90.0  # mountains
	h += _detail.get_noise_2d(x, z) * 2.0
	return lerp(h, -25.0, falloff)


func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	for pad in _pads:
		var d: float = Vector2(x, z).distance_to(pad[0])
		if d < pad[1] * 1.6:
			h = lerp(float(pad[2]), h, smoothstep(pad[1], pad[1] * 1.6, d))
	return h


func ground_y(x: float, z: float) -> float:
	return max(height_at(x, z), WATER_LEVEL)


func _color_for(h: float, slope: float, x: float, z: float) -> Color:
	var v := _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	var c: Color
	if h < 1.5:
		c = Color(0.76, 0.7, 0.5)
	elif h < 40.0:
		c = Color(0.32, 0.48, 0.18).lerp(Color(0.45, 0.52, 0.22), clamp(h / 40.0, 0.0, 1.0))
	elif h < 75.0:
		c = Color(0.42, 0.4, 0.33)
	else:
		c = Color(0.93, 0.94, 0.97)
	if slope > 0.55 and h < 75.0:
		c = c.lerp(Color(0.45, 0.42, 0.38), 0.7)
	return Color(c.r + v, c.g + v, c.b + v)


func _build_terrain() -> void:
	var step := map_size / RES
	var half := map_size * 0.5
	var heights := PackedFloat32Array()
	heights.resize((RES + 1) * (RES + 1))
	for iz in RES + 1:
		for ix in RES + 1:
			heights[iz * (RES + 1) + ix] = height_at(-half + ix * step, -half + iz * step)
	minimap_image = Image.create(RES + 1, RES + 1, false, Image.FORMAT_RGB8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in RES + 1:
		for ix in RES + 1:
			var h := heights[iz * (RES + 1) + ix]
			var hl := heights[iz * (RES + 1) + max(ix - 1, 0)]
			var hr := heights[iz * (RES + 1) + min(ix + 1, RES)]
			var hd := heights[max(iz - 1, 0) * (RES + 1) + ix]
			var hu := heights[min(iz + 1, RES) * (RES + 1) + ix]
			var normal := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			var x := -half + ix * step
			var z := -half + iz * step
			var col := _color_for(h, 1.0 - normal.y, x, z)
			minimap_image.set_pixel(ix, iz, col if h > WATER_LEVEL else Color(0.16, 0.32, 0.45).lerp(Color(0.05, 0.12, 0.25), clamp(-h / 25.0, 0.0, 1.0)))
			st.set_color(col)
			st.set_normal(normal)
			st.add_vertex(Vector3(x, h, z))
	for iz in RES:
		for ix in RES:
			var i := iz * (RES + 1) + ix
			st.add_index(i); st.add_index(i + 1); st.add_index(i + RES + 1)
			st.add_index(i + 1); st.add_index(i + RES + 2); st.add_index(i + RES + 1)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_size * 3.0, map_size * 3.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.3, 0.42, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4
	m.roughness = 0.08
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	mi.material_override = m
	mi.position.y = WATER_LEVEL
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _near_pad(x: float, z: float, extra: float) -> bool:
	for pad in _pads:
		if Vector2(x, z).distance_to(pad[0]) < pad[1] + extra:
			return true
	return false


func _build_forests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var forest := FastNoiseLite.new()
	forest.seed = seed_value + 3
	forest.frequency = 0.006
	var xforms: Array[Transform3D] = []
	var half := map_size * 0.48
	var tries := 0
	while xforms.size() < 6000 and tries < 60000:
		tries += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if forest.get_noise_2d(x, z) < 0.08:
			continue
		var h := height_at(x, z)
		if h < 3.0 or h > 62.0 or _near_pad(x, z, 15.0):
			continue
		var s := rng.randf_range(0.8, 1.5)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s)), Vector3(x, h - 0.3, z)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35; trunk.bottom_radius = 0.5; trunk.height = 3.0; trunk.radial_segments = 5; trunk.rings = 1
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0; crown.bottom_radius = 3.2; crown.height = 9.0; crown.radial_segments = 7; crown.rings = 1
	var trunk_m := StandardMaterial3D.new()
	trunk_m.albedo_color = Color(0.3, 0.2, 0.12)
	var crown_m := StandardMaterial3D.new()
	crown_m.albedo_color = Color(0.12, 0.3, 0.12)
	crown_m.roughness = 1.0
	_multimesh("TreeTrunks", trunk, trunk_m, xforms, Vector3(0, 1.5, 0))
	_multimesh("TreeCrowns", crown, crown_m, xforms, Vector3(0, 7.0, 0))


func _multimesh(n: String, mesh: Mesh, m: Material, xforms: Array[Transform3D], offset: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var xf := xforms[i]
		mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin + xf.basis * offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)


## Ray vs terrain (ray-march + bisection). Returns null if no hit.
func ray_ground(from: Vector3, dir: Vector3, max_dist := 8000.0) -> Variant:
	var t := 0.0
	var prev := 0.0
	var step := 6.0
	while t < max_dist:
		var p := from + dir * t
		if p.y <= ground_y(p.x, p.z):
			var lo := prev
			var hi := t
			for i in 12:
				var mid := (lo + hi) * 0.5
				var q := from + dir * mid
				if q.y <= ground_y(q.x, q.z): hi = mid
				else: lo = mid
			return from + dir * hi
		prev = t
		t += step
		step = min(step * 1.02, 25.0)
	return null
