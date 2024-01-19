@tool
extends Node

const Utils = preload("res://addons/planetary_processing/pp_utils.gd")

signal state_changed(new_state)

static var is_entity_node: bool = true
static var base_path = "res://addons/planetary_processing/lua/entity/" 

@export_category("Entity Properties")
@export_multiline var data = ''
@export var chunkloader = false
var type = '' : set = _set_type, get = _get_type
var lua_path = ''
var entity_id = ''
var pp_root_node
var is_instance

func _on_button_pressed(text:String):
	assert(
		type, "no type provided"
	)
	assert(
		not FileAccess.file_exists(lua_path),
		"lua file named " + type + ".lua already exists"
	)
	Utils.write_string_to_file(lua_path, "-- Dummy content for " + type + ".lua")
	Utils.refresh_filesystem()

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "type",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR if is_instance else PROPERTY_USAGE_DEFAULT
	})
	if not is_instance:
		properties.append({
			"name": "pp_button_generate_lua_skeleton_file",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		properties.append({
			"name": "lua_path",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR
		})
	return properties

func _set_type(new_type: String):
	type = new_type
	if Engine.is_editor_hint() and is_inside_tree():
		if not type:
			lua_path = ''
		else:
			lua_path = base_path + type + ".lua"
			print("Lua path set to " + lua_path)

func _get_type():
	return type

func _enter_tree():
	is_instance = get_tree().get_edited_scene_root() != get_parent()
	if Engine.is_editor_hint():
		if not is_instance:
			if not type:
				# set the default type value based on the name
				type = get_parent().name
			if not lua_path:
				# select existing lua file for lua path if exists
				var filepath = base_path + type + ".lua"
				if FileAccess.file_exists(filepath):
					lua_path = filepath
		return
	pp_root_node = get_tree().current_scene.get_node('PPRootNode')
	assert(pp_root_node, "PPRootNode not present as direct child of parent scene")
	# connect to events from the root
	pp_root_node.entity_state_changed.connect(_on_entity_state_change)
	
func _on_entity_state_change(new_entity_id, new_state):
	if new_entity_id == entity_id:
		emit_signal("state_changed", new_state)
