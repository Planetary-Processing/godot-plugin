extends MarginContainer

var object: Object

func _init(obj: Object, text:String):
	object = obj
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var button := Button.new()
	add_child(button)
	print(object)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.text = text
	button.button_down.connect(object._on_button_pressed.bind(text))
