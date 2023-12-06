@tool
extends Control

var game_id_edit : LineEdit
var username_edit : LineEdit
var password_edit : LineEdit
var fetch_button : Button
var publish_button : Button

func _enter_tree():
	print('enter tree custom dock')
	
	game_id_edit = $VBoxContainer/GameIDLineEdit
	username_edit = $VBoxContainer/UsernameLineEdit
	password_edit = $VBoxContainer/PasswordLineEdit
	fetch_button = $VBoxContainer/FetchButton
	publish_button = $VBoxContainer/PublishButton

	game_id_edit.text = ProjectSettings.get_setting("pp_game_id") if ProjectSettings.has_setting("pp_game_id") else ""
	username_edit.text = ProjectSettings.get_setting("pp_username") if ProjectSettings.has_setting("pp_username") else ""
	password_edit.text = ProjectSettings.get_setting("pp_password") if ProjectSettings.has_setting("pp_password") else ""
	
	game_id_edit.connect("text_changed", _on_text_changed)
	username_edit.connect("text_changed", _on_text_changed)
	password_edit.connect("text_changed", _on_text_changed)
	
	fetch_button.connect("pressed", _on_fetch_button_pressed)
	publish_button.connect("pressed", _on_publish_button_pressed)
	
func _exit_tree():
	game_id_edit.disconnect("text_changed", _on_text_changed)
	username_edit.disconnect("text_changed", _on_text_changed)
	password_edit.disconnect("text_changed", _on_text_changed)
	
	fetch_button.disconnect("pressed", _on_fetch_button_pressed)
	publish_button.disconnect("pressed", _on_publish_button_pressed)
	

func _on_text_changed(new_text):
	# Handle text change events for all LineEdit fields
	var game_id = game_id_edit.text
	var username = username_edit.text
	var password = password_edit.text
	
	ProjectSettings.set_setting("pp_game_id", game_id)
	ProjectSettings.set_setting("pp_username", username)
	ProjectSettings.set_setting("pp_password", password)
	ProjectSettings.save()

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
