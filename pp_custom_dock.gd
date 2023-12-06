extends Control

var game_id_edit : LineEdit
var username_edit : LineEdit
var password_edit : LineEdit
var fetch_button : Button
var publish_button : Button

var editor_settings_instance

func _ready():
	editor_settings_instance = EditorSettings.new()
	
	game_id_edit = $GameIDLineEdit
	username_edit = $UsernameLineEdit
	password_edit = $PasswordLineEdit
	fetch_button = $FetchButton
	publish_button = $PublishButton

	game_id_edit.text = editor_settings_instance.get_setting("pp_game_id", "")
	username_edit.text = editor_settings_instance.get_setting("pp_username", "")
	password_edit.text = editor_settings_instance.get_setting("pp_password", "")
	
	game_id_edit.connect("text_changed", _on_text_changed)
	username_edit.connect("text_changed", _on_text_changed)
	password_edit.connect("text_changed", _on_text_changed)
	
	fetch_button.connect("pressed", _on_fetch_button_pressed)
	publish_button.connect("pressed", _on_publish_button_pressed)

func _on_text_changed(new_text):
	# Handle text change events for all LineEdit fields
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	editor_settings_instance.set_setting("pp_game_id", game_id)
	editor_settings_instance.set_setting("pp_username", username)
	editor_settings_instance.set_setting("pp_password", password)
	editor_settings_instance.save_settings()

func _on_fetch_button_pressed():
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	fetch_from_pp(game_id, username, password)

func _on_publish_button_pressed():
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	publish_to_pp(game_id, username, password)

func fetch_from_pp(game_id, username, password):
	print("Fetching from PP...")

func publish_to_pp(game_id, username, password):
	print("Publishing to PP...")
