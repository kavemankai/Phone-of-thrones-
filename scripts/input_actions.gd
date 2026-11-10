class_name InputActions
extends RefCounted
## The one table of game input actions. ensure() registers them in Godot's InputMap, so no
## other script asks for a physical key or pad button. Bindings match every device (-1).
## Menu navigation uses Godot's built-in ui_* actions. Their default bindings are not relied
## on: ensure() adds the pad bindings the menus need (A confirm, B back, D-pad and left stick
## to move the focus) and takes Space off ui_accept, because Space is the dodge key.

const MOVE_LEFT := &"fb_move_left"
const MOVE_RIGHT := &"fb_move_right"
const MOVE_UP := &"fb_move_up"
const MOVE_DOWN := &"fb_move_down"
const AIM_LEFT := &"fb_aim_left"
const AIM_RIGHT := &"fb_aim_right"
const AIM_UP := &"fb_aim_up"
const AIM_DOWN := &"fb_aim_down"
const LIGHT := &"fb_light"
const HEAVY := &"fb_heavy"
const DODGE := &"fb_dodge"
const GUARD := &"fb_guard"
const PAUSE := &"fb_pause"
const FULLSCREEN := &"fb_fullscreen"

## Radial dead zones applied to the whole stick, not per axis.
const MOVE_DEADZONE := 0.20
const AIM_DEADZONE := 0.35
## Per-action threshold for "pressed". The sticks are read as vectors with the radial dead
## zones above, so this only has to be low enough not to clip them.
const AXIS_ACTION_DEADZONE := 0.10

const ALL: Array[StringName] = [
	MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN,
	LIGHT, HEAVY, DODGE, GUARD, PAUSE, FULLSCREEN,
]

const BINDINGS_PATH := "user://controls.cfg"
static var _defaults: Dictionary = {}
static var _custom := ConfigFile.new()


## Registers every action once. Safe to call again.
static func ensure() -> void:
	_bind(MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)], AXIS_ACTION_DEADZONE)
	_bind(MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)], AXIS_ACTION_DEADZONE)
	_bind(MOVE_UP, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)], AXIS_ACTION_DEADZONE)
	_bind(MOVE_DOWN, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)], AXIS_ACTION_DEADZONE)
	_bind(AIM_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)], AXIS_ACTION_DEADZONE)
	_bind(AIM_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)], AXIS_ACTION_DEADZONE)
	_bind(AIM_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)], AXIS_ACTION_DEADZONE)
	_bind(AIM_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)], AXIS_ACTION_DEADZONE)
	_bind(LIGHT, [_key(KEY_J), _button(JOY_BUTTON_X)])
	_bind(HEAVY, [_key(KEY_L), _button(JOY_BUTTON_Y)])
	_bind(DODGE, [_key(KEY_SPACE), _button(JOY_BUTTON_B)])
	_bind(GUARD, [_key(KEY_K), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_bind(PAUSE, [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	_bind(FULLSCREEN, [_key(KEY_F11)])
	_ensure_ui()
	if _defaults.is_empty():
		for action in ALL:
			_defaults[action] = InputMap.action_get_events(action)
		_custom.load(BINDINGS_PATH)
		_apply_bindings()


## Each override replaces the bindings for one device family. An unused action
## can take a binding from another action without creating a duplicate.
static func rebind(action: StringName, event: InputEvent) -> Error:
	var pad := is_pad_event(event)
	var section := "controller" if pad else "keyboard"
	var encoded := _encode(event)
	var previous := binding_events(action, pad)
	var next := ConfigFile.new()
	next.parse(_custom.encode_to_text())
	for other in ALL:
		if other == action:
			continue
		var events := binding_events(other, pad)
		for i in events.size():
			if _encode(events[i]) != encoded:
				continue
			events.remove_at(i)
			if not previous.is_empty() and accepts_binding(other, previous[0]):
				events.insert(i, previous[0])
			next.set_value(section, other, _encode_list(events))
			break
	next.set_value(section, action, [encoded])
	return _save_bindings(next)


static func accepts_binding(action: StringName, event: InputEvent) -> bool:
	return not event is InputEventJoypadMotion or action in [
		MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN,
	]


static func reset_bindings() -> Error:
	return _save_bindings(ConfigFile.new())


static func has_override(action: StringName, pad: bool) -> bool:
	return _custom.has_section_key("controller" if pad else "keyboard", action)


static func binding_events(action: StringName, pad: bool) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if is_pad_event(event) == pad:
			result.append(event)
	return result


static func _save_bindings(next: ConfigFile) -> Error:
	var error := next.save(BINDINGS_PATH)
	if error == OK:
		_custom = next
		_apply_bindings()
	return error


static func _apply_bindings() -> void:
	release_all()
	for action in ALL:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			if not has_override(action, is_pad_event(event)):
				InputMap.action_add_event(action, event)
		for section in ["keyboard", "controller"]:
			var values: Variant = _custom.get_value(section, action, [])
			if not values is Array:
				continue
			for value in values:
				if value is Vector2i:
					var event := _decode(value)
					if event != null and accepts_binding(action, event) and is_pad_event(event) == (section == "controller"):
						InputMap.action_add_event(action, event)


static func _encode_list(events: Array[InputEvent]) -> Array[Vector2i]:
	var values: Array[Vector2i] = []
	for event in events:
		values.append(_encode(event))
	return values


static func _encode(event: InputEvent) -> Vector2i:
	if event is InputEventKey:
		return Vector2i(0, event.physical_keycode)
	if event is InputEventJoypadButton:
		return Vector2i(1, event.button_index)
	var motion := event as InputEventJoypadMotion
	return Vector2i(2 if motion.axis_value < 0.0 else 3, motion.axis)


static func _decode(value: Vector2i) -> InputEvent:
	match value.x:
		0:
			if value.y > 0:
				return _key(value.y as Key)
		1:
			if value.y >= 0 and value.y < JOY_BUTTON_MAX:
				return _button(value.y as JoyButton)
		2, 3:
			if value.y >= 0 and value.y < JOY_AXIS_MAX:
				return _axis(value.y as JoyAxis, -1.0 if value.x == 2 else 1.0)
	return null


## Menu actions. Adds only what is missing, so calling this again never duplicates an event.
static func _ensure_ui() -> void:
	_add_missing(&"ui_accept", [_key(KEY_ENTER), _button(JOY_BUTTON_A)])
	_add_missing(&"ui_cancel", [_key(KEY_ESCAPE), _button(JOY_BUTTON_B)])
	_add_missing(&"ui_left", [_key(KEY_LEFT), _button(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_missing(&"ui_right", [_key(KEY_RIGHT), _button(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_missing(&"ui_up", [_key(KEY_UP), _button(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_missing(&"ui_down", [_key(KEY_DOWN), _button(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	# One Space press must never both dodge and confirm a menu button (Retry, Resume).
	_remove_key(&"ui_accept", KEY_SPACE)


static func _add_missing(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev: InputEvent in events:
		if not _has_equivalent(action, ev):
			InputMap.action_add_event(action, ev)


## True when the action already has this key, pad button or stick direction on any device.
static func _has_equivalent(action: StringName, wanted: InputEvent) -> bool:
	for have: InputEvent in InputMap.action_get_events(action):
		if wanted is InputEventKey and have is InputEventKey:
			var code: Key = wanted.physical_keycode
			if have.physical_keycode == code or have.keycode == code:
				return true
		elif wanted is InputEventJoypadButton and have is InputEventJoypadButton:
			if have.button_index == wanted.button_index:
				return true
		elif wanted is InputEventJoypadMotion and have is InputEventJoypadMotion:
			if have.axis == wanted.axis and signf(have.axis_value) == signf(wanted.axis_value):
				return true
	return false


static func _remove_key(action: StringName, code: Key) -> void:
	if not InputMap.has_action(action):
		return
	for have: InputEvent in InputMap.action_get_events(action):
		if have is InputEventKey and (have.physical_keycode == code or have.keycode == code):
			InputMap.action_erase_event(action, have)


static func _bind(action: StringName, events: Array, deadzone := 0.5) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, deadzone)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.device = -1
	return ev


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	ev.device = -1
	return ev


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	ev.device = -1
	return ev


static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Left stick / movement keys as a screen-space vector, radial dead zone applied.
static func read_move() -> Vector2:
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, MOVE_DEADZONE)


## Right stick as a screen-space vector. Zero while the stick rests inside its dead zone.
static func read_aim() -> Vector2:
	return Input.get_vector(AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN, AIM_DEADZONE)


## Force every game action up. Used when a pad is unplugged or the window loses focus, so
## nothing stays held by a device that can no longer send the release.
static func release_all() -> void:
	for action in ALL:
		if InputMap.has_action(action):
			Input.action_release(action)
