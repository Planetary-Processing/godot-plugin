@tool
extends EditorPlugin

var dock

func _enter_tree():
	var interface = get_editor_interface()
	var settings = interface.get_editor_settings()
	var textfile_extensions = settings.get_setting("docks/filesystem/textfile_extensions")
	settings.set_setting("docks/filesystem/textfile_extensions", textfile_extensions + ',lua')
	dock = preload("pp_custom_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	add_custom_type("PPRootNode", "Node", preload("pp_root_node.gd"), preload("pp_logo.png"))
	add_custom_type("PPEntityNode", "Node", preload("pp_entity_node.gd"), preload("pp_logo.png"))

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
	remove_custom_type("PPRootNode")
