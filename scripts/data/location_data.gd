class_name LocationData
extends Resource
## Pure data for one map location. Serializable, so it can later come from a
## server / persistent world save instead of the local seed in WorldSeed.

enum Kind { CASTLE, CITY, VILLAGE, FORTRESS, BATTLEFIELD }

const KIND_NAMES := {
	Kind.CASTLE: "Castle",
	Kind.CITY: "City",
	Kind.VILLAGE: "Village",
	Kind.FORTRESS: "Fortress",
	Kind.BATTLEFIELD: "Battlefield",
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.VILLAGE
@export var map_position: Vector2 = Vector2.ZERO  # world X/Z
@export var owner_id: String = ""                 # "" = neutral
@export var level: int = 1
@export var garrison: int = 100
@export var production := {"gold": 2, "food": 4, "wood": 3, "stone": 1, "iron": 0}
@export_multiline var description: String = ""


func kind_name() -> String:
	return KIND_NAMES.get(kind, "Location")


func to_dict() -> Dictionary:
	return {
		"id": id, "name": display_name, "kind": kind, "x": map_position.x, "z": map_position.y,
		"owner": owner_id, "level": level, "garrison": garrison, "production": production,
	}
