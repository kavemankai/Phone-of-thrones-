class_name BindingsPanel
extends Control

signal closed

const ACTION_LABELS := [
	"Move left", "Move right", "Move up", "Move down",
	"Aim left", "Aim right", "Aim up", "Aim down",
	"Light attack", "Heavy attack", "Roll", "Guard", "Pause", "Fullscreen",
]
const HELP := "Select a binding to change it. Shared inputs swap where possible."
const CAPTURE_SECONDS := 8.0

var _keys: Array[Button] = []
var _pads: Array[Button] = []
var _status: Label
var _back: Button
var _capture := -1
var _capture_pad := false
var _remaining := 0.0
var _axis_positions: Dictionary = {}
var _style := InputPrompts.Style.XBOX


func _ready() -> void:
	hide()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.08, 0.10)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	for caption: String in ["Action", "Keyboard", "Controller"]:
		var heading := Label.new()
		heading.text = caption
		grid.add_child(heading)
	for i in InputActions.ALL.size():
		var label := Label.new()
		label.text = ACTION_LABELS[i]
		label.custom_minimum_size.x = 155
		grid.add_child(label)
		_keys.append(_button(grid, "", _begin_capture.bind(i, false)))
		_pads.append(_button(grid, "", _begin_capture.bind(i, true)))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	_button(footer, "Restore defaults", _reset)
	_back = _button(footer, "Back", _close)


func _button(parent: Container, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(225, 30)
	UiFocus.style(button)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func open(style: InputPrompts.Style) -> void:
	_style = InputPrompts.Style.PLAYSTATION if style == InputPrompts.Style.PLAYSTATION else InputPrompts.Style.XBOX
	_axis_positions.clear()
	for device in Input.get_connected_joypads():
		for axis in JOY_AXIS_MAX:
			_axis_positions[Vector2i(device, axis)] = Input.get_joy_axis(device, axis as JoyAxis)
	_refresh()
	_status.text = HELP
	show()
	_keys[0].grab_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	UiFocus.keep_inside(self, _back)
	if _capture >= 0:
		_remaining -= delta
		if _remaining <= 0.0:
			_finish_capture("Binding unchanged.")
		else:
			_show_capture_hint()


func _begin_capture(index: int, pad: bool) -> void:
	_capture = index
	_capture_pad = pad
	_remaining = CAPTURE_SECONDS
	_show_capture_hint()


func _show_capture_hint() -> void:
	var device := "a key"
	if _capture_pad:
		device = "a controller button"
		if _capture < 8:
			device += " or move a stick"
	_status.text = "%s: press %s (%ds)" % [ACTION_LABELS[_capture], device, ceili(_remaining)]


## Called before gameplay input so selecting a binding cannot trigger an action.
func handle_event(event: InputEvent) -> bool:
	var fresh_axis := false
	if event is InputEventJoypadMotion:
		var axis := Vector2i(event.device, event.axis)
		var prior: float = _axis_positions.get(axis, 0.0)
		fresh_axis = absf(event.axis_value) >= 0.65 and (
			absf(prior) < 0.65 or signf(prior) != signf(event.axis_value))
		_axis_positions[axis] = event.axis_value
	if _capture < 0:
		if event.is_action_pressed(&"ui_cancel"):
			_close()
			return true
		return false
	if not (event is InputEventKey or InputActions.is_pad_event(event)):
		return false
	var action := InputActions.ALL[_capture]
	if InputActions.is_pad_event(event) != _capture_pad or not InputActions.accepts_binding(action, event):
		return true
	if event is InputEventJoypadMotion:
		if not fresh_axis:
			return true
	elif not event.is_pressed() or event.is_echo():
		return true
	if event is InputEventKey and event.physical_keycode == 0:
		return true
	if _capture_pad:
		_style = InputPrompts.style_for_joypad(event.device)
	var error := InputActions.rebind(action, event)
	_finish_capture("Binding saved." if error == OK else "Could not save binding.")
	return true


func _finish_capture(message: String) -> void:
	_capture = -1
	_status.text = message
	_refresh()


func _reset() -> void:
	var error := InputActions.reset_bindings()
	_finish_capture("Defaults restored." if error == OK else "Could not save defaults.")


func _close() -> void:
	_capture = -1
	hide()
	closed.emit()


func _refresh() -> void:
	for i in InputActions.ALL.size():
		_keys[i].text = InputPrompts.binding_label(InputActions.ALL[i], InputPrompts.Style.KEYBOARD)
		_pads[i].text = InputPrompts.binding_label(InputActions.ALL[i], _style)
