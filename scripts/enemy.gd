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
signal phase_changed

## How long an enemy reels when it enters its second phase.
const PHASE_REEL_TIME := 1.2

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
var orbit_time := 0.0
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
## Movement speed multiplier from a nearby War Herald. Game sets it every step.
var speed_buff := 1.0
## 1, or 2 once a two-phase enemy has passed its threshold.
var phase := 1
var guard_flash := 0.0
## Presentation state. Tracks real ground displacement rather than movement intent.
var _visual_time := 0.0
var _visual_initialized := false
var _visual_previous_position := Vector2.ZERO
var _walk_phase := 0.0
var _walk_blend := 0.0


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
	speed_buff = 1.0
	phase = 1
	state = State.APPROACH
	fade = 0.0
	_visual_time = 0.0
	_visual_initialized = false
	_walk_phase = 0.0
	_walk_blend = 0.0
	visible = true


func is_dead() -> bool:
	return state == State.DEAD


func is_captain() -> bool:
	return profile != null and (profile.id == "captain" or profile.id == "crown_tyrant")


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
	if shield_faces(from):
		damage *= profile.front_guard_mult
		knockback = 0.0
		stagger_time = 0.0
		guard_flash = 0.15
	hp -= damage
	flash = 0.12
	if knockback > 0.0:
		var away := position - from
		var dir := away.normalized() if away.length() > 0.001 else Vector2.DOWN
		position = clamp_to_arena(position + dir * knockback)
	if hp <= 0.0:
		_die()
	elif _enter_second_phase():
		damaged.emit(false)
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
	else:
		_enter_second_phase()


## True when a hit from `from` lands on a raised front shield. The shield is down while
## the enemy recovers from its own attack or is staggered: that is the opening.
func shield_faces(from: Vector2) -> bool:
	if profile.front_guard_arc <= 0.0 or state == State.RECOVER or state == State.STAGGER \
			or state == State.DEAD:
		return false
	var toward := from - position
	if toward.length() < 0.001:
		return true
	return absf(facing.angle_to(toward)) <= deg_to_rad(profile.front_guard_arc) * 0.5


## Crossing the phase threshold: reel briefly (hits do not end it and get no bonus), then
## fight with the second pattern. The profile is copied first, so the shared one is not edited.
func _enter_second_phase() -> bool:
	if phase != 1 or profile.phase2_at <= 0.0 or hp > profile.max_hp * profile.phase2_at:
		return false
	phase = 2
	var second := profile.duplicate() as EnemyProfile
	if not second.phase2_pattern.is_empty():
		second.pattern = second.phase2_pattern
	second.speed *= second.phase2_speed_mult
	profile = second
	pattern_pos = 0
	stagger(PHASE_REEL_TIME, false, 1.0)
	phase_changed.emit()
	return true


func clamp_to_arena(p: Vector2) -> Vector2:
	return ArenaSpace.move(position, p, radius, arena_size, hero.arena_cover)


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
	orbit_time = 0.0
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
	var wants_in := cooldown <= 0.0 and controller.has_slot(self) and not profile.passive
	if ArenaSpace.blocked(position, hero.position, hero.arena_cover):
		state = State.APPROACH
		orbit_time = 0.0
		_move(ArenaSpace.approach(position, _route_goal(), radius, hero.nav()), 1.0, dt)
		return
	if profile.orbit_before_attack > 0.0:
		if dist > next.max_range + 14.0:
			orbit_time = 0.0
		elif orbit_time < profile.orbit_before_attack:
			state = State.POSITION
			orbit_time += dt
			var inward := clampf((dist - profile.hover_range) * 0.05, -0.7, 0.7)
			var orbit := dir.orthogonal() * strafe_sign + dir * inward
			var old := position
			_move(orbit.normalized(), 0.62, dt)
			if old.distance_squared_to(position) < 0.01:
				strafe_sign *= -1.0
			return
	if wants_in and dist >= next.min_range and dist <= next.max_range \
			and controller.try_commit(self):
		pattern_pos = next_pos + 1
		_begin_attack(next)
		return
	var hover := profile.hover_range
	if next.min_range > 0.0 and dist < next.min_range:
		state = State.POSITION
		_move(-dir, 0.75, dt)
		return
	if wants_in or dist > hover + 6.0:
		state = State.APPROACH
		_move(ArenaSpace.approach(position, hero.position, radius, hero.nav()), 1.0, dt)
	elif dist < hover - 10.0:
		state = State.POSITION
		_move(-dir, 0.6, dt)
	else:
		state = State.POSITION
		_move(dir.orthogonal() * strafe_sign, tuning.enemy_strafe_mult, dt)


## Where to walk when the hero is out of sight. Normally the hero. On a map of rooms in a
## column, an open gate that lies between us (along y) comes first, until we stand in it.
func _route_goal() -> Vector2:
	var best := hero.position
	var nearest := INF
	for gate in hero.nav_waypoints:
		if (gate.y - position.y) * (gate.y - hero.position.y) >= 0.0:
			continue
		var away := position.distance_to(gate)
		if away < nearest and away > radius * 0.75:
			nearest = away
			best = gate
	return best


func _move(dir: Vector2, mult: float, dt: float) -> void:
	position = clamp_to_arena(position + dir * profile.speed * speed_buff * mult * dt)


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
	if ArenaSpace.blocked(attack_origin, hero.position, hero.arena_cover):
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
	_visual_time += delta
	if not _visual_initialized:
		_visual_previous_position = position
		_visual_initialized = true
	# Uses measured travel, so a blocked enemy never walks in place. The clamp ignores
	# large hit knockbacks and respawn jumps for purposes of the walk cycle.
	var travel := minf(position.distance_to(_visual_previous_position), radius)
	_visual_previous_position = position
	var moving := 0.0
	if state in [State.APPROACH, State.POSITION]:
		moving = clampf(travel / maxf(130.0 * delta, 0.001), 0.0, 1.0)
	_walk_blend = move_toward(_walk_blend, moving, delta * 9.0)
	_walk_phase = fposmod(_walk_phase + travel * 0.22, TAU)
	flash = maxf(0.0, flash - delta)
	guard_flash = maxf(0.0, guard_flash - delta)
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
	var texture: Texture2D = ForgeArt.ACTORS.get(profile.id, ForgeArt.ACTORS.penitent)
	var height := radius * (2.4 if profile.id == "hound" else 3.5)
	if state == State.DEAD:
		draw_set_transform_matrix(Iso.upright())
		ForgeArt.actor(self, texture, height, Vector2.RIGHT, Color(0.56, 0.49, 0.46),
				Vector2(-height * 0.35, 0.0), PI * 0.46)
		return
	# Ground pass (projected by the iso layer): shadow and the attack wedge, which is the
	# exact sector the damage test uses.
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0, 0, 0, 0.3))
	# Team/elite silhouette: no ambiguity when sprites and telegraphs overlap.
	var ring_color := Color(1.0, 0.77, 0.22, 0.95) if is_captain() else Color(0.95, 0.25, 0.23, 0.72)
	if profile.elite:
		# Veteran: a second, pale ring outside the red one.
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.7, 0.9), 2.5)
	draw_arc(Vector2.ZERO, radius + (10.0 if is_captain() else 5.0),
			0.0, TAU, 40, ring_color, 3.0 if is_captain() else 2.0)
	if state == State.WINDUP or state == State.ACTIVE:
		_draw_telegraph()
	if profile.front_guard_arc > 0.0:
		# The shield arc on the ground: bright while it is up, gone while it is down.
		var shield_up := state != State.RECOVER and state != State.STAGGER
		if shield_up:
			var half_arc := deg_to_rad(profile.front_guard_arc) * 0.5
			var mid := facing.angle()
			var tint := Color(1, 1, 1) if guard_flash > 0.0 else Color(0.70, 0.80, 0.95, 0.9)
			draw_arc(Vector2.ZERO, radius + 9.0, mid - half_arc, mid + half_arc, 18, tint, 5.0)
	if profile.aura_range > 0.0:
		# The Herald's reach: enemies inside this ring are faster.
		draw_circle(Vector2.ZERO, profile.aura_range, Color(profile.color, 0.05))
		draw_arc(Vector2.ZERO, profile.aura_range, 0.0, TAU, 64, Color(profile.color, 0.22), 1.5)
	if speed_buff > 1.0:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.85), 2.0)

	# Upright pass.
	draw_set_transform_matrix(Iso.upright())
	var f := attack_dir if state in [State.WINDUP, State.ACTIVE] else facing
	var screen_facing := Iso.to_screen(f).normalized()
	var tint := Color.WHITE if phase == 1 else Color(1.18, 0.85, 0.67)
	if flash > 0.0:
		tint = Color(1.6, 1.45, 1.35)
	var lean := 0.0
	if state == State.WINDUP:
		lean = -0.16 * screen_facing.x * clampf(state_time / cur.windup, 0.0, 1.0)
	elif state == State.ACTIVE:
		lean = 0.23 * screen_facing.x
	if flash > 0.0:
		# Struck: rock back, away from where it is facing.
		lean -= 0.20 * screen_facing.x * clampf(flash / 0.12, 0.0, 1.0)
	var stride := sin(_walk_phase) * _walk_blend * (2.0 if profile.id == "hound" else 3.0)
	var stretch := 1.0 + 0.035 * cos(_walk_phase * 2.0) * _walk_blend
	# Anticipation, strike and recoil are tied to the exact combat state/timer.
	if state == State.WINDUP:
		var anticipation := clampf(state_time / maxf(cur.windup, 0.01), 0.0, 1.0)
		stretch = 1.0 - 0.07 * anticipation
	elif state == State.ACTIVE:
		var follow_through := clampf(state_time / maxf(cur.active, 0.01), 0.0, 1.0)
		stretch = 1.0 + 0.07 * sin(follow_through * PI)
	elif state == State.STAGGER:
		stretch = 0.90 + 0.025 * sin(_visual_time * 11.0)
	elif state == State.RECOVER:
		var release := clampf(state_time / maxf(cur.recover, 0.01), 0.0, 1.0)
		stretch = 1.0 - 0.035 * (1.0 - release)
	ForgeArt.actor(self, texture, height, screen_facing, tint,
			Vector2(0.0, -stride), lean, stretch)
	if state == State.STAGGER:
		# Dazed: stars circling the head.
		var t := Time.get_ticks_msec() * 0.008
		for i in 3:
			var a := t + i * TAU / 3.0
			draw_circle(Vector2(0.0, -height - 8.0) + Vector2(cos(a), sin(a) * 0.4) * radius * 0.9, 3.5, Color(1.0, 0.9, 0.3))
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
