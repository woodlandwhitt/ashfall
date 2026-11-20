# First-person player: a capsule moved by Godot's physics (Jolt), camera at eye height, a pistol on the camera.
# Movement comes from WASD or the on-screen stick; looking from the mouse or a drag on the right of the screen.
extends CharacterBody3D

const WALK := 4.4
const RUN := 7.2
const JUMP_V := 4.8
const GRAV := 14.0
const EYE := 1.62

var yaw := 0.0
var pitch := 0.0
var cam: Camera3D
var gun: Node3D
var flash: OmniLight3D
var flash_q: MeshInstance3D
var running := false
var step_d := 0.0
var step_lr := 0
var fire_cd := 0.0
var reload_t := 0.0
var recoil := 0.0
var bob := 0.0
var hurt_shake := 0.0
var trigger := false

func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(48.0)
	collision_layer = 1
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.76
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 75.0
	cam.near = 0.06
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	# the pistol (same CC0 model and fit as the WebView build)
	gun = Node3D.new()
	cam.add_child(gun)
	var ps: PackedScene = load("res://guns/Pistol_4.glb")
	var m := ps.instantiate() as Node3D
	m.scale = Vector3.ONE * 0.121
	m.rotation.y = PI / 2.0
	gun.add_child(m)
	gun.position = Vector3(0.19, -0.19, -0.4)
	_make_arms(m)
	_no_shadow(gun)
	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.omni_range = 7.0
	flash.light_energy = 0.0
	flash.position = Vector3(0.0, 0.05, -0.3)
	gun.add_child(flash)
	flash_q = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	flash_q.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.45)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_q.material_override = fm
	flash_q.position = Vector3(0.0, 0.04, -0.28)
	flash_q.visible = false
	gun.add_child(flash_q)

# First-person arms: vault-suit sleeves, bare forearms and hands, built from capsules around the pistol's grip.
# The grip is found from the gun model's bounds (the handle is the low, rear part of a pistol).
func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	var len := a.distance_to(b)
	cm.radius = r
	cm.height = len + r * 2.0
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, c: Vector3, size: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = c
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _make_arms(model: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for c in model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := gun.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else model.transform * mi.transform
		var bb: AABB = xf * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var lo := aabb.position
	var hi := aabb.end
	var cx := (lo.x + hi.x) * 0.5
	var h := hi.y - lo.y
	var ln := hi.z - lo.z
	var grip := Vector3(cx, lo.y + h * 0.42, hi.z - ln * 0.2)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.58, 0.45)
	skin.roughness = 0.75
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.22, 0.16, 0.11)
	glove.roughness = 0.85
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.17, 0.27, 0.5)
	sleeve.roughness = 0.9
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = Color(0.85, 0.68, 0.2)
	cuff.roughness = 0.8
	var arms := Node3D.new()
	arms.name = "Arms"
	gun.add_child(arms)
	var k := clampf(ln / 0.2, 0.6, 1.4)   # hand size relative to the gun
	# right hand: palm on the right of the grip, four fingers wrapped round its front, thumb up the left side
	_box(arms, grip + Vector3(0.022, -0.004, 0.004) * k, Vector3(0.022, 0.085, 0.07) * k, Vector3(0.1, 0, 0), glove)
	for f in 4:
		var fy := grip.y + (0.026 - f * 0.019) * k
		_limb(arms, Vector3(grip.x + 0.03 * k, fy, grip.z - 0.03 * k), Vector3(grip.x - 0.022 * k, fy - 0.004, grip.z - 0.026 * k), 0.0095 * k, glove)
	_limb(arms, grip + Vector3(-0.022, 0.03, 0.02) * k, grip + Vector3(-0.024, 0.042, -0.035) * k, 0.011 * k, glove)
	# left hand: wraps over the right fingers from the left, palm under the grip
	_box(arms, grip + Vector3(-0.03, -0.03, -0.005) * k, Vector3(0.024, 0.07, 0.075) * k, Vector3(0.15, 0, -0.35), glove)
	for f in 4:
		var fy := grip.y + (0.012 - f * 0.018) * k
		_limb(arms, Vector3(grip.x - 0.04 * k, fy - 0.01 * k, grip.z - 0.045 * k), Vector3(grip.x + 0.03 * k, fy, grip.z - 0.05 * k), 0.0095 * k, glove)
	# forearms run down and back out of the bottom corners of the screen, into vault-suit sleeves
	var rw := grip + Vector3(0.02, -0.05, 0.035) * k
	var rdir := Vector3(0.22, -0.55, 0.8).normalized()
	_limb(arms, rw, rw + rdir * 0.12, 0.028 * k, glove)
	_limb(arms, rw + rdir * 0.12, rw + rdir * 0.135, 0.036 * k, cuff)
	_limb(arms, rw + rdir * 0.135, rw + rdir * 0.5, 0.042 * k, sleeve)
	var lw := grip + Vector3(-0.035, -0.06, 0.03) * k
	var ldir := Vector3(-0.42, -0.5, 0.75).normalized()
	_limb(arms, lw, lw + ldir * 0.12, 0.028 * k, glove)
	_limb(arms, lw + ldir * 0.12, lw + ldir * 0.135, 0.036 * k, cuff)
	_limb(arms, lw + ldir * 0.135, lw + ldir * 0.5, 0.042 * k, sleeve)

func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)

func look(dx: float, dy: float) -> void:
	yaw -= dx
	pitch = clampf(pitch - dy, -1.45, 1.45)

func _unhandled_input(e: InputEvent) -> void:
	if Game.paused or Game.main.in_dialog():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.relative.x * 0.0026, e.relative.y * 0.0026)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_E: Game.main.interact()
			KEY_R: reload()
			KEY_SHIFT: running = not running
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(d: float) -> void:
	if Game.hp <= 0 or Game.paused:
		velocity = Vector3.ZERO
		return
	var talking: bool = Game.main.in_dialog()
	var iv := Game.touch_move
	if not talking:
		if Input.is_key_pressed(KEY_W): iv.y -= 1
		if Input.is_key_pressed(KEY_S): iv.y += 1
		if Input.is_key_pressed(KEY_A): iv.x -= 1
		if Input.is_key_pressed(KEY_D): iv.x += 1
	else:
		iv = Vector2.ZERO
	if iv.length() > 1.0:
		iv = iv.normalized()
	var spd := RUN if (running or Input.is_key_pressed(KEY_SHIFT)) and iv.y < 0 else WALK
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var want := (right * iv.x - fwd * iv.y) * spd
	var k := 1.0 - exp(-(10.0 if is_on_floor() else 2.0) * d)
	velocity.x = lerpf(velocity.x, want.x, k)
	velocity.z = lerpf(velocity.z, want.z, k)
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE) and not talking:
			jump()
	else:
		velocity.y -= GRAV * d
	move_and_slide()
	# never fall through the world
	var gh := Game.height(global_position.x, global_position.z)
	if global_position.y < gh - 2.0:
		global_position.y = gh + 0.2
		velocity.y = 0
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 0.5:
		step_d += hs * d
		bob += hs * d * 1.9
		if step_d > (1.9 if spd > WALK else 1.45):
			step_d = 0.0
			step_lr = 1 - step_lr
			Sfx.play(["step_sandl1", "step_sandl2", "step_sandr1", "step_sandr2"][step_lr * 2 + randi() % 2], -9.0, randf_range(0.92, 1.08))
	if trigger and not talking:
		fire()

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_V

func _process(d: float) -> void:
	fire_cd = maxf(0.0, fire_cd - d)
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-12.0 * d))
	hurt_shake = maxf(0.0, hurt_shake - d * 2.0)
	var sh := Vector2(randf() - 0.5, randf() - 0.5) * hurt_shake * 0.03
	cam.rotation = Vector3(pitch + recoil * 0.06 + sh.y, 0, sh.x)
	rotation.y = yaw
	cam.position.y = EYE + sin(bob * 2.0) * 0.025
	var hs := Vector2(velocity.x, velocity.z).length()
	var target := Vector3(0.19 + sin(bob) * 0.008 * hs * 0.2, -0.19 + absf(cos(bob)) * 0.006 * hs * 0.2, -0.4 + recoil * 0.06)
	if reload_t > 0.0:
		reload_t -= d
		target += Vector3(0, -0.12 * sin(clampf(reload_t / 1.3, 0.0, 1.0) * PI), 0)
		if reload_t <= 0.0:
			var n := mini(Game.mag_size - Game.mag, Game.reserve)
			Game.mag += n
			Game.reserve -= n
			Game.stats_changed.emit()
	gun.position = gun.position.lerp(target, 1.0 - exp(-20.0 * d))
	gun.rotation.x = recoil * 0.35
	if flash.light_energy > 0.0:
		flash.light_energy = maxf(0.0, flash.light_energy - d * 60.0)
		flash_q.visible = flash.light_energy > 0.5

func reload() -> void:
	if reload_t > 0.0 or Game.mag >= Game.mag_size or Game.reserve <= 0:
		return
	reload_t = 1.3
	Sfx.play("k_draw", -4.0)

func fire() -> void:
	if fire_cd > 0.0 or reload_t > 0.0 or Game.hp <= 0:
		return
	if Game.mag <= 0:
		fire_cd = 0.3
		Sfx.play("k_click", -6.0)
		reload()
		return
	Game.mag -= 1
	Game.stats_changed.emit()
	fire_cd = 0.28
	recoil = 1.0
	flash.light_energy = 6.0
	flash_q.visible = true
	flash_q.rotation.z = randf() * TAU
	Sfx.play("pistol", -3.0, randf_range(0.95, 1.05))
	var spread := Vector2(randf() - 0.5, randf() - 0.5) * 0.012
	var from := cam.global_position
	var dir := (-cam.global_transform.basis.z + cam.global_transform.basis.x * spread.x + cam.global_transform.basis.y * spread.y).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 160.0, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var c: Object = hit.collider
		if c and c.has_method("hit"):
			c.hit(randf_range(16.0, 24.0), hit.position, dir)
		else:
			Game.main.impact(hit.position, hit.normal)
	if Game.mag == 0:
		reload()

func hurt_fx(d: float) -> void:
	hurt_shake = minf(1.0, hurt_shake + d * 0.05)
