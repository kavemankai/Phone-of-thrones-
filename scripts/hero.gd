class_name Hero
extends Node2D
## The player character. All gameplay runs in step(dt, enemies); _process only animates.
## Positions are in arena space: (0,0) is the arena's top-left corner.

enum State { IDLE, CHARGING, WINDUP, ACTIVE, RECOVER, DODGE, HURT, DEAD, BLOCK, GUARD_BREAK }
## What an incoming attack did. NONE means it was refused (dodge i-frames, immunity, dead)
## and may be retried; every other result consumes the attack.
enum HitResult { NONE, HIT, BLOCKED, PARRIED }

signal swung(heavy: bool)
signal dodged
signal damaged
signal died
signal hit_landed(enemy: Enemy, heavy: bool)
signal blocked(parried: bool)
signal guard_broken

const EPS := 0.000001
const BODY_COLOR := Color(0.25, 0.55, 1.0)
const FLASH_COLOR := Color(1, 1, 1)

var tuning: Tuning
var weapon: Weapon
## A shield is carried only with a one-handed weapon (see equip).
var has_shield := false
var input: CombatInput
var arena_size := Vector2(340, 380)

var state: State = State.IDLE
var state_time := 0.0
var hp := 100.0
var facing := Vector2.UP
var charge_time := 0.0
var immune_time := 0.0
var dodge_charges := 0
var dodge_recharge_t := 0.0
var dodge_dir := Vector2.ZERO
var cur_attack: Dictionary = {}
var hit_ids: Dictionary = {}
var flash := 0.0
var radius := 16.0
var guard := 0.0
var guard_wait := 0.0
var block_cd := 0.0
var parry_flash := 0.0
var block_flash := 0.0
## Experimental defence preset only; all-round mode keeps the original value.
var block_stun_mult := 1.0
var cue_text := ""
var cue_left := 0.0
var cue_color := Color.WHITE
## Ground-space walking velocity. It ramps toward the stick and is zeroed whenever an action
## takes over movement (wind-up, strike, dodge, hurt, guard break, death).
var velocity := Vector2.ZERO

var _enemies: Array = []


func setup(t: Tuning, inp: CombatInput, arena: Vector2) -> void:
	tuning = t
	input = inp
	arena_size = arena
	radius = t.hero_radius
	weapon = Weapon.sword_from(t)
	reset(t.hero_spawn())


## Weapon without a shield (kept for callers that only pick a weapon).
func set_weapon(w: Weapon) -> void:
	equip(w, false)


func equip(w: Weapon, shield: bool) -> void:
	weapon = w
	has_shield = shield and w.one_handed


## Weapon-adjusted numbers. Everything else about the hero comes straight from Tuning.
func max_charges() -> int:
	return tuning.dodge_max_charges + weapon.extra_dodge_charges


func recharge_time() -> float:
	return tuning.dodge_recharge * weapon.dodge_recharge_mult


func move_speed() -> float:
	var shield_mult := tuning.shield_move_mult if has_shield else 1.0
	return tuning.hero_speed * weapon.move_mult * shield_mult


## Guard numbers: a shield gives a wider, stronger, longer-lasting guard than a bare weapon.
func guard_arc() -> float:
	return tuning.block_arc_shield if has_shield else tuning.block_arc_bare


func guard_max() -> float:
	return tuning.guard_max_shield if has_shield else tuning.guard_max_bare


func guard_cost_mult() -> float:
	return tuning.guard_cost_shield if has_shield else tuning.guard_cost_bare


func guard_reduction() -> float:
	return tuning.block_reduction_shield if has_shield else tuning.block_reduction_bare


## How long this weapon's parry freezes an attacker, and how long its block recoils one.
func parry_stagger_time() -> float:
	return weapon.parry_stagger_time


func block_stun_time() -> float:
	return weapon.block_stun_time * block_stun_mult


func parry_window() -> float:
	return tuning.parry_window_shield if has_shield else tuning.parry_window_bare


## The breather before the captain: some health back and a full set of dodges.
func restore(heal: float) -> void:
	if state == State.DEAD:
		return
	hp = minf(tuning.hero_max_hp, hp + heal)
	dodge_charges = max_charges()
	dodge_recharge_t = 0.0


func reset(pos: Vector2) -> void:
	position = pos
	state = State.IDLE
	state_time = 0.0
	hp = tuning.hero_max_hp
	facing = Vector2.UP
	charge_time = 0.0
	immune_time = 0.0
	dodge_charges = max_charges()
	dodge_recharge_t = 0.0
	dodge_dir = Vector2.ZERO
	cur_attack = {}
	hit_ids = {}
	flash = 0.0
	guard = guard_max()
	guard_wait = 0.0
	block_cd = 0.0
	parry_flash = 0.0
	block_flash = 0.0
	cue_text = ""
	cue_left = 0.0
	velocity = Vector2.ZERO
	_enemies = []
	modulate.a = 1.0
	queue_redraw()


func is_dead() -> bool:
	return state == State.DEAD


func is_invulnerable() -> bool:
	return immune_time > 0.0 or (state == State.DODGE and state_time < tuning.dodge_iframes)


func charge_progress() -> float:
	if state != State.CHARGING:
		return 0.0
	return clampf(charge_time / tuning.heavy_hold_time, 0.0, 1.0)


func is_heavy_ready() -> bool:
	return state == State.CHARGING and charge_time + EPS >= tuning.heavy_hold_time


## Seconds until the next dodge charge returns; 0 when full.
func dodge_recharge_left() -> float:
	if dodge_charges >= max_charges():
		return 0.0
	return recharge_time() - dodge_recharge_t


## Called before enemies resolve their strikes on each Game simulation step.
## Apply only immediate defensive transitions here; attack damage still resolves
## AFTER enemies, preserving defeat on simultaneous killing blows.
func pre_resolve_defense() -> void:
	if state == State.DEAD:
		return
	# Releasing a block before impact must not grant a phantom guard frame.
	if state == State.BLOCK and not input.block_down():
		block_cd = tuning.block_reraise_delay
		_enter(State.IDLE)
	if input.dodge_pressed and state in [State.IDLE, State.CHARGING, State.RECOVER, State.BLOCK]:
		if _try_dodge():
			input.dodge_pressed = false
			return
	if input.block_down() and block_cd <= 0.0 and state in [State.IDLE, State.CHARGING]:
		_raise_guard()


func _show_cue(message: String, tint: Color) -> void:
	cue_text = message
	cue_color = tint
	cue_left = 0.65


func step(dt: float, enemies: Array) -> void:
	if state == State.DEAD:
		return
	_enemies = enemies
	immune_time = maxf(0.0, immune_time - dt)
	_recharge_dodge(dt)
	block_cd = maxf(0.0, block_cd - dt)
	_regen_guard(dt)
	state_time += dt
	match state:
		State.IDLE:
			if input.dodge_pressed and _try_dodge():
				return
			if input.block_down() and block_cd <= 0.0:
				_raise_guard()
				return
			_move(dt, 1.0)
			if input.heavy_pressed:
				_start_attack(true)
			elif input.attack_pressed:
				_enter(State.CHARGING)
				charge_time = 0.0
				_step_charging(0.0)
		State.CHARGING:
			_step_charging(dt)
		State.WINDUP:
			_move(dt, _attack_move(), false)
			if state_time >= cur_attack.windup:
				_enter(State.ACTIVE)
				hit_ids = {}
				swung.emit(cur_attack.heavy)
				_apply_hits()
		State.ACTIVE:
			_move(dt, _attack_move(), false)
			var lunge: float = cur_attack.get("lunge", 0.0)
			if lunge > 0.0:
				position = _clamp_to_arena(position + facing * (lunge / cur_attack.active) * dt)
			_apply_hits()
			if state_time >= cur_attack.active:
				_enter(State.RECOVER)
		State.RECOVER:
			_move(dt, _slow_move())
			if input.dodge_pressed and _try_dodge():
				return
			if state_time >= cur_attack.recover:
				_enter(State.IDLE)
		State.DODGE:
			_step_dodge(dt)
		State.HURT:
			if state_time >= tuning.hurt_duration:
				_enter(State.IDLE)
		State.BLOCK:
			if input.dodge_pressed and _try_dodge():
				return
			if not input.block_down():
				block_cd = tuning.block_reraise_delay
				_enter(State.IDLE)
				return
			guard_wait = tuning.guard_regen_delay  # no regeneration while the guard is up
			_move(dt, tuning.block_move_mult)
		State.GUARD_BREAK:
			if state_time >= tuning.guard_break_time:
				guard = guard_max() * tuning.guard_break_refill
				guard_wait = tuning.guard_regen_delay
				_enter(State.IDLE)


func is_guarding() -> bool:
	return state == State.BLOCK


func _raise_guard() -> void:
	charge_time = 0.0
	_enter(State.BLOCK)


func _in_guard_arc(origin: Vector2) -> bool:
	if guard_arc() >= 360.0:
		return true
	var d := origin - position
	if d.length() < 0.001:
		return true
	return absf(facing.angle_to(d)) <= deg_to_rad(guard_arc()) * 0.5


## An enemy strike. Handles the guard: a parry inside the window, a block inside the guard
## arc, otherwise an ordinary hit. The caller learns what happened from the result.
func receive_attack(damage: float, origin: Vector2, atk: AttackDef) -> HitResult:
	if state == State.DEAD or is_invulnerable():
		return HitResult.NONE
	if state == State.BLOCK and _in_guard_arc(origin):
		if state_time < parry_window():
			parry_flash = 0.3
			_show_cue("PARRY", Color(1.0, 0.85, 0.22))
			guard_wait = tuning.guard_regen_delay
			blocked.emit(true)
			return HitResult.PARRIED
		if has_shield or not atk.breaks_bare_guard:
			_absorb(damage, atk)
			return HitResult.BLOCKED
	return HitResult.HIT if take_hit(damage) else HitResult.NONE


func _absorb(damage: float, atk: AttackDef) -> void:
	var chip := damage * (1.0 - guard_reduction())
	if chip > 0.0:
		hp = maxf(0.0, hp - chip)
		flash = 0.08
		if hp <= 0.0:
			_enter(State.DEAD)
			died.emit()
			return
	guard = maxf(0.0, guard - damage * guard_cost_mult() * atk.guard_cost_mult)
	guard_wait = tuning.guard_regen_delay
	block_flash = 0.15
	_show_cue("BLOCK", Color(0.6, 0.85, 1.0))
	if guard <= 0.0:
		_enter(State.GUARD_BREAK)
		_show_cue("BROKEN", Color(1.0, 0.45, 0.2))
		guard_broken.emit()
	else:
		blocked.emit(false)


func _regen_guard(dt: float) -> void:
	if state == State.BLOCK or state == State.GUARD_BREAK or guard >= guard_max():
		return
	guard_wait = maxf(0.0, guard_wait - dt)
	if guard_wait <= 0.0:
		guard = minf(guard_max(), guard + tuning.guard_regen * dt)


## Returns true when the hit landed. Dodge i-frames, post-hit immunity and death all refuse it.
func take_hit(damage: float) -> bool:
	if state == State.DEAD or is_invulnerable():
		return false
	hp = maxf(0.0, hp - damage)
	immune_time = tuning.hit_immunity
	flash = 0.15
	_show_cue("HIT", Color(1.0, 0.4, 0.3))
	charge_time = 0.0
	cur_attack = {}
	if hp <= 0.0:
		_enter(State.DEAD)
		died.emit()
	else:
		_enter(State.HURT)
		damaged.emit()
	return true


func _enter(s: State) -> void:
	state = s
	state_time = 0.0
	var rooted := s == State.DODGE or s == State.HURT or s == State.GUARD_BREAK or s == State.DEAD
	if (s == State.WINDUP or s == State.ACTIVE) and weapon.attack_move_mult <= 0.0:
		rooted = true
	if rooted:
		velocity = Vector2.ZERO


func _step_charging(dt: float) -> void:
	charge_time += dt
	_move(dt, _slow_move())
	if input.dodge_pressed and _try_dodge():
		return
	if input.block_down() and block_cd <= 0.0:
		_raise_guard()
		return
	if input.attack_released:
		_start_attack(charge_time + EPS >= tuning.heavy_hold_time)
	elif not input.attack_down():
		# The finger left the button: cancel without attacking.
		charge_time = 0.0
		_enter(State.IDLE)


func _start_attack(heavy: bool) -> void:
	cur_attack = weapon.attack_data(heavy)
	charge_time = 0.0
	_aim_assist()
	hit_ids = {}
	_enter(State.WINDUP)


func _aim_assist() -> void:
	var half := deg_to_rad(tuning.aim_cone_deg) * 0.5
	var best: Enemy = null
	var best_dist := INF
	for e in _enemies:
		if e.is_dead():
			continue
		var d: Vector2 = e.position - position
		var dist := d.length()
		if dist > cur_attack.reach + e.radius:
			continue
		if dist > 0.001 and absf(facing.angle_to(d)) > half:
			continue
		if dist < best_dist:
			best_dist = dist
			best = e
	if best != null and best_dist > 0.001:
		facing = (best.position - position).normalized()


func _apply_hits() -> void:
	for e in _enemies:
		if e.is_dead():
			continue
		var id: int = e.get_instance_id()
		if hit_ids.has(id):
			continue
		if HitShapes.circle_in_sector(position, facing, cur_attack.reach, cur_attack.arc,
				e.position, e.radius):
			hit_ids[id] = true
			e.take_hit(cur_attack.damage, position, cur_attack.knockback, cur_attack.get("stagger", 0.0))
			hit_landed.emit(e, cur_attack.heavy)


func _try_dodge() -> bool:
	if dodge_charges <= 0:
		return false
	var v := input.move_vector()
	dodge_dir = v.normalized() if v.length() > 0.2 else -facing
	if dodge_charges >= max_charges():
		dodge_recharge_t = 0.0
	dodge_charges -= 1
	charge_time = 0.0
	if state == State.BLOCK:
		block_cd = tuning.block_reraise_delay
	_enter(State.DODGE)
	dodged.emit()
	return true


func _step_dodge(dt: float) -> void:
	var prev := state_time - dt
	var moving := clampf(tuning.dodge_duration - prev, 0.0, dt)
	position += dodge_dir * (tuning.dodge_distance / tuning.dodge_duration) * moving
	position = _clamp_to_arena(position)
	if state_time >= tuning.dodge_duration:
		_enter(State.IDLE)


func _recharge_dodge(dt: float) -> void:
	if dodge_charges >= max_charges():
		dodge_recharge_t = 0.0
		return
	dodge_recharge_t += dt
	if dodge_recharge_t + EPS >= recharge_time():
		dodge_charges += 1
		dodge_recharge_t = maxf(0.0, dodge_recharge_t - recharge_time())


## Speed fraction while winding up or striking: 0 (rooted) unless the weapon moves while attacking.
func _attack_move() -> float:
	return weapon.attack_move_mult


## Speed fraction while charging and recovering.
func _slow_move() -> float:
	return weapon.attack_move_mult if weapon.attack_move_mult > 0.0 else tuning.half_speed_mult


func _move(dt: float, mult: float, turn := true) -> void:
	var v := input.move_vector()
	var target := v * move_speed() * mult
	var ramp := tuning.move_ramp_up if target.length_squared() >= velocity.length_squared() else tuning.move_ramp_down
	velocity = velocity.move_toward(target, move_speed() / maxf(ramp, 0.001) * dt)
	if turn and v.length() > 0.001:
		facing = v.normalized()
	if velocity.length_squared() > 0.000001:
		position = _clamp_to_arena(position + velocity * dt)


func _clamp_to_arena(p: Vector2) -> Vector2:
	return p.clamp(Vector2(radius, radius), arena_size - Vector2(radius, radius))


func _process(delta: float) -> void:
	cue_left = maxf(0.0, cue_left - delta)
	flash = maxf(0.0, flash - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	block_flash = maxf(0.0, block_flash - delta)
	z_index = int(position.x + position.y)  # isometric depth order: nearer is lower on screen
	if state == State.DODGE and state_time < (tuning.dodge_iframes if tuning else 0.0):
		modulate.a = 0.4
	elif immune_time > 0.0 and state != State.DEAD:
		modulate.a = 0.55 if int(immune_time * 24.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	if tuning == null:
		return
	var r := radius
	# Ground pass: drawn in ground space, so the iso layer projects it. Wedges here are the
	# same sector the damage test uses.
	draw_circle(Vector2.ZERO, r + 3.0, Color(0, 0, 0, 0.3))
	var attacking := not cur_attack.is_empty() and state in [State.WINDUP, State.ACTIVE, State.RECOVER]
	if attacking:
		var poly := HitShapes.sector_polygon(facing, cur_attack.reach, cur_attack.arc)
		var a := 0.0
		match state:
			State.WINDUP:
				a = 0.10 + 0.12 * clampf(state_time / cur_attack.windup, 0.0, 1.0)
			State.ACTIVE:
				a = 0.6
			State.RECOVER:
				a = 0.25 * (1.0 - clampf(state_time / cur_attack.recover, 0.0, 1.0))
		draw_colored_polygon(poly, Color(0.6, 0.85, 1.0, a))
		if state == State.ACTIVE:
			var outline := poly.duplicate()
			outline.append(poly[0])
			draw_polyline(outline, Color(1, 1, 1, 0.9), 2.0)
	if state == State.BLOCK:
		# The guard arc: a hit from inside it can be blocked. Same sector helper as every wedge.
		var guard_color := Color(1.0, 0.85, 0.3, 0.5) if parry_flash > 0.0 else Color(0.5, 0.8, 1.0, 0.16)
		if guard_arc() >= 360.0:
			# All around: a ring instead of a wedge.
			draw_circle(Vector2.ZERO, r + 34.0, guard_color)
			draw_arc(Vector2.ZERO, r + 34.0, 0.0, TAU, 48, Color(0.7, 0.9, 1.0, 0.55), 2.0)
		else:
			var guard_poly := HitShapes.sector_polygon(facing, r + 34.0, guard_arc())
			draw_colored_polygon(guard_poly, guard_color)
			var guard_outline := guard_poly.duplicate()
			guard_outline.append(guard_poly[0])
			draw_polyline(guard_outline, Color(0.7, 0.9, 1.0, 0.55), 2.0)
	if state == State.CHARGING:
		if is_heavy_ready():
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
			draw_arc(Vector2.ZERO, r + 10.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, pulse), 4.0)
		else:
			draw_arc(Vector2.ZERO, r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * charge_progress(), 32,
					Color(1, 1, 1, 0.8), 3.0)

	# Upright pass: the body stands on the ground point.
	draw_set_transform_matrix(Iso.upright())
	var height := r * 2.0
	var side := FLASH_COLOR if flash > 0.0 else BODY_COLOR
	if state == State.DEAD:
		side = Color(0.3, 0.35, 0.45)
	var shield_pos := _shield_offset(height)
	# A raised shield is always held in front; a carried one is hidden behind the body when
	# it is on the far side.
	var shield_in_front := state == State.BLOCK or shield_pos.y > -height * 0.5
	if has_shield and not shield_in_front:
		_draw_shield(shield_pos, state == State.BLOCK)
	Iso.draw_cylinder(self, r, height, side, Color(0.05, 0.1, 0.25))
	if has_shield and shield_in_front:
		_draw_shield(shield_pos, state == State.BLOCK)
	if state == State.GUARD_BREAK:
		# Dazed: stars circling the head.
		var spin := Time.get_ticks_msec() * 0.008
		for i in 3:
			var a := spin + i * TAU / 3.0
			draw_circle(Vector2(0.0, -height - 8.0) + Vector2(cos(a), sin(a) * 0.4) * r * 0.9, 3.5, Color(1.0, 0.9, 0.3))
	# Facing marker on top of the body.
	var top := Vector2(0.0, -height)
	var tip := top + Iso.to_screen(facing) * r * 0.8
	draw_line(top, tip, Color(1, 1, 1), 3.0)
	draw_circle(tip, 3.0, Color(1, 1, 1))
	_draw_weapon(height * 0.55, attacking)
	if cue_left > 0.0:
		var cue_pos := Vector2(-80.0, -height - 28.0)
		draw_string(ThemeDB.fallback_font, cue_pos + Vector2(1.0, 2.0), cue_text,
				HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26, Color(0.0, 0.0, 0.0, 0.95))
		draw_string(ThemeDB.fallback_font, cue_pos, cue_text,
				HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26, cue_color)


## Screen-space centre of the shield: raised in front of the body, or carried at its left side.
func _shield_offset(height: float) -> Vector2:
	var mid := Vector2(0.0, -height * 0.5)
	if state == State.BLOCK:
		return mid + Iso.to_screen(facing) * radius * 1.6
	return mid + Iso.to_screen(facing.rotated(-PI * 0.5)) * radius * 1.0


func _draw_shield(center: Vector2, raised: bool) -> void:
	var k := 1.0 if raised else 0.8
	var w := radius * 1.15 * k
	var h := radius * 1.5 * k
	var body := PackedVector2Array([
		center + Vector2(-w, -h), center + Vector2(w, -h), center + Vector2(w, h * 0.1),
		center + Vector2(0.0, h * 1.1), center + Vector2(-w, h * 0.1)])
	var face := Color(0.62, 0.68, 0.8)
	if parry_flash > 0.0:
		face = Color(1.0, 0.85, 0.3)
	elif block_flash > 0.0:
		face = Color(1, 1, 1)
	draw_colored_polygon(body, face)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.15, 0.18, 0.3), 2.5)
	draw_circle(center + Vector2(0.0, -h * 0.1), w * 0.3, Color(0.35, 0.4, 0.55))


func _draw_weapon(anchor_height: float, attacking: bool) -> void:
	if state == State.BLOCK and not has_shield:
		# Bare guard: the weapon is held across the body.
		var c := Vector2(0.0, -anchor_height) + Iso.to_screen(facing) * radius * 1.0
		var half := Iso.to_screen(facing.rotated(PI * 0.5)).normalized() * (radius + weapon.length) * 0.55
		draw_line(c - half, c + half, weapon.color, weapon.thickness + 1.0)
		return
	var base := facing.angle()
	var ang := base + 0.6
	var length := radius + weapon.length
	var width := weapon.thickness
	if attacking:
		var half := deg_to_rad(cur_attack.arc) * 0.5
		ang = base
		match state:
			State.WINDUP:
				ang = base - half
			State.ACTIVE:
				ang = base + lerpf(-half, half, clampf(state_time / cur_attack.active, 0.0, 1.0))
			State.RECOVER:
				ang = base + half
		if cur_attack.heavy:
			length += 8.0
			width += 2.0
	var angles: Array = [ang - 0.35, ang + 0.35] if weapon.dual else [ang]
	var anchor := Vector2(0.0, -anchor_height)
	for blade_angle in angles:
		var dir := Vector2.from_angle(blade_angle)
		draw_line(anchor + Iso.to_screen(dir) * radius * 0.6, anchor + Iso.to_screen(dir) * length,
				weapon.color, width)
