@tool
extends Node

signal authentication_successful(username)
signal entity_state_changed(entity_id, new_state)

var game_id : String
var is_authenticated : bool = false

func authenticate(username: String, password: String) -> bool:
	is_authenticated = true
	emit_signal("authentication_successful", game_id, username)
	return true

func update_entity_state(entity_id: int, new_state: Dictionary) -> void:
	emit_signal("entity_state_changed", entity_id, new_state)

func _ready():
	if Engine.is_editor_hint():
		return
	assert(
		ProjectSettings.has_setting("pp_game_id") and ProjectSettings.get_setting("pp_game_id") != "",
		"Planetary Processing Game ID not configured"
	)
	game_id = ProjectSettings.get_setting("pp_game_id")
	
	# for testing, call authenticate on ready - will be up to the developer to
	# trigger auth how they see fit in real games
	authenticate("any_username", "any_password")

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	print('yo')
	get_tree().connect("node_added", _on_node_added)
	
func _exit_tree():
	if not Engine.is_editor_hint():
		return
	get_tree().disconnect("node_added", _on_node_added)

func _on_node_added(node):
	if 'is_entity_node' in node:
		print('entity node added: ', node.name)
