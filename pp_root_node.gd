@tool
extends Node

const PPHTTPClient = preload("res://addons/planetary_processing/pp_editor_http_client.gd")
const Utils = preload("res://addons/planetary_processing/pp_utils.gd")
var SDKScript = preload("res://addons/planetary_processing/SDKNode.cs")

signal chunk_state_changed(chunk_id, new_state)
signal entity_state_changed(entity_id, new_state)
signal new_player_entity(entity_id, state)
signal new_chunk(chunk_id, state)
signal new_entity(entity_id, state)
signal player_authenticated(player_uuid)
signal player_authentication_error(err)
signal player_unauthenticated()
signal player_connected()
signal player_disconnected()
signal remove_chunk(chunk_id)
signal remove_entity(entity_id)

@export_category("Game Config")
var game_id = ''
#var username = ''
#var password = ''
var logged_in = false
var registered_entities = []
var registered_chunks = []
@export_range(64, 64, 65536) var Chunk_Size: int = 64

var csproj_reference_exists = false
var client = PPHTTPClient.new()
var player_is_connected = false
var player_uuid = null
var timer: Timer
var timer_wait_in_s = 10
var sdk_node



func _ready():
	if Engine.is_editor_hint():
		return
	assert(
		game_id != "",
		"Planetary Processing Game ID not configured"
	)
	sdk_node = SDKScript.new()
	sdk_node.SetGameID(game_id)
	
	var player_connected_timer = Timer.new()
	add_child(player_connected_timer)
	player_connected_timer.wait_time = 1.0
	player_connected_timer.connect("timeout", _on_player_connected_timer_timeout)
	player_connected_timer.start()

func _on_player_connected_timer_timeout():
	var new_player_is_connected = sdk_node.GetIsConnected()
	if not player_is_connected and new_player_is_connected:
		emit_signal("player_connected")
	if player_is_connected and not new_player_is_connected:
		emit_signal("player_disconnected")
	player_is_connected = new_player_is_connected

func authenticate_player(username: String, password: String):
	var callable = Callable(self, "authenticate_player_thread")
	var bound_callable = callable.bind(username, password)
	var thread = Thread.new()
	thread.start(bound_callable)
	thread.wait_to_finish()
	
func authenticate_player_thread(username: String, password: String):
	var err : String = sdk_node.Connect(username, password)
	if err:
		player_uuid = null
		var callable = Callable(self, "emit_signal")
		var bound_callable = callable.bind("player_authentication_error", err)
		bound_callable.call_deferred()
		return
	player_uuid = sdk_node.GetUUID()
	var callable = Callable(self, "emit_signal")
	var bound_callable = callable.bind("player_authenticated", player_uuid)
	bound_callable.call_deferred()

func message(msg):
	sdk_node.Message(msg)

func _process(delta):
	if Engine.is_editor_hint() or !sdk_node or !player_uuid:
		return
	sdk_node.Update()
	
	# ----- ENTITIES ------
	# iterate through entities, emit changes
	var entities = sdk_node.GetEntities()
	var entity_ids = entities.keys()
	var to_remove_entity_ids = registered_entities.duplicate()
	for entity_id in entity_ids:
		to_remove_entity_ids.erase(entity_id)
		var entity_data = entities[entity_id]
		if registered_entities.find(entity_id) != -1:
			emit_signal("entity_state_changed", entity_id, entity_data)
		else:
			if entity_id == player_uuid:
				emit_signal("new_player_entity", player_uuid, entity_data)
			else:
				emit_signal("new_entity", entity_id, entity_data)
				#print('Fired new_entity: ' + entity_id, entity_data)
	# remove missing entities
	for entity_id in to_remove_entity_ids:
		if entity_id != player_uuid:
			emit_signal("remove_entity", entity_id)
	registered_entities = entity_ids
	
	# ----- CHUNKS ------
	# Iterate through chunks, emit changes 
	var chunks = sdk_node.GetChunks()
	var chunk_ids = chunks.keys()
	# copy memory. We remove chunks from the copy that appear in new list until only those that don't appear are left
	var to_remove_chunk_ids = registered_chunks.duplicate()
	for chunk_id in chunk_ids:
		# Don't remove if in new chunks list
		to_remove_chunk_ids.erase(chunk_id)
		
		#change chunk if chunk in registered_chunks memory map
		var chunk_data = chunks[chunk_id]
		if registered_chunks.find(chunk_id) != -1: 
			emit_signal("chunk_state_changed", chunk_id, chunk_data)
					
		else: # Chunk has not been seen before 
			#emit new chunk
			emit_signal("new_chunk", chunk_id, chunk_data)
	
	#to_remove... now only includes chunks that didn't appear in new chunks list
	for chunk_id in to_remove_chunk_ids:
		emit_signal("remove_chunk", chunk_id)
	# Log chunk state in memory
	registered_chunks = chunk_ids

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "game_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_DEFAULT if logged_in else PROPERTY_USAGE_DEFAULT
	})
	if not csproj_reference_exists:
		properties.append({
			"name": "pp_button_add_csproj_reference",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	return properties

func _validate_fields():
	var regex = RegEx.new()
	regex.compile("^[0-9]+$")
	if not regex.search(game_id):
		return {
			"valid": false,
			"message": "Game ID should be a numeric value"
		}
	return {
		"valid": true,
		"message": ""
	}

func _on_button_pressed(text:String):
	var validation_result = _validate_fields()
	assert(validation_result.valid, validation_result.message)
	if text.to_lower() == "add csproj reference":
		_on_csproj_button_pressed()
		return
		
func _get_csharp_error_msg():
	return "C# solution not created. Trigger Project > Tools > C# > Create C# Solution"

func _on_csproj_button_pressed():
	var csproj_files = Utils.find_files_by_extension(".csproj")
	assert(len(csproj_files), _get_csharp_error_msg())
	Utils.add_planetary_csproj_ref('res://' + csproj_files[0])
	notify_property_list_changed()

func _get_entity_nodes():
	var entity_nodes : Array = []
	var root = get_tree().get_edited_scene_root()

	_recursive_scene_entity_traversal(root, entity_nodes)
	return entity_nodes

func _recursive_scene_entity_traversal(node, entity_nodes):
	for child in node.get_children():
		if 'is_entity_node' in child and child.is_entity_node:
			entity_nodes.append(child)
			break
		_recursive_scene_entity_traversal(child, entity_nodes)

func _remove_all_entity_scenes():
	var root = get_tree().get_root()
	_recursive_scene_entity_removal(root)

func _recursive_scene_entity_removal(node):
	for child in node.get_children():
		if 'is_entity_node' in child and child.is_entity_node:
			node.queue_free()
			break
		_recursive_scene_entity_removal(child)
		
func _enter_tree():
	if not Engine.is_editor_hint():
		_remove_all_entity_scenes()
		return

	# check for existence of cs proj / sln files
	var csproj_files = Utils.find_files_by_extension(".csproj")
	csproj_reference_exists = false
	notify_property_list_changed()
	assert(len(csproj_files), _get_csharp_error_msg())
	assert(len(Utils.find_files_by_extension(".sln")), _get_csharp_error_msg())
	csproj_reference_exists = Utils.csproj_planetary_reference_exists(csproj_files[0])
	notify_property_list_changed()
	assert(csproj_reference_exists, "Planetary Processing reference does not exist in " + csproj_files[0] + "\nClick \"Add Csproj Reference\" in the PPRootNode inspector to add the reference.")
