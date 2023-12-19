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

static func scrub_lua_files(path):
	var dir = DirAccess.open(path)
	while dir.next() == OK:
		var file_name = dir.get_file()
		if file_name.ends_with(".lua"):
			var file_path = dir.remove(file_name)
			print("Deleted file: ", file_path)

	dir.list_end()
	
