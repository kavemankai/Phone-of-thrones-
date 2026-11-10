class_name Boon
extends RefCounted
## Run pickups. Each one changes how a fight is played, not just a number on the sheet.
## This table is the catalogue; the effects live in Hero at the point each one applies
## (search for the id). A door offers one, and it lasts until the run ends.

const RIPOSTE := "riposte"
const SECOND_WIND := "second_wind"
const THIRD_STEP := "third_step"
const PATIENT_GUARD := "patient_guard"
const HEAVY_HAND := "heavy_hand"
const BLOOD_PRICE := "blood_price"
const SLIPSTREAM := "slipstream"
const IRON_LUNGS := "iron_lungs"

## Numbers the effects use, kept beside the text that describes them.
const RIPOSTE_WINDOW := 2.5
const RIPOSTE_DAMAGE_MULT := 2.0
const SECOND_WIND_STAMINA := 30.0
const PATIENT_GUARD_BONUS := 0.08
const HEAVY_HAND_REACH_MULT := 1.15
const HEAVY_HAND_KNOCKBACK := 30.0
const BLOOD_PRICE_HEAL := 5.0
const SLIPSTREAM_WINDOW := 0.8
const SLIPSTREAM_WINDUP_MULT := 0.6
const IRON_LUNGS_DELAY_MULT := 0.5

## Offer order is the order here, so a saved run reads the same doors after an update only
## if new entries are added at the end.
const ALL := {
	RIPOSTE: {"name": "Riposte", "text": "After a parry, your next attack hits twice as hard."},
	SECOND_WIND: {"name": "Second Wind", "text": "A parry gives back 30 stamina."},
	THIRD_STEP: {"name": "Third Step", "text": "One more roll charge."},
	PATIENT_GUARD: {"name": "Patient Guard", "text": "The parry window lasts 0.08 s longer."},
	HEAVY_HAND: {"name": "Heavy Hand", "text": "Heavy attacks reach further and shove harder."},
	BLOOD_PRICE: {"name": "Blood Price", "text": "Each kill heals 5 health."},
	SLIPSTREAM: {"name": "Slipstream", "text": "After a roll, your next attack is free and faster."},
	IRON_LUNGS: {"name": "Iron Lungs", "text": "Stamina starts returning twice as soon."},
}


static func exists(id: String) -> bool:
	return ALL.has(id)


static func title(id: String) -> String:
	return ALL[id]["name"] if ALL.has(id) else ""


static func text(id: String) -> String:
	return ALL[id]["text"] if ALL.has(id) else ""


## Names of the given ids, for one-line displays.
static func titles(ids: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = []
	for id in ids:
		if ALL.has(id):
			names.append(ALL[id]["name"])
	return names
