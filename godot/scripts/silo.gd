# Silo 9 (build 18). The console at the bottom of the Glass Bowl used to end the silo with a line of text. Now its
# two drastic choices happen in the world:
#  - LAUNCH (the crew key and Tobiah's override together: the two-man rule): a klaxon and a forty-five second count,
#    the hatch steaming, then the missile climbs out of the silo on a pillar of fire and smoke, rolls north-east and is
#    gone. Half a minute later the sky to the north-east goes white: an airburst over the old test range forty
#    kilometres out. The mushroom cloud stands on the horizon for the rest of the day, the rumble arrives after the
#    flash, and for a day after the ash wind carries fallout over the north (radiation outdoors north of Northgate).
#  - SCUTTLE (the core run past its limits): ninety seconds to get out of the Bowl's floor before the silo folds into
#    the earth. Anyone close is killed; the blockhouse and the silo cap are rubble from then on.
# The count survives a save (flags.silo_count).
class_name Silo9
extends Node3D

const CAP := Vector3(1164.0, 0.0, -790.0)         # the silo's hatch (y from the ground)
const HOUSE := Vector3(1146.0, 0.0, -802.0)       # the blockhouse
const BURST_DIR := Vector3(0.62, 0.0, -0.78)       # north-east, where the test range was
const LAUNCH_COUNT := 45.0
const SCUTTLE_COUNT := 90.0

var main: Node
var cap_y := 0.0
var alarm: AudioStreamPlayer3D
var lamps: Array = []
var missile: Node3D
var mt := 0.0                 # seconds since the missile left
var flight := Vector3.ZERO
var cloud: Node3D             # the mushroom on the horizon
var cloud_t := -1.0
var flash: ColorRect
var rumble_t := -1.0
var steam: CPUParticles3D
var t := 0.0
var shown_count := -1

# after the scuttle the blockhouse and the cap are gone: their walls come out of the solid list before the colliders
# and navigation are built
static func prepare() -> void:
	if Game.area != "world" or String(Game.flags.get("silo_end", "")) != "blown":
		return
	var S: Array = Game.region.solids
	for i in range(S.size() - 1, -1, -1):
		var c := Vector2((float(S[i][0]) + float(S[i][1])) * 0.5, (float(S[i][2]) + float(S[i][3])) * 0.5)
		if c.distance_to(Vector2(CAP.x, CAP.z)) < 9.0 or c.distance_to(Vector2(HOUSE.x, HOUSE.z)) < 8.0:
			S.remove_at(i)

func _init(m: Node) -> void:
	main = m
	name = "Silo9"

func _ready() -> void:
	if Game.area != "world":
		return
	cap_y = Game.height(CAP.x, CAP.z)
	alarm = AudioStreamPlayer3D.new()
	alarm.stream = load("res://sfx/alarm.wav")
	alarm.volume_db = 6.0
	alarm.max_distance = 220.0
	alarm.unit_size = 30.0
	add_child(alarm)
	alarm.global_position = CAP + Vector3(0, cap_y + 4.0, 0)
	for p in [CAP + Vector3(6.5, 1.6, 0), CAP + Vector3(-6.5, 1.6, 0), HOUSE + Vector3(0, 3.0, 4.6)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.18, 0.08)
		l.light_energy = 0.0
		l.omni_range = 12.0
		add_child(l)
		l.global_position = p + Vector3(0, Game.height(p.x, p.z), 0)
		lamps.append(l)
	if String(Game.flags.get("silo_end", "")) == "blown":
		_ruin(true)
	# the day of the burst: the cloud still stands on the horizon
	if Game.flags.has("burst_day") and Game.day <= int(Game.flags.burst_day):
		_make_cloud(1.0)

func _physics_process(d: float) -> void:
	if Game.area != "world" or Game.player == null:
		return
	t += d
	var seq := String(Game.flags.get("silo_seq", ""))
	if seq != "":
		_count(d, seq)
	if missile:
		_fly(d)
	if cloud:
		_cloud(d)
	if rumble_t >= 0.0:
		rumble_t -= d
		if rumble_t < 0.0:
			_rumble()
	if flash:
		flash.color.a -= d * 0.35
		if flash.color.a <= 0.0:
			flash.queue_free()
			flash = null
	# the ash wind: fallout over the north for a day after the burst
	if Game.flags.has("burst_day") and Game.day <= int(Game.flags.burst_day) + 1 and Game.player.global_position.z < -520.0 and int(t / 3.0) != int((t - d) / 3.0):
		if not main.hud.screens.is_open():
			Game.add_rad(0.4)

func _count(d: float, seq: String) -> void:
	var left := float(Game.flags.get("silo_count", LAUNCH_COUNT if seq == "launch" else SCUTTLE_COUNT)) - d
	Game.flags["silo_count"] = left
	if not alarm.playing:
		alarm.play()
	for l in lamps:
		(l as OmniLight3D).light_energy = 2.5 + 2.0 * sin(t * 9.0)
	var shown := int(ceil(left))
	if shown != shown_count and (shown % 10 == 0 or shown <= 5) and shown > 0:
		shown_count = shown
		Game.msg(("LAUNCH IN %d" if seq == "launch" else "CORE FAILURE IN %d. GET OUT OF THE BOWL.") % shown)
	if seq == "launch" and left < 12.0:
		_steam()
		Game.player.hurt_shake = maxf(Game.player.hurt_shake, 0.15 * _near(140.0))
	if left > 0.0:
		return
	Game.flags.erase("silo_seq")
	Game.flags.erase("silo_count")
	alarm.stop()
	for l in lamps:
		(l as OmniLight3D).light_energy = 0.0
	if seq == "launch":
		_launch()
	else:
		_scuttle()

# 0..1, how close you are inside r
func _near(r: float) -> float:
	var dd: float = Game.player.global_position.distance_to(CAP + Vector3(0, cap_y, 0))
	return clampf(1.0 - dd / r, 0.0, 1.0)

func _steam() -> void:
	if steam:
		return
	steam = _smoke(CAP + Vector3(0, cap_y + 1.0, 0), 60, 3.0, Color(0.85, 0.85, 0.82, 0.5), 4.0)
	steam.direction = Vector3.UP
	steam.initial_velocity_min = 4.0
	steam.initial_velocity_max = 9.0

func _smoke(at: Vector3, amount: int, life: float, col: Color, size: float) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = amount
	s.lifetime = life
	s.spread = 30.0
	s.gravity = Vector3(0, 0.6, 0)
	s.scale_amount_min = size * 0.6
	s.scale_amount_max = size * 1.4
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Reactor._soft()
	q.material = m
	s.mesh = q
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	s.color_ramp = g
	add_child(s)
	s.global_position = at
	return s

# ---------------------------------------------------------------- the launch
func _launch() -> void:
	var kit := Frontier.Kit.new()
	kit.cyl("paint", Vector3(0, 0, 0), 0.9, 0.9, 13.0, 16, 0)
	kit.cyl("paint", Vector3(0, 13.0, 0), 0.9, 0.0, 3.2, 16, 0)
	kit.cyl("dark", Vector3(0, 4.0, 0), 0.92, 0.92, 0.6, 16, 0)
	kit.cyl("red", Vector3(0, 11.0, 0), 0.92, 0.92, 0.35, 16, 0)
	for i in 4:
		var a := i * TAU / 4.0
		kit.box("metal", Vector3(cos(a) * 1.3, 1.0, sin(a) * 1.3), Vector3(0.1, 2.0, 1.0) if i % 2 == 0 else Vector3(1.0, 2.0, 0.1), 0)
	missile = Node3D.new()
	missile.name = "Missile"
	kit.commit(missile)
	add_child(missile)
	missile.global_position = CAP + Vector3(0, cap_y - 16.0, 0)
	# fire and smoke under it
	var fire := CPUParticles3D.new()
	fire.amount = 70
	fire.lifetime = 0.5
	fire.direction = Vector3.DOWN
	fire.spread = 12.0
	fire.initial_velocity_min = 18.0
	fire.initial_velocity_max = 28.0
	fire.gravity = Vector3.ZERO
	fire.scale_amount_min = 1.5
	fire.scale_amount_max = 3.0
	fire.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.billboard_keep_scale = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = Reactor._soft()
	q.material = fm
	fire.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.add_point(0.4, Color(1.0, 0.55, 0.15, 0.9))
	g.set_color(1, Color(0.4, 0.1, 0.0, 0.0))
	fire.color_ramp = g
	missile.add_child(fire)
	fire.position = Vector3(0, -0.5, 0)
	var trail := _smoke(missile.global_position, 420, 12.0, Color(0.86, 0.84, 0.8, 0.85), 9.0)
	trail.local_coords = false
	trail.gravity = Vector3(1.0, 0.3, 0)
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 2.0
	trail.reparent(missile)
	trail.position = Vector3(0, -2.0, 0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.65, 0.3)
	glow.light_energy = 6.0
	glow.omni_range = 60.0
	missile.add_child(glow)
	glow.position = Vector3(0, -3.0, 0)
	mt = 0.0
	flight = Vector3.UP
	Sfx.play_at("x_boom3", CAP + Vector3(0, cap_y, 0), 12.0, 0.45)
	Sfx.play_at("x_boom1", CAP + Vector3(0, cap_y, 0), 10.0, 0.35)
	var roar := AudioStreamPlayer3D.new()
	roar.stream = load("res://sfx/o_hum.ogg")
	roar.pitch_scale = 0.5
	roar.volume_db = 14.0
	roar.max_distance = 1500.0
	roar.unit_size = 60.0
	missile.add_child(roar)
	roar.play()
	# the exhaust out of the silo: whoever stands at the hatch is burnt
	var nr := _near(18.0)
	if nr > 0.0:
		Game.hurt(160.0 * nr)
	Game.player.hurt_shake = maxf(Game.player.hurt_shake, 1.2 * _near(200.0) + 0.2)
	Game.banner("LAUNCH", "Silo 9's missile is in the air")

func _fly(d: float) -> void:
	mt += d
	# straight up for six seconds, then a slow roll toward the north-east and a long climb out of sight
	var speed := minf(3.0 + mt * mt * 3.2, 280.0)
	var pitch := clampf((mt - 6.0) / 10.0, 0.0, 1.0) * 0.9
	flight = (Vector3.UP * cos(pitch) + BURST_DIR * sin(pitch)).normalized()
	missile.global_position += flight * speed * d
	missile.global_basis = Basis(Quaternion(Vector3.UP, flight))
	if mt < 4.0:
		Game.player.hurt_shake = maxf(Game.player.hurt_shake, 0.8 * _near(300.0))
	if mt > 26.0:
		missile.queue_free()
		missile = null
		_burst()

# ---------------------------------------------------------------- the burst over the test range
func _burst() -> void:
	Game.flags["burst_day"] = Game.day
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	flash = ColorRect.new()
	flash.color = Color(1.0, 0.97, 0.9, 0.95)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	_make_cloud(0.0)
	# sound takes its time over forty kilometres; this is a game, so a dozen seconds
	rumble_t = 12.0
	Game.msg("The sky to the north-east goes white.")

func _rumble() -> void:
	Sfx.play("x_boom3", 4.0, 0.3)
	Sfx.play("x_boom1", 2.0, 0.25)
	Game.player.hurt_shake = maxf(Game.player.hurt_shake, 0.9)
	Game.msg("A long, low roll of thunder comes in from the north-east, and the ground shivers.")

# a cloud drawn as if forty kilometres away: it rides at a fixed distance from you, in a fixed direction
func _make_cloud(grown: float) -> void:
	cloud = Node3D.new()
	cloud.name = "Mushroom"
	add_child(cloud)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 col : source_color = vec4(1.0);
uniform float glow = 0.0;
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = mix(col.rgb * (0.75 + 0.35 * rim), vec3(1.0, 0.55, 0.2), glow * (1.0 - rim * 0.5));
	ALPHA = col.a * (0.55 + 0.45 * (1.0 - rim));
}"""
	for part in [["stem", Vector3(0, 0.5, 0), Vector3(0.16, 1.0, 0.16)], ["cap", Vector3(0, 1.05, 0), Vector3(0.62, 0.3, 0.62)], ["ring", Vector3(0, 0.62, 0), Vector3(0.36, 0.08, 0.36)],
			["skirt", Vector3(0, 0.03, 0), Vector3(0.9, 0.08, 0.9)]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 20
		sm.rings = 10
		mi.mesh = sm
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("col", Color(0.78, 0.72, 0.66, 0.95))
		mi.material_override = mat
		mi.position = part[1]
		mi.scale = part[2]
		mi.name = part[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.add_child(mi)
	cloud_t = 60.0 * grown

func _cloud(d: float) -> void:
	cloud_t += d
	# half a minute after the flash, the north starts talking about it (the radio, the Ash Wind)
	if cloud_t > 30.0 and not Game.flags.has("silo_burst"):
		Game.flags["silo_burst"] = 1
		Game.check_quests()
	var g := clampf(cloud_t / 30.0, 0.0, 1.0)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var D := minf(cam.far * 0.85, 700.0)
	var base := cam.global_position + BURST_DIR * D
	base.y = cam.global_position.y + D * 0.02
	cloud.global_position = base
	var size := D * 0.85 * (0.2 + 0.8 * sqrt(g))
	cloud.scale = Vector3(size, size * (0.4 + 0.6 * g), size)
	var heat := clampf(1.0 - cloud_t / 18.0, 0.0, 1.0)
	for mi in cloud.get_children():
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override
		m.set_shader_parameter("glow", heat)
		m.set_shader_parameter("col", Color(0.78, 0.72, 0.66, 0.95 * (1.0 if Game.day <= int(Game.flags.get("burst_day", Game.day)) else 0.0)))
	if Game.day > int(Game.flags.get("burst_day", Game.day)):
		cloud.queue_free()
		cloud = null

# ---------------------------------------------------------------- the scuttle
func _scuttle() -> void:
	var at := CAP + Vector3(0, cap_y, 0)
	Sfx.play_at("x_boom3", at, 14.0, 0.4)
	Sfx.play_at("x_boom1", at, 12.0, 0.3)
	Nade._flash_at(at + Vector3.UP * 4.0, Color(1.0, 0.7, 0.4), 40.0)
	var dd: float = Game.player.global_position.distance_to(at)
	if dd < 45.0:
		Game.hurt(1000.0)
	elif dd < 130.0:
		Game.hurt(140.0 * (1.0 - (dd - 45.0) / 85.0))
	Game.player.hurt_shake = maxf(Game.player.hurt_shake, 1.4 * _near(400.0) + 0.3)
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) < 60.0:
			e.hit(9999.0, e.global_position + Vector3.UP, (e.global_position - at).normalized())
	var dust := _smoke(at + Vector3.UP * 6.0, 120, 10.0, Color(0.6, 0.55, 0.48, 0.85), 14.0)
	dust.emission_sphere_radius = 18.0
	dust.one_shot = true
	dust.explosiveness = 0.7
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	_ruin(false)
	# a column of dust that hangs over the Bowl for a while
	var col := _smoke(at + Vector3.UP * 3.0, 80, 14.0, Color(0.55, 0.5, 0.45, 0.6), 10.0)
	col.direction = Vector3.UP
	col.initial_velocity_min = 2.0
	col.initial_velocity_max = 5.0
	col.emission_sphere_radius = 6.0
	get_tree().create_timer(120.0).timeout.connect(func(): col.emitting = false)
	Game.banner("SILO 9", "The silo folds into the earth")

# the blockhouse and the silo cap down: what Frontier built there is hidden and rubble takes its place
func _ruin(instant: bool) -> void:
	var fr = main.get("frontier")
	if fr == null:
		return
	for n in fr.get_children():
		if n is Node3D:
			var p: Vector3 = (n as Node3D).global_position
			if Vector2(p.x - CAP.x, p.z - CAP.z).length() < 3.0 or Vector2(p.x - HOUSE.x, p.z - HOUSE.z).length() < 3.0:
				(n as Node3D).visible = false
				for c in (n as Node).find_children("*", "CollisionShape3D", true, false):
					(c as CollisionShape3D).disabled = true
	# (live, the walls' colliders are already built: switch off the ones standing there)
	if not instant:
		for nb in main.get_children():
			if nb is StaticBody3D:
				for c in nb.get_children():
					if c is CollisionShape3D:
						var p2 := Vector2((c as CollisionShape3D).position.x, (c as CollisionShape3D).position.z)
						if p2.distance_to(Vector2(CAP.x, CAP.z)) < 9.0 or p2.distance_to(Vector2(HOUSE.x, HOUSE.z)) < 8.0:
							(c as CollisionShape3D).disabled = true
	var kit := Frontier.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 16.0)
		var p := Vector3(cos(a) * r, rng.randf_range(-0.3, 0.6), sin(a) * r)
		kit.box("concrete_dk" if i % 3 else "metal", p, Vector3(rng.randf_range(0.6, 2.6), rng.randf_range(0.4, 1.6), rng.randf_range(0.6, 2.4)), 0,
			Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)))
	# the cap's slabs, broken and tipped into the hole, and the stub of the blockhouse
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		kit.box("concrete", Vector3(cos(a) * 6.0 + 9.0, 1.2, sin(a) * 6.0 + 6.0), Vector3(4.5, 0.8, 3.0), 0,
			Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, 0.6 + 0.2 * sin(i * 2.0)))
	kit.box("concrete", Vector3(-9.0, 1.4, -6.0), Vector3(9.0, 2.8, 0.5), 0, Basis(Vector3.FORWARD, 0.25))
	kit.box("concrete", Vector3(-12.5, 0.9, -3.0), Vector3(0.5, 1.8, 7.0), 0, Basis(Vector3.RIGHT, -0.3))
	kit.cyl("dark", Vector3(0, 0.02, 0), 14.0, 14.0, 0.05, 24, 0)
	kit.cyl("burnt", Vector3(0, 0.04, 0), 9.0, 9.0, 0.05, 24, 0)
	var rubble := Node3D.new()
	rubble.name = "SiloRubble"
	kit.commit(rubble)
	add_child(rubble)
	rubble.global_position = Vector3((CAP.x + HOUSE.x) * 0.5, Game.height((CAP.x + HOUSE.x) * 0.5, (CAP.z + HOUSE.z) * 0.5) - 0.3, (CAP.z + HOUSE.z) * 0.5)
	if not instant:
		rubble.position.y -= 3.0
		var tw := rubble.create_tween()
		tw.tween_property(rubble, "position:y", rubble.position.y + 3.0, 2.5).set_trans(Tween.TRANS_BOUNCE)
