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
var cover: Array[Rect2] = []


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
	for footprint in cover:
		_draw_cover(footprint)
	if room_style == 0 or room_style == 1:
		_draw_torch(Vector2(31.0, 29.0))
		_draw_torch(Vector2(arena_size.x - 31.0, 29.0))
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


func _draw_cover(footprint: Rect2) -> void:
	var masonry := room_style == 0
	var top_color := Color(0.38, 0.36, 0.32) if masonry else Color(0.32, 0.23, 0.17)
	draw_rect(footprint, top_color)
	draw_rect(footprint, Color(0.10, 0.09, 0.08), false, 4.0)
	var mid := footprint.get_center()
	if masonry:
		draw_line(Vector2(footprint.position.x, mid.y), Vector2(footprint.end.x, mid.y),
				top_color.darkened(0.4), 3.0)
		draw_line(Vector2(mid.x - 15.0, footprint.position.y), Vector2(mid.x - 15.0, mid.y),
				top_color.darkened(0.4), 3.0)
		draw_line(Vector2(mid.x + 15.0, mid.y), Vector2(mid.x + 15.0, footprint.end.y),
				top_color.darkened(0.4), 3.0)
	else:
		for offset in [-15.0, 0.0, 15.0]:
			var y := mid.y + float(offset)
			draw_line(Vector2(footprint.position.x + 3.0, y), Vector2(footprint.end.x - 3.0, y),
					Color(0.53, 0.37, 0.23), 6.0)
	draw_rect(footprint.grow(3.0), Color(room_light, 0.55), false, 1.5)


func _draw_torch(point: Vector2) -> void:
	draw_circle(point, 35.0, Color(0.95, 0.49, 0.17, 0.08))
	draw_circle(point, 22.0, Color(1.0, 0.55, 0.21, 0.10))
	draw_set_transform_matrix(Transform2D(0.0, point) * Iso.upright())
	draw_line(Vector2.ZERO, Vector2(0, -24), Color(0.34, 0.28, 0.21), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -24), Vector2(-1, -38), Vector2(6, -24)]),
			Color(1.0, 0.60, 0.23))
	draw_set_transform(Vector2.ZERO)
