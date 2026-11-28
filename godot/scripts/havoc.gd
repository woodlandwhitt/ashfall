# Loose things you can knock about (build 24): tyres, traffic cones, buckets, cans, crates and fuel cans lying round
# the settlements and the road stops, real rigid bodies. A bullet sends them spinning, a blast throws them, you
# kick them out of the way by walking into them, a car shoves them aside. They're scattered from a seed per place
# (the same every visit), made only while you're near, put to sleep until something touches them, and cleared when
# you've gone. Nothing here is saved: a cone you knocked over is upright again next time.
class_name Havoc
extends Node3D

const NEAR := 110.0
const FAR := 170.0
const PER_SITE := 26
static var inst: Havoc
var main
var live := {}            # site -> Array of bodies
var check_t := 0.0
var mats := {}

func setup(m) -> void:
	main = m
	inst = self

func _process(d: float) -> void:
	check_t -= d
	if check_t > 0.0 or Game.player == null or Game.area != "world":
		return
	check_t = 1.0
	var pp: Vector3 = Game.player.global_position
	for k in Frontier.SITES:
		var s: Array = Frontier.SITES[k]
		var dist := Vector2(pp.x - float(s[0]), pp.z - float(s[1])).length()
		if dist < NEAR + float(s[2]) and not live.has(k):
			live[k] = _scatter(k, s)
		elif dist > FAR + float(s[2]) and live.has(k):
			for b in live[k]:
				if is_instance_valid(b):
					b.queue_free()
			live.erase(k)

# ---------------------------------------------------------------- what's lying about, and where
func _scatter(site: String, s: Array) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(site + "havoc")
	var space := get_world_3d().direct_space_state
	var r: float = minf(float(s[2]) * 0.8, 45.0)
	var kinds := ["tyre", "tyre", "tyre", "cone", "cone", "cone", "bucket", "can", "can", "crate", "fuelcan", "tyre", "cone"]
	# out in the wilds (a crash site, a tribe's camp, a lookout, a farm) there are no roadworks: no traffic cones,
	# fewer tyres, and less of it all
	var wild := site in ["starfall", "ashborn", "lookout", "holloway", "havens_door", "glass_camp"]
	if wild:
		kinds = ["can", "can", "bucket", "crate", "crate", "fuelcan", "tyre"]
	var per := PER_SITE / 2 if wild else PER_SITE
	var tries := 0
	while out.size() < per and tries < PER_SITE * 6:
		tries += 1
		var a := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * r
		var x := float(s[0]) + cos(a) * rr
		var z := float(s[1]) + sin(a) * rr
		var g: float = Game.height(x, z)
		# only on open ground: nothing above it (a roof, a table, a wall), and not inside a building
		if Frontier.indoors(x, z):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, g + 25.0, z), Vector3(x, g - 1.0, z), 1))
		if hit.is_empty() or absf(float(hit.position.y) - g) > 0.15:
			continue
		var kind: String = kinds[rng.randi() % kinds.size()]
		# cones come in a little run, a roadworks or a checkpoint; tyres in a heap of two or three
		var n := 1
		if kind == "cone":
			n = rng.randi_range(2, 4)
		elif kind == "tyre" and rng.randf() < 0.4:
			n = rng.randi_range(2, 3)
		var yaw := rng.randf() * TAU
		for i in n:
			var at := Vector3(x, g, z)
			var rot := Vector3(0, yaw, 0)
			if kind == "cone":
				at += Vector3(cos(yaw), 0, sin(yaw)) * i * 1.4
				at.y = Game.height(at.x, at.z)
				if rng.randf() < 0.2:
					rot = Vector3(PI * 0.5, yaw, 0)   # one knocked over already
			elif kind == "tyre":
				if i > 0:
					at.y += 0.24 * i                      # stacked flat
				elif n == 1 and rng.randf() < 0.45:
					rot = Vector3(0, yaw, PI * 0.5)       # standing on its tread
			var b := make(kind, rng)
			add_child(b)
			b.global_position = at + Vector3(0, _lift(kind, rot), 0)
			b.rotation = rot
			# let it settle onto the ground as it really lies (a slope, a stone under it), then it sleeps by itself
			# (build 24: a tyre stood on its tread was set down 12 cm up and slept there, hanging in the air)
			b.sleeping = false
			out.append(b)
	return out

static func _lift(kind: String, rot: Vector3) -> float:
	match kind:
		"tyre": return 0.33 if absf(rot.z) > 0.5 else 0.12
		"cone": return 0.37 if absf(rot.x) < 0.5 else 0.17
		"bucket": return 0.17
		"can": return 0.07
		"crate": return 0.28
		"fuelcan": return 0.2
	return 0.2

# ---------------------------------------------------------------- the things themselves
func _mat(key: String, col: Color, rough: float, metal := 0.0, emissive := 0.0) -> StandardMaterial3D:
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = metal
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emissive
		mats[key] = m
	return mats[key]

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.visibility_range_end = 90.0
	parent.add_child(mi)
	return mi

func make(kind: String, rng: RandomNumberGenerator) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "Havoc_" + kind
	b.collision_layer = 1
	b.collision_mask = 1
	b.can_sleep = true
	b.sleeping = true
	b.continuous_cd = false
	b.add_to_group("havoc")
	b.set_meta("kind", kind)
	var cs := CollisionShape3D.new()
	var pm := PhysicsMaterial.new()
	match kind:
		"tyre":
			b.mass = 9.0
			pm.bounce = 0.35
			pm.friction = 0.9
			var t := TorusMesh.new()
			t.inner_radius = 0.2
			t.outer_radius = 0.33
			t.rings = 20
			t.ring_segments = 10
			_mi(b, t, _mat("rubber", Color(0.06, 0.06, 0.06), 0.92))
			# the tread: a band of ribs round the outside
			for i in 18:
				var a := i * TAU / 18.0
				_mi(b, _box(Vector3(0.045, 0.2, 0.025)), _mat("rubber2", Color(0.09, 0.09, 0.09), 0.95), Vector3(cos(a) * 0.325, 0, sin(a) * 0.325), Vector3(0, -a, 0))
			if rng.randf() < 0.5:
				# still on its rusty rim
				var rim := CylinderMesh.new()
				rim.top_radius = 0.2
				rim.bottom_radius = 0.2
				rim.height = 0.16
				rim.radial_segments = 14
				_mi(b, rim, _mat("rim", Color(0.4, 0.27, 0.18), 0.6, 0.6))
			var sh := CylinderShape3D.new()
			sh.radius = 0.33
			sh.height = 0.24
			cs.shape = sh
		"cone":
			b.mass = 2.5
			pm.bounce = 0.2
			pm.friction = 0.7
			var orange := _mat("cone", Color(0.95, 0.35, 0.06), 0.55)
			var white := _mat("cone_band", Color(0.92, 0.92, 0.88), 0.3, 0.0, 0.25)
			_mi(b, _box(Vector3(0.38, 0.04, 0.38)), orange, Vector3(0, -0.35, 0))
			var c := CylinderMesh.new()
			c.top_radius = 0.025
			c.bottom_radius = 0.14
			c.height = 0.68
			c.radial_segments = 14
			_mi(b, c, orange, Vector3(0, 0.0, 0))
			for band in [[0.06, 0.098, 0.088], [-0.14, 0.12, 0.112]]:
				var w := CylinderMesh.new()
				w.top_radius = float(band[2]) + 0.003
				w.bottom_radius = float(band[1]) + 0.003
				w.height = 0.09
				w.radial_segments = 14
				_mi(b, w, white, Vector3(0, float(band[0]), 0))
			var sh := ConvexPolygonShape3D.new()
			var pts := PackedVector3Array()
			for k in 8:
				var a := k * TAU / 8.0
				pts.append(Vector3(cos(a) * 0.19, -0.37, sin(a) * 0.19))
				pts.append(Vector3(cos(a) * 0.03, 0.33, sin(a) * 0.03))
			sh.points = pts
			cs.shape = sh
		"bucket":
			b.mass = 1.5
			pm.bounce = 0.3
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.12
			c.height = 0.32
			c.radial_segments = 14
			var col: Color = [Color(0.5, 0.52, 0.5), Color(0.6, 0.3, 0.2), Color(0.25, 0.35, 0.5)][rng.randi() % 3]
			_mi(b, c, _mat("bucket" + col.to_html(), col, 0.5, 0.5))
			var hnd := TorusMesh.new()
			hnd.inner_radius = 0.15
			hnd.outer_radius = 0.16
			hnd.rings = 12
			hnd.ring_segments = 4
			_mi(b, hnd, _mat("wire", Color(0.3, 0.3, 0.3), 0.5, 0.7), Vector3(0, 0.16, 0), Vector3(PI * 0.5, 0, 0))
			var sh := CylinderShape3D.new()
			sh.radius = 0.15
			sh.height = 0.32
			cs.shape = sh
		"can":
			b.mass = 0.4
			pm.bounce = 0.45
			var c := CylinderMesh.new()
			c.top_radius = 0.05
			c.bottom_radius = 0.05
			c.height = 0.13
			c.radial_segments = 10
			var col: Color = [Color(0.6, 0.15, 0.12), Color(0.7, 0.62, 0.2), Color(0.3, 0.45, 0.3), Color(0.55, 0.55, 0.55)][rng.randi() % 4]
			_mi(b, c, _mat("can" + col.to_html(), col, 0.4, 0.7))
			var sh := CylinderShape3D.new()
			sh.radius = 0.05
			sh.height = 0.13
			cs.shape = sh
		"crate":
			b.mass = 7.0
			pm.friction = 0.8
			var wood := _mat("crate", Color(0.5, 0.38, 0.24), 0.9)
			var dark := _mat("crate_dk", Color(0.3, 0.22, 0.14), 0.9)
			_mi(b, _box(Vector3(0.55, 0.55, 0.55)), wood)
			for e in [Vector3(0.28, 0, 0.28), Vector3(-0.28, 0, 0.28), Vector3(0.28, 0, -0.28), Vector3(-0.28, 0, -0.28)]:
				_mi(b, _box(Vector3(0.05, 0.57, 0.05)), dark, e)
			for f in [0.28, -0.28]:
				_mi(b, _box(Vector3(0.57, 0.06, 0.02)), dark, Vector3(0, 0, f), Vector3(0, 0, 0.75))
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.56, 0.56, 0.56)
			cs.shape = sh
		"fuelcan":
			b.mass = 3.0
			var red := _mat("fuel", Color(0.55, 0.08, 0.06), 0.45, 0.5)
			_mi(b, _box(Vector3(0.3, 0.38, 0.14)), red)
			_mi(b, _box(Vector3(0.18, 0.04, 0.05)), _mat("wire", Color(0.3, 0.3, 0.3), 0.5, 0.7), Vector3(-0.03, 0.21, 0))
			var sp := CylinderMesh.new()
			sp.top_radius = 0.025
			sp.bottom_radius = 0.03
			sp.height = 0.08
			_mi(b, sp, red, Vector3(0.11, 0.21, 0), Vector3(0, 0, -0.5))
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.3, 0.4, 0.14)
			cs.shape = sh
	b.physics_material_override = pm
	b.add_child(cs)
	b.linear_damp = 0.15
	b.angular_damp = 0.4
	b.body_entered.connect(func(_o): _clunk(b))
	b.contact_monitor = true
	b.max_contacts_reported = 1
	return b

static func _box(s: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = s
	return bm

func _clunk(b: RigidBody3D) -> void:
	if not is_instance_valid(b):
		return
	var v := b.linear_velocity.length()
	if v < 1.5 or b.get_meta("clunk_t", 0.0) > Time.get_ticks_msec() * 0.001:
		return
	b.set_meta("clunk_t", Time.get_ticks_msec() * 0.001 + 0.25)
	var k := String(b.get_meta("kind", ""))
	var snd := "x_metall0" if k in ["can", "bucket", "fuelcan"] else ("x_rock0" if k == "crate" else "p_thud1")
	Sfx.play_at(snd, b.global_position, clampf(-14.0 + v * 1.5, -14.0, -2.0), randf_range(0.8, 1.15))

# ---------------------------------------------------------------- pushes from the world
# a bullet: a shove at the point it hit, along the shot
static func shot(c: Object, at: Vector3, dir: Vector3, force := 1.0) -> bool:
	if not (c is RigidBody3D) or not (c as RigidBody3D).is_in_group("havoc"):
		return false
	var b := c as RigidBody3D
	b.sleeping = false
	# enough to see: a can leaps away, a cone goes over and skids, a tyre lurches and rolls
	var j := (2.5 + b.mass * 0.55) * force
	b.apply_impulse(dir.normalized() * j + Vector3.UP * j * 0.35, at - b.global_position)
	return true

# a blast: everything in reach thrown outward and up, harder the closer it was
static func blast(at: Vector3, r: float, force := 1.0) -> void:
	if inst == null or not is_instance_valid(inst):
		return
	for b in inst.get_tree().get_nodes_in_group("havoc"):
		var rb := b as RigidBody3D
		var dv := rb.global_position - at
		var dd := dv.length()
		if dd > r * 1.4:
			continue
		var k := (1.0 - dd / (r * 1.4)) * force
		rb.sleeping = false
		rb.apply_impulse((dv.normalized() + Vector3.UP * 0.9) * rb.mass * 9.0 * k, Vector3(randf_range(-0.1, 0.1), 0.1, randf_range(-0.1, 0.1)))

# a body walking (or driving) into one: it's shoved along the way it was going
static func bump(c: Object, push: Vector3) -> void:
	if not (c is RigidBody3D) or not (c as RigidBody3D).is_in_group("havoc"):
		return
	var b := c as RigidBody3D
	b.sleeping = false
	b.apply_central_impulse(push * minf(b.mass, 6.0) * 0.35 + Vector3.UP * 0.4)
