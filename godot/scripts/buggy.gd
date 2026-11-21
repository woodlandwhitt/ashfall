# The Rust Runner (main.js car*, entities.js makeBuggy): Brannock's dune buggy behind the shop in Dustwell. Wrecked
# until the Rust Runner quest fixes it; then the key starts it. Arcade handling (faster on the road, slides on the
# sand, stalls on slopes too steep), a chase camera, crashes hurt, it runs over what it hits. Parked spot is saved.
class_name Buggy
extends Node3D

var main
var body: Node3D
var wheels: Array = []
var cam: Camera3D
var driving := false
var h := PI
var v := 0.0
var steer := 0.0
var spin := 0.0
var pitch := 0.0
var roll := 0.0
var cam_yaw := 0.0
var eng_lo: AudioStreamPlayer
var eng_hi: AudioStreamPlayer
var col: StaticBody3D

func setup(m) -> void:
	main = m
	_build()
	var b = Game.flags.get("buggy")
	var D: Dictionary = Game.DB.locs.dustwell
	var x := float(D.x) + 27.5
	var z := float(D.z) - 11.5
	h = PI
	if b is Dictionary and b.has("x"):
		x = float(b.x)
		z = float(b.z)
		h = float(b.get("h", PI))
	global_position = Vector3(x, Game.height(x, z), z)
	_sync(0.0, true)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	m.add_child(cam)

func fixed() -> bool:
	return Game.flags.get("buggy") is Dictionary and Game.flags.buggy.get("fixed", false)

func _mat(c: Color, metal := 0.5, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _box(p: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)

func _cyl(p: Node3D, r: float, len: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 12) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = len
	c.radial_segments = seg
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)

func _build() -> void:
	body = Node3D.new()
	add_child(body)
	var paint := _mat(Color(0.69, 0.35, 0.12) * (1.0 if fixed() else 0.62), 0.5, 0.42)
	var dark := _mat(Color(0.16, 0.16, 0.17), 0.6, 0.55)
	var tube := _mat(Color(0.2, 0.21, 0.23), 0.85, 0.32)
	var seat := _mat(Color(0.35, 0.23, 0.13), 0.0, 0.8)
	var chrome := _mat(Color(0.82, 0.82, 0.82), 1.0, 0.18)
	var rust := _mat(Color(0.42, 0.23, 0.12), 0.2, 0.9)
	_box(body, Vector3(1.46, 0.16, 2.9), dark, Vector3(0, 0.52, 0))
	_box(body, Vector3(1.32, 0.34, 1.05), paint, Vector3(0, 0.76, 1.02))
	_box(body, Vector3(1.2, 0.12, 0.5), paint, Vector3(0, 0.95, 0.72), Vector3(-0.35, 0, 0))
	_box(body, Vector3(1.5, 0.3, 0.75), paint, Vector3(0, 0.74, -1.1))
	_box(body, Vector3(0.78, 0.46, 0.62), dark, Vector3(0, 1.08, -1.12))
	_box(body, Vector3(0.5, 0.1, 0.5), chrome, Vector3(0, 1.36, -1.12))
	for x in [-0.22, 0.22]:
		_cyl(body, 0.065, 0.7, chrome, Vector3(x, 1.18, -1.55), Vector3(1.25, 0, 0), 8)
	for x in [-0.36, 0.36]:
		_box(body, Vector3(0.5, 0.14, 0.55), seat, Vector3(x, 0.68, -0.25))
		_box(body, Vector3(0.5, 0.62, 0.12), seat, Vector3(x, 1.0, -0.56), Vector3(-0.18, 0, 0))
	_cyl(body, 0.04, 0.5, dark, Vector3(-0.36, 1.0, 0.3), Vector3(0.9, 0, 0), 6)
	for p in [[-0.68, 0.48], [0.68, 0.48], [-0.68, -0.78], [0.68, -0.78]]:
		_cyl(body, 0.045, 1.25, tube, Vector3(p[0], 1.22, p[1]), Vector3.ZERO, 6)
	for z in [0.48, -0.78]:
		_cyl(body, 0.045, 1.36, tube, Vector3(0, 1.84, z), Vector3(0, 0, PI / 2), 6)
	for x in [-0.68, 0.68]:
		_cyl(body, 0.045, 1.26, tube, Vector3(x, 1.84, -0.15), Vector3(PI / 2, 0, 0), 6)
	_box(body, Vector3(1.62, 0.14, 0.14), tube, Vector3(0, 0.62, 1.62))
	_box(body, Vector3(1.2, 0.4, 0.06), tube, Vector3(0, 0.8, 1.66))
	for x in [-0.82, 0.82]:
		for z in [1.0, -1.0]:
			_box(body, Vector3(0.34, 0.06, 0.95), paint if z > 0 else rust, Vector3(x, 1.0, z))
	_cyl(body, 0.3, 0.25, dark, Vector3(0, 1.02, -1.62), Vector3(PI / 2, 0, 0))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.95, 0.78)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.9, 0.7)
	for x in [-0.5, 0.5]:
		_cyl(body, 0.1, 0.06, lamp, Vector3(x, 0.86, 1.6), Vector3(PI / 2, 0, 0))
	var tyre := _mat(Color(0.11, 0.11, 0.11), 0.0, 0.95)
	var hub := _mat(Color(0.6, 0.6, 0.6), 0.85, 0.3)
	for p in [[-0.86, 1.02], [0.86, 1.02], [-0.86, -1.02], [0.86, -1.02]]:
		var piv := Node3D.new()
		piv.position = Vector3(p[0], 0.44, p[1])
		body.add_child(piv)
		var w := Node3D.new()
		piv.add_child(w)
		_cyl(w, 0.44, 0.32, tyre, Vector3.ZERO, Vector3(0, 0, PI / 2), 20)
		_cyl(w, 0.22, 0.34, hub, Vector3.ZERO, Vector3(0, 0, PI / 2), 10)
		wheels.append({"piv": piv, "w": w, "front": p[1] > 0})
	# you can't walk through it
	col = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.6, 1.4, 3.0)
	cs.shape = bx
	cs.position.y = 0.8
	col.add_child(cs)
	col.collision_layer = 1
	body.add_child(col)

# ground under the four wheels: height, pitch and roll
func _ground() -> Array:
	var s := sin(h)
	var c := cos(h)
	var x := global_position.x
	var z := global_position.z
	var pts := []
	for p in [[-0.86, 1.02], [0.86, 1.02], [-0.86, -1.02], [0.86, -1.02]]:
		pts.append(Game.height(x + p[0] * c + p[1] * s, z - p[0] * s + p[1] * c))
	var f: float = (pts[0] + pts[1]) / 2.0
	var r: float = (pts[2] + pts[3]) / 2.0
	var l: float = (pts[0] + pts[2]) / 2.0
	var ri: float = (pts[1] + pts[3]) / 2.0
	return [(f + r) / 2.0, atan2(f - r, 2.04), atan2(l - ri, 1.72)]

func _sync(dt: float, snap := false) -> void:
	var g := _ground()
	var k := 1.0 if snap else minf(1.0, dt * 10.0)
	var p := global_position
	p.y = lerpf(p.y, float(g[0]), 1.0 if snap else minf(1.0, dt * 14.0))
	global_position = p
	pitch = lerpf(pitch, float(g[1]), k)
	roll = lerpf(roll, float(g[2]), k)
	body.position.y = 0.0 if fixed() else -0.16
	basis = Basis(Vector3.UP, h) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, roll + (0.0 if fixed() else 0.05))
	spin += v * dt / 0.44
	for w in wheels:
		w.w.rotation.x = spin
		if w.front:
			w.piv.rotation.y = steer * 0.45

func label() -> String:
	if not fixed():
		return "Look at the wrecked buggy"
	return "Drive the Rust Runner" if Game.has("buggy_key") else "Locked. Brannock has the key"

func use() -> void:
	if fixed() and Game.has("buggy_key"):
		enter()
	else:
		Game.msg("Brannock still has the key." if fixed() else "A dune buggy with no engine, two flat tyres and a family of lizards in the seat. Brannock might know more.")
		Sfx.play("k_click", -8.0)

func enter() -> void:
	if driving:
		return
	driving = true
	v = 0.0
	cam_yaw = 0.0
	col.collision_layer = 0
	main.player.visible = false
	main.player.collision_layer = 0
	main.player.collision_mask = 0
	main.player.vm.visible = false
	cam.global_position = global_position - Vector3(sin(h), -2.5, cos(h)) * 6.0
	cam.current = true
	Sfx.play("o_cardoor_open")
	Sfx.play("o_carstart", -2.0)
	eng_lo = Sfx.loop("o_engine_lo", -10.0)
	eng_hi = Sfx.loop("o_engine_hi", -40.0)
	Game.msg("Engine coughs into life. Drive with the stick or WASD. USE to get out.")

func exit() -> void:
	if not driving:
		return
	var s := sin(h)
	var c := cos(h)
	var spot = null
	var space := get_world_3d().direct_space_state
	for side in [1.0, -1.0, 0.0]:
		var ox: float = side * 1.9 if side != 0.0 else 0.0
		var oz: float = 0.0 if side != 0.0 else -2.8
		var x := global_position.x + ox * c + oz * s
		var z := global_position.z - ox * s + oz * c
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.45
		q.shape = sh
		q.transform = Transform3D(Basis(), Vector3(x, Game.height(x, z) + 1.0, z))
		q.collision_mask = 1
		q.exclude = [col.get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			spot = Vector3(x, Game.height(x, z) + 0.2, z)
			break
	if spot == null:
		Game.msg("No room to get out here.")
		Sfx.play("k_metal_click", -6.0)
		return
	driving = false
	v = 0.0
	col.collision_layer = 1
	var P = main.player
	P.global_position = spot
	P.velocity = Vector3.ZERO
	P.yaw = h + PI
	P.pitch = 0.0
	P.visible = true
	P.collision_layer = 1
	P.collision_mask = 1
	P.vm.visible = true
	P.cam.current = true
	Game.flags["buggy"] = {"fixed": fixed(), "x": global_position.x, "z": global_position.z, "h": h}
	for e in [eng_lo, eng_hi]:
		if e:
			e.queue_free()
	eng_lo = null
	eng_hi = null
	Sfx.play("o_cardoor_close")

func _exit_tree() -> void:
	for e in [eng_lo, eng_hi]:
		if is_instance_valid(e):
			e.queue_free()

# input: x = steer (right +), y = throttle (forward -)
func drive(dt: float, iv: Vector2) -> void:
	var thr := -iv.y
	var st := iv.x
	var on_road := false
	var max := 24.0
	steer = lerpf(steer, st, minf(1.0, dt * 6.0))
	if thr > 0.05:
		v += (22.0 if v < -0.5 else 13.0) * thr * dt
	elif thr < -0.05:
		v += (26.0 if v > 0.5 else 8.0) * thr * dt
	else:
		v -= signf(v) * minf(absf(v), 3.0 * dt)
	v -= sin(pitch) * 9.8 * dt * 0.8
	v = clampf(v, -8.0, max + maxf(0.0, -pitch * 8.0))
	var turn := steer * 1.9 * clampf(v / 5.0, -1.0, 1.0) * (1.0 - 0.45 * minf(1.0, absf(v) / 27.0))
	h -= turn * dt
	var s := sin(h)
	var c := cos(h)
	var from := global_position
	var to := from + Vector3(s, 0, c) * v * dt
	# walls and buildings stop you (a shape sweep at bumper height)
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.1
	q.shape = sh
	q.transform = Transform3D(Basis(), from + Vector3.UP * 1.0)
	q.motion = to - from
	q.collision_mask = 1
	q.exclude = [col.get_rid(), main.player.get_rid()]
	var frac := space.cast_motion(q)
	if frac.size() and frac[0] < 1.0:
		var imp := absf(v)
		if imp > 9.0:
			Sfx.play("x_metall0", 2.0)
			Game.player.hurt_shake = minf(1.2, imp * 0.05)
			Game.hurt((imp - 9.0) * 2.2)
		v *= -0.25
		to = from + (to - from) * maxf(0.0, frac[0] - 0.05)
	to.x = clampf(to.x, -480.0, 480.0)
	to.z = clampf(to.z, -480.0, 480.0)
	var ng := Game.height(to.x, to.z)
	if ng - from.y > absf(v) * dt * 1.4 + 0.35:
		v *= 0.4
		to = from
	global_position = Vector3(to.x, from.y, to.z)
	_sync(dt)
	# run-over: enemies take damage and get thrown aside
	var sp := absf(v)
	if sp > 5.0:
		for e in main.enemies:
			if e.dead:
				continue
			var dx: float = e.global_position.x - global_position.x
			var dz: float = e.global_position.z - global_position.z
			if dx * dx + dz * dz > 3.4:
				continue
			if float(e.get_meta("car_t", 0.0)) > Time.get_ticks_msec() / 1000.0:
				continue
			e.set_meta("car_t", Time.get_ticks_msec() / 1000.0 + 0.8)
			e.hit(sp * 4.5, e.global_position + Vector3.UP, Vector3(dx, 0.3, dz).normalized())
			v *= 0.82
	var P = main.player
	P.global_position = global_position + Vector3.UP * 0.3
	P.velocity = Vector3.ZERO
	P.yaw = h + PI
	if eng_lo:
		eng_lo.pitch_scale = 0.8 + sp / 27.0 * 0.9
		eng_lo.volume_db = -10.0 + sp * 0.2
	if eng_hi:
		eng_hi.pitch_scale = 0.9 + sp / 27.0 * 0.6
		eng_hi.volume_db = -30.0 + sp * 0.9
	if randf() < dt * 0.5:
		Game.flags["buggy"] = {"fixed": fixed(), "x": global_position.x, "z": global_position.z, "h": h}
	_camera(dt)

func _camera(dt: float) -> void:
	cam_yaw *= pow(0.25, dt)
	var yaw := h + cam_yaw
	var dist := 6.2 + absf(v) * 0.06
	var t := global_position - Vector3(sin(yaw), 0, cos(yaw)) * dist
	t.y = maxf(Game.height(t.x, t.z) + 1.2, global_position.y + 2.6)
	var k := minf(1.0, dt * 5.0)
	cam.global_position = cam.global_position.lerp(t, k)
	if cam.global_position.distance_to(global_position) > 20.0:
		cam.global_position = t
	cam.look_at(global_position + Vector3(sin(h), 0, cos(h)) * 3.0 + Vector3.UP * 1.2, Vector3.UP)
	cam.fov = lerpf(cam.fov, 72.0 + absf(v) * 0.25, minf(1.0, dt * 4.0))

func _physics_process(dt: float) -> void:
	if not driving:
		_sync(dt)
