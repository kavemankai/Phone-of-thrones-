extends SceneTree
## Writes the weapon and captain resources. Run from the project root:
##   godot --headless --path . --script tools/generate_resources.gd
## The files can then be edited in the Godot inspector or as text. The sword and the grunt are
## not here: they are built from resources/tuning.tres.


func _init() -> void:
	var failed := 0
	failed += _save(_spear(), "res://resources/weapons/spear.tres")
	failed += _save(_axe(), "res://resources/weapons/axe.tres")
	failed += _save(_daggers(), "res://resources/weapons/daggers.tres")
	failed += _save(_zweihander(), "res://resources/weapons/zweihander.tres")
	failed += _save(_captain(), "res://resources/captain.tres")
	quit(failed)


func _save(res: Resource, path: String) -> int:
	var err := ResourceSaver.save(res, path)
	print("saved ", path, " err=", err)
	return 0 if err == OK else 1


func _spear() -> Weapon:
	var w := Weapon.new()
	w.id = "spear"
	w.display_name = "Spear"
	w.description = "Reach. Long narrow thrusts keep you out of range; the heavy lunges forward."
	w.light = AttackDef.make("Thrust", 10.0, 95.0, 30.0, 0.12, 0.08, 0.26)
	w.heavy = AttackDef.make("Lunge", 22.0, 120.0, 24.0, 0.22, 0.10, 0.45, 0.0, 35.0)
	w.length = 46.0
	w.thickness = 3.0
	w.color = Color(0.95, 0.9, 0.7)
	w.parry_stagger_time = 3.5
	w.heavy_stagger_time = 0.8
	w.block_stun_time = 1.4
	return w


func _axe() -> Weapon:
	var w := Weapon.new()
	w.id = "axe"
	w.display_name = "Axe"
	w.description = "Power. Slow, wide swings; the heavy spins 200 degrees and hurls enemies back. Walks slower."
	w.light = AttackDef.make("Chop", 16.0, 70.0, 150.0, 0.22, 0.10, 0.38)
	w.heavy = AttackDef.make("Spin", 38.0, 90.0, 200.0, 0.35, 0.14, 0.60, 60.0)
	w.move_mult = 0.9
	w.dodge_recharge_mult = 1.2
	w.length = 20.0
	w.thickness = 8.0
	w.color = Color(0.85, 0.75, 0.55)
	w.one_handed = false
	w.parry_stagger_time = 2.5
	w.heavy_stagger_time = 1.5
	w.block_stun_time = 1.6
	return w


func _daggers() -> Weapon:
	var w := Weapon.new()
	w.id = "daggers"
	w.display_name = "Daggers"
	w.description = "Speed. A fast ring of short stabs that hits all around. Parrying kills. Faster walking, three dodges."
	w.light = AttackDef.make("Stab", 5.0, 40.0, 360.0, 0.04, 0.05, 0.09)
	w.heavy = AttackDef.make("Whirl", 12.0, 50.0, 360.0, 0.08, 0.07, 0.18)
	w.move_mult = 1.1
	w.extra_dodge_charges = 1
	w.dodge_recharge_mult = 0.8
	w.length = 14.0
	w.thickness = 3.0
	w.dual = true
	w.one_handed = false
	w.parry_stagger_time = 2.0
	w.heavy_stagger_time = 0.6
	w.block_stun_time = 0.8
	w.parry_kill = true
	w.color = Color(0.8, 0.95, 1.0)
	return w


func _zweihander() -> Weapon:
	var w := Weapon.new()
	w.id = "zweihander"
	w.display_name = "Zweihander"
	w.description = "Long reach, wide arcs, slow and heavy. Two-handed, so no shield."
	w.light = AttackDef.make("Sweep", 14.0, 85.0, 100.0, 0.18, 0.08, 0.32)
	w.heavy = AttackDef.make("Great cleave", 34.0, 105.0, 160.0, 0.28, 0.12, 0.50, 45.0)
	w.move_mult = 0.95
	w.dodge_recharge_mult = 1.1
	w.length = 40.0
	w.thickness = 7.0
	w.color = Color(0.82, 0.86, 0.95)
	w.one_handed = false
	w.parry_stagger_time = 3.0
	w.heavy_stagger_time = 1.3
	w.block_stun_time = 1.4
	return w


func _captain() -> EnemyProfile:
	var p := EnemyProfile.new()
	p.id = "captain"
	p.display_name = "Captain"
	p.max_hp = 150.0
	p.speed = 95.0
	p.radius = 22.0
	p.hover_range = 100.0
	p.color = Color(0.55, 0.08, 0.14)
	p.cap_color = Color(0.95, 0.78, 0.2)
	p.bar_width = 64.0
	p.heavy_stagger_mult = 0.5  # a heavy hit staggers the captain for half as long
	p.execute_fraction = 0.4  # an executing parry takes 40% of its max HP instead of killing it

	var slash := AttackDef.make("Slash", 18.0, 62.0, 120.0, 0.70, 0.10, 0.60)
	slash.max_range = 62.0

	var combo1 := AttackDef.make("Combo 1", 14.0, 58.0, 110.0, 0.55, 0.10, 0.12)
	combo1.max_range = 62.0
	combo1.chain_to = 2
	var combo2 := AttackDef.make("Combo 2", 20.0, 66.0, 130.0, 0.38, 0.10, 0.80)
	combo2.lock_time = 0.18

	var lunge := AttackDef.make("Lunge", 22.0, 150.0, 28.0, 0.80, 0.12, 0.90, 0.0, 120.0)
	lunge.lock_time = 0.30
	lunge.min_range = 105.0
	lunge.max_range = 140.0
	lunge.guard_cost_mult = 2.0
	lunge.block_stun = false
	lunge.breaks_bare_guard = true

	p.attacks = [slash, combo1, combo2, lunge]
	p.pattern = PackedInt32Array([3, 0, 1, 0, 1])
	return p
