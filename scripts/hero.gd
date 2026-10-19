class_name Hero
extends Node2D
## The player character. All gameplay runs in step(dt, enemies); _process only animates.
## Positions are in arena space: (0,0) is the arena's top-left corner.

enum State { IDLE, CHARGING, WINDUP, ACTIVE, RECOVER, DODGE, HURT, DEAD }

signal swung(heavy: bool)
signal dodged
signal damaged
signal died
signal hit_landed(enemy: Enemy, heavy: bool)

const EPS := 0.000001
const BODY_COLOR := Color(0.25, 0.55, 1.0)
const FLASH_COLOR := Color(1, 1, 1)

var tuning: Tuning
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

var _enemies: Array = []


func setup(t: Tuning, inp: CombatInput, arena: Vector2) -> void:
	tuning = t
	input = inp
	arena_size = arena
	radius = t.hero_radius
	reset(t.hero_spawn())


func reset(pos: Vector2) -> void:
	position = pos
	state = State.IDLE
	state_time = 0.0
	hp = tuning.hero_max_hp
	facing = Vector2.UP
	charge_time = 0.0
	immune_time = 0.0
	dodge_charges = tuning.dodge_max_charges
	dodge_recharge_t = 0.0
	dodge_dir = Vector2.ZERO
	cur_attack = {}
	hit_ids = {}
	flash = 0.0
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
	if dodge_charges >= tuning.dodge_max_charges:
		return 0.0
	return tuning.dodge_recharge - dodge_recharge_t


func step(dt: float, enemies: Array) -> void:
	if state == State.DEAD:
		return
	_enemies = enemies
	immune_time = maxf(0.0, immune_time - dt)
	_recharge_dodge(dt)
	state_time += dt
	match state:
		State.IDLE:
			if input.dodge_pressed and _try_dodge():
				return
			_move(dt, 1.0)
			if input.attack_pressed:
				_enter(State.CHARGING)
				charge_time = 0.0
				_step_charging(0.0)
		State.CHARGING:
			_step_charging(dt)
		State.WINDUP:
			if state_time >= cur_attack.windup:
				_enter(State.ACTIVE)
				hit_ids = {}
				swung.emit(cur_attack.heavy)
				_apply_hits()
		State.ACTIVE:
			_apply_hits()
			if state_time >= cur_attack.active:
				_enter(State.RECOVER)
		State.RECOVER:
			_move(dt, tuning.half_speed_mult)
			if input.dodge_pressed and _try_dodge():
				return
			if state_time >= cur_attack.recover:
				_enter(State.IDLE)
		State.DODGE:
			_step_dodge(dt)
		State.HURT:
			if state_time >= tuning.hurt_duration:
				_enter(State.IDLE)


## Returns true when the hit landed. Dodge i-frames, post-hit immunity and death all refuse it.
func take_hit(damage: float) -> bool:
	if state == State.DEAD or is_invulnerable():
		return false
	hp = maxf(0.0, hp - damage)
	immune_time = tuning.hit_immunity
	flash = 0.15
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


func _step_charging(dt: float) -> void:
	charge_time += dt
	_move(dt, tuning.half_speed_mult)
	if input.dodge_pressed and _try_dodge():
		return
	if input.attack_released:
		_start_attack(charge_time + EPS >= tuning.heavy_hold_time)
	elif not input.attack_down():
		# The finger left the button: cancel without attacking.
		charge_time = 0.0
		_enter(State.IDLE)


func _start_attack(heavy: bool) -> void:
	cur_attack = tuning.attack_data(heavy)
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
			e.take_hit(cur_attack.damage, position, cur_attack.knockback)
			hit_landed.emit(e, cur_attack.heavy)


func _try_dodge() -> bool:
	if dodge_charges <= 0:
		return false
	var v := input.move_vector()
	dodge_dir = v.normalized() if v.length() > 0.2 else -facing
	if dodge_charges >= tuning.dodge_max_charges:
		dodge_recharge_t = 0.0
	dodge_charges -= 1
	charge_time = 0.0
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
	if dodge_charges >= tuning.dodge_max_charges:
		dodge_recharge_t = 0.0
		return
	dodge_recharge_t += dt
	if dodge_recharge_t + EPS >= tuning.dodge_recharge:
		dodge_charges += 1
		dodge_recharge_t = maxf(0.0, dodge_recharge_t - tuning.dodge_recharge)


func _move(dt: float, mult: float) -> void:
	var v := input.move_vector()
	if v.length() > 0.001:
		position += v * tuning.hero_speed * mult * dt
		facing = v.normalized()
		position = _clamp_to_arena(position)


func _clamp_to_arena(p: Vector2) -> Vector2:
	return p.clamp(Vector2(radius, radius), arena_size - Vector2(radius, radius))


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
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
	Iso.draw_cylinder(self, r, height, side, Color(0.05, 0.1, 0.25))
	# Facing marker on top of the body.
	var top := Vector2(0.0, -height)
	var tip := top + Iso.to_screen(facing) * r * 0.8
	draw_line(top, tip, Color(1, 1, 1), 3.0)
	draw_circle(tip, 3.0, Color(1, 1, 1))
	_draw_weapon(height * 0.55, attacking)


func _draw_weapon(anchor_height: float, attacking: bool) -> void:
	var base := facing.angle()
	var ang := base + 0.6
	var length := radius + 22.0
	var width := 4.0
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
			length = radius + 30.0
			width = 6.0
	var dir := Vector2.from_angle(ang)
	var anchor := Vector2(0.0, -anchor_height)
	draw_line(anchor + Iso.to_screen(dir) * radius * 0.6, anchor + Iso.to_screen(dir) * length,
			Color(0.9, 0.93, 1.0), width)
