@tool
extends Control

var game_id_edit : LineEdit
var username_edit : LineEdit
var password_edit : LineEdit
var fetch_button : Button
var publish_button : Button

var timer: Timer
var timer_wait_in_s = 10

func _enter_tree():
	print('enter tree custom dock')
	
	game_id_edit = $VBoxContainer/GameIDLineEdit
	username_edit = $VBoxContainer/UsernameLineEdit
	password_edit = $VBoxContainer/PasswordLineEdit
	fetch_button = $VBoxContainer/FetchButton
	publish_button = $VBoxContainer/PublishButton

	game_id_edit.text = ProjectSettings.get_setting("pp_game_id") if ProjectSettings.has_setting("pp_game_id") else ""
	username_edit.text = ProjectSettings.get_setting("pp_username") if ProjectSettings.has_setting("pp_username") else ""
	password_edit.text = ProjectSettings.get_setting("pp_password") if ProjectSettings.has_setting("pp_password") else ""
	
	game_id_edit.connect("text_changed", _on_text_changed)
	username_edit.connect("text_changed", _on_text_changed)
	password_edit.connect("text_changed", _on_text_changed)
	
	fetch_button.connect("pressed", _on_fetch_button_pressed)
	publish_button.connect("pressed", _on_publish_button_pressed)
	
	timer = Timer.new()
	timer.set_wait_time(timer_wait_in_s)
	timer.set_one_shot(false)
	timer.connect("timeout", _on_timer)
	add_child(timer)
	timer.start()
	

# not being used currently, but leaving here for reference
#func _populate_lua_tree():
#	lua_tree.clear()
#	var lua_files = _get_lua_files("res://addons/planetary_processing/lua")
#	var entities_files = _get_lua_files("res://addons/planetary_processing/lua/entities")
#
#	var root = lua_tree.create_item()
#	lua_tree.hide_root = true
#	for file_name in lua_files:
#		var tree_item = lua_tree.create_item(root)	print("Fetching from PP...")
#		tree_item.set_text(0, file_name)
#		tree_item.set_metadata(0, file_name)
#
#	var entities = lua_tree.create_item(root)
#	entities.set_text(0, "Entities")
#	for file_name in entities_files:
#		var tree_item = lua_tree.create_item(entities)
#		tree_item.set_text(0, file_name)
#		tree_item.set_metadata(0, 'entities/' + file_name)

#func _get_lua_files(directory_path: String) -> Array:
#	var dir = DirAccess.open(directory_path)
#	var files = []
#
#	dir.list_dir_begin()
#	var file_name = dir.get_next()
#	while file_name != "":
#		if file_name.ends_with(".lua"):
#			files.append(file_name)
#		file_name = dir.get_next()
#	dir.list_dir_end()
#
#	return files

	
func _exit_tree():
	game_id_edit.disconnect("text_changed", _on_text_changed)
	username_edit.disconnect("text_changed", _on_text_changed)
	password_edit.disconnect("text_changed", _on_text_changed)
	
	fetch_button.disconnect("pressed", _on_fetch_button_pressed)
	publish_button.disconnect("pressed", _on_publish_button_pressed)
	
	timer.disconnect("timeout", _on_timer)
	remove_child(timer)
	timer.free()
	

func _on_text_changed(new_text):
	# Handle text change events for all LineEdit fields
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	ProjectSettings.set_setting("pp_game_id", game_id)
	ProjectSettings.set_setting("pp_username", username)
	ProjectSettings.set_setting("pp_password", password)
	ProjectSettings.save()

func _on_fetch_button_pressed():
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	var fetched_data = fetch_from_pp(game_id, username, password)

	# Loop through the dictionary using the keys
	for filename in fetched_data.keys():
		var content = fetched_data[filename]
		write_lua_file(filename, content)
	
	var interface = EditorPlugin.new().get_editor_interface()
	var resource_filesystem = interface.get_resource_filesystem()
	resource_filesystem.scan()
	

func _on_publish_button_pressed():
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	publish_to_pp(game_id, username, password)

func _on_timer():
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	check_changes_from_pp(game_id, username, password)

func fetch_from_pp(game_id, username, password):
	print("Fetching from PP...")
	
	var dummy_data = {
		"init.lua": "-- Dummy content for init.lua",
		"entities/demo1.lua": "-- Dummy content for demo1.lua",
		"entities/demo2.lua": "-- Dummy content for demo2.lua",
		"entities/demo3.lua": "-- Dummy content for demo3.lua"
	}

	return dummy_data

func publish_to_pp(game_id, username, password):
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
	write_lua_file('init.json', data)
	
	var interface = EditorPlugin.new().get_editor_interface()
	var resource_filesystem = interface.get_resource_filesystem()
	resource_filesystem.scan()

func recursive_scene_traversal(node, scenes_with_entity_node):
	for child in node.get_children():
		if 'is_entity_node' in child and child.is_entity_node:
			scenes_with_entity_node.append(child)
			break
		recursive_scene_traversal(child, scenes_with_entity_node)
	
func check_changes_from_pp(game_id, username, password):
	print("Checking PP for changes...")
	
func write_lua_file(filename, content):
	var filepath = "res://addons/planetary_processing/lua/" + filename
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	print(filepath)
	file.store_string(content)
	file.close()

