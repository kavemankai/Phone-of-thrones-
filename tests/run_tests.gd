extends SceneTree
## Headless state and timing tests. Run from the project root:
##   godot --headless --path . --script tests/run_tests.gd
## Exit code is the number of failed checks (0 = all passed). These are desktop checks of
## game logic. They say nothing about touch feel or performance on a phone.

var passes := 0
var fails := 0
var T: Tuning


class Rig:
	extends RefCounted
	## A hero (and optionally enemies) without the Game node, stepped by hand.
	var t: Tuning
	var input := CombatInput.new()
	var ctrl := EncounterController.new()
	var hero: Hero
	var enemies: Array = []
	var host: Node
	var run_enemies := false
	var time := 0.0
	var swings := 0
	var heavy_swings := 0
	var hits := 0
	var hurts := 0

	func _init(host_node: Node, tuning: Tuning, hero_pos := Vector2(320, 500)) -> void:
		t = tuning
		host = host_node
		ctrl.configure(t)
		hero = Hero.new()
		host.add_child(hero)
		hero.setup(t, input, t.arena_size)
		hero.position = hero_pos
		hero.swung.connect(func(heavy: bool):
			swings += 1
			if heavy:
				heavy_swings += 1)
		hero.hit_landed.connect(func(_e, _h): hits += 1)
		hero.damaged.connect(func(): hurts += 1)

	func use_weapon(w: Weapon, shield := false) -> void:
		hero.equip(w, shield)
		hero.reset(hero.position)

	func add_enemy(pos: Vector2, idx := 0, prof: EnemyProfile = null) -> Enemy:
		var e := Enemy.new()
		host.add_child(e)
		e.setup(t, ctrl, hero, t.arena_size, idx, prof)
		e.position = pos
		enemies.append(e)
		return e

	func tick(dt: float) -> void:
		time += dt
		if run_enemies:
			for e in enemies:
				e.step(dt)
		hero.step(dt, enemies)
		input.end_step()

	func run(seconds: float, dt := 0.005) -> void:
		var n := int(round(seconds / dt))
		for i in n:
			tick(dt)

	func run_until(target: float, dt := 0.005) -> void:
		while time < target - 0.0000001:
			tick(dt)

	func until_state(s: Hero.State, limit := 3.0, dt := 0.005) -> bool:
		var end := time + limit
		while hero.state != s and time < end:
			tick(dt)
		return hero.state == s

	func free_all() -> void:
		for e in enemies:
			e.free()
		hero.free()


func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", name)
	else:
		fails += 1
		print("  FAIL  ", name, "   ", detail)


func section(title: String) -> void:
	print("\n== ", title)


func _initialize() -> void:
	# Nodes added to the root only get _ready once the tree has run a frame.
	await process_frame
	T = load("res://resources/tuning.tres") as Tuning
	if T == null:
		print("FAIL: cannot load tuning.tres")
		quit(1)
		return
	test_tuning_matches_design()
	# Mechanics tests below use hard-coded coordinates, so give them a roomy test arena.
	# (Game-level tests use the shipping arena size from tuning.tres.)
	T = T.duplicate() as Tuning
	T.arena_size = Vector2(640, 720)
	test_light_heavy_separation()
	test_one_hit_per_swing()
	test_invulnerability_windows()
	test_dodge_charges()
	test_hit_area_matches_telegraph()
	test_action_cancellation()
	test_wall_containment()
	test_enemy_telegraph_and_evasion()
	test_enemy_hits_once_per_attack()
	test_dodge_avoids_strike()
	test_multitouch_and_focus()
	test_touch_drives_hero()
	test_isometric_view()
	test_commitment_limit()
	test_full_fights()
	test_retry_resets_everything()
	test_weapon_and_captain_data()
	test_weapon_mechanics()
	test_all_attack_shapes()
	test_captain_attacks()
	test_captain_flow()
	test_scripted_player_per_weapon()
	test_block_input_and_layout()
	test_guard_rules()
	test_block_arc_and_costs()
	test_guard_break_and_regen()
	test_parry()
	test_stagger_freeze_and_wake()
	test_frozen_not_pushed()
	test_heavy_stagger()
	test_weapon_stagger_lengths()
	test_parry_timing_sweep()
	test_block_stun()
	test_daggers()
	test_movement_ramp()
	test_attack_move()
	test_heavy_hold_and_menu()
	test_captain_vs_guard()
	test_shield_equipment()
	test_blocking_player()
	test_pre_resolution_defense()
	test_control_and_guard_trials()
	print("\n%d passed, %d failed" % [passes, fails])
	quit(fails)


func test_tuning_matches_design() -> void:
	section("Tuning resource matches the design table")
	var ok := true
	var expect := {
		"hero_max_hp": 100.0, "hero_speed": 195.0, "hero_radius": 16.0,
		"light_damage": 10.0, "light_reach": 75.0, "light_arc_deg": 90.0,
		"light_windup": 0.10, "light_active": 0.08, "light_recover": 0.22,
		"heavy_damage": 25.0, "heavy_reach": 95.0, "heavy_arc_deg": 140.0,
		"heavy_windup": 0.15, "heavy_active": 0.10, "heavy_recover": 0.40,
		"heavy_knockback": 35.0, "heavy_hold_time": 0.20,
		"dodge_distance": 90.0, "dodge_duration": 0.30, "dodge_iframes": 0.16,
		"dodge_max_charges": 2, "dodge_recharge": 1.4,
		"enemy_max_hp": 30.0, "enemy_speed": 105.0, "enemy_reach": 48.0, "enemy_damage": 12.0,
		"enemy_windup": 0.65, "enemy_active": 0.10, "enemy_recover": 0.65,
		"enemy_attack_gap": 0.35, "enemy_lock_time": 0.25, "max_commits": 2,
		"hurt_duration": 0.15, "hit_immunity": 0.35, "aim_cone_deg": 90.0,
		"half_speed_mult": 0.5, "captain_heal": 30.0, "captain_intro_time": 2.0,
		"parry_stagger_time": 3.0, "heavy_stagger_time": 1.0, "parry_window_shield": 0.40, "parry_window_bare": 0.32,
		"move_ramp_up": 0.12, "move_ramp_down": 0.08, "block_stun_time": 1.2,
	}
	for k in expect:
		if not is_equal_approx(float(T.get(k)), float(expect[k])):
			ok = false
			print("      mismatch ", k, ": ", T.get(k), " vs ", expect[k])
	check("tuning.tres values equal the Part 2 table", ok)


func attack_for(hold: float) -> Rig:
	var r := Rig.new(root, T)
	r.input.press_attack(false)
	r.tick(0.01)
	for i in int(round(hold / 0.01)):
		r.tick(0.01)
	r.input.release_attack(false)
	r.tick(0.01)
	return r


func test_light_heavy_separation() -> void:
	section("Light and heavy attack separation (hold threshold %.2f s)" % T.heavy_hold_time)
	var tap := attack_for(0.10)
	check("0.10 s hold -> light", tap.hero.state == Hero.State.WINDUP and not tap.hero.cur_attack.heavy)
	tap.free_all()
	var edge_low := attack_for(0.18)
	check("0.19 s total -> still light", not edge_low.hero.cur_attack.heavy)
	edge_low.free_all()
	var edge_high := attack_for(0.20)
	check("0.21 s total -> heavy", edge_high.hero.cur_attack.heavy)
	edge_high.free_all()
	var long_hold := attack_for(0.8)
	check("0.8 s hold -> heavy", long_hold.hero.cur_attack.heavy)
	long_hold.free_all()

	var r := Rig.new(root, T)
	r.input.press_attack(false)
	r.run(0.15, 0.01)
	check("heavy-ready cue is off at 0.15 s", not r.hero.is_heavy_ready())
	r.run(0.07, 0.01)
	check("heavy-ready cue is on at 0.22 s", r.hero.is_heavy_ready())
	r.run(3.0, 0.01)
	check("holding does not repeat or fire attacks", r.swings == 0 and r.hero.state == Hero.State.CHARGING)
	r.input.release_attack(false)
	r.run(1.0)
	check("release fires exactly one heavy", r.swings == 1 and r.heavy_swings == 1)
	check("hero returns to idle", r.hero.state == Hero.State.IDLE)
	r.free_all()

	var c := Rig.new(root, T)
	c.input.press_attack(true)
	c.run(0.2, 0.01)
	c.input.cancel_attack(true)
	c.run(0.5)
	check("sliding off the button cancels the attack (no swing)", c.swings == 0 and c.hero.state == Hero.State.IDLE)
	c.free_all()


func test_one_hit_per_swing() -> void:
	section("Each swing damages a target at most once")
	var r := Rig.new(root, T)
	var e1 := r.add_enemy(Vector2(320, 450))
	var e2 := r.add_enemy(Vector2(345, 455), 1)
	var e3 := r.add_enemy(Vector2(320, 575), 2)
	r.input.press_attack(false)
	r.tick(0.005)
	r.input.release_attack(false)
	r.run(1.0)
	check("both enemies in the arc take exactly one light hit",
			is_equal_approx(e1.hp, 20.0) and is_equal_approx(e2.hp, 20.0), "hp %s %s" % [e1.hp, e2.hp])
	check("enemy behind the hero is untouched", is_equal_approx(e3.hp, 30.0))
	check("hit_landed fired once per target", r.hits == 2, "hits=%d" % r.hits)
	r.free_all()

	var h := Rig.new(root, T)
	var t1 := h.add_enemy(Vector2(320, 450))
	h.input.press_attack(false)
	h.run(0.4, 0.01)
	h.input.release_attack(false)
	h.run(1.0)
	check("heavy deals 25 once", is_equal_approx(t1.hp, 5.0), "hp=%s" % t1.hp)
	check("heavy pushes the enemy 35 px, once", is_equal_approx(t1.position.y, 415.0), "y=%s" % t1.position.y)
	h.free_all()


func test_invulnerability_windows() -> void:
	section("Dodge i-frames (%.2f s) and post-hit immunity (%.2f s)" % [T.dodge_iframes, T.hit_immunity])
	var a := Rig.new(root, T)
	a.input.press_dodge()
	a.tick(0.001)
	a.run(0.158, 0.001)
	check("hit at 0.158 s into the dodge is ignored", not a.hero.take_hit(12.0) and is_equal_approx(a.hero.hp, 100.0))
	a.free_all()
	var b := Rig.new(root, T)
	b.input.press_dodge()
	b.tick(0.001)
	b.run(0.162, 0.001)
	check("hit at 0.162 s into the dodge lands", b.hero.take_hit(12.0) and is_equal_approx(b.hero.hp, 88.0))
	b.free_all()

	var c := Rig.new(root, T)
	check("plain hit lands", c.hero.take_hit(10.0))
	c.run(0.14, 0.001)
	check("hurt state lasts through 0.14 s", c.hero.state == Hero.State.HURT)
	c.run(0.02, 0.001)
	check("hurt state is over at 0.16 s", c.hero.state == Hero.State.IDLE)
	c.run(0.18, 0.001)
	check("second hit at 0.34 s is ignored", not c.hero.take_hit(10.0) and is_equal_approx(c.hero.hp, 90.0))
	c.run(0.02, 0.001)
	check("second hit at 0.36 s lands", c.hero.take_hit(10.0) and is_equal_approx(c.hero.hp, 80.0))
	c.free_all()


func test_dodge_charges() -> void:
	section("Dodge charges: two max, one back every %.1f s" % T.dodge_recharge)
	var r := Rig.new(root, T)
	check("starts with 2 charges", r.hero.dodge_charges == 2)
	r.input.press_dodge()
	r.tick(0.01)
	var t0 := r.time
	check("first dodge starts and uses a charge", r.hero.state == Hero.State.DODGE and r.hero.dodge_charges == 1)
	r.run(0.35, 0.01)
	r.input.press_dodge()
	r.tick(0.01)
	check("second dodge uses the last charge", r.hero.state == Hero.State.DODGE and r.hero.dodge_charges == 0)
	r.run(0.35, 0.01)
	r.input.press_dodge()
	r.tick(0.01)
	check("third dodge is refused", r.hero.state != Hero.State.DODGE and r.hero.dodge_charges == 0)
	r.run_until(t0 + 1.35, 0.01)
	check("no charge back at 1.35 s", r.hero.dodge_charges == 0)
	r.run_until(t0 + 1.45, 0.01)
	check("one charge back at 1.45 s", r.hero.dodge_charges == 1)
	r.run_until(t0 + 2.75, 0.01)
	check("still one charge at 2.75 s", r.hero.dodge_charges == 1)
	r.run_until(t0 + 2.85, 0.01)
	check("full again at 2.85 s", r.hero.dodge_charges == 2)
	r.run_until(t0 + 6.0, 0.01)
	check("never exceeds 2", r.hero.dodge_charges == 2)
	r.free_all()


func polygon_edge_distance(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func test_hit_area_matches_telegraph() -> void:
	section("Drawn wedge equals the damage area")
	var shapes := [
		["hero light", T.light_reach, T.light_arc_deg],
		["hero heavy", T.heavy_reach, T.heavy_arc_deg],
		["enemy", T.enemy_reach, T.enemy_arc_deg],
	]
	var facings := [Vector2.UP, Vector2.RIGHT.rotated(0.7)]
	for s in shapes:
		var reach: float = s[1]
		var arc: float = s[2]
		for f in facings:
			var poly := HitShapes.sector_polygon(f, reach, arc)
			var point_bad := 0
			var circle_bad := 0
			var samples := 0
			var x := -reach - 30.0
			while x <= reach + 30.0:
				var y := -reach - 30.0
				while y <= reach + 30.0:
					var p := Vector2(x, y)
					var edge := polygon_edge_distance(poly, p)
					if edge > 0.6:
						samples += 1
						var inside := Geometry2D.is_point_in_polygon(p, poly)
						if inside != HitShapes.circle_in_sector(Vector2.ZERO, f, reach, arc, p, 0.0001):
							point_bad += 1
						# A hero-sized body touches the wedge when its centre is inside it
						# or within one radius of its outline.
						var r := T.hero_radius
						var edge_gap := absf(edge - r)
						if edge_gap > 0.6:
							var touching := inside or edge <= r
							if touching != HitShapes.circle_in_sector(Vector2.ZERO, f, reach, arc, p, r):
								circle_bad += 1
					y += 3.0
				x += 3.0
			check("%s %s: point test agrees with polygon (%d samples)" % [s[0], f, samples], point_bad == 0, "bad=%d" % point_bad)
			check("%s %s: body-circle test agrees with polygon" % [s[0], f], circle_bad == 0, "bad=%d" % circle_bad)


func test_action_cancellation() -> void:
	section("Action cancellation and refused inputs")
	# Dodge cancels charging and does not release an attack.
	var a := Rig.new(root, T)
	a.input.press_attack(false)
	a.run(0.2, 0.01)
	a.input.press_dodge()
	a.tick(0.01)
	check("dodge cancels charging", a.hero.state == Hero.State.DODGE)
	a.input.release_attack(false)
	a.run(1.0)
	check("cancelled charge never attacks", a.swings == 0 and a.hero.state == Hero.State.IDLE)
	a.free_all()

	# Dodge cancels recovery.
	var b := Rig.new(root, T)
	b.input.press_attack(false)
	b.tick(0.005)
	b.input.release_attack(false)
	check("reaches recovery", b.until_state(Hero.State.RECOVER))
	b.input.press_dodge()
	b.tick(0.005)
	check("dodge cancels recovery", b.hero.state == Hero.State.DODGE)
	b.free_all()

	# Dodge cannot cancel wind-up or active frames.
	var c := Rig.new(root, T)
	c.input.press_attack(false)
	c.run(0.4, 0.01)
	c.input.release_attack(false)
	c.tick(0.005)
	check("heavy is in wind-up", c.hero.state == Hero.State.WINDUP)
	c.input.press_dodge()
	c.tick(0.005)
	check("dodge refused during wind-up", c.hero.state != Hero.State.DODGE)
	check("reaches active", c.until_state(Hero.State.ACTIVE))
	c.input.press_dodge()
	c.tick(0.005)
	check("dodge refused during active frames", c.hero.state == Hero.State.ACTIVE)
	check("refused dodge spent no charge", c.hero.dodge_charges == 2)
	c.free_all()

	# Attacks cannot start during dodge, hurt or death, and nothing is queued.
	var d := Rig.new(root, T)
	d.input.press_dodge()
	d.tick(0.01)
	d.input.press_attack(false)
	d.tick(0.01)
	d.input.release_attack(false)
	d.tick(0.01)
	d.run(0.5)
	check("attack pressed during dodge is dropped, not queued", d.swings == 0 and d.hero.state == Hero.State.IDLE)
	d.free_all()

	var e := Rig.new(root, T)
	e.hero.take_hit(10.0)
	e.input.press_attack(false)
	e.tick(0.01)
	check("attack refused during hurt", e.hero.state == Hero.State.HURT)
	e.run(0.5)
	check("still-held button after hurt does not auto-attack", e.swings == 0 and e.hero.state == Hero.State.IDLE)
	e.free_all()

	var f := Rig.new(root, T)
	f.hero.take_hit(500.0)
	check("lethal hit -> dead", f.hero.state == Hero.State.DEAD)
	f.input.press_attack(false)
	f.input.press_dodge()
	f.run(0.5)
	check("dead hero ignores attack and dodge", f.hero.state == Hero.State.DEAD and f.swings == 0)
	f.free_all()

	var g := Rig.new(root, T)
	g.input.press_attack(false)
	g.tick(0.005)
	g.input.release_attack(false)
	check("first attack in recovery", g.until_state(Hero.State.RECOVER))
	g.input.press_attack(false)
	g.tick(0.005)
	g.input.release_attack(false)
	g.tick(0.005)
	g.run(1.0)
	check("tap during recovery is ignored, not buffered", g.swings == 1)
	g.free_all()

	# Death overrides an attack in progress.
	var h := Rig.new(root, T)
	h.input.press_attack(false)
	h.tick(0.005)
	h.input.release_attack(false)
	h.tick(0.005)
	h.hero.take_hit(500.0)
	check("death overrides wind-up", h.hero.state == Hero.State.DEAD)
	h.free_all()


func test_wall_containment() -> void:
	section("Wall containment")
	var a := Rig.new(root, T, Vector2(20, 20))
	a.input.key_move = Vector2(-1, -1)
	a.input.press_dodge()
	a.run(0.5, 0.01)
	check("dodge into top-left corner stays inside", a.hero.position.x >= 16.0 - 0.001 and a.hero.position.y >= 16.0 - 0.001, str(a.hero.position))
	a.free_all()
	var b := Rig.new(root, T, Vector2(615, 695))
	b.input.key_move = Vector2(1, 1)
	b.input.press_dodge()
	b.run(0.5, 0.01)
	var lim := T.arena_size - Vector2(16, 16)
	check("dodge into bottom-right corner stays inside", b.hero.position.x <= lim.x + 0.001 and b.hero.position.y <= lim.y + 0.001, str(b.hero.position))
	b.free_all()
	var c := Rig.new(root, T, Vector2(300, 300))
	c.input.key_move = Vector2(-1, 0)
	c.run(5.0, 0.01)
	check("walking into the wall stops at the boundary", is_equal_approx(c.hero.position.x, 16.0), str(c.hero.position))
	c.free_all()
	var d := Rig.new(root, T, Vector2(60, 450))
	d.hero.facing = Vector2.LEFT
	var e := d.add_enemy(Vector2(20, 450))
	d.input.press_attack(false)
	d.run(0.4, 0.01)
	d.input.release_attack(false)
	d.run(1.0)
	check("heavy knockback is clamped at the wall", e.position.x >= 16.0 - 0.001 and e.hp < 30.0, "pos=%s hp=%s" % [e.position, e.hp])
	d.free_all()


func test_enemy_telegraph_and_evasion() -> void:
	section("Enemy telegraph, direction lock and evasion")
	var r := Rig.new(root, T)
	r.run_enemies = true
	var e := r.add_enemy(Vector2(320, 440))
	var wind_start := -1.0
	var hit_time := -1.0
	var guard := 0
	while hit_time < 0.0 and guard < 4000:
		guard += 1
		r.tick(0.005)
		if wind_start < 0.0 and e.state == Enemy.State.WINDUP:
			wind_start = r.time
		if r.hero.hp < T.hero_max_hp and hit_time < 0.0:
			hit_time = r.time
	check("enemy winds up before hitting", wind_start > 0.0 and hit_time > 0.0)
	var gap := hit_time - wind_start
	check("hit lands one wind-up (%.2f s) after the wedge appears" % T.enemy_windup,
			gap >= T.enemy_windup - 0.01 and gap <= T.enemy_windup + 0.02, "gap=%.3f" % gap)
	r.free_all()

	# Tracking before the lock, frozen after it.
	var s := Rig.new(root, T)
	s.run_enemies = true
	var en := s.add_enemy(Vector2(320, 440))
	while en.state != Enemy.State.WINDUP:
		s.tick(0.005)
	var start_dir := en.attack_dir
	while en.state_time < 0.30:
		s.tick(0.005)
	s.hero.position = Vector2(420, 440)
	s.tick(0.005)
	check("before the lock the wedge follows the hero", en.attack_dir.angle_to(start_dir) != 0.0 and en.attack_dir.x > 0.5)
	while en.state_time < T.enemy_windup - T.enemy_lock_time + 0.02:
		s.tick(0.005)
	var locked_dir := en.attack_dir
	check("wedge locks for the final %.2f s" % T.enemy_lock_time, en.locked)
	s.hero.position = Vector2(320, 560)
	s.run(0.1)
	check("locked direction does not follow the hero", en.attack_dir == locked_dir)
	s.run(0.5)
	check("stepping out of the locked wedge avoids all damage", is_equal_approx(s.hero.hp, T.hero_max_hp), "hp=%s" % s.hero.hp)
	s.free_all()


func test_enemy_hits_once_per_attack() -> void:
	section("An enemy attack damages the hero once")
	var quick := T.duplicate() as Tuning
	quick.hit_immunity = 0.0
	var r := Rig.new(root, quick)
	r.run_enemies = true
	var e := r.add_enemy(Vector2(320, 450))
	while e.state != Enemy.State.WINDUP:
		r.tick(0.005)
	while e.state != Enemy.State.RECOVER and e.state != Enemy.State.STAGGER:
		r.tick(0.005)
	check("even with no post-hit immunity, one strike = one hit", r.hurts == 1 and is_equal_approx(r.hero.hp, 88.0), "hurts=%d hp=%s" % [r.hurts, r.hero.hp])
	r.free_all()


func test_dodge_avoids_strike() -> void:
	section("Dodge i-frames cover an enemy strike")
	var without := Rig.new(root, T)
	without.run_enemies = true
	var e1 := without.add_enemy(Vector2(320, 455))
	while e1.state != Enemy.State.RECOVER and e1.state != Enemy.State.STAGGER:
		without.tick(0.005)
	check("control: standing still takes the hit", is_equal_approx(without.hero.hp, 88.0))
	without.free_all()

	var with_dodge := Rig.new(root, T)
	with_dodge.run_enemies = true
	var e2 := with_dodge.add_enemy(Vector2(320, 455))
	while e2.state != Enemy.State.WINDUP:
		with_dodge.tick(0.005)
	while e2.state_time < 0.60:
		with_dodge.tick(0.005)
	# Dodge toward the enemy so the hero stays inside the wedge: only i-frames can save it.
	with_dodge.input.key_move = Vector2(0, -1)
	with_dodge.input.press_dodge()
	while e2.state != Enemy.State.RECOVER and e2.state != Enemy.State.STAGGER:
		with_dodge.tick(0.005)
	check("dodging into the strike with i-frames takes no damage", is_equal_approx(with_dodge.hero.hp, 100.0), "hp=%s" % with_dodge.hero.hp)
	with_dodge.free_all()


func screen_touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	return ev


func screen_drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	return ev


func make_controls(inp: CombatInput) -> TouchControls:
	var c := TouchControls.new()
	c.input = inp
	c.tuning = T
	c.layout(Vector2(720, 1280), 1280.0 * T.control_band_fraction, Vector4.ZERO)
	c.set_enabled(true)
	return c


func test_multitouch_and_focus() -> void:
	section("Simultaneous touches and focus loss")
	var inp := CombatInput.new()
	var c := make_controls(inp)
	var start := c.joy_hint
	c._input(screen_touch(0, start, true))
	c._input(screen_drag(0, start + Vector2(80, 0)))
	check("left thumb drives the stick", inp.touch_move.x > 0.5 and c.joy_index == 0, str(inp.touch_move))
	c._input(screen_touch(1, c.attack_center, true))
	check("attack touch registers while the stick is held", inp.attack_down() and inp.attack_pressed and inp.touch_move.x > 0.5)
	c._input(screen_drag(0, start + Vector2(0, -80)))
	check("stick keeps updating while attack is held", inp.touch_move.y < -0.5 and inp.attack_down())
	c._input(screen_touch(2, c.dodge_center, true))
	check("third finger dodges while stick and attack are held", inp.dodge_pressed and inp.attack_down() and inp.touch_move.length() > 0.5)
	c._input(screen_touch(1, c.attack_center, false))
	check("releasing the attack finger releases only the attack", inp.attack_released and not inp.attack_down() and inp.touch_move.length() > 0.5)
	c._input(screen_touch(0, start, false))
	check("releasing the stick stops movement", inp.touch_move == Vector2.ZERO and c.joy_index == -1)
	c.free()

	var inp2 := CombatInput.new()
	var c2 := make_controls(inp2)
	c2._input(screen_touch(5, c2.attack_center, true))
	c2._input(screen_drag(5, c2.attack_center + Vector2(0, -400)))
	check("dragging off the attack button cancels it", not inp2.attack_down())
	inp2.end_step()
	c2._input(screen_touch(5, c2.attack_center + Vector2(0, -400), false))
	check("lifting after a cancel does not fire a release", not inp2.attack_released)
	c2._input(screen_touch(6, Vector2(600, 960), true))
	check("touch in empty right-hand space does nothing", c2.joy_index == -1 and not inp2.attack_down())
	c2._input(screen_touch(7, Vector2(100, 200), true))
	check("touch above the control band does not start the stick", c2.joy_index == -1)
	c2.free()

	var inp3 := CombatInput.new()
	var c3 := make_controls(inp3)
	c3._input(screen_touch(0, c3.joy_hint, true))
	c3._input(screen_drag(0, c3.joy_hint + Vector2(70, 0)))
	c3._input(screen_touch(1, c3.attack_center, true))
	c3.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss clears stick, attack and finger tracking",
			inp3.touch_move == Vector2.ZERO and not inp3.attack_down() and c3.joy_index == -1 and c3.atk_index == -1)
	c3._input(screen_touch(1, c3.attack_center, false))
	check("late release after focus loss is harmless", not inp3.attack_released)
	c3.free()

	var inp4 := CombatInput.new()
	var c4 := make_controls(inp4)
	c4.set_enabled(false)
	c4._input(screen_touch(0, c4.attack_center, true))
	check("disabled controls ignore touches", not inp4.attack_down())
	c4.free()


func test_touch_drives_hero() -> void:
	section("Touch input reaches the same hero code")
	var r := Rig.new(root, T)
	var c := make_controls(r.input)
	c._input(screen_touch(1, c.attack_center, true))
	r.run(0.1, 0.01)
	c._input(screen_touch(1, c.attack_center, false))
	r.run(0.5)
	check("tap on the Attack button produces a light swing", r.swings == 1 and r.heavy_swings == 0)
	c._input(screen_touch(1, c.attack_center, true))
	r.run(0.5, 0.01)
	c._input(screen_touch(1, c.attack_center, false))
	r.run(0.6)
	check("hold then release produces a heavy swing", r.swings == 2 and r.heavy_swings == 1)
	r.run(0.5)
	check("hero is idle again before the move test", r.hero.state == Hero.State.IDLE)
	c._input(screen_touch(0, c.joy_hint, true))
	c._input(screen_drag(0, c.joy_hint + Vector2(90, 0)))
	r.run(0.4, 0.01)
	var x0 := r.hero.position.x
	r.run(0.5, 0.01)
	check("stick moves the hero at about 195 px/s", absf((r.hero.position.x - x0) - 97.5) < 3.0, "dx=%s" % (r.hero.position.x - x0))
	c._input(screen_touch(2, c.dodge_center, true))
	r.tick(0.01)
	check("Dodge button starts a dodge", r.hero.state == Hero.State.DODGE)
	c.free()
	r.free_all()


func test_isometric_view() -> void:
	section("Isometric view: projection, stick mapping, spawns, layout")
	var ok := true
	for v in [Vector2(10, 0), Vector2(0, 10), Vector2(3, -7), Vector2(-120, 45.5)]:
		if Iso.to_ground(Iso.to_screen(v)).distance_to(v) > 0.0001 or Iso.to_screen(Iso.to_ground(v)).distance_to(v) > 0.0001:
			ok = false
	check("Iso.to_screen and to_ground are inverses", ok)
	check("ground (1,1) is screen-down, ground (1,-1) is screen-right",
			Iso.to_screen(Vector2(1, 1)).is_equal_approx(Vector2(0, 1)) and Iso.to_screen(Vector2(1, -1)).is_equal_approx(Vector2(2, 0)))

	# Affine maps keep containment, so a wedge drawn through the projection covers exactly
	# the projected hit area.
	var poly := HitShapes.sector_polygon(Vector2.UP, T.heavy_reach, T.heavy_arc_deg)
	var screen_poly := PackedVector2Array()
	for p in poly:
		screen_poly.append(Iso.to_screen(p))
	var mismatches := 0
	var x := -100.0
	while x <= 100.0:
		var y := -100.0
		while y <= 100.0:
			var g := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(g, poly) != Geometry2D.is_point_in_polygon(Iso.to_screen(g), screen_poly):
				if polygon_edge_distance(poly, g) > 0.6:
					mismatches += 1
			y += 3.0
		x += 3.0
	check("a projected wedge contains exactly the projected hit area", mismatches == 0, "bad=%d" % mismatches)

	# Stick up means up on the screen, at full ground speed.
	var r := Rig.new(root, T, Vector2(320, 360))
	r.input.iso_view = true
	r.input.key_move = Vector2(0, -1)
	r.run(0.4, 0.01)
	var start := r.hero.position
	r.run(0.5, 0.01)
	var delta := r.hero.position - start
	var on_screen := Iso.to_screen(delta)
	check("stick up moves the hero straight up the screen", on_screen.y < -10.0 and absf(on_screen.x) < 0.01, str(on_screen))
	check("ground speed is 195 px/s", absf(delta.length() - 97.5) < 0.5, "d=%s" % delta.length())
	r.input.key_move = Vector2(1, 0)
	r.run(0.3, 0.01)
	var before := r.hero.position
	r.run(0.3, 0.01)
	var right_move := Iso.to_screen(r.hero.position - before)
	check("stick right moves the hero straight right on the screen", right_move.x > 5.0 and absf(right_move.y) < 0.01, str(right_move))
	r.free_all()

	var d := Rig.new(root, T, Vector2(320, 360))
	d.input.iso_view = true
	d.input.key_move = Vector2(0, -1)
	d.input.press_dodge()
	var s0 := d.hero.position
	d.tick(0.01)
	d.input.key_move = Vector2.ZERO  # let go once the dodge has started
	d.run(0.5, 0.01)
	var dodge_screen := Iso.to_screen(d.hero.position - s0)
	check("dodge with stick up goes up the screen, 90 ground px", dodge_screen.y < 0.0 and absf(dodge_screen.x) < 0.01 and absf((d.hero.position - s0).length() - 90.0) < 0.5)
	d.free_all()

	var g := make_game()
	check("the game turns the isometric stick mapping on", g.input.iso_view)
	g.start_fight(Game.Mode.THREE_CAPTAIN)
	var a := g.tuning.arena_size
	var spawns_ok := true
	var min_gap := INF
	for e in g.enemies:
		if e.position.x < 20 or e.position.y < 20 or e.position.x > a.x - 20 or e.position.y > a.y - 20:
			spawns_ok = false
		min_gap = minf(min_gap, e.position.distance_to(g.hero.position))
	check("hero and all enemies spawn inside the arena", spawns_ok and g.hero.position.x < a.x - 16 and g.hero.position.y < a.y - 16)
	check("enemies spawn outside melee range (> %d)" % int(g.tuning.enemy_reach + 32.0), min_gap > g.tuning.enemy_reach + 32.0 + 40.0, "gap=%.1f" % min_gap)
	var hero_screen := Iso.to_screen(g.hero.position)
	var above := true
	for e in g.enemies:
		if Iso.to_screen(e.position).y >= hero_screen.y:
			above = false
	check("enemies start above the hero on the screen", above)

	# Whole diamond sits inside the area above the control band.
	var vp := g.get_viewport().get_visible_rect().size
	var band_top := vp.y * (1.0 - g.tuning.control_band_fraction)
	var fits := true
	for corner in [Vector2.ZERO, Vector2(a.x, 0), Vector2(0, a.y), a]:
		var sp := g.arena_root.transform * Iso.to_screen(corner)
		if sp.x < 0.0 or sp.x > vp.x or sp.y < 0.0 or sp.y > band_top:
			fits = false
			print("      corner off screen: ", corner, " -> ", sp)
	check("all four arena corners are on screen, above the control band", fits)
	check("scene tree is ArenaRoot > IsoLayer > hero and enemies", g.hero.get_parent() == g.iso_layer and g.enemies[0].get_parent() == g.iso_layer and g.iso_layer.get_parent() == g.arena_root)
	g.queue_free()


func make_game() -> Game:
	var g := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	root.add_child(g)
	return g


func nearest_alive(g: Game) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e in g.enemies:
		if not e.is_dead():
			var d: float = e.position.distance_to(g.hero.position)
			if d < bd:
				bd = d
				best = e
	return best


## A simple scripted player: walk to the nearest enemy, tap-attack at the weapon's range and
## sidestep-dodge a locked strike. Deterministic, no randomness.
func bot(g: Game, block := false) -> void:
	var h := g.hero
	var target := nearest_alive(g)
	if target == null:
		g.input.key_move = Vector2.ZERO
		return
	var to := target.position - h.position
	var want: float = h.weapon.light.reach * 0.85
	g.input.key_move = to.normalized() if to.length() > want else to.normalized() * 0.05
	# A dodge cancels a charge but the "finger" is still down: lift it, as a player would.
	if h.state == Hero.State.IDLE and g.input.attack_down():
		g.input.release_attack(false)
	if block:
		# Guard up in the last 0.28 s of a locked strike that covers us (a plain block; a parry
		# only if it happens to be raised inside the window), and through the strike itself.
		var threatened := false
		var threat_dir := Vector2.ZERO
		for e in g.enemies:
			if e.is_dead() or not (e.state == Enemy.State.WINDUP or e.state == Enemy.State.ACTIVE):
				continue
			var left_b: float = e.cur.windup - e.state_time if e.state == Enemy.State.WINDUP else 0.0
			if (e.state == Enemy.State.ACTIVE or (e.locked and left_b <= 0.28)) \
					and HitShapes.circle_in_sector(e.attack_origin, e.attack_dir, e.cur.reach,
							e.cur.arc_deg, h.position, h.radius):
				threatened = true
				threat_dir = e.attack_origin - h.position
		if threatened:
			# Turn the guard toward the attacker, then hold it up through the strike.
			if threat_dir.length() > 0.001:
				g.input.key_move = threat_dir.normalized() * 0.3
			g.input.press_block(false)
			return
		g.input.release_block(false)
	for e in g.enemies:
		if e.is_dead() or e.state != Enemy.State.WINDUP or not e.locked:
			continue
		var left: float = e.cur.windup - e.state_time
		# Start late enough that the i-frames (0.16 s) still cover the whole strike.
		if left <= maxf(0.02, 0.15 - e.cur.active) and h.dodge_charges > 0 \
				and h.state in [Hero.State.IDLE, Hero.State.CHARGING, Hero.State.RECOVER]:
			if HitShapes.circle_in_sector(e.attack_origin, e.attack_dir, e.cur.reach,
					e.cur.arc_deg, h.position, h.radius):
				g.input.key_move = e.attack_dir.orthogonal()
				g.input.press_dodge()
				return
	if h.state == Hero.State.IDLE and to.length() <= want + 4.0:
		g.input.press_attack(false)
	elif h.state == Hero.State.CHARGING:
		g.input.release_attack(false)


func play(g: Game, max_seconds: float, use_bot: bool, block := false) -> void:
	var steps := int(max_seconds * 60.0)
	for i in steps:
		if g.state != Game.State.FIGHTING:
			break
		if use_bot:
			bot(g, block)
		g.step(1.0 / 60.0)


func test_commitment_limit() -> void:
	section("At most two enemies commit to an attack at once")
	var g := make_game()
	g.tuning.hero_max_hp = 100000.0
	g.start_fight(Game.Mode.THREE_CAPTAIN)
	var peak_states := 0
	var waiting_while_two := false
	var steps := 0
	while steps < 60 * 40 and g.state == Game.State.FIGHTING:
		g.step(1.0 / 60.0)
		steps += 1
		var committed := 0
		var waiting := 0
		for e in g.enemies:
			if e.is_committed():
				committed += 1
			elif not e.is_dead():
				waiting += 1
		peak_states = maxi(peak_states, committed)
		if committed == 2 and waiting == 1:
			waiting_while_two = true
		if committed > 2 or g.controller.count() > 2:
			break
	check("never more than 2 enemies in wind-up/strike/recovery (40 s idle hero)", peak_states <= 2 and g.controller.peak <= 2, "peak=%d" % peak_states)
	check("two do attack together at some point", peak_states == 2)
	check("the third visibly waits (not attacking) while two are committed", waiting_while_two)
	# Killing a committed enemy frees its slot.
	var victim: Enemy = null
	for e in g.enemies:
		if e.is_committed():
			victim = e
			break
	if victim != null:
		var before := g.controller.count()
		victim.take_hit(999.0, victim.position + Vector2(0, 10), 0.0)
		check("death releases the attack commitment", g.controller.count() == before - 1)
	g.queue_free()


func test_full_fights() -> void:
	section("Full fights: victory, defeat and result priority")
	var one := make_game()
	one.start_fight(Game.Mode.ONE)
	play(one, 90.0, true)
	check("1 enemy: scripted hero wins", one.state == Game.State.RESULT and one.outcome == Game.Outcome.VICTORY,
			"outcome=%s t=%.1f hp=%s" % [one.outcome, one.fight_time, one.hero.hp])
	print("        (1 enemy bot win: %.1f s, hero hp %d)" % [one.fight_time, ceili(one.hero.hp)])
	one.queue_free()

	var idle := make_game()
	idle.start_fight(Game.Mode.THREE_CAPTAIN)
	play(idle, 90.0, false)
	check("hero can die: idle hero is defeated", idle.state == Game.State.RESULT and idle.outcome == Game.Outcome.DEFEAT,
			"outcome=%s hp=%s" % [idle.outcome, idle.hero.hp])
	check("hero is dead at defeat", idle.hero.is_dead() and idle.hero.hp == 0.0)
	idle.queue_free()

	# Defeat takes priority when both sides are down.
	var tie := make_game()
	tie.start_fight(Game.Mode.ONE)
	tie.hero.hp = 0.0
	tie.hero.state = Hero.State.DEAD
	for e in tie.enemies:
		e.take_hit(999.0, e.position, 0.0)
	tie._check_outcome()
	check("hero and last enemy both down -> DEFEAT", tie.outcome == Game.Outcome.DEFEAT)
	tie.queue_free()

	# Same-step trade: enemy strike and killing blow in one step.
	var trade := make_game()
	trade.start_fight(Game.Mode.ONE)
	var e := trade.enemies[0] as Enemy
	var mid := trade.tuning.arena_size.x * 0.5
	e.position = Vector2(mid, 250)
	e.hp = 1.0
	trade.hero.position = Vector2(mid, 300)
	trade.hero.hp = 5.0
	trade.hero.facing = Vector2.UP
	trade.hero.cur_attack = trade.tuning.attack_data(false)
	trade.hero.hit_ids = {}
	trade.hero.state = Hero.State.ACTIVE
	trade.hero.state_time = 0.0
	e.attack_dir = Vector2.DOWN
	e.attack_origin = e.position
	e.hit_done = false
	e.locked = true
	e.state = Enemy.State.ACTIVE
	e.state_time = 0.0
	trade.controller.try_commit(e)
	trade.step(1.0 / 60.0)
	check("strike and killing blow on the same step -> DEFEAT", trade.outcome == Game.Outcome.DEFEAT,
			"outcome=%s hero_hp=%s enemy_hp=%s" % [trade.outcome, trade.hero.hp, e.hp])
	trade.queue_free()


func snapshot(g: Game) -> Dictionary:
	var es := []
	for e in g.enemies:
		es.append([e.position, e.hp, e.state, e.cooldown, e.state_time])
	var enemy_nodes := 0
	for c in g.iso_layer.get_children():
		if c is Enemy:
			enemy_nodes += 1
	return {
		"state": g.state, "outcome": g.outcome, "time": g.fight_time, "result_timer": g.result_timer,
		"hero": [g.hero.position, g.hero.hp, g.hero.state, g.hero.state_time, g.hero.charge_time,
				g.hero.immune_time, g.hero.dodge_charges, g.hero.dodge_recharge_t, g.hero.facing,
				g.hero.cur_attack.size(), g.hero.hit_ids.size()],
		"enemies": es, "enemy_nodes": enemy_nodes, "commits": g.controller.count(),
		"peak": g.controller.peak, "mode": g.mode, "weapon": g.hero.weapon.id,
		"captain": [g.captain_spawned, g.intermission_active, g.intermission_left],
		"guard": [g.hero.guard, g.hero.has_shield, g.hero.block_cd, g.hero.guard_wait],
		"input": [g.input.touch_move, g.input.key_move, g.input.attack_touch, g.input.attack_key,
				g.input.attack_pressed, g.input.attack_released, g.input.dodge_pressed],
		"controls": [g.controls.joy_index, g.controls.atk_index, g.controls.dodge_index],
	}


func test_retry_resets_everything() -> void:
	section("Retry resets all state (10 cycles per mode)")
	var g := make_game()
	var expected := {Game.Mode.THREE_CAPTAIN: 3, Game.Mode.ONE: 1, Game.Mode.CAPTAIN_ONLY: 1}
	for mode in expected:
		g.shield_on = (mode == Game.Mode.ONE)  # cover both loadouts
		g.start_fight(mode)
		var baseline := snapshot(g)
		var identical := true
		for i in 10:
			# Dirty everything: fight, hold inputs, spend dodges, lose HP.
			g.input.press_attack(true)
			g.input.touch_move = Vector2(1, 0)
			g.controls.atk_index = 3
			play(g, 6.0 + i * 0.3, true)
			g.input.press_attack(false)
			g.input.press_block(false)
			g.hero.guard = 3.0
			g.hero.take_hit(1.0)
			g.start_fight(mode)
			if snapshot(g) != baseline:
				identical = false
				print("      first difference on cycle ", i)
		check("%s: state after every Retry equals a fresh start" % Game.Mode.keys()[mode], identical)
		check("%s: exactly %d enemies exist after Retry" % [Game.Mode.keys()[mode], expected[mode]],
				g.enemies.size() == expected[mode] and baseline.enemy_nodes == expected[mode])

	# Retry from the result screen, via the menu button signal.
	g.start_fight(Game.Mode.THREE_CAPTAIN)
	g.hero.take_hit(1000.0)
	g.step(1.0 / 60.0)
	check("defeat moves to the result state", g.state == Game.State.RESULT)
	g.menu.fight_requested.emit(Game.Mode.ONE, 0, false)
	check("Retry from the result screen starts a new 1-enemy fight", g.state == Game.State.FIGHTING and g.enemies.size() == 1 and g.hero.hp == g.tuning.hero_max_hp and not g.hero.is_dead())
	g.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss through the Game node clears held input", not g.input.attack_down() and g.input.touch_move == Vector2.ZERO)
	g.queue_free()


func attack_tuple(a: AttackDef) -> Array:
	return [a.damage, a.reach, a.arc_deg, a.windup, a.active, a.recover, a.knockback, a.lunge]


func tuple_close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not is_equal_approx(float(a[i]), float(b[i])):
			return false
	return true


func test_weapon_and_captain_data() -> void:
	section("Weapon and captain data")
	var g := make_game()
	var ids := []
	for w in g.weapons:
		ids.append(w.id)
	check("five weapons: sword, spear, axe, daggers, zweihander", ids == ["sword", "spear", "axe", "daggers", "zweihander"], str(ids))
	var sword: Weapon = g.weapons[0]
	check("sword light (reach buffed to 75)", tuple_close(attack_tuple(sword.light), [10, 75, 90, 0.10, 0.08, 0.22, 0, 0]))
	check("sword heavy (reach buffed to 95)", tuple_close(attack_tuple(sword.heavy), [25, 95, 140, 0.15, 0.10, 0.40, 35, 0]))
	var spear: Weapon = g.weapons[1]
	check("spear light/heavy values", tuple_close(attack_tuple(spear.light), [10, 95, 30, 0.12, 0.08, 0.26, 0, 0]) and tuple_close(attack_tuple(spear.heavy), [22, 120, 24, 0.22, 0.10, 0.45, 0, 35]))
	var axe: Weapon = g.weapons[2]
	check("axe light/heavy values", tuple_close(attack_tuple(axe.light), [16, 70, 150, 0.22, 0.10, 0.38, 0, 0]) and tuple_close(attack_tuple(axe.heavy), [38, 90, 200, 0.35, 0.14, 0.60, 60, 0]))
	check("axe moves at 0.9x and recharges dodges 1.2x slower", is_equal_approx(axe.move_mult, 0.9) and is_equal_approx(axe.dodge_recharge_mult, 1.2))
	var daggers: Weapon = g.weapons[3]
	check("daggers light/heavy values", tuple_close(attack_tuple(daggers.light), [5, 40, 360, 0.04, 0.05, 0.09, 0, 0]) and tuple_close(attack_tuple(daggers.heavy), [12, 50, 360, 0.08, 0.07, 0.18, 0, 0]))
	var zwei: Weapon = g.weapons[4]
	check("zweihander light/heavy values", tuple_close(attack_tuple(zwei.light), [14, 85, 100, 0.18, 0.08, 0.32, 0, 0]) and tuple_close(attack_tuple(zwei.heavy), [34, 105, 160, 0.28, 0.12, 0.50, 45, 0]))
	check("zweihander: two-handed, 0.95x speed, 1.1x dodge recharge", not zwei.one_handed and is_equal_approx(zwei.move_mult, 0.95) and is_equal_approx(zwei.dodge_recharge_mult, 1.1))
	check("daggers: 1.1x speed, one extra dodge, 0.8x recharge", is_equal_approx(daggers.move_mult, 1.1) and daggers.extra_dodge_charges == 1 and is_equal_approx(daggers.dodge_recharge_mult, 0.8))
	check("stagger lengths per weapon: sword 3.0/1.0, spear 3.5/0.8, axe 2.5/1.5, daggers 2.0/0.6, zweihander 3.0/1.3 (parry/heavy)",
			tuple_close([sword.parry_stagger_time, sword.heavy_stagger_time, spear.parry_stagger_time, spear.heavy_stagger_time, axe.parry_stagger_time, axe.heavy_stagger_time, daggers.parry_stagger_time, daggers.heavy_stagger_time, zwei.parry_stagger_time, zwei.heavy_stagger_time],
			[3.0, 1.0, 3.5, 0.8, 2.5, 1.5, 2.0, 0.6, 3.0, 1.3]))
	check("block stun per weapon: sword 1.2, spear 1.4, axe 1.6, daggers 0.8, zweihander 1.4",
			tuple_close([sword.block_stun_time, spear.block_stun_time, axe.block_stun_time, daggers.block_stun_time, zwei.block_stun_time], [1.2, 1.4, 1.6, 0.8, 1.4]))
	check("only the daggers kill on a parry", daggers.parry_kill and not sword.parry_kill and not spear.parry_kill and not axe.parry_kill and not zwei.parry_kill)
	var cap: EnemyProfile = g.captain_profile
	check("captain scales stagger: parry x1.0, heavy x0.5", is_equal_approx(cap.stagger_mult, 1.0) and is_equal_approx(cap.heavy_stagger_mult, 0.5))
	check("captain loaded: 150 HP, radius 22, speed 95", cap != null and cap.id == "captain" and is_equal_approx(cap.max_hp, 150.0) and is_equal_approx(cap.radius, 22.0) and is_equal_approx(cap.speed, 95.0))
	check("captain has slash, two combo hits and a lunge", cap.attacks.size() == 4 and cap.attacks[1].chain_to == 2 and cap.attacks[2].chain_to == -1)
	check("captain attack values", tuple_close(attack_tuple(cap.attacks[0]), [18, 62, 120, 0.70, 0.10, 0.60, 0, 0]) and tuple_close(attack_tuple(cap.attacks[1]), [14, 58, 110, 0.55, 0.10, 0.12, 0, 0]) and tuple_close(attack_tuple(cap.attacks[2]), [20, 66, 130, 0.38, 0.10, 0.80, 0, 0]) and tuple_close(attack_tuple(cap.attacks[3]), [22, 150, 28, 0.80, 0.12, 0.90, 0, 120]))
	check("captain pattern is lunge, slash, combo, slash, combo", cap.pattern == PackedInt32Array([3, 0, 1, 0, 1]))
	check("pattern picks the lunge from afar and skips it up close", cap.choose(200.0, 0) == 0 and cap.choose(60.0, 0) == 1)
	var order := []
	var pos := 1
	for i in 4:
		order.append(cap.attack_at(pos).label)
		pos += 1
	check("up close the captain alternates slash and combo", order == ["Slash", "Combo 1", "Slash", "Combo 1"], str(order))
	g.queue_free()


func weapon_rig(w: Weapon) -> Rig:
	var r := Rig.new(root, T)
	r.use_weapon(w)
	return r


func test_weapon_mechanics() -> void:
	section("Weapon mechanics")
	var g := make_game()
	var arena_t := T
	for w in g.weapons:
		# Light attack: hits a target in front exactly once, for the weapon's damage.
		var r := weapon_rig(w)
		var near := r.add_enemy(r.hero.position + Vector2(0, -w.light.reach * 0.7))
		near.hp = 1000.0
		r.input.press_attack(false)
		r.tick(0.005)
		r.input.release_attack(false)
		r.run(1.2)
		check("%s light: one hit for %d" % [w.display_name, int(w.light.damage)], is_equal_approx(near.hp, 1000.0 - w.light.damage) and r.hits == 1, "hp=%s hits=%d" % [near.hp, r.hits])
		r.free_all()

		# Beyond reach: no hit.
		var far := weapon_rig(w)
		var out := far.add_enemy(far.hero.position + Vector2(0, -(w.light.reach + far.t.enemy_radius + 6.0)))
		out.hp = 1000.0
		far.input.press_attack(false)
		far.tick(0.005)
		far.input.release_attack(false)
		far.run(1.2)
		check("%s light: a target just past reach is not hit" % w.display_name, far.hits == 0)
		far.free_all()

		# Heavy: damage and knockback match the weapon.
		var h := weapon_rig(w)
		var tgt := h.add_enemy(h.hero.position + Vector2(0, -w.heavy.reach * 0.6))
		tgt.hp = 1000.0
		var y0 := tgt.position.y
		h.input.press_attack(false)
		h.run(0.5, 0.01)
		h.input.release_attack(false)
		h.run(1.5)
		check("%s heavy: one hit for %d, pushed %d" % [w.display_name, int(w.heavy.damage), int(w.heavy.knockback)],
				is_equal_approx(tgt.hp, 1000.0 - w.heavy.damage) and h.hits == 1 and absf((y0 - tgt.position.y) - w.heavy.knockback) < 0.01,
				"hp=%s hits=%d moved=%s" % [tgt.hp, h.hits, y0 - tgt.position.y])
		h.free_all()

	# Reach differences.
	var spear: Weapon = g.weapons[1]
	var sword: Weapon = g.weapons[0]
	var rs := weapon_rig(spear)
	var es := rs.add_enemy(rs.hero.position + Vector2(0, -100))
	es.hp = 1000.0
	rs.input.press_attack(false)
	rs.tick(0.005)
	rs.input.release_attack(false)
	rs.run(1.0)
	var rw := weapon_rig(sword)
	var ew := rw.add_enemy(rw.hero.position + Vector2(0, -100))
	ew.hp = 1000.0
	rw.input.press_attack(false)
	rw.tick(0.005)
	rw.input.release_attack(false)
	rw.run(1.0)
	check("a target 100 away is hit by the spear and not by the sword", rs.hits == 1 and rw.hits == 0)
	rs.free_all()
	rw.free_all()

	# Axe spin covers 95 degrees off axis; the sword heavy does not.
	var axe: Weapon = g.weapons[2]
	for pair in [[axe, 1], [sword, 0]]:
		var w: Weapon = pair[0]
		var r := weapon_rig(w)
		var side := r.add_enemy(r.hero.position + Vector2.UP.rotated(deg_to_rad(95.0)) * 58.0)
		side.hp = 1000.0
		r.input.press_attack(false)
		r.run(0.5, 0.01)
		r.input.release_attack(false)
		r.run(1.5)
		check("%s heavy %s a target 95 degrees off axis" % [w.display_name, "hits" if pair[1] == 1 else "misses"], r.hits == pair[1], "hits=%d" % r.hits)
		r.free_all()

	# Dodge style.
	var dg: Weapon = g.weapons[3]
	var d := weapon_rig(dg)
	check("daggers start with 3 dodge charges", d.hero.dodge_charges == 3 and d.hero.max_charges() == 3)
	d.input.press_dodge()
	d.tick(0.01)
	var t0 := d.time
	d.run_until(t0 + 1.05, 0.01)
	var before := d.hero.dodge_charges
	d.run_until(t0 + 1.18, 0.01)
	check("daggers recharge a dodge in 1.12 s (not 1.4)", before == 2 and d.hero.dodge_charges == 3, "before=%d after=%d" % [before, d.hero.dodge_charges])
	d.free_all()
	var ax := weapon_rig(axe)
	ax.input.press_dodge()
	ax.tick(0.01)
	var a0 := ax.time
	ax.run_until(a0 + 1.5, 0.01)
	var still_low := ax.hero.dodge_charges == 1
	ax.run_until(a0 + 1.75, 0.01)
	check("axe needs 1.68 s for a dodge charge (not 1.4)", still_low and ax.hero.dodge_charges == 2)
	ax.free_all()

	# Movement speed (measured at steady state, after the ramp-up).
	var zwei: Weapon = g.weapons[4]
	for pair in [[axe, 175.5], [dg, 214.5], [sword, 195.0], [zwei, 185.25]]:
		var w: Weapon = pair[0]
		var r := weapon_rig(w)
		r.hero.position = Vector2(500, 360)
		r.input.key_move = Vector2(-1, 0)
		r.run(0.4, 0.01)
		var x0 := r.hero.position.x
		r.run(1.0, 0.01)
		check("%s walks at %s px/s" % [w.display_name, pair[1]], absf((x0 - r.hero.position.x) - pair[1]) < 1.5, "dx=%s" % (x0 - r.hero.position.x))
		r.free_all()

	# Spear heavy steps forward during the strike.
	var sp := weapon_rig(spear)
	var y_start := sp.hero.position.y
	sp.input.press_attack(false)
	sp.run(0.5, 0.01)
	sp.input.release_attack(false)
	sp.run(1.5)
	check("spear heavy lunges 35 forward", absf((y_start - sp.hero.position.y) - 35.0) < 1.0, "dy=%s" % (y_start - sp.hero.position.y))
	sp.free_all()
	g.queue_free()


func test_all_attack_shapes() -> void:
	section("Wedge equals hit area for every weapon and captain attack")
	var g := make_game()
	var shapes := []
	for w in g.weapons:
		shapes.append([w.display_name + " light", w.light.reach, w.light.arc_deg])
		shapes.append([w.display_name + " heavy", w.heavy.reach, w.heavy.arc_deg])
	for a in g.captain_profile.attacks:
		shapes.append(["Captain " + a.label, a.reach, a.arc_deg])
	for s_ in shapes:
		var reach: float = s_[1]
		var arc: float = s_[2]
		var bad := 0
		for f in [Vector2.UP, Vector2.RIGHT.rotated(0.7)]:
			var poly := HitShapes.sector_polygon(f, reach, arc)
			var x: float = -reach - 20.0
			while x <= reach + 20.0:
				var y: float = -reach - 20.0
				while y <= reach + 20.0:
					var p := Vector2(x, y)
					if polygon_edge_distance(poly, p) > 0.6:
						if Geometry2D.is_point_in_polygon(p, poly) != HitShapes.circle_in_sector(Vector2.ZERO, f, reach, arc, p, 0.0001):
							bad += 1
					y += 4.0
				x += 4.0
		check("%s: drawn wedge equals hit area" % s_[0], bad == 0, "bad=%d" % bad)
	g.queue_free()


func captain_rig(hero_pos: Vector2, cap_pos: Vector2) -> Array:
	var cap_profile := load("res://resources/captain.tres") as EnemyProfile
	var r := Rig.new(root, T, hero_pos)
	r.run_enemies = true
	var c := r.add_enemy(cap_pos, 0, cap_profile)
	return [r, c]


func test_captain_attacks() -> void:
	section("Captain attacks")
	# Slash: lands one wind-up after the wedge appears.
	var pair := captain_rig(Vector2(320, 500), Vector2(320, 445))
	var r: Rig = pair[0]
	var c: Enemy = pair[1]
	var wind_start := -1.0
	var hit_time := -1.0
	var guard := 0
	while hit_time < 0.0 and guard < 4000:
		guard += 1
		r.tick(0.005)
		if wind_start < 0.0 and c.state == Enemy.State.WINDUP:
			wind_start = r.time
			check("up close the captain opens with the slash", c.cur.label == "Slash")
		if r.hero.hp < T.hero_max_hp and hit_time < 0.0:
			hit_time = r.time
	check("slash lands 0.70 s after its wedge appears", absf((hit_time - wind_start) - 0.70) < 0.02, "gap=%.3f" % (hit_time - wind_start))
	check("slash deals 18", is_equal_approx(r.hero.hp, 82.0))
	r.free_all()

	# Combo: two separate telegraphed hits under one commitment.
	var cp := captain_rig(Vector2(320, 500), Vector2(320, 445))
	var cr: Rig = cp[0]
	var cc: Enemy = cp[1]
	cc.pattern_pos = 2  # the combo entry
	var hit_times := []
	var last_hp := cr.hero.hp
	var seen_second_windup := false
	var max_commit := 0
	var steps := 0
	while steps < 3000 and cc.state != Enemy.State.POSITION or steps == 0:
		steps += 1
		cr.tick(0.005)
		max_commit = maxi(max_commit, cr.ctrl.count())
		if cr.hero.hp < last_hp:
			hit_times.append(cr.time)
			last_hp = cr.hero.hp
		if cc.cur.label == "Combo 2" and cc.state == Enemy.State.WINDUP:
			seen_second_windup = true
	check("combo: both hits land (14 then 20)", cr.hurts == 2 and is_equal_approx(cr.hero.hp, 66.0), "hurts=%d hp=%s" % [cr.hurts, cr.hero.hp])
	check("combo: the second hit has its own wind-up", seen_second_windup)
	check("combo: second hit lands 0.60 s after the first", hit_times.size() == 2 and absf((hit_times[1] - hit_times[0]) - 0.60) < 0.02, str(hit_times))
	check("combo: one commitment for the whole chain, released at the end", max_commit == 1 and cr.ctrl.count() == 0)
	check("combo: attack gap applies afterwards", is_equal_approx(cc.cooldown, T.enemy_attack_gap) or cc.cooldown <= T.enemy_attack_gap)
	cr.free_all()

	# Lunge: hit once, slides the captain about 120, and the wedge is the one telegraphed.
	var lp := captain_rig(Vector2(320, 425), Vector2(320, 300))
	var lr: Rig = lp[0]
	var lc: Enemy = lp[1]
	var origin_y := 300.0
	var saw_lunge := false
	steps = 0
	while steps < 4000 and not (saw_lunge and lc.state == Enemy.State.RECOVER):
		steps += 1
		lr.tick(0.005)
		if lc.state == Enemy.State.WINDUP and lc.cur.label == "Lunge":
			saw_lunge = true
	check("at 125 away the captain opens with the lunge", saw_lunge)
	check("lunge hits a hero standing in its path once for 22", lr.hurts == 1 and is_equal_approx(lr.hero.hp, 78.0), "hurts=%d hp=%s" % [lr.hurts, lr.hero.hp])
	check("lunge carries the captain about 120 forward", absf((lc.position.y - origin_y) - 120.0) < 6.0, "moved=%s" % (lc.position.y - origin_y))
	lr.free_all()

	# Sidestep after the lock: no damage.
	var sp := captain_rig(Vector2(320, 425), Vector2(320, 300))
	var sr: Rig = sp[0]
	var sc: Enemy = sp[1]
	while not (sc.state == Enemy.State.WINDUP and sc.locked):
		sr.tick(0.005)
	sr.hero.position = Vector2(380, 425)
	while sc.state != Enemy.State.RECOVER and sc.state != Enemy.State.STAGGER:
		sr.tick(0.005)
	check("stepping out of the locked lunge wedge takes no damage", is_equal_approx(sr.hero.hp, 100.0), "hp=%s" % sr.hero.hp)
	sr.free_all()

	# Dodge i-frames cover the lunge's active frames when started on time.
	var dp := captain_rig(Vector2(320, 425), Vector2(320, 300))
	var dr: Rig = dp[0]
	var dc: Enemy = dp[1]
	while not (dc.state == Enemy.State.WINDUP and dc.state_time >= 0.78):
		dr.tick(0.005)
	dr.input.key_move = Vector2(0, -1)
	dr.input.press_dodge()
	while dc.state != Enemy.State.RECOVER and dc.state != Enemy.State.STAGGER:
		dr.tick(0.005)
	check("a dodge started 0.02 s before the lunge lands avoids it", is_equal_approx(dr.hero.hp, 100.0), "hp=%s" % dr.hero.hp)
	dr.free_all()


func kill_all(g: Game) -> void:
	for e in g.enemies:
		if not e.is_dead():
			e.take_hit(9999.0, e.position + Vector2(0, 10), 0.0)


func test_captain_flow() -> void:
	section("Wave, intermission, captain, victory")
	var g := make_game()
	g.start_fight(Game.Mode.THREE_CAPTAIN)
	g.hero.hp = 40.0
	g.hero.dodge_charges = 0
	kill_all(g)
	g.step(1.0 / 60.0)
	check("clearing the wave does not end the fight", g.state == Game.State.FIGHTING and g.outcome == Game.Outcome.NONE and g.intermission_active)
	check("breather heals 30 and refills dodges", is_equal_approx(g.hero.hp, 70.0) and g.hero.dodge_charges == g.hero.max_charges(), "hp=%s" % g.hero.hp)
	check("no captain yet", g.enemies_alive() == 0 and not g.captain_spawned)
	for i in int(1.8 * 60.0):
		g.step(1.0 / 60.0)
	check("still waiting at 1.8 s", g.enemies_alive() == 0 and g.intermission_active)
	for i in int(0.3 * 60.0):
		g.step(1.0 / 60.0)
	check("the captain appears after the 2.0 s breather", g.enemies_alive() == 1 and g.captain_alive() and g.captain_spawned and not g.intermission_active)
	var cap: Enemy = g.enemies.back()
	check("captain spawns at the far end from the hero", cap.position.distance_to(g.hero.position) > 150.0, "d=%.1f" % cap.position.distance_to(g.hero.position))
	check("captain has 150 HP and is bigger", is_equal_approx(cap.hp, 150.0) and cap.radius > 20.0)
	cap.take_hit(9999.0, cap.position, 0.0)
	g.step(1.0 / 60.0)
	check("killing the captain wins", g.state == Game.State.RESULT and g.outcome == Game.Outcome.VICTORY)

	g.start_fight(Game.Mode.THREE_CAPTAIN)
	g.hero.hp = 90.0
	kill_all(g)
	g.step(1.0 / 60.0)
	check("the heal never exceeds max health", is_equal_approx(g.hero.hp, 100.0))
	for i in 150:
		g.step(1.0 / 60.0)
	g.hero.take_hit(1000.0)
	g.step(1.0 / 60.0)
	check("dying to the captain is a defeat", g.outcome == Game.Outcome.DEFEAT)

	g.start_fight(Game.Mode.ONE)
	kill_all(g)
	g.step(1.0 / 60.0)
	check("1 enemy mode has no captain", g.outcome == Game.Outcome.VICTORY and not g.captain_spawned and not g.intermission_active)

	g.start_fight(Game.Mode.CAPTAIN_ONLY)
	check("captain-only starts with just the captain", g.enemies.size() == 1 and g.captain_alive() and g.outcome == Game.Outcome.NONE)
	kill_all(g)
	g.step(1.0 / 60.0)
	check("captain-only ends with the captain's death", g.outcome == Game.Outcome.VICTORY)

	# Weapon choice through the menu, and it survives Retry.
	g.menu.fight_requested.emit(Game.Mode.CAPTAIN_ONLY, 3, false)
	check("menu picks daggers and captain-only", g.mode == Game.Mode.CAPTAIN_ONLY and g.hero.weapon.id == "daggers" and g.hero.dodge_charges == 3 and g.captain_alive())
	g.start_fight(Game.Mode.ONE)
	check("Retry keeps the chosen weapon", g.hero.weapon.id == "daggers" and g.weapon_index == 3)
	g.start_fight(Game.Mode.ONE, 0)
	check("choosing the sword resets weapon stats", g.hero.weapon.id == "sword" and g.hero.dodge_charges == 2 and is_equal_approx(g.hero.move_speed(), 195.0))
	g.queue_free()


func test_scripted_player_per_weapon() -> void:
	section("Scripted player: 3 enemies, captain, victory with each weapon")
	for wi in 5:
		var g := make_game()
		g.tuning.hero_max_hp = 100000.0
		g.start_fight(Game.Mode.THREE_CAPTAIN, wi)
		play(g, 240.0, true)
		check("%s: full 3 + captain fight completes with a victory (inflated HP)" % g.weapon().display_name,
				g.outcome == Game.Outcome.VICTORY and g.captain_spawned, "outcome=%s t=%.1f" % [g.outcome, g.fight_time])
		print("        (%s, inflated HP: %.1f s)" % [g.weapon().display_name, g.fight_time])
		g.queue_free()
		var n := make_game()
		n.start_fight(Game.Mode.THREE_CAPTAIN, wi)
		play(n, 240.0, true)
		print("        (%s, normal HP: %s in %.1f s, hero hp %d, captain seen %s)" % [n.weapon().display_name, Game.Outcome.keys()[n.outcome], n.fight_time, ceili(n.hero.hp), n.captain_spawned])
		n.queue_free()


func test_block_input_and_layout() -> void:
	section("Block button, keyboard and layout")
	var inp := CombatInput.new()
	var c := make_controls(inp)
	var vp := Vector2(720, 1280)
	check("BLOCK button sits inside the control band", c.block_center.y - TouchControls.BLOCK_R >= c.band.position.y and c.block_center.y + TouchControls.BLOCK_R <= vp.y and c.block_center.x > vp.x * 0.5)
	check("BLOCK does not overlap ATTACK or DODGE", c.block_center.distance_to(c.attack_center) > TouchControls.BLOCK_R + TouchControls.ATTACK_R and c.block_center.distance_to(c.dodge_center) > TouchControls.BLOCK_R + TouchControls.DODGE_R)
	c._input(screen_touch(3, c.block_center, true))
	check("touching BLOCK raises the guard input", inp.block_down() and c.block_index == 3)
	c._input(screen_touch(3, c.block_center, false))
	check("lifting the finger lowers it", not inp.block_down() and c.block_index == -1)
	c._input(screen_touch(3, c.block_center, true))
	c._input(screen_drag(3, c.block_center + Vector2(0, -300)))
	check("sliding well off BLOCK lowers the guard", not inp.block_down())
	c._input(screen_touch(3, c.block_center, false))
	c.free()

	var inp2 := CombatInput.new()
	var c2 := make_controls(inp2)
	c2._input(screen_touch(0, c2.joy_hint, true))
	c2._input(screen_drag(0, c2.joy_hint + Vector2(80, 0)))
	c2._input(screen_touch(1, c2.block_center, true))
	c2._input(screen_touch(2, c2.attack_center, true))
	check("stick, BLOCK and ATTACK fingers all register at once", inp2.touch_move.x > 0.5 and inp2.block_down() and inp2.attack_down())
	c2._input(screen_touch(1, c2.block_center, false))
	check("lifting BLOCK leaves the stick and attack alone", not inp2.block_down() and inp2.attack_down() and inp2.touch_move.length() > 0.5)
	c2._input(screen_touch(1, c2.block_center, true))
	c2.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss clears the guard input and finger", not inp2.block_down() and c2.block_index == -1)
	c2.free()

	var g := make_game()
	g.start_fight(Game.Mode.ONE)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	g._input(key)
	check("K raises the guard", g.input.block_down())
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_K
	key_up.pressed = false
	g._input(key_up)
	check("releasing K lowers it", not g.input.block_down())
	g.queue_free()


func test_guard_rules() -> void:
	section("Raising and lowering the guard")
	var r := Rig.new(root, T)
	r.input.press_block(false)
	r.tick(0.01)
	check("block from idle", r.hero.state == Hero.State.BLOCK and r.hero.is_guarding())
	r.input.release_block(false)
	r.tick(0.01)
	check("lowering returns to idle", r.hero.state == Hero.State.IDLE)
	r.input.press_block(false)
	r.run(0.30, 0.01)
	check("re-raising right away is refused for 0.35 s", r.hero.state == Hero.State.IDLE)
	r.run(0.10, 0.01)
	check("then it goes up", r.hero.state == Hero.State.BLOCK)
	r.free_all()

	var c := Rig.new(root, T)
	c.input.press_attack(false)
	c.run(0.20, 0.01)
	c.input.press_block(false)
	c.tick(0.01)
	check("block cancels a charge", c.hero.state == Hero.State.BLOCK)
	c.input.release_attack(false)
	c.input.release_block(false)
	c.run(1.0)
	check("a cancelled charge never attacks", c.swings == 0)
	c.free_all()

	var w := Rig.new(root, T)
	w.input.press_attack(false)
	w.tick(0.005)
	w.input.release_attack(false)
	w.tick(0.005)
	check("the swing has started", w.hero.state == Hero.State.WINDUP)
	w.input.press_block(false)
	w.tick(0.005)
	check("block is refused during wind-up", w.hero.state == Hero.State.WINDUP)
	check("reaches the strike", w.until_state(Hero.State.ACTIVE))
	check("still refused during the strike", w.hero.state == Hero.State.ACTIVE)
	check("reaches recovery", w.until_state(Hero.State.RECOVER))
	check("still refused during recovery", w.hero.state == Hero.State.RECOVER)
	w.run(1.0)
	check("a guard held through the swing goes up when it ends", w.hero.state == Hero.State.BLOCK)
	w.free_all()

	var h := Rig.new(root, T)
	h.hero.take_hit(10.0)
	h.input.press_block(false)
	h.tick(0.01)
	check("block is refused while hurt", h.hero.state == Hero.State.HURT)
	h.run(0.3, 0.01)
	check("held guard goes up once hurt ends", h.hero.state == Hero.State.BLOCK)
	h.free_all()

	var d := Rig.new(root, T)
	d.input.press_block(false)
	d.tick(0.01)
	d.input.press_dodge()
	d.tick(0.01)
	check("dodge exits a block", d.hero.state == Hero.State.DODGE)
	d.run(0.4, 0.01)
	check("the guard does not snap back up straight after the dodge", d.hero.state == Hero.State.IDLE or d.hero.state == Hero.State.BLOCK)
	d.free_all()

	var a := Rig.new(root, T)
	a.input.press_block(false)
	a.tick(0.01)
	a.input.press_attack(false)
	a.tick(0.01)
	a.input.release_attack(false)
	a.tick(0.01)
	a.run(0.3, 0.01)
	check("attack presses are ignored while blocking", a.swings == 0 and a.hero.state == Hero.State.BLOCK)
	a.input.release_block(false)
	a.run(0.5)
	check("and not queued for later", a.swings == 0)
	a.free_all()

	var g := make_game()
	var sword: Weapon = g.weapons[0]
	for spec in [[false, false, 195.0], [false, true, 78.0], [true, false, 185.25], [true, true, 74.1]]:
		var m := Rig.new(root, T)
		m.use_weapon(sword, spec[0])
		m.hero.position = Vector2(500, 360)
		if spec[1]:
			m.input.press_block(false)
			m.tick(0.01)
		m.input.key_move = Vector2(-1, 0)
		m.run(0.4, 0.01)
		var x0 := m.hero.position.x
		m.run(1.0, 0.01)
		check("walking speed: shield %s, blocking %s -> %.1f" % [spec[0], spec[1], spec[2]], absf((x0 - m.hero.position.x) - spec[2]) < 1.5, "dx=%s" % (x0 - m.hero.position.x))
		m.free_all()
	g.queue_free()


func guard_rig(shield: bool, settle := 0.50, t: Tuning = null) -> Rig:
	var tu := t if t != null else T
	var r := Rig.new(root, tu, Vector2(320, 360))
	r.use_weapon(Weapon.sword_from(tu), shield)
	r.input.press_block(false)
	r.run(settle, 0.01)
	return r


func test_block_arc_and_costs() -> void:
	section("Guard arc, damage and guard cost")
	var atk := AttackDef.make("Test", 12.0, 50.0, 100.0, 0.65, 0.10, 0.65)
	# The arc is a tuning value, so the narrow-arc logic is still tested with 140 / 100 degrees.
	var narrow := T.duplicate() as Tuning
	narrow.block_arc_shield = 140.0
	narrow.block_arc_bare = 100.0
	var cases := [[true, 69.0, true], [true, 75.0, false], [false, 45.0, true], [false, 55.0, false], [true, 180.0, false], [false, 180.0, false]]
	for cs in cases:
		var r := guard_rig(cs[0], 0.50, narrow)
		var origin := r.hero.position + Vector2.UP.rotated(deg_to_rad(cs[1])) * 40.0
		var res := r.hero.receive_attack(12.0, origin, atk)
		var blocked := res == Hero.HitResult.BLOCKED
		check("narrow arc, %s guard vs a hit from %d degrees: %s" % ["shield" if cs[0] else "bare", int(cs[1]), "blocked" if cs[2] else "hit"],
				blocked == cs[2] and (res == Hero.HitResult.HIT) == (not cs[2]), "result=%d" % res)
		if not cs[2]:
			check("  an unblocked hit hurts and interrupts the guard", r.hero.state == Hero.State.HURT and is_equal_approx(r.hero.hp, 88.0))
		r.free_all()

	# Default: 360 degrees. Every direction is covered, whichever way the hero faces.
	check("default guard arc is 360 degrees, shield and bare", is_equal_approx(T.block_arc_shield, 360.0) and is_equal_approx(T.block_arc_bare, 360.0))
	for shield in [true, false]:
		var all_ok := true
		var bad_angles := []
		for deg in [0, 45, 90, 135, 179, 180, -179, -135, -90, -45, 1]:
			var rr := guard_rig(shield)
			var org := rr.hero.position + Vector2.UP.rotated(deg_to_rad(float(deg))) * 40.0
			var res_all := rr.hero.receive_attack(12.0, org, atk)
			if res_all != Hero.HitResult.BLOCKED or rr.hero.state != Hero.State.BLOCK:
				all_ok = false
				bad_angles.append(deg)
			rr.free_all()
		check("360 guard (%s): a hit from any of 11 directions, including behind, is blocked" % ("shield" if shield else "bare"), all_ok, str(bad_angles))
	var facing_rig := guard_rig(true)
	facing_rig.input.key_move = Vector2(1, 0)
	facing_rig.run(0.3, 0.01)
	var turned_res := facing_rig.hero.receive_attack(12.0, facing_rig.hero.position + Vector2(0, 40), atk)
	check("facing a different way changes nothing: still blocked", turned_res == Hero.HitResult.BLOCKED)
	facing_rig.free_all()

	var s := guard_rig(true)
	var res_s := s.hero.receive_attack(12.0, s.hero.position + Vector2(0, -40), atk)
	check("shield: blocked hit costs 12 guard and no health", res_s == Hero.HitResult.BLOCKED and is_equal_approx(s.hero.guard, 68.0) and is_equal_approx(s.hero.hp, 100.0))
	check("a block causes no hurt state and no immunity", s.hero.state == Hero.State.BLOCK and s.hero.immune_time == 0.0)
	s.free_all()
	var b := guard_rig(false)
	var res_b := b.hero.receive_attack(12.0, b.hero.position + Vector2(0, -40), atk)
	check("bare: 18 guard cost and 4.8 chip damage", res_b == Hero.HitResult.BLOCKED and is_equal_approx(b.hero.guard, 22.0) and is_equal_approx(b.hero.hp, 95.2), "guard=%s hp=%s" % [b.hero.guard, b.hero.hp])
	check("bare chip damage does not stagger", b.hero.state == Hero.State.BLOCK)
	b.free_all()

	# A real enemy strike is blocked once, not once per active frame.
	var e := guard_rig(true, 0.0)
	e.run_enemies = true
	var grunt := e.add_enemy(Vector2(320, 330))
	while grunt.state != Enemy.State.RECOVER and grunt.state != Enemy.State.STAGGER:
		e.tick(0.005)
	check("one enemy strike is one block: guard 68, no damage", is_equal_approx(e.hero.guard, 68.0) and is_equal_approx(e.hero.hp, 100.0) and e.hurts == 0, "guard=%s hp=%s" % [e.hero.guard, e.hero.hp])
	e.run(0.3)
	check("it stays at 68 after the strike ends", is_equal_approx(e.hero.guard, 68.0))
	e.free_all()

	# The drawn guard area equals the guard test: a full ring at 360, a wedge when narrowed.
	for shield in [true, false]:
		for arc_deg in [360.0, 140.0, 100.0]:
			var tw := T.duplicate() as Tuning
			tw.block_arc_shield = arc_deg
			tw.block_arc_bare = arc_deg
			var gr := guard_rig(shield, 0.50, tw)
			var arc := gr.hero.guard_arc()
			var poly := HitShapes.sector_polygon(gr.hero.facing, 50.0, arc) if arc < 360.0 else PackedVector2Array()
			var bad := 0
			for deg in range(0, 360):
				var edge_gap := absf(absf(deg if deg <= 180 else deg - 360) - arc * 0.5)
				if arc < 360.0 and edge_gap < 0.6:
					continue
				var dir := Vector2.UP.rotated(deg_to_rad(float(deg)))
				var inside := true if arc >= 360.0 else Geometry2D.is_point_in_polygon(dir * 30.0, poly)
				if inside != gr.hero._in_guard_arc(gr.hero.position + dir * 30.0):
					bad += 1
			check("%s guard area matches the block test at %d degrees" % ["shield" if shield else "bare", int(arc)], bad == 0, "bad=%d" % bad)
			gr.free_all()


func test_guard_break_and_regen() -> void:
	section("Guard break and regeneration")
	var atk := AttackDef.make("Test", 12.0, 50.0, 100.0, 0.65, 0.10, 0.65)
	var r := guard_rig(true)
	r.hero.guard = 10.0
	var res := r.hero.receive_attack(12.0, r.hero.position + Vector2(0, -40), atk)
	check("an emptying block is still absorbed", res == Hero.HitResult.BLOCKED and is_equal_approx(r.hero.hp, 100.0))
	check("then the guard breaks and you are stunned", r.hero.state == Hero.State.GUARD_BREAK and r.hero.guard == 0.0)
	r.input.press_attack(false)
	r.input.press_dodge()
	r.tick(0.01)
	check("no actions during the stun", r.hero.state == Hero.State.GUARD_BREAK and r.swings == 0)
	r.run(0.4, 0.01)
	check("still stunned at 0.4 s", r.hero.state == Hero.State.GUARD_BREAK)
	var open := r.hero.receive_attack(12.0, r.hero.position + Vector2(0, -40), atk)
	check("a hit during the stun lands", open == Hero.HitResult.HIT and is_equal_approx(r.hero.hp, 88.0))
	r.free_all()

	var b := guard_rig(true)
	b.hero.guard = 10.0
	b.hero.receive_attack(12.0, b.hero.position + Vector2(0, -40), atk)
	b.input.release_block(false)
	b.run(0.9, 0.01)
	check("the stun lasts 0.8 s and leaves guard at 50%", b.hero.state == Hero.State.IDLE and is_equal_approx(b.hero.guard, 40.0), "state=%d guard=%s" % [b.hero.state, b.hero.guard])
	b.free_all()

	var g := guard_rig(true)
	g.hero.receive_attack(12.0, g.hero.position + Vector2(0, -40), atk)
	g.input.release_block(false)
	g.tick(0.01)
	var base := g.hero.guard
	g.run(0.5, 0.01)
	check("no regeneration for 0.6 s after a block", is_equal_approx(g.hero.guard, base), "guard=%s base=%s" % [g.hero.guard, base])
	g.run(1.0, 0.01)
	check("then 25 per second", absf(g.hero.guard - minf(80.0, base + 25.0 * 0.9)) < 1.0, "guard=%s" % g.hero.guard)
	g.free_all()

	var h := guard_rig(true)
	h.hero.guard = 20.0
	h.run(2.0, 0.01)
	check("no regeneration while the guard is held up", is_equal_approx(h.hero.guard, 20.0))
	h.free_all()


func parry_rig(shield: bool, cap: bool, lead: float, behind := false, immune := false, w: Weapon = null) -> Array:
	## Enemy adjacent to the hero (in front, or behind it); the hero raises the guard `lead`
	## seconds before the strike.
	var r := Rig.new(root, T, Vector2(320, 360))
	r.use_weapon(w if w != null else Weapon.sword_from(T), shield)
	r.run_enemies = true
	var prof: EnemyProfile = (load("res://resources/captain.tres") as EnemyProfile) if cap else null
	var e := r.add_enemy(Vector2(320, 390) if behind else Vector2(320, 330), 0, prof)
	if immune:
		e.stagger_immune = 10.0  # as if it had only just woken from a stagger
	if cap:
		e.pattern_pos = 1  # first the slash
	while not (e.state == Enemy.State.WINDUP):
		r.tick(0.005)
	var target: float = e.cur.windup - lead
	while e.state_time < target - 0.0001:
		r.tick(0.005)
	r.input.press_block(false)
	while e.state != Enemy.State.RECOVER and e.state != Enemy.State.STAGGER and e.state != Enemy.State.DEAD:
		r.tick(0.005)
	return [r, e]


## A plain block leaves the attacker in a fixed stun that a hit does not end.
func block_stunned(e: Enemy, length := 1.2) -> bool:
	return e.state == Enemy.State.STAGGER and not e.stagger_wakes and is_equal_approx(e.stagger_total, length)


func parried(e: Enemy) -> bool:
	return e.state == Enemy.State.STAGGER and e.stagger_wakes


func test_parry() -> void:
	section("Parry")
	var p1 := parry_rig(true, false, 0.10)
	var r1: Rig = p1[0]
	var e1: Enemy = p1[1]
	check("raising the guard 0.10 s before the hit parries it (shield)", e1.state == Enemy.State.STAGGER and is_equal_approx(r1.hero.hp, 100.0))
	check("a parry costs no guard", is_equal_approx(r1.hero.guard, 80.0))
	check("the parried enemy's commitment is released", r1.ctrl.count() == 0)
	check("a parry freezes for 3.0 s", is_equal_approx(e1.stagger_total, 3.0) and e1.stagger_left > 2.9)
	r1.free_all()

	var p2 := parry_rig(true, false, 0.50)
	check("raising it 0.50 s early is an ordinary block (mini stun, not a parry)", block_stunned(p2[1]) and is_equal_approx(p2[0].hero.guard, 68.0) and is_equal_approx(p2[0].hero.hp, 100.0))
	p2[0].free_all()

	var p3 := parry_rig(true, false, 0.35)
	check("0.35 s before the hit still parries with a shield (window 0.40)", parried(p3[1]) and is_equal_approx(p3[0].hero.guard, 80.0))
	p3[0].free_all()
	var p3b := parry_rig(true, false, 0.45)
	check("0.45 s before the hit is only a block with a shield", block_stunned(p3b[1]))
	p3b[0].free_all()
	var p4 := parry_rig(false, false, 0.40)
	check("0.40 s before the hit does not parry bare-handed (window 0.32)", block_stunned(p4[1]) and is_equal_approx(p4[0].hero.guard, 22.0))
	p4[0].free_all()
	var p4c := parry_rig(false, false, 0.30)
	check("0.30 s before the hit parries bare-handed", parried(p4c[1]) and is_equal_approx(p4c[0].hero.guard, 40.0))
	p4c[0].free_all()
	var p4b := parry_rig(false, false, 0.18)
	check("0.18 s before the hit parries bare-handed", p4b[1].state == Enemy.State.STAGGER)
	p4b[0].free_all()
	var p5 := parry_rig(false, false, 0.08)
	check("0.08 s before the hit parries bare-handed", p5[1].state == Enemy.State.STAGGER and is_equal_approx(p5[0].hero.hp, 100.0) and is_equal_approx(p5[0].hero.guard, 40.0))
	p5[0].free_all()

	# From behind: the hero faces up, the grunt stands below.
	var pb := parry_rig(true, false, 0.10, true)
	check("a parry works against an attacker behind you", pb[1].state == Enemy.State.STAGGER and is_equal_approx(pb[0].hero.hp, 100.0) and is_equal_approx(pb[0].hero.guard, 80.0))
	pb[0].free_all()
	var bb := parry_rig(true, false, 0.50, true)
	check("a plain block works against an attacker behind you: guard 68, no damage", block_stunned(bb[1]) and is_equal_approx(bb[0].hero.guard, 68.0) and is_equal_approx(bb[0].hero.hp, 100.0), "guard=%s hp=%s" % [bb[0].hero.guard, bb[0].hero.hp])
	bb[0].free_all()
	var bare_behind := parry_rig(false, false, 0.50, true)
	check("bare-handed, a hit from behind is blocked too: guard 22, 4.8 chip", block_stunned(bare_behind[1]) and is_equal_approx(bare_behind[0].hero.guard, 22.0) and is_equal_approx(bare_behind[0].hero.hp, 95.2), "guard=%s hp=%s" % [bare_behind[0].hero.guard, bare_behind[0].hero.hp])
	bare_behind[0].free_all()

	var c1 := parry_rig(true, true, 0.10)
	var cr: Rig = c1[0]
	var ce: Enemy = c1[1]
	check("the captain can be parried, for 18 damage avoided", ce.state == Enemy.State.STAGGER and is_equal_approx(cr.hero.hp, 100.0))
	check("the captain freezes for 3.0 s too", is_equal_approx(ce.stagger_total, 3.0))
	cr.free_all()

	# Parrying the first combo hit cancels the second.
	var cp := Rig.new(root, T, Vector2(320, 360))
	cp.use_weapon(Weapon.sword_from(T), true)
	cp.run_enemies = true
	var combo := cp.add_enemy(Vector2(320, 330), 0, load("res://resources/captain.tres") as EnemyProfile)
	combo.pattern_pos = 2
	while combo.state != Enemy.State.WINDUP:
		cp.tick(0.005)
	while combo.state_time < combo.cur.windup - 0.10:
		cp.tick(0.005)
	cp.input.press_block(false)
	var saw_second := false
	var t_end := cp.time + 1.2
	while cp.time < t_end:
		cp.tick(0.005)
		if combo.cur.label == "Combo 2" and combo.state == Enemy.State.WINDUP:
			saw_second = true
	check("parrying combo hit 1 cancels hit 2", not saw_second and is_equal_approx(cp.hero.hp, 100.0))
	cp.free_all()


func test_captain_vs_guard() -> void:
	section("Captain attacks against a guard")
	# Hold the guard from the start so every hit is a plain block (past the parry window).
	var lunge_pos := [Vector2(320, 425), Vector2(320, 300)]
	for shield in [true, false]:
		var pair := captain_rig(lunge_pos[0], lunge_pos[1])
		var r: Rig = pair[0]
		var c: Enemy = pair[1]
		r.use_weapon(Weapon.sword_from(T), shield)
		r.input.press_block(false)
		while not (c.state == Enemy.State.WINDUP and c.cur.label == "Lunge"):
			r.tick(0.005)
		while c.state != Enemy.State.RECOVER and c.state != Enemy.State.STAGGER:
			r.tick(0.005)
		if shield:
			check("lunge vs shield: blocked, costs 44 of 80 guard, no damage", is_equal_approx(r.hero.hp, 100.0) and is_equal_approx(r.hero.guard, 36.0), "hp=%s guard=%s" % [r.hero.hp, r.hero.guard])
		else:
			check("lunge vs a bare guard: breaks through for the full 22, guard untouched", is_equal_approx(r.hero.hp, 78.0) and is_equal_approx(r.hero.guard, 40.0), "hp=%s guard=%s" % [r.hero.hp, r.hero.guard])
		r.free_all()

	var parry_lunge := [true, false]
	for shield in parry_lunge:
		var pair2 := captain_rig(lunge_pos[0], lunge_pos[1])
		var r2: Rig = pair2[0]
		var c2: Enemy = pair2[1]
		r2.use_weapon(Weapon.sword_from(T), shield)
		while not (c2.state == Enemy.State.WINDUP and c2.cur.label == "Lunge"):
			r2.tick(0.005)
		while c2.state_time < 0.72:
			r2.tick(0.005)
		r2.input.press_block(false)
		while c2.state != Enemy.State.RECOVER and c2.state != Enemy.State.STAGGER:
			r2.tick(0.005)
		check("a parry beats the lunge (%s)" % ("shield" if shield else "bare"), c2.state == Enemy.State.STAGGER and is_equal_approx(r2.hero.hp, 100.0), "state=%d hp=%s" % [c2.state, r2.hero.hp])
		r2.free_all()

	# Slash and combo against a held guard.
	var sp := captain_rig(Vector2(320, 360), Vector2(320, 330))
	var sr: Rig = sp[0]
	var sc: Enemy = sp[1]
	sr.use_weapon(Weapon.sword_from(T), false)
	sr.input.press_block(false)
	while sc.state != Enemy.State.RECOVER and sc.state != Enemy.State.STAGGER:
		sr.tick(0.005)
	check("slash vs a bare guard: 7.2 chip damage, 27 guard", is_equal_approx(sr.hero.hp, 92.8) and is_equal_approx(sr.hero.guard, 13.0), "hp=%s guard=%s" % [sr.hero.hp, sr.hero.guard])
	sr.free_all()

	var cp := captain_rig(Vector2(320, 360), Vector2(320, 330))
	var cr: Rig = cp[0]
	var cc: Enemy = cp[1]
	cr.use_weapon(Weapon.sword_from(T), true)
	cc.pattern_pos = 2
	cr.input.press_block(false)
	var steps := 0
	while steps < 2000 and cc.state != Enemy.State.POSITION:
		cr.tick(0.005)
		steps += 1
	check("combo vs a shield: hit 1 is blocked (14 guard), the stun cancels hit 2, no damage", is_equal_approx(cr.hero.hp, 100.0) and is_equal_approx(cr.hero.guard, 66.0), "hp=%s guard=%s" % [cr.hero.hp, cr.hero.guard])
	cr.free_all()


func test_shield_equipment() -> void:
	section("Shield equipment")
	var g := make_game()
	var sword: Weapon = g.weapons[0]
	var spear: Weapon = g.weapons[1]
	var axe: Weapon = g.weapons[2]
	var daggers: Weapon = g.weapons[3]
	var zwei_w: Weapon = g.weapons[4]
	check("sword and spear are one-handed, axe, daggers and zweihander are not", sword.one_handed and spear.one_handed and not axe.one_handed and not daggers.one_handed and not zwei_w.one_handed)
	g.hero.equip(sword, true)
	check("shield with the sword: arc 360, guard 80, window 0.40", g.hero.has_shield and is_equal_approx(g.hero.guard_arc(), 360.0) and is_equal_approx(g.hero.guard_max(), 80.0) and is_equal_approx(g.hero.parry_window(), 0.40))
	g.hero.equip(axe, true)
	check("shield with the axe is ignored: arc 360, guard 40, window 0.32", not g.hero.has_shield and is_equal_approx(g.hero.guard_arc(), 360.0) and is_equal_approx(g.hero.guard_max(), 40.0) and is_equal_approx(g.hero.parry_window(), 0.32))

	g.menu.set_weapon(0)
	g.menu.set_shield(true)
	check("menu: the shield toggle works for the sword", not g.menu._shield_button.disabled and g.menu.shield_usable())
	g.menu.set_weapon(2)
	check("menu: the toggle is disabled for the axe and the shield is unusable", g.menu._shield_button.disabled and not g.menu.shield_usable())
	g.menu.set_weapon(3)
	check("menu: also disabled for the daggers", g.menu._shield_button.disabled and not g.menu.shield_usable())
	g.menu.set_weapon(4)
	check("menu: also disabled for the zweihander", g.menu._shield_button.disabled and not g.menu.shield_usable())
	g.menu.set_weapon(1)
	check("menu: back on for the spear, choice remembered", not g.menu._shield_button.disabled and g.menu.shield_usable())

	g.menu.fight_requested.emit(Game.Mode.ONE, 0, true)
	check("starting with a shield equips it", g.shield_on and g.hero.has_shield and is_equal_approx(g.hero.guard, 80.0) and g.loadout_name() == "Sword + Shield")
	g.start_fight(Game.Mode.ONE)
	check("Retry keeps the shield", g.hero.has_shield)
	g.hero.guard = 5.0
	g.input.press_block(false)
	g.start_fight(Game.Mode.ONE)
	check("Retry restores guard and clears the held guard", is_equal_approx(g.hero.guard, 80.0) and not g.input.block_down() and g.hero.state == Hero.State.IDLE)
	g.menu.fight_requested.emit(Game.Mode.ONE, 2, true)
	check("a two-handed weapon drops the shield even if asked", not g.hero.has_shield and g.loadout_name() == "Axe")
	g.queue_free()


func test_blocking_player() -> void:
	section("Scripted blocking player")
	for wi in [0, 1]:
		var inflated := make_game()
		inflated.tuning.hero_max_hp = 100000.0
		inflated.shield_on = true
		inflated.start_fight(Game.Mode.THREE_CAPTAIN, wi)
		var counts := [0, 0, 0]
		inflated.hero.blocked.connect(func(was_parry: bool): counts[1 if was_parry else 0] += 1)
		inflated.hero.guard_broken.connect(func(): counts[2] += 1)
		play(inflated, 240.0, true, true)
		check("%s + Shield: 3 enemies and the captain are beaten by a blocking player (inflated HP)" % inflated.weapon().display_name,
				inflated.outcome == Game.Outcome.VICTORY and inflated.captain_spawned, "outcome=%s t=%.1f" % [inflated.outcome, inflated.fight_time])
		check("  the run actually used blocks and parries", counts[0] + counts[1] > 0, str(counts))
		print("        (%s + Shield, blocking bot, inflated HP: %.1f s, %d blocks, %d parries, %d guard breaks)" % [inflated.weapon().display_name, inflated.fight_time, counts[0], counts[1], counts[2]])
		inflated.queue_free()
		var normal := make_game()
		normal.shield_on = true
		normal.start_fight(Game.Mode.THREE_CAPTAIN, wi)
		var n_counts := [0, 0, 0]
		normal.hero.blocked.connect(func(was_parry: bool): n_counts[1 if was_parry else 0] += 1)
		normal.hero.guard_broken.connect(func(): n_counts[2] += 1)
		play(normal, 240.0, true, true)
		print("        (%s + Shield, blocking bot, normal HP: %s in %.1f s, hero hp %d, %d blocks, %d parries, %d guard breaks)" % [normal.weapon().display_name, Game.Outcome.keys()[normal.outcome], normal.fight_time, ceili(normal.hero.hp), n_counts[0], n_counts[1], n_counts[2]])
		normal.queue_free()


func test_stagger_freeze_and_wake() -> void:
	section("Parry freeze: 3 s, or until hit")
	for cap in [false, true]:
		var p := parry_rig(true, cap, 0.10)
		var r: Rig = p[0]
		var e: Enemy = p[1]
		var who := "captain" if cap else "grunt"
		var pos0 := e.position
		check("%s: parried into a stagger with a 3.0 s timer" % who, e.state == Enemy.State.STAGGER and is_equal_approx(e.stagger_total, 3.0) and e.stagger_left > 2.95)
		r.run(1.0)
		check("%s: timer counts down (about 2.0 left after 1 s)" % who, absf(e.stagger_left - 2.0) < 0.03, "left=%s" % e.stagger_left)
		r.run(1.8)
		check("%s: still frozen at 2.8 s, has not moved or attacked" % who, e.state == Enemy.State.STAGGER and e.position == pos0 and r.hurts == 0 and is_equal_approx(r.hero.hp, 100.0))
		r.run(0.3)
		check("%s: wakes at 3.0 s into waiting, with the 0.35 s gap" % who, e.state == Enemy.State.POSITION and e.cooldown <= T.enemy_attack_gap + 0.001 and e.stagger_left == 0.0)
		r.free_all()

	# A hit ends it at once, for x2.0.
	var w := parry_rig(true, false, 0.10)
	var wr: Rig = w[0]
	var we: Enemy = w[1]
	wr.run(1.0)
	var hp0 := we.hp
	we.take_hit(10.0, wr.hero.position, 0.0)
	check("a light hit on a frozen enemy does x2.0 (20)", is_equal_approx(hp0 - we.hp, 20.0), "dmg=%s" % (hp0 - we.hp))
	check("and wakes it at once, with the attack gap and re-stagger immunity", we.state == Enemy.State.POSITION and we.stagger_left == 0.0 and we.cooldown <= T.enemy_attack_gap + 0.001 and is_equal_approx(we.stagger_immune, 1.0))
	var hp1 := we.hp
	we.take_hit(10.0, wr.hero.position, 0.0)
	check("the next hit is ordinary damage", is_equal_approx(hp1 - we.hp, 10.0))
	wr.free_all()

	# Small hits are doubled too, and a later hit can finish the enemy.
	var k := parry_rig(true, false, 0.10)
	k[1].hp = 5.0
	k[1].take_hit(1.0, k[0].hero.position, 0.0)
	check("the x2.0 applies to small hits too (1 becomes 2) and still wakes it", is_equal_approx(k[1].hp, 3.0) and k[1].state == Enemy.State.POSITION)
	k[1].take_hit(10.0, k[0].hero.position, 0.0)
	check("a following hit can finish it", k[1].is_dead())
	k[0].free_all()


func test_frozen_not_pushed() -> void:
	section("A frozen enemy is held in place")
	var g := make_game()
	g.tuning.hero_max_hp = 100000.0
	g.start_fight(Game.Mode.ONE)
	var frozen: Enemy = g.enemies[0]
	frozen.stagger(3.0)
	var spot := frozen.position
	var other := g._add_enemy(spot + Vector2(3, 3), 1, null)
	g.hero.position = spot + Vector2(-4, 2)
	for i in 30:
		g.step(1.0 / 60.0)
	check("bodies overlapping a frozen enemy do not push it", frozen.position == spot and frozen.state == Enemy.State.STAGGER)
	check("the other enemy is the one that gets shoved apart", other.position.distance_to(spot) > 3.0 * 1.4143 + 1.0)
	g.input.key_move = Vector2(-1, 0)
	for i in 20:
		g.step(1.0 / 60.0)
	check("hero walking into a frozen enemy leaves it where it was", frozen.position == spot)
	g.queue_free()


func heavy_hit(w: Weapon) -> Rig:
	## A grunt directly ahead takes a real heavy attack. The grunt is not stepped, so only the
	## hit decides its state.
	var r := Rig.new(root, T)
	r.use_weapon(w)
	var e := r.add_enemy(r.hero.position + Vector2(0, -w.heavy.reach * 0.6))
	e.hp = 1000.0
	r.input.press_attack(false)
	r.run(0.5, 0.01)
	r.input.release_attack(false)
	r.run(0.4)
	return r


func test_heavy_stagger() -> void:
	section("Heavy hits stagger; light hits do not")
	var sword := Weapon.sword_from(T)
	var hr := heavy_hit(sword)
	var he: Enemy = hr.enemies[0]
	check("a heavy hit staggers a grunt for 1.0 s", he.state == Enemy.State.STAGGER and is_equal_approx(he.stagger_total, 1.0) and he.stagger_left > 0.0, "state=%d total=%s" % [he.state, he.stagger_total])
	check("the heavy's own damage is ordinary (25) and knockback still applies", is_equal_approx(he.hp, 975.0))
	hr.free_all()

	var lr := Rig.new(root, T)
	var le := lr.add_enemy(lr.hero.position + Vector2(0, -45))
	le.hp = 1000.0
	lr.input.press_attack(false)
	lr.tick(0.005)
	lr.input.release_attack(false)
	lr.run(1.0)
	check("a light hit damages but does not stagger", le.state != Enemy.State.STAGGER and is_equal_approx(le.hp, 990.0))
	lr.free_all()

	# Two enemies in the arc are both staggered.
	var two := Rig.new(root, T)
	two.use_weapon(sword)
	var t1 := two.add_enemy(Vector2(320, 450))
	var t2 := two.add_enemy(Vector2(345, 455), 1)
	t1.hp = 1000.0
	t2.hp = 1000.0
	two.input.press_attack(false)
	two.run(0.5, 0.01)
	two.input.release_attack(false)
	two.run(0.4)
	check("a heavy that hits two enemies staggers both", t1.state == Enemy.State.STAGGER and t2.state == Enemy.State.STAGGER)
	two.free_all()

	# It interrupts a strike.
	var wr := Rig.new(root, T, Vector2(320, 500))
	wr.run_enemies = true
	var winder := wr.add_enemy(Vector2(320, 470))
	while winder.state != Enemy.State.WINDUP:
		wr.tick(0.005)
	while winder.state_time < 0.4:
		wr.tick(0.005)
	check("the grunt holds a commitment mid wind-up", wr.ctrl.count() == 1)
	winder.take_hit(25.0, wr.hero.position, 35.0, 1.0)
	check("a heavy hit cancels the wind-up and releases the slot", winder.state == Enemy.State.STAGGER and wr.ctrl.count() == 0)
	wr.hero.position = Vector2(320, 360)  # knockback moved it; stand right beside it again
	winder.position = Vector2(320, 330)
	wr.run(0.9)
	check("the interrupted strike never lands", is_equal_approx(wr.hero.hp, 100.0) and wr.hurts == 0)
	wr.free_all()

	# The captain is staggered more briefly.
	var cr := Rig.new(root, T, Vector2(320, 500))
	var cap := cr.add_enemy(Vector2(320, 300), 0, load("res://resources/captain.tres") as EnemyProfile)
	cap.take_hit(25.0, cr.hero.position, 35.0, 1.0)
	check("a heavy hit staggers the captain for 0.5 s", cap.state == Enemy.State.STAGGER and is_equal_approx(cap.stagger_total, 0.5))
	cr.free_all()

	# A profile with no heavy stagger is never staggered by a heavy.
	var rr := Rig.new(root, T, Vector2(320, 500))
	var none_profile := EnemyProfile.grunt_from(T)
	none_profile.heavy_stagger_mult = 0.0
	var tough := rr.add_enemy(Vector2(320, 300), 0, none_profile)
	tough.hp = 1000.0
	tough.take_hit(25.0, rr.hero.position, 35.0, 1.0)
	check("heavy_stagger_mult = 0 turns the heavy stagger off", tough.state != Enemy.State.STAGGER)
	rr.free_all()

	# No stun-lock.
	var ir := Rig.new(root, T, Vector2(320, 500))
	ir.run_enemies = true
	var ie := ir.add_enemy(Vector2(320, 150))
	ie.hp = 1000.0
	ie.cooldown = 1000.0
	ie.take_hit(25.0, ir.hero.position, 0.0, 1.0)
	check("first heavy: staggered", ie.state == Enemy.State.STAGGER)
	ir.run(1.05)
	check("it wakes after 1.0 s and cannot be heavy-staggered for 1.0 s", ie.state != Enemy.State.STAGGER and ie.stagger_immune > 0.9)
	ie.take_hit(25.0, ir.hero.position, 0.0, 1.0)
	check("a heavy inside the window damages but does not stagger", ie.state != Enemy.State.STAGGER and is_equal_approx(ie.hp, 950.0))
	ir.run(1.0)
	ie.take_hit(25.0, ir.hero.position, 0.0, 1.0)
	check("a heavy after the window staggers again", ie.state == Enemy.State.STAGGER)
	ir.free_all()

	# A heavy waking a parry-frozen enemy: x2.0, no re-stagger.
	var pr := parry_rig(true, true, 0.10)
	var pe: Enemy = pr[1]
	pr[0].run(0.5)
	var before := pe.hp
	pe.take_hit(25.0, pr[0].hero.position, 35.0, 1.0)
	check("a heavy on a parry-frozen captain does x2.0 (50)", is_equal_approx(before - pe.hp, 50.0), "dmg=%s" % (before - pe.hp))
	check("and does not stagger it again", pe.state == Enemy.State.POSITION)
	pr[0].free_all()

	# A parry ignores the re-stagger window.
	var im := parry_rig(true, false, 0.10, false, true)
	check("a parry still works on an enemy inside the immunity window", im[1].state == Enemy.State.STAGGER and is_equal_approx(im[1].stagger_total, 3.0))
	im[0].free_all()


func test_weapon_stagger_lengths() -> void:
	section("The stagger timer differs by weapon")
	var list: Array[Weapon] = [Weapon.sword_from(T), load("res://resources/weapons/spear.tres") as Weapon,
			load("res://resources/weapons/axe.tres") as Weapon, load("res://resources/weapons/daggers.tres") as Weapon,
			load("res://resources/weapons/zweihander.tres") as Weapon]
	var parry_expect := [3.0, 3.5, 2.5, 2.0, 3.0]
	var heavy_expect := [1.0, 0.8, 1.5, 0.6, 1.3]
	var stun_expect := [1.2, 1.4, 1.6, 0.8, 1.4]
	for i in list.size():
		var w: Weapon = list[i]
		# Parry: shield for the one-handed weapons, bare-handed for the others; raised 0.08 s early.
		var p := parry_rig(w.one_handed, false, 0.08, false, false, w)
		if w.parry_kill:
			check("%s parry kills a grunt outright" % w.display_name, p[1].is_dead())
		else:
			check("%s parry freezes a grunt for %.1f s" % [w.display_name, parry_expect[i]], parried(p[1]) and is_equal_approx(p[1].stagger_total, parry_expect[i]), "total=%s" % p[1].stagger_total)
		p[0].free_all()
		var c := parry_rig(w.one_handed, true, 0.08, false, false, w)
		check("%s parry freezes the captain for %.1f s too" % [w.display_name, parry_expect[i]], parried(c[1]) and is_equal_approx(c[1].stagger_total, parry_expect[i]))
		check("%s parry %s the captain" % [w.display_name, "takes 60 HP off" if w.parry_kill else "does not damage"], is_equal_approx(c[1].hp, 90.0 if w.parry_kill else 150.0), "hp=%s" % c[1].hp)
		c[0].free_all()
		var bs := parry_rig(w.one_handed, false, 0.60, false, false, w)
		check("%s block stuns a grunt for %.1f s" % [w.display_name, stun_expect[i]], block_stunned(bs[1], stun_expect[i]), "state=%d wakes=%s total=%s" % [bs[1].state, bs[1].stagger_wakes, bs[1].stagger_total])
		bs[0].free_all()
		var h := heavy_hit(w)
		check("%s heavy staggers a grunt for %.1f s" % [w.display_name, heavy_expect[i]], h.enemies[0].state == Enemy.State.STAGGER and is_equal_approx(h.enemies[0].stagger_total, heavy_expect[i]), "state=%d total=%s" % [h.enemies[0].state, h.enemies[0].stagger_total])
		h.free_all()
		var light := Rig.new(root, T)
		light.use_weapon(w)
		var lt := light.add_enemy(light.hero.position + Vector2(0, -w.light.reach * 0.6))
		lt.hp = 1000.0
		light.input.press_attack(false)
		light.tick(0.005)
		light.input.release_attack(false)
		light.run(1.0)
		check("%s light hit never staggers" % w.display_name, lt.state != Enemy.State.STAGGER and lt.hp < 1000.0)
		light.free_all()
	# The captain halves heavy staggers, whichever weapon caused them.
	var cr := Rig.new(root, T, Vector2(320, 500))
	var captain := cr.add_enemy(Vector2(320, 300), 0, load("res://resources/captain.tres") as EnemyProfile)
	captain.take_hit(25.0, cr.hero.position, 0.0, list[2].heavy_stagger_time)
	check("an axe heavy staggers the captain for 0.75 s (1.5 x 0.5)", captain.state == Enemy.State.STAGGER and is_equal_approx(captain.stagger_total, 0.75))
	cr.free_all()


func test_parry_timing_sweep() -> void:
	section("Parry timing sweep: raise the guard 0.02 to 0.60 s before a grunt's strike")
	for shield in [true, false]:
		var window := T.parry_window_shield if shield else T.parry_window_bare
		var parried_at := []
		var blocked := []
		var hit := []
		var lead := 0.02
		while lead <= 0.60 + 0.0001:
			var p := parry_rig(shield, false, lead)
			var e: Enemy = p[1]
			var r: Rig = p[0]
			if parried(e):
				parried_at.append(lead)
			elif r.hero.hp < 100.0 - 0.001 and r.hurts > 0:
				hit.append(lead)
			else:
				blocked.append(lead)
			r.free_all()
			lead += 0.02
		var name := "shield" if shield else "bare"
		var lo_p: float = parried_at.min() if parried_at.size() > 0 else -1.0
		var hi_p: float = parried_at.max() if parried_at.size() > 0 else -1.0
		print("        (%s: parried at %.2f to %.2f s early, blocked beyond, %d of 30 timings took a hit)" % [name, lo_p, hi_p, hit.size()])
		check("%s: every timing from 0.04 s to just inside the window (%.2f s) is a parry" % [name, window - 0.02],
				_all_in(parried_at, 0.04, window - 0.02), str(parried_at))
		check("%s: every timing from just past the window to 0.60 s is a plain block, never a hit" % name,
				_all_in(blocked, window + 0.02, 0.60) and hit.is_empty(), "hit=%s" % str(hit))
		check("%s: the parry band is wide enough to hit by reaction (%d timings, 0.02 s apart)" % [name, parried_at.size()],
				parried_at.size() >= int(window / 0.02) - 2)


func test_block_stun() -> void:
	section("Block mini stun")
	var p := parry_rig(true, false, 0.50)
	var r: Rig = p[0]
	var e: Enemy = p[1]
	check("a blocked grunt is staggered for exactly 1.2 s", block_stunned(e) and e.stagger_left > 1.15)
	check("the stun released its commitment slot", r.ctrl.count() == 0)
	var pos0 := e.position
	r.run(0.5)
	var hp0 := e.hp
	e.take_hit(10.0, r.hero.position, 0.0)
	check("a hit during the stun does ordinary damage (no x2.0 bonus)", is_equal_approx(hp0 - e.hp, 10.0), "dmg=%s" % (hp0 - e.hp))
	check("and does not end the stun", e.state == Enemy.State.STAGGER and e.position == pos0)
	r.run(0.6)
	check("still stunned at 1.1 s", e.state == Enemy.State.STAGGER)
	r.run(0.2)
	check("wakes at 1.2 s into waiting", e.state == Enemy.State.POSITION and e.cooldown <= T.enemy_attack_gap + 0.001)
	r.free_all()

	# A heavy hit is a different stagger: it still wakes a stunned enemy? No: a block stun is
	# fixed, so only the heavy's own stagger can replace it.
	var q := parry_rig(true, false, 0.50)
	q[1].take_hit(25.0, q[0].hero.position, 0.0, 1.0)
	check("a heavy on a block-stunned grunt re-staggers it, not x2.0", q[1].state == Enemy.State.STAGGER)
	q[0].free_all()

	# The captain's lunge is not stunned by a block.
	var pair := captain_rig(Vector2(320, 425), Vector2(320, 300))
	var lr: Rig = pair[0]
	var lc: Enemy = pair[1]
	lr.use_weapon(Weapon.sword_from(T), true)
	lr.input.press_block(false)
	while not (lc.state == Enemy.State.WINDUP and lc.cur.label == "Lunge"):
		lr.tick(0.005)
	while lc.state != Enemy.State.RECOVER and lc.state != Enemy.State.STAGGER:
		lr.tick(0.005)
	check("a blocked lunge does not stun the captain", lc.state == Enemy.State.RECOVER)
	lr.free_all()

	# A block that breaks the guard gives no stun.
	var br := guard_rig(true, 0.5)
	br.run_enemies = true
	var grunt := br.add_enemy(Vector2(320, 330))
	br.hero.guard = 10.0
	while grunt.state != Enemy.State.RECOVER and grunt.state != Enemy.State.STAGGER:
		br.tick(0.005)
	check("a block that breaks the guard does not stun the attacker", grunt.state == Enemy.State.RECOVER and br.hero.state == Hero.State.GUARD_BREAK, "grunt=%d hero=%d" % [grunt.state, br.hero.state])
	br.free_all()

	# Combo: a block of hit 1 stuns the captain, so hit 2 never starts.
	var cp := captain_rig(Vector2(320, 360), Vector2(320, 330))
	var cr: Rig = cp[0]
	var cc: Enemy = cp[1]
	cr.use_weapon(Weapon.sword_from(T), true)
	cc.pattern_pos = 2
	cr.input.press_block(false)
	var saw_second := false
	var t_end := cr.time + 1.6
	while cr.time < t_end:
		cr.tick(0.005)
		if cc.cur != null and cc.cur.label == "Combo 2" and cc.state == Enemy.State.WINDUP:
			saw_second = true
	check("blocking combo hit 1 stuns the captain and cancels hit 2", not saw_second and is_equal_approx(cr.hero.guard, 66.0), "guard=%s" % cr.hero.guard)
	cr.free_all()


func test_daggers() -> void:
	section("Daggers: 360 degree ring, fast, parry kill")
	var dg := load("res://resources/weapons/daggers.tres") as Weapon
	check("both daggers attacks are full rings", is_equal_approx(dg.light.arc_deg, 360.0) and is_equal_approx(dg.heavy.arc_deg, 360.0))
	check("light cycle is 0.18 s", is_equal_approx(dg.light.windup + dg.light.active + dg.light.recover, 0.18))
	var rad := T.enemy_radius
	for heavy in [false, true]:
		var reach: float = dg.heavy.reach if heavy else dg.light.reach
		var behind_all := true
		for deg in range(0, 360, 45):
			var r := weapon_rig(dg)
			var tgt := r.add_enemy(r.hero.position + Vector2.UP.rotated(deg_to_rad(float(deg))) * (reach * 0.7))
			tgt.hp = 1000.0
			r.input.press_attack(false)
			if heavy:
				r.run(0.4, 0.01)
			else:
				r.tick(0.005)
			r.input.release_attack(false)
			r.run(1.0)
			if r.hits != 1:
				behind_all = false
			r.free_all()
		check("daggers %s hits a target in each of 8 directions, behind included" % ("heavy" if heavy else "light"), behind_all)
		var inside := weapon_rig(dg)
		var ei := inside.add_enemy(inside.hero.position + Vector2(0, reach + rad - 1.0))
		ei.hp = 1000.0
		var outside := weapon_rig(dg)
		var eo := outside.add_enemy(outside.hero.position + Vector2(0, reach + rad + 4.0))
		eo.hp = 1000.0
		for rr in [inside, outside]:
			rr.input.press_attack(false)
			if heavy:
				rr.run(0.4, 0.01)
			else:
				rr.tick(0.005)
			rr.input.release_attack(false)
			rr.run(1.0)
		check("daggers %s reach is %d: just inside hits, just outside misses" % ["heavy" if heavy else "light", int(reach)], inside.hits == 1 and outside.hits == 0, "in=%d out=%d" % [inside.hits, outside.hits])
		inside.free_all()
		outside.free_all()

	# The drawn ring equals the hit area.
	var poly := HitShapes.sector_polygon(Vector2.UP, 40.0, 360.0)
	var bad := 0
	var x := -60.0
	while x <= 60.0:
		var y := -60.0
		while y <= 60.0:
			var pt := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(pt, poly) != (pt.length() <= 40.0) and absf(pt.length() - 40.0) > 1.5:
				bad += 1
			y += 3.0
		x += 3.0
	check("the 360 ring polygon equals the hit circle", bad == 0, "bad=%d" % bad)

	# Parry kill.
	var gp := parry_rig(false, false, 0.08, false, false, dg)
	check("a daggers parry kills a grunt", gp[1].is_dead())
	gp[0].free_all()
	var cpr := parry_rig(false, true, 0.08, false, false, dg)
	check("a daggers parry takes exactly 60 HP off the captain and still freezes it 2.0 s", is_equal_approx(cpr[1].hp, 90.0) and parried(cpr[1]) and is_equal_approx(cpr[1].stagger_total, 2.0))
	cpr[0].free_all()
	var sp := parry_rig(true, false, 0.08)
	check("a sword parry never kills", parried(sp[1]) and is_equal_approx(sp[1].hp, 30.0))
	sp[0].free_all()


func test_movement_ramp() -> void:
	section("Movement: speed 195 with a short ramp")
	var r := Rig.new(root, T, Vector2(500, 360))
	r.input.key_move = Vector2(-1, 0)
	r.run(0.06, 0.01)
	check("0.06 s into a start the hero is at about half speed", absf(r.hero.velocity.length() - 97.5) < 8.0, "v=%s" % r.hero.velocity.length())
	r.run(0.2, 0.01)
	check("full speed 195 after the ramp", absf(r.hero.velocity.length() - 195.0) < 0.5, "v=%s" % r.hero.velocity.length())
	r.input.key_move = Vector2.ZERO
	var x1 := r.hero.position.x
	r.run(0.1, 0.01)
	check("releasing the stick stops the hero within 0.1 s", r.hero.velocity.length() < 0.01)
	check("and the glide is under 10 px", absf(r.hero.position.x - x1) < 10.0, "glide=%s" % absf(r.hero.position.x - x1))
	r.free_all()

	var w := Rig.new(root, T, Vector2(500, 360))
	w.input.key_move = Vector2(-1, 0)
	w.run(0.4, 0.01)
	w.input.press_attack(false)
	w.tick(0.005)
	w.input.release_attack(false)
	w.tick(0.005)
	check("a wind-up zeroes the velocity", w.hero.state == Hero.State.WINDUP and w.hero.velocity == Vector2.ZERO)
	var wx := w.hero.position.x
	w.run(0.04, 0.005)
	check("the hero does not slide during the wind-up", absf(w.hero.position.x - wx) < 0.01)
	w.free_all()

	var d := Rig.new(root, T, Vector2(500, 360))
	d.input.key_move = Vector2(-1, 0)
	d.run(0.4, 0.01)
	var dx0 := d.hero.position.x
	d.input.press_dodge()
	d.tick(0.01)
	d.run(0.4, 0.01)
	check("a dodge still covers 90 px at full speed", absf((dx0 - d.hero.position.x) - 90.0) < 20.0, "d=%s" % (dx0 - d.hero.position.x))
	d.free_all()


## Speed of the hero while it is in `state`, sampled once the state has run for `after` seconds.
func speed_in_state(r: Rig, state: Hero.State, after: float, limit := 1.5) -> float:
	var end := r.time + limit
	while r.time < end:
		r.tick(0.005)
		if r.hero.state == state and r.hero.state_time >= after:
			return r.hero.velocity.length()
	return -1.0


func test_attack_move() -> void:
	section("Daggers move while they attack (0.7x walking speed)")
	var dg := load("res://resources/weapons/daggers.tres") as Weapon
	check("only the daggers have attack_move_mult (0.7)", is_equal_approx(dg.attack_move_mult, 0.7) and is_equal_approx((load("res://resources/weapons/zweihander.tres") as Weapon).attack_move_mult, 0.0) and Weapon.sword_from(T).attack_move_mult == 0.0)
	var expect := 214.5 * 0.7
	for heavy in [false, true]:
		var r := weapon_rig(dg)
		r.hero.position = Vector2(500, 360)
		r.input.key_move = Vector2(-1, 0)
		r.run(0.4, 0.01)
		r.input.press_attack(false)
		r.run(0.25 if heavy else 0.08, 0.01)
		var charge_v := r.hero.velocity.length()
		check("daggers %s: moving at %.0f while the attack charges" % ["heavy" if heavy else "light", expect], absf(charge_v - expect) < 1.0, "v=%s" % charge_v)
		r.input.release_attack(false)
		r.tick(0.005)
		var face0 := r.hero.facing
		check("daggers %s: the attack starts with the hero still moving" % ["heavy" if heavy else "light"], r.hero.state == Hero.State.WINDUP and r.hero.velocity.length() > 100.0, "state=%d v=%s" % [r.hero.state, r.hero.velocity.length()])
		var x0 := r.hero.position.x
		r.input.key_move = Vector2(0, -1)  # steer while the attack plays
		var wv := speed_in_state(r, Hero.State.WINDUP, 0.01 if not heavy else 0.07)
		check("daggers %s: wind-up speed is about %.0f" % ["heavy" if heavy else "light", expect], wv >= 0.0 and wv > 100.0 and wv < 215.0, "v=%s" % wv)
		check("daggers %s: moved during the wind-up" % ["heavy" if heavy else "light"], r.hero.position.x < x0 - 0.01)
		check("daggers %s: facing is locked in the wind-up" % ["heavy" if heavy else "light"], r.hero.facing.is_equal_approx(face0), str(r.hero.facing))
		var av := speed_in_state(r, Hero.State.ACTIVE, 0.0)
		check("daggers %s: still moving during the strike, facing still locked" % ["heavy" if heavy else "light"], av > 100.0 and r.hero.facing.is_equal_approx(face0), "v=%s" % av)
		var rv := speed_in_state(r, Hero.State.RECOVER, 0.07)
		check("daggers %s: moving in recovery, at 0.7x once steered" % ["heavy" if heavy else "light"], rv > 100.0, "v=%s" % rv)
		r.free_all()
	# Steady state: the speed settles on 0.7 x 214.5 = 150.
	var s1 := weapon_rig(dg)
	s1.hero.position = Vector2(500, 360)
	s1.input.key_move = Vector2(-1, 0)
	s1.input.press_attack(false)
	s1.run(0.15, 0.01)
	check("daggers charge at 0.7x walking speed", absf(s1.hero.velocity.length() - expect) < 1.0, "v=%s" % s1.hero.velocity.length())
	s1.free_all()
	check("150 px/s is above the sword's recovery speed (97.5)", expect > 195.0 * 0.5)

	# Other weapons are unchanged: rooted in wind-up and strike, half speed only in recovery.
	for w in [Weapon.sword_from(T), load("res://resources/weapons/zweihander.tres") as Weapon]:
		var r := weapon_rig(w)
		r.hero.position = Vector2(500, 360)
		r.input.key_move = Vector2(-1, 0)
		r.run(0.4, 0.01)
		r.input.press_attack(false)
		r.tick(0.005)
		r.input.release_attack(false)
		r.tick(0.005)
		check("%s: wind-up is rooted" % w.display_name, r.hero.state == Hero.State.WINDUP and r.hero.velocity == Vector2.ZERO)
		var sv := speed_in_state(r, Hero.State.ACTIVE, 0.0)
		check("%s: the strike is rooted" % w.display_name, sv == 0.0, "v=%s" % sv)
		var half := speed_in_state(r, Hero.State.RECOVER, w.light.recover - 0.05)
		check("%s: recovery moves at half speed" % w.display_name, absf(half - 195.0 * w.move_mult * 0.5) < 1.5, "v=%s" % half)
		r.free_all()

	# The ring still hits while the hero moves, once.
	var h := weapon_rig(dg)
	h.hero.position = Vector2(500, 360)
	var tgt := h.add_enemy(Vector2(440, 360))
	tgt.hp = 1000.0
	h.input.key_move = Vector2(-1, 0)
	h.run(0.2, 0.01)
	h.input.press_attack(false)
	h.run(0.05, 0.01)
	h.input.release_attack(false)
	h.run(0.5)
	check("a daggers swing on the move still lands exactly once", h.hits == 1 and h.swings == 1, "hits=%d swings=%d" % [h.hits, h.swings])
	h.free_all()

	# Dodge and hurt still root the hero.
	var d := weapon_rig(dg)
	d.hero.position = Vector2(500, 360)
	d.input.key_move = Vector2(-1, 0)
	d.run(0.3, 0.01)
	d.input.press_attack(false)
	d.tick(0.005)
	d.input.release_attack(false)
	d.until_state(Hero.State.WINDUP)
	d.hero.take_hit(10.0)
	check("a hit stops the daggers hero (hurt)", d.hero.state == Hero.State.HURT and d.hero.velocity == Vector2.ZERO)
	d.free_all()
	var dd := weapon_rig(dg)
	dd.hero.position = Vector2(500, 360)
	dd.input.key_move = Vector2(-1, 0)
	dd.run(0.3, 0.01)
	dd.input.press_dodge()
	dd.tick(0.005)
	check("a dodge zeroes velocity and takes over", dd.hero.state == Hero.State.DODGE and dd.hero.velocity == Vector2.ZERO)
	dd.free_all()


func test_heavy_hold_and_menu() -> void:
	section("Heavy hold 0.20 s and the five-weapon menu")
	var tap := attack_for(0.15)
	check("a 0.15 s press is a light attack", not tap.hero.cur_attack.heavy)
	tap.free_all()
	var hold := attack_for(0.25)
	check("a 0.25 s press is a heavy attack", hold.hero.cur_attack.heavy)
	hold.free_all()
	var g := make_game()
	check("the start panel has five weapon buttons", g.menu._weapon_buttons.size() == 5)
	var labels := []
	for b in g.menu._weapon_buttons:
		labels.append(b.text)
	check("including the Zweihander", "Zweihander" in str(labels), str(labels))
	g.queue_free()


## A pressed defensive action must apply before the enemy's ACTIVE strike resolves.
func _force_strike_now(g: Game) -> Enemy:
	var e: Enemy = g.enemies[0]
	e.state = Enemy.State.ACTIVE
	e.state_time = 0.0
	e.cur = e.profile.attacks[0]
	e.position = g.hero.position + Vector2(0.0, -40.0)
	e.attack_origin = e.position
	e.attack_dir = Vector2.DOWN
	e.hit_done = false
	return e


func test_pre_resolution_defense() -> void:
	section("Frame-edge defensive input")
	var g := make_game()
	g.start_fight(Game.Mode.ONE)
	_force_strike_now(g)
	g.input.press_dodge()
	g.step(1.0 / 60.0)
	check("same-frame dodge protects before enemy hit", g.hero.state == Hero.State.DODGE and is_equal_approx(g.hero.hp, 100.0))
	g.start_fight(Game.Mode.ONE)
	_force_strike_now(g)
	g.input.press_block(false)
	g.step(1.0 / 60.0)
	check("same-frame block raises guard before enemy hit", g.hero.state == Hero.State.BLOCK and is_equal_approx(g.hero.hp, 100.0))
	g.start_fight(Game.Mode.ONE)
	g.input.press_block(false)
	g.step(1.0 / 60.0)
	g.input.release_block(false)
	_force_strike_now(g)
	g.step(1.0 / 60.0)
	check("releasing block before strike cannot phantom block", g.hero.hp < 100.0)
	g.start_fight(Game.Mode.ONE)
	_force_strike_now(g)
	g.step(1.0 / 60.0)
	check("no defence still takes the strike", g.hero.hp < 100.0)
	g.queue_free()


func test_control_and_guard_trials() -> void:
	section("0.9 optional control and defence variants")
	var g := make_game()
	g.start_fight(Game.Mode.ONE)
	check("baseline remains all-round and hold", not g.split_attacks and not g.directional_guard and is_equal_approx(g.tuning.block_arc_shield, 360.0) and not g.controls.separate_attacks)
	g.directional_guard = true
	g.split_attacks = true
	g.shield_on = true
	g.start_fight(Game.Mode.ONE)
	check("directional defence applies tuned arcs and parry window", is_equal_approx(g.tuning.block_arc_shield, 140.0) and is_equal_approx(g.tuning.block_arc_bare, 110.0) and is_equal_approx(g.hero.parry_window(), 0.30))
	check("trial shortens block stun and activates split layout", is_equal_approx(g.hero.block_stun_time(), g.hero.weapon.block_stun_time * 0.55) and g.controls.separate_attacks)
	# In split mode, tapping LIGHT must strike on press, without awaiting touch-up.
	g.controls._touch_down(7, g.controls.attack_center)
	g.step(1.0 / 60.0)
	check("split light starts immediately on down", g.hero.state == Hero.State.WINDUP and not g.hero.cur_attack.heavy)
	g.controls._touch_up(7)
	g.start_fight(Game.Mode.ONE)
	g.controls._touch_down(8, g.controls.heavy_center)
	g.step(1.0 / 60.0)
	check("split heavy starts immediately on down", g.hero.state == Hero.State.WINDUP and g.hero.cur_attack.heavy)
	g.controls._touch_up(8)
	g.directional_guard = false
	g.split_attacks = false
	g.start_fight(Game.Mode.ONE)
	check("retry with defaults restores original defence and layout", is_equal_approx(g.tuning.block_arc_shield, 360.0) and is_equal_approx(g.tuning.parry_window_shield, 0.40) and is_equal_approx(g.hero.block_stun_mult, 1.0) and not g.controls.separate_attacks)
	g.queue_free()


func _all_in(values: Array, lo: float, hi: float) -> bool:
	## True when every 0.02 s step between lo and hi is present in the list.
	var t := ceilf(lo / 0.02) * 0.02
	while t <= hi + 0.0001:
		var found := false
		for v in values:
			if absf(v - t) < 0.005:
				found = true
				break
		if not found:
			return false
		t += 0.02
	return true
