class_name AttackDef
extends Resource
## One attack, for the hero or an enemy. Times in seconds, distances in ground units.
## The same numbers drive the drawn wedge and the damage test.

@export var label := ""
@export var damage := 0.0
@export var reach := 0.0
@export var arc_deg := 0.0
@export var windup := 0.0
@export var active := 0.0
@export var recover := 0.0
@export var knockback := 0.0
## Distance the attacker slides forward along its facing during the active frames. For
## enemies the hit area stays the wedge from where the attack started.
@export var lunge := 0.0
## Enemies only: the wedge direction locks this long before the strike.
@export var lock_time := 0.25
## Enemies only: the attack may start when the hero is this far away (centre distance).
@export var min_range := 0.0
@export var max_range := 0.0
## Enemies only: index of an attack that follows straight after this one's recovery
## (same commitment), or -1.
@export var chain_to := -1


static func make(p_label: String, p_damage: float, p_reach: float, p_arc: float, p_windup: float,
		p_active: float, p_recover: float, p_knockback := 0.0, p_lunge := 0.0) -> AttackDef:
	var a := AttackDef.new()
	a.label = p_label
	a.damage = p_damage
	a.reach = p_reach
	a.arc_deg = p_arc
	a.windup = p_windup
	a.active = p_active
	a.recover = p_recover
	a.knockback = p_knockback
	a.lunge = p_lunge
	return a
