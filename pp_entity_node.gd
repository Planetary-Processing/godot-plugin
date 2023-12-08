@tool
extends Node

static var is_entity_node: bool = true

@export_category("Statistics")
@export_multiline var data = ''
@export var chunkloader = false
@export_file("*.lua") var lua_path: String = ''

