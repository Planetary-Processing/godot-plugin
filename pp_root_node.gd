@tool
extends Node

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

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "password",
		"hint": PROPERTY_HINT_PASSWORD,
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_SECRET | PROPERTY_USAGE_DEFAULT
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

func _on_button_pressed(text:String):
	if text.to_lower() == "fetch":
		_on_fetch_button_pressed()
		return
	if text.to_lower() == "publish":
		_on_publish_button_pressed()
		return
		
func _on_fetch_button_pressed():	
	var fetched_data = fetch_from_pp()

	for filename in fetched_data.keys():
		var content = fetched_data[filename]
		Utils.write_lua_file(base_path + filename, content)
	
	Utils.refresh_filesystem()

func _on_publish_button_pressed():
	publish_to_pp()

func _on_timer():
	check_changes_from_pp()

func fetch_from_pp():
	print("Fetching from PP...")
	
	var dummy_data = {
		"init.lua": "-- Dummy content for init.lua",
		"entities/demo1.lua": "-- Dummy content for demo1.lua",
		"entities/demo2.lua": "-- Dummy content for demo2.lua",
		"entities/demo3.lua": "-- Dummy content for demo3.lua"
	}

	return dummy_data

func publish_to_pp():
	print("Publishing to PP...")
	var scenes_with_entity_node : Array = []
	var root = get_tree().get_edited_scene_root()

	recursive_scene_traversal(root, scenes_with_entity_node)
	
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

func recursive_scene_traversal(node, scenes_with_entity_node):
	for child in node.get_children():
		if 'is_entity_node' in child and child.is_entity_node:
			scenes_with_entity_node.append(child)
			break
		recursive_scene_traversal(child, scenes_with_entity_node)
	
func check_changes_from_pp():
	print("Checking PP for changes...")

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
		game_id != "",
		"Planetary Processing Game ID not configured"
	)
	
	# for testing, call authenticate on ready - will be up to the developer to
	# trigger auth how they see fit in real games
	authenticate("any_username", "any_password")

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	get_tree().connect("node_added", _on_node_added)
	
	timer = Timer.new()
	timer.set_wait_time(timer_wait_in_s)
	timer.set_one_shot(false)
	timer.connect("timeout", _on_timer)
	add_child(timer)
	timer.start()
	
func _exit_tree():
	if not Engine.is_editor_hint():
		return
	get_tree().disconnect("node_added", _on_node_added)
	timer.disconnect("timeout", _on_timer)
	remove_child(timer)
	timer.free()

func _on_node_added(node):
	if 'is_entity_node' in node:
		print('entity node added: ', node.name)
