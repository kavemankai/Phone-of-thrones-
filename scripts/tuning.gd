class_name Tuning
extends Resource
## Every combat number lives here. Edit resources/tuning.tres in the Godot inspector
## (or the .tres text file) and re-run. Times are seconds, distances are design-space
## pixels (the design canvas is 720 x 1280). Values are starting points, not final balance.

@export_group("Hero")
@export var hero_max_hp: float = 100.0
@export var hero_speed: float = 180.0
@export var hero_radius: float = 16.0
## Movement multiplier while charging and during attack recovery.
@export var half_speed_mult: float = 0.5
## Aim assist: nearest enemy inside a cone this wide, centred on facing, snaps the swing toward it.
@export var aim_cone_deg: float = 90.0

@export_group("Light attack")
@export var light_damage: float = 10.0
@export var light_reach: float = 65.0
@export var light_arc_deg: float = 90.0
@export var light_windup: float = 0.10
@export var light_active: float = 0.08
@export var light_recover: float = 0.22

@export_group("Heavy attack")
## Hold the attack button this long before release to get a heavy attack.
@export var heavy_hold_time: float = 0.35
@export var heavy_damage: float = 25.0
@export var heavy_reach: float = 85.0
@export var heavy_arc_deg: float = 140.0
@export var heavy_windup: float = 0.15
@export var heavy_active: float = 0.10
@export var heavy_recover: float = 0.40
@export var heavy_knockback: float = 35.0

@export_group("Dodge")
@export var dodge_distance: float = 90.0
@export var dodge_duration: float = 0.30
@export var dodge_iframes: float = 0.16
@export var dodge_max_charges: int = 2
@export var dodge_recharge: float = 1.4

@export_group("Taking damage")
@export var hurt_duration: float = 0.15
## Total damage immunity, measured from the moment of the hit.
@export var hit_immunity: float = 0.35

@export_group("Enemy")
@export var enemy_max_hp: float = 30.0
@export var enemy_speed: float = 105.0
@export var enemy_radius: float = 16.0
@export var enemy_reach: float = 48.0
## Not in the design table. 100 degrees keeps the wedge readable at a small body size.
@export var enemy_arc_deg: float = 100.0
@export var enemy_damage: float = 12.0
@export var enemy_windup: float = 0.65
@export var enemy_active: float = 0.10
@export var enemy_recover: float = 0.65
@export var enemy_attack_gap: float = 0.35
## The wedge direction is locked for the last part of the wind-up.
@export var enemy_lock_time: float = 0.25
## Centre distance at which an enemy with an attack slot starts its wind-up.
@export var enemy_engage_range: float = 52.0
## Distance enemies keep while waiting for an attack slot.
@export var enemy_hover_range: float = 90.0
@export var enemy_strafe_mult: float = 0.4
## Extra delay before the n-th enemy may first request an attack.
@export var enemy_stagger: float = 0.6
@export var max_commits: int = 2
## Maximum speed at which overlapping bodies are pushed apart.
@export var separation_speed: float = 300.0

@export_group("Arena and layout")
## Logical ground size. The view is isometric (2:1), so the arena appears as a diamond about
## (width + height) wide and half that tall; the layout scales it to fit above the control band.
## Every distance in this file is in these ground units. Larger arenas look smaller on screen.
@export var arena_size: Vector2 = Vector2(340.0, 380.0)
## Spawn distance from the arena centre along the screen-vertical axis (hero below, enemies above).
@export var spawn_axis_dist: float = 110.0
@export var enemy_spawn_spread: float = 80.0
## Share of the screen height reserved for the control band.
@export var control_band_fraction: float = 0.28
@export var joystick_radius: float = 90.0
@export var joystick_deadzone: float = 0.12
## Delay between the last blow and the result panel.
@export var result_delay: float = 0.6


func attack_data(heavy: bool) -> Dictionary:
	if heavy:
		return {
			"heavy": true,
			"damage": heavy_damage,
			"reach": heavy_reach,
			"arc": heavy_arc_deg,
			"windup": heavy_windup,
			"active": heavy_active,
			"recover": heavy_recover,
			"knockback": heavy_knockback,
		}
	return {
		"heavy": false,
		"damage": light_damage,
		"reach": light_reach,
		"arc": light_arc_deg,
		"windup": light_windup,
		"active": light_active,
		"recover": light_recover,
		"knockback": 0.0,
	}


## Screen-down in ground coordinates, and screen-right.
const DOWN := Vector2(0.70710678, 0.70710678)
const RIGHT := Vector2(0.70710678, -0.70710678)


func hero_spawn() -> Vector2:
	return arena_size * 0.5 + DOWN * spawn_axis_dist


## Positions for up to three enemies: one ahead, two flanking slightly nearer.
func enemy_spawns() -> Array[Vector2]:
	var c := arena_size * 0.5
	return [
		c - DOWN * spawn_axis_dist,
		c - DOWN * (spawn_axis_dist - 15.0) - RIGHT * enemy_spawn_spread,
		c - DOWN * (spawn_axis_dist - 15.0) + RIGHT * enemy_spawn_spread,
	]
