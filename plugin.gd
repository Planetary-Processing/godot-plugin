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

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
