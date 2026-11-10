class_name InputPrompts
extends RefCounted
## Button names shown on screen, chosen by the device the player touched last.

enum Style { KEYBOARD, XBOX, PLAYSTATION }

const PLAYSTATION_NAMES := ["playstation", "dualsense", "dualshock", "sony", "ps3", "ps4", "ps5"]

const NEUTRAL := Color(0.28, 0.31, 0.38)
const BLUE := Color(0.16, 0.38, 0.85)
const YELLOW := Color(0.78, 0.6, 0.1)
const RED := Color(0.78, 0.2, 0.18)
const GREEN := Color(0.2, 0.6, 0.28)
const PINK := Color(0.72, 0.32, 0.6)


## Xbox labels unless the pad names itself as a PlayStation one.
static func style_for_joypad(device: int) -> Style:
	var joy_name := Input.get_joy_name(device).to_lower()
	for key: String in PLAYSTATION_NAMES:
		if joy_name.contains(key):
			return Style.PLAYSTATION
	return Style.XBOX


## Combat legend as [glyph, action, badge colour] rows, in display order.
static func combat(style: Style, hold_for_heavy := false) -> Array:
	var rows := _default_combat(style, hold_for_heavy)
	var pad := style != Style.KEYBOARD
	var first_button := 2 if pad else 1
	if _group_changed([InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
			InputActions.MOVE_UP, InputActions.MOVE_DOWN], pad):
		rows[0][0] = "Custom"
	if pad and _group_changed([InputActions.AIM_LEFT, InputActions.AIM_RIGHT,
			InputActions.AIM_UP, InputActions.AIM_DOWN], true):
		rows[1][0] = "Custom"
	var buttons := [InputActions.LIGHT, InputActions.HEAVY, InputActions.DODGE,
			InputActions.GUARD, InputActions.PAUSE]
	for i in buttons.size():
		if InputActions.has_override(buttons[i], pad):
			var events := InputActions.binding_events(buttons[i], pad)
			rows[first_button + i][0] = "—" if events.is_empty() else _event_label(events[0], style)
			rows[first_button + i][2] = NEUTRAL
	return rows


static func _group_changed(actions: Array, pad: bool) -> bool:
	for action: StringName in actions:
		if InputActions.has_override(action, pad):
			return true
	return false


static func binding_label(action: StringName, style: Style) -> String:
	var names: PackedStringArray = []
	for event in InputActions.binding_events(action, style != Style.KEYBOARD):
		names.append(_event_label(event, style))
	return " / ".join(names) if not names.is_empty() else "Unbound"


static func _event_label(event: InputEvent, style: Style) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode))
	if event is InputEventJoypadButton:
		var ps_names := {
			JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square",
			JOY_BUTTON_Y: "Triangle", JOY_BUTTON_LEFT_SHOULDER: "L1",
			JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		}
		if style == Style.PLAYSTATION and ps_names.has(event.button_index):
			return ps_names[event.button_index]
		var names := {
			JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
			JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide",
			JOY_BUTTON_LEFT_STICK: "LS click", JOY_BUTTON_RIGHT_STICK: "RS click",
			JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
			JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
		}
		return names.get(event.button_index, "Button %d" % event.button_index)
	var motion := event as InputEventJoypadMotion
	match motion.axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X:
			var stick := "Left stick" if motion.axis == JOY_AXIS_LEFT_X else "Right stick"
			return stick + (" ←" if motion.axis_value < 0.0 else " →")
		JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y:
			var stick := "Left stick" if motion.axis == JOY_AXIS_LEFT_Y else "Right stick"
			return stick + (" ↑" if motion.axis_value < 0.0 else " ↓")
		JOY_AXIS_TRIGGER_LEFT:
			return "L2" if style == Style.PLAYSTATION else "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2" if style == Style.PLAYSTATION else "RT"
	return "Axis %d%s" % [motion.axis, "−" if motion.axis_value < 0.0 else "+"]


static func _default_combat(style: Style, hold_for_heavy: bool) -> Array:
	match style:
		Style.XBOX:
			return [
				["LS", "Move", NEUTRAL], ["RS", "Aim", NEUTRAL], ["X", "Light", BLUE],
				["Y", "Heavy", YELLOW], ["B", "Roll", RED], ["LB", "Guard", NEUTRAL],
				["Menu", "Pause", NEUTRAL],
			]
		Style.PLAYSTATION:
			return [
				["L", "Move", NEUTRAL], ["R", "Aim", NEUTRAL], ["Square", "Light", PINK],
				["Triangle", "Heavy", GREEN], ["Circle", "Roll", RED], ["L1", "Guard", NEUTRAL],
				["Options", "Pause", NEUTRAL],
			]
	return [
		["WASD", "Move", NEUTRAL], ["J", "Light / hold" if hold_for_heavy else "Light", NEUTRAL],
		["L", "Heavy", NEUTRAL], ["Space", "Roll", NEUTRAL], ["K", "Guard", NEUTRAL],
		["Esc", "Pause", NEUTRAL],
	]


static func confirm(style: Style) -> String:
	match style:
		Style.XBOX:
			return "A"
		Style.PLAYSTATION:
			return "Cross"
	return "Enter"


static func back(style: Style) -> String:
	match style:
		Style.XBOX:
			return "B"
		Style.PLAYSTATION:
			return "Circle"
	return "Esc"


static func navigate(style: Style) -> String:
	return "Arrow keys" if style == Style.KEYBOARD else "D-pad / left stick"


## One line for menus: how to move the focus and confirm.
static func menu_hint(style: Style) -> String:
	return "%s: choose      %s: select" % [navigate(style), confirm(style)]


## The combat legend as one line of text, for panels that use labels.
static func combat_line(style: Style, hold_for_heavy := false) -> String:
	var parts: PackedStringArray = []
	for row: Array in combat(style, hold_for_heavy):
		parts.append("%s %s" % [row[0], row[1]])
	return "   ".join(parts)
