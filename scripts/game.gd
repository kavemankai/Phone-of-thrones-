class_name Game
extends Node
## Owns the encounter: builds the scene, runs the simulation in fixed sub-steps, decides
## victory or defeat, and handles retry. step(dt) is public so tests can drive it.

enum State { MENU, FIGHTING, RESULT }
enum Outcome { NONE, VICTORY, DEFEAT }
## ONE: a single enemy for practice. THREE_CAPTAIN: three enemies, then the captain.
## CAPTAIN_ONLY: skip straight to the captain.
enum Mode { ONE, THREE_CAPTAIN, CAPTAIN_ONLY }

const SUBSTEP := 1.0 / 60.0
const MAX_FRAME_DT := 0.1
const HUD_HEIGHT := 110.0
const TUNING_PATH := "res://resources/tuning.tres"
const HERO_SCENE := preload("res://scenes/hero.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const WEAPON_PATHS := [
	"res://resources/weapons/spear.tres",
	"res://resources/weapons/axe.tres",
	"res://resources/weapons/daggers.tres",
	"res://resources/weapons/zweihander.tres",
]
const CAPTAIN_PATH := "res://resources/captain.tres"

signal state_changed(new_state: State)

var tuning: Tuning
var input := CombatInput.new()
var controller := EncounterController.new()

var state: State = State.MENU
var outcome: Outcome = Outcome.NONE
var mode: Mode = Mode.THREE_CAPTAIN
var weapons: Array[Weapon] = []
var weapon_index := 0
## Off-hand shield. Only takes effect with a one-handed weapon.
var shield_on := false
## A/B settings available on the start/result screen; original modes remain default.
var split_attacks := false
var directional_guard := false
var original_defense: Dictionary = {}
var captain_profile: EnemyProfile
var captain_spawned := false
## True during the breather between the last grunt dying and the captain appearing.
var intermission_active := false
var intermission_left := 0.0
var fight_time := 0.0
var result_timer := 0.0
var enemies: Array = []

var arena_root: Node2D
## Holds the arena, hero and enemies. Its transform is the isometric projection; children
## keep plain ground coordinates.
var iso_layer: Node2D
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
	original_defense = {
		"shield_arc": tuning.block_arc_shield, "bare_arc": tuning.block_arc_bare,
		"shield_parry": tuning.parry_window_shield, "bare_parry": tuning.parry_window_bare
	}
	controller.configure(tuning)

	weapons.append(Weapon.sword_from(tuning))
	for path in WEAPON_PATHS:
		var w := load(path) as Weapon
		if w != null:
			weapons.append(w)
		else:
			push_warning("Could not load weapon %s" % path)
	captain_profile = load(CAPTAIN_PATH) as EnemyProfile
	if captain_profile == null:
		push_warning("Could not load %s: the captain will not appear." % CAPTAIN_PATH)

	arena_root = Node2D.new()
	arena_root.name = "ArenaRoot"
	add_child(arena_root)
	iso_layer = Node2D.new()
	iso_layer.name = "IsoLayer"
	iso_layer.transform = Iso.basis()
	arena_root.add_child(iso_layer)
	input.iso_view = true
	arena_view = ArenaView.new()
	arena_view.arena_size = tuning.arena_size
	iso_layer.add_child(arena_view)

	hero = HERO_SCENE.instantiate() as Hero
	hero.setup(tuning, input, tuning.arena_size)
	iso_layer.add_child(hero)
	hero.swung.connect(func(heavy: bool): sfx.play("swing_heavy" if heavy else "swing_light"))
	hero.hit_landed.connect(func(_e: Enemy, _h: bool): sfx.play("hit"))
	hero.dodged.connect(func(): sfx.play("dodge"))
	hero.damaged.connect(func(): sfx.play("hurt"))
	hero.died.connect(func(): sfx.play("hurt"))
	hero.blocked.connect(func(parried: bool): sfx.play("parry" if parried else "block"))
	hero.guard_broken.connect(func(): sfx.play("guard_break"))

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
	menu.set_weapons(weapons)
	menu.fight_requested.connect(func(m: int, w: int, sh: bool):
		shield_on = sh
		split_attacks = menu.split_attacks
		directional_guard = menu.directional_guard
		start_fight(m as Mode, w))

	sfx = Sfx.new()
	add_child(sfx)

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_set_state(State.MENU)


func weapon() -> Weapon:
	return weapons[weapon_index]


## Weapon name, with the shield when one is actually carried.
func loadout_name() -> String:
	return weapon().display_name + (" + Shield" if hero.has_shield else "")


func captain_alive() -> bool:
	for e in enemies:
		if e.is_captain() and not e.is_dead():
			return true
	return false


func enemies_alive() -> int:
	var n := 0
	for e in enemies:
		if not e.is_dead():
			n += 1
	return n


## Clears every piece of fight state and starts a new encounter. A negative weapon_idx
## keeps the current weapon.
func start_fight(new_mode: Mode, weapon_idx := -1) -> void:
	mode = new_mode
	if weapon_idx >= 0:
		weapon_index = clampi(weapon_idx, 0, weapons.size() - 1)
	for e in enemies:
		iso_layer.remove_child(e)
		e.queue_free()
	enemies.clear()
	controller.reset()
	controls.reset()
	input.clear()
	# The trial changes only this Game's private tuning copy.
	tuning.block_arc_shield = 140.0 if directional_guard else original_defense["shield_arc"]
	tuning.block_arc_bare = 110.0 if directional_guard else original_defense["bare_arc"]
	tuning.parry_window_shield = 0.30 if directional_guard else original_defense["shield_parry"]
	tuning.parry_window_bare = 0.23 if directional_guard else original_defense["bare_parry"]
	hero.block_stun_mult = 0.55 if directional_guard else 1.0
	controls.separate_attacks = split_attacks
	hero.equip(weapon(), shield_on)
	hero.reset(tuning.hero_spawn())
	captain_spawned = false
	intermission_active = false
	intermission_left = 0.0
	match mode:
		Mode.ONE:
			_spawn_grunts(1)
		Mode.THREE_CAPTAIN:
			_spawn_grunts(3)
		Mode.CAPTAIN_ONLY:
			_spawn_captain()
	outcome = Outcome.NONE
	fight_time = 0.0
	result_timer = 0.0
	menu.set_mode(mode)
	menu.set_weapon(weapon_index)
	menu.set_shield(shield_on)
	menu.set_split_attacks(split_attacks)
	menu.set_directional_guard(directional_guard)
	_set_state(State.FIGHTING)


func _spawn_grunts(count: int) -> void:
	var spots := tuning.enemy_spawns()
	for i in count:
		_add_enemy(spots[i], i, null)


func _add_enemy(pos: Vector2, idx: int, profile: EnemyProfile) -> Enemy:
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.setup(tuning, controller, hero, tuning.arena_size, idx, profile)
	e.position = pos
	e.struck.connect(func(): sfx.play("enemy_strike"))
	iso_layer.add_child(e)
	enemies.append(e)
	return e


## The captain appears at whichever end of the screen axis is farther from the hero.
func _spawn_captain() -> void:
	if captain_profile == null:
		return
	var top := tuning.enemy_spawns()[0]
	var bottom := tuning.hero_spawn()
	var pos := top if top.distance_to(hero.position) >= bottom.distance_to(hero.position) else bottom
	_add_enemy(pos, 0, captain_profile)
	captain_spawned = true


func _begin_intermission() -> void:
	intermission_active = true
	intermission_left = tuning.captain_intro_time
	hero.restore(tuning.captain_heal)
	sfx.play("captain")


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
	# Input events arrive between simulation steps: honour a just-pressed dodge/block
	# before collision, but still resolve enemy STRIKES before hero ATTACKS (tie = defeat).
	hero.pre_resolve_defense()
	for e in enemies:
		e.step(dt)
	hero.step(dt, enemies)
	_resolve_overlaps(dt)
	input.end_step()
	if intermission_active:
		intermission_left -= dt
		if intermission_left <= 0.0:
			intermission_active = false
			_spawn_captain()
	_check_outcome()


func _check_outcome() -> void:
	# Defeat wins a tie: the hero dying on the same step as the last enemy is a loss.
	if hero.is_dead():
		_finish(Outcome.DEFEAT)
		return
	if enemies_alive() > 0 or intermission_active:
		return
	if mode == Mode.THREE_CAPTAIN and not captain_spawned and captain_profile != null:
		_begin_intermission()
		return
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
	arena_root.visible = s != State.MENU
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
					menu.show_result(outcome == Outcome.VICTORY, fight_time, hero.hp, mode, loadout_name())


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
		elif event.physical_keycode == KEY_K:
			if event.pressed:
				input.press_block(false)
			else:
				input.release_block(false)
	elif event.pressed and event.physical_keycode == KEY_ENTER and menu.visible:
		shield_on = menu.shield_usable()
		start_fight(menu.mode as Mode, menu.weapon_index)


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
		if hero_solid and not a.is_immovable():
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
			if a.is_immovable() and b.is_immovable():
				continue
			elif a.is_immovable():
				b.position = b.clamp_to_arena(b.position + dir * push)
			elif b.is_immovable():
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
	# The isometric diamond spans x in [-H, W] and y in [0, (W + H) / 2] around the ground origin.
	var a := tuning.arena_size
	var extent := Vector2(a.x + a.y, (a.x + a.y) * 0.5)
	var s := minf(free.size.x / extent.x, free.size.y / extent.y)
	arena_root.scale = Vector2(s, s)
	var local_center := Vector2((a.x - a.y) * 0.5, (a.x + a.y) * 0.25)
	arena_root.position = free.get_center() - local_center * s
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
