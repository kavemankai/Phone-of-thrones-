class_name ArenaView
extends Node2D
## Flat ground, a faint grid so movement is easy to read, and a visible boundary.

const GROUND := Color(0.17, 0.22, 0.18)
const GRID := Color(1, 1, 1, 0.05)
const BORDER := Color(0.62, 0.55, 0.42)
const GRID_STEP := 60.0

var arena_size := Vector2(340, 380)
var room_ground := GROUND
var room_light := BORDER
var room_style := -1
var doors_open := false
var has_doors := false
var near_door := -1


func door_position(index: int) -> Vector2:
	return Vector2(arena_size.x * (0.26 if index == 0 else 0.74), 34.0)


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), room_ground)
	var x := GRID_STEP
	while x < arena_size.x:
		draw_line(Vector2(x, 0), Vector2(x, arena_size.y), GRID, 1.0)
		x += GRID_STEP
	var y := GRID_STEP
	while y < arena_size.y:
		draw_line(Vector2(0, y), Vector2(arena_size.x, y), GRID, 1.0)
		y += GRID_STEP
	draw_rect(Rect2(Vector2.ZERO, arena_size), room_light, false, 6.0)
	if room_style < 0:
		return
	var stripe := Color(room_light, 0.23)
	match room_style:
		0:
			for offset in [-28.0, 28.0]:
				var lane_x := arena_size.x * 0.5 + float(offset)
				draw_line(Vector2(lane_x, 20.0), Vector2(lane_x, arena_size.y - 20.0), stripe, 4.0)
		1:
			for i in 5:
				draw_rect(Rect2(14.0, 35.0 + i * 52.0, 37.0, 33.0), stripe, false, 3.0)
		2:
			draw_rect(Rect2(arena_size * 0.5 - Vector2(46, 154), Vector2(92, 308)), stripe)
	if not has_doors:
		return
	for i in 2:
		var point := door_position(i)
		var tint := Color(1.0, 0.83, 0.35) if i == near_door else room_light
		if not doors_open:
			tint = tint.darkened(0.50)
		draw_circle(point, 19.0, tint.darkened(0.65))
		draw_arc(point, 20.0, 0.0, TAU, 28, tint, 3.0)
		draw_set_transform_matrix(Transform2D(0.0, point) * Iso.upright())
		draw_rect(Rect2(-14.0, -41.0, 28.0, 41.0), tint.darkened(0.55))
		draw_rect(Rect2(-14.0, -41.0, 28.0, 41.0), tint, false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-10.0, -15.0), str(i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, 20.0, 19, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
