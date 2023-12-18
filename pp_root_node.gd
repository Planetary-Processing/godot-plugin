@tool
extends Node

const PPHTTPClient = preload("res://addons/planetary_processing/pp_editor_http_client.gd")
const Utils = preload("res://addons/planetary_processing/pp_utils.gd")

signal authentication_successful(username)
signal entity_state_changed(entity_id, new_state)

static var base_path = "res://addons/planetary_processing/lua/"

@export_category("Game Config")
@export var game_id = ''
@export var username = ''
var password = ''

var timer: Timer
var timer_wait_in_s = 10

var developer_token : String = ""
var player_is_authenticated : bool = false

var settings = EditorInterface.get_editor_settings()

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
		"name": "password",
		"hint": PROPERTY_HINT_PASSWORD,
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_SECRET | PROPERTY_USAGE_DEFAULT
	})
	properties.append({
		"name": "pp_button_login",
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
	if text.to_lower() == "fetch":
		_on_fetch_button_pressed()
		return
	if text.to_lower() == "publish":
		_on_publish_button_pressed()
		return
		
func _on_login_button_pressed():
	var client = PPHTTPClient.new()
	var resp = client.post('/apis/liteauth/LiteAuth', { "Email": username, "Password": password })
	print(resp)
	#var http = HTTPClient.new()
	#var err = http.connect_to_host("https://golang.planetaryprocessing.io", 443)
	#assert(err==OK)
	#while( http.get_status()==HTTPClient.STATUS_CONNECTING or http.get_status()==HTTPClient.STATUS_RESOLVING):
		#http.poll()
		#print("Connecting..")
		#OS.delay_msec(500)
	#assert( http.get_status() == HTTPClient.STATUS_CONNECTED )
	#http.close()
	#print('a')
	#var request = HTTPRequest.new()
	#print('b')
	#request.connect("request_completed", _on_login_request_completed)
	#request.request(
		#"https://golang.planetaryprocessing.io/apis/liteauth",
		#[ "Content-Type: application/json" ],
		#HTTPClient.METHOD_POST,
		#JSON.stringify({ "Email": username, "Password": password })
	#)
	#await request.request_completed
#
	## Parse the response and store the token
	#if request.get_response_code() == HTTPClient.RESPONSE_OK:
		#var json = JSON.new()
		#var result = json.parse(request.get_response_data_as_text())
		#assert(result == OK, 'invalid response from login request')
		#var data = json.data
		#if "Token" in data:
			#var token = data["Token"]
			#print("Authentication successful. Token:", token)
			#settings.set_setting("auth/token", token)
			#return true
#
	## Authentication failed
	#print("Authentication failed.")
	#return false
	
func _on_login_request_completed(result, response_code, headers, body):
	print("Authentication request completed. Response Code:", response_code)
	print("Response Body:", body)
		
func _on_fetch_button_pressed():	
	var fetched_data = _fetch_from_pp()

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
	print("Fetching from PP...")
	
	var dummy_data = {
		"init.lua": "-- Dummy content for init.lua",
		"entities/demo1.lua": "-- Dummy content for demo1.lua",
		"entities/demo2.lua": "-- Dummy content for demo2.lua",
		"entities/demo3.lua": "-- Dummy content for demo3.lua"
	}

	return dummy_data

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
	Utils.write_lua_file(base_path + 'init.json', data)
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
