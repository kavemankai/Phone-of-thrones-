class_name CampaignRun
extends RefCounted

const CHECKPOINT := "user://campaign_checkpoint.cfg"
const VERSION := 1
const FOE_NAMES := {
	"guard": "Gate Guard", "pike": "Pike Sentinel",
	"hound": "War Hound", "sweeper": "Hall Sweeper",
	"warden": "Iron Warden", "penitent": "Chain Penitent",
	"herald": "War Herald", "gate_captain": "Gate Captain",
}
## Which room table a run walks. The slice is the original three-room test (ROOMS below);
## a ward is a full table from WardData.
const PLAN_SLICE := "slice"
const PLAN_OUTER_WALLS := "outer_walls"
const ROOMS := [
	[
		{"name": "Shattered Gatehouse", "size": Vector2(340, 380), "ground": Color(0.19, 0.18, 0.17), "light": Color(0.62, 0.57, 0.46),
			"cover": [Rect2(126, 154, 88, 64)], "foes": ["guard", "pike"]},
	],
	[
		{"name": "Blood Kennels", "size": Vector2(365, 325), "ground": Color(0.23, 0.16, 0.13), "light": Color(0.71, 0.43, 0.24),
			"cover": [Rect2(58, 125, 32, 54), Rect2(271, 163, 34, 56)], "foes": ["hound"], "door": "Quiet pens", "heal": 10},
		{"name": "Blood Kennels", "size": Vector2(365, 325), "ground": Color(0.21, 0.13, 0.11), "light": Color(0.82, 0.37, 0.22),
			"cover": [Rect2(58, 125, 32, 54), Rect2(271, 163, 34, 56)], "foes": ["hound", "hound"], "door": "Feeding yard", "heal": 25},
	],
	[
		{"name": "Hall of Banners", "size": Vector2(330, 450), "ground": Color(0.22, 0.18, 0.18), "light": Color(0.66, 0.51, 0.46), "foes": ["sweeper", "guard"], "door": "Side aisle", "heal": 10},
		{"name": "Hall of Banners", "size": Vector2(330, 450), "ground": Color(0.19, 0.16, 0.18), "light": Color(0.62, 0.44, 0.46), "foes": ["sweeper", "pike", "hound"], "door": "Grand stairs", "heal": 25},
	],
]

var stage := 0
var variant := 0
var hp := 100.0
var weapon_index := 0
var shield := false
var split := false
var directional := false
var route := PackedInt32Array()
var guard_bonus := 0
## Pickups taken so far (Boon ids), in the order taken.
var boons := PackedStringArray()
## Fixed when the run starts. Decides which pickup each door offers, so a reloaded run
## shows the same doors.
var run_seed := 0
var plan := PLAN_SLICE
## Run totals for the ending screen. They count every attempt, including rooms retried.
var time := 0.0
var hits_taken := 0
var parries := 0


static func table_for(plan_id: String) -> Array:
	return WardData.OUTER_WALLS if plan_id == PLAN_OUTER_WALLS else ROOMS


func table() -> Array:
	return table_for(plan)


func stage_count() -> int:
	return table().size()


func title() -> String:
	return WardData.OUTER_WALLS_TITLE if plan == PLAN_OUTER_WALLS else "Fortress slice"


func room() -> Dictionary:
	return table()[stage][variant]


## Which variants of the next stage stand behind door 0 and door 1. A stage with one or two
## variants uses them as they are (one variant: both doors lead to it). A larger pool has
## two picked by the run seed, so a reloaded run shows the same doors.
func door_variants() -> PackedInt32Array:
	var doors := PackedInt32Array()
	var rooms := table()
	if stage + 1 >= rooms.size():
		return doors
	var count: int = rooms[stage + 1].size()
	if count == 1:
		return PackedInt32Array([0, 0])
	if count == 2:
		return PackedInt32Array([0, 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, stage, "doors"])
	var first := rng.randi_range(0, count - 1)
	var second := (first + 1 + rng.randi_range(0, count - 2)) % count
	doors.append(first)
	doors.append(second)
	return doors


## The rooms behind the two doors, in door order. Empty in the last room.
func choices() -> Array:
	var rooms := table()
	var behind: Array = []
	for index in door_variants():
		behind.append(rooms[stage + 1][index])
	return behind


func advance(choice: int, current_hp: float, max_hp: float) -> void:
	var doors := door_variants()
	if doors.is_empty():
		return
	choice = clampi(choice, 0, doors.size() - 1)
	var next_room: Dictionary = table()[stage + 1][doors[choice]]
	var gained := offer(choice)
	if gained != "":
		boons.append(gained)
	hp = minf(max_hp, current_hp + float(next_room.heal))
	guard_bonus = mini(16, guard_bonus + guard_reward(choice))
	stage += 1
	variant = doors[choice]
	route.append(variant)


## The pickup behind a door of the current room: two different ones not yet owned, chosen
## by the run seed and the stage. Empty when the catalogue is used up.
func offer(choice: int) -> String:
	var pool: PackedStringArray = []
	for id: String in Boon.ALL:
		if not boons.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return pool[0] if choice == 0 else ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, stage])
	var first := rng.randi_range(0, pool.size() - 1)
	var second := (first + 1 + rng.randi_range(0, pool.size() - 2)) % pool.size()
	return pool[first if choice == 0 else second]


func boon_set() -> Dictionary:
	var owned := {}
	for id in boons:
		owned[id] = true
	return owned


func guard_reward(choice: int) -> int:
	return mini(8, 16 - guard_bonus) if choice == 0 else 0


func save() -> Error:
	# Preserve an unreadable or incompatible checkpoint for recovery.
	if FileAccess.file_exists(CHECKPOINT) and read() == null:
		return ERR_FILE_CORRUPT
	var file := ConfigFile.new()
	file.set_value("run", "version", VERSION)
	file.set_value("run", "entry", [stage, variant, hp, weapon_index, shield, split, directional])
	file.set_value("run", "route", route)
	file.set_value("run", "guard_bonus", guard_bonus)
	file.set_value("run", "boons", boons)
	file.set_value("run", "seed", run_seed)
	file.set_value("run", "plan", plan)
	file.set_value("run", "stats", [time, hits_taken, parries])
	var temp := CHECKPOINT + ".tmp"
	var error := file.save(temp)
	if error == OK:
		error = DirAccess.rename_absolute(temp, CHECKPOINT)
	return error


static func read() -> CampaignRun:
	var file := ConfigFile.new()
	if file.load(CHECKPOINT) != OK or file.get_value("run", "version", 0) != VERSION:
		return null
	var entry: Variant = file.get_value("run", "entry", null)
	if not entry is Array or entry.size() != 7:
		return null
	if not (entry[0] is int and entry[1] is int and (entry[2] is float or entry[2] is int) and entry[3] is int
			and entry[4] is bool and entry[5] is bool and entry[6] is bool):
		return null
	# Older checkpoints have no plan: they are slice runs.
	var saved_plan: Variant = file.get_value("run", "plan", PLAN_SLICE)
	if not saved_plan is String or saved_plan not in [PLAN_SLICE, PLAN_OUTER_WALLS]:
		return null
	var rooms := table_for(saved_plan)
	if entry[0] < 0 or entry[0] >= rooms.size() or entry[1] < 0 or entry[1] >= rooms[entry[0]].size():
		return null
	if not is_finite(entry[2]) or entry[2] <= 0.0 or entry[3] < 0:
		return null
	var saved_route: Variant = file.get_value("run", "route", null)
	if not saved_route is PackedInt32Array or saved_route.size() != entry[0]:
		return null
	for i in saved_route.size():
		if saved_route[i] < 0 or saved_route[i] >= rooms[i + 1].size():
			return null
	if not saved_route.is_empty() and saved_route[-1] != entry[1]:
		return null
	var bonus: Variant = file.get_value("run", "guard_bonus", 0)
	if not bonus is int or bonus < 0 or bonus > 16:
		return null
	# Pickups were added after the first checkpoints: a file without them is a run with none.
	var saved_boons: Variant = file.get_value("run", "boons", PackedStringArray())
	if not saved_boons is PackedStringArray or saved_boons.size() > entry[0]:
		return null
	for i in saved_boons.size():
		if not Boon.exists(saved_boons[i]) or saved_boons.slice(0, i).has(saved_boons[i]):
			return null
	var saved_seed: Variant = file.get_value("run", "seed", 0)
	if not saved_seed is int:
		return null
	var result := CampaignRun.new()
	result.boons = saved_boons
	result.run_seed = saved_seed
	result.plan = saved_plan
	var stats: Variant = file.get_value("run", "stats", null)
	if stats is Array and stats.size() == 3 and (stats[0] is float or stats[0] is int) \
			and stats[1] is int and stats[2] is int:
		result.time = maxf(0.0, stats[0])
		result.hits_taken = maxi(0, stats[1])
		result.parries = maxi(0, stats[2])
	result.stage = entry[0]
	result.variant = entry[1]
	result.hp = entry[2]
	result.weapon_index = entry[3]
	result.shield = entry[4]
	result.split = entry[5]
	result.directional = entry[6]
	result.route = saved_route
	result.guard_bonus = bonus
	return result


static func enemy_profile(kind: String, t: Tuning, stage_index: int) -> EnemyProfile:
	var profile := EnemyProfile.grunt_from(t)
	profile.display_name = FOE_NAMES[kind]
	profile.max_hp += 3.0 * stage_index
	match kind:
		"pike":
			profile.id = "pike"
			profile.color = Color(0.56, 0.52, 0.43)
			profile.speed = 102.0
			profile.hover_range = 108.0
			var thrust := AttackDef.make("Pike thrust", 14.0, 118.0, 23.0, 0.82, 0.09, 1.10)
			thrust.lock_time = 0.34
			thrust.min_range = 52.0
			thrust.max_range = 111.0
			profile.attacks = [thrust]
		"hound":
			profile.id = "hound"
			profile.color = Color(0.53, 0.36, 0.26)
			profile.speed = 162.0
			profile.radius = 12.0
			profile.hover_range = 69.0
			profile.orbit_before_attack = 0.50
			profile.max_hp = 19.0 + 2.0 * stage_index
			var bite := AttackDef.make("Pounce", 9.0, 80.0, 42.0, 0.46, 0.16, 0.70, 0.0, 46.0)
			bite.lock_time = 0.23
			bite.max_range = 71.0
			profile.attacks = [bite]
		"sweeper":
			profile.id = "sweeper"
			profile.color = Color(0.64, 0.37, 0.32)
			profile.speed = 83.0
			profile.max_hp = 46.0
			profile.radius = 19.0
			var sweep := AttackDef.make("Wide sweep", 15.0, 76.0, 155.0, 0.86, 0.13, 0.92)
			sweep.max_range = 72.0
			profile.attacks = [sweep]
		"warden":
			# Answer: get behind the shield, or hit it while the bash recovers.
			profile.id = "warden"
			profile.color = Color(0.45, 0.50, 0.58)
			profile.speed = 78.0
			profile.max_hp = 55.0 + 3.0 * stage_index
			profile.radius = 19.0
			profile.hover_range = 80.0
			profile.front_guard_arc = 120.0
			profile.front_guard_mult = 0.25
			var bash := AttackDef.make("Shield bash", 12.0, 60.0, 70.0, 0.60, 0.10, 1.15)
			bash.max_range = 58.0
			bash.guard_cost_mult = 1.6
			profile.attacks = [bash]
		"penitent":
			# Answer: roll through the first sweep, or stay outside both and punish the second.
			profile.id = "penitent"
			profile.color = Color(0.64, 0.37, 0.32)
			profile.speed = 80.0
			profile.max_hp = 48.0 + 3.0 * stage_index
			profile.radius = 19.0
			profile.hover_range = 96.0
			var first := AttackDef.make("Chain sweep", 14.0, 92.0, 170.0, 0.90, 0.14, 0.25)
			first.max_range = 86.0
			first.chain_to = 1
			var second := AttackDef.make("Back sweep", 16.0, 92.0, 170.0, 0.45, 0.14, 1.00)
			second.lock_time = 0.15
			profile.attacks = [first, second]
		"herald":
			# Answer: kill it first. It never attacks; it makes the others faster.
			profile.id = "herald"
			profile.color = Color(0.75, 0.68, 0.30)
			profile.speed = 110.0
			profile.max_hp = 22.0 + 2.0 * stage_index
			profile.radius = 14.0
			profile.hover_range = 150.0
			profile.passive = true
			profile.aura_range = 170.0
			profile.aura_speed_mult = 1.35
			var jab := AttackDef.make("Staff", 6.0, 55.0, 40.0, 0.70, 0.10, 0.90)
			jab.max_range = 52.0
			profile.attacks = [jab]
	return profile


## The ward boss: the captain, with more health and a second phase at half health that
## moves faster and adds a full-circle whirl. `base` is never edited.
static func boss_profile(base: EnemyProfile) -> EnemyProfile:
	var profile := base.duplicate() as EnemyProfile
	profile.display_name = FOE_NAMES["gate_captain"]
	profile.max_hp = 190.0
	var whirl := AttackDef.make("Whirl", 20.0, 88.0, 360.0, 0.95, 0.14, 1.00)
	whirl.max_range = 80.0
	whirl.lock_time = 0.0
	var moves: Array[AttackDef] = []
	moves.assign(base.attacks)
	var whirl_index := moves.size()
	moves.append(whirl)
	profile.attacks = moves
	profile.phase2_at = 0.5
	profile.phase2_speed_mult = 1.2
	# Whirl first, then the captain's own moves with the whirl mixed in.
	var second_phase := PackedInt32Array([whirl_index])
	for index in base.pattern:
		second_phase.append(index)
	second_phase.append(whirl_index)
	profile.phase2_pattern = second_phase
	return profile


static func foe_summary(foes: Array) -> PackedStringArray:
	var labels: PackedStringArray = []
	for kind: String in FOE_NAMES:
		var count := foes.count(kind)
		if count > 0:
			labels.append("%d %s%s" % [count, FOE_NAMES[kind], "s" if count > 1 else ""])
	return labels
