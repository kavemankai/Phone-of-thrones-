class_name EndingPanel
extends Control
## The closing screen after the final boss, and the credits from the title menu. One
## heading, one block of text and one button, so a gamepad alone can read and leave it.

signal closed

const CREDITS := "FORGEBREACH is a working title.\n\n" \
		+ "Made with Godot Engine 4.6, copyright the Godot Engine contributors, MIT licence.\n" \
		+ "Paintings generated with an image model and edited for this project.\n" \
		+ "Sound and music are original procedural designs.\n" \
		+ "Code written with AI coding assistants under human direction.\n\n" \
		+ "Thank you for playing."
const CLOSING := "The Tyrant's crown lies in the pit. The gates stand open behind you,\n" \
		+ "and for the first time the forges are quiet.\n" \
		+ "By morning the fortress will have rebuilt itself. So will you."

var _heading: Label
var _body: Label
var _button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.025, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 44)
	box.add_child(_heading)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(860, 0)
	_body.add_theme_font_size_override("font_size", 20)
	box.add_child(_body)
	_button = Button.new()
	_button.text = "Continue"
	_button.custom_minimum_size = Vector2(300, 54)
	_button.add_theme_font_size_override("font_size", 24)
	UiFocus.style(_button)
	_button.pressed.connect(close)
	var wrap := CenterContainer.new()
	wrap.add_child(_button)
	box.add_child(wrap)


## The ending: the closing lines, this run's numbers, then the credits.
func show_ending(run_summary: String) -> void:
	_open("THE FORTRESS HAS FALLEN", Color(0.5, 1.0, 0.55),
			"%s\n\n%s\n\n%s" % [CLOSING, run_summary, CREDITS])


func show_credits() -> void:
	_open("CREDITS", Color(1.0, 0.86, 0.64), CREDITS)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func layout(vp: Vector2) -> void:
	position = Vector2.ZERO
	size = vp


func _open(heading: String, tint: Color, body: String) -> void:
	_heading.text = heading
	_heading.modulate = tint
	_body.text = body
	visible = true
	if is_inside_tree():
		_button.grab_focus()


func _process(_delta: float) -> void:
	UiFocus.keep_inside(self, _button)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
