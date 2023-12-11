static func write_lua_file(filepath, content):
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	print(filepath)
	file.store_string(content)
	file.close()

static func refresh_filesystem():
	if Engine.is_editor_hint():
		var _editor_plugin = (EditorPlugin as Variant).new()
		var interface = _editor_plugin.get_editor_interface()
		var resource_filesystem = interface.get_resource_filesystem()
		resource_filesystem.scan()
