static func write_lua_file(filepath, content):
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	file.store_buffer(content)
	file.close()
	print("Stored file: ", filepath)

static func refresh_filesystem():
	if Engine.is_editor_hint():
		var _editor_plugin = (EditorPlugin as Variant).new()
		var interface = _editor_plugin.get_editor_interface()
		var resource_filesystem = interface.get_resource_filesystem()
		resource_filesystem.scan()

static func scrub_lua_files(path):
	var dir = DirAccess.open(path)
	for file_name in dir.get_files():
		if file_name.ends_with(".lua"):
			dir.remove(file_name)
			print("Deleted file: ", file_name)
