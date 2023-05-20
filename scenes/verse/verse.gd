extends VBoxContainer

signal clicked
var global_number: int

func set_text(text: String):
	$TextEdit.text = text

func set_english_text(text: String):
	$TextEdit2.text = text

func set_transliteration_text(text: String):
	$TextEdit3.text = text.replace("<B", "[b").replace("B>", "b]").replace("<U", "[u").replace("U>", "u]").replace(">", "]").replace("<", "[")

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		clicked.emit(global_number)
