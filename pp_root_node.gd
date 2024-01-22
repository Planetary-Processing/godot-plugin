@tool
extends Node

const PPHTTPClient = preload("res://addons/planetary_processing/pp_editor_http_client.gd")
const Utils = preload("res://addons/planetary_processing/pp_utils.gd")
var SDKScript = preload("res://addons/planetary_processing/SDKNode.cs")

signal entity_state_changed(entity_id, new_state)
signal new_player_entity(entity_id, state)
signal new_entity(entity_id, state)
signal player_authenticated(player_uuid)
signal player_authentication_error(err)
signal player_unauthenticated()
signal player_connected()
signal player_disconnected()
signal remove_entity(entity_id)

static var base_path = "res://addons/planetary_processing/lua/"

@export_category("Game Config")
var game_id = ''
var username = ''
var password = ''
var logged_in = false
var remote_changes = false
var registered_entities = []

var csproj_reference_exists = false
var client = PPHTTPClient.new()
var player_is_connected = false
var player_uuid = null
var timer: Timer
var timer_wait_in_s = 10
var settings = EditorInterface.get_editor_settings() if Engine.is_editor_hint() else null
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
	var err : String = sdk_node.Connect(username, password)
	if err:
		player_uuid = null
		emit_signal("player_authentication_error", err)
		return
	player_uuid = sdk_node.GetUUID()
	emit_signal("player_authenticated", player_uuid)

func message(msg):
	sdk_node.Message(msg)

func _process(delta):
	if Engine.is_editor_hint() or !sdk_node or !player_uuid:
		return
	sdk_node.Update()
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
				print('Fired new_player_entity: ' + player_uuid)
			else:
				emit_signal("new_entity", entity_id, entity_data)
				print('Fired new_entity: ' + entity_id, entity_data)
	# remove missing entities
	for entity_id in to_remove_entity_ids:
		if entity_id != player_uuid:
			emit_signal("remove_entity", entity_id)
			print('Fired remove_entity: ' + entity_id)
	registered_entities = entity_ids

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "game_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_DEFAULT if logged_in else PROPERTY_USAGE_DEFAULT
	})
	properties.append({
		"name": "username",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_DEFAULT if logged_in else PROPERTY_USAGE_DEFAULT
	})
	properties.append({
		"name": "password",
		"hint": PROPERTY_HINT_PASSWORD,
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_SECRET | PROPERTY_USAGE_EDITOR if logged_in else PROPERTY_USAGE_SECRET | PROPERTY_USAGE_DEFAULT 
	})
	if logged_in:
		properties.append({
			"name": "pp_button_logout",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		if remote_changes:
			properties.append({
				"name": "pp_button_fetch",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_DEFAULT
			})
		else:
			properties.append({
				"name": "pp_button_no_remote_changes",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_DEFAULT
			})
		properties.append({
			"name": "pp_button_publish",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	else:
		properties.append({
			"name": "pp_button_login",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
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
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	if not regex.search(username):
		return {
			"valid": false,
			"message": "Username should be a valid email address"
		}
	if password.length() < 6:
		return {
			"valid": false,
			"message": "Password must be at least 6 characters long"
		}
	return {
		"valid": true,
		"message": ""
	}

func _on_button_pressed(text:String):
	if text.to_lower() == "add csproj reference":
		_on_csproj_button_pressed()
		return
	var validation_result = _validate_fields()
	assert(validation_result.valid, validation_result.message)
	if text.to_lower() == "login":
		_on_login_button_pressed()
		return
	if text.to_lower() == "logout":
		_on_logout_button_pressed()
		return
	if text.to_lower() == "fetch":
		_on_fetch_button_pressed()
		return
	if text.to_lower() == "publish":
		_on_publish_button_pressed()
		return

func _on_login_button_pressed():
	var resp = client.post('/apis/httputils/HTTPUtils/WhoAmI', {}, username, password)
	if !resp:
		return
	var json = JSON.new()
	var result = json.parse(resp)
	var data = json.data
	assert("Approved" in data, "Malformed response")
	assert(data["Approved"], "User is not approved")
	# check user has access to provided game
	resp = client.post('/apis/gamestore/GameStore/GetGame', { "GameID": game_id }, username, password)
	assert(resp, "User does not have access to this game")
	logged_in = true
	notify_property_list_changed()

func _on_logout_button_pressed():
	logged_in = false
	notify_property_list_changed()

func _on_fetch_button_pressed():
	var fetched_data = _fetch_from_pp()
	if !fetched_data:
		return
	
	# remove old lua files before writing new ones
	Utils.scrub_lua_files("res://addons/planetary_processing/lua/")
	Utils.scrub_lua_files("res://addons/planetary_processing/lua/entity/")
	for filename in fetched_data.keys():
		var content = fetched_data[filename]
		Utils.write_lua_file(base_path + filename, content)
	
	Utils.refresh_filesystem()

func _on_publish_button_pressed():
	_publish_to_pp()

func _get_csharp_error_msg():
	return "C# solution not created. Trigger Project > Tools > C# > Create C# Solution"

func _on_csproj_button_pressed():
	var csproj_files = Utils.find_files_by_extension(".csproj")
	assert(len(csproj_files), _get_csharp_error_msg())
	Utils.add_planetary_csproj_ref(csproj_files[0])
	notify_property_list_changed()

func _on_timer_timeout():
	if not logged_in:
		return
	_check_changes_from_pp()

func _fetch_from_pp():
	print("Fetching from Planetary Processing...")
	var resp = client.post('/apis/sdkendpoints/SDKEndpoints/Fetch', { "GameID": game_id }, username, password)
	if !resp:
		return
	var json = JSON.new()
	var result = json.parse(resp)
	var data = json.data
	assert("ZipContent" in data, "Malformed response")
	var zip_content_b64 = data["ZipContent"]
	var zip_content_bytes = Marshalls.base64_to_raw(zip_content_b64)
	
	# write zip to temp file
	var temp_path = "res://addons/planetary_processing/fetch.zip"
	DirAccess.remove_absolute(temp_path)
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	temp_file.store_buffer(zip_content_bytes)
	temp_file.close()
	
	# extract temp file
	var reader := ZIPReader.new()
	var r = reader.open(temp_path)
	assert(r == OK, "Zip file could not be read")
	var files := reader.get_files()
	var files_dict = {}
	for file in files:
		var content = reader.read_file(file)
		if len(content):
			files_dict[file] = content
	
	# set commit hash
	settings.set_setting("planetary_processing/commit", data["CommitHash"])
	remote_changes = false
	notify_property_list_changed()
	
	return files_dict

func _publish_to_pp():
	var entity_nodes = _get_entity_nodes()
	
	var entity_init_data = []
	for entity_node in entity_nodes:
		var scene_instance = entity_node.get_parent()
		var data = {}
		if entity_node.data:
			var json = JSON.new()
			var result = json.parse(entity_node.data)
			assert(result == OK, 'invalid json found in data field of entity: ' + scene_instance.name)
			data = json.data
		entity_init_data.append({
			'data': data,
			'chunkloader': entity_node.chunkloader,
			'type': entity_node.type,
			'x': scene_instance.global_transform.origin.x,
			'z': scene_instance.global_transform.origin.y,
			'y': scene_instance.global_transform.origin.z
		})
		
	var data = JSON.stringify(entity_init_data)
	Utils.write_string_to_file(base_path + 'init.json', data)
	var temp_path = "res://addons/planetary_processing/publish.zip"
	Utils.zip_directory("res://addons/planetary_processing/lua", temp_path)
	var zip_content_bytes = FileAccess.get_file_as_bytes(temp_path)
	var zip_content_b64 = Marshalls.raw_to_base64(zip_content_bytes)
	DirAccess.remove_absolute(temp_path)
	var resp = client.post('/apis/sdkendpoints/SDKEndpoints/Publish', { "ZipContent": zip_content_b64, "GameID": game_id }, username, password)
	if !resp:
		return
	Utils.refresh_filesystem()
	
	var json = JSON.new()
	var result = json.parse(resp)
	var resp_data = json.data
	
	# set commit hash
	settings.set_setting("planetary_processing/commit", resp_data["CommitHash"])
	remote_changes = false
	notify_property_list_changed()
	
	print("Published changes to Planetary Processing")

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
	
func _check_changes_from_pp():
	var resp = client.post('/apis/sdkendpoints/SDKEndpoints/LastUpdate', { "GameID": game_id }, username, password)
	if !resp:
		return
	var json = JSON.new()
	var result = json.parse(resp)
	var data = json.data
	var current_commit = settings.get_setting("planetary_processing/commit")
	remote_changes = current_commit != data["CommitHash"]
	notify_property_list_changed()

func _enter_tree():
	if not Engine.is_editor_hint():
		_remove_all_entity_scenes()
		return
	
	timer = Timer.new()
	timer.set_wait_time(timer_wait_in_s)
	timer.set_one_shot(false)
	timer.connect("timeout", _on_timer_timeout)
	add_child(timer)
	timer.start()
	
	# check for existence of cs proj / sln files
	var csproj_files = Utils.find_files_by_extension(".csproj")
	csproj_reference_exists = false
	notify_property_list_changed()
	assert(len(csproj_files), _get_csharp_error_msg())
	assert(len(Utils.find_files_by_extension(".sln")), _get_csharp_error_msg())
	csproj_reference_exists = Utils.csproj_planetary_reference_exists(csproj_files[0])
	notify_property_list_changed()
	assert(csproj_reference_exists, "Planetary Processing reference does not exist in " + csproj_files[0] + "\nClick \"Add Csproj Reference\" in the PPRootNode inspector to add the reference.")

func _exit_tree():
	if not Engine.is_editor_hint():
		return
	timer.disconnect("timeout", _on_timer_timeout)
	remove_child(timer)
	timer.free()
