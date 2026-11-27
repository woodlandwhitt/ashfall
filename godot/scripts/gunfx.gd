# Gunfire and what it hits (build 23). Before this a shot was a flat orange square at the muzzle and a handful of
# tan squares where it landed. Now:
#  - the muzzle: a flash shaped like a real one (a short cone of flame out of the barrel, a star of side-jets, a hot
#    core), different every shot, gone in two frames; a breath of smoke that hangs and drifts; a few sparks; and on a
#    gun that ejects, a brass case spinning out to the right
#  - the impact: by what was hit. Dirt kicks up a brown plume and clods; stone and concrete a grey puff and sparks;
#    wood splinters; metal a spray of bright sparks and a ring. Each leaves a hole in the surface (a decal that
#    follows the shape under it) and the last 48 stay
#  - tracers: a short bright streak that runs from the gun to the hit rather than a line drawn whole
# All textures are made here, in code, once.
class_name GunFX

static var _tex := {}
static var _mats := {}
static var _holes: Array = []
const MAX_HOLES := 48

# ---------------------------------------------------------------- textures
static func _soft() -> Texture2D:
	if _tex.has("soft"):
		return _tex.soft
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.09
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.65 + 0.35 * (nz.get_noise_2d(x, y) * 0.5 + 0.5))
			im.set_pixel(x, y, Color(1, 1, 1, a))
	_tex["soft"] = ImageTexture.create_from_image(im)
	return _tex.soft

# a flash seen side-on: a tapered flame along +Y, ragged at its tip
static func _flame() -> Texture2D:
	if _tex.has("flame"):
		return _tex.flame
	var w := 32
	var h := 96
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.15
	for y in h:
		var t := float(y) / h          # 0 at the muzzle (bottom of the image is y = h)
		var along := 1.0 - t
		var half := (0.18 + 0.82 * sin(clampf(along * 1.15, 0.0, 1.0) * PI * 0.5)) * (1.0 - pow(along, 3.0)) * 0.5
		for x in w:
			var dx := absf((x + 0.5) / w - 0.5)
			var a := clampf(1.0 - dx / maxf(0.02, half), 0.0, 1.0)
			a *= 0.75 + 0.25 * nz.get_noise_2d(x * 2.0, y)
			var hot := clampf(1.0 - dx / maxf(0.02, half * 0.45), 0.0, 1.0) * (1.0 - along * 0.6)
			im.set_pixel(x, y, Color(1.0, 0.72 + 0.28 * hot, 0.35 + 0.6 * hot, clampf(a, 0.0, 1.0)))
	_tex["flame"] = ImageTexture.create_from_image(im)
	return _tex.flame

# a flash seen head-on: a hot core and four to six ragged prongs
static func _star() -> Texture2D:
	if _tex.has("star"):
		return _tex.star
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var prong := pow(absf(cos(ang * 2.5)), 6.0) * 0.75 + 0.25
			var a := clampf(1.0 - r / prong, 0.0, 1.0)
			var core := clampf(1.0 - r / 0.3, 0.0, 1.0)
			im.set_pixel(x, y, Color(1.0, 0.75 + 0.25 * core, 0.4 + 0.6 * core, clampf(a * a + core, 0.0, 1.0)))
	_tex["star"] = ImageTexture.create_from_image(im)
	return _tex.star

# a bullet hole: a dark, rough-edged pit with a lighter chipped ring round it
static func _hole() -> Texture2D:
	if _tex.has("hole"):
		return _tex.hole
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.2
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r := p.length() + nz.get_noise_2d(x, y) * 0.12
			var c := Color(0, 0, 0, 0)
			if r < 0.22:
				c = Color(0.03, 0.025, 0.02, 1.0)
			elif r < 0.4:
				c = Color(0.12, 0.1, 0.08, 0.95)
			elif r < 0.75:
				var k := (r - 0.4) / 0.35
				c = Color(0.55, 0.5, 0.45, (1.0 - k) * 0.5)
			im.set_pixel(x, y, c)
	_tex["hole"] = ImageTexture.create_from_image(im)
	return _tex.hole

static func _mat(key: String, tex: Texture2D, add: bool, col := Color.WHITE, billboard := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_mats[key] = m
	return m

# ---------------------------------------------------------------- particles
static func _burst(parent: Node, at: Vector3, dir: Vector3, n: int, life: float, v: Vector2, spread: float, grav: Vector3,
		size: Vector2, col0: Color, col1: Color, mat: Material, grow := 1.0, damp := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, n)
	p.lifetime = life
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.local_coords = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v.x
	p.initial_velocity_max = v.y
	p.gravity = grav
	p.damping_min = damp
	p.damping_max = damp * 1.5
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	if grow != 1.0:
		var c := Curve.new()
		c.add_point(Vector2(0, 1.0 / grow))
		c.add_point(Vector2(1, 1.0))
		p.scale_amount_curve = c
	p.angle_min = 0.0
	p.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, col0)
	g.set_color(1, col1)
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

# sparks: thin bright streaks that fly and fall
static func _sparks(parent: Node, at: Vector3, dir: Vector3, n: int, v: float, spread: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.randomness = 0.6
	p.local_coords = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v * 0.4
	p.initial_velocity_max = v
	p.gravity = Vector3(0, -12, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.45)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.9, 1))
	g.set_color(1, Color(1.0, 0.4, 0.1, 0))
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---------------------------------------------------------------- the muzzle
# Called with the muzzle node (its -Z is the barrel's way, in the first-person view and on a body alike) and how big
# a gun it is (pistol ~1, rifle ~1.4, shotgun 1.8). Quiet guns get a wisp of smoke and nothing else.
static func muzzle(m: Node3D, size: float, quiet := false, energy := false, eject := true, aim := Vector3.ZERO) -> void:
	if m == null or not m.is_inside_tree():
		return
	var world := m.get_tree().current_scene
	# the way the shot goes: given (the first-person view knows it better than a gun model's own axes), or -Z
	var fwd := aim.normalized() if aim.length() > 0.1 else -m.global_basis.z.normalized()
	var at := m.global_position
	if not quiet:
		var f := Node3D.new()
		m.add_child(f)
		f.global_basis = Basis.looking_at(fwd, Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT)
		var col := Color(0.55, 0.85, 1.0) if energy else Color(1.0, 0.85, 0.6)
		var fl := _mat("flame", _flame(), true, col, BaseMaterial3D.BILLBOARD_DISABLED)
		var st := _mat("star", _star(), true, col, BaseMaterial3D.BILLBOARD_DISABLED)
		var fl_len := randf_range(0.16, 0.26) * size
		var wid := fl_len * randf_range(0.32, 0.45)
		# the cone out of the barrel: two crossed planes along the barrel, randomly turned about it
		var roll := randf() * PI
		for k in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(wid, fl_len)
			qm.material = fl
			q.mesh = qm
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# the quad's +Y along -Z (the barrel), its face turned roll + k*90 about the barrel
			q.basis = Basis(Vector3.FORWARD, roll + k * PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
			q.position = Vector3(0, 0, -fl_len * 0.5)
			f.add_child(q)
		# the star across the muzzle, facing along the barrel
		var s := MeshInstance3D.new()
		var sm := QuadMesh.new()
		var ss := fl_len * randf_range(0.7, 1.0)
		sm.size = Vector2(ss, ss)
		sm.material = st
		s.mesh = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.rotation = Vector3(0, 0, randf() * TAU)
		s.position = Vector3(0, 0, -0.02)
		f.add_child(s)
		# two frames at least, however slow the frames are coming
		f.get_tree().create_timer(maxf(0.045 if size < 1.6 else 0.06, m.get_process_delta_time() * 1.8)).timeout.connect(f.queue_free)
		_sparks(world, at + fwd * 0.05, fwd, 3 + int(size * 2), 7.0, 18.0)
	# smoke: a soft breath that leaves the barrel, slows, rises and spreads
	var smk := _mat("smoke", _soft(), false)
	_burst(world, at + fwd * 0.04, fwd, 4 if quiet else 6, 1.2, Vector2(0.4, 1.4), 14.0, Vector3(0, 0.35, 0),
		Vector2(0.05, 0.11) * size, Color(0.75, 0.73, 0.7, 0.32 if not quiet else 0.18), Color(0.7, 0.7, 0.7, 0.0), smk, 3.5, 2.5)
	if eject and not energy:
		_case(world, m.global_position, fwd, size)

# a flash and smoke at a point, aimed along dir (for guns without a muzzle node: the enemies' guns)
static func muzzle_at(world: Node, pos: Vector3, dir: Vector3, size: float) -> void:
	var n := Node3D.new()
	world.add_child(n)
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	n.global_transform = Transform3D(Basis(side, side.cross(d).normalized() * -1.0, -d).orthonormalized(), pos)
	n.global_basis = Basis.looking_at(d, Vector3.UP)
	muzzle(n, size, false, false, false)
	n.get_tree().create_timer(0.2).timeout.connect(n.queue_free)

# a brass case thrown out to the right and a little back, tumbling, bouncing once
static func _case(world: Node, at: Vector3, fwd: Vector3, size: float) -> void:
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0045 * size
	cm.bottom_radius = 0.0045 * size
	cm.height = 0.022 * size
	cm.radial_segments = 6
	cm.rings = 1
	c.mesh = cm
	if not _mats.has("brass"):
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.85, 0.62, 0.25)
		bm.metallic = 0.9
		bm.roughness = 0.3
		_mats["brass"] = bm
	c.material_override = _mats.brass
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(c)
	var right := fwd.cross(Vector3.UP).normalized()
	# out of the ejection port, a hand back from the muzzle
	c.global_position = at - fwd * 0.16 * size + right * 0.02
	var v: Vector3 = right * randf_range(1.6, 2.4) + Vector3.UP * randf_range(1.4, 2.0) - fwd * 0.4
	var spin := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	var tw := c.create_tween()
	var state := {"v": v, "bounced": false}
	tw.tween_method(func(tt: float):
		if not is_instance_valid(c):
			return
		var dt := 1.0 / 60.0
		state.v += Vector3(0, -9.8, 0) * dt
		c.global_position += state.v * dt
		c.rotation += spin * dt
		var gy := Game.height(c.global_position.x, c.global_position.z) if Game.area == "world" else -INF
		if c.global_position.y < gy + 0.01:
			c.global_position.y = gy + 0.01
			if not state.bounced:
				state.bounced = true
				state.v = Vector3(state.v.x * 0.3, -state.v.y * 0.25, state.v.z * 0.3)
				spin *= 0.3
				if Game.player and c.global_position.distance_to(Game.player.global_position) < 4.0 and randf() < 0.5:
					Sfx.play_at("k_click", c.global_position, -22.0, randf_range(2.2, 2.8))
			else:
				state.v = Vector3.ZERO
				spin = Vector3.ZERO, 0.0, 1.0, 1.4)
	tw.tween_callback(c.queue_free)

# ---------------------------------------------------------------- the impact
# what a hit landed on: "dirt", "stone", "wood", "metal" or "flesh"
static func surface(hit: Dictionary) -> String:
	var c = hit.get("collider")
	var p: Vector3 = hit.position
	if c is Node:
		var n := c as Node
		for k in ["metal", "wood", "stone", "dirt"]:
			if n.is_in_group("surf_" + k) or n.has_meta("surf_" + k):
				return k
		var nm := String(n.name).to_lower()
		if "barrel" in nm or "drum" in nm or "car" in nm or "truck" in nm or "bus" in nm:
			return "metal"
	if Game.area == "world" and absf(p.y - Game.height(p.x, p.z)) < 0.25 and Vector3(hit.normal).y > 0.5:
		return "dirt"
	if Game.area != "world":
		return "stone"
	return "wood" if randf() < 0.35 else "stone"

static func impact(world: Node, pos: Vector3, normal: Vector3, kind: String) -> void:
	var nrm := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var smk := _mat("smoke", _soft(), false)
	var dust := _mat("dust", _soft(), false)
	match kind:
		"dirt":
			# a plume of dust thrown up and hanging, lighter than the ground it came from, and clods
			var up := (nrm + Vector3.UP * 0.6).normalized()
			_burst(world, pos + nrm * 0.03, up, 12, 1.0, Vector2(1.2, 3.8), 18.0, Vector3(0, -5, 0), Vector2(0.1, 0.22),
				Color(0.78, 0.7, 0.58, 0.95), Color(0.75, 0.68, 0.58, 0.0), dust, 2.2, 2.0)
			_burst(world, pos + nrm * 0.08, up, 6, 2.0, Vector2(0.3, 1.0), 30.0, Vector3(0, 0.15, 0), Vector2(0.25, 0.45),
				Color(0.82, 0.75, 0.64, 0.7), Color(0.8, 0.75, 0.65, 0.0), smk, 2.5, 1.5)
			_chunks(world, pos, up, 7, Color(0.36, 0.29, 0.2))
			Sfx.play_at(["x_rock0", "x_rock1"][randi() % 2], pos, -9.0, randf_range(0.8, 0.95))
		"metal":
			_sparks(world, pos + nrm * 0.02, nrm, 16, 9.0, 55.0)
			_burst(world, pos + nrm * 0.04, nrm, 3, 0.6, Vector2(0.2, 0.8), 30.0, Vector3(0, 0.3, 0), Vector2(0.08, 0.14),
				Color(0.6, 0.6, 0.62, 0.35), Color(0.6, 0.6, 0.6, 0.0), smk, 2.0)
			Sfx.play_at("k_click", pos, -6.0, randf_range(1.7, 2.3))
			Sfx.play_at(["x_rock0", "x_rock1"][randi() % 2], pos, -10.0, randf_range(1.4, 1.7))
		"wood":
			_chunks(world, pos, nrm, 7, Color(0.55, 0.4, 0.25), Vector3(0.012, 0.012, 0.07))
			_burst(world, pos + nrm * 0.04, nrm, 6, 0.8, Vector2(0.5, 2.0), 30.0, Vector3(0, -2, 0), Vector2(0.06, 0.12),
				Color(0.6, 0.5, 0.38, 0.6), Color(0.6, 0.5, 0.4, 0.0), dust, 2.0)
			Sfx.play_at(["x_rock0", "x_rock1"][randi() % 2], pos, -8.0, randf_range(1.1, 1.3))
		_:
			_sparks(world, pos + nrm * 0.02, nrm, 5, 6.0, 50.0)
			_burst(world, pos + nrm * 0.04, nrm, 10, 1.0, Vector2(0.8, 3.0), 28.0, Vector3(0, -3, 0), Vector2(0.08, 0.18),
				Color(0.8, 0.78, 0.74, 0.9), Color(0.75, 0.73, 0.7, 0.0), dust, 2.2)
			_burst(world, pos + nrm * 0.05, nrm, 4, 1.6, Vector2(0.2, 0.7), 40.0, Vector3(0, 0.15, 0), Vector2(0.22, 0.36),
				Color(0.82, 0.8, 0.76, 0.45), Color(0.8, 0.8, 0.8, 0.0), smk, 2.2)
			_chunks(world, pos, nrm, 4, Color(0.45, 0.43, 0.4))
			Sfx.play_at(["x_rock0", "x_rock1"][randi() % 2], pos, -7.0, randf_range(1.0, 1.2))
	_decal(world, pos, nrm, kind)

# chips of what was hit, flung out and dropping
static func _chunks(world: Node, pos: Vector3, nrm: Vector3, n: int, col: Color, sz := Vector3(0.025, 0.02, 0.03)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = nrm
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.particle_flag_rotate_y = true
	var b := BoxMesh.new()
	b.size = sz
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	b.material = m
	p.mesh = b
	world.add_child(p)
	p.global_position = pos + nrm * 0.03
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _decal(world: Node, pos: Vector3, nrm: Vector3, kind: String) -> void:
	# a small lit quad laid on the surface (a Decal node draws nothing under the compatibility renderer that some
	# phones fall back to)
	if not _mats.has("hole"):
		var hm := StandardMaterial3D.new()
		hm.albedo_texture = _hole()
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.roughness = 1.0
		hm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["hole"] = hm
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var s := randf_range(0.09, 0.12) * (1.8 if kind == "dirt" else 1.0)
	qm.size = Vector2(s, s)
	q.mesh = qm
	q.material_override = _mats.hole
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.visibility_range_end = 40.0
	world.add_child(q)
	# the quad faces +Z: turn that onto the normal, a random twist about it
	var z := nrm
	var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
	var b := Basis(x, z.cross(x).normalized(), z).rotated(z, randf() * TAU)
	q.global_transform = Transform3D(b, pos + nrm * 0.006)
	_holes.append(q)
	while _holes.size() > MAX_HOLES:
		var o = _holes.pop_front()
		if is_instance_valid(o):
			o.queue_free()

# ---------------------------------------------------------------- tracers
# a short streak that runs from a to b over a couple of frames
static func tracer(world: Node, a: Vector3, b: Vector3, col: Color, thick := 0.012) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.5:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = thick * 0.4
	cm.bottom_radius = thick
	var seg := minf(L * 0.35, 6.0)
	cm.height = seg
	cm.radial_segments = 4
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var dir := d / L
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var bas := Basis(side, dir, side.cross(dir).normalized())
	var travel := clampf(L / 600.0, 0.03, 0.14)
	var tw := mi.create_tween()
	tw.tween_method(func(f: float):
		if is_instance_valid(mi):
			var head := a + d * f
			mi.global_transform = Transform3D(bas, head - dir * seg * 0.5 * minf(1.0, f * L / seg)), 0.0, 1.0, travel)
	tw.tween_callback(mi.queue_free)
