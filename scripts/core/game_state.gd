class_name GameState
extends Node
## Authoritative game state for the offline prototype.
## Every player action is a Command dictionary sent through submit_command().
## For multiplayer, NetworkService forwards commands to the authority World
## instead of applying them here; the UI and world only react to signals.

signal resources_changed(player_id: String)
signal location_changed(loc: LocationData)
signal command_rejected(reason: String)
signal march_ordered(army_id: String, target: Vector3)

const UPGRADE_COST := {"gold": 200, "wood": 150, "stone": 200}
const TICK_SECONDS := 2.0

var players := {}      # id -> PlayerData
var locations := {}    # id -> LocationData
var local_player_id := "p_local"
var _tick := 0.0


func _ready() -> void:
	for p in WorldSeed.players():
		players[p.id] = p
	for l in WorldSeed.locations():
		locations[l.id] = l


func local_player() -> PlayerData:
	return players.get(local_player_id)


func owner_of(loc: LocationData) -> PlayerData:
	return players.get(loc.owner_id)


func is_allied(loc: LocationData) -> bool:
	var o := owner_of(loc)
	return o != null and o.alliance_id == local_player().alliance_id


func _process(delta: float) -> void:
	_tick += delta
	if _tick < TICK_SECONDS:
		return
	_tick = 0.0
	for loc: LocationData in locations.values():
		var p: PlayerData = players.get(loc.owner_id)
		if p == null:
			continue
		for res in loc.production:
			p.resources[res] = p.resources.get(res, 0) + int(loc.production[res] * loc.level)
	resources_changed.emit(local_player_id)


## Single entry point for all gameplay actions (local or networked later).
func submit_command(cmd: Dictionary) -> bool:
	match cmd.get("type", ""):
		"upgrade":
			return _cmd_upgrade(cmd)
		"march":
			march_ordered.emit(cmd.army_id, cmd.target)
			return true
		"capture":
			return _cmd_capture(cmd)
	command_rejected.emit("Unknown command")
	return false


func can_afford(cost: Dictionary) -> bool:
	var r := local_player().resources
	for k in cost:
		if r.get(k, 0) < cost[k]:
			return false
	return true


func _cmd_upgrade(cmd: Dictionary) -> bool:
	var loc: LocationData = locations.get(cmd.location_id)
	if loc == null or loc.owner_id != local_player_id:
		command_rejected.emit("You can only upgrade your own holdings.")
		return false
	var cost := upgrade_cost(loc)
	if not can_afford(cost):
		command_rejected.emit("Not enough resources.")
		return false
	for k in cost:
		local_player().resources[k] -= cost[k]
	loc.level += 1
	loc.garrison += 100
	resources_changed.emit(local_player_id)
	location_changed.emit(loc)
	return true


func upgrade_cost(loc: LocationData) -> Dictionary:
	var c := {}
	for k in UPGRADE_COST:
		c[k] = UPGRADE_COST[k] * loc.level
	return c


## Called by the world when a local army arrives at a location (prototype rule:
## army strength beats garrison -> capture). Battles become a real system later.
func _cmd_capture(cmd: Dictionary) -> bool:
	var loc: LocationData = locations.get(cmd.location_id)
	if loc == null or loc.owner_id == local_player_id or is_allied(loc):
		return false
	if cmd.get("strength", 0) <= loc.garrison:
		command_rejected.emit("%s's garrison repelled your army." % loc.display_name)
		return false
	loc.owner_id = local_player_id
	loc.garrison = 50
	location_changed.emit(loc)
	return true
