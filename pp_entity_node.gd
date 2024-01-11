@tool
extends Node

const Utils = preload("res://addons/planetary_processing/pp_utils.gd")

signal state_changed(new_state)

static var is_entity_node: bool = true
static var base_path = "res://addons/planetary_processing/lua/entity/" 

@export_category("Entity Properties")
@export_multiline var data = ''
@export var chunkloader = false
@export var type = ''
var lua_path = ''
var entity_id = ''
var previous_position = Vector3.ZERO

var pp_root_node

func _on_button_pressed(text:String):
	var filename = get_parent().name
	var filepath = base_path + filename + ".lua"
	assert(
		not FileAccess.file_exists(filepath),
		"lua file named " + filename + ".lua already exists"
	)
	Utils.write_lua_file(filepath, "-- Dummy content for " + filename + ".lua")
	Utils.refresh_filesystem()
	lua_path = filepath

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if self.is_inside_tree(): 
		var is_instance = get_tree().get_edited_scene_root() != get_parent()
		properties.append({
			"name": "pp_button_generate_lua_skeleton_file",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_READ_ONLY if is_instance else PROPERTY_USAGE_DEFAULT
		})
		properties.append({
			"name": "lua_path",
			"type": TYPE_STRING,
			"hint_string": "*.lua",
			"hint": PROPERTY_HINT_FILE,
			"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR if is_instance else PROPERTY_USAGE_DEFAULT
		})
	return properties

func _enter_tree():
	if Engine.is_editor_hint():
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
	# TEMPORARY FOR TESTING
	if new_state["type"] == "player":
		entity_id = new_entity_id
	
	if new_entity_id == entity_id:
		emit_signal("state_changed", new_state)
		
# TEMPORARY FOR TESTING
func _process(delta):
	if Engine.is_editor_hint():
		return
	var current_position = get_parent().transform.origin
	var position_change = current_position - previous_position
	previous_position = current_position
	pp_root_node.message({
		"x": position_change[0],
		"y": position_change[1],
		"z": position_change[2]
	})
