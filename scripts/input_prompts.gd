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
	match style:
		Style.XBOX:
			return [
				["LS", "Move", NEUTRAL], ["RS", "Aim", NEUTRAL], ["X", "Light", BLUE],
				["Y", "Heavy", YELLOW], ["B", "Dodge", RED], ["LB", "Guard", NEUTRAL],
				["Menu", "Pause", NEUTRAL],
			]
		Style.PLAYSTATION:
			return [
				["L", "Move", NEUTRAL], ["R", "Aim", NEUTRAL], ["Square", "Light", PINK],
				["Triangle", "Heavy", GREEN], ["Circle", "Dodge", RED], ["L1", "Guard", NEUTRAL],
				["Options", "Pause", NEUTRAL],
			]
	return [
		["WASD", "Move", NEUTRAL], ["J", "Light / hold" if hold_for_heavy else "Light", NEUTRAL],
		["L", "Heavy", NEUTRAL], ["Space", "Dodge", NEUTRAL], ["K", "Guard", NEUTRAL],
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
