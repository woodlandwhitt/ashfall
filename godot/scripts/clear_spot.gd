# Finding clear ground for a body: someone (or something) placed inside a boulder, a desk or a wall steps out to the
# nearest spot where a standing body fits.
class_name ClearSpot

static func free_at(space: PhysicsDirectSpaceState3D, p: Vector3, r: float, h: float, exclude: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	q.shape = cap
	q.collision_mask = 1
	q.exclude = exclude
	q.transform = Transform3D(Basis(), p + Vector3.UP * (h * 0.5 + 0.2))
	return space.intersect_shape(q, 1).is_empty()

# the nearest clear spot within 'reach' (the point itself if it's clear); Vector3.INF if there's none
static func near(space: PhysicsDirectSpaceState3D, p: Vector3, r: float, h: float, exclude: Array, reach := 3.0) -> Vector3:
	if free_at(space, p, r, h, exclude):
		return p
	var step := 0.4
	var d := step
	while d <= reach:
		var n := maxi(8, int(TAU * d / 0.45))
		for i in n:
			var a := i / float(n) * TAU
			var c := p + Vector3(cos(a), 0, sin(a)) * d
			if Game.area == "world":
				c.y = Game.height(c.x, c.z)
			if free_at(space, c, r, h, exclude):
				return c
		d += step
	return Vector3.INF
