class_name CombatInput
extends RefCounted
## The only thing the hero reads. Touch controls and the keyboard both write here,
## so gameplay code never knows which device produced an action.

var touch_move := Vector2.ZERO
var key_move := Vector2.ZERO
var attack_touch := false
var attack_key := false

## One-step flags. The game clears them after every simulation step, so a press the hero
## cannot use right now is dropped instead of queued.
var attack_pressed := false
var attack_released := false
var dodge_pressed := false


func attack_down() -> bool:
	return attack_touch or attack_key


func move_vector() -> Vector2:
	var v := touch_move if touch_move.length_squared() > 0.0 else key_move
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
	end_step()
