# First-person player: a capsule moved by Godot's physics (Jolt), camera at eye height, a pistol on the camera.
# Movement comes from WASD or the on-screen stick; looking from the mouse or a drag on the right of the screen.
extends CharacterBody3D

const WALK := 4.4
const RUN := 7.9           # build 17 ran at 8.6 (too fast), before it 7.2: the middle of the two (build 20)
const JUMP_V := 5.9
const STEP := 0.5             # the tallest step walked up without jumping (doorsteps, porches, kerbs)
const GRAV := 14.0
const EYE := 1.62

var yaw := 0.0
var pitch := 0.0
var cam: Camera3D
var gun: Node3D
var flash: OmniLight3D
var vm: Viewmodel
var fxc: Dictionary = {"speed": 1.0, "spread": 1.0, "ap": 1.0, "fov": 1.0, "warp": 0.0}
var flash_q: MeshInstance3D
var running := false
var crouch := false          # sneaking: slower, lower, much harder to notice
var eye_h := EYE
var step_d := 0.0
var step_lr := 0
var fire_cd := 0.0
var reload_t := 0.0
var recoil := 0.0
var bob := 0.0
var hurt_shake := 0.0
var trigger := false
var tp: ThirdPerson

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
	tp = ThirdPerson.new()
	add_child(tp)
	tp.setup(self)
	tp.set_on(ThirdPerson.load_on())

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
		fit = Basis(Vector3.UP, float(f.get("ry", 0.0))).scaled(_kv(f))
	# first-person guns are drawn a little larger than life, as in the original
	fit = fit.scaled(Vector3.ONE * float(f.get("s", 1.0)))
	var gf := f.duplicate()
	gf["glb"] = glb
	if it.has("finish"):
		gf["finish"] = it.finish
	return ["res://guns/" + glb + ".glb", fit, gf]

# a model's scale: one number, or (the chunky blaster-kit guns) slimmed across and kept long
static func _kv(f: Dictionary) -> Vector3:
	if f.has("kv"):
		var v: Array = f.kv
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ONE * float(f.get("k", 1.0))

# the same model at life size, for a gun held in the world (third person, a body's hands)
static func world_model(id: String) -> Array:
	var m := model_for(id)
	if m.is_empty():
		return m
	var f: Dictionary = Game.DB.gunfit.get(String(m[2].glb), {})
	m[1] = Basis(Vector3.UP, float(f.get("ry", 0.0))).scaled(_kv(f) if f.has("k") else Vector3.ONE)
	return m

func weapon_changed() -> void:
	holstered = false
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
		vm.setup(load(mdl[0]), mdl[1], mdl[2])
	vm.muzzle.add_child(flash)
	vm.muzzle.add_child(flash_q)
	if tp and tp.on:
		gun.visible = false
	if it.get("energy") or String(it.get("kind", "")) == "energy":
		flash.light_color = Color(0.4, 0.8, 1.0)
	else:
		flash.light_color = Color(1.0, 0.75, 0.4)

func reload_time() -> float:
	return _reload_base() * float(Game.item(Game.weapon).get("reload_k", 1.0))

func _reload_base() -> float:
	return (1.5 - (int(Game.stats.agility) - 5) * 0.07) * (0.6 if Game.perks.has("quick_hands") else 1.0) * float(Game.fx().reload)

# damage as in the original: aim (or might for melee) and perks scale the weapon's base damage
func weapon_damage() -> float:
	var it := Game.item(Game.weapon)
	var d := float(it.get("dmg", 8)) * (1.0 + 0.12 * int(Game.upgrades.get(Game.weapon, 0)))
	if String(it.get("kind", "")) == "melee":
		d *= (1.0 + (int(Game.stats.might) - 5) * 0.07) * (1.35 if Game.perks.has("brawler") else 1.0) * float(Game.fx().melee)
		if Game.perks.has("nerd_rage") and Game.hp < Game.hp_max * 0.2:
			d *= 1.5
	else:
		d *= (1.0 + (int(Game.stats.aim) - 5) * 0.05) * (1.15 if Game.perks.has("gunner") else 1.0)
	if Game.perks.has("bloody_mess"):
		d *= 1.05
	return d

func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)

func look(dx: float, dy: float) -> void:
	var k := Settings.num("sens")
	yaw -= dx * k
	pitch = clampf(pitch - dy * k, -1.45, 1.45)

func _unhandled_input(e: InputEvent) -> void:
	if Game.paused or Game.main.in_dialog():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.relative.x * 0.0026, e.relative.y * 0.0026)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif Game.main.forge and Game.main.forge.active and not (e is InputEventKey and e.keycode in [KEY_F1, KEY_F2, KEY_QUOTELEFT, KEY_ESCAPE]):
		return
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_E: Game.main.interact()
			KEY_R: reload()
			KEY_H: toggle_holster()
			KEY_G: throw_nade()
			KEY_H: Game.use_chem()
			KEY_F5: toggle_view()
			KEY_V: Game.main.hud.focus.enter()
			KEY_SHIFT:
				running = not running
				if running:
					crouch = false
			KEY_C, KEY_CTRL: toggle_crouch()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F1, KEY_QUOTELEFT: Game.main.hud.toggle_dev()
			KEY_F2: Game.main.forge.toggle()

# Field of view: the setting is the height of the view, but on a wide phone screen 75 degrees tall is close to 120 across,
# which shrinks every room, chair and doorway into the distance (build 23). The view across is held to WIDE_FOV at most.
const WIDE_FOV := 100.0
func view_fov(v: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / maxf(1.0, vs.y)
	if asp <= 1.0:
		return v
	var cap := rad_to_deg(2.0 * atan(tan(deg_to_rad(WIDE_FOV * 0.5)) / asp))
	return minf(v, cap)

func _physics_process(d: float) -> void:
	if Game.hp <= 0 or Game.paused:
		velocity = Vector3.ZERO
		return
	var talking: bool = Game.main.in_dialog() or Game.main.hud.focus.exec >= 0
	# chems, buffs and radiation; action points come back over time, slower while something is hunting you
	Game.body_tick(d)
	fxc = Game.fx()
	cam.fov = lerpf(cam.fov, view_fov(Quality.fov * float(fxc.fov) + sin(Time.get_ticks_msec() * 0.0011) * 4.0 * float(fxc.warp)), minf(1.0, d * 3.0))
	if Game.dev.ap:
		Game.ap = Game.ap_max
	if Game.ap < Game.ap_max:
		Game.ap = minf(Game.ap_max, Game.ap + d * (5.0 if Game.main.in_combat() else 9.0) * float(fxc.ap) * (1.3 if Game.perks.has("action_runner") else 1.0))
	var iv := Game.touch_move
	if not seat.is_empty():
		# sitting: any move (or jump) gets you up again
		var want := iv.length() > 0.3 or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE)
		if want and not talking:
			stand_up()
		else:
			velocity = Vector3.ZERO
			return
	if not talking:
		if Input.is_key_pressed(KEY_W): iv.y -= 1
		if Input.is_key_pressed(KEY_S): iv.y += 1
		if Input.is_key_pressed(KEY_A): iv.x -= 1
		if Input.is_key_pressed(KEY_D): iv.x += 1
	else:
		iv = Vector2.ZERO
	if iv.length() > 1.0:
		iv = iv.normalized()
	if Game.main.buggy and Game.main.buggy.driving:
		Game.main.buggy.drive(d, iv)
		return
	var spd: float = (RUN if (running or Input.is_key_pressed(KEY_SHIFT)) and iv.y < 0 and not crouch else WALK) * float(fxc.speed) * float(Game.dev.speed) * float(Game.item(Game.armor).get("spd", 1.0)) * ((0.68 if Game.perks.has("light_step") else 0.5) if crouch else 1.0)
	# free flight: through walls, wherever you look (forge mode flies this way too)
	if Game.dev.noclip or (Game.main.forge and Game.main.forge.active):
		collision_mask = 0
		var cf := -cam.global_basis.z
		var cr := cam.global_basis.x
		var up := 0.0
		if not talking:
			if Input.is_key_pressed(KEY_SPACE): up += 1.0
			if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): up -= 1.0
		up += Game.touch_fly
		var fv := (cr * iv.x - cf * iv.y + Vector3.UP * up) * spd * 2.2
		velocity = velocity.lerp(fv, 1.0 - exp(-8.0 * d))
		global_position += velocity * d
		return
	collision_mask = 1
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
	var was_air := not is_on_floor()
	var fall_v := -velocity.y
	move_and_slide()
	# walking into a loose tyre or cone shoves it along (build 24)
	for i in get_slide_collision_count():
		var sc := get_slide_collision(i)
		var hv := Vector3(velocity.x, 0, velocity.z)
		if hv.length() > 0.5:
			Havoc.bump(sc.get_collider(), hv.normalized() * minf(hv.length(), 6.0) * 0.4)
	if was_air and is_on_floor():
		_landed(fall_v)
	_step_up(want)
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

# coming down (build 22): a thud for anything more than a hop, and past about four metres it hurts. Free fall from
# h metres lands at sqrt(2 g h): 11 m/s is a drop of about 4.3 m, 16 m/s about 9 m (around half your health)
const FALL_SAFE := 11.0
func _landed(v: float) -> void:
	if v > 6.5:
		Sfx.play("p_thud%d" % (1 + randi() % 3), clampf(-16.0 + (v - 6.5) * 1.6, -16.0, -2.0), randf_range(0.85, 1.0))
	if v <= FALL_SAFE or Game.dev.noclip or not seat.is_empty():
		return
	var dmg := pow(v - FALL_SAFE, 2.0) * 1.2 + (v - FALL_SAFE) * 2.0
	if Game.perks.has("light_step"):
		dmg *= 0.7
	Sfx.play("p_land1", -4.0, randf_range(0.95, 1.05))
	hurt_shake = maxf(hurt_shake, 0.6 + dmg * 0.03)
	Game.hurt(dmg)
	if Game.hp > 0.0 and dmg > 8.0:
		Game.msg("You land hard.")

# walking into a step, a doorstep or a porch edge lifts you onto it: try the same move half a metre higher, and
# if that's clear and there's floor to land on, climb by however much the floor is higher
func _step_up(want: Vector3) -> void:
	var wh := Vector2(want.x, want.z)
	if not is_on_floor() or wh.length() < 0.5:
		return
	# blocked: moving much slower than you're trying to (is_on_wall misses a low edge the capsule's round foot rides)
	if Vector2(velocity.x, velocity.z).length() > wh.length() * 0.6 and not is_on_wall():
		return
	var dir := Vector3(want.x, 0, want.z).normalized()
	var t := global_transform
	# a low step first (under a door's lintel there's no room to lift half a metre), then a tall one
	for h in [0.28, STEP]:
		if test_move(t, Vector3(0, h, 0)):
			continue
		var up := t.translated(Vector3(0, h, 0))
		if test_move(up, dir * 0.3):
			continue
		var ahead := up.translated(dir * 0.3)
		var col := KinematicCollision3D.new()
		if not test_move(ahead, Vector3(0, -h - 0.05, 0), col):
			continue
		if col.get_normal().y < 0.7:
			continue
		var climb: float = h - col.get_travel().length()
		if climb < 0.03:
			return
		global_position += Vector3(0, climb + 0.02, 0) + dir * 0.06
		velocity.y = 0.0
		return

# ---------------------------------------------------------------- sitting down (TownLife seats)
var seat: Dictionary = {}
var _seat_from := Vector3.ZERO
func sit(s: Dictionary) -> void:
	if not seat.is_empty():
		return
	seat = s
	s.who = self
	_seat_from = global_position
	collision_mask = 0
	var at: Vector3 = s.at
	global_position = Vector3(at.x, global_position.y, at.z)
	yaw = float(s.yaw) + PI
	crouch = false
	running = false
	Sfx.play("k_cloth1", -8.0)
	Game.msg("You sit down. Move to get up.")

func stand_up() -> void:
	if seat.is_empty():
		return
	var p: Vector3 = seat.p
	seat.who = null
	seat = {}
	collision_mask = 1 | 4
	global_position = Vector3(p.x, global_position.y + 0.05, p.z)
	Sfx.play("k_cloth1", -10.0)

func toggle_crouch() -> void:
	crouch = not crouch
	if crouch:
		running = false
	Sfx.play("k_cloth1", -10.0)

# how noticeable you are: sneaking and keeping still hide you; running gives you away
func visibility() -> float:
	var v := 1.0
	var hs := Vector2(velocity.x, velocity.z).length()
	if crouch:
		v = 0.32 if hs < 0.5 else 0.48
	elif hs > WALK + 0.5:
		v = 1.2
	if Game.dev.invis:
		v = 0.0
	# Ghostweed: you fade at the edges
	v *= 1.0 - 0.5 * float(fxc.get("stealth", 0.0))
	return v * (0.8 if Game.time < 0.25 or Game.time > 0.8 else 1.0)

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_V
		# the effort of it, now and then; always a rustle of clothes (build 22)
		Sfx.play(["k_cloth1", "k_cloth2"][randi() % 2], -16.0, randf_range(0.9, 1.1))
		if randf() < 0.3:
			Sfx.play("p_jump%d" % (1 + randi() % 2), -8.0, randf_range(0.95, 1.05))

func _process(d: float) -> void:
	fire_cd = maxf(0.0, fire_cd - d)
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-12.0 * d))
	hurt_shake = maxf(0.0, hurt_shake - d * 2.0)
	var sh := Vector2(randf() - 0.5, randf() - 0.5) * hurt_shake * 0.03
	cam.rotation = Vector3(pitch + recoil * 0.06 + sh.y, 0, sh.x)
	rotation.y = yaw
	eye_h = lerpf(eye_h, (float(seat.seat_h) + 0.72) if not seat.is_empty() else EYE * (0.62 if crouch else 1.0), 1.0 - exp(-10.0 * d))
	cam.position.y = eye_h + sin(bob * 2.0) * 0.025
	var hs := Vector2(velocity.x, velocity.z).length()
	var target := Vector3(sin(bob) * 0.008 * hs * 0.2, absf(cos(bob)) * 0.006 * hs * 0.2, recoil * 0.025)
	if reload_t > 0.0:
		reload_t -= d
		if reload_t <= 0.0:
			# a different type of round chosen: what's in the gun goes back in the box first
			var want := Game.ammo_id()
			if Game.mag > 0 and Game.loaded_ammo() != want and Game.count(want) > 0:
				Game.give(Game.loaded_ammo(), Game.mag)
				Game.mag = 0
			if Game.count(want) > 0 or Game.mag == 0:
				Game.magt[Game.weapon] = want
			var n := mini(Game.mag_size - Game.mag, Game.reserve)
			Game.mag += n
			Game.reserve = Game.reserve - n
			Game.stats_changed.emit()
	holster_k = move_toward(holster_k, 1.0 if holstered else 0.0, d * 4.0)
	target += Vector3(0.06, -0.5, 0.12) * holster_k
	# the arms and gun are drawn as if through the field of view the setting asks for, whatever the world's view is
	# narrowed to: grown about the eye by the ratio of the two, they cover the same part of the screen as before
	var vk := tan(deg_to_rad(Quality.fov * 0.5)) / maxf(0.05, tan(deg_to_rad(cam.fov * 0.5)))
	gun.position = gun.position.lerp(target * vk, 1.0 - exp(-20.0 * d))
	gun.rotation.x = recoil * 0.06 - 1.0 * holster_k
	gun.scale = Vector3.ONE * vk
	if flash.light_energy > 0.0:
		flash.light_energy = maxf(0.0, flash.light_energy - d * 60.0)
		flash_q.visible = flash.light_energy > 0.5
	if tp:
		tp.update(d)

func toggle_view() -> void:
	tp.set_on(not tp.on)
	ThirdPerson.save_on(tp.on)
	Game.msg("Third-person view" if tp.on else "First-person view")

# put the gun away (or draw it): lowered out of sight, it can't fire until it's drawn again
var holstered := false
var holster_k := 0.0
func toggle_holster() -> void:
	if Game.weapon == "" and not holstered:
		return
	holstered = not holstered
	reload_t = 0.0
	Sfx.play("k_draw" if not holstered else "k_belt", -6.0)
	Game.msg("Weapon holstered." if holstered else "Weapon drawn.")

func reload() -> void:
	if holstered:
		return
	if reload_t > 0.0 or Game.mag_size <= 0:
		return
	if Game.mag >= Game.mag_size and (Game.loaded_ammo() == Game.ammo_id() or Game.count(Game.ammo_id()) <= 0):
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
	if holstered:
		# pulling the trigger with it put away draws it first
		toggle_holster()
		fire_cd = 0.35
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
	if not Game.dev.ammo:
		Game.mag -= 1
	Game.stats_changed.emit()
	fire_cd = cd
	shot_fx(kind)
	if String(it.get("proj", "")) == "rocket":
		var aim := -cam.global_basis.z
		Nade.launch(vm.muzzle_pos() + aim * 0.3, aim, weapon_damage(), float(it.get("r", 6.0)))
		if Game.mag == 0:
			reload()
		return
	var pel := int(it.get("pellets", 1))
	var dmg := weapon_damage() * (0.75 if pel > 1 else 1.0)
	var moving := 1.5 if Vector2(velocity.x, velocity.z).length() > 1.0 else 1.0
	var spread := float(it.get("spread", 0.02)) * moving * float(fxc.spread) * (0.7 if kind == "rifle" and Game.perks.has("sniper") else 1.0)
	round_kind = Ammo.kind(Game.loaded_ammo())
	if pel > 1 and round_kind == "fmj":
		# a slug: one heavy ball, tight and far
		dmg *= pel * 0.8
		spread *= 0.3
		pel = 1
	for i in pel:
		burst_ok = i == 0
		_ray(dmg, float(it.get("range", 100)) * (1.6 if round_kind == "fmj" and int(it.get("pellets", 1)) > 1 else 1.0), spread, kind == "energy")
	round_kind = ""
	if Game.mag == 0:
		reload()

# the look and sound of one shot (FOCUS plays its queued shots through this too)
func shot_fx(kind: String) -> void:
	var it := Game.item(Game.weapon)
	vm.shoot()
	if kind == "melee":
		Sfx.play("k_slice", -2.0, randf_range(0.9, 1.1))
		return
	recoil = clampf(float(it.get("dmg", 15)) / 25.0, 0.6, 2.0)
	var quiet: bool = it.get("quiet", false)
	flash.light_energy = 1.2 if quiet else 6.0
	# build 23: a real flash, smoke and a spent case instead of a flat orange square
	flash_q.visible = false
	if gun.visible and vm and vm.muzzle:
		var gsize := 1.0 if kind == "pistol" else (1.8 if kind == "shotgun" else (1.0 if kind == "energy" else 1.35))
		GunFX.muzzle(vm.muzzle, gsize, quiet, kind == "energy", kind != "energy" and int(it.get("pellets", 1)) <= 1, -cam.global_basis.z)
	var snd: String = it.get("snd", SND.get(kind, "pistol"))
	Sfx.play(snd, -17.0 if quiet else -3.0, randf_range(0.95, 1.05) * (1.4 if kind == "energy" else 1.0) * (1.5 if quiet else 1.0))

var round_kind := ""     # the loaded round's type while a shot is fired ("", "fmj", "ex")
var burst_ok := true     # explosive buckshot bursts once a shot, not once a pellet
func _ray(dmg: float, rng: float, spread: float, energy: bool) -> void:
	var sp := Vector2(randf() - 0.5, randf() - 0.5) * spread * 2.0
	var from := cam.global_position
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * sp.x + b.y * sp.y).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * rng, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var it := Game.item(Game.weapon)
	if energy:
		Game.main.tracer(vm.muzzle_pos(), hit.position if hit else from + dir * rng, Color(String(it.beam)) if it.has("beam") else Color(0.4, 0.85, 1.0))
	if hit and it.has("splash"):
		_splash(hit.position, float(it.splash), dmg * 0.45, Color(String(it.get("beam", "#88ff88"))))
	if hit:
		var c: Object = hit.collider
		var crit := randf() < 0.03 + (int(Game.stats.luck) - 5) * 0.01
		if c and c.has_method("hit"):
			# a shot to the head of anything on two legs does half again as much
			var head := false
			if c.get("quad") == false and c.get("model") != null:
				head = hit.position.y - c.global_position.y > 1.5 * float(c.model.scale.y)
			var was_dead: bool = c.get("dead") == true
			# a sneak attack: crouched, on something that hasn't noticed you
			var sneak: bool = crouch and c.get("hostile") == true and c.get("state") != null and c.get("state") != "chase"
			if sneak:
				dmg *= 3.0 if String(Game.item(Game.weapon).get("kind", "")) == "melee" or Game.weapon == "" else 2.0
				if Game.perks.has("ninja"):
					dmg *= 1.5
				Game.msg("Sneak attack!")
			var machine: bool = c.get("def") is Dictionary and c.def.get("robot", false)
			var ion := float(it.get("ion", 1.0)) if machine else 1.0
			if round_kind != "":
				ion *= Ammo.mult("x_" + round_kind, machine)
			c.hit(dmg * ion * randf_range(0.9, 1.1) * (2.0 if crit else 1.0) * ((2.25 if Game.perks.has("sniper") else 1.5) if head else 1.0), hit.position, dir)
			_stranger(c)
			if it.has("burn") and c.get("bleed") != null and c.get("dead") == false:
				c.bleed = [float(it.burn[0]) * (1.5 if Game.perks.has("pyromaniac") else 1.0), float(it.burn[1])]
			if c.get("hp_max") != null and Game.main and Game.main.hud:
				var killed: bool = c.get("dead") == true and not was_dead
				Game.main.hud.hit_marker("kill" if killed else ("crit" if crit or head or sneak else "hit"))
				Game.main.hud.track_target(c)
				if head and not killed:
					Sfx.play("k_click", -10.0, 1.6)
		else:
			Game.main.impact(hit.position, hit.normal, GunFX.surface(hit))
			# a loose tyre, cone or can takes the shot and goes (build 24)
			Havoc.shot(c, hit.position, dir, clampf(dmg / 14.0, 0.5, 3.0))
		if round_kind == "ex" and burst_ok:
			_ex_burst(hit.position, dmg * 0.35, c)

# an explosive round bursting: a hand-span of fire that catches whoever stands right there
func _ex_burst(at: Vector3, dmg: float, skip) -> void:
	Game.main._puff(at, Vector3.UP, Color(1.0, 0.6, 0.25, 0.95), 10, 2.5)
	Sfx.play_at("x_rock1", at, -2.0, 1.4)
	for e in Game.main.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e != skip and e.global_position.distance_to(at) < 1.8:
			e.hit(dmg, e.global_position + Vector3.UP, (e.global_position - at).normalized())
	if Game.main.get("barrels"):
		Game.main.barrels.blast_near(at, 0.6)

# a plasma bolt bursting where it lands: a little blast that catches anyone close by
# Mysterious Stranger: something nearly dead, and sometimes a figure in a long coat finishes it for you
func _stranger(c) -> void:
	if not Game.perks.has("mysterious_stranger") or c.get("dead") != false or c.get("hp_max") == null:
		return
	if float(c.hp) > float(c.hp_max) * 0.35 or randf() > 0.08 + (int(Game.stats.luck) - 5) * 0.01:
		return
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(c) or c.dead:
		return
	Sfx.play("magnum" if Sfx.stream("magnum") else "pistol", 0.0, 0.8)
	c.hit(c.hp + 50.0, c.global_position + Vector3.UP * 1.5, (c.global_position - global_position).normalized())
	Game.msg("A stranger in a long coat fires once, tips his hat, and is gone.")

func _splash(at: Vector3, r: float, dmg: float, col: Color) -> void:
	for e in Game.main.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			var dd: float = e.global_position.distance_to(at)
			if dd < r + 0.4:
				e.hit(dmg * (1.0 - dd / (r + 0.4) * 0.5), e.global_position + Vector3.UP, (e.global_position - at).normalized())
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = r * 3.0
	Game.main.add_child(l)
	l.global_position = at + Vector3.UP * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
	Game.main._puff(at, Vector3.UP, Color(col.r, col.g, col.b, 0.9), 14, r)

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
