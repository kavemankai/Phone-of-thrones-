class_name CombatFx
extends Node2D
## Impact feedback: a short freeze, screen shake, sparks and rings. Nothing here touches the
## simulation. Game asks `frozen()` before it steps, and reads `shake_offset()` when it
## places the arena. Lives on the iso layer, so positions are ground coordinates.

const MAX_MARKS := 48

## Seconds of freeze left. While it is above zero Game does not step the simulation.
var hitstop := 0.0
var shake_enabled := true

var _shake_left := 0.0
var _shake_total := 0.0
var _shake_power := 0.0
var _clock := 0.0
## Each mark: {pos, age, life, tint, size, ring, dust?}.
var _marks: Array[Dictionary] = []


func _ready() -> void:
	z_index = 4000


func frozen() -> bool:
	return hitstop > 0.0


## Hold the fight still for a moment. Overlapping requests keep the longest.
func hit_stop(seconds: float) -> void:
	hitstop = maxf(hitstop, seconds)


## `power` is the largest offset in screen pixels.
func shake(power: float, seconds: float) -> void:
	if power * seconds >= _shake_power * _shake_left:
		_shake_power = power
		_shake_left = seconds
		_shake_total = seconds


## A burst of short lines standing at a ground position.
func spark(pos: Vector2, tint: Color, size := 22.0, life := 0.22) -> void:
	_add({"pos": pos, "age": 0.0, "life": life, "tint": tint, "size": size, "ring": false})


## A ring spreading over the ground.
func ring(pos: Vector2, tint: Color, size := 60.0, life := 0.32) -> void:
	_add({"pos": pos, "age": 0.0, "life": life, "tint": tint, "size": size, "ring": true})


## A restrained ground-space dust puff for rolls and scuffed steps. Never affects physics.
func dust(pos: Vector2, size := 18.0, life := 0.27) -> void:
	_add({"pos": pos, "age": 0.0, "life": life,
			"tint": Color(0.70, 0.62, 0.49, 0.36), "size": size,
			"ring": false, "dust": true})


func clear() -> void:
	hitstop = 0.0
	_shake_left = 0.0
	_shake_total = 0.0
	_shake_power = 0.0
	_marks.clear()
	queue_redraw()


## Real time, called once a frame whatever the game state.
func advance(delta: float) -> void:
	_clock += delta
	hitstop = maxf(0.0, hitstop - delta)
	_shake_left = maxf(0.0, _shake_left - delta)
	if _marks.is_empty():
		return
	var kept: Array[Dictionary] = []
	for mark in _marks:
		mark["age"] = float(mark["age"]) + delta
		if float(mark["age"]) < float(mark["life"]):
			kept.append(mark)
	_marks = kept
	queue_redraw()


## Screen-space offset for the arena this frame.
func shake_offset() -> Vector2:
	if not shake_enabled or _shake_left <= 0.0 or _shake_total <= 0.0:
		return Vector2.ZERO
	var fade := _shake_left / _shake_total
	return Vector2(sin(_clock * 97.0), cos(_clock * 71.0)) * _shake_power * fade


func _add(mark: Dictionary) -> void:
	if _marks.size() >= MAX_MARKS:
		_marks.pop_front()
	_marks.append(mark)
	queue_redraw()


func _draw() -> void:
	for mark in _marks:
		var progress := clampf(float(mark["age"]) / maxf(float(mark["life"]), 0.001), 0.0, 1.0)
		var tint: Color = mark["tint"]
		var size: float = mark["size"]
		var pos: Vector2 = mark["pos"]
		tint.a *= 1.0 - progress
		if mark["ring"]:
			draw_set_transform(Vector2.ZERO)
			draw_arc(pos, size * (0.35 + 0.65 * progress), 0.0, TAU, 40,
					tint, 4.0 * (1.0 - progress) + 1.0)
			continue
		if mark.get("dust", false):
			draw_set_transform(Vector2.ZERO)
			for i in 5:
				var angle := TAU * float(i) / 5.0 + size * 0.025
				var spread := size * (0.18 + progress * 0.72)
				var puff := pos + Vector2(cos(angle), sin(angle)) * spread
				draw_circle(puff, size * (0.13 + 0.15 * progress), tint)
			continue
		# Sparks rotate slightly over their lifetime; previously their angle was frozen
		# because the formula used the constant lifetime instead of the elapsed age.
		draw_set_transform_matrix(Transform2D(0.0, pos) * Iso.upright())
		var centre := Vector2(0.0, -24.0)
		for i in 7:
			var angle := TAU * float(i) / 7.0 + float(mark["age"]) * 9.0
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(centre + dir * size * (0.25 + 0.55 * progress),
					centre + dir * size * (0.55 + 0.75 * progress), tint, 2.5)
	draw_set_transform(Vector2.ZERO)
