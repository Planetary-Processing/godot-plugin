extends EditorInspectorPlugin

var InspectorToolButton = preload("pp_inspector_button.gd")

var button_text : String

func _can_handle(object) -> bool:
	return true

func _parse_property(
	object: Object, type: Variant.Type, 
	name: String, hint_type: PropertyHint, 
	hint_string: String, usage_flags, wide: bool):
	if name.begins_with("pp_button_"):
		var s = str(name.split("pp_button_")[1])
		s = s.replace("_", " ")
		s = s.capitalize() 
		add_custom_control( InspectorToolButton.new(object, s) )
		return true
	return false
