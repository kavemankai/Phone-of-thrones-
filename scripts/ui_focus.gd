class_name UiFocus
extends RefCounted
## Shared focus behaviour for controller-driven panels: a focus ring that is easy to see
## from a sofa, and a guard that keeps the focus inside the panel that is on screen.

const RING := Color(1.0, 0.86, 0.3)


## Thick outline drawn over the button's own style when it has the focus.
static func ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = RING
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_expand_margin_all(4.0)
	return sb


static func style(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", ring())


## Call every frame from a panel. If the panel is on screen and the focus is nowhere inside
## it (first show, a mouse click on empty space, a pad plugged in later), focus `fallback`.
static func keep_inside(panel: Control, fallback: Control) -> void:
	if fallback == null or not panel.is_inside_tree() or not panel.is_visible_in_tree():
		return
	var focused := panel.get_viewport().gui_get_focus_owner()
	if focused != null and (focused == panel or panel.is_ancestor_of(focused)):
		return
	if fallback.is_visible_in_tree() and fallback.focus_mode != Control.FOCUS_NONE:
		fallback.grab_focus()
