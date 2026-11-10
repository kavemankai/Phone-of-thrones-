class_name PausePanel
extends Control
## Pause overlay. Every entry is a focusable button, so it works on a gamepad alone. It only
## emits requests; Game decides what they do.

signal resume_requested
signal restart_requested
signal loadout_requested
signal quit_requested

var _title: Label
var _reason: Label
var _legend: Label
var _resume: Button
var _fullscreen: Button
var _style: InputPrompts.Style = InputPrompts.Style.KEYBOARD
var _hold_for_heavy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_title = _label(48)
	_title.text = "PAUSED"
	box.add_child(_title)
	_reason = _label(22)
	_reason.modulate = Color(1.0, 0.85, 0.45)
	box.add_child(_reason)

	_resume = _button("Resume", box)
	_resume.pressed.connect(func(): resume_requested.emit())
	_button("Restart fight", box).pressed.connect(func(): restart_requested.emit())
	_button("Change loadout", box).pressed.connect(func(): loadout_requested.emit())
	_fullscreen = _button("", box)
	_fullscreen.pressed.connect(toggle_fullscreen)
	_button("Quit to desktop", box).pressed.connect(func(): quit_requested.emit())

	_legend = _label(18)
	_legend.modulate = Color(1, 1, 1, 0.65)
	box.add_child(_legend)
	_refresh()


## Shows the panel. `reason` explains a pause the player did not ask for.
func open(reason := "") -> void:
	set_reason(reason)
	_refresh()
	visible = true
	if is_inside_tree() and _resume != null:
		_resume.grab_focus()


func close() -> void:
	visible = false


func set_reason(reason: String) -> void:
	if _reason != null:
		_reason.text = reason
		_reason.visible = reason != ""


func set_prompt_style(style: InputPrompts.Style, hold_for_heavy: bool) -> void:
	_style = style
	_hold_for_heavy = hold_for_heavy
	_refresh()


func layout(vp: Vector2) -> void:
	position = Vector2.ZERO
	size = vp


func _process(_delta: float) -> void:
	UiFocus.keep_inside(self, _resume)


func _refresh() -> void:
	if _legend == null:
		return
	_legend.text = "%s      %s: resume\n%s" % [InputPrompts.menu_hint(_style),
			InputPrompts.back(_style), InputPrompts.combat_line(_style, _hold_for_heavy)]
	_fullscreen.text = "Fullscreen: ON" if _is_fullscreen() else "Fullscreen: OFF"


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen()
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh()


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String, parent: Container) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 58)
	b.add_theme_font_size_override("font_size", 26)
	UiFocus.style(b)
	var wrap := CenterContainer.new()
	wrap.add_child(b)
	parent.add_child(wrap)
	return b
