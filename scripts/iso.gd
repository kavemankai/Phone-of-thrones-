class_name Iso
extends RefCounted
## Fixed 2:1 isometric view. The simulation runs in flat ground coordinates; only drawing
## and the stick mapping go through here.
##   screen.x = ground.x - ground.y
##   screen.y = (ground.x + ground.y) * 0.5
## Ground +x runs down-right on screen, ground +y runs down-left. Screen "down" is ground
## (1, 1) and screen "right" is ground (1, -1).

const X_AXIS := Vector2(1.0, 0.5)
const Y_AXIS := Vector2(-1.0, 0.5)

## Ellipse semi-axes of a ground circle of radius 1 once projected.
const RX := 1.41421356
const RY := 0.70710678


static func basis() -> Transform2D:
	return Transform2D(X_AXIS, Y_AXIS, Vector2.ZERO)


## Draw-state transform that cancels the isometric squash, so shapes drawn with it appear
## upright at the entity's projected position.
static func upright() -> Transform2D:
	return basis().affine_inverse()


static func to_screen(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * 0.5)


static func to_ground(v: Vector2) -> Vector2:
	return Vector2(v.x * 0.5 + v.y, v.y - v.x * 0.5)


## A screen-space stick vector as a ground-space vector of the same length, so that
## pushing the stick up on the screen moves the hero up on the screen.
static func stick_to_ground(v: Vector2) -> Vector2:
	var len := v.length()
	if len <= 0.0:
		return Vector2.ZERO
	return to_ground(v).normalized() * len


static func ellipse(center: Vector2, rx: float, ry: float, steps := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / steps
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A plain cylinder standing on the ground point (0, 0). Call after draw_set_transform_matrix
## (Iso.upright()). Its base ellipse is exactly the projected ground circle, so the base is
## where the body really is.
static func draw_cylinder(ci: CanvasItem, ground_radius: float, height: float, side: Color,
		outline: Color) -> void:
	var rx := ground_radius * RX
	var ry := ground_radius * RY
	var top := side.lightened(0.28)
	ci.draw_colored_polygon(ellipse(Vector2.ZERO, rx, ry), side.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-rx, 0.0), Vector2(-rx, -height), Vector2(rx, -height), Vector2(rx, 0.0)]), side)
	ci.draw_colored_polygon(ellipse(Vector2(0.0, -height), rx, ry), top)
	var rim := ellipse(Vector2(0.0, -height), rx, ry)
	rim.append(rim[0])
	ci.draw_polyline(rim, outline, 2.0)
	ci.draw_line(Vector2(-rx, 0.0), Vector2(-rx, -height), outline, 2.0)
	ci.draw_line(Vector2(rx, 0.0), Vector2(rx, -height), outline, 2.0)
	var base := ellipse(Vector2.ZERO, rx, ry)
	base.append(base[0])
	ci.draw_polyline(base, outline, 2.0)
