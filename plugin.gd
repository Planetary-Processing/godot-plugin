@tool
extends EditorPlugin

var inspector_plugin
	
func _enter_tree():
	add_custom_type("PPRootNode", "Node", preload("pp_root_node.gd"), preload("pp_logo.png"))
	add_custom_type("PPEntityNode", "Node", preload("pp_entity_node.gd"), preload("pp_logo.png"))
	if Engine.is_editor_hint():
		inspector_plugin = preload("pp_inspector_button_plugin.gd").new()
		add_inspector_plugin(inspector_plugin)
		var interface = get_editor_interface()
		var settings = interface.get_editor_settings()
		var textfile_extensions = settings.get_setting("docks/filesystem/textfile_extensions")
		settings.set_setting("docks/filesystem/textfile_extensions", textfile_extensions + ',lua,csproj')

func _exit_tree():
	remove_custom_type("PPRootNode")
	remove_custom_type("PPEntityNode")
	if Engine.is_editor_hint():
		remove_inspector_plugin(inspector_plugin)
