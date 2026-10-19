class_name HitShapes
extends RefCounted
## One definition of an attack's area. The same sector is drawn as the telegraph and used
## for the damage test, so what the player sees is what hurts.

const ARC_STEPS := 24


## True when the body circle touches the sector (apex at origin, direction facing, given
## reach and full arc in degrees). facing must be normalised.
static func circle_in_sector(origin: Vector2, facing: Vector2, reach: float, arc_deg: float,
		center: Vector2, circle_r: float) -> bool:
	var d := center - origin
	var dist := d.length()
	if dist <= circle_r:
		return true
	if dist > reach + circle_r:
		return false
	if arc_deg >= 359.9:
		return true  # a full ring: anything within reach is inside
	var half := deg_to_rad(arc_deg) * 0.5
	if absf(facing.angle_to(d)) <= half:
		return true
	# Centre is outside the angular range: the circle can still clip one straight edge.
	for s in [-1.0, 1.0]:
		var edge := facing.rotated(s * half)
		var t := clampf(d.dot(edge), 0.0, reach)
		if (d - edge * t).length() <= circle_r:
			return true
	return false


## Sector outline relative to its apex, for drawing.
static func sector_polygon(facing: Vector2, reach: float, arc_deg: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if arc_deg >= 359.9:
		# A full ring has no apex: just the circle.
		var n := ARC_STEPS * 2
		for i in n:
			pts.append(Vector2.from_angle(TAU * float(i) / n) * reach)
		return pts
	pts.append(Vector2.ZERO)
	var half := deg_to_rad(arc_deg) * 0.5
	var base := facing.angle()
	for i in ARC_STEPS + 1:
		var a := base + lerpf(-half, half, float(i) / ARC_STEPS)
		pts.append(Vector2.from_angle(a) * reach)
	return pts
