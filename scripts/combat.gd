extends RefCounted
## Pure geometry, shared by the live game and regression tests.

static func segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))

static func vulnerable(from: Vector2, enemy: Vector2, weak_side: Vector2) -> bool:
	var approach := from - enemy
	return approach.length() > 1.0 and approach.normalized().dot(weak_side.normalized()) >= cos(deg_to_rad(48.0))

static func classify(from: Vector2, to: Vector2, enemy: Vector2, weak_side: Vector2) -> String:
	if segment_distance(enemy, from, to) > 48.0:
		return "miss"
	return "hit" if vulnerable(from, enemy, weak_side) else "blocked"
