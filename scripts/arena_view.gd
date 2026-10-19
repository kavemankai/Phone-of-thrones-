class_name ArenaView
extends Node2D
## Flat ground, a faint grid so movement is easy to read, and a visible boundary.

const GROUND := Color(0.17, 0.22, 0.18)
const GRID := Color(1, 1, 1, 0.05)
const BORDER := Color(0.62, 0.55, 0.42)
const GRID_STEP := 60.0

var arena_size := Vector2(340, 380)


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), GROUND)
	var x := GRID_STEP
	while x < arena_size.x:
		draw_line(Vector2(x, 0), Vector2(x, arena_size.y), GRID, 1.0)
		x += GRID_STEP
	var y := GRID_STEP
	while y < arena_size.y:
		draw_line(Vector2(0, y), Vector2(arena_size.x, y), GRID, 1.0)
		y += GRID_STEP
	draw_rect(Rect2(Vector2.ZERO, arena_size), BORDER, false, 6.0)
