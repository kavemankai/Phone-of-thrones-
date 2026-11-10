class_name CombatInput
extends RefCounted
## The only thing the hero reads. Gamepad, keyboard and (on phones) touch controls all write
## here, so gameplay code never knows which device produced an action.

## When true, stick and key vectors are screen-space and are mapped to ground space
## (see Iso), so "up" on the stick is "up" on an isometric screen.
var iso_view := false
var touch_move := Vector2.ZERO
## Polled movement: left stick or movement keys, screen-space, dead zone already applied.
var key_move := Vector2.ZERO
## Right-stick facing, screen-space, dead zone already applied. Zero means "no aim input":
## the hero then faces where it walks and otherwise keeps its last facing.
var aim := Vector2.ZERO
var attack_touch := false
var attack_key := false
var block_touch := false
var block_key := false
var block_pad := false

## One-step flags. The game clears them after every simulation step, so a press the hero
## cannot use right now is dropped instead of queued.
var attack_pressed := false
var attack_released := false
var dodge_pressed := false
## Separate-button trial: one-step heavy action, independent of tap/hold charging.
var heavy_pressed := false


func attack_down() -> bool:
	return attack_touch or attack_key


## The guard is a held state, so there are no one-step flags for it.
func block_down() -> bool:
	return block_touch or block_key or block_pad


## Gamepad guard button, tracked apart from the key so releasing one never drops the other.
func set_pad_block(down: bool) -> void:
	block_pad = down


## Ground-space unit facing asked for by the right stick, or zero when it is at rest.
func aim_vector() -> Vector2:
	if aim.length_squared() <= 0.0:
		return Vector2.ZERO
	var v := Iso.stick_to_ground(aim) if iso_view else aim
	return v.normalized()


func press_block(from_touch: bool) -> void:
	if from_touch:
		block_touch = true
	else:
		block_key = true


func release_block(from_touch: bool) -> void:
	if from_touch:
		block_touch = false
	else:
		block_key = false


func move_vector() -> Vector2:
	var v := touch_move if touch_move.length_squared() > 0.0 else key_move
	if iso_view:
		v = Iso.stick_to_ground(v)
	return v.limit_length(1.0)


func press_attack(from_touch: bool) -> void:
	var was_down := attack_down()
	if from_touch:
		attack_touch = true
	else:
		attack_key = true
	if not was_down:
		attack_pressed = true


func release_attack(from_touch: bool) -> void:
	var was_down := attack_down()
	if from_touch:
		attack_touch = false
	else:
		attack_key = false
	if was_down and not attack_down():
		attack_released = true


## The finger slid off the button: drop the pending attack without firing it.
func cancel_attack(from_touch: bool) -> void:
	if from_touch:
		attack_touch = false
	else:
		attack_key = false


func press_dodge() -> void:
	dodge_pressed = true


func press_heavy() -> void:
	heavy_pressed = true


## Immediate light attack (gamepad X): press and release inside one step, so there is no
## tap/hold timing and nothing stays held.
func press_light() -> void:
	attack_pressed = true
	attack_released = true


func end_step() -> void:
	attack_pressed = false
	attack_released = false
	dodge_pressed = false
	heavy_pressed = false


func clear() -> void:
	touch_move = Vector2.ZERO
	key_move = Vector2.ZERO
	aim = Vector2.ZERO
	attack_touch = false
	attack_key = false
	block_touch = false
	block_key = false
	block_pad = false
	end_step()
