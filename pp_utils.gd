static var reference_tag = ""
static var reference_hint = ""

static func _init_static_variables():
	reference_tag = "<Reference Include=\"Planetary\">"
	reference_hint = "<HintPath>addons/planetary_processing/sdk/csharp-sdk.dll</HintPath>"

static func write_lua_file(file_path, bytes):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	print("Stored file: ", file_path)

static func write_string_to_file(file_path, content):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	print("Stored file: ", file_path)

static func refresh_filesystem():
	if Engine.is_editor_hint():
		var _editor_interface = Engine.get_singleton("EditorInterface")
		var resource_filesystem = _editor_interface.get_resource_filesystem()
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

static func find_files_by_extension(extension, path = "res://"):
	var dir = DirAccess.open(path)
	var files = []
	for file_name in dir.get_files():
		if file_name.to_lower().ends_with(extension):
			files.append(file_name)
	return files

static func get_csproj_content(csproj_path):
	var file := FileAccess.open(csproj_path, FileAccess.READ)
	assert(file, "csproj file could not be opened: " + csproj_path)

	var csproj_content = file.get_as_text()
	file.close()
	return csproj_content

static func csproj_planetary_reference_exists(csproj_path):
	_init_static_variables()
	var csproj_content = get_csproj_content(csproj_path)
	return csproj_content.find(reference_tag) != -1 and csproj_content.find(reference_hint) != -1

static func add_planetary_csproj_ref(csproj_path):
	_init_static_variables()
	var csproj_content = get_csproj_content(csproj_path)

	var item_group_exists = csproj_content.find("<ItemGroup>") != -1
	var reference_exists = csproj_planetary_reference_exists(csproj_path)
	var reference_string = reference_tag + "\n      " + reference_hint + "\n    </Reference>\n"
	if item_group_exists and reference_exists:
		return
	if not item_group_exists:
		var item_group_tag = "  <ItemGroup>\n    " + reference_string + "  </ItemGroup>"
		csproj_content = csproj_content.replace("</PropertyGroup>", "</PropertyGroup>\n" + item_group_tag)
	elif not reference_exists:
		var item_group_pos = csproj_content.find("<ItemGroup>")
		var item_group_end_pos = csproj_content.find("</ItemGroup>", item_group_pos)
		csproj_content = csproj_content.insert(item_group_end_pos, "  " + reference_string + "  ")

	var csproj_file = FileAccess.open(csproj_path, FileAccess.WRITE)
	csproj_file.store_string(csproj_content)
	csproj_file.close()
	print("Updated CS Proj file: ", csproj_path)
