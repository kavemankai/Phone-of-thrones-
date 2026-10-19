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
