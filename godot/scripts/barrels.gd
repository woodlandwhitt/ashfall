# Explosive drums. The WebView build baked its red fuel drums into the scenery (with a glowing yellow plate that read
# as a floating dot), so bullets passed through them; build 17 folds those away (data/settle.json) and stands live
# drums in their place (data/barrels.json), plus one beside most raider camps. A shot punctures a drum: it catches,
# hisses for a couple of seconds and goes up, and a drum caught in a blast goes up almost at once, so a row of them
# chains. Spent drums stay gone (Game.opened["eb_<id>"]).
class_name Barrels
extends Node3D

const HP := 14.0
const R := 6.5           # blast radius
const DMG := 110.0
const FUSE := 2.2        # seconds a punctured drum burns before it goes

var main: Node
var all: Array = []      # [{id, x, z, y, node, extra}]
var t := 0.0
static var _mats: Array = []

func _init(m: Node) -> void:
	main = m
	name = "Barrels"

func _ready() -> void:
	if FileAccess.file_exists("res://data/barrels.json"):
		var B = JSON.parse_string(FileAccess.get_file_as_string("res://data/barrels.json"))
		if B is Array:
			for b in B:
				all.append({"id": String(b.id), "x": float(b.x), "z": float(b.z), "y": float(b.y), "node": null, "extra": false})

var extras_done := false
# one more drum beside most raider camps: something to shoot when they bunch up
func _extras() -> void:
	extras_done = true
	var seen := {}
	for s in Game.W.get("spawns", []):
		if not (String(s.get("type", "")) in ["raider", "pyro", "marauder", "heavy"]) or s.has("flag"):
			continue
		var key := "%d_%d" % [int(float(s.x) / 30.0), int(float(s.z) / 30.0)]
		if seen.has(key):
			continue
		seen[key] = true
		var h := absi(hash(String(s.get("id", key))))
		if h % 4 == 0:
			continue
		var a := float(h % 628) / 100.0
		var d := 3.0 + float(h % 3)
		all.append({"id": "x_" + String(s.get("id", key)), "x": float(s.x) + sin(a) * d, "z": float(s.z) + cos(a) * d, "y": float(s.get("y", 0.0)), "node": null, "extra": true})

func _physics_process(d: float) -> void:
	t -= d
	if t > 0.0 or Game.player == null:
		return
	t = 0.5
	var surface: bool = Game.area == "world"
	if surface and not extras_done:
		_extras()
	var p: Vector3 = Game.player.global_position
	for b in all:
		var near := surface and Vector2(float(b.x) - p.x, float(b.z) - p.z).length() < 110.0
		if near and b.node == null and not Game.opened.has("eb_" + String(b.id)) and not b.get("bad", false):
			_spawn(b)
		elif not near and b.node != null and is_instance_valid(b.node) and not b.node.lit:
			b.node.queue_free()
			b.node = null

func _spawn(b: Dictionary) -> void:
	var space := get_world_3d().direct_space_state
	var gy := Game.height(float(b.x), float(b.z))
	var top := maxf(gy, float(b.y)) + 2.5
	var q := PhysicsRayQueryParameters3D.create(Vector3(float(b.x), top, float(b.z)), Vector3(float(b.x), minf(gy, float(b.y)) - 2.0, float(b.z)), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return    # the ground there isn't loaded yet: try again next tick
	var y: float = hit.position.y
	if b.extra:
		# a camp drum mustn't stand in a wall, on a roof or on a slope
		if hit.normal.y < 0.9 or absf(y - gy) > 0.6:
			b["bad"] = true
			return
		var sq := PhysicsShapeQueryParameters3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45
		cyl.height = 0.9
		sq.shape = cyl
		sq.transform = Transform3D(Basis(), Vector3(float(b.x), y + 0.6, float(b.z)))
		sq.collision_mask = 1
		if not space.intersect_shape(sq, 1).is_empty():
			b["bad"] = true
			return
	var n := Drum.new()
	n.owner_list = self
	n.info = b
	add_child(n)
	n.global_position = Vector3(float(b.x), y - 0.03, float(b.z))
	n.rotation.y = float(absi(hash(String(b.id))) % 628) / 100.0
	b.node = n

# something went off nearby (a grenade, a mine, another drum): drums inside the blast follow it
func blast_near(at: Vector3, r: float) -> void:
	for b in all:
		var n = b.node
		if n != null and is_instance_valid(n) and not n.gone:
			var dd: float = n.global_position.distance_to(at)
			if dd < r + 0.5:
				n.ignite(0.15 + dd * 0.04)

func find_at(at: Vector3, r: float) -> Array:
	var out := []
	for b in all:
		if b.node != null and is_instance_valid(b.node) and not b.node.gone and b.node.global_position.distance_to(at) < r:
			out.append(b.node)
	return out

static func mats() -> Array:
	if _mats.is_empty():
		var nz := FastNoiseLite.new()
		nz.frequency = 0.08
		nz.fractal_octaves = 4
		var nt := NoiseTexture2D.new()
		nt.width = 128
		nt.height = 128
		nt.seamless = true
		nt.noise = nz
		var g := Gradient.new()
		g.set_color(0, Color(0.32, 0.12, 0.07))
		g.set_color(1, Color(0.78, 0.2, 0.12))
		g.add_point(0.55, Color(0.62, 0.15, 0.1))
		nt.color_ramp = g
		var body := StandardMaterial3D.new()
		body.albedo_texture = nt
		body.metallic = 0.35
		body.roughness = 0.62
		body.uv1_scale = Vector3(2, 1, 1)
		var rim := StandardMaterial3D.new()
		rim.albedo_color = Color(0.2, 0.17, 0.15)
		rim.metallic = 0.6
		rim.roughness = 0.5
		var stencil := StandardMaterial3D.new()
		stencil.albedo_color = Color(0.78, 0.72, 0.62)
		stencil.roughness = 0.9
		_mats = [body, rim, stencil]
	return _mats


class Drum extends StaticBody3D:
	var owner_list: Barrels
	var info: Dictionary
	var hp := HP
	var lit := false
	var gone := false
	var fuse := 0.0
	var flame: CPUParticles3D
	var light: OmniLight3D

	func _ready() -> void:
		collision_layer = 1
		var M := Barrels.mats()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.37
		sh.height = 1.05
		cs.shape = sh
		cs.position.y = 0.525
		add_child(cs)
		var body := CylinderMesh.new()
		body.top_radius = 0.36
		body.bottom_radius = 0.36
		body.height = 1.05
		body.radial_segments = 18
		body.material = M[0]
		_mi(body, Vector3(0, 0.525, 0))
		for yy in [0.3, 0.75, 1.03]:
			var r := CylinderMesh.new()
			r.top_radius = 0.375
			r.bottom_radius = 0.375
			r.height = 0.045
			r.radial_segments = 18
			r.material = M[1]
			_mi(r, Vector3(0, yy, 0))
		# the bung on the lid, and a worn stencilled flame stripe (no glow: build 17 report)
		var bung := CylinderMesh.new()
		bung.top_radius = 0.045
		bung.bottom_radius = 0.05
		bung.height = 0.04
		bung.material = M[1]
		_mi(bung, Vector3(0.18, 1.06, 0.0))
		var st := BoxMesh.new()
		st.size = Vector3(0.2, 0.05, 0.01)
		st.material = M[2]
		_mi(st, Vector3(0, 0.52, 0.362))

	func _mi(m: Mesh, at: Vector3) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = at
		add_child(mi)

	# shot: a hole, a jet of burning fuel, and a few seconds to get clear
	func hit(dmg: float, at: Vector3, _dir: Vector3) -> void:
		if gone:
			return
		hp -= dmg
		Game.main.impact(at, (at - global_position - Vector3.UP * 0.5).normalized())
		Sfx.play_at("k_click", at, -4.0, 0.7)
		if hp <= 0.0:
			ignite(0.12)
		else:
			ignite(FUSE)

	func ignite(after: float) -> void:
		if gone:
			return
		if lit:
			fuse = minf(fuse, after)
			return
		lit = true
		fuse = after
		flame = CPUParticles3D.new()
		flame.amount = 24
		flame.lifetime = 0.6
		flame.direction = Vector3.UP
		flame.spread = 18.0
		flame.initial_velocity_min = 1.2
		flame.initial_velocity_max = 2.4
		flame.gravity = Vector3(0, 1.5, 0)
		flame.scale_amount_min = 0.5
		flame.scale_amount_max = 1.0
		var q := QuadMesh.new()
		q.size = Vector2(0.22, 0.22)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.billboard_keep_scale = true
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.vertex_color_use_as_albedo = true
		q.material = fm
		flame.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
		g.set_color(1, Color(0.6, 0.15, 0.05, 0.0))
		flame.color_ramp = g
		flame.position = Vector3(0.18, 1.08, 0.0)
		add_child(flame)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 1.5
		light.omni_range = 4.0
		light.position = Vector3(0, 1.3, 0)
		add_child(light)
		Sfx.play_at("k_cloth1", global_position, 0.0, 0.5)

	func _physics_process(d: float) -> void:
		if not lit or gone:
			return
		fuse -= d
		if light:
			light.light_energy = 1.2 + randf() * 0.8
		if fuse <= 0.0:
			_boom()

	func _boom() -> void:
		gone = true
		var at := global_position + Vector3.UP * 0.5
		Game.opened["eb_" + String(info.id)] = true
		info.node = null
		Nade.blast(at, Barrels.R, Barrels.DMG, Color(1.0, 0.55, 0.2), false)
		queue_free()
