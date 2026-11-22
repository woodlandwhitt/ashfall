# Thrown explosives, ported from the WebView build: pipe bomb and frag (blast), molotov (burning ground for a few
# seconds), pulse grenade (wrecks robots, barely hurts flesh). The grenade flies on a simple arc, bounces off the
# ground and goes off when its fuse runs out (a molotov shatters on first impact).
class_name Nade
extends Node3D

const LOOK := {"pipe_bomb": Color(0.42, 0.42, 0.43), "frag": Color(0.29, 0.35, 0.23), "molotov": Color(0.48, 0.6, 0.35), "pulse_nade": Color(0.23, 0.42, 0.6)}
# what NADE throws when nothing is readied, in this order (build 13 added the rest)
const THROWN := ["pipe_bomb", "frag", "molotov", "pulse_nade", "nail_bomb", "dynamite", "sticky", "incendiary", "smoke", "flashbang", "cryo",
	"rad_nade", "plasma_nade", "prox_mine"]
var kind := ""
var spec: Dictionary = {}
var vel := Vector3.ZERO
var fuse := 1.7
var by_enemy := false
var mesh: Node3D
var stuck_to: Node3D = null       # a sticky bomb on someone
var stuck_off := Vector3.ZERO
var landed := false
var armed_t := 0.0
var rocket := false

static func default_spec() -> Dictionary:
	return {"r": 8.0, "dmg": 95.0, "fuse": 1.7}

static func throw_from(pos: Vector3, dir: Vector3, k: String, enemy: bool = false) -> Nade:
	var n := Nade.new()
	n.kind = k
	n.spec = Game.item(k).get("nade", default_spec())
	n.fuse = float(n.spec.get("fuse", 1.7))
	n.vel = dir * (11.0 if n.spec.has("mine") else 17.0) + Vector3.UP * 4.5
	n.by_enemy = enemy
	Game.main.add_child(n)
	n.global_position = pos
	return n

# a rocket from the Rocket Tube: flies straight and fast, goes off on whatever it touches
static func launch(pos: Vector3, dir: Vector3, dmg: float, r: float) -> Nade:
	var n := Nade.new()
	n.kind = "rocket"
	n.rocket = true
	n.spec = {"r": r, "dmg": dmg}
	n.fuse = 5.0
	n.vel = dir * 46.0
	Game.main.add_child(n)
	n.global_position = pos
	n.look_at(pos + dir, Vector3.UP)
	return n

func _ready() -> void:
	mesh = _model()
	add_child(mesh)
	if rocket:
		var tr := CPUParticles3D.new()
		tr.amount = 40
		tr.lifetime = 0.6
		tr.local_coords = false
		tr.gravity = Vector3(0, 0.6, 0)
		tr.initial_velocity_min = 0.2
		tr.initial_velocity_max = 0.6
		tr.scale_amount_min = 0.2
		tr.scale_amount_max = 0.45
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material = m
		tr.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.8, 0.4, 0.9))
		g.set_color(1, Color(0.4, 0.4, 0.4, 0.0))
		tr.color_ramp = g
		add_child(tr)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.light_energy = 2.0
		l.omni_range = 5.0
		add_child(l)
		Sfx.play_at("shotgun_far", global_position, 2.0, 0.6)
	else:
		Sfx.play_at("k_cloth1", global_position, -2.0, 1.3)

func _mat(c: Color, metal := 0.4, rough := 0.5, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.4
	return m

func _cyl(root: Node3D, r: float, h: float, m: Material, at := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	root.add_child(mi)

# each kind looks like itself: a model where there is one, a simple shape painted in its colours otherwise
func _model() -> Node3D:
	var root := Node3D.new()
	if spec.has("glb") and ResourceLoader.exists("res://guns/" + String(spec.glb) + ".glb"):
		var g := (load("res://guns/" + String(spec.glb) + ".glb") as PackedScene).instantiate() as Node3D
		g.scale = Vector3.ONE * float(spec.get("gs", 1.0))
		GunPaint.apply(g, {"glb": String(spec.glb), "finish": "olive" if kind != "incendiary" else "rust"})
		root.add_child(g)
		return root
	var col: Color = Color(String(spec.col)) if spec.has("col") else LOOK.get(kind, Color(0.4, 0.4, 0.42))
	match kind:
		"rocket":
			_cyl(root, 0.045, 0.5, _mat(Color(0.32, 0.36, 0.24)), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			var tip := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.045
			cm.height = 0.14
			tip.mesh = cm
			tip.material_override = _mat(Color(0.5, 0.5, 0.48), 0.6)
			tip.rotation.x = -PI / 2
			tip.position.z = -0.32
			root.add_child(tip)
		"molotov":
			_cyl(root, 0.04, 0.2, _mat(col, 0.1, 0.25))
			_cyl(root, 0.012, 0.08, _mat(Color(0.8, 0.75, 0.6), 0.0, 0.9), Vector3(0, 0.13, 0))
		"dynamite":
			for i in 3:
				var a := i / 3.0 * TAU
				_cyl(root, 0.017, 0.2, _mat(col, 0.0, 0.8), Vector3(cos(a), 0, sin(a)) * 0.02)
			_cyl(root, 0.004, 0.08, _mat(Color(0.2, 0.18, 0.15), 0.0, 0.9), Vector3(0, 0.13, 0))
		"prox_mine":
			_cyl(root, 0.09, 0.04, _mat(col, 0.5, 0.5))
			_cyl(root, 0.015, 0.03, _mat(Color(0.9, 0.2, 0.1), 0.0, 0.4, true), Vector3(0, 0.03, 0))
		"nail_bomb":
			_cyl(root, 0.045, 0.1, _mat(col, 0.7, 0.4))
			_cyl(root, 0.004, 0.05, _mat(Color(0.2, 0.18, 0.15), 0.0, 0.9), Vector3(0, 0.07, 0))
		"pipe_bomb":
			_cyl(root, 0.03, 0.2, _mat(col, 0.6, 0.45))
		_:
			var glow: bool = kind in ["pulse_nade", "plasma_nade", "rad_nade", "cryo"]
			if kind == "frag" or kind == "plasma_nade":
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.05
				sm.height = 0.11
				mi.mesh = sm
				mi.material_override = _mat(col, 0.4, 0.45, glow)
				root.add_child(mi)
			else:
				_cyl(root, 0.035, 0.13, _mat(Color(0.3, 0.31, 0.3), 0.5, 0.45))
				_cyl(root, 0.037, 0.04, _mat(col, 0.3, 0.45, glow))
	return root

func _physics_process(d: float) -> void:
	fuse -= d
	if stuck_to != null:
		if is_instance_valid(stuck_to):
			global_position = stuck_to.global_position + stuck_off
		if fuse <= 0.0:
			_explode()
		return
	if spec.has("mine") and landed:
		# armed after a moment; anything hostile (or you, careless) stepping close sets it off
		armed_t += d
		if armed_t > 1.0:
			for e in Game.main.enemies:
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < float(spec.mine):
					_explode()
					return
			if armed_t > 3.0 and Game.player and not Game.perks.has("light_step") and Game.player.global_position.distance_to(global_position) < 1.0:
				_explode()
		return
	if not rocket:
		vel.y -= 20.0 * d
	var p := global_position + vel * d
	var g := Game.height(p.x, p.z)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, p)
	q.collision_mask = 1 | (2 if rocket or spec.get("stick", false) else 0)
	if rocket and Game.player:
		q.exclude = [Game.player.get_rid()]
	var hit := space.intersect_ray(q)
	# a rocket, a sticky bomb: an enemy in the way counts as a hit too
	if (rocket or spec.get("stick", false)) and hit.is_empty():
		for e in Game.main.enemies:
			if is_instance_valid(e) and not e.dead and (e.global_position + Vector3.UP).distance_to(p) < 0.8:
				hit = {"position": p, "normal": -vel.normalized(), "collider": e}
				break
	if not hit.is_empty():
		if kind in ["molotov", "incendiary"] or rocket:
			global_position = hit.position
			_explode()
			return
		if spec.get("stick", false):
			global_position = hit.position
			var c = hit.get("collider")
			if c is Node3D and c.has_method("hit"):
				stuck_to = c
				stuck_off = global_position - (c as Node3D).global_position
			else:
				stuck_to = self
				stuck_off = Vector3.ZERO
				set_physics_process(true)
			Sfx.play_at("k_metal_click", global_position, -4.0, 1.3)
			return
		var nrm: Vector3 = hit.normal
		vel = vel.bounce(nrm) * 0.4
		p = hit.position + nrm * 0.06
	if p.y < g + 0.06:
		if kind in ["molotov", "incendiary"] or rocket:
			global_position = Vector3(p.x, g, p.z)
			_explode()
			return
		if spec.get("stick", false):
			global_position = Vector3(p.x, g + 0.03, p.z)
			stuck_to = self
			return
		p.y = g + 0.06
		vel = Vector3(vel.x * 0.55, absf(vel.y) * 0.3, vel.z * 0.55)
		if spec.has("mine") and vel.length() < 3.0:
			landed = true
			global_position = Vector3(p.x, g + 0.02, p.z)
			mesh.rotation = Vector3.ZERO
			Sfx.play_at("k_metal_click", p, -2.0, 0.7)
			return
		if vel.length() > 2.0:
			Sfx.play_at("k_metal_click", p, -8.0, 0.8)
	global_position = p
	if rocket:
		if vel.length() > 0.1:
			look_at(global_position + vel, Vector3.UP)
	else:
		mesh.rotate_x(d * 9.0)
	if fuse <= 0.0 and not spec.has("mine"):
		_explode()

# everyone hit, by how close they were (k: 1 at the centre to 0.4 at the edge)
func _each_enemy(at: Vector3, r: float, f: Callable) -> void:
	for e in Game.main.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var dist: float = e.global_position.distance_to(at)
		if dist <= r:
			f.call(e, 1.0 - dist / r * 0.6)

func _explode() -> void:
	var at := global_position
	if OS.get_cmdline_user_args().has("--selftest"):
		print("NADE ", kind, " at ", at, " fuse ", fuse, " near ", Game.main.enemies.map(func(e): return [e.type, snappedf(e.global_position.distance_to(at), 0.1), e.dead]).slice(0, 4))
	var r := float(spec.get("r", 8.0))
	var dmg := float(spec.get("dmg", 95.0))
	if not by_enemy and Game.perks.has("demolition"):
		r *= 1.15
		dmg *= 1.35
	if spec.get("fire", false):
		Fire.start(at, r, dmg * (1.5 if not by_enemy and Game.perks.has("pyromaniac") else 1.0), float(spec.get("dur", 8.0)), by_enemy)
		Sfx.play_at("x_rock1", at, 2.0, 1.6)
		queue_free()
		return
	if spec.has("smoke"):
		Cloud.start(at, r, float(spec.smoke), "smoke")
		Sfx.play_at("k_cloth1", at, 4.0, 0.5)
		queue_free()
		return
	if spec.has("rad"):
		Cloud.start(at, r, float(spec.rad), "rad", float(spec.get("dmg", 9.0)))
		_flash(at, Color(0.7, 1.0, 0.2), r * 0.5)
		Sfx.play_at("shotgun_far", at, 2.0, 0.7)
		queue_free()
		return
	if spec.has("flash"):
		# a blinding crack: everything that can see it staggers, blind, for a few seconds
		_flash(at, Color(1.0, 1.0, 0.95), r * 1.6)
		Sfx.play_at("shotgun", at, 8.0, 1.4)
		_each_enemy(at, r, func(e, k):
			if e.can_see(at - Vector3.UP * 1.2):
				e.stun = maxf(e.stun, float(spec.flash) * k)
			e.hit(float(spec.get("dmg", 4.0)) * k, e.global_position + Vector3.UP, Vector3.UP))
		if Game.player and Game.main.hud:
			var pd: float = Game.player.global_position.distance_to(at)
			var to: Vector3 = (at - Game.player.cam.global_position).normalized()
			var facing: float = (-Game.player.cam.global_basis.z).dot(to)
			if pd < r * 1.4 and facing > 0.2:
				Game.main.hud.white_flash(clampf((1.0 - pd / (r * 1.4)) * 2.5 * facing, 0.4, 3.0))
		queue_free()
		return
	if spec.has("cryo"):
		_flash(at, Color(0.55, 0.85, 1.0), r)
		Sfx.play_at("shotgun_far", at, 4.0, 1.3)
		Cloud.start(at, r * 0.8, 2.5, "frost")
		_each_enemy(at, r, func(e, k):
			e.hit(dmg * k, e.global_position + Vector3.UP, Vector3.UP)
			if not e.dead:
				e.slow = maxf(e.slow, float(spec.cryo) * k))
		if Game.player and Game.player.global_position.distance_to(at) < r * 0.6:
			Game.hurt(dmg * 0.3)
		queue_free()
		return
	var pulse: bool = spec.get("pulse", false)
	var plasma: bool = spec.get("plasma", false)
	_flash(at, Color(0.4, 0.6, 1.0) if pulse else (Color(0.4, 1.0, 0.5) if plasma else Color(1.0, 0.6, 0.25)), r)
	Sfx.play_at("shotgun_far", at, 6.0, 0.45 if not plasma else 0.7)
	Sfx.play_at("shotgun", at, 4.0, 0.55)
	if kind == "dynamite":
		Sfx.play_at("x_rock1", at, 6.0, 0.6)
	for e in Game.main.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var dist: float = e.global_position.distance_to(at)
		if dist > r:
			continue
		var k := 1.0 - dist / r * 0.6
		var robot: bool = e.def.get("robot", false)
		var amt := dmg * k
		if pulse:
			amt = dmg * (5.0 if robot else 0.25) * k
		var dir: Vector3 = (e.global_position - at).normalized()
		e.hit(amt, e.global_position + Vector3.UP, dir)
		if not e.dead:
			e.velocity += (dir + Vector3.UP * 0.4) * 6.0 * k
			if spec.has("nails"):
				e.bleed = [float(spec.nails) * 2.0, 6.0]
	for e in Game.main.enemies:
		if is_instance_valid(e):
			e.hear(at)
	if not by_enemy and not pulse:
		for n in Game.main.npcs.duplicate():
			if is_instance_valid(n) and n.visible and not n.follow and n.global_position.distance_to(at) < r:
				Game.main.provoke(n, dmg * (1.0 - n.global_position.distance_to(at) / r * 0.75), (n.global_position - at).normalized())
	if not pulse and Game.player:
		var pd: float = Game.player.global_position.distance_to(at)
		if pd < r:
			Game.hurt(dmg * (1.0 - pd / r) * 0.6)
		if pd < r * 3.0:
			Game.player.hurt_shake = maxf(Game.player.hurt_shake, 0.6 * (1.0 - pd / (r * 3.0)))
	queue_free()

func _flash(at: Vector3, col: Color, r: float) -> void:
	var main: Node = Game.main
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 6.0
	l.omni_range = r * 2.0
	main.add_child(l)
	l.global_position = at + Vector3.UP * 0.8
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	main._puff(at + Vector3.UP * 0.3, Vector3.UP, Color(col.r, col.g * 0.8, col.b * 0.6, 1.0), 26, r * 0.9)
	main._puff(at + Vector3.UP * 0.2, Vector3.UP, Color(0.25, 0.22, 0.2, 0.9), 22, r * 0.5)


# burning ground left by a molotov: hurts whoever stands in it, lights the area, burns out
class Fire extends Node3D:
	var r := 4.0
	var dps := 16.0
	var t := 8.0
	var by_enemy := false
	var light: OmniLight3D
	var parts: CPUParticles3D

	static func start(at: Vector3, radius: float, dmg: float, dur: float, enemy: bool) -> void:
		var f := Fire.new()
		f.r = radius
		f.dps = dmg
		f.t = dur
		f.by_enemy = enemy
		Game.main.add_child(f)
		f.global_position = at

	func _ready() -> void:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.15)
		light.light_energy = 3.0
		light.omni_range = r * 3.0
		light.position = Vector3.UP
		add_child(light)
		parts = CPUParticles3D.new()
		parts.amount = 48
		parts.lifetime = 0.8
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		parts.emission_sphere_radius = r * 0.75
		parts.direction = Vector3.UP
		parts.spread = 15.0
		parts.gravity = Vector3(0, 2.5, 0)
		parts.initial_velocity_min = 0.4
		parts.initial_velocity_max = 1.4
		parts.scale_amount_min = 0.3
		parts.scale_amount_max = 0.8
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		q.material = m
		parts.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
		g.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
		parts.color_ramp = g
		parts.position = Vector3.UP * 0.3
		parts.visible = false
		add_child(parts)
		# real flames over the burning patch
		for i in 4:
			var ff := FireFX.make(0.8 + randf() * 0.5, i == 0)
			add_child(ff)
			var a := randf() * TAU
			ff.position = Vector3(cos(a), 0, sin(a)) * r * (0.15 + 0.45 * randf())
		Sfx.play_at("k_slice", global_position, 0.0, 0.5)

	func _physics_process(d: float) -> void:
		t -= d
		light.light_energy = (2.5 + randf()) * clampf(t / 1.5, 0.0, 1.0)
		var at := global_position
		for e in Game.main.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			var p: Vector3 = e.global_position
			if Vector2(p.x - at.x, p.z - at.z).length() < r:
				e.hp -= dps * d * (0.4 if e.def.get("robot", false) else 1.0)
				e.state = "chase"
				e.hostile = true
				if e.hp <= 0.0:
					e.die(Vector3.UP)
		if Game.player:
			var pp: Vector3 = Game.player.global_position
			if Vector2(pp.x - at.x, pp.z - at.z).length() < r and pp.y < at.y + 1.2:
				Game.hurt(dps * d * 0.7)
		if t <= 0.0:
			queue_free()


# a lingering cloud: smoke that nobody can see through, a sickening green rad cloud, or a puff of frost
class Cloud extends Node3D:
	var r := 5.0
	var t := 10.0
	var kind := "smoke"
	var dps := 0.0
	var parts: CPUParticles3D
	static var smokes: Array = []

	static func start(at: Vector3, radius: float, dur: float, k: String, dmg := 0.0) -> void:
		var c := Cloud.new()
		c.r = radius
		c.t = dur
		c.kind = k
		c.dps = dmg
		Game.main.add_child(c)
		c.global_position = at
		if k == "smoke":
			smokes.append(c)

	# whether a line of sight passes through any smoke
	static func blocks(a: Vector3, b: Vector3) -> bool:
		for c in smokes:
			if not is_instance_valid(c) or c.t < 1.0:
				continue
			var cc: Vector3 = (c as Node3D).global_position + Vector3.UP * 1.2
			var ab := b - a
			var tt := clampf((cc - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if (a + ab * tt).distance_to(cc) < float(c.r) * 0.85:
				return true
		return false

	func _ready() -> void:
		parts = CPUParticles3D.new()
		var col := {"smoke": Color(0.62, 0.62, 0.6, 0.55), "rad": Color(0.6, 0.85, 0.2, 0.35), "frost": Color(0.8, 0.92, 1.0, 0.45)}[kind] as Color
		parts.amount = 70 if kind == "smoke" else 40
		parts.lifetime = 3.5 if kind != "frost" else 1.4
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		parts.emission_sphere_radius = r * 0.7
		parts.direction = Vector3.UP
		parts.spread = 60.0
		parts.gravity = Vector3(0.2, 0.15, 0)
		parts.initial_velocity_min = 0.1
		parts.initial_velocity_max = 0.5
		parts.scale_amount_min = r * 0.35
		parts.scale_amount_max = r * 0.7
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if kind != "smoke" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.albedo_texture = FireFX._tex(false)
		q.material = m
		parts.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(col.r, col.g, col.b, 0.0))
		g.add_point(0.2, col)
		g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
		parts.color_ramp = g
		parts.position.y = r * 0.4
		add_child(parts)
		if kind == "rad":
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 1.0, 0.3)
			l.light_energy = 1.2
			l.omni_range = r * 2.0
			l.position.y = 1.0
			add_child(l)

	func _physics_process(d: float) -> void:
		t -= d
		if t < 1.5:
			parts.emitting = false
		if kind == "rad":
			var at := global_position
			for e in Game.main.enemies:
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) < r and not e.def.get("robot", false):
					e.hp -= dps * d
					e.state = "chase"
					if e.hp <= 0.0:
						e.die(Vector3.UP)
			if Game.player and Game.player.global_position.distance_to(at) < r:
				Game.add_rad(dps * 0.8 * d)
				Game.hurt(dps * 0.25 * d)
		if t <= -3.5:
			smokes.erase(self)
			queue_free()
