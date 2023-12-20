extends MarginContainer

func _init(obj: Object, text:String):
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	add_child(button)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.text = text
	button.button_down.connect(obj._on_button_pressed.bind(text))
