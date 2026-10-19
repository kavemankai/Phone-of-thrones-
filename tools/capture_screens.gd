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

	# Idle hero: wait for the first locked wind-up and capture the telegraph.
	game.start_fight(3)
	await _advance(1.0)
	await _shot("02_fight_start")
	var guard := 0
	while guard < 1200 and not _any_locked_windup():
		game.step(1.0 / 60.0)
		guard += 1
	await _frames(2)
	await _shot("03_telegraph_locked")

	# Charge to heavy-ready on a fresh fight.
	game.start_fight(1)
	var mid := game.tuning.arena_size.x * 0.5
	game.enemies[0].position = Vector2(mid, 250)
	game.hero.position = Vector2(mid, 320)
	game.input.press_attack(false)
	await _advance(0.5)
	await _shot("04_heavy_ready")

	# Hero swing active frame next to an enemy.
	game.input.release_attack(false)
	game.step(1.0 / 60.0)
	var g2 := 0
	while g2 < 120 and game.hero.state != Hero.State.ACTIVE:
		game.step(1.0 / 120.0)
		g2 += 1
	await _frames(2)
	await _shot("05_heavy_active")

	# Touch overlay with sticks held (synthetic events through the real handler).
	game.start_fight(3)
	var c := game.controls
	var t1 := InputEventScreenTouch.new()
	t1.index = 0
	t1.pressed = true
	t1.position = c.joy_hint
	c._input(t1)
	var d1 := InputEventScreenDrag.new()
	d1.index = 0
	d1.position = c.joy_hint + Vector2(60, -50)
	c._input(d1)
	var t2 := InputEventScreenTouch.new()
	t2.index = 1
	t2.pressed = true
	t2.position = c.attack_center
	c._input(t2)
	await _advance(0.45)
	await _shot("06_touch_held")

	# Result panel.
	game.start_fight(1)
	game.enemies[0].take_hit(999.0, game.enemies[0].position, 0.0)
	game.step(1.0 / 60.0)
	game.set_process(true)
	await _frames(60)
	await _shot("07_result")
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
