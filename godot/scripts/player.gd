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
var vm: Viewmodel
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
	# the player's own arms holding the equipped weapon (Quaternius CC0 body and animations), swaying with movement
	gun = Node3D.new()
	cam.add_child(gun)
	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.omni_range = 7.0
	flash.light_energy = 0.0
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
	flash_q.visible = false
	weapon_changed()

# which model a weapon uses: its own, or the closest Quaternius gun for its kind
const KIND_MODEL := {"pistol": "Pistol_Compact_West", "smg": "SMG_Compact_West", "rifle": "Rifle_Battle_West",
	"shotgun": "Shotgun_Pump_West", "energy": "AssaultRifle2_2"}
static func model_for(id: String) -> Array:
	var it := Game.item(id)
	var glb: String = it.get("glb", KIND_MODEL.get(String(it.get("kind", "")), ""))
	if glb == "":
		return []
	var f: Dictionary = Game.DB.gunfit.get(glb, {})
	var fit := Basis.IDENTITY
	if f.has("k"):
		fit = Basis(Vector3.UP, float(f.get("ry", 0.0))).scaled(Vector3.ONE * float(f.k))
	return ["res://guns/" + glb + ".glb", fit]

func weapon_changed() -> void:
	if vm:
		if flash.get_parent():
			flash.get_parent().remove_child(flash)
		if flash_q.get_parent():
			flash_q.get_parent().remove_child(flash_q)
		vm.queue_free()
	reload_t = 0.0
	vm = Viewmodel.new()
	gun.add_child(vm)
	var mdl := model_for(Game.weapon)
	var it := Game.item(Game.weapon)
	if mdl.is_empty():
		vm.setup_melee(String(it.get("kind", "")) == "melee", Game.weapon)
	else:
		vm.setup(load(mdl[0]), mdl[1])
	vm.muzzle.add_child(flash)
	vm.muzzle.add_child(flash_q)
	if it.get("energy") or String(it.get("kind", "")) == "energy":
		flash.light_color = Color(0.4, 0.8, 1.0)
	else:
		flash.light_color = Color(1.0, 0.75, 0.4)

func reload_time() -> float:
	return (1.5 - (int(Game.stats.agility) - 5) * 0.07) * (0.6 if Game.perks.has("quick_hands") else 1.0)

# damage as in the original: aim (or might for melee) and perks scale the weapon's base damage
func weapon_damage() -> float:
	var it := Game.item(Game.weapon)
	var d := float(it.get("dmg", 8)) * (1.0 + 0.12 * int(Game.upgrades.get(Game.weapon, 0)))
	if String(it.get("kind", "")) == "melee":
		d *= (1.0 + (int(Game.stats.might) - 5) * 0.07) * (1.35 if Game.perks.has("brawler") else 1.0)
	else:
		d *= (1.0 + (int(Game.stats.aim) - 5) * 0.05) * (1.15 if Game.perks.has("gunner") else 1.0)
	return d

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
			KEY_G: throw_nade()
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
	var target := Vector3(sin(bob) * 0.008 * hs * 0.2, absf(cos(bob)) * 0.006 * hs * 0.2, recoil * 0.025)
	if reload_t > 0.0:
		reload_t -= d
		if reload_t <= 0.0:
			var n := mini(Game.mag_size - Game.mag, Game.reserve)
			Game.mag += n
			Game.reserve = Game.reserve - n
			Game.stats_changed.emit()
	gun.position = gun.position.lerp(target, 1.0 - exp(-20.0 * d))
	gun.rotation.x = recoil * 0.06
	if flash.light_energy > 0.0:
		flash.light_energy = maxf(0.0, flash.light_energy - d * 60.0)
		flash_q.visible = flash.light_energy > 0.5

func reload() -> void:
	if reload_t > 0.0 or Game.mag_size <= 0 or Game.mag >= Game.mag_size:
		return
	if Game.reserve <= 0:
		Game.msg("Out of " + Game.iname(Game.item(Game.weapon).get("ammo")))
		return
	reload_t = reload_time()
	vm.reload(reload_t)
	Sfx.play("k_draw", -4.0)

const SND := {"energy": "carbine"}
func fire() -> void:
	if fire_cd > 0.0 or reload_t > 0.0 or Game.hp <= 0:
		return
	var it := Game.item(Game.weapon)
	var kind := String(it.get("kind", "pistol"))
	var cd := float(it.get("rof", 0.3))
	if kind == "melee":
		fire_cd = cd
		vm.shoot()
		Sfx.play("k_slice", -2.0, randf_range(0.9, 1.1))
		_ray(weapon_damage(), float(it.get("range", 2.6)), 0.0, false)
		return
	if Game.mag <= 0:
		fire_cd = 0.3
		Sfx.play("k_click", -6.0)
		reload()
		return
	Game.mag -= 1
	Game.stats_changed.emit()
	fire_cd = cd
	recoil = clampf(float(it.get("dmg", 15)) / 25.0, 0.6, 2.0)
	vm.shoot()
	flash.light_energy = 6.0
	flash_q.visible = true
	flash_q.rotation.z = randf() * TAU
	var snd: String = it.get("snd", SND.get(kind, "pistol"))
	Sfx.play(snd, -3.0, randf_range(0.95, 1.05) * (1.4 if kind == "energy" else 1.0))
	var pel := int(it.get("pellets", 1))
	var dmg := weapon_damage() * (0.75 if pel > 1 else 1.0)
	var moving := 1.5 if Vector2(velocity.x, velocity.z).length() > 1.0 else 1.0
	for i in pel:
		_ray(dmg, float(it.get("range", 100)), float(it.get("spread", 0.02)) * moving, kind == "energy")
	if Game.mag == 0:
		reload()

func _ray(dmg: float, rng: float, spread: float, energy: bool) -> void:
	var sp := Vector2(randf() - 0.5, randf() - 0.5) * spread * 2.0
	var from := cam.global_position
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * sp.x + b.y * sp.y).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * rng, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if energy:
		Game.main.tracer(vm.muzzle_pos(), hit.position if hit else from + dir * rng, Color(0.4, 0.85, 1.0))
	if hit:
		var c: Object = hit.collider
		var crit := randf() < 0.03 + (int(Game.stats.luck) - 5) * 0.01
		if c and c.has_method("hit"):
			c.hit(dmg * randf_range(0.9, 1.1) * (2.0 if crit else 1.0), hit.position, dir)
		else:
			Game.main.impact(hit.position, hit.normal)

func hurt_fx(d: float) -> void:
	hurt_shake = minf(1.0, hurt_shake + d * 0.05)

func throw_nade() -> void:
	var k := Game.nade_kind()
	if k == "":
		Game.msg("Nothing to throw")
		return
	Game.take(k)
	var dir := -cam.global_basis.z
	Nade.throw_from(cam.global_position + dir * 0.6 - Vector3.UP * 0.1, dir, k)
	Game.stats_changed.emit()
