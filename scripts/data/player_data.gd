class_name PlayerData
extends Resource
## One player account / kingdom. Later loaded from persistent account storage.

@export var id: String = ""
@export var display_name: String = ""
@export var alliance_id: String = ""
@export var banner_color: Color = Color(0.7, 0.1, 0.1)
@export var is_local: bool = false
@export var resources := {"gold": 500, "food": 800, "wood": 600, "stone": 400, "iron": 150}
@export var research := {}   # tech_id -> level (future tech tree)
@export var heroes: Array[String] = []
