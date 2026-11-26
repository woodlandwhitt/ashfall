# The Meridian reactor (build 17). The plant's thing in the dark, the Glow Brute, used to stand by the core and come
# at you the moment the door opened, and its man-sized collision let most shots through. Now the reactor opens into
# a containment hall (Frontier "reactor_hall") and the brute starts in a holding cell there. Step inside the plant and
# the klaxon goes: CONTAINMENT FAULT, and a few seconds later the cell door lifts. Red lamps turn, steam vents from
# the coolant loop. Once it's out it stays out (Game.flags.reactor_cell), and once it's dead the alarm stays quiet.
class_name Reactor
extends Node3D

const HALL := Vector3(15.0, 5.218, -221.0)          # the containment hall's floor centre
const CELL := Vector3(9.45, 5.218, -225.6)           # the holding cell's centre (the brute's home)
const INSIDE := [7.0, 23.0, -228.0, -200.4]          # x0 x1 z0 z1: the plant's two rooms
const OLD_WALL := [7, 23, -214.4, -213.6]            # the old north wall's solid (the hall's wall replaces it)

var main: Node
var door: Node3D
var door_col: CollisionShape3D
var lamps: Array = []
var steam: Array = []
var alarm: AudioStreamPlayer3D
var count := -1.0            # seconds until the cell opens, once the alarm is running
var t := 0.0

static func prepare() -> void:
	if Game.area != "world" or Game.region.get("reactor", false):
		return
	Game.region["reactor"] = true
	var S: Array = Game.region.solids
	for i in range(S.size() - 1, -1, -1):
		var s: Array = S[i]
		if is_equal_approx(float(s[0]), OLD_WALL[0]) and is_equal_approx(float(s[1]), OLD_WALL[1]) and is_equal_approx(float(s[2]), OLD_WALL[2]) and is_equal_approx(float(s[3]), OLD_WALL[3]):
			S.remove_at(i)
	for sp in Game.W.get("spawns", []) + Game.region.get("enemies", []):
		if String(sp.get("id", "")) == "brute":
			sp.x = CELL.x
			sp.z = CELL.z
	# the cell's three fixed sides stand in the solid list, so nothing paths through them
	S.append([CELL.x - 2.05, CELL.x - 1.85, CELL.z - 2.0, CELL.z + 2.0, -999, CELL.y + 3.6])
	S.append([CELL.x + 1.85, CELL.x + 2.05, CELL.z - 2.0, CELL.z + 2.0, -999, CELL.y + 3.6])
	S.append([CELL.x - 2.05, CELL.x + 2.05, CELL.z - 2.05, CELL.z - 1.85, -999, CELL.y + 3.6])

# the ground rises toward the cooling tower: under the hall it's cut down below the floor, or it shows through
static func level_ground() -> void:
	if Game.area != "world":
		return
	var top := HALL.y - 0.08
	for z in range(-228, -213):
		for x in range(7, 24):
			var ix := x - int(Game.x0)
			var iz := z - int(Game.z0)
			if ix < 0 or iz < 0 or ix >= Game.hw or iz >= Game.hd:
				continue
			var a := iz * Game.hw + ix
			if Game.hm[a] > top:
				Game.hm[a] = top

func _init(m: Node) -> void:
	main = m
	name = "Reactor"

func _ready() -> void:
	if Game.area != "world":
		return
	_build_cell()
	# turning red lamps in the hall and over the core, dark until the alarm
	for p in [HALL + Vector3(-5.2, 4.6, 6.2), HALL + Vector3(5.2, 4.6, 6.2), HALL + Vector3(0, 6.4, -4.0), Vector3(15.0, 9.8, -207.0)]:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.15, 0.08)
		l.light_energy = 0.0
		l.spot_range = 14.0
		l.spot_angle = 38.0
		add_child(l)
		l.global_position = p
		l.rotation = Vector3(-0.9, 0, 0)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.5, 0.08, 0.05)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.15, 0.05)
		bm.emission_energy_multiplier = 0.0
		sm.material = bm
		bulb.mesh = sm
		add_child(bulb)
		bulb.global_position = p + Vector3.UP * 0.2
		lamps.append([l, bm])
	# steady work lights so the hall isn't black
	for p in [HALL + Vector3(-4.0, 6.3, 3.0), HALL + Vector3(4.0, 6.3, -3.0), HALL + Vector3(-4.0, 6.3, -4.0)]:
		var o := OmniLight3D.new()
		o.light_color = Color(0.85, 0.95, 0.8)
		o.light_energy = 0.9
		o.omni_range = 10.0
		add_child(o)
		o.global_position = p
	# steam from the coolant loop
	for p in [HALL + Vector3(6.2, 5.7, -1.2), HALL + Vector3(-7.2, 5.9, -6.0), HALL + Vector3(3.6, 1.2, -2.4)]:
		var s := CPUParticles3D.new()
		s.amount = 18
		s.lifetime = 2.2
		s.direction = Vector3(0, -0.4, 1)
		s.spread = 25.0
		s.initial_velocity_min = 0.6
		s.initial_velocity_max = 1.4
		s.gravity = Vector3(0, 0.25, 0)
		s.scale_amount_min = 1.0
		s.scale_amount_max = 2.6
		var q := QuadMesh.new()
		q.size = Vector2(0.6, 0.6)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft()
		q.material = m
		s.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(0.85, 0.88, 0.85, 0.35))
		g.set_color(1, Color(0.8, 0.82, 0.8, 0.0))
		s.color_ramp = g
		add_child(s)
		s.global_position = p
		steam.append(s)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = load("res://sfx/o_hum.ogg")
	hum.volume_db = -6.0
	hum.max_distance = 30.0
	hum.autoplay = true
	add_child(hum)
	hum.global_position = HALL + Vector3(1.0, 2.0, -2.4)
	alarm = AudioStreamPlayer3D.new()
	alarm.stream = load("res://sfx/alarm.wav")
	alarm.volume_db = 2.0
	alarm.max_distance = 60.0
	add_child(alarm)
	alarm.global_position = HALL + Vector3(0, 5.0, 5.0)
	if Game.flags.get("reactor_cell", false):
		_open(true)

static var _soft_tex: Texture2D
static func _soft() -> Texture2D:
	if _soft_tex == null:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = g
		gt.width = 64
		gt.height = 64
		_soft_tex = gt
	return _soft_tex

func _build_cell() -> void:
	var kit := Frontier.Kit.new()
	var hw := 2.0
	var hgt := 3.6
	for i in 11:
		var f := -hw + i * (hw * 2.0 / 10.0)
		kit.box("metal", Vector3(-hw, hgt * 0.5, f), Vector3(0.07, hgt, 0.07), 0)
		kit.box("metal", Vector3(hw, hgt * 0.5, f), Vector3(0.07, hgt, 0.07), 0)
		kit.box("metal", Vector3(f, hgt * 0.5, -hw), Vector3(0.07, hgt, 0.07), 0)
	for y in [0.05, 1.8, hgt]:
		kit.box("metal", Vector3(-hw, y, 0), Vector3(0.12, 0.1, hw * 2.0), 0)
		kit.box("metal", Vector3(hw, y, 0), Vector3(0.12, 0.1, hw * 2.0), 0)
		kit.box("metal", Vector3(0, y, -hw), Vector3(hw * 2.0, 0.1, 0.12), 0)
	kit.box("metal", Vector3(0, hgt + 0.05, 0), Vector3(hw * 2.0 + 0.1, 0.08, hw * 2.0 + 0.1), 0)
	kit.box("ochre", Vector3(0, 0.02, hw + 0.4), Vector3(hw * 2.0, 0.02, 0.5), 0)
	# the lifting mechanism over the door, and a sign
	kit.box("metal", Vector3(0, hgt + 0.35, hw), Vector3(hw * 2.2, 0.5, 0.4), 0)
	kit.box("ochre", Vector3(0, hgt + 0.35, hw + 0.21), Vector3(1.6, 0.3, 0.02), 0)
	var cell := Node3D.new()
	cell.name = "Cell"
	kit.commit(cell)
	add_child(cell)
	cell.global_position = CELL
	var sign := Label3D.new()
	sign.text = "HOLDING CELL 2\nDO NOT FEED"
	sign.font_size = 40
	sign.pixel_size = 0.005
	sign.modulate = Color(0.1, 0.08, 0.05)
	sign.outline_size = 0
	cell.add_child(sign)
	sign.position = Vector3(0, hgt + 0.36, hw + 0.23)
	# the door: bars on a frame that lifts into the mechanism
	door = Node3D.new()
	var dk := Frontier.Kit.new()
	for i in 11:
		var f := -hw + i * (hw * 2.0 / 10.0)
		dk.box("metal", Vector3(f, hgt * 0.5, 0), Vector3(0.07, hgt, 0.07), 0)
	for y in [0.1, 1.2, 2.4, hgt - 0.1]:
		dk.box("metal", Vector3(0, y, 0), Vector3(hw * 2.0, 0.09, 0.1), 0)
	dk.commit(door)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	door_col = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(hw * 2.0, hgt, 0.2)
	door_col.shape = bs
	door_col.position = Vector3(0, hgt * 0.5, 0)
	body.add_child(door_col)
	door.add_child(body)
	cell.add_child(door)
	door.position = Vector3(0, 0, hw)

func _brute():
	for e in main.enemies:
		if is_instance_valid(e) and e.eid == "brute":
			return e
	return null

func _physics_process(d: float) -> void:
	if Game.area != "world" or Game.player == null:
		return
	t += d
	var b = _brute()
	var free: bool = Game.flags.get("reactor_cell", false)
	if b and not b.dead and not free:
		b.caged = true
	var p: Vector3 = Game.player.global_position
	var inside: bool = p.x > INSIDE[0] and p.x < INSIDE[1] and p.z > INSIDE[2] and p.z < INSIDE[3] and p.y < 13.0
	var live: bool = not Game.killed.has("brute")
	if inside and live and not free and count < 0.0:
		count = 4.0
		alarm.play()
		Game.msg("CONTAINMENT FAULT - HOLDING CELL 2. EVACUATE THE HALL.")
	if count >= 0.0:
		count -= d
		if count <= 0.0:
			count = -1.0
			_open(false)
	var on: bool = (count >= 0.0 or (free and live and t < 9999.0)) and live and p.distance_to(HALL) < 60.0
	for L in lamps:
		var l: SpotLight3D = L[0]
		if on:
			l.rotation.y = t * 4.0 + l.global_position.x
			l.light_energy = 3.0
			(L[1] as StandardMaterial3D).emission_energy_multiplier = 3.0 + 2.0 * sin(t * 8.0)
		elif l.light_energy > 0.0:
			l.light_energy = 0.0
			(L[1] as StandardMaterial3D).emission_energy_multiplier = 0.0
	if on and not alarm.playing and count < 0.0 and free and fmod(t, 6.0) < d:
		alarm.play()
	if not live and alarm.playing:
		alarm.stop()

func _open(instant: bool) -> void:
	Game.flags["reactor_cell"] = true
	door_col.disabled = true
	if instant:
		door.position.y = 3.4
	else:
		Sfx.play_at("o_bigdoor", CELL + Vector3(0, 2, 2), 6.0, 0.8)
		var tw := door.create_tween()
		tw.tween_property(door, "position:y", 3.4, 1.6).set_trans(Tween.TRANS_SINE)
		Game.msg("The cell door grinds up into its housing.")
	var b = _brute()
	if b and not b.dead:
		b.caged = false
		b.state = "chase"
		Sfx.play_at("o_creature1", b.global_position, 8.0, 0.6)
