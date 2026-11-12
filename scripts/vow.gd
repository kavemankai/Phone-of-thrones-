class_name Vow
extends RefCounted
## Vows: a handicap sworn at a door in exchange for a second pickup. A vow lasts until the
## run ends. This table is the catalogue; each effect lives where it applies (search the id).

const IRON := "vow_iron"
const FURY := "vow_fury"
const FASTING := "vow_fasting"
const VETERANS := "vow_veterans"
const FRAILTY := "vow_frailty"

const IRON_HEALTH_MULT := 1.25
const FURY_EXTRA_ATTACKERS := 1
const FRAILTY_DAMAGE_MULT := 1.25
## Chance that one of a room's two doors carries a vow.
const OFFER_CHANCE := 0.65

const ALL := {
	IRON: {"name": "Vow of Iron", "text": "Enemies have a quarter more health."},
	FURY: {"name": "Vow of Fury", "text": "Three enemies may attack at once."},
	FASTING: {"name": "Vow of Fasting", "text": "Doors no longer heal you."},
	VETERANS: {"name": "Vow of Veterans", "text": "Each group is led by a veteran."},
	FRAILTY: {"name": "Vow of Frailty", "text": "Hits on you hurt a quarter more."},
}


static func exists(id: String) -> bool:
	return ALL.has(id)


static func title(id: String) -> String:
	return ALL[id]["name"] if ALL.has(id) else ""


static func text(id: String) -> String:
	return ALL[id]["text"] if ALL.has(id) else ""


static func titles(ids: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = []
	for id in ids:
		if ALL.has(id):
			names.append(ALL[id]["name"])
	return names
