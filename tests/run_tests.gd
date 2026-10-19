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

	func use_weapon(w: Weapon) -> void:
		hero.set_weapon(w)
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
	print("\n%d passed, %d failed" % [passes, fails])
	quit(fails)


func test_tuning_matches_design() -> void:
	section("Tuning resource matches the design table")
	var ok := true
	var expect := {
		"hero_max_hp": 100.0, "hero_speed": 180.0, "hero_radius": 16.0,
		"light_damage": 10.0, "light_reach": 65.0, "light_arc_deg": 90.0,
		"light_windup": 0.10, "light_active": 0.08, "light_recover": 0.22,
		"heavy_damage": 25.0, "heavy_reach": 85.0, "heavy_arc_deg": 140.0,
		"heavy_windup": 0.15, "heavy_active": 0.10, "heavy_recover": 0.40,
		"heavy_knockback": 35.0, "heavy_hold_time": 0.35,
		"dodge_distance": 90.0, "dodge_duration": 0.30, "dodge_iframes": 0.16,
		"dodge_max_charges": 2, "dodge_recharge": 1.4,
		"enemy_max_hp": 30.0, "enemy_speed": 105.0, "enemy_reach": 48.0, "enemy_damage": 12.0,
		"enemy_windup": 0.65, "enemy_active": 0.10, "enemy_recover": 0.65,
		"enemy_attack_gap": 0.35, "enemy_lock_time": 0.25, "max_commits": 2,
		"hurt_duration": 0.15, "hit_immunity": 0.35, "aim_cone_deg": 90.0,
		"half_speed_mult": 0.5, "captain_heal": 30.0, "captain_intro_time": 2.0,
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
	var edge_low := attack_for(0.33)
	check("0.34 s total -> still light", not edge_low.hero.cur_attack.heavy)
	edge_low.free_all()
	var edge_high := attack_for(0.35)
	check("0.36 s total -> heavy", edge_high.hero.cur_attack.heavy)
	edge_high.free_all()
	var long_hold := attack_for(0.8)
	check("0.8 s hold -> heavy", long_hold.hero.cur_attack.heavy)
	long_hold.free_all()

	var r := Rig.new(root, T)
	r.input.press_attack(false)
	r.run(0.30, 0.01)
	check("heavy-ready cue is off at 0.30 s", not r.hero.is_heavy_ready())
	r.run(0.06, 0.01)
	check("heavy-ready cue is on at 0.36 s", r.hero.is_heavy_ready())
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
	while e.state != Enemy.State.RECOVER:
		r.tick(0.005)
	check("even with no post-hit immunity, one strike = one hit", r.hurts == 1 and is_equal_approx(r.hero.hp, 88.0), "hurts=%d hp=%s" % [r.hurts, r.hero.hp])
	r.free_all()


func test_dodge_avoids_strike() -> void:
	section("Dodge i-frames cover an enemy strike")
	var without := Rig.new(root, T)
	without.run_enemies = true
	var e1 := without.add_enemy(Vector2(320, 455))
	while e1.state != Enemy.State.RECOVER:
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
	while e2.state != Enemy.State.RECOVER:
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
	var x0 := r.hero.position.x
	r.run(0.5, 0.01)
	check("stick moves the hero at about 180 px/s", absf((r.hero.position.x - x0) - 90.0) < 3.0, "dx=%s" % (r.hero.position.x - x0))
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
	var start := r.hero.position
	r.run(0.5, 0.01)
	var delta := r.hero.position - start
	var on_screen := Iso.to_screen(delta)
	check("stick up moves the hero straight up the screen", on_screen.y < -10.0 and absf(on_screen.x) < 0.01, str(on_screen))
	check("ground speed is still 180 px/s", absf(delta.length() - 90.0) < 0.5, "d=%s" % delta.length())
	r.input.key_move = Vector2(1, 0)
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
func bot(g: Game) -> void:
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


func play(g: Game, max_seconds: float, use_bot: bool) -> void:
	var steps := int(max_seconds * 60.0)
	for i in steps:
		if g.state != Game.State.FIGHTING:
			break
		if use_bot:
			bot(g)
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
		"input": [g.input.touch_move, g.input.key_move, g.input.attack_touch, g.input.attack_key,
				g.input.attack_pressed, g.input.attack_released, g.input.dodge_pressed],
		"controls": [g.controls.joy_index, g.controls.atk_index, g.controls.dodge_index],
	}


func test_retry_resets_everything() -> void:
	section("Retry resets all state (10 cycles per mode)")
	var g := make_game()
	var expected := {Game.Mode.THREE_CAPTAIN: 3, Game.Mode.ONE: 1, Game.Mode.CAPTAIN_ONLY: 1}
	for mode in expected:
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
	g.menu.fight_requested.emit(Game.Mode.ONE, 0)
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
	check("four weapons: sword, spear, axe, daggers", ids == ["sword", "spear", "axe", "daggers"], str(ids))
	var sword: Weapon = g.weapons[0]
	check("sword light equals the design table", tuple_close(attack_tuple(sword.light), [10, 65, 90, 0.10, 0.08, 0.22, 0, 0]))
	check("sword heavy equals the design table", tuple_close(attack_tuple(sword.heavy), [25, 85, 140, 0.15, 0.10, 0.40, 35, 0]))
	var spear: Weapon = g.weapons[1]
	check("spear light/heavy values", tuple_close(attack_tuple(spear.light), [10, 95, 30, 0.12, 0.08, 0.26, 0, 0]) and tuple_close(attack_tuple(spear.heavy), [22, 120, 24, 0.22, 0.10, 0.45, 0, 35]))
	var axe: Weapon = g.weapons[2]
	check("axe light/heavy values", tuple_close(attack_tuple(axe.light), [16, 70, 150, 0.22, 0.10, 0.38, 0, 0]) and tuple_close(attack_tuple(axe.heavy), [38, 90, 200, 0.35, 0.14, 0.60, 60, 0]))
	check("axe moves at 0.9x and recharges dodges 1.2x slower", is_equal_approx(axe.move_mult, 0.9) and is_equal_approx(axe.dodge_recharge_mult, 1.2))
	var daggers: Weapon = g.weapons[3]
	check("daggers light/heavy values", tuple_close(attack_tuple(daggers.light), [6, 45, 80, 0.05, 0.06, 0.12, 0, 0]) and tuple_close(attack_tuple(daggers.heavy), [14, 55, 100, 0.10, 0.08, 0.22, 0, 0]))
	check("daggers: 1.1x speed, one extra dodge, 0.8x recharge", is_equal_approx(daggers.move_mult, 1.1) and daggers.extra_dodge_charges == 1 and is_equal_approx(daggers.dodge_recharge_mult, 0.8))
	var cap: EnemyProfile = g.captain_profile
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

	# Movement speed.
	for pair in [[axe, 162.0], [dg, 198.0], [sword, 180.0]]:
		var w: Weapon = pair[0]
		var r := weapon_rig(w)
		r.hero.position = Vector2(500, 360)
		r.input.key_move = Vector2(-1, 0)
		var x0 := r.hero.position.x
		r.run(1.0, 0.01)
		check("%s walks at %d px/s" % [w.display_name, int(pair[1])], absf((x0 - r.hero.position.x) - pair[1]) < 1.0, "dx=%s" % (x0 - r.hero.position.x))
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
	while sc.state != Enemy.State.RECOVER:
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
	while dc.state != Enemy.State.RECOVER:
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
	g.menu.fight_requested.emit(Game.Mode.CAPTAIN_ONLY, 3)
	check("menu picks daggers and captain-only", g.mode == Game.Mode.CAPTAIN_ONLY and g.hero.weapon.id == "daggers" and g.hero.dodge_charges == 3 and g.captain_alive())
	g.start_fight(Game.Mode.ONE)
	check("Retry keeps the chosen weapon", g.hero.weapon.id == "daggers" and g.weapon_index == 3)
	g.start_fight(Game.Mode.ONE, 0)
	check("choosing the sword resets weapon stats", g.hero.weapon.id == "sword" and g.hero.dodge_charges == 2 and is_equal_approx(g.hero.move_speed(), 180.0))
	g.queue_free()


func test_scripted_player_per_weapon() -> void:
	section("Scripted player: 3 enemies, captain, victory with each weapon")
	for wi in 4:
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
