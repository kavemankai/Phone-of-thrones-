class_name Game
extends Node
## Owns the encounter: builds the scene, runs the simulation in fixed sub-steps, decides
## victory or defeat, and handles retry and pause. step(dt) is public so tests can drive it.
## Device input arrives as InputMap actions (see InputActions) and is translated into
## CombatInput here; nothing below this node knows about keys or pads.

enum State { MENU, FIGHTING, RESULT, ROOM_CLEAR, DOOR_CHOICE }
enum Outcome { NONE, VICTORY, DEFEAT }
## ONE: a single enemy for practice. THREE_CAPTAIN: three enemies, then the captain.
## CAPTAIN_ONLY: skip straight to the captain.
enum Mode { ONE, THREE_CAPTAIN, CAPTAIN_ONLY }

const SUBSTEP := 1.0 / 60.0
const MAX_FRAME_DT := 0.1
const HUD_HEIGHT := 110.0
## Gap above the arena on PC, where the status bar sits under the arena instead.
const ARENA_TOP_MARGIN := 14.0
## Height of the PC status strip under the arena. The phone build keeps its touch band.
const DESKTOP_BAR_HEIGHT := 96.0
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
const DOOR_REACH := 49.0
## The combined test map: one variant of each Ward I stage ([stage, variant] in
## WardData.OUTER_WALLS), stacked in a column with a wall and a gate between neighbours.
const MAP_ROOMS := [[0, 0], [1, 1], [2, 1], [3, 0], [4, 0]]
const MAP_WALL := 18.0
const MAP_GATE_WIDTH := 84.0

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
var campaign: CampaignRun
var checkpoint_message := ""
var _clear_delay := 0.0
## Enemy groups still to enter the current campaign room.
var _waves_left: Array = []
## Seconds left to show the "reinforcements" banner.
var wave_notice := 0.0
## Groups called in mid-fight (the Tyrant's second phase). They enter on the next step, so
## nothing is added to the enemy list while a strike is still being resolved.
var _summons: Array = []
## The run that just ended set a new best time.
var _new_best := false
## Floor vents of the current room, and for each "vent:body" the last cycle that burned it.
var _vents: Array[Rect2] = []
var _vent_burned: Dictionary = {}
## Combined test map state. Room 0 is where the hero starts; gate k stands between room k
## and room k + 1 and opens when every enemy of room k is dead.
var map_active := false
var map_label := ""
var _map_rooms: Array[Rect2] = []
var _map_names: Array[String] = []
var _map_walls: Array[Rect2] = []
var _map_gates: Array[Rect2] = []
var _map_gate_open: Array[bool] = []
var _map_props: Array = []
var _map_prop_styles: Array = []
## The furthest room the hero has reached. Enemies of later rooms wait until then.
var _map_room := 0
var _view_size := Vector2(400, 400)
var _view_centre := Vector2.ZERO
var _view_scale := 1.0
## First-room control prompts: 0 move, 1 attack, 2 roll, 3 guard, 4 finished.
const TUTORIAL_STEPS := 4
var tutorial_step := 0
var _tutorial_moved := 0.0
var _test_room_size := Vector2(340, 380)
## Pause is a flag on top of FIGHTING, so the fight state underneath is untouched.
var paused := false
## Phone build only: show and read the on-screen buttons. Never on desktop.
var touch_ui := false
var prompt_style: InputPrompts.Style = InputPrompts.Style.KEYBOARD
## The guard button was down when the pause ended, so no press event will arrive for it.
var _guard_held_over_pause := false

var arena_root: Node2D
## Holds the arena, hero and enemies. Its transform is the isometric projection; children
## keep plain ground coordinates.
var iso_layer: Node2D
var arena_view: ArenaView
var hero: Hero
var controls: TouchControls
var hud: CombatHud
var menu: MenuPanel
var pause_panel: PausePanel
var bindings_panel: BindingsPanel
var ending_panel: EndingPanel
var _bindings_return_panel: Control
var _bindings_return_focus: Control
var sfx: Sfx
var fx: CombatFx
## Where the arena sits before any screen shake is added.
var _arena_origin := Vector2.ZERO


func _ready() -> void:
	InputActions.ensure()
	GameSettings.ensure_loaded()
	if GameSettings.tutorial_done:
		tutorial_step = TUTORIAL_STEPS
	touch_ui = OS.has_feature("mobile")
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
	fx = CombatFx.new()
	iso_layer.add_child(fx)
	hero.swung.connect(func(heavy: bool):
		sfx.play("swing_heavy" if heavy else "swing_light")
		_tutorial_did(1))
	hero.hit_landed.connect(func(e: Enemy, heavy: bool):
		sfx.play("hit")
		_fx_hit_landed(e, heavy))
	hero.dodged.connect(func():
		sfx.play("dodge")
		_tutorial_did(2))
	hero.damaged.connect(func():
		sfx.play("hurt")
		_count_hit()
		_fx_hero_hurt())
	hero.died.connect(func():
		sfx.play("hurt")
		_count_hit()
		_fx_hero_hurt())
	hero.blocked.connect(func(parried: bool):
		sfx.play("parry" if parried else "block")
		_count_parry(parried)
		_fx_blocked(parried))
	hero.guard_broken.connect(func():
		sfx.play("guard_break")
		fx.shake(6.0, 0.25))

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
	menu.map_requested.connect(func(w: int, sh: bool): start_map(w, sh))
	menu.fight_requested.connect(func(m: int, w: int, sh: bool):
		if campaign != null and state == State.RESULT and outcome == Outcome.DEFEAT:
			_start_campaign_room()
			return
		if map_active and state == State.RESULT:
			start_map(w, sh)
			return
		shield_on = sh
		split_attacks = menu.split_attacks
		directional_guard = menu.directional_guard
		start_fight(m as Mode, w))
	menu.campaign_requested.connect(func(w: int, sh: bool):
		_new_campaign(w, sh, CampaignRun.PLAN_FORTRESS, menu.hard_run))
	menu.credits_requested.connect(_open_credits)
	menu.continue_requested.connect(_continue_campaign)
	menu.quit_requested.connect(func(): get_tree().quit())
	pause_panel = PausePanel.new()
	ui.add_child(pause_panel)
	pause_panel.resume_requested.connect(resume_game)
	pause_panel.restart_requested.connect(_restart_room)
	pause_panel.loadout_requested.connect(return_to_menu)
	pause_panel.quit_requested.connect(func(): get_tree().quit())
	ending_panel = EndingPanel.new()
	ui.add_child(ending_panel)
	ending_panel.closed.connect(_on_ending_closed)
	bindings_panel = BindingsPanel.new()
	ui.add_child(bindings_panel)
	menu.controls_requested.connect(_open_bindings.bind(menu))
	pause_panel.controls_requested.connect(_open_bindings.bind(pause_panel))
	bindings_panel.closed.connect(_close_bindings)

	sfx = Sfx.new()
	add_child(sfx)

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		prompt_style = InputPrompts.style_for_joypad(pads[0])
	_apply_prompt_style()

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_set_state(State.MENU)


func weapon() -> Weapon:
	return weapons[weapon_index]


## Weapon name, with the shield when one is actually carried.
func loadout_name() -> String:
	return weapon().display_name + (" + Shield" if hero.has_shield else "")


func captain_alive() -> bool:
	return not captain_name().is_empty()


func captain_name() -> String:
	for e in enemies:
		if e.is_captain() and not e.is_dead():
			return e.profile.display_name
	return ""


func enemies_alive() -> int:
	var n := 0
	for e in enemies:
		if not e.is_dead():
			n += 1
	return n


## Clears every piece of fight state and starts a new encounter. A negative weapon_idx
## keeps the current weapon.
func start_fight(new_mode: Mode, weapon_idx := -1) -> void:
	campaign = null
	checkpoint_message = ""
	mode = new_mode
	if weapon_idx >= 0:
		weapon_index = clampi(weapon_idx, 0, weapons.size() - 1)
	_prepare_room(_test_room_size if arena_view.room_style >= 0 else tuning.arena_size)
	match mode:
		Mode.ONE:
			_spawn_grunts(1)
		Mode.THREE_CAPTAIN:
			_spawn_grunts(3)
		Mode.CAPTAIN_ONLY:
			_spawn_captain()
	_begin_room()


func _prepare_room(room_size: Vector2) -> void:
	for e in enemies:
		iso_layer.remove_child(e)
		e.queue_free()
	enemies.clear()
	controller.reset()
	controls.reset()
	_release_all_input()
	paused = false
	_waves_left = []
	_summons = []
	_new_best = false
	ending_panel.visible = false
	wave_notice = 0.0
	_vents.clear()
	_vent_burned.clear()
	map_active = false
	map_label = ""
	_map_rooms.clear()
	_map_names.clear()
	_map_walls.clear()
	_map_gates.clear()
	_map_gate_open.clear()
	_map_props.clear()
	_map_prop_styles.clear()
	_map_room = 0
	hero.nav_override = false
	hero.nav_cover.clear()
	hero.nav_waypoints.clear()
	arena_view.tiles.clear()
	arena_view.walls.clear()
	arena_view.locked_gates.clear()
	arena_view.open_gates.clear()
	arena_view.cover_styles.clear()
	arena_view.vents.clear()
	arena_view.vent_time = 0.0
	fx.clear()
	tuning.arena_size = room_size
	hero.arena_size = room_size
	hero.arena_cover.clear()
	arena_view.arena_size = room_size
	arena_view.cover.clear()
	arena_view.room_style = -1
	arena_view.room_ground = ArenaView.GROUND
	arena_view.room_light = ArenaView.BORDER
	arena_view.doors_open = false
	arena_view.has_doors = false
	arena_view.near_door = -1
	# The trial changes only this Game's private tuning copy.
	tuning.block_arc_shield = 140.0 if directional_guard else original_defense["shield_arc"]
	tuning.block_arc_bare = 110.0 if directional_guard else original_defense["bare_arc"]
	tuning.parry_window_shield = 0.30 if directional_guard else original_defense["shield_parry"]
	tuning.parry_window_bare = 0.23 if directional_guard else original_defense["bare_parry"]
	hero.block_stun_mult = 0.55 if directional_guard else 1.0
	controls.separate_attacks = split_attacks
	hero.equip(weapon(), shield_on)
	hero.run_guard_bonus = float(campaign.guard_bonus) if campaign != null else 0.0
	hero.boons = campaign.boon_set() if campaign != null else {}
	hero.damage_taken_mult = Vow.FRAILTY_DAMAGE_MULT \
			if campaign != null and campaign.has_vow(Vow.FRAILTY) else 1.0
	controller.max_commits = tuning.max_commits + (Vow.FURY_EXTRA_ATTACKERS
			if campaign != null and campaign.has_vow(Vow.FURY) else 0)
	hero.reset(tuning.hero_spawn())
	captain_spawned = false
	intermission_active = false
	intermission_left = 0.0


func _begin_room() -> void:
	arena_view.rebuild_props(iso_layer)
	match arena_view.room_style:
		3:
			sfx.set_bed("forge")
		4:
			sfx.set_bed("crown_pit")
		_:
			sfx.set_bed("outer_walls")
	arena_view.queue_redraw()
	_apply_layout()
	outcome = Outcome.NONE
	fight_time = 0.0
	result_timer = 0.0
	menu.set_mode(mode)
	menu.set_weapon(weapon_index)
	menu.set_shield(shield_on)
	menu.set_split_attacks(split_attacks)
	menu.set_directional_guard(directional_guard)
	_apply_prompt_style()
	_set_state(State.FIGHTING)


## Impact feedback. Each of these only asks CombatFx for a freeze, a shake or a mark; the
## simulation has already resolved the hit.
func _fx_hit_landed(e: Enemy, heavy: bool) -> void:
	fx.spark(e.position, Color(1.0, 0.86, 0.55) if heavy else Color(1, 1, 1), 30.0 if heavy else 20.0)
	fx.hit_stop(0.09 if heavy else 0.045)
	if heavy:
		fx.shake(3.5, 0.16)
	if e.is_dead():
		fx.ring(e.position, Color(1.0, 0.55, 0.35), 46.0, 0.30)


func _fx_hero_hurt() -> void:
	fx.spark(hero.position, Color(1.0, 0.35, 0.28), 26.0)
	fx.hit_stop(0.06)
	fx.shake(5.0, 0.20)


func _fx_blocked(parried: bool) -> void:
	if parried:
		fx.ring(hero.position, Color(1.0, 0.85, 0.3), 70.0, 0.36)
		fx.spark(hero.position, Color(1.0, 0.92, 0.6), 30.0, 0.26)
		fx.hit_stop(0.12)
	else:
		fx.spark(hero.position, Color(0.65, 0.85, 1.0), 16.0, 0.16)
		fx.hit_stop(0.03)


## The first room of a ward teaches the controls one at a time, once per machine.
func tutorial_showing() -> bool:
	return tutorial_step < TUTORIAL_STEPS and state == State.FIGHTING and campaign != null \
			and campaign.is_ward_run() and campaign.stage == 0


## What to show for the current step, naming the buttons of the device in use.
func tutorial_text() -> String:
	var rows := InputPrompts.combat(prompt_style, not split_attacks)
	# Pad rows are move, aim, light, heavy, roll, guard; the keyboard has no aim row.
	var shift := 1 if prompt_style != InputPrompts.Style.KEYBOARD else 0
	match tutorial_step:
		0:
			return "Move with %s" % rows[0][0]
		1:
			return "%s light attack      %s heavy attack" % [rows[1 + shift][0], rows[2 + shift][0]]
		2:
			return "%s rolls through an attack" % rows[3 + shift][0]
		3:
			return "Hold %s to guard. Raise it just before a hit to parry." % rows[4 + shift][0]
	return ""


func _tutorial_did(step: int) -> void:
	if tutorial_showing() and tutorial_step == step:
		tutorial_step += 1
		if tutorial_step >= TUTORIAL_STEPS:
			GameSettings.tutorial_done = true
			GameSettings.save()


## Steps that have no signal of their own: walking for half a second, and raising the guard.
func _tutorial_watch(delta: float) -> void:
	if not tutorial_showing():
		return
	if tutorial_step == 0:
		if input.move_vector().length() > 0.5:
			_tutorial_moved += delta
		if _tutorial_moved >= 0.5:
			_tutorial_did(0)
	elif tutorial_step == 3 and hero.is_guarding():
		_tutorial_did(3)


func _count_hit() -> void:
	if campaign != null and state == State.FIGHTING:
		campaign.hits_taken += 1


func _count_parry(parried: bool) -> void:
	if parried and campaign != null and state == State.FIGHTING:
		campaign.parries += 1


## Starts a run. The menu starts the first ward; the default is the original three-room
## slice, kept so its checks still describe what they were written for.
func _new_campaign(w: int, shield: bool, plan := CampaignRun.PLAN_SLICE, oathbound := false) -> void:
	campaign = CampaignRun.new()
	campaign.plan = plan
	if oathbound:
		campaign.swear_oathbound()
	campaign.weapon_index = w
	campaign.shield = shield
	campaign.split = menu.split_attacks
	campaign.directional = menu.directional_guard
	campaign.hp = tuning.hero_max_hp
	campaign.run_seed = randi()
	_save_campaign()
	_start_campaign_room()


func _continue_campaign() -> void:
	var saved := CampaignRun.read()
	if saved == null:
		menu.set_continue_available(false)
		return
	campaign = saved
	checkpoint_message = ""
	_start_campaign_room()


func _save_campaign() -> void:
	checkpoint_message = "" if campaign.save() == OK else "Checkpoint could not be saved."


func _start_campaign_room() -> void:
	var room := campaign.room()
	weapon_index = clampi(campaign.weapon_index, 0, weapons.size() - 1)
	shield_on = campaign.shield
	split_attacks = campaign.split
	directional_guard = campaign.directional
	if arena_view.room_style < 0:
		_test_room_size = tuning.arena_size
	_prepare_room(room["size"])
	arena_view.room_style = room.get("style", campaign.stage)
	arena_view.has_doors = not campaign.choices().is_empty()
	arena_view.room_ground = room.ground
	arena_view.room_light = room.light
	hero.arena_cover.assign(room.get("cover", []))
	arena_view.cover.assign(hero.arena_cover)
	_vents.assign(room.get("vents", []))
	arena_view.vents.assign(_vents)
	hero.hp = clampf(campaign.hp, 1.0, tuning.hero_max_hp)
	_waves_left = room.get("waves", []).duplicate()
	wave_notice = 0.0
	_spawn_group(room.foes, tuning.enemy_spawns())
	_begin_room()


func _spawn_group(kinds: Array, spots: Array[Vector2]) -> void:
	for i in mini(kinds.size(), spots.size()):
		var kind := String(kinds[i])
		# Vow of Veterans: the first of each group is its veteran, where the kind has one.
		if i == 0 and campaign != null and campaign.has_vow(Vow.VETERANS) \
				and CampaignRun.FOE_NAMES.has(kind + "!"):
			kind += "!"
		_add_enemy(spots[i], enemies.size(), _campaign_profile(kind))


func _campaign_profile(kind: String) -> EnemyProfile:
	if kind == "gate_captain" and captain_profile != null:
		return CampaignRun.boss_profile(captain_profile)
	if kind == "crown_tyrant" and captain_profile != null:
		return CampaignRun.tyrant_profile(captain_profile)
	var profile := CampaignRun.enemy_profile(kind, tuning, campaign.stage)
	if campaign.has_vow(Vow.IRON):
		profile.max_hp = roundf(profile.max_hp * Vow.IRON_HEALTH_MULT)
	return profile


## The next group enters from whichever end of the room is farther from the hero.
## A boss crossing into its second phase: a ring, a long freeze, a hard shake. The Crown
## Tyrant also calls two hounds, which enter on the next step.
func _on_phase_changed(e: Enemy) -> void:
	fx.ring(e.position, Color(1.0, 0.6, 0.25), 110.0, 0.5)
	fx.hit_stop(0.15)
	fx.shake(8.0, 0.4)
	if e.profile.id == "crown_tyrant":
		_summons.append(["hound", "hound"])


func _spawn_next_wave() -> void:
	_spawn_far_group(_waves_left.pop_front())


func _spawn_far_group(kinds: Array) -> void:
	var spots := tuning.enemy_spawns()
	var far_end := tuning.hero_spawn()
	if far_end.distance_to(hero.position) > spots[0].distance_to(hero.position):
		var centre := tuning.arena_size * 0.5
		for i in spots.size():
			spots[i] = centre * 2.0 - spots[i]
	_spawn_group(kinds, spots)
	wave_notice = 1.6
	sfx.play("captain")


## The combined test map: every Ward I room on one floor, hero at the bottom, the Gate
## Captain at the top. No doors to choose and no pickups; each gate stays locked until the
## room in front of it is cleared, then you walk through.
func start_map(weapon_idx: int, shield: bool) -> void:
	campaign = null
	checkpoint_message = ""
	shield_on = shield
	split_attacks = menu.split_attacks
	directional_guard = menu.directional_guard
	if weapon_idx >= 0:
		weapon_index = clampi(weapon_idx, 0, weapons.size() - 1)
	var picks: Array[Dictionary] = []
	var width := 0.0
	var depth := MAP_WALL * (MAP_ROOMS.size() - 1)
	for pick: Array in MAP_ROOMS:
		var room: Dictionary = WardData.OUTER_WALLS[pick[0]][pick[1]]
		picks.append(room)
		var extent: Vector2 = room["size"]
		width = maxf(width, extent.x)
		depth += extent.y
	var map_size := Vector2(width, depth)
	if arena_view.room_style < 0:
		_test_room_size = tuning.arena_size
	_prepare_room(map_size)
	map_active = true
	_view_size = Vector2(width, 400.0)
	arena_view.room_style = 0
	arena_view.has_doors = false

	var gate_left := (width - MAP_GATE_WIDTH) * 0.5
	var gate_right := gate_left + MAP_GATE_WIDTH
	var hero_start := Vector2.ZERO
	var spawns: Array = []
	var cursor := depth
	for k in picks.size():
		var room := picks[k]
		var extent: Vector2 = room["size"]
		var origin := Vector2((width - extent.x) * 0.5, cursor - extent.y)
		var area := Rect2(origin, extent)
		cursor = origin.y - MAP_WALL
		_map_rooms.append(area)
		_map_names.append(String(room["name"]))
		arena_view.tiles.append({"rect": area, "style": int(room.get("style", k)), "tint": room["ground"]})
		# A room narrower than the map is closed in at the sides.
		if origin.x > 0.5:
			_map_walls.append(Rect2(0.0, origin.y, origin.x, extent.y))
			_map_walls.append(Rect2(area.end.x, origin.y, width - area.end.x, extent.y))
		var props: Array[Rect2] = []
		for footprint: Rect2 in room.get("cover", []):
			props.append(Rect2(footprint.position + origin, footprint.size))
		_map_props.append(props)
		_map_prop_styles.append(int(room.get("style", 0)))
		for strip: Rect2 in room.get("vents", []):
			_vents.append(Rect2(strip.position + origin, strip.size))
		if k < picks.size() - 1:
			var wall_y := origin.y - MAP_WALL
			_map_walls.append(Rect2(0.0, wall_y, gate_left, MAP_WALL))
			_map_walls.append(Rect2(gate_right, wall_y, width - gate_right, MAP_WALL))
			_map_gates.append(Rect2(gate_left, wall_y, MAP_GATE_WIDTH, MAP_WALL))
			_map_gate_open.append(false)
		# Spawn points use the room's own size, then move to where the room sits.
		tuning.arena_size = extent
		var spots := tuning.enemy_spawns()
		if k == 0:
			hero_start = origin + tuning.hero_spawn()
		tuning.arena_size = map_size
		var kinds: Array = room["foes"]
		for i in mini(kinds.size(), spots.size()):
			spawns.append([origin + spots[i], String(kinds[i]), k])

	for entry: Array in spawns:
		var kind: String = entry[1]
		var room_index: int = entry[2]
		var profile := CampaignRun.boss_profile(captain_profile) \
				if kind == "gate_captain" and captain_profile != null \
				else CampaignRun.enemy_profile(kind, tuning, room_index)
		var e := _add_enemy(entry[0], enemies.size(), profile)
		e.set_meta(&"map_room", room_index)
	arena_view.vents.assign(_vents)
	hero.position = hero_start
	_map_room = 0
	_refresh_map_cover()
	_begin_room()


## Rebuilds what blocks movement and attacks (walls, locked gates, every prop) and what
## enemies route around (the props of the room being fought in).
func _refresh_map_cover() -> void:
	var solid: Array[Rect2] = []
	var styles: Array[int] = []
	var locked: Array[Rect2] = []
	var opened: Array[Rect2] = []
	solid.append_array(_map_walls)
	for k in _map_gates.size():
		if _map_gate_open[k]:
			opened.append(_map_gates[k])
		else:
			locked.append(_map_gates[k])
	solid.append_array(locked)
	var props: Array[Rect2] = []
	for k in _map_props.size():
		for footprint: Rect2 in _map_props[k]:
			props.append(footprint)
			styles.append(int(_map_prop_styles[k]))
	solid.append_array(props)
	hero.arena_cover.assign(solid)
	hero.nav_override = true
	hero.nav_cover.assign(_map_props[_map_room])
	hero.nav_waypoints.clear()
	for gate in opened:
		hero.nav_waypoints.append(gate.get_center())
	arena_view.walls.assign(_map_walls)
	arena_view.locked_gates.assign(locked)
	arena_view.open_gates.assign(opened)
	arena_view.cover.assign(props)
	arena_view.cover_styles.assign(styles)
	arena_view.queue_redraw()
	map_label = "All rooms   %d / %d   %s" % [_map_room + 1, _map_rooms.size(), _map_names[_map_room]]


## Once per simulation step on the combined map: note the furthest room the hero has
## reached, and open the gate of any room whose enemies are all dead.
func _step_map() -> void:
	var changed := false
	for k in range(_map_room + 1, _map_rooms.size()):
		if _map_rooms[k].grow(MAP_WALL * 0.5).has_point(hero.position):
			_map_room = k
			changed = true
	for k in _map_gates.size():
		if _map_gate_open[k]:
			continue
		var cleared := true
		for e: Enemy in enemies:
			if int(e.get_meta(&"map_room", 0)) == k and not e.is_dead():
				cleared = false
				break
		if cleared:
			_map_gate_open[k] = true
			changed = true
			sfx.play("win")
			fx.ring(_map_gates[k].get_center(), Color(0.5, 1.0, 0.55), 90.0, 0.6)
	if changed:
		_refresh_map_cover()


## Where the arena must sit for the hero to be at the centre of the play area.
func _camera_target() -> Vector2:
	return _view_centre - Iso.to_screen(hero.position) * _view_scale


func _follow_hero(delta: float) -> void:
	_arena_origin = _arena_origin.lerp(_camera_target(), 1.0 - exp(-9.0 * delta))


func _restart_room() -> void:
	if map_active:
		start_map(-1, shield_on)
	elif campaign == null:
		start_fight(mode)
	else:
		_start_campaign_room()


func _spawn_grunts(count: int) -> void:
	var spots := tuning.enemy_spawns()
	for i in count:
		_add_enemy(spots[i], i, null)


func _add_enemy(pos: Vector2, idx: int, profile: EnemyProfile) -> Enemy:
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.setup(tuning, controller, hero, tuning.arena_size, idx, profile)
	e.position = pos
	e.struck.connect(func(): sfx.play("enemy_strike"))
	e.phase_changed.connect(_on_phase_changed.bind(e))
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
	if state != State.FIGHTING or paused:
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
	if campaign != null:
		campaign.time += dt
	_apply_auras()
	# Input events arrive between simulation steps: honour a just-pressed dodge/block
	# before collision, but still resolve enemy STRIKES before hero ATTACKS (tie = defeat).
	hero.pre_resolve_defense()
	for e in enemies:
		# On the combined map, rooms the hero has not reached yet stand still.
		if map_active and int(e.get_meta(&"map_room", 0)) > _map_room:
			continue
		e.step(dt)
	hero.step(dt, enemies)
	if map_active:
		_step_map()
	_resolve_overlaps(dt)
	while not _summons.is_empty() and campaign != null:
		_spawn_far_group(_summons.pop_front())
	_step_vents()
	input.end_step()
	if intermission_active:
		intermission_left -= dt
		if intermission_left <= 0.0:
			intermission_active = false
			_spawn_captain()
	_check_outcome()


## A bursting vent burns whoever stands in its strip, once per burst. A hit the hero's roll
## or hit immunity refuses is tried again next step, like an enemy strike.
func _step_vents() -> void:
	for i in _vents.size():
		if WardData.vent_state(i, fight_time) != WardData.Vent.BURSTING:
			continue
		var cycle := WardData.vent_cycle(i, fight_time)
		var strip := _vents[i]
		var hero_key := "%d:hero" % i
		if not hero.is_dead() and strip.has_point(hero.position) \
				and _vent_burned.get(hero_key, -1) != cycle:
			if hero.take_hit(WardData.VENT_DAMAGE):
				_vent_burned[hero_key] = cycle
		for e: Enemy in enemies:
			if e.is_dead() or not strip.has_point(e.position):
				continue
			var key := "%d:%d" % [i, e.get_instance_id()]
			if _vent_burned.get(key, -1) != cycle:
				_vent_burned[key] = cycle
				# From behind, so a Warden's front shield does not stop fire from the floor.
				e.take_hit(WardData.VENT_ENEMY_DAMAGE, e.position - e.facing * 10.0, 0.0)


## A living Herald speeds up the other living enemies inside its ring.
func _apply_auras() -> void:
	for e: Enemy in enemies:
		e.speed_buff = 1.0
	for source: Enemy in enemies:
		if source.is_dead() or source.profile.aura_range <= 0.0:
			continue
		for e: Enemy in enemies:
			if e == source or e.is_dead() or e.profile.aura_range > 0.0:
				continue
			if e.position.distance_to(source.position) <= source.profile.aura_range:
				e.speed_buff = maxf(e.speed_buff, source.profile.aura_speed_mult)


func _check_outcome() -> void:
	# Defeat wins a tie: the hero dying on the same step as the last enemy is a loss.
	if hero.is_dead():
		_finish(Outcome.DEFEAT)
		return
	if enemies_alive() > 0 or intermission_active:
		return
	if map_active:
		_finish(Outcome.VICTORY)
		return
	if campaign != null:
		if not _waves_left.is_empty():
			_spawn_next_wave()
			return
		if campaign.choices().is_empty():
			if CampaignRun.read() != null:
				var error := DirAccess.remove_absolute(CampaignRun.CHECKPOINT)
				checkpoint_message = "" if error == OK else "Could not close the checkpoint."
			if campaign.plan == CampaignRun.PLAN_FORTRESS:
				_new_best = RunRecords.note_win(weapon().display_name, campaign.time, campaign.hard)
			_finish(Outcome.VICTORY)
		else:
			_clear_delay = 0.55
			_release_all_input()
			hero.begin_room_clear()
			sfx.play("win")
			_set_state(State.ROOM_CLEAR)
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
	paused = false
	pause_panel.close()
	hud.visible = s != State.MENU
	arena_root.visible = s != State.MENU
	_update_touch_controls()
	match s:
		State.MENU:
			sfx.set_bed("title")
			menu.show_start()
			menu.set_continue_available(CampaignRun.read() != null)
		State.RESULT:
			sfx.set_bed("")
			menu.visible = false
		_:
			menu.visible = false
	state_changed.emit(s)


func _process(delta: float) -> void:
	if not paused:
		fx.advance(delta)
	fx.shake_enabled = GameSettings.screen_shake
	if map_active:
		_follow_hero(delta)
	arena_root.position = _arena_origin + fx.shake_offset()
	match state:
		State.FIGHTING:
			if paused:
				return
			wave_notice = maxf(0.0, wave_notice - delta)
			if not _vents.is_empty():
				arena_view.vent_time = fight_time
				arena_view.queue_redraw()
			_tutorial_watch(delta)
			_poll_devices()
			# Hit-stop: hold the fight for a few frames after an impact. Input is still read,
			# and its press flags wait in CombatInput for the next step, so nothing is lost.
			if fx.frozen():
				return
			step(delta)
		State.ROOM_CLEAR:
			if paused:
				return
			_clear_delay -= delta
			if _clear_delay <= 0.0:
				arena_view.doors_open = true
				arena_view.queue_redraw()
				_set_state(State.DOOR_CHOICE)
		State.DOOR_CHOICE:
			if paused:
				return
			_poll_devices()
			hero.walk_clear_room(minf(delta, MAX_FRAME_DT))
			_update_near_door()
		State.RESULT:
			wave_notice = 0.0
			if result_timer > 0.0:
				result_timer -= delta
				if result_timer <= 0.0:
					if campaign == null:
						menu.show_result(outcome == Outcome.VICTORY, fight_time, hero.hp, mode, loadout_name())
					elif outcome == Outcome.VICTORY and campaign.plan == CampaignRun.PLAN_FORTRESS:
						_show_fortress_ending()
					else:
						_show_campaign_result()
					menu.set_continue_available(CampaignRun.read() != null)


## The line of numbers for a finished run.
func _run_totals() -> String:
	var line := "Time %s      Hits taken %d      Parries %d" % [
		RunRecords.clock(campaign.time), campaign.hits_taken, campaign.parries]
	if campaign.hard:
		line += "      Oathbound"
	if _new_best:
		line += "      New best time"
	return line


## After the final boss: the ending and credits first, then the usual result screen.
func _show_fortress_ending() -> void:
	ending_panel.layout(get_viewport().get_visible_rect().size)
	ending_panel.show_ending(_run_totals())


func _open_credits() -> void:
	menu.hide()
	ending_panel.layout(get_viewport().get_visible_rect().size)
	ending_panel.show_credits()


func _on_ending_closed() -> void:
	if state == State.RESULT and campaign != null:
		_show_campaign_result()
		menu.set_continue_available(CampaignRun.read() != null)
	else:
		menu.show()


func _show_campaign_result() -> void:
	var won := outcome == Outcome.VICTORY
	var seconds := int(campaign.time)
	var totals := "Time %d:%02d      Hits taken %d      Parries %d      Seed %d" % [
		seconds / 60, seconds % 60, campaign.hits_taken, campaign.parries, campaign.run_seed]
	var carried := Boon.titles(campaign.boons)
	var pickups := "Pickups: " + (", ".join(carried) if not carried.is_empty() else "none")
	if not campaign.vows.is_empty():
		pickups += "\nVows: " + ", ".join(Vow.titles(campaign.vows))
	if won:
		var heading := "SLICE COMPLETE"
		if campaign.plan == CampaignRun.PLAN_OUTER_WALLS:
			heading = "OUTER WALLS BREACHED"
		elif campaign.plan == CampaignRun.PLAN_FORTRESS:
			heading = "THE FORTRESS HAS FALLEN"
		menu.show_campaign_result(true, heading, "%s\n%s" % [totals, pickups])
	else:
		menu.show_campaign_result(false, "DEFEAT", "Checkpoint: %s  (room %d of %d)\n%s" % [
			campaign.room().name, campaign.stage + 1, campaign.stage_count(), pickups])


func _update_near_door() -> void:
	var nearest := -1
	var distance := DOOR_REACH
	for i in 2:
		var candidate := hero.position.distance_to(arena_view.door_position(i))
		if candidate < distance:
			nearest = i
			distance = candidate
	if nearest != arena_view.near_door:
		arena_view.near_door = nearest
		arena_view.queue_redraw()


func _enter_near_door() -> void:
	_update_near_door()
	if arena_view.near_door < 0:
		return
	campaign.advance(arena_view.near_door, hero.hp, tuning.hero_max_hp)
	_save_campaign()
	_start_campaign_room()


## Held, analogue input: left stick / movement keys and the right stick. Read once per frame;
## the radial dead zones live in InputActions.
func _poll_devices() -> void:
	input.key_move = InputActions.read_move()
	input.aim = InputActions.read_aim()
	if _guard_held_over_pause and not Input.is_action_pressed(InputActions.GUARD):
		_drop_guard_carryover()


## Button edges. Each press sets a one-step flag in CombatInput, which the next simulation
## sub-step consumes and clears, so a press is acted on once however long the frame was.
func _input(event: InputEvent) -> void:
	if bindings_panel != null and bindings_panel.visible:
		if bindings_panel.handle_event(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		return
	_note_device(event)
	var menu_input := false
	if state != State.FIGHTING or paused:
		for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
			if event.is_action(action):
				menu_input = true
				break
	if not menu_input and event.is_action_pressed(InputActions.FULLSCREEN):
		pause_panel.toggle_fullscreen()
		return
	if state not in [State.FIGHTING, State.ROOM_CLEAR, State.DOOR_CHOICE]:
		return
	if paused:
		# Pause again or Back closes the pause. Everything else belongs to the panel.
		if event.is_action_pressed(&"ui_cancel") or (
				not menu_input and event.is_action_pressed(InputActions.PAUSE)):
			resume_game()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputActions.PAUSE):
		pause_game()
		get_viewport().set_input_as_handled()
		return
	if state == State.DOOR_CHOICE and event.is_action_pressed(&"ui_accept"):
		_enter_near_door()
		get_viewport().set_input_as_handled()
	elif state == State.DOOR_CHOICE and event is InputEventScreenTouch and event.pressed:
		_update_near_door()
		if arena_view.near_door >= 0:
			var door := arena_view.to_global(arena_view.door_position(arena_view.near_door))
			if event.position.distance_to(door) < 70.0:
				_enter_near_door()
				get_viewport().set_input_as_handled()
	elif state == State.FIGHTING:
		_combat_event(event)


func _open_bindings(panel: Control) -> void:
	_bindings_return_panel = panel
	_bindings_return_focus = get_viewport().gui_get_focus_owner()
	panel.hide()
	bindings_panel.open(prompt_style)


func _close_bindings() -> void:
	InputActions.release_all()
	_apply_prompt_style()
	_bindings_return_panel.show()
	if is_instance_valid(_bindings_return_focus):
		_bindings_return_focus.grab_focus()


func _combat_event(event: InputEvent) -> void:
	var from_pad := InputActions.is_pad_event(event)
	if event.is_action_pressed(InputActions.LIGHT):
		# Gamepad X is always an immediate light. The key keeps the v0.9 tap/hold unless the
		# split-attack option is on.
		if from_pad or split_attacks:
			input.press_light()
		else:
			input.press_attack(false)
	elif event.is_action_released(InputActions.LIGHT):
		if not from_pad:
			input.release_attack(false)
	elif event.is_action_pressed(InputActions.HEAVY):
		input.press_heavy()
	elif event.is_action_pressed(InputActions.DODGE):
		input.press_dodge()
	elif event.is_action_pressed(InputActions.GUARD):
		_drop_guard_carryover()
		if from_pad:
			input.set_pad_block(true)
		else:
			input.press_block(false)
	elif event.is_action_released(InputActions.GUARD):
		_drop_guard_carryover()
		if from_pad:
			input.set_pad_block(false)
		else:
			input.release_block(false)


func _drop_guard_carryover() -> void:
	if not _guard_held_over_pause:
		return
	_guard_held_over_pause = false
	input.release_block(false)
	input.set_pad_block(false)


## Stops the simulation and shows the pause panel. Held input is dropped, so nothing can
## stay stuck behind the panel.
func pause_game(reason := "") -> void:
	if state not in [State.FIGHTING, State.ROOM_CLEAR, State.DOOR_CHOICE] or paused:
		return
	paused = true
	_guard_held_over_pause = false
	input.clear()
	_update_touch_controls()
	pause_panel.set_pickups(campaign.boons if campaign != null else PackedStringArray(),
			campaign.vows if campaign != null else PackedStringArray())
	pause_panel.open(reason)


func resume_game() -> void:
	if not paused:
		return
	paused = false
	pause_panel.close()
	_update_touch_controls()
	input.clear()
	# A guard held through the pause is still held; sticks are read again next frame.
	_guard_held_over_pause = Input.is_action_pressed(InputActions.GUARD)
	if _guard_held_over_pause:
		input.press_block(false)


## Leaves the fight for the loadout screen (from the pause panel).
func return_to_menu() -> void:
	campaign = null
	map_active = false
	for e in enemies:
		iso_layer.remove_child(e)
		e.queue_free()
	enemies.clear()
	controller.reset()
	controls.reset()
	input.clear()
	_guard_held_over_pause = false
	outcome = Outcome.NONE
	_set_state(State.MENU)


func _update_touch_controls() -> void:
	controls.visible = touch_ui
	controls.set_enabled(touch_ui and state in [State.FIGHTING, State.DOOR_CHOICE] and not paused)


## Drop everything a device was holding: used when it can no longer send the release.
func _release_all_input() -> void:
	InputActions.release_all()
	_guard_held_over_pause = false
	input.clear()
	if controls != null:
		controls.reset()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		if paused:
			pause_panel.set_reason("Controller connected.")
		return
	_release_all_input()
	if Input.get_connected_joypads().is_empty():
		_set_prompt_style(InputPrompts.Style.KEYBOARD)
	if state in [State.FIGHTING, State.ROOM_CLEAR, State.DOOR_CHOICE]:
		if paused:
			pause_panel.set_reason("Controller disconnected.")
		else:
			pause_game("Controller disconnected.")


## Remember which kind of device was used last, so prompts name the right buttons.
func _note_device(event: InputEvent) -> void:
	var style := prompt_style
	if event is InputEventJoypadButton:
		if not event.pressed:
			return
		style = InputPrompts.style_for_joypad(event.device)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.5:
			return
		style = InputPrompts.style_for_joypad(event.device)
	elif event is InputEventKey:
		if not event.pressed:
			return
		style = InputPrompts.Style.KEYBOARD
	else:
		return
	_set_prompt_style(style)


func _set_prompt_style(style: InputPrompts.Style) -> void:
	if style == prompt_style:
		return
	prompt_style = style
	_apply_prompt_style()


func _apply_prompt_style() -> void:
	if menu != null:
		menu.set_prompt_style(prompt_style)
	if pause_panel != null:
		pause_panel.set_prompt_style(prompt_style, not split_attacks)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if controls == null or pause_panel == null:
			return
		_release_all_input()
		if state in [State.FIGHTING, State.ROOM_CLEAR, State.DOOR_CHOICE]:
			pause_game("Paused: the game window lost focus.")


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
	# The strip under the arena: touch buttons on a phone, the status bar and button legend
	# on PC. The arena never reaches into it.
	var band_h := vp.y * tuning.control_band_fraction if touch_ui else DESKTOP_BAR_HEIGHT + insets.w
	var top := insets.y + (HUD_HEIGHT if touch_ui else ARENA_TOP_MARGIN)
	if campaign != null and touch_ui:
		top += 35.0
	var free := Rect2(
		insets.x + 10.0,
		top,
		vp.x - insets.x - insets.z - 20.0,
		vp.y - band_h - top - 10.0)
	# The isometric diamond spans x in [-H, W] and y in [0, (W + H) / 2] around the ground origin.
	# A combined map is far larger than the screen: scale it as one room and follow the hero.
	var a := _view_size if map_active else tuning.arena_size
	var extent := Vector2(a.x + a.y, (a.x + a.y) * 0.5)
	var s := minf(free.size.x / extent.x, free.size.y / extent.y)
	arena_root.scale = Vector2(s, s)
	var local_center := Vector2((a.x - a.y) * 0.5, (a.x + a.y) * 0.25)
	_arena_origin = free.get_center() - local_center * s
	_view_centre = free.get_center()
	_view_scale = s
	if map_active:
		_arena_origin = _camera_target()
	arena_root.position = _arena_origin
	hud.layout(vp, insets, band_h)
	controls.layout(vp, band_h, insets)
	menu.layout(vp)
	pause_panel.layout(vp)
	bindings_panel.size = vp


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
