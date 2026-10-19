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

	func add_enemy(pos: Vector2, idx := 0) -> Enemy:
		var e := Enemy.new()
		host.add_child(e)
		e.setup(t, ctrl, hero, t.arena_size, idx)
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
		"half_speed_mult": 0.5,
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
	g.start_fight(3)
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


## A simple scripted player: walk to the nearest enemy, tap-attack in range, sidestep-dodge
## a locked strike. Deterministic, no randomness.
func bot(g: Game) -> void:
	var h := g.hero
	var target := nearest_alive(g)
	if target == null:
		g.input.key_move = Vector2.ZERO
		return
	var to := target.position - h.position
	g.input.key_move = to.normalized() if to.length() > 54.0 else to.normalized() * 0.05
	# A dodge cancels a charge but the "finger" is still down: lift it, as a player would.
	if h.state == Hero.State.IDLE and g.input.attack_down():
		g.input.release_attack(false)
	for e in g.enemies:
		if e.is_dead() or e.state != Enemy.State.WINDUP or not e.locked:
			continue
		var left: float = g.tuning.enemy_windup - e.state_time
		if left <= 0.10 and h.dodge_charges > 0 and h.state in [Hero.State.IDLE, Hero.State.CHARGING, Hero.State.RECOVER]:
			if HitShapes.circle_in_sector(e.position, e.attack_dir, g.tuning.enemy_reach,
					g.tuning.enemy_arc_deg, h.position, h.radius):
				g.input.key_move = e.attack_dir.orthogonal()
				g.input.press_dodge()
				return
	if h.state == Hero.State.IDLE and to.length() <= 60.0:
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
	g.start_fight(3)
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
	one.start_fight(1)
	play(one, 90.0, true)
	check("1 enemy: scripted hero wins", one.state == Game.State.RESULT and one.outcome == Game.Outcome.VICTORY,
			"outcome=%s t=%.1f hp=%s" % [one.outcome, one.fight_time, one.hero.hp])
	print("        (1 enemy bot win: %.1f s, hero hp %d)" % [one.fight_time, ceili(one.hero.hp)])
	one.queue_free()

	var three := make_game()
	three.start_fight(3)
	play(three, 120.0, true)
	check("3 enemies: scripted hero wins with default tuning", three.outcome == Game.Outcome.VICTORY,
			"outcome=%s t=%.1f hp=%s alive=%d" % [three.outcome, three.fight_time, three.hero.hp, three.enemies_alive()])
	print("        (3 enemy bot result: %s in %.1f s, hero hp %d)" % [three.outcome, three.fight_time, ceili(three.hero.hp)])
	three.queue_free()

	var idle := make_game()
	idle.start_fight(3)
	play(idle, 90.0, false)
	check("hero can die: idle hero is defeated", idle.state == Game.State.RESULT and idle.outcome == Game.Outcome.DEFEAT,
			"outcome=%s hp=%s" % [idle.outcome, idle.hero.hp])
	check("hero is dead at defeat", idle.hero.is_dead() and idle.hero.hp == 0.0)
	idle.queue_free()

	# Defeat takes priority when both sides are down.
	var tie := make_game()
	tie.start_fight(1)
	tie.hero.hp = 0.0
	tie.hero.state = Hero.State.DEAD
	for e in tie.enemies:
		e.take_hit(999.0, e.position, 0.0)
	tie._check_outcome()
	check("hero and last enemy both down -> DEFEAT", tie.outcome == Game.Outcome.DEFEAT)
	tie.queue_free()

	# Same-step trade: enemy strike and killing blow in one step.
	var trade := make_game()
	trade.start_fight(1)
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
		"peak": g.controller.peak,
		"input": [g.input.touch_move, g.input.key_move, g.input.attack_touch, g.input.attack_key,
				g.input.attack_pressed, g.input.attack_released, g.input.dodge_pressed],
		"controls": [g.controls.joy_index, g.controls.atk_index, g.controls.dodge_index],
	}


func test_retry_resets_everything() -> void:
	section("Retry resets all state (10 cycles per mode)")
	var g := make_game()
	for mode in [3, 1]:
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
		check("%d-enemy mode: state after every Retry equals a fresh start" % mode, identical)
		check("%d-enemy mode: exactly %d enemies exist after Retry" % [mode, mode], g.enemies.size() == mode and baseline.enemy_nodes == mode)

	# Retry from the result screen, via the menu button signal.
	g.start_fight(3)
	g.hero.take_hit(1000.0)
	g.step(1.0 / 60.0)
	check("defeat moves to the result state", g.state == Game.State.RESULT)
	g.menu.fight_requested.emit(1)
	check("Retry from the result screen starts a new 1-enemy fight", g.state == Game.State.FIGHTING and g.enemies.size() == 1 and g.hero.hp == g.tuning.hero_max_hp and not g.hero.is_dead())
	g.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss through the Game node clears held input", not g.input.attack_down() and g.input.touch_move == Vector2.ZERO)
	g.queue_free()
