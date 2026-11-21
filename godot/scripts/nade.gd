# Thrown explosives, ported from the WebView build: pipe bomb and frag (blast), molotov (burning ground for a few
# seconds), pulse grenade (wrecks robots, barely hurts flesh). The grenade flies on a simple arc, bounces off the
# ground and goes off when its fuse runs out (a molotov shatters on first impact).
class_name Nade
extends Node3D

const LOOK := {"pipe_bomb": Color(0.42, 0.42, 0.43), "frag": Color(0.29, 0.35, 0.23), "molotov": Color(0.48, 0.6, 0.35), "pulse_nade": Color(0.23, 0.42, 0.6)}
const THROWN := ["pipe_bomb", "frag", "molotov", "pulse_nade"]
var kind := ""
var spec: Dictionary = {}
var vel := Vector3.ZERO
var fuse := 1.7
var by_enemy := false
var mesh: MeshInstance3D

static func default_spec() -> Dictionary:
	return {"r": 8.0, "dmg": 95.0, "fuse": 1.7}

static func throw_from(pos: Vector3, dir: Vector3, k: String, enemy: bool = false) -> Nade:
	var n := Nade.new()
	n.kind = k
	n.spec = Game.item(k).get("nade", default_spec())
	n.fuse = float(n.spec.get("fuse", 1.7))
	n.vel = dir * 17.0 + Vector3.UP * 4.5
	n.by_enemy = enemy
	Game.main.add_child(n)
	n.global_position = pos
	return n

func _ready() -> void:
	mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = LOOK.get(kind, Color(0.4, 0.4, 0.42))
	m.metallic = 0.1 if kind == "molotov" else 0.6
	m.roughness = 0.25 if kind == "molotov" else 0.45
	if kind == "pulse_nade":
		m.emission_enabled = true
		m.emission = Color(0.15, 0.4, 1.0)
		m.emission_energy_multiplier = 1.5
	if kind == "molotov":
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.045
		c.height = 0.2
		mesh.mesh = c
	else:
		var s := SphereMesh.new()
		s.radius = 0.055
		s.height = 0.12 if kind == "frag" else 0.2
		mesh.mesh = s
	mesh.material_override = m
	add_child(mesh)
	Sfx.play_at("k_cloth1", global_position, -2.0, 1.3)

func _physics_process(d: float) -> void:
	fuse -= d
	vel.y -= 20.0 * d
	var p := global_position + vel * d
	var g := Game.height(p.x, p.z)
	# solid boxes (buildings, walls) stop it too
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, p)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		if kind == "molotov":
			global_position = hit.position
			_explode()
			return
		var nrm: Vector3 = hit.normal
		vel = vel.bounce(nrm) * 0.4
		p = hit.position + nrm * 0.06
	if p.y < g + 0.06:
		if kind == "molotov":
			global_position = Vector3(p.x, g, p.z)
			_explode()
			return
		p.y = g + 0.06
		vel = Vector3(vel.x * 0.55, absf(vel.y) * 0.3, vel.z * 0.55)
		if vel.length() > 2.0:
			Sfx.play_at("k_metal_click", p, -8.0, 0.8)
	global_position = p
	mesh.rotate_x(d * 9.0)
	if fuse <= 0.0:
		_explode()

func _explode() -> void:
	var at := global_position
	if OS.get_cmdline_user_args().has("--selftest"):
		print("NADE ", kind, " at ", at, " fuse ", fuse, " near ", Game.main.enemies.map(func(e): return [e.type, snappedf(e.global_position.distance_to(at), 0.1), e.dead]).slice(0, 4))
	var r := float(spec.get("r", 8.0))
	var dmg := float(spec.get("dmg", 95.0))
	if spec.get("fire", false):
		Fire.start(at, r, dmg, float(spec.get("dur", 8.0)), by_enemy)
		Sfx.play_at("x_rock1", at, 2.0, 1.6)
		queue_free()
		return
	var pulse: bool = spec.get("pulse", false)
	_flash(at, Color(0.4, 0.6, 1.0) if pulse else Color(1.0, 0.6, 0.25), r)
	Sfx.play_at("shotgun_far", at, 6.0, 0.45)
	Sfx.play_at("shotgun", at, 4.0, 0.55)
	for e in Game.main.enemies:
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
	for e in Game.main.enemies:
		if is_instance_valid(e):
			e.hear(at)
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
		add_child(parts)
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
