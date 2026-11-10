class_name MenuPanel
extends Control
## Start screen and result screen share one panel: title, weapon and mode selectors and a
## primary button. Mode values match Game.Mode (0 one enemy, 1 three then captain, 2 captain).
## Laid out for 16:9. Every choice is a focusable button, so a gamepad alone can use it:
## D-pad or left stick moves the focus, A selects.

signal fight_requested(mode: int, weapon_index: int, shield: bool)
signal quit_requested
signal controls_requested
signal campaign_requested(weapon_index: int, shield: bool)
signal continue_requested

const MODE_NAMES := ["1 Enemy", "3 + Captain", "Captain only"]

var mode := 1
var weapon_index := 0
var shield := false
var split_attacks := false
var directional_guard := false

var _title: Label
var _info: Label
var _weapon_desc: Label
var _fight_button: Button
var _campaign_button: Button
var _continue_button: Button
var _new_campaign_armed := false
var _quit_button: Button
## Quit takes two presses; moving the focus away cancels the first.
var _quit_armed := false
var _weapon_row: HBoxContainer
var _shield_button: Button
var _attack_mode_button: Button
var _guard_mode_button: Button
var _weapon_group := ButtonGroup.new()
var _weapon_buttons: Array[Button] = []
var _weapons: Array[Weapon] = []
var _mode_buttons: Array[Button] = []
var _hint: Label
var _style: InputPrompts.Style = InputPrompts.Style.KEYBOARD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	_title = _label(50)
	box.add_child(_title)
	_info = _label(22)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(900, 0)
	box.add_child(_info)

	var weapon_label := _label(18)
	weapon_label.text = "WEAPON"
	weapon_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(weapon_label)
	_weapon_row = HBoxContainer.new()
	_weapon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_weapon_row.add_theme_constant_override("separation", 8)
	box.add_child(_weapon_row)
	_weapon_desc = _label(20)
	_weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_desc.custom_minimum_size = Vector2(900, 54)
	box.add_child(_weapon_desc)

	# Shield and the two trial toggles share one row in landscape.
	var option_row := HBoxContainer.new()
	option_row.alignment = BoxContainer.ALIGNMENT_CENTER
	option_row.add_theme_constant_override("separation", 12)
	box.add_child(option_row)

	_shield_button = Button.new()
	_shield_button.toggle_mode = true
	_shield_button.custom_minimum_size = Vector2(270, 54)
	_shield_button.add_theme_font_size_override("font_size", 22)
	UiFocus.style(_shield_button)
	var shield_on := StyleBoxFlat.new()
	shield_on.bg_color = Color(0.2, 0.45, 0.85)
	shield_on.set_corner_radius_all(8)
	_shield_button.add_theme_stylebox_override("pressed", shield_on)
	_shield_button.add_theme_stylebox_override("hover_pressed", shield_on)
	_shield_button.pressed.connect(func(): set_shield(_shield_button.button_pressed))
	option_row.add_child(_shield_button)

	_attack_mode_button = Button.new()
	_attack_mode_button.toggle_mode = true
	_attack_mode_button.custom_minimum_size = Vector2(320, 54)
	_attack_mode_button.add_theme_font_size_override("font_size", 22)
	UiFocus.style(_attack_mode_button)
	_attack_mode_button.pressed.connect(func(): set_split_attacks(_attack_mode_button.button_pressed))
	option_row.add_child(_attack_mode_button)

	_guard_mode_button = Button.new()
	_guard_mode_button.toggle_mode = true
	_guard_mode_button.custom_minimum_size = Vector2(320, 54)
	_guard_mode_button.add_theme_font_size_override("font_size", 22)
	UiFocus.style(_guard_mode_button)
	_guard_mode_button.pressed.connect(func(): set_directional_guard(_guard_mode_button.button_pressed))
	option_row.add_child(_guard_mode_button)

	var mode_label := _label(18)
	mode_label.text = "FIGHT"
	mode_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(mode_label)
	var mode_group := ButtonGroup.new()
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 12)
	box.add_child(mode_row)
	for i in MODE_NAMES.size():
		var b := _toggle(MODE_NAMES[i], mode_group, Vector2(220, 56))
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func(): mode = i)
		mode_row.add_child(b)
		_mode_buttons.append(b)

	_fight_button = Button.new()
	_fight_button.custom_minimum_size = Vector2(340, 76)
	_fight_button.add_theme_font_size_override("font_size", 38)
	UiFocus.style(_fight_button)
	for style_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.62, 0.3) if style_name != "pressed" else Color(0.14, 0.45, 0.22)
		sb.set_corner_radius_all(10)
		_fight_button.add_theme_stylebox_override(style_name, sb)
	_fight_button.pressed.connect(func(): fight_requested.emit(mode, weapon_index, shield_usable()))
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 12)
	play_row.add_child(_fight_button)
	box.add_child(play_row)
	_campaign_button = _toggle("New campaign", null, Vector2(245, 76))
	_campaign_button.toggle_mode = false
	_campaign_button.add_theme_font_size_override("font_size", 26)
	_campaign_button.pressed.connect(_on_campaign_pressed)
	_campaign_button.focus_exited.connect(_disarm_campaign)
	play_row.add_child(_campaign_button)
	_continue_button = _toggle("Continue", null, Vector2(180, 76))
	_continue_button.toggle_mode = false
	_continue_button.add_theme_font_size_override("font_size", 24)
	_continue_button.pressed.connect(func(): continue_requested.emit())
	play_row.add_child(_continue_button)
	_continue_button.hide()

	_quit_button = Button.new()
	_quit_button.custom_minimum_size = Vector2(340, 42)
	_quit_button.add_theme_font_size_override("font_size", 20)
	UiFocus.style(_quit_button)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_button.focus_exited.connect(_disarm_quit)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	var bindings := Button.new()
	bindings.text = "Controls"
	bindings.custom_minimum_size = Vector2(200, 42)
	bindings.add_theme_font_size_override("font_size", 20)
	UiFocus.style(bindings)
	bindings.pressed.connect(func(): controls_requested.emit())
	footer.add_child(bindings)
	footer.add_child(_quit_button)
	_disarm_quit()

	_hint = _label(18)
	_hint.modulate = Color(1, 1, 1, 0.65)
	box.add_child(_hint)
	_refresh_hint()

	set_mode(mode)
	set_split_attacks(split_attacks)
	set_directional_guard(directional_guard)
	show_start()


## Builds the weapon buttons. Call once after the panel is in the tree.
func set_weapons(list: Array[Weapon]) -> void:
	_weapons = list
	for b in _weapon_buttons:
		b.queue_free()
	_weapon_buttons.clear()
	for i in list.size():
		var b := _toggle(list[i].display_name, _weapon_group, Vector2(160, 58))
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): set_weapon(i))
		_weapon_row.add_child(b)
		_weapon_buttons.append(b)
	set_weapon(weapon_index)


func set_weapon(i: int) -> void:
	weapon_index = i
	for k in _weapon_buttons.size():
		_weapon_buttons[k].button_pressed = (k == i)
	if i < _weapons.size():
		_weapon_desc.text = _weapons[i].description
	_refresh_shield()


func set_shield(on: bool) -> void:
	shield = on
	_refresh_shield()


## A/B toggles; default values reproduce the 0.8 controls and all-round defence.
func set_split_attacks(on: bool) -> void:
	split_attacks = on
	if _attack_mode_button != null:
		_attack_mode_button.set_pressed_no_signal(on)
		_attack_mode_button.text = "Attack key: LIGHT only" if on else "Attack key: HOLD = heavy"
	_refresh_hint()


func set_directional_guard(on: bool) -> void:
	directional_guard = on
	if _guard_mode_button != null:
		_guard_mode_button.set_pressed_no_signal(on)
		_guard_mode_button.text = "Guard: DIRECTIONAL trial" if on else "Guard: ALL-ROUND"


## A shield only works with a one-handed weapon.
func shield_usable() -> bool:
	return shield and weapon_index < _weapons.size() and _weapons[weapon_index].one_handed


func _refresh_shield() -> void:
	if _shield_button == null:
		return
	var one_handed := weapon_index >= _weapons.size() or _weapons[weapon_index].one_handed
	_shield_button.disabled = not one_handed
	_shield_button.set_pressed_no_signal(shield and one_handed)
	if one_handed:
		_shield_button.text = "Shield: ON" if shield else "Shield: OFF"
	else:
		_shield_button.text = "Two-handed: no shield"


func set_mode(m: int) -> void:
	mode = m
	for k in _mode_buttons.size():
		_mode_buttons[k].button_pressed = (k == m)


func show_start() -> void:
	_title.text = "FORGEBREACH"
	_title.modulate = Color.WHITE
	_info.text = "Pick a weapon, then start a campaign or enter the Test Room."
	_fight_button.text = "Test Room"
	_disarm_campaign()
	_disarm_quit()
	visible = true


func show_result(victory: bool, seconds: float, hp_left: float, m: int, weapon_name: String) -> void:
	_title.text = "VICTORY" if victory else "DEFEAT"
	_title.modulate = Color(0.5, 1.0, 0.55) if victory else Color(1.0, 0.4, 0.35)
	_info.text = "%s, %s.  Time %.1f s.  Health left %d." % [weapon_name, MODE_NAMES[m], seconds, ceili(hp_left)]
	_fight_button.text = "Retry"
	set_mode(m)
	_disarm_quit()
	visible = true


## End of a run or of an attempt: `heading` is the title, `details` the lines under it.
func show_campaign_result(cleared: bool, heading: String, details: String) -> void:
	show_start()
	_title.text = heading
	_title.modulate = Color(0.5, 1.0, 0.55) if cleared else Color(1.0, 0.4, 0.35)
	_info.text = details
	_fight_button.text = "Test Room" if cleared else "Retry room"


func set_continue_available(available: bool) -> void:
	_continue_button.visible = available


func _on_campaign_pressed() -> void:
	if _continue_button.visible and not _new_campaign_armed:
		_new_campaign_armed = true
		_campaign_button.text = "Replace save?"
		return
	campaign_requested.emit(weapon_index, shield_usable())


func _disarm_campaign() -> void:
	_new_campaign_armed = false
	_campaign_button.text = "New campaign"


func layout(vp: Vector2) -> void:
	position = Vector2.ZERO
	size = vp


## Button names in the hint follow the device in use.
func set_prompt_style(style: InputPrompts.Style) -> void:
	_style = style
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint == null:
		return
	_hint.text = "%s\n%s" % [
			InputPrompts.menu_hint(_style), InputPrompts.combat_line(_style, not split_attacks)]


func _on_quit_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_button.text = "Press again to quit"
		return
	quit_requested.emit()


func _disarm_quit() -> void:
	_quit_armed = false
	if _quit_button != null:
		_quit_button.text = "Quit to desktop"


## Keeps the focus on the panel while it is shown; the primary button is the default.
func _process(_delta: float) -> void:
	UiFocus.keep_inside(self, _fight_button)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _toggle(text: String, group: ButtonGroup, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 28)
	UiFocus.style(b)
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.2, 0.45, 0.85)
	on.set_corner_radius_all(8)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b
