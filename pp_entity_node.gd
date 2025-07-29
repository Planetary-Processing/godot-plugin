@tool
extends Node

const Utils = preload("res://addons/planetary_processing/pp_utils.gd")

signal state_changed(new_state)

static var is_entity_node: bool = true
    

@export_category("Entity Properties")
var type = '' : set = _set_type, get = _get_type
var entity_id = ''
var pp_root_node
var is_instance

func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []
    properties.append({
        "name": "type",
        "type": TYPE_STRING,
        "usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR if is_instance else PROPERTY_USAGE_DEFAULT
    })
    return properties

func _set_type(new_type: String):
    type = new_type

func _get_type():
    return type

func _enter_tree():
    is_instance = get_tree().get_edited_scene_root() != get_parent()
    if Engine.is_editor_hint():
        if not is_instance:
            if not type:
                # set the default type value based on the name
                type = get_parent().name
        return
    pp_root_node = get_tree().current_scene.get_node('PPRootNode')
    assert(pp_root_node, "PPRootNode not present as direct child of parent scene")
    # connect to events from the root
    pp_root_node.entity_state_changed.connect(_on_entity_state_change)
    
func _on_entity_state_change(entity_ids, new_states):
    var entity_index = entity_ids.find(entity_id)
    if entity_index != -1:
        emit_signal("state_changed", new_states[entity_index])
