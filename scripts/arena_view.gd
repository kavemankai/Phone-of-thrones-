class_name ArenaView
extends Node2D
## Flat ground, a faint grid so movement is easy to read, and a visible boundary.

const GROUND := Color(0.17, 0.22, 0.18)
const BORDER := Color(0.62, 0.55, 0.42)
const FLOORS := [
	preload("res://assets/arenas/shattered_gatehouse.webp"),
	preload("res://assets/arenas/blood_kennels.webp"),
	preload("res://assets/arenas/hall_of_banners.webp"),
	preload("res://assets/arenas/cinder_forge.webp"),
	preload("res://assets/arenas/crown_pit.webp"),
	preload("res://assets/arenas/test_room.webp"),
]
const COVER_ART := {
	0: preload("res://assets/props/masonry.webp"),
	1: preload("res://assets/props/barricade.webp"),
	3: preload("res://assets/props/anvil.webp"),
}
const SEALED_DOOR := preload("res://assets/props/door_sealed.webp")
const OPEN_DOOR := preload("res://assets/props/door_open.webp")
const BRAZIER := preload("res://assets/props/brazier.webp")


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
	var floor_rect := Rect2(Vector2.ZERO, arena_size)
	var floor_index := room_style if room_style >= 0 and room_style < FLOORS.size() - 1 else FLOORS.size() - 1
	draw_rect(Rect2(Vector2(10, 15), arena_size).grow(7.0), Color(0, 0, 0, 0.65))
	draw_rect(floor_rect.grow(6.0), Color(0.17, 0.14, 0.12))
	var tint := Color.WHITE.lerp(room_ground.lightened(0.5), 0.32)
	draw_texture_rect(FLOORS[floor_index], floor_rect, false, tint)
	draw_rect(floor_rect, room_light.darkened(0.28), false, 3.0)
	draw_rect(floor_rect.grow(-5.0), Color(room_light, 0.35), false, 1.0)
	for footprint in cover:
		_draw_cover(footprint)
	if room_style in [0, 1, 3, 4]:
		_draw_brazier(Vector2(39.0, 44.0))
		_draw_brazier(Vector2(arena_size.x - 31.0, 29.0))
	if not has_doors:
		return
	for i in 2:
		var point := door_position(i)
		var edge := Color(1.0, 0.83, 0.35) if i == near_door else room_light
		if not doors_open:
			edge = edge.darkened(0.50)
		draw_circle(point, 19.0, Color(0.09, 0.07, 0.05, 0.75))
		draw_arc(point, 20.0, 0.0, TAU, 28, edge, 3.0)
		draw_set_transform_matrix(Transform2D(0.0, point) * Iso.upright())
		var door := OPEN_DOOR if doors_open else SEALED_DOOR
		draw_texture_rect(door, Rect2(-23.0, -61.0, 46.0, 61.0), false,
				Color(1.22, 1.10, 0.85) if i == near_door else Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(-10.0, -11.0), str(i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, 20.0, 16, Color(1.0, 0.92, 0.72))
		draw_set_transform(Vector2.ZERO)


func _draw_cover(footprint: Rect2) -> void:
	draw_rect(footprint, Color(0.10, 0.08, 0.07, 0.84))
	draw_rect(footprint, Color(room_light, 0.70), false, 2.0)
	var texture: Texture2D = COVER_ART.get(room_style, COVER_ART[0])
	var span := footprint.size.x + footprint.size.y
	var height := span * (0.39 if room_style == 0 else 0.57)
	draw_set_transform_matrix(Transform2D(0.0, footprint.get_center()) * Iso.upright())
	draw_texture_rect(texture, Rect2(-span * 0.45, -height + 9.0, span * 0.90, height), false)
	draw_set_transform(Vector2.ZERO)


func _draw_brazier(point: Vector2) -> void:
	draw_circle(point, 34.0, Color(0.95, 0.49, 0.17, 0.08))
	draw_circle(point, 20.0, Color(1.0, 0.55, 0.21, 0.10))
	draw_set_transform_matrix(Transform2D(0.0, point) * Iso.upright())
	draw_texture_rect(BRAZIER, Rect2(-11.0, -34.0, 22.0, 34.0), false)
	draw_set_transform(Vector2.ZERO)
