extends SceneTree
## Desktop screenshot helper (needs a display, e.g. xvfb-run). Not a test: it only writes PNGs
## so layout and telegraphs can be looked at. Usage:
##   xvfb-run -a godot --path . --resolution 720x1280 --script tools/capture_screens.gd -- /output/dir

var out_dir := "/tmp"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	await process_frame
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	game.set_process(false)
	await _frames(3)
	await _shot("01_menu")
	game.menu.set_weapon(0)
	game.menu.set_shield(true)
	await _frames(2)
	await _shot("01b_menu_sword_shield")
	game.menu.set_weapon(2)
	await _frames(2)
	await _shot("01c_menu_axe_no_shield")
	game.menu.set_weapon(4)
	await _frames(2)
	await _shot("01d_menu_zweihander")
	game.menu.set_weapon(0)

	# Three enemies: first locked grunt wedge.
	game.start_fight(Game.Mode.THREE_CAPTAIN, 0)
	await _advance(1.0)
	await _shot("02_fight_start")
	var guard := 0
	while guard < 1200 and not _any_locked_windup():
		game.step(1.0 / 60.0)
		guard += 1
	await _frames(2)
	await _shot("03_grunt_telegraph")

	# Each weapon's heavy swing, active frame, next to one enemy.
	var mid := game.tuning.arena_size.x * 0.5
	for wi in game.weapons.size():
		game.start_fight(Game.Mode.ONE, wi)
		var w := game.weapon()
		game.enemies[0].position = Vector2(mid, 320.0 - w.heavy.reach * 0.55)
		game.enemies[0].hp = 9999.0
		game.enemies[0].cooldown = 1000.0  # stand still so the swing is not interrupted
		game.hero.position = Vector2(mid, 320)
		game.input.press_attack(false)
		await _advance(0.45)
		if wi == 0:
			await _shot("04_heavy_ready")
		game.input.release_attack(false)
		game.step(1.0 / 120.0)
		var g2 := 0
		while g2 < 240 and game.hero.state != Hero.State.ACTIVE:
			game.step(1.0 / 120.0)
			g2 += 1
		game.step(1.0 / 120.0)
		await _frames(2)
		await _shot("05_heavy_%s" % w.id)

	# Guard poses: shield raised, bare guard.
	for shield in [true, false]:
		game.shield_on = shield
		game.start_fight(Game.Mode.ONE, 0)
		game.enemies[0].cooldown = 1000.0
		game.hero.position = Vector2(mid, 320)
		game.enemies[0].position = Vector2(mid, 250)
		game.input.press_block(false)
		await _advance(0.4)
		await _shot("10_block_shield" if shield else "11_block_bare")

	# Parry: raise the guard 0.10 s before a grunt's strike; the grunt is left dazed.
	game.shield_on = true
	game.start_fight(Game.Mode.ONE, 0)
	game.hero.position = Vector2(mid, 320)
	game.enemies[0].position = Vector2(mid, 290)
	var grunt: Enemy = game.enemies[0]
	var guard_n := 0
	while not (grunt.state == Enemy.State.WINDUP) and guard_n < 600:
		game.step(1.0 / 60.0)
		guard_n += 1
	while grunt.state_time < grunt.cur.windup - 0.10:
		game.step(1.0 / 60.0)
	game.input.press_block(false)
	var wedge_shot := false
	while grunt.state != Enemy.State.STAGGER and guard_n < 1200:
		game.step(1.0 / 60.0)
		guard_n += 1
	await _frames(2)
	await _shot("12_parry_dazed")
	# Same freeze two seconds later: the timer has run down to about 1.0.
	await _advance(2.0)
	await _shot("12b_parry_timer_one_second")

	# Block mini stun: the guard goes up well before the strike, so it is a plain block and
	# the grunt is left recoiling with a 1.2 s timer.
	game.shield_on = true
	game.start_fight(Game.Mode.ONE, 0)
	game.hero.position = Vector2(mid, 320)
	game.enemies[0].position = Vector2(mid, 290)
	var blocked_grunt: Enemy = game.enemies[0]
	game.input.press_block(false)
	var bn := 0
	while blocked_grunt.state != Enemy.State.STAGGER and bn < 1200:
		game.step(1.0 / 60.0)
		bn += 1
	await _advance(0.2)
	await _shot("12e_block_stun_timer")

	# Daggers: ring swing, and a parry that kills.
	game.shield_on = false
	game.start_fight(Game.Mode.ONE, 3)
	game.hero.position = Vector2(mid, 320)
	game.enemies[0].position = Vector2(mid, 290)
	game.enemies[0].hp = 9999.0
	game.enemies[0].cooldown = 1000.0
	game.input.press_attack(false)
	game.step(1.0 / 120.0)
	game.input.release_attack(false)
	var dn := 0
	while game.hero.state != Hero.State.ACTIVE and dn < 240:
		game.step(1.0 / 240.0)
		dn += 1
	await _frames(2)
	await _shot("05b_daggers_light_ring")
	game.start_fight(Game.Mode.ONE, 3)
	game.hero.position = Vector2(mid, 320)
	game.enemies[0].position = Vector2(mid, 290)
	var doomed: Enemy = game.enemies[0]
	var dk := 0
	while doomed.state != Enemy.State.WINDUP and dk < 600:
		game.step(1.0 / 60.0)
		dk += 1
	while doomed.state_time < doomed.cur.windup - 0.10:
		game.step(1.0 / 60.0)
	game.input.press_block(false)
	var dd := 0
	while not doomed.is_dead() and dd < 240:
		game.step(1.0 / 60.0)
		dd += 1
	await _frames(2)
	await _shot("12f_dagger_parry_kill")

	# Heavy-hit stagger on a grunt: a 1.0 s freeze with its own timer.
	game.shield_on = false
	game.start_fight(Game.Mode.ONE, 0)
	game.hero.position = Vector2(mid, 320)
	var heavy_target: Enemy = game.enemies[0]
	heavy_target.position = Vector2(mid, 290)
	heavy_target.hp = 9999.0
	heavy_target.cooldown = 1000.0
	game.input.press_attack(false)
	await _advance(0.45)
	game.input.release_attack(false)
	var hn := 0
	while not heavy_target.is_staggered() and hn < 300:
		game.step(1.0 / 60.0)
		hn += 1
	await _advance(0.2)
	await _shot("12c_heavy_stagger_timer")

	# The captain frozen by a parry (3 s).
	game.start_fight(Game.Mode.CAPTAIN_ONLY, 0)
	game.enemies[0].position = Vector2(mid, 250)
	game.enemies[0].stagger()
	await _advance(0.5)
	await _shot("12d_captain_frozen_timer")

	# Guard break.
	game.start_fight(Game.Mode.ONE, 0)
	game.enemies[0].cooldown = 1000.0
	game.input.press_block(false)
	await _advance(0.3)
	game.hero.guard = 5.0
	game.hero.receive_attack(12.0, game.hero.position + Vector2(0, -30), game.enemies[0].cur)
	await _frames(2)
	await _shot("13_guard_break")

	# Captain attacks, each at the first locked wind-up of that attack.
	game.start_fight(Game.Mode.CAPTAIN_ONLY, 0)
	game.hero.hp = 100000.0
	game.tuning.hero_max_hp = 100000.0
	var wanted := ["Lunge", "Slash", "Combo 1", "Combo 2"]
	var n := 0
	while wanted.size() > 0 and n < 6000:
		game.step(1.0 / 60.0)
		n += 1
		var c: Enemy = game.enemies[0]
		if c.state == Enemy.State.WINDUP and c.locked and c.cur.label == wanted[0]:
			await _frames(2)
			await _shot("06_captain_%s" % wanted[0].to_lower().replace(" ", "_"))
			wanted.remove_at(0)

	# Intermission banner.
	game.start_fight(Game.Mode.THREE_CAPTAIN, 1)
	game.hero.hp = 45.0
	for e in game.enemies:
		e.take_hit(9999.0, e.position, 0.0)
	game.step(1.0 / 60.0)
	await _advance(0.5)
	await _shot("07_intermission")

	# Touch overlay with stick and Attack held (synthetic events through the real handler).
	game.start_fight(Game.Mode.THREE_CAPTAIN, 3)
	var c2 := game.controls
	var t1 := InputEventScreenTouch.new()
	t1.index = 0
	t1.pressed = true
	t1.position = c2.joy_hint
	c2._input(t1)
	var d1 := InputEventScreenDrag.new()
	d1.index = 0
	d1.position = c2.joy_hint + Vector2(60, -50)
	c2._input(d1)
	var t2 := InputEventScreenTouch.new()
	t2.index = 1
	t2.pressed = true
	t2.position = c2.attack_center
	c2._input(t2)
	await _advance(0.45)
	await _shot("08_touch_daggers_three_pips")
	# BLOCK finger held with the stick: the button lights up and the guard ring shows.
	var t3 := InputEventScreenTouch.new()
	t3.index = 2
	t3.pressed = true
	t3.position = c2.block_center
	c2._input(t3)
	await _advance(0.3)
	await _shot("08b_touch_block")

	# Result panel.
	game.start_fight(Game.Mode.CAPTAIN_ONLY, 2)
	game.enemies[0].take_hit(99999.0, game.enemies[0].position, 0.0)
	game.step(1.0 / 60.0)
	game.set_process(true)
	await _frames(60)
	await _shot("09_result")
	quit(0)


func _any_locked_windup() -> bool:
	for e in game.enemies:
		if e.state == Enemy.State.WINDUP and e.locked:
			return true
	return false


func _advance(seconds: float) -> void:
	var n := int(seconds * 60.0)
	for i in n:
		game.step(1.0 / 60.0)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
