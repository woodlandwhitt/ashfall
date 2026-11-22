# A fire that looks like one: licking flames that narrow and redden as they rise, a hot white-yellow core, a column
# of grey smoke drifting with the wind, embers spitting up, and a light that flickers on everything around it.
# Replaces the old solid flame cones on barrel fires and campfires, and burns where a molotov lands.
class_name FireFX
extends Node3D

var size := 1.0
var light: OmniLight3D
var base_energy := 2.0
var t := 0.0
static var flame_tex: Texture2D
static var smoke_tex: Texture2D

# a fire put in place of an old flame cone settles once the ground's collision is in: down onto what's under it if
# it was hanging in the air, and out of a boulder it was drawn half inside (or smaller, if there's no room)
func _settle() -> void:
	var tr := get_tree()
	for i in 3:
		await tr.physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var p := global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.25, p + Vector3.DOWN * 2.5, 1))
	var gy: float = Game.height(p.x, p.z)
	var below: float = float(hit.position.y) if not hit.is_empty() else gy
	if p.y - below > 0.12 and p.y - below < 2.4 and not _held_up(p):
		p.y = below + 0.02
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.28 * size
	q.shape = sph
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.45 * size)
	if not space.intersect_shape(q, 1).is_empty():
		var moved := false
		for r in [0.35, 0.6, 0.9]:
			for k in 8:
				var a := k / 8.0 * TAU
				var t2: Vector3 = p + Vector3(cos(a), 0, sin(a)) * r
				q.transform = Transform3D(Basis(), t2 + Vector3.UP * 0.45 * size)
				if space.intersect_shape(q, 1).is_empty():
					p = t2
					moved = true
					break
			if moved:
				break
		if not moved:
			scale = Vector3.ONE * 0.45
	global_position = p

# something drawn right under the fire (a barrel's rim, a brazier) holds it up even without collision of its own
func _held_up(p: Vector3) -> bool:
	var probe := p + Vector3.DOWN * 0.08
	var par := get_parent()
	if par == null:
		return false
	for c in par.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.visible:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if ab.size.length() < 3.0 and ab.grow(0.03).has_point(probe):
			return true
	return false

static func make(s := 1.0, with_smoke := true) -> FireFX:
	var f := FireFX.new()
	f.size = s
	f.set_meta("smoke", with_smoke)
	return f

static func _tex(flame: bool) -> Texture2D:
	if flame and flame_tex:
		return flame_tex
	if not flame and smoke_tex:
		return smoke_tex
	# a soft blob, drawn once: tall and pointed for flames, round for smoke
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			if flame:
				# wider at the bottom, a point at the top
				var w := lerpf(0.25, 0.85, clampf((v + 1.0) * 0.5, 0.0, 1.0))
				a = clampf(1.0 - sqrt((u / w) * (u / w) + v * v * 0.85), 0.0, 1.0)
				a = pow(a, 1.4)
			else:
				var d := sqrt(u * u + v * v)
				a = clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (0.75 + 0.25 * sin(x * 0.7) * sin(y * 0.6))
			im.set_pixel(x, y, Color(1, 1, 1, a))
	var tx := ImageTexture.create_from_image(im)
	if flame:
		flame_tex = tx
	else:
		smoke_tex = tx
	return tx

func _mat(flame: bool, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex(flame)
	m.disable_receive_shadows = true
	return m

func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return float(s[0])))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	return g

func _curve(a: float, b: float, c: float) -> Curve:
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, a))
	cv.add_point(Vector2(0.45, b))
	cv.add_point(Vector2(1.0, c))
	return cv

func _parts(n: int, life: float, quad: Vector2, flame: bool, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(2, n)
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = quad
	q.material = _mat(flame, additive)
	p.mesh = q
	p.visibility_range_end = 70.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _ready() -> void:
	var s := size
	# the flames: many, short-lived, rising and narrowing, yellow to orange to deep red
	var fl := _parts(int(26 * s), 0.75, Vector2(0.32, 0.5) * s, true, true)
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 0.16 * s
	fl.direction = Vector3.UP
	fl.spread = 12.0
	fl.gravity = Vector3(0, 1.6 * s, 0)
	fl.initial_velocity_min = 0.35 * s
	fl.initial_velocity_max = 0.9 * s
	fl.angle_min = -12.0
	fl.angle_max = 12.0
	fl.scale_amount_curve = _curve(0.7, 1.0, 0.15)
	fl.color_ramp = _ramp([[0.0, Color(1.0, 0.85, 0.5, 0.0)], [0.12, Color(1.0, 0.78, 0.38, 0.85)], [0.45, Color(1.0, 0.42, 0.08, 0.65)], [0.8, Color(0.6, 0.12, 0.03, 0.25)], [1.0, Color(0.2, 0.05, 0.02, 0.0)]])
	# the white-hot core low in the fire
	var core := _parts(int(10 * s), 0.4, Vector2(0.24, 0.3) * s, true, true)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = 0.1 * s
	core.direction = Vector3.UP
	core.initial_velocity_min = 0.2 * s
	core.initial_velocity_max = 0.5 * s
	core.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.75, 0.0)], [0.2, Color(1.0, 0.92, 0.65, 0.9)], [1.0, Color(1.0, 0.6, 0.2, 0.0)]])
	# smoke: slow, spreading, drifting downwind, fading out high up
	if get_meta("smoke", true):
		var sm := _parts(int(9 * s), 3.6, Vector2(0.7, 0.7) * s, false, false)
		sm.position.y = 0.55 * s
		sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sm.emission_sphere_radius = 0.12 * s
		sm.direction = Vector3(0.25, 1, 0.1)
		sm.spread = 10.0
		sm.gravity = Vector3(0.35, 0.45, 0.1)
		sm.initial_velocity_min = 0.4 * s
		sm.initial_velocity_max = 0.7 * s
		sm.angle_min = -180.0
		sm.angle_max = 180.0
		sm.angular_velocity_min = -20.0
		sm.angular_velocity_max = 20.0
		sm.scale_amount_curve = _curve(0.5, 1.4, 2.4)
		sm.color_ramp = _ramp([[0.0, Color(0.2, 0.18, 0.16, 0.0)], [0.15, Color(0.22, 0.2, 0.18, 0.32)], [0.6, Color(0.3, 0.29, 0.28, 0.16)], [1.0, Color(0.35, 0.35, 0.35, 0.0)]])
	# embers spitting up and drifting
	var em := _parts(int(7 * s), 1.6, Vector2(0.025, 0.025) * s, false, true)
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 0.15 * s
	em.direction = Vector3.UP
	em.spread = 28.0
	em.gravity = Vector3(0.2, -0.6, 0.0)
	em.initial_velocity_min = 1.0 * s
	em.initial_velocity_max = 2.4 * s
	em.damping_min = 0.5
	em.damping_max = 1.2
	em.color_ramp = _ramp([[0.0, Color(1.0, 0.8, 0.4, 1.0)], [0.7, Color(1.0, 0.4, 0.1, 0.8)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])
	# the light it throws, flickering
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	base_energy = 1.7 * s
	light.light_energy = base_energy
	light.omni_range = 6.5 * s
	light.omni_attenuation = 1.3
	light.position.y = 0.45 * s
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 10.0
	add_child(light)
	t = randf() * 10.0

func _process(d: float) -> void:
	t += d
	# two out-of-step wobbles and a little jitter: a fire never holds still
	var f := 0.82 + sin(t * 9.1) * 0.08 + sin(t * 15.3 + 1.7) * 0.06 + randf() * 0.08
	light.light_energy = base_energy * f
	light.position.x = sin(t * 7.0) * 0.04 * size
	light.position.z = cos(t * 5.3) * 0.04 * size

# the exported scenery's flame cones (bright unlit cones over barrels and fire pits) become real fires
static func dress(root: Node) -> void:
	var done: Array = []
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var m := mi.get_active_material(0)
		if not m is StandardMaterial3D:
			continue
		var sm := m as StandardMaterial3D
		# the flames were drawn unlit and over-bright (colour values above 1)
		if sm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or sm.albedo_color.r < 1.2 or sm.albedo_color.r + sm.albedo_color.g + sm.albedo_color.b < 2.6:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if ab.size.length() > 3.0:
			continue
		mi.visible = false
		var base := Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
		var dup := false
		for p in done:
			if (p as Vector3).distance_to(base) < 0.6:
				dup = true
		if dup:
			continue
		done.append(base)
		var f := FireFX.make(clampf(maxf(ab.size.x, ab.size.z) * 1.9, 0.6, 2.2))
		root.add_child(f)
		f.global_position = base
		f._settle()
