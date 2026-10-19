class_name TouchControls
extends Control
## On-screen controls. A floating joystick on the left half of the control band; Attack, Dodge
## and Block buttons on the right. Each finger is tracked by its own touch index, so a
## stick and a button can be used at the same moment. Output goes to CombatInput only.

const FORGIVE := 14.0
const CANCEL_MARGIN := 46.0
const ATTACK_R := 84.0
const DODGE_R := 62.0
const BLOCK_R := 52.0

var input: CombatInput
var hero: Hero
var tuning: Tuning
var enabled := false

var band := Rect2()
var joy_zone := Rect2()
var joy_hint := Vector2()
var attack_center := Vector2()
var dodge_center := Vector2()
var block_center := Vector2()

var joy_index := -1
var atk_index := -1
var dodge_index := -1
var block_index := -1
var joy_origin := Vector2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## vp: visible canvas size. insets: left, top, right, bottom safe-area margins.
func layout(vp: Vector2, band_h: float, insets: Vector4) -> void:
	position = Vector2.ZERO
	size = vp
	band = Rect2(0.0, vp.y - band_h, vp.x, band_h)
	var right := vp.x - insets.z
	var bottom := vp.y - insets.w
	attack_center = Vector2(right - 118.0, bottom - 118.0)
	dodge_center = Vector2(right - 118.0 - 175.0, bottom - 118.0 - 70.0)
	block_center = Vector2(right - 118.0, bottom - 282.0)
	joy_zone = Rect2(insets.x, band.position.y, vp.x * 0.5 - insets.x, band_h)
	joy_hint = Vector2(vp.x * 0.22, bottom - 150.0)
	queue_redraw()


func set_enabled(on: bool) -> void:
	enabled = on
	reset()


## Forget every finger and release all held input (focus loss, retry, result screen).
func reset() -> void:
	joy_index = -1
	atk_index = -1
	dodge_index = -1
	block_index = -1
	if input != null:
		input.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)


func _touch_down(index: int, p: Vector2) -> void:
	if atk_index == -1 and p.distance_to(attack_center) <= ATTACK_R + FORGIVE:
		atk_index = index
		input.press_attack(true)
	elif dodge_index == -1 and p.distance_to(dodge_center) <= DODGE_R + FORGIVE:
		dodge_index = index
		input.press_dodge()
	elif block_index == -1 and p.distance_to(block_center) <= BLOCK_R + FORGIVE:
		block_index = index
		input.press_block(true)
	elif joy_index == -1 and joy_zone.has_point(p):
		joy_index = index
		joy_origin = p
		input.touch_move = Vector2.ZERO


func _touch_up(index: int) -> void:
	if index == atk_index:
		atk_index = -1
		input.release_attack(true)
	elif index == dodge_index:
		dodge_index = -1
	elif index == block_index:
		block_index = -1
		input.release_block(true)
	elif index == joy_index:
		joy_index = -1
		input.touch_move = Vector2.ZERO


func _touch_move(index: int, p: Vector2) -> void:
	if index == joy_index:
		var v := p - joy_origin
		var radius := tuning.joystick_radius
		if v.length() > radius:
			# Floating stick: the base follows the thumb so it never needs re-centring.
			joy_origin = p - v.normalized() * radius
			v = p - joy_origin
		var len := v.length() / radius
		var dz := tuning.joystick_deadzone
		if len < dz:
			input.touch_move = Vector2.ZERO
		else:
			input.touch_move = v.normalized() * minf(1.0, (len - dz) / (1.0 - dz))
	elif index == atk_index:
		if p.distance_to(attack_center) > ATTACK_R + CANCEL_MARGIN:
			atk_index = -1
			input.cancel_attack(true)
	elif index == block_index:
		# A thumb that slides well off the button lowers the guard.
		if p.distance_to(block_center) > BLOCK_R + CANCEL_MARGIN:
			block_index = -1
			input.release_block(true)


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or tuning == null:
		return
	var font := ThemeDB.fallback_font
	draw_rect(band, Color(0, 0, 0, 0.2))
	draw_line(band.position, band.position + Vector2(band.size.x, 0.0), Color(1, 1, 1, 0.12), 2.0)

	# Joystick.
	var jr := tuning.joystick_radius
	var base := joy_origin if joy_index != -1 else joy_hint
	var idle_alpha := 0.12 if joy_index != -1 else 0.06
	draw_circle(base, jr, Color(1, 1, 1, idle_alpha))
	draw_arc(base, jr, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	if joy_index != -1:
		draw_circle(base + input.touch_move * jr, 34.0, Color(1, 1, 1, 0.55))
	else:
		draw_string(font, base + Vector2(-jr, 8.0), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, jr * 2.0,
				24, Color(1, 1, 1, 0.4))

	# Attack button.
	var held := atk_index != -1
	var ready := hero != null and hero.is_heavy_ready()
	var atk_col := Color(0.9, 0.25, 0.2, 0.75 if held else 0.5)
	if ready:
		atk_col = Color(1.0, 0.75, 0.15, 0.9)
	draw_circle(attack_center, ATTACK_R, atk_col)
	draw_arc(attack_center, ATTACK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	# Crossed swords icon.
	draw_line(attack_center + Vector2(-26, -30), attack_center + Vector2(26, 22), Color.WHITE, 6.0)
	draw_line(attack_center + Vector2(26, -30), attack_center + Vector2(-26, 22), Color.WHITE, 6.0)
	draw_line(attack_center + Vector2(-34, 12), attack_center + Vector2(-14, 32), Color.WHITE, 5.0)
	draw_line(attack_center + Vector2(34, 12), attack_center + Vector2(14, 32), Color.WHITE, 5.0)
	var label := "HEAVY!" if ready else "ATTACK"
	draw_string(font, attack_center + Vector2(-ATTACK_R, ATTACK_R * 0.62), label,
			HORIZONTAL_ALIGNMENT_CENTER, ATTACK_R * 2.0, 22, Color.WHITE)
	if hero != null and hero.state == Hero.State.CHARGING:
		var p := hero.charge_progress()
		draw_arc(attack_center, ATTACK_R + 10.0, -PI * 0.5, -PI * 0.5 + TAU * p, 48,
				Color(1.0, 0.85, 0.2) if ready else Color.WHITE, 8.0)

	# Dodge button: a diamond so it is not confused with Attack.
	var dodge_col := Color(0.2, 0.55, 0.95, 0.75 if dodge_index != -1 else 0.5)
	var dr := DODGE_R + 6.0
	var diamond := PackedVector2Array([
		dodge_center + Vector2(0, -dr), dodge_center + Vector2(dr, 0),
		dodge_center + Vector2(0, dr), dodge_center + Vector2(-dr, 0)])
	draw_colored_polygon(diamond, dodge_col)
	var outline := diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, Color(1, 1, 1, 0.7), 3.0)
	# Chevron icon.
	draw_polyline(PackedVector2Array([dodge_center + Vector2(-16, -22), dodge_center + Vector2(0, -6),
			dodge_center + Vector2(16, -22)]), Color.WHITE, 5.0)
	draw_polyline(PackedVector2Array([dodge_center + Vector2(-16, -8), dodge_center + Vector2(0, 8),
			dodge_center + Vector2(16, -8)]), Color.WHITE, 5.0)
	draw_string(font, dodge_center + Vector2(-dr, 34.0), "DODGE", HORIZONTAL_ALIGNMENT_CENTER,
			dr * 2.0, 20, Color.WHITE)
	if hero != null:
		var charges := hero.max_charges()
		for i in charges:
			var c := dodge_center + Vector2((i - (charges - 1) * 0.5) * 20.0, 52.0)
			if i < hero.dodge_charges:
				draw_circle(c, 6.0, Color(0.7, 0.9, 1.0))
			else:
				draw_arc(c, 6.0, 0.0, TAU, 16, Color(0.7, 0.9, 1.0, 0.6), 2.0)
	_draw_block_button(font)


func _draw_block_button(font: Font) -> void:
	var held := block_index != -1
	var guarding := hero != null and hero.is_guarding()
	var r := BLOCK_R
	var c := block_center
	draw_circle(c, r, Color(0.2, 0.3, 0.45, 0.75 if (held or guarding) else 0.5))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 3.0)
	# A heater-shield icon, so it reads differently from the round Attack and diamond Dodge.
	var face := Color(0.85, 0.9, 1.0) if not (hero != null and hero.parry_flash > 0.0) else Color(1.0, 0.85, 0.3)
	var top := c + Vector2(0, -8)
	var shield := PackedVector2Array([
		top + Vector2(-16, -20), top + Vector2(16, -20), top + Vector2(16, 2),
		top + Vector2(0, 21), top + Vector2(-16, 2)])
	draw_colored_polygon(shield, face)
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, Color(0.1, 0.15, 0.3), 3.0)
	draw_string(font, c + Vector2(-r, 40.0), "BLOCK", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Color.WHITE)
	if hero != null and (guarding or hero.guard < hero.guard_max()):
		# Guard meter ring around the button.
		var frac := clampf(hero.guard / hero.guard_max(), 0.0, 1.0)
		var col := Color(0.55, 0.85, 1.0) if frac > 0.3 else Color(1.0, 0.5, 0.25)
		draw_arc(c, r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, col, 6.0)
