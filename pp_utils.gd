static func write_lua_file(file_path, bytes):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	print("Stored file: ", file_path)

static func write_string_to_file(file_path, content):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	print("Stored file: ", file_path)
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
	for file_name in dir.get_files():
		if file_name.ends_with(".lua"):
			dir.remove(file_name)
			print("Deleted file: ", file_name)

static func zip_directory(path, file_path) -> Error:
	DirAccess.remove_absolute(file_path)
	var zip_packer := ZIPPacker.new()
	var err := zip_packer.open(file_path, ZIPPacker.APPEND_CREATE)
	if err != OK:
		return err

	err = add_files_to_zip(zip_packer, path, "")

	zip_packer.close()
	return err

static func add_files_to_zip(zip_packer, directory_path, relative_path) -> Error:
	var dir = DirAccess.open(directory_path)
	for file_name in dir.get_files():
		var file_path = relative_path + file_name
		print(file_path)
		var absolute_file_path = directory_path + "/" + file_name
		var err = zip_packer.start_file(file_path)
		if err != OK:
			return err
		
		var file := FileAccess.open(absolute_file_path, FileAccess.READ)
		if file:
			zip_packer.write_file(FileAccess.get_file_as_bytes(absolute_file_path))
			file.close()
	for dir_name in dir.get_directories():
		var dir_path = relative_path + dir_name + '/'
		var absolute_dir_path = directory_path + "/" + dir_name
		add_files_to_zip(zip_packer, absolute_dir_path, dir_path)
	return OK
