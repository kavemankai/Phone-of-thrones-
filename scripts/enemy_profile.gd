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
## Time spent circling in range before the first attack and each new commitment.
@export var orbit_before_attack := 0.0
@export var color := Color(0.88, 0.2, 0.2)
## Drawing only: a gold cap marks the captain. Alpha 0 means no cap.
@export var cap_color := Color(0, 0, 0, 0)
@export var bar_width := 36.0
## Scales the hero weapon's stagger lengths for this enemy: a parry freeze, and a heavy-hit
## freeze. 0 on the heavy one means heavy hits never stagger it.
@export var stagger_mult := 1.0
@export var heavy_stagger_mult := 1.0
## Share of this enemy's max HP that an executing parry (Weapon.parry_kill) takes: 1 kills it.
@export var execute_fraction := 1.0
## Front shield: a hit arriving inside this arc (degrees, centred on facing) is multiplied
## by front_guard_mult and cannot stagger or shove. 0 means no shield. The shield is down
## while the enemy recovers from its own attack or is staggered.
@export var front_guard_arc := 0.0
@export var front_guard_mult := 1.0
## Never takes an attack slot; it only keeps its distance.
@export var passive := false
## Other living enemies within aura_range move aura_speed_mult times as fast. 0 means none.
@export var aura_range := 0.0
@export var aura_speed_mult := 1.0
## Second phase: when health falls to this share of max (0 means never) the enemy reels
## for a moment, then uses phase2_pattern and moves phase2_speed_mult times as fast.
@export var phase2_at := 0.0
@export var phase2_pattern: PackedInt32Array = PackedInt32Array()
@export var phase2_speed_mult := 1.0
## A veteran: more health and one twist on the ordinary kind (see CampaignRun._make_elite).
@export var elite := false
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
