class_name Weapon
extends Resource
## A weapon is a fight style: its own light and heavy attack plus a few modifiers.
## The sword is built from Tuning (the design table); the others are .tres files in
## resources/weapons/, written by tools/generate_resources.gd.

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var light: AttackDef
@export var heavy: AttackDef
## Multiplies walking speed.
@export var move_mult := 1.0
@export var extra_dodge_charges := 0
## Multiplies the time for a dodge charge to return (below 1 is faster).
@export var dodge_recharge_mult := 1.0
## Drawing only: blade length past the body, thickness, colour, and whether two are drawn.
@export var length := 22.0
@export var thickness := 4.0
@export var color := Color(0.9, 0.93, 1.0)
@export var dual := false


## The dictionary shape the hero uses while an attack plays.
func attack_data(heavy_attack: bool) -> Dictionary:
	var a := heavy if heavy_attack else light
	return {
		"heavy": heavy_attack,
		"damage": a.damage,
		"reach": a.reach,
		"arc": a.arc_deg,
		"windup": a.windup,
		"active": a.active,
		"recover": a.recover,
		"knockback": a.knockback,
		"lunge": a.lunge,
	}


static func sword_from(t: Tuning) -> Weapon:
	var w := Weapon.new()
	w.id = "sword"
	w.display_name = "Sword"
	w.description = "Balanced. Quick cuts, and a wide heavy swing that shoves enemies back."
	w.light = AttackDef.make("Cut", t.light_damage, t.light_reach, t.light_arc_deg,
			t.light_windup, t.light_active, t.light_recover)
	w.heavy = AttackDef.make("Cleave", t.heavy_damage, t.heavy_reach, t.heavy_arc_deg,
			t.heavy_windup, t.heavy_active, t.heavy_recover, t.heavy_knockback)
	return w
