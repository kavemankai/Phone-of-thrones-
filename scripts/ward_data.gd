class_name WardData
extends RefCounted
## Room tables for full wards, in the same shape as CampaignRun.ROOMS: a list of stages,
## each a list of room variants. A stage with more than two variants is a pool; the run
## seed picks which two stand behind the doors.
##
## Room keys: name, door (label on the door that leads here), size, ground, light, style
## (floor dressing, see ArenaView), heal (granted on entry), foes (first group, at most
## three), and optionally cover (solid rectangles) and waves (further groups, each entering
## when the group before it is dead) and vents (floor strips that burst on a timer and
## hurt anyone standing in them, hero or enemy).

const OUTER_WALLS_TITLE := "Ward I: The Outer Walls"

const _GATE_COVER := [Rect2(126, 154, 88, 64)]
const _KENNEL_COVER := [Rect2(58, 125, 32, 54), Rect2(271, 163, 34, 56)]
const _FORGE_COVER := [Rect2(110, 170, 36, 56), Rect2(234, 134, 36, 56)]
## Two strips across the forge floor, clear of the anvils, that vent fire in turn.
const _FORGE_VENTS := [Rect2(18, 95, 344, 26), Rect2(18, 239, 344, 26)]

## Vent timing, in seconds of fight time. The first vent warns after VENT_DELAY; each later
## vent is VENT_STAGGER behind the one before. A cycle is a warning, a burst, then quiet.
const VENT_DELAY := 2.0
const VENT_STAGGER := 2.5
const VENT_CYCLE := 5.0
const VENT_WARN := 1.4
const VENT_BURST := 0.8
const VENT_DAMAGE := 10.0
const VENT_ENEMY_DAMAGE := 8.0
enum Vent { QUIET, WARNING, BURSTING }

const OUTER_WALLS := [
	[
		{"name": "Shattered Gatehouse", "door": "Breach", "size": Vector2(340, 380), "style": 0,
			"ground": Color(0.19, 0.18, 0.17), "light": Color(0.62, 0.57, 0.46),
			"cover": _GATE_COVER, "foes": ["guard", "pike"], "heal": 0},
	],
	[
		{"name": "Blood Kennels", "door": "Quiet pens", "size": Vector2(365, 325), "style": 1,
			"ground": Color(0.23, 0.16, 0.13), "light": Color(0.71, 0.43, 0.24),
			"cover": _KENNEL_COVER, "foes": ["hound"], "heal": 10},
		{"name": "Blood Kennels", "door": "Feeding yard", "size": Vector2(365, 325), "style": 1,
			"ground": Color(0.21, 0.13, 0.11), "light": Color(0.82, 0.37, 0.22),
			"cover": _KENNEL_COVER, "foes": ["hound", "hound"], "heal": 25},
		{"name": "Blood Kennels", "door": "Handler's run", "size": Vector2(365, 325), "style": 1,
			"ground": Color(0.22, 0.15, 0.14), "light": Color(0.76, 0.48, 0.30),
			"cover": _KENNEL_COVER, "foes": ["hound", "pike"], "heal": 20},
	],
	[
		{"name": "Hall of Banners", "door": "Side aisle", "size": Vector2(330, 450), "style": 2,
			"ground": Color(0.22, 0.18, 0.18), "light": Color(0.66, 0.51, 0.46),
			"foes": ["penitent", "guard"], "heal": 10},
		{"name": "Hall of Banners", "door": "Grand stairs", "size": Vector2(330, 450), "style": 2,
			"ground": Color(0.19, 0.16, 0.18), "light": Color(0.62, 0.44, 0.46),
			"foes": ["penitent", "pike", "hound"], "heal": 25},
		{"name": "Hall of Banners", "door": "Shield line", "size": Vector2(330, 450), "style": 2,
			"ground": Color(0.20, 0.18, 0.20), "light": Color(0.58, 0.55, 0.62),
			"foes": ["warden", "guard"], "heal": 15},
	],
	[
		{"name": "Cinder Forge", "door": "Bellows", "size": Vector2(380, 360), "style": 3,
			"ground": Color(0.17, 0.13, 0.12), "light": Color(0.92, 0.46, 0.18),
			"cover": _FORGE_COVER, "vents": _FORGE_VENTS, "foes": ["warden", "herald"], "heal": 15},
		{"name": "Cinder Forge", "door": "Ash pit", "size": Vector2(380, 360), "style": 3,
			"ground": Color(0.15, 0.12, 0.12), "light": Color(0.98, 0.40, 0.14),
			"cover": _FORGE_COVER, "vents": _FORGE_VENTS, "foes": ["herald", "hound", "hound"], "heal": 20},
		{"name": "Cinder Forge", "door": "Anvil row", "size": Vector2(380, 360), "style": 3,
			"ground": Color(0.18, 0.14, 0.12), "light": Color(0.88, 0.52, 0.22),
			"cover": _FORGE_COVER, "vents": _FORGE_VENTS, "foes": ["penitent", "warden"], "waves": [["pike", "guard"]],
			"heal": 30},
	],
	[
		{"name": "Crown Pit", "door": "The pit", "size": Vector2(400, 400), "style": 4,
			"ground": Color(0.14, 0.13, 0.15), "light": Color(0.95, 0.78, 0.30),
			"foes": ["gate_captain"], "heal": 20},
	],
]


static func _vent_clock(index: int, fight_time: float) -> float:
	return fight_time - VENT_DELAY - VENT_STAGGER * index


## What vent `index` is doing at `fight_time`.
static func vent_state(index: int, fight_time: float) -> Vent:
	var clock := _vent_clock(index, fight_time)
	if clock < 0.0:
		return Vent.QUIET
	var into := fmod(clock, VENT_CYCLE)
	if into < VENT_WARN:
		return Vent.WARNING
	if into < VENT_WARN + VENT_BURST:
		return Vent.BURSTING
	return Vent.QUIET


## Which cycle the vent is in, so a burst hurts each body once. -1 before the first.
static func vent_cycle(index: int, fight_time: float) -> int:
	var clock := _vent_clock(index, fight_time)
	return -1 if clock < 0.0 else int(clock / VENT_CYCLE)


## 0 to 1 through the warning, for drawing.
static func vent_warning_progress(index: int, fight_time: float) -> float:
	var clock := _vent_clock(index, fight_time)
	if clock < 0.0:
		return 0.0
	return clampf(fmod(clock, VENT_CYCLE) / VENT_WARN, 0.0, 1.0)


## Problems with a room table, empty when it is sound. `known_foes` is the set of enemy
## kinds the game can build (CampaignRun.FOE_NAMES).
static func validate(table: Array, known_foes: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = []
	if table.is_empty():
		problems.append("no stages")
	for s in table.size():
		var stage: Array = table[s]
		if stage.is_empty():
			problems.append("stage %d has no rooms" % s)
		for v in stage.size():
			var room: Dictionary = stage[v]
			var where := "stage %d room %d" % [s, v]
			for key: String in ["name", "door", "size", "ground", "light", "foes", "heal"]:
				if not room.has(key):
					problems.append("%s: missing %s" % [where, key])
			var groups: Array = [room.get("foes", [])]
			groups.append_array(room.get("waves", []))
			for group: Array in groups:
				if group.is_empty() or group.size() > 3:
					problems.append("%s: a group needs one to three foes" % where)
				for kind: String in group:
					if not known_foes.has(kind):
						problems.append("%s: unknown foe %s" % [where, kind])
			var size: Vector2 = room.get("size", Vector2.ZERO)
			for footprint: Rect2 in room.get("cover", []):
				if not Rect2(Vector2.ZERO, size).encloses(footprint):
					problems.append("%s: cover outside the room" % where)
			for strip: Rect2 in room.get("vents", []):
				if not Rect2(Vector2.ZERO, size).encloses(strip):
					problems.append("%s: vent outside the room" % where)
				for footprint: Rect2 in room.get("cover", []):
					if strip.intersects(footprint):
						problems.append("%s: vent under cover" % where)
	return problems
