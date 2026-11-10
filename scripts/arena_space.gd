class_name ArenaSpace
extends RefCounted

## Positions and cover use the same ground-space rectangles as the arena drawing.
static func move(from: Vector2, target: Vector2, radius: float, size: Vector2,
		cover: Array[Rect2]) -> Vector2:
	var margin := Vector2.ONE * radius
	var next := target.clamp(margin, size - margin)
	var slide := from
	for axis in 2:
		var value := next[axis]
		var cross := 1 - axis
		for footprint in cover:
			var wall := footprint.grow(radius)
			if slide[cross] <= wall.position[cross] or slide[cross] >= wall.end[cross]:
				continue
			if slide[axis] <= wall.position[axis] and value > wall.position[axis]:
				value = wall.position[axis]
			elif slide[axis] >= wall.end[axis] and value < wall.end[axis]:
				value = wall.end[axis]
		slide[axis] = value
	return slide


static func blocked(from: Vector2, to: Vector2, cover: Array[Rect2], padding := 0.0) -> bool:
	for footprint in cover:
		var wall := footprint.grow(padding)
		if wall.has_point(from) or wall.has_point(to):
			return true
		var corners := _corners(wall)
		for i in 4:
			if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
				return true
	return false


## A room only has a few corners. Find the shortest visible chain of corners to the
## target so enemies keep moving when the direct route crosses cover.
static func approach(from: Vector2, target: Vector2, radius: float, cover: Array[Rect2]) -> Vector2:
	if not blocked(from, target, cover, radius - 0.1):
		return from.direction_to(target)
	var points: Array[Vector2] = [from, target]
	for footprint in cover:
		points.append_array(_corners(footprint.grow(radius + 5.0)))
	var cost: Array[float] = []
	var first: Array[int] = []
	cost.resize(points.size())
	cost.fill(INF)
	cost[0] = 0.0
	first.resize(points.size())
	first.fill(-1)
	var visited: Array[bool] = []
	visited.resize(points.size())
	visited.fill(false)
	for _step in points.size():
		var best := -1
		var distance := INF
		for i in points.size():
			if not visited[i] and cost[i] < distance:
				best = i
				distance = cost[i]
		if best < 0:
			break
		if best == 1:
			return from.direction_to(points[first[best]])
		visited[best] = true
		for i in range(1, points.size()):
			if visited[i]:
				continue
			var next := distance + points[best].distance_to(points[i])
			if next < cost[i] and not blocked(points[best], points[i], cover, radius - 0.1):
				cost[i] = next
				first[i] = i if best == 0 else first[best]
	return from.direction_to(target)


static func _corners(rect: Rect2) -> Array[Vector2]:
	return [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]
