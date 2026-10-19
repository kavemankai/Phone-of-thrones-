class_name CombatInput
extends RefCounted
## The only thing the hero reads. Touch controls and the keyboard both write here,
## so gameplay code never knows which device produced an action.

## When true, stick and key vectors are screen-space and are mapped to ground space
## (see Iso), so "up" on the stick is "up" on an isometric screen.
var iso_view := false
var touch_move := Vector2.ZERO
var key_move := Vector2.ZERO
var attack_touch := false
var attack_key := false
var block_touch := false
var block_key := false

## One-step flags. The game clears them after every simulation step, so a press the hero
## cannot use right now is dropped instead of queued.
var attack_pressed := false
var attack_released := false
var dodge_pressed := false


func attack_down() -> bool:
	return attack_touch or attack_key


## The guard is a held state, so there are no one-step flags for it.
func block_down() -> bool:
	return block_touch or block_key


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


func end_step() -> void:
	attack_pressed = false
	attack_released = false
	dodge_pressed = false


func clear() -> void:
	touch_move = Vector2.ZERO
	key_move = Vector2.ZERO
	attack_touch = false
	attack_key = false
	block_touch = false
	block_key = false
	end_step()
