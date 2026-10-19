class_name MenuPanel
extends Control
## Start screen and result screen share one panel: title, weapon and mode selectors and a
## primary button. Mode values match Game.Mode (0 one enemy, 1 three then captain, 2 captain).

signal fight_requested(mode: int, weapon_index: int, shield: bool)

const MODE_NAMES := ["1 Enemy", "3 + Captain", "Captain only"]

var mode := 1
var weapon_index := 0
var shield := false

var _title: Label
var _info: Label
var _weapon_desc: Label
var _fight_button: Button
var _weapon_row: HBoxContainer
var _shield_button: Button
var _weapon_group := ButtonGroup.new()
var _weapon_buttons: Array[Button] = []
var _weapons: Array[Weapon] = []
var _mode_buttons: Array[Button] = []


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
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_title = _label(56)
	box.add_child(_title)
	_info = _label(26)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(600, 0)
	box.add_child(_info)

	var weapon_label := _label(22)
	weapon_label.text = "WEAPON"
	weapon_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(weapon_label)
	_weapon_row = HBoxContainer.new()
	_weapon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_weapon_row.add_theme_constant_override("separation", 12)
	box.add_child(_weapon_row)
	_weapon_desc = _label(24)
	_weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_desc.custom_minimum_size = Vector2(600, 64)
	box.add_child(_weapon_desc)

	_shield_button = Button.new()
	_shield_button.toggle_mode = true
	_shield_button.custom_minimum_size = Vector2(320, 70)
	_shield_button.add_theme_font_size_override("font_size", 28)
	var shield_on := StyleBoxFlat.new()
	shield_on.bg_color = Color(0.2, 0.45, 0.85)
	shield_on.set_corner_radius_all(8)
	_shield_button.add_theme_stylebox_override("pressed", shield_on)
	_shield_button.add_theme_stylebox_override("hover_pressed", shield_on)
	_shield_button.pressed.connect(func(): set_shield(_shield_button.button_pressed))
	var shield_wrap := CenterContainer.new()
	shield_wrap.add_child(_shield_button)
	box.add_child(shield_wrap)

	var mode_label := _label(22)
	mode_label.text = "FIGHT"
	mode_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(mode_label)
	var mode_group := ButtonGroup.new()
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 12)
	box.add_child(mode_row)
	for i in MODE_NAMES.size():
		var b := _toggle(MODE_NAMES[i], mode_group, Vector2(200, 84))
		b.pressed.connect(func(): mode = i)
		mode_row.add_child(b)
		_mode_buttons.append(b)

	_fight_button = Button.new()
	_fight_button.custom_minimum_size = Vector2(360, 110)
	_fight_button.add_theme_font_size_override("font_size", 44)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.62, 0.3) if style_name != "pressed" else Color(0.14, 0.45, 0.22)
		sb.set_corner_radius_all(10)
		_fight_button.add_theme_stylebox_override(style_name, sb)
	_fight_button.pressed.connect(func(): fight_requested.emit(mode, weapon_index, shield_usable()))
	var wrap := CenterContainer.new()
	wrap.add_child(_fight_button)
	box.add_child(wrap)

	var hint := _label(21)
	hint.text = "Left thumb: move.  ATTACK: tap = light, hold = heavy.\nBLOCK: hold to guard; raise it just before a hit to parry.\nDODGE: roll with brief invulnerability.\nDesktop: WASD / arrows, J attack, K block, Space dodge, Enter."
	hint.modulate = Color(1, 1, 1, 0.65)
	box.add_child(hint)

	set_mode(mode)
	show_start()


## Builds the weapon buttons. Call once after the panel is in the tree.
func set_weapons(list: Array[Weapon]) -> void:
	_weapons = list
	for b in _weapon_buttons:
		b.queue_free()
	_weapon_buttons.clear()
	for i in list.size():
		var b := _toggle(list[i].display_name, _weapon_group, Vector2(146, 84))
		b.add_theme_font_size_override("font_size", 28)
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
	_title.text = "SHIELDWALL"
	_title.modulate = Color.WHITE
	_info.text = "Combat test: pick a weapon, then fight."
	_fight_button.text = "Fight"
	visible = true


func show_result(victory: bool, seconds: float, hp_left: float, m: int, weapon_name: String) -> void:
	_title.text = "VICTORY" if victory else "DEFEAT"
	_title.modulate = Color(0.5, 1.0, 0.55) if victory else Color(1.0, 0.4, 0.35)
	_info.text = "%s, %s.  Time %.1f s.  Health left %d." % [weapon_name, MODE_NAMES[m], seconds, ceili(hp_left)]
	_fight_button.text = "Retry"
	set_mode(m)
	visible = true


func layout(vp: Vector2) -> void:
	position = Vector2.ZERO
	size = vp


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
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.2, 0.45, 0.85)
	on.set_corner_radius_all(8)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b
