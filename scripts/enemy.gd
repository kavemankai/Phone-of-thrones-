class_name Enemy
extends Node2D
## A melee enemy. States: approach, position (hover and wait), wind-up, active strike,
## recover, dead. It stands still from wind-up through recovery (a lunge slides it during
## the strike), and commits to an attack only after the EncounterController grants a slot.
## What it can do comes from its EnemyProfile: the grunt has one strike, the captain has a
## pattern of slash, combo and lunge.

enum State { APPROACH, POSITION, WINDUP, ACTIVE, RECOVER, DEAD, STAGGER }

signal damaged(knocked_back: bool)
signal struck
signal died

var tuning: Tuning
var profile: EnemyProfile
var controller: EncounterController
var hero: Hero
var arena_size := Vector2(340, 380)
var index := 0
var radius := 16.0

var state: State = State.APPROACH
var state_time := 0.0
var hp := 30.0
var facing := Vector2.DOWN
var attack_dir := Vector2.DOWN
## The attack being wound up, struck or recovered from.
var cur: AttackDef
## Where the current attack started. The hit area is the wedge from here, even while a
## lunge slides the enemy forward.
var attack_origin := Vector2.ZERO
var pattern_pos := 0
var locked := false
var hit_done := false
var cooldown := 0.0
var strafe_sign := 1.0
var flash := 0.0
var fade := 0.0
## Stagger: seconds left and the length it started with (for the timer), and the short
## window after one ends in which a heavy hit cannot stagger it again.
var stagger_left := 0.0
var stagger_total := 0.0
## Whether a hit ends the current stagger early (parry and heavy freezes) or not (a block
## recoil), and the damage multiplier for the hit that ends it.
var stagger_wakes := true
var stagger_bonus := 2.0
var stagger_immune := 0.0


func setup(t: Tuning, ctrl: EncounterController, h: Hero, arena: Vector2, idx: int,
		prof: EnemyProfile = null) -> void:
	tuning = t
	controller = ctrl
	hero = h
	arena_size = arena
	index = idx
	profile = prof if prof != null else EnemyProfile.grunt_from(t)
	radius = profile.radius
	hp = profile.max_hp
	cur = profile.attacks[0]
	pattern_pos = 0
	cooldown = t.enemy_stagger * idx
	strafe_sign = 1.0 if idx % 2 == 0 else -1.0
	state = State.APPROACH
	fade = 0.0
	visible = true


func is_dead() -> bool:
	return state == State.DEAD


func is_captain() -> bool:
	return profile != null and profile.id == "captain"


## Cancels whatever the enemy was doing and freezes it for `duration` seconds. A hit on it
## ends the stagger early. Every cause goes through here, so every stagger gets the timer.
func stagger(duration := 3.0, wake_on_hit := true, damage_mult := -1.0) -> void:
	if state == State.DEAD:
		return
	stagger_wakes = wake_on_hit
	stagger_bonus = damage_mult if damage_mult >= 0.0 else tuning.stagger_damage_mult
	stagger_total = duration
	stagger_left = stagger_total
	controller.release(self)
	hit_done = true
	locked = false
	_enter(State.STAGGER)


func _wake() -> void:
	stagger_left = 0.0
	stagger_immune = tuning.stagger_immunity
	cooldown = tuning.enemy_attack_gap
	_enter(State.POSITION)


func is_staggered() -> bool:
	return state == State.STAGGER


## Wind-up, strike and recovery: the attack slot is held.
func is_committed() -> bool:
	return state == State.WINDUP or state == State.ACTIVE or state == State.RECOVER


## Committed or frozen: the enemy holds its ground and other bodies cannot shove it.
func is_immovable() -> bool:
	return is_committed() or state == State.STAGGER


## stagger_time > 0 (a heavy hit) staggers the enemy unless it only just woke up; any hit on a
## staggered enemy does extra damage and wakes it.
func take_hit(damage: float, from: Vector2, knockback: float, stagger_time := 0.0) -> void:
	if state == State.DEAD:
		return
	var was_staggered := state == State.STAGGER
	if was_staggered:
		damage *= stagger_bonus
	hp -= damage
	flash = 0.12
	if knockback > 0.0:
		var away := position - from
		var dir := away.normalized() if away.length() > 0.001 else Vector2.DOWN
		position = clamp_to_arena(position + dir * knockback)
	if hp <= 0.0:
		_die()
	else:
		if was_staggered:
			if stagger_wakes:
				_wake()
		elif stagger_time > 0.0 and stagger_immune <= 0.0 and profile.heavy_stagger_mult > 0.0:
			stagger(stagger_time * profile.heavy_stagger_mult)
		damaged.emit(knockback > 0.0)


func _die() -> void:
	hp = 0.0
	state = State.DEAD
	state_time = 0.0
	fade = 0.6
	controller.release(self)
	died.emit()


## A parry with an executing weapon: takes a share of max HP (all of it for a grunt).
func _execute() -> void:
	hp -= profile.max_hp * profile.execute_fraction
	flash = 0.12
	if hp <= 0.0:
		_die()


func clamp_to_arena(p: Vector2) -> Vector2:
	return p.clamp(Vector2(radius, radius), arena_size - Vector2(radius, radius))


func step(dt: float) -> void:
	if state == State.DEAD:
		return
	cooldown = maxf(0.0, cooldown - dt)
	stagger_immune = maxf(0.0, stagger_immune - dt)
	state_time += dt
	match state:
		State.APPROACH, State.POSITION:
			_step_free(dt)
		State.WINDUP:
			_step_windup()
		State.ACTIVE:
			_try_hit()
			_slide(dt)
			if state_time >= cur.active:
				_enter(State.RECOVER)
		State.STAGGER:
			stagger_left -= dt
			if stagger_left <= 0.0:
				_wake()
		State.RECOVER:
			if state_time >= cur.recover:
				if cur.chain_to >= 0:
					# Combo: straight into the next telegraphed attack, same commitment.
					if not hero.is_dead():
						facing = _dir_to_hero()
					_begin_attack(profile.attacks[cur.chain_to])
				else:
					controller.release(self)
					cooldown = tuning.enemy_attack_gap
					_enter(State.POSITION)


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


func _dir_to_hero() -> Vector2:
	var d := hero.position - position
	return d.normalized() if d.length() > 0.001 else facing


func _begin_attack(atk: AttackDef) -> void:
	cur = atk
	locked = false
	hit_done = false
	attack_dir = facing
	attack_origin = position
	_enter(State.WINDUP)


func _step_free(dt: float) -> void:
	if hero.is_dead():
		return
	var to_hero := hero.position - position
	var dist := to_hero.length()
	var dir := _dir_to_hero()
	facing = dir
	var next_pos := profile.choose(dist, pattern_pos)
	var next := profile.attack_at(next_pos)
	var wants_in := cooldown <= 0.0 and controller.has_slot(self)
	if wants_in and dist >= next.min_range and dist <= next.max_range \
			and controller.try_commit(self):
		pattern_pos = next_pos + 1
		_begin_attack(next)
		return
	var hover := profile.hover_range
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
	position = clamp_to_arena(position + dir * profile.speed * mult * dt)


func _step_windup() -> void:
	var lock_at := cur.windup - cur.lock_time
	if state_time < lock_at:
		if not hero.is_dead():
			facing = _dir_to_hero()
		attack_dir = facing
	elif not locked:
		locked = true
		attack_dir = facing
	if state_time >= cur.windup:
		_enter(State.ACTIVE)
		attack_origin = position
		struck.emit()
		_try_hit()


func _slide(dt: float) -> void:
	if cur.lunge > 0.0:
		position = clamp_to_arena(position + attack_dir * (cur.lunge / cur.active) * dt)


func _try_hit() -> void:
	if hit_done:
		return
	if HitShapes.circle_in_sector(attack_origin, attack_dir, cur.reach, cur.arc_deg,
			hero.position, hero.radius):
		var result := hero.receive_attack(cur.damage, attack_origin, cur)
		if result == Hero.HitResult.NONE:
			return  # dodge i-frames or immunity: the strike may still connect next step
		hit_done = true
		if result == Hero.HitResult.PARRIED:
			stagger(hero.parry_stagger_time() * profile.stagger_mult)
			if hero.weapon.parry_kill:
				_execute()
		elif result == Hero.HitResult.BLOCKED and cur.block_stun and hero.state == Hero.State.BLOCK:
			# A block recoils the attacker for a fixed time; hits do not end it and get no bonus.
			stagger(hero.block_stun_time() * profile.stagger_mult, false, 1.0)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	z_index = int(position.x + position.y)  # isometric depth order
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
	# Ground pass (projected by the iso layer): shadow and the attack wedge, which is the
	# exact sector the damage test uses.
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0, 0, 0, 0.3))
	# Team/elite silhouette: no ambiguity when sprites and telegraphs overlap.
	var ring_color := Color(1.0, 0.77, 0.22, 0.95) if is_captain() else Color(0.95, 0.25, 0.23, 0.72)
	draw_arc(Vector2.ZERO, radius + (10.0 if is_captain() else 5.0),
			0.0, TAU, 40, ring_color, 3.0 if is_captain() else 2.0)
	if state == State.WINDUP or state == State.ACTIVE:
		_draw_telegraph()

	# Upright pass.
	draw_set_transform_matrix(Iso.upright())
	var height := radius * 2.0
	var side := Color(1, 1, 1) if flash > 0.0 else profile.color
	Iso.draw_cylinder(self, radius, height, side, profile.color.darkened(0.7))
	if state == State.STAGGER:
		# Dazed: stars circling the head.
		var t := Time.get_ticks_msec() * 0.008
		for i in 3:
			var a := t + i * TAU / 3.0
			draw_circle(Vector2(0.0, -height - 8.0) + Vector2(cos(a), sin(a) * 0.4) * radius * 0.9, 3.5, Color(1.0, 0.9, 0.3))
	if profile.cap_color.a > 0.0:
		var rx := radius * Iso.RX * 0.7
		var ry := radius * Iso.RY * 0.7
		draw_colored_polygon(Iso.ellipse(Vector2(0.0, -height), rx, ry), profile.cap_color)
	var f := attack_dir if (state == State.WINDUP or state == State.ACTIVE) else facing
	var top := Vector2(0.0, -height)
	var tip := top + Iso.to_screen(f) * radius * 0.8
	draw_line(top, tip, Color(1, 1, 1), 3.0)
	draw_circle(tip, 3.0, Color(1, 1, 1))
	_draw_weapon(f, height * 0.55)
	if is_captain():
		draw_string(ThemeDB.fallback_font, Vector2(-65.0, -height - 51.0), "CAPTAIN",
				HORIZONTAL_ALIGNMENT_CENTER, 130.0, 21, Color(1.0, 0.85, 0.3))
	# Health bar above the head.
	var w := profile.bar_width
	var bar := Vector2(-w * 0.5, -height - 16.0)
	draw_rect(Rect2(bar, Vector2(w, 5.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar, Vector2(w * clampf(hp / profile.max_hp, 0.0, 1.0), 5.0)), Color(0.9, 0.25, 0.25))
	if state == State.STAGGER:
		# Stagger timer: a bar and the seconds left, whatever caused the stagger.
		var tb := Vector2(-w * 0.5, -height - 30.0)
		var frac := clampf(stagger_left / maxf(stagger_total, 0.001), 0.0, 1.0)
		draw_rect(Rect2(tb, Vector2(w, 6.0)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(tb, Vector2(w * frac, 6.0)), Color(1.0, 0.85, 0.25))
		draw_string(ThemeDB.fallback_font, tb + Vector2(0.0, -3.0), "%.1f" % maxf(stagger_left, 0.0),
				HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color.WHITE)


func _wedge_polygon() -> PackedVector2Array:
	var poly := HitShapes.sector_polygon(attack_dir, cur.reach, cur.arc_deg)
	if state == State.ACTIVE:
		# The wedge stays where the attack started even if the enemy lunges out of it.
		var offset := attack_origin - position
		for i in poly.size():
			poly[i] += offset
	return poly


func _draw_telegraph() -> void:
	var poly := _wedge_polygon()
	var outline := poly.duplicate()
	outline.append(poly[0])
	if state == State.ACTIVE:
		draw_colored_polygon(poly, Color(1.0, 0.95, 0.9, 0.85))
		draw_polyline(outline, Color(1, 0.2, 0.1), 4.0)
		return
	var p := clampf(state_time / cur.windup, 0.0, 1.0)
	if locked:
		# Direction is fixed: solid red, step away to avoid it.
		draw_colored_polygon(poly, Color(1.0, 0.1, 0.05, 0.35 + 0.3 * p))
		draw_polyline(outline, Color(1.0, 0.25, 0.1, 0.95), 4.0)
	else:
		draw_colored_polygon(poly, Color(1.0, 0.65, 0.2, 0.12 + 0.18 * p))
		draw_polyline(outline, Color(1.0, 0.7, 0.3, 0.6), 2.0)


func _draw_weapon(f: Vector2, anchor_height: float) -> void:
	var half := deg_to_rad(cur.arc_deg) * 0.5
	var base := f.angle()
	var ang := base + 0.8
	match state:
		State.WINDUP:
			ang = base - half * clampf(state_time / cur.windup, 0.0, 1.0)
		State.ACTIVE:
			ang = base + lerpf(-half, half, clampf(state_time / cur.active, 0.0, 1.0))
		State.RECOVER:
			ang = base + half
	var dir := Vector2.from_angle(ang)
	var anchor := Vector2(0.0, -anchor_height)
	draw_line(anchor + Iso.to_screen(dir) * radius * 0.6, anchor + Iso.to_screen(dir) * (radius + 20.0),
			Color(0.95, 0.85, 0.85), 4.0)
