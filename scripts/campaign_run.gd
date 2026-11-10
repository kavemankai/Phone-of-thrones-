class_name CampaignRun
extends RefCounted

const CHECKPOINT := "user://campaign_checkpoint.cfg"
const VERSION := 1
const ROOMS := [
	[
		{"name": "Gatehouse", "size": Vector2(340, 380), "ground": Color(0.22, 0.24, 0.28), "light": Color(0.48, 0.60, 0.75), "foes": ["guard"]},
	],
	[
		{"name": "Kennels", "size": Vector2(365, 325), "ground": Color(0.25, 0.18, 0.12), "light": Color(0.73, 0.45, 0.24), "foes": ["hound"], "door": "Quiet pens", "heal": 10},
		{"name": "Kennels", "size": Vector2(365, 325), "ground": Color(0.22, 0.15, 0.12), "light": Color(0.90, 0.40, 0.20), "foes": ["hound", "hound"], "door": "Feeding yard", "heal": 25},
	],
	[
		{"name": "Hall", "size": Vector2(330, 450), "ground": Color(0.23, 0.18, 0.25), "light": Color(0.70, 0.46, 0.72), "foes": ["sweeper", "guard"], "door": "Side aisle", "heal": 10},
		{"name": "Hall", "size": Vector2(330, 450), "ground": Color(0.20, 0.17, 0.26), "light": Color(0.62, 0.48, 0.88), "foes": ["sweeper", "guard", "hound"], "door": "Grand stairs", "heal": 25},
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


func room() -> Dictionary:
	return ROOMS[stage][variant]


func choices() -> Array:
	return ROOMS[stage + 1] if stage + 1 < ROOMS.size() else []


func advance(choice: int, current_hp: float, max_hp: float) -> void:
	hp = minf(max_hp, current_hp + float(choices()[choice].heal))
	guard_bonus = mini(16, guard_bonus + guard_reward(choice))
	stage += 1
	variant = choice
	route.append(choice)


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
	if entry[0] < 0 or entry[0] >= ROOMS.size() or entry[1] < 0 or entry[1] >= ROOMS[entry[0]].size():
		return null
	if not is_finite(entry[2]) or entry[2] <= 0.0 or entry[3] < 0:
		return null
	var saved_route: Variant = file.get_value("run", "route", null)
	if not saved_route is PackedInt32Array or saved_route.size() != entry[0]:
		return null
	for i in saved_route.size():
		if saved_route[i] < 0 or saved_route[i] >= ROOMS[i + 1].size():
			return null
	if not saved_route.is_empty() and saved_route[-1] != entry[1]:
		return null
	var bonus: Variant = file.get_value("run", "guard_bonus", 0)
	if not bonus is int or bonus < 0 or bonus > 16:
		return null
	var result := CampaignRun.new()
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
	profile.display_name = "Gate Guard"
	profile.max_hp += 3.0 * stage_index
	match kind:
		"hound":
			profile.id = "hound"
			profile.display_name = "Hound"
			profile.color = Color(0.88, 0.46, 0.24)
			profile.speed = 151.0
			profile.radius = 12.0
			profile.hover_range = 64.0
			profile.max_hp = 23.0 + 2.0 * stage_index
			var bite := AttackDef.make("Pounce", 9.0, 61.0, 43.0, 0.50, 0.11, 0.72, 0.0, 18.0)
			bite.max_range = 59.0
			profile.attacks = [bite]
		"sweeper":
			profile.id = "sweeper"
			profile.display_name = "Hall Sweeper"
			profile.color = Color(0.68, 0.36, 0.73)
			profile.speed = 83.0
			profile.max_hp = 46.0
			profile.radius = 19.0
			var sweep := AttackDef.make("Wide sweep", 15.0, 76.0, 155.0, 0.86, 0.13, 0.92)
			sweep.max_range = 72.0
			profile.attacks = [sweep]
	return profile


static func foe_summary(foes: Array) -> String:
	var labels: PackedStringArray = []
	for kind: String in ["guard", "hound", "sweeper"]:
		var count := foes.count(kind)
		if count > 0:
			labels.append("%d %s%s" % [count, kind.capitalize(), "s" if count > 1 else ""])
	return " + ".join(labels)
