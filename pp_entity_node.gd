@tool
extends Node

static var is_entity_node: bool = true

@export_category("Entity Properties")
@export_multiline var data = ''
@export var chunkloader = false
var lua_path = ''

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if self.is_inside_tree(): 
		var is_instance = get_tree().get_edited_scene_root() != get_parent()
		properties.append({
			"name": "lua_path",
			"type": TYPE_STRING,
			"hint_string": "*.lua",
			"hint": PROPERTY_HINT_FILE,
			"usage": PROPERTY_USAGE_READ_ONLY if is_instance else PROPERTY_USAGE_DEFAULT
		})
	return properties
