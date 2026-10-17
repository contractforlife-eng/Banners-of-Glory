class_name TerrainTiles
extends RefCounted
## Builds the terrain TileSet in code (placeholder art).
## Later you can replace this with a real painted atlas: keep the same layout,
## 4 variants per row (x) and one row per terrain type (y, same order as TerrainData).

const VARIANTS := 4
const TYPE_COUNT := 7

const BASE: Array[Color] = [
	Color("1c3f73"), # ocean
	Color("2f6fa8"), # shallow water
	Color("3d82b8"), # lake
	Color("86a83f"), # grassland
	Color("2f5a28"), # forest
	Color("7b7771"), # mountain
	Color("d9b878"), # desert
]


static func build_tileset(tile: int) -> TileSet:
	var img := Image.create(tile * VARIANTS, tile * TYPE_COUNT, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260417
	for t in TYPE_COUNT:
		for v in VARIANTS:
			_draw_tile(img, v * tile, t * tile, tile, t, rng)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(tile, tile)
	for t in TYPE_COUNT:
		for v in VARIANTS:
			source.create_tile(Vector2i(v, t))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile, tile)
	tile_set.add_source(source, 0)
	return tile_set


static func _draw_tile(img: Image, ox: int, oy: int, size: int, type: int, rng: RandomNumberGenerator) -> void:
	var base: Color = BASE[type]
	for y in size:
		for x in size:
			var n := rng.randf_range(-0.04, 0.04)
			img.set_pixel(ox + x, oy + y, Color(base.r + n, base.g + n, base.b + n))

	match type:
		TerrainData.OCEAN, TerrainData.SHALLOW, TerrainData.LAKE:
			_draw_waves(img, ox, oy, size, base.lightened(0.18), rng)
		TerrainData.GRASS:
			_draw_tufts(img, ox, oy, size, base, rng)
		TerrainData.FOREST:
			_draw_trees(img, ox, oy, size, base, rng)
		TerrainData.MOUNTAIN:
			_draw_peak(img, ox, oy, size, base, rng)
		TerrainData.DESERT:
			_draw_dunes(img, ox, oy, size, base, rng)


static func _put(img: Image, ox: int, oy: int, size: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < size and y < size:
		img.set_pixel(ox + x, oy + y, c)


static func _draw_waves(img: Image, ox: int, oy: int, size: int, c: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var y := rng.randi_range(3, size - 4)
		var x0 := rng.randi_range(2, size - 12)
		for k in rng.randi_range(5, 9):
			_put(img, ox, oy, size, x0 + k, y + (1 if k % 4 > 1 else 0), c)


static func _draw_tufts(img: Image, ox: int, oy: int, size: int, base: Color, rng: RandomNumberGenerator) -> void:
	for i in 7:
		var x := rng.randi_range(2, size - 3)
		var y := rng.randi_range(3, size - 2)
		var c := base.lightened(0.22) if i % 2 == 0 else base.darkened(0.2)
		_put(img, ox, oy, size, x, y, c)
		_put(img, ox, oy, size, x - 1, y - 1, c)
		_put(img, ox, oy, size, x + 1, y - 1, c)


static func _draw_trees(img: Image, ox: int, oy: int, size: int, base: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var cx := rng.randi_range(7, size - 8)
		var cy := rng.randi_range(7, size - 8)
		var r := rng.randi_range(5, 7)
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var d := Vector2(x, y).length()
				if d <= r:
					var c := base.darkened(0.25)
					if Vector2(x + 2, y + 2).length() < r - 2:
						c = base.lightened(0.12)
					_put(img, ox, oy, size, cx + x, cy + y, c)


static func _draw_peak(img: Image, ox: int, oy: int, size: int, base: Color, rng: RandomNumberGenerator) -> void:
	var apex_x := size / 2 + rng.randi_range(-3, 3)
	var apex_y := 5
	var base_y := size - 5
	var half_w := 12
	for y in range(apex_y, base_y + 1):
		var t := float(y - apex_y) / float(base_y - apex_y)
		var hw := int(t * half_w)
		for x in range(-hw, hw + 1):
			var c := base.lightened(0.18) if x < 0 else base.darkened(0.3)
			if t < 0.28:
				c = Color(0.93, 0.95, 0.97) if x < 0 else Color(0.74, 0.78, 0.84)
			_put(img, ox, oy, size, apex_x + x, y, c)


static func _draw_dunes(img: Image, ox: int, oy: int, size: int, base: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var y0 := rng.randi_range(6, size - 6)
		var phase := rng.randf_range(0.0, TAU)
		for x in size:
			var y := y0 + int(round(sin(x * 0.3 + phase) * 2.0))
			_put(img, ox, oy, size, x, y, base.lightened(0.15))
			_put(img, ox, oy, size, x, y + 1, base.darkened(0.12))
