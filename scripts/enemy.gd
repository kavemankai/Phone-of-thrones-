class_name Enemy
extends Node2D
## A melee enemy. States: approach, position (hover and wait), wind-up, active strike,
## recover, dead. It stands still from wind-up through recovery, and commits to an attack
## only after the EncounterController grants it a slot.

enum State { APPROACH, POSITION, WINDUP, ACTIVE, RECOVER, DEAD }

signal damaged(knocked_back: bool)
signal struck
signal died

const BODY_COLOR := Color(0.88, 0.2, 0.2)

var tuning: Tuning
var controller: EncounterController
var hero: Hero
var arena_size := Vector2(420, 480)
var index := 0
var radius := 16.0

var state: State = State.APPROACH
var state_time := 0.0
var hp := 30.0
var facing := Vector2.DOWN
var attack_dir := Vector2.DOWN
var locked := false
var hit_done := false
var cooldown := 0.0
var strafe_sign := 1.0
var flash := 0.0
var fade := 0.0


func setup(t: Tuning, ctrl: EncounterController, h: Hero, arena: Vector2, idx: int) -> void:
	tuning = t
	controller = ctrl
	hero = h
	arena_size = arena
	index = idx
	radius = t.enemy_radius
	hp = t.enemy_max_hp
	cooldown = t.enemy_stagger * idx
	strafe_sign = 1.0 if idx % 2 == 0 else -1.0
	state = State.APPROACH
	fade = 0.0
	visible = true


func is_dead() -> bool:
	return state == State.DEAD


## Wind-up, strike and recovery: the enemy holds its ground and cannot be shoved by others.
func is_committed() -> bool:
	return state == State.WINDUP or state == State.ACTIVE or state == State.RECOVER


func take_hit(damage: float, from: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	hp -= damage
	flash = 0.12
	if knockback > 0.0:
		var away := position - from
		var dir := away.normalized() if away.length() > 0.001 else Vector2.DOWN
		position = clamp_to_arena(position + dir * knockback)
	if hp <= 0.0:
		hp = 0.0
		state = State.DEAD
		state_time = 0.0
		fade = 0.6
		controller.release(self)
		died.emit()
	else:
		damaged.emit(knockback > 0.0)


func clamp_to_arena(p: Vector2) -> Vector2:
	return p.clamp(Vector2(radius, radius), arena_size - Vector2(radius, radius))


func step(dt: float) -> void:
	if state == State.DEAD:
		return
	cooldown = maxf(0.0, cooldown - dt)
	state_time += dt
	match state:
		State.APPROACH, State.POSITION:
			_step_free(dt)
		State.WINDUP:
			_step_windup()
		State.ACTIVE:
			_try_hit()
			if state_time >= tuning.enemy_active:
				_enter(State.RECOVER)
		State.RECOVER:
			if state_time >= tuning.enemy_recover:
				controller.release(self)
				cooldown = tuning.enemy_attack_gap
				_enter(State.POSITION)


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


func _dir_to_hero() -> Vector2:
	var d := hero.position - position
	return d.normalized() if d.length() > 0.001 else facing


func _step_free(dt: float) -> void:
	if hero.is_dead():
		return
	var to_hero := hero.position - position
	var dist := to_hero.length()
	var dir := _dir_to_hero()
	facing = dir
	var wants_in := cooldown <= 0.0 and controller.has_slot(self)
	if wants_in and dist <= tuning.enemy_engage_range and controller.try_commit(self):
		locked = false
		hit_done = false
		attack_dir = facing
		_enter(State.WINDUP)
		return
	var hover := tuning.enemy_hover_range
	if wants_in or dist > hover + 6.0:
		state = State.APPROACH
		_move(dir, 1.0, dt)
	elif dist < hover - 10.0:
		state = State.POSITION
		_move(-dir, 0.6, dt)
	else:
		state = State.POSITION
		_move(dir.orthogonal() * strafe_sign, tuning.enemy_strafe_mult, dt)


func _move(dir: Vector2, mult: float, dt: float) -> void:
	position = clamp_to_arena(position + dir * tuning.enemy_speed * mult * dt)


func _step_windup() -> void:
	var lock_at := tuning.enemy_windup - tuning.enemy_lock_time
	if state_time < lock_at:
		if not hero.is_dead():
			facing = _dir_to_hero()
		attack_dir = facing
	elif not locked:
		locked = true
		attack_dir = facing
	if state_time >= tuning.enemy_windup:
		_enter(State.ACTIVE)
		struck.emit()
		_try_hit()


func _try_hit() -> void:
	if hit_done:
		return
	if HitShapes.circle_in_sector(position, attack_dir, tuning.enemy_reach,
			tuning.enemy_arc_deg, hero.position, hero.radius):
		if hero.take_hit(tuning.enemy_damage):
			hit_done = true


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	if state == State.DEAD:
		fade = maxf(0.0, fade - delta)
		modulate.a = fade / 0.6
		if fade <= 0.0:
			visible = false
	queue_redraw()


func _draw() -> void:
	if tuning == null:
		return
	if state == State.DEAD:
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.35, 0.38))
		return
	if state == State.WINDUP or state == State.ACTIVE:
		_draw_telegraph()
	var body := Color(1, 1, 1) if flash > 0.0 else BODY_COLOR
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.3, 0.02, 0.02), 2.0)
	# Facing marker and weapon.
	var f := attack_dir if (state == State.WINDUP or state == State.ACTIVE) else facing
	draw_line(f * radius * 0.2, f * (radius + 5.0), Color(1, 1, 1), 3.0)
	_draw_weapon(f)
	# Health bar.
	var w := 36.0
	var top := Vector2(-w * 0.5, -radius - 14.0)
	draw_rect(Rect2(top, Vector2(w, 5.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * hp / tuning.enemy_max_hp, 5.0)), Color(0.9, 0.25, 0.25))


func _draw_telegraph() -> void:
	var poly := HitShapes.sector_polygon(attack_dir, tuning.enemy_reach, tuning.enemy_arc_deg)
	var outline := poly.duplicate()
	outline.append(poly[0])
	if state == State.ACTIVE:
		draw_colored_polygon(poly, Color(1.0, 0.95, 0.9, 0.85))
		draw_polyline(outline, Color(1, 0.2, 0.1), 3.0)
		return
	var p := clampf(state_time / tuning.enemy_windup, 0.0, 1.0)
	if locked:
		# Direction is fixed: solid red, step away to avoid it.
		draw_colored_polygon(poly, Color(1.0, 0.1, 0.05, 0.35 + 0.3 * p))
		draw_polyline(outline, Color(1.0, 0.25, 0.1, 0.95), 3.0)
	else:
		draw_colored_polygon(poly, Color(1.0, 0.65, 0.2, 0.12 + 0.18 * p))
		draw_polyline(outline, Color(1.0, 0.7, 0.3, 0.6), 2.0)


func _draw_weapon(f: Vector2) -> void:
	var half := deg_to_rad(tuning.enemy_arc_deg) * 0.5
	var base := f.angle()
	var ang := base + 0.8
	match state:
		State.WINDUP:
			ang = base - half * clampf(state_time / tuning.enemy_windup, 0.0, 1.0)
		State.ACTIVE:
			ang = base + lerpf(-half, half, clampf(state_time / tuning.enemy_active, 0.0, 1.0))
		State.RECOVER:
			ang = base + half
	draw_line(Vector2.from_angle(ang) * radius * 0.6, Vector2.from_angle(ang) * (radius + 20.0),
			Color(0.95, 0.85, 0.85), 4.0)
