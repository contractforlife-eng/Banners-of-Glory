class_name NetworkService
extends Node
## Seam for future online play. Today it runs in OFFLINE mode and hands every
## command straight to the local GameState. When moving to Summer multiplayer
## (read the "multiplayer" skill), this becomes the client Session: commands are
## sent to the authority World, and State/Events update GameState here.

enum Mode { OFFLINE, ONLINE }

@export var mode := Mode.OFFLINE
@export var game_state_path: NodePath = ^"../GameState"


func send_command(cmd: Dictionary) -> bool:
	var gs := get_node(game_state_path) as GameState
	if mode == Mode.OFFLINE:
		return gs.submit_command(cmd)
	push_warning("Online mode not implemented yet")
	return false
