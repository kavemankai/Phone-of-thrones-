class_name Game
extends Node
## Owns the encounter: builds the scene, runs the simulation in fixed sub-steps, decides
## victory or defeat, and handles retry. step(dt) is public so tests can drive it.

enum State { MENU, FIGHTING, RESULT }
enum Outcome { NONE, VICTORY, DEFEAT }

const SUBSTEP := 1.0 / 60.0
const MAX_FRAME_DT := 0.1
const HUD_HEIGHT := 110.0
const TUNING_PATH := "res://resources/tuning.tres"
const HERO_SCENE := preload("res://scenes/hero.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

signal state_changed(new_state: State)

var tuning: Tuning
var input := CombatInput.new()
var controller := EncounterController.new()

var state: State = State.MENU
var outcome: Outcome = Outcome.NONE
var enemy_count := 3
var fight_time := 0.0
var result_timer := 0.0
var enemies: Array = []

var arena_root: Node2D
var arena_view: ArenaView
var hero: Hero
var controls: TouchControls
var hud: CombatHud
var menu: MenuPanel
var sfx: Sfx


func _ready() -> void:
	# A private copy, so changing values at runtime (tests) never edits the shared resource.
	var loaded := load(TUNING_PATH) as Tuning
	tuning = loaded.duplicate() as Tuning if loaded != null else null
	if tuning == null:
		push_warning("Could not load %s, using built-in defaults." % TUNING_PATH)
		tuning = Tuning.new()
	controller.configure(tuning)

	arena_root = Node2D.new()
	arena_root.name = "ArenaRoot"
	add_child(arena_root)
	arena_view = ArenaView.new()
	arena_view.arena_size = tuning.arena_size
	arena_root.add_child(arena_view)

	hero = HERO_SCENE.instantiate() as Hero
	hero.setup(tuning, input, tuning.arena_size)
	arena_root.add_child(hero)
	hero.swung.connect(func(heavy: bool): sfx.play("swing_heavy" if heavy else "swing_light"))
	hero.hit_landed.connect(func(_e: Enemy, _h: bool): sfx.play("hit"))
	hero.dodged.connect(func(): sfx.play("dodge"))
	hero.damaged.connect(func(): sfx.play("hurt"))
	hero.died.connect(func(): sfx.play("hurt"))

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	hud = CombatHud.new()
	hud.game = self
	ui.add_child(hud)
	controls = TouchControls.new()
	controls.input = input
	controls.hero = hero
	controls.tuning = tuning
	ui.add_child(controls)
	menu = MenuPanel.new()
	ui.add_child(menu)
	menu.fight_requested.connect(start_fight)

	sfx = Sfx.new()
	add_child(sfx)

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_set_state(State.MENU)


func enemies_alive() -> int:
	var n := 0
	for e in enemies:
		if not e.is_dead():
			n += 1
	return n


## Clears every piece of fight state and starts a new encounter.
func start_fight(count: int) -> void:
	enemy_count = clampi(count, 1, 3)
	for e in enemies:
		arena_root.remove_child(e)
		e.queue_free()
	enemies.clear()
	controller.reset()
	controls.reset()
	input.clear()
	var a := tuning.arena_size
	hero.reset(Vector2(a.x * 0.5, a.y - tuning.hero_spawn_from_bottom))
	var top := tuning.enemy_spawn_from_top
	var spread := tuning.enemy_spawn_spread
	var spots: Array[Vector2] = [
		Vector2(a.x * 0.5, top),
		Vector2(a.x * 0.5 - spread, top + 20.0),
		Vector2(a.x * 0.5 + spread, top + 20.0),
	]
	for i in enemy_count:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.setup(tuning, controller, hero, a, i)
		e.position = spots[i]
		e.struck.connect(func(): sfx.play("enemy_strike"))
		arena_root.add_child(e)
		enemies.append(e)
	outcome = Outcome.NONE
	fight_time = 0.0
	result_timer = 0.0
	menu.set_mode(enemy_count)
	_set_state(State.FIGHTING)


## Advance the simulation by dt seconds in fixed-size slices (a slow frame never skips
## the short active window of an attack).
func step(dt: float) -> void:
	if state != State.FIGHTING:
		return
	dt = minf(dt, MAX_FRAME_DT)
	var n := maxi(1, ceili(dt / SUBSTEP - 0.0001))
	var sub := dt / n
	for i in n:
		_sim_step(sub)
		if state != State.FIGHTING:
			break


func _sim_step(dt: float) -> void:
	fight_time += dt
	# Enemies resolve first: if a strike on the hero and the hero's killing blow land on the
	# same step, the hero is already down and defeat takes priority.
	for e in enemies:
		e.step(dt)
	hero.step(dt, enemies)
	_resolve_overlaps(dt)
	input.end_step()
	_check_outcome()


func _check_outcome() -> void:
	# Defeat wins a tie: the hero dying on the same step as the last enemy is a loss.
	if hero.is_dead():
		_finish(Outcome.DEFEAT)
	elif enemies_alive() == 0:
		_finish(Outcome.VICTORY)


func _finish(result: Outcome) -> void:
	outcome = result
	result_timer = tuning.result_delay
	controls.reset()
	sfx.play("win" if result == Outcome.VICTORY else "lose")
	_set_state(State.RESULT)


func _set_state(s: State) -> void:
	state = s
	hud.visible = s != State.MENU
	controls.set_enabled(s == State.FIGHTING)
	match s:
		State.MENU:
			menu.show_start()
		State.FIGHTING:
			menu.visible = false
		State.RESULT:
			menu.visible = false
	state_changed.emit(s)


func _process(delta: float) -> void:
	match state:
		State.FIGHTING:
			_poll_keyboard()
			step(delta)
		State.RESULT:
			if result_timer > 0.0:
				result_timer -= delta
				if result_timer <= 0.0:
					menu.show_result(outcome == Outcome.VICTORY, fight_time, hero.hp, enemy_count)


func _poll_keyboard() -> void:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	input.key_move = v.limit_length(1.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if state == State.FIGHTING:
		if event.physical_keycode == KEY_J:
			if event.pressed:
				input.press_attack(false)
			else:
				input.release_attack(false)
		elif event.physical_keycode == KEY_SPACE and event.pressed:
			input.press_dodge()
	elif event.pressed and event.physical_keycode == KEY_ENTER and menu.visible:
		start_fight(menu.enemy_count)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if controls != null:
			controls.reset()


# Bodies never share a spot. Enemies in a committed attack hold still and the others
# move around them; the hero is never pushed. A dodging hero passes through everyone.
func _resolve_overlaps(dt: float) -> void:
	var max_push := tuning.separation_speed * dt
	var alive: Array = []
	for e in enemies:
		if not e.is_dead():
			alive.append(e)
	var hero_solid := hero.state != Hero.State.DODGE and not hero.is_dead()
	for i in alive.size():
		var a: Enemy = alive[i]
		if hero_solid and not a.is_committed():
			_push_from_point(a, hero.position, hero.radius, max_push)
		for j in range(i + 1, alive.size()):
			var b: Enemy = alive[j]
			var d := b.position - a.position
			var dist := d.length()
			var min_dist := a.radius + b.radius
			if dist >= min_dist:
				continue
			var dir := d / dist if dist > 0.001 else Vector2.from_angle(float(i + j))
			var push := minf(min_dist - dist, max_push)
			if a.is_committed() and b.is_committed():
				continue
			elif a.is_committed():
				b.position = b.clamp_to_arena(b.position + dir * push)
			elif b.is_committed():
				a.position = a.clamp_to_arena(a.position - dir * push)
			else:
				a.position = a.clamp_to_arena(a.position - dir * push * 0.5)
				b.position = b.clamp_to_arena(b.position + dir * push * 0.5)


func _push_from_point(e: Enemy, point: Vector2, point_r: float, max_push: float) -> void:
	var d := e.position - point
	var dist := d.length()
	var min_dist := e.radius + point_r
	if dist >= min_dist:
		return
	var dir := d / dist if dist > 0.001 else Vector2.UP
	e.position = e.clamp_to_arena(e.position + dir * minf(min_dist - dist, max_push))


func _apply_layout() -> void:
	if arena_root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var insets := _safe_insets(vp)
	var band_h := vp.y * tuning.control_band_fraction
	var free := Rect2(
		insets.x + 10.0,
		insets.y + HUD_HEIGHT,
		vp.x - insets.x - insets.z - 20.0,
		vp.y - band_h - insets.y - HUD_HEIGHT - 10.0)
	var a := tuning.arena_size
	var s := minf(free.size.x / a.x, free.size.y / a.y)
	arena_root.scale = Vector2(s, s)
	arena_root.position = free.position + (free.size - a * s) * 0.5
	hud.layout(vp, insets)
	controls.layout(vp, band_h, insets)
	menu.layout(vp)


## Safe-area margins (left, top, right, bottom) in canvas pixels. Zero on desktop.
func _safe_insets(vp: Vector2) -> Vector4:
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var sx := vp.x / screen.x
	var sy := vp.y / screen.y
	return Vector4(
		maxf(0.0, safe.position.x * sx),
		maxf(0.0, safe.position.y * sy),
		maxf(0.0, (screen.x - safe.end.x) * sx),
		maxf(0.0, (screen.y - safe.end.y) * sy))
