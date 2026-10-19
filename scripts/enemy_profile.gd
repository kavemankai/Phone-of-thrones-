class_name EnemyProfile
extends Resource
## Everything that makes one kind of enemy different: body, speed and its attacks.
## The grunt is built from Tuning; the captain is resources/captain.tres.

@export var id := "grunt"
@export var display_name := "Enemy"
@export var max_hp := 30.0
@export var speed := 105.0
@export var radius := 16.0
## Distance kept while waiting for an attack slot.
@export var hover_range := 90.0
@export var color := Color(0.88, 0.2, 0.2)
## Drawing only: a gold cap marks the captain. Alpha 0 means no cap.
@export var cap_color := Color(0, 0, 0, 0)
@export var bar_width := 36.0
## How long a parry freezes this enemy (a hit ends it sooner).
@export var stagger_time := 3.0
## How long a heavy hit freezes it. 0 means heavy hits never stagger this enemy.
@export var heavy_stagger_time := 1.0
@export var attacks: Array[AttackDef] = []
## Attack indices used in order, repeating. An entry is skipped when the hero is closer
## than that attack's min_range.
@export var pattern: PackedInt32Array = PackedInt32Array([0])


## Position in the (unbounded) pattern counter of the attack to use now.
func choose(dist: float, pos: int) -> int:
	var n := pattern.size()
	for k in n:
		if dist >= attacks[pattern[(pos + k) % n]].min_range:
			return pos + k
	return pos


func attack_at(pos: int) -> AttackDef:
	return attacks[pattern[pos % pattern.size()]]


static func grunt_from(t: Tuning) -> EnemyProfile:
	var p := EnemyProfile.new()
	p.id = "grunt"
	p.display_name = "Enemy"
	p.max_hp = t.enemy_max_hp
	p.speed = t.enemy_speed
	p.radius = t.enemy_radius
	p.hover_range = t.enemy_hover_range
	var a := AttackDef.make("Strike", t.enemy_damage, t.enemy_reach, t.enemy_arc_deg,
			t.enemy_windup, t.enemy_active, t.enemy_recover)
	a.lock_time = t.enemy_lock_time
	a.max_range = t.enemy_engage_range
	p.attacks = [a]
	return p
