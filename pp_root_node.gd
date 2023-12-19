@tool
extends Node

const PPHTTPClient = preload("res://addons/planetary_processing/pp_editor_http_client.gd")
const Utils = preload("res://addons/planetary_processing/pp_utils.gd")

signal authentication_successful(username)
signal entity_state_changed(entity_id, new_state)

static var base_path = "res://addons/planetary_processing/lua/"

@export_category("Game Config")
var game_id = ''
var username = ''
var password = ''
var logged_in = false

var client = PPHTTPClient.new()
var player_is_authenticated : bool = false
var timer: Timer
var timer_wait_in_s = 10

func authenticate_player(username: String, password: String) -> bool:
	player_is_authenticated = true
	emit_signal("authentication_successful", game_id, username)
	return true

func update_entity_state(entity_id: int, new_state: Dictionary) -> void:
	emit_signal("entity_state_changed", entity_id, new_state)

func _ready():
	if Engine.is_editor_hint():
		return
	assert(
		game_id != "",
		"Planetary Processing Game ID not configured"
	)
	
	# for testing, call authenticate on ready - will be up to the developer to
	# trigger auth how they see fit in real games
	authenticate_player("any_username", "any_password")

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
		properties.append({
			"name": "pp_button_fetch",
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

func _on_timer():
	if not _validate_fields().valid:
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
	
	#extract temp file
	var reader := ZIPReader.new()
	var r = reader.open(temp_path)
	assert(r == OK, "Zip file could not be read")
	var files := reader.get_files()
	var files_dict = {}
	for file in files:
		var content = reader.read_file(file)
		if len(content):
			files_dict[file] = content
	
	return files_dict

func _publish_to_pp():
	print("Publishing to PP...")
	var scenes_with_entity_node : Array = []
	var root = get_tree().get_edited_scene_root()

	_recursive_scene_traversal(root, scenes_with_entity_node)
	
	var entity_init_data = []
	for scene_instance in scenes_with_entity_node:
		var scene_instance_parent = scene_instance.get_parent()
		var data = {}
		if scene_instance.data:
			var json = JSON.new()
			var result = json.parse(scene_instance.data)
			assert(result == OK, 'invalid json found in data field of entity: ' + scene_instance_parent.name)
			data = json.data
		var lua_path_array = scene_instance.lua_path.split('/')
		entity_init_data.append({
			'data': data,
			'chunkloader': scene_instance.chunkloader,
			'lua_file': lua_path_array[lua_path_array.size() - 1],
			'position': scene_instance_parent.transform.origin
		})
		
	var data = JSON.stringify(entity_init_data)
	Utils.write_string_to_file(base_path + 'init.json', data)
	Utils.zip_directory("res://addons/planetary_processing/lua", "res://addons/planetary_processing/publish.zip")
	Utils.refresh_filesystem()

func _recursive_scene_traversal(node, scenes_with_entity_node):
	for child in node.get_children():
		if 'is_entity_node' in child and child.is_entity_node:
			scenes_with_entity_node.append(child)
			break
		_recursive_scene_traversal(child, scenes_with_entity_node)
	
func _check_changes_from_pp():
	print("Checking PP for changes...")

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	
	timer = Timer.new()
	timer.set_wait_time(timer_wait_in_s)
	timer.set_one_shot(false)
	timer.connect("timeout", _on_timer)
	add_child(timer)
	timer.start()

func _exit_tree():
	if not Engine.is_editor_hint():
		return
	timer.disconnect("timeout", _on_timer)
	remove_child(timer)
	timer.free()
