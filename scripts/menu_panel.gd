class_name MenuPanel
extends Control
## Start screen and result screen share one panel: title, mode selector and a primary button.

signal fight_requested(enemy_count: int)

var enemy_count := 3

var _title: Label
var _info: Label
var _fight_button: Button
var _one_button: Button
var _three_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)

	_title = _label(56)
	box.add_child(_title)
	_info = _label(28)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(560, 0)
	box.add_child(_info)

	var group := ButtonGroup.new()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_one_button = _mode_button("1 Enemy", group)
	_three_button = _mode_button("3 Enemies", group)
	row.add_child(_one_button)
	row.add_child(_three_button)
	_one_button.pressed.connect(func(): enemy_count = 1)
	_three_button.pressed.connect(func(): enemy_count = 3)

	_fight_button = Button.new()
	_fight_button.custom_minimum_size = Vector2(360, 110)
	_fight_button.add_theme_font_size_override("font_size", 44)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.62, 0.3) if style_name != "pressed" else Color(0.14, 0.45, 0.22)
		sb.set_corner_radius_all(10)
		_fight_button.add_theme_stylebox_override(style_name, sb)
	_fight_button.pressed.connect(func(): fight_requested.emit(enemy_count))
	var wrap := CenterContainer.new()
	wrap.add_child(_fight_button)
	box.add_child(wrap)

	var hint := _label(22)
	hint.text = "Left thumb: move.  ATTACK: tap = light, hold = heavy.\nDODGE: roll with brief invulnerability.\nDesktop: WASD / arrows, J, Space."
	hint.modulate = Color(1, 1, 1, 0.65)
	box.add_child(hint)

	set_mode(enemy_count)
	show_start()


func set_mode(n: int) -> void:
	enemy_count = n
	_one_button.button_pressed = (n == 1)
	_three_button.button_pressed = (n == 3)


func show_start() -> void:
	_title.text = "SHIELDWALL"
	_info.text = "Combat test: one hero against melee enemies."
	_fight_button.text = "Fight"
	visible = true


func show_result(victory: bool, seconds: float, hp_left: float, mode: int) -> void:
	_title.text = "VICTORY" if victory else "DEFEAT"
	_title.modulate = Color(0.5, 1.0, 0.55) if victory else Color(1.0, 0.4, 0.35)
	_info.text = "%d enemy mode.  Time %.1f s.  Health left %d." % [mode, seconds, ceili(hp_left)]
	_fight_button.text = "Retry"
	set_mode(mode)
	visible = true


func layout(vp: Vector2) -> void:
	position = Vector2.ZERO
	size = vp


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _mode_button(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(240, 90)
	b.add_theme_font_size_override("font_size", 34)
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.2, 0.45, 0.85)
	on.set_corner_radius_all(8)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b
