# The Ashwood's trees (build 15). data/flora.png (written by tools/terrain/expand.py, one pixel per metre like the
# ground mask) holds how thick the living pine forest is (red) and how many dead snags stand about (green). Every
# chunk the player is near gets its trees as two MultiMeshes, a detailed one for close up and a cheap one for
# further off, plus a trunk collider per tree; the coarse horizon chunks get a sparse far forest so the hills read as
# wooded from a distance. Meshes are built once, in code, vertex-coloured for scripts/tree.gdshader.
class_name Flora
extends RefCounted

const STEP := 4.6               # one candidate spot per this many metres, jittered
const NEAR := 120.0             # detailed trees out to here, cheap ones beyond
static var img: Image
static var mat: ShaderMaterial
static var meshes: Dictionary = {}
static var far_on := true       # Quality turns the horizon forest off on Low

static func _ready_data() -> bool:
	if img == null:
		if not ResourceLoader.exists("res://data/flora.png"):
			return false
		var t := load("res://data/flora.png") as Texture2D
		if t == null:
			return false
		img = t.get_image()
		if img.is_compressed():
			img.decompress()
		mat = ShaderMaterial.new()
		mat.shader = preload("res://scripts/tree.gdshader")
	return true

static func at(x: float, z: float) -> Color:
	return img.get_pixel(clampi(int(x - Game.x0), 0, img.get_width() - 1), clampi(int(z - Game.z0), 0, img.get_height() - 1))

# ---------------------------------------------------------------- where the trees stand in one chunk
# [x, z, kind (0 pine, 1 dead), scale, yaw, tint]
static func spots(i: int, j: int, size: float, keep: float, mask: Image) -> Array:
	var out: Array = []
	if not _ready_data() or Game.area != "world":
		return out
	var x0 := Game.x0 + i * size
	var z0 := Game.z0 + j * size
	# a chunk the forest doesn't reach costs nothing: check a few samples first
	var any := false
	for a in 5:
		for b in 5:
			var c := at(x0 + a * size / 4.0, z0 + b * size / 4.0)
			if c.r > 0.02 or c.g > 0.02:
				any = true
	if not any:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 92821 + j * 68917 + 15
	var n := int(size / STEP)
	for gz in n:
		for gx in n:
			var x := x0 + (gx + rng.randf()) * STEP
			var z := z0 + (gz + rng.randf()) * STEP
			var r := rng.randf()
			var sc := rng.randf_range(0.75, 1.3)
			var yaw := rng.randf() * TAU
			var tint := rng.randf_range(0.82, 1.12)
			var c := at(x, z)
			var kind := -1
			if r < c.r * keep:
				kind = 0
			elif r < (c.r + c.g * 0.35) * keep:
				kind = 1
			if kind < 0:
				continue
			if mask:
				var mk := mask.get_pixel(clampi(int(x - Game.x0), 0, mask.get_width() - 1), clampi(int(z - Game.z0), 0, mask.get_height() - 1))
				if mk.r > 0.05:
					continue
			var h := Game.height(x, z)
			if absf(Game.height(x + 1.5, z) - h) > 1.6 or absf(Game.height(x, z + 1.5) - h) > 1.6:
				continue
			if Frontier.blocked(x, z):
				continue
			out.append([x, z, kind, sc * (0.8 if kind == 1 else 1.0), yaw, tint])
	return out

# ---------------------------------------------------------------- a chunk's trees, its colliders
static func plant(root: Node3D, i: int, j: int, size: float, mask: Image) -> void:
	var sp := spots(i, j, size, 0.85, mask)
	if sp.is_empty():
		return
	var centre := Vector3(Game.x0 + (i + 0.5) * size, 0, Game.z0 + (j + 0.5) * size)
	centre.y = Game.height(centre.x, centre.z)
	var node := Node3D.new()
	node.name = "Trees"
	node.position = centre
	root.add_child(node)
	for lod in 2:
		for kind in 2:
			var list := sp.filter(func(s): return int(s[2]) == kind)
			if list.is_empty():
				continue
			var mmi := _multimesh(list, _mesh(kind, lod == 1), centre)
			mmi.name = "T%d_%d" % [kind, lod]
			if lod == 0:
				mmi.visibility_range_end = NEAR
				mmi.visibility_range_end_margin = 10.0
			else:
				mmi.visibility_range_begin = NEAR
				mmi.visibility_range_begin_margin = 10.0
				mmi.visibility_range_end = 900.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "TreeBody"
	body.collision_layer = 1
	node.add_child(body)
	for s in sp:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = (0.32 if int(s[2]) == 0 else 0.22) * float(s[3])
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = Vector3(float(s[0]), Game.height(float(s[0]), float(s[1])) + 2.0, float(s[1])) - centre
		body.add_child(cs)

# the sparse far forest on a coarse chunk (hidden with it when the chunk's detail streams in)
static func far(mi: MeshInstance3D, i: int, j: int, size: float, mask: Image) -> void:
	if not far_on:
		return
	var sp := spots(i, j, size, 0.4, mask)
	if sp.is_empty():
		return
	var centre := Vector3(Game.x0 + (i + 0.5) * size, 0, Game.z0 + (j + 0.5) * size)
	centre.y = Game.height(centre.x, centre.z)
	var mmi := _multimesh(sp, _mesh(0, true), centre)
	mmi.name = "FarTrees"
	mmi.position = centre
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(mmi)

static func _multimesh(list: Array, mesh: Mesh, centre: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	var buf := PackedFloat32Array()
	for s in list:
		var x := float(s[0])
		var z := float(s[1])
		var sc := float(s[3])
		var bs := Basis(Vector3.UP, float(s[4])).scaled(Vector3(sc, sc, sc))
		# a little lean, more on dead ones
		bs = Basis(Vector3(1, 0, 0), sin(x * 1.7) * (0.06 if int(s[2]) == 1 else 0.02)) * bs
		var p := Vector3(x, Game.height(x, z) - 0.15, z) - centre
		buf.append_array([bs.x.x, bs.y.x, bs.z.x, p.x, bs.x.y, bs.y.y, bs.z.y, p.y, bs.x.z, bs.y.z, bs.z.z, p.z])
		var t := float(s[5])
		buf.append_array([t, t * (0.95 + sin(z) * 0.05), t * 0.95, 1.0])
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi

# ---------------------------------------------------------------- meshes
static func _mesh(kind: int, cheap: bool) -> Mesh:
	var key := "%d_%d" % [kind, int(cheap)]
	if meshes.has(key):
		return meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + kind
	var bark := Color(0.27, 0.2, 0.14)
	if kind == 0:
		var H := 10.0
		_cone(st, Vector3.ZERO, 0.3, 0.07, H * 0.8, 4 if cheap else 6, bark, bark.darkened(0.2), false)
		var tiers := 2 if cheap else 5
		for t in tiers:
			var f := float(t) / tiers
			var y := H * (0.2 + f * 0.62)
			var ht := H * (0.42 if cheap else 0.3) * (1.0 - f * 0.25)
			var rad := H * 0.25 * (1.0 - f * 0.62) * (1.15 if cheap else 1.0)
			var low := Color(0.11, 0.19, 0.1).lerp(Color(0.16, 0.25, 0.12), f)
			var high := Color(0.2, 0.31, 0.15).lerp(Color(0.25, 0.36, 0.17), f)
			_cone(st, Vector3(0, y, 0), rad, 0.0, ht, 5 if cheap else 9, low, high, true, rng.randf() * TAU, 0.0 if cheap else 0.18)
	else:
		var grey := Color(0.36, 0.33, 0.3)
		_cone(st, Vector3.ZERO, 0.24, 0.05, 6.5, 4 if cheap else 6, grey.darkened(0.25), grey, false)
		if not cheap:
			for b in 5:
				var y := rng.randf_range(2.2, 5.4)
				var a := rng.randf() * TAU
				var up := rng.randf_range(0.5, 1.0)
				var dir := Vector3(cos(a), up, sin(a)).normalized()
				_limb(st, Vector3(0, y, 0), dir, rng.randf_range(1.0, 2.2) * (1.0 - y / 9.0), 0.07, grey.darkened(0.1), grey)
	st.index()
	var m := st.commit()
	meshes[key] = m
	return m

# a cone or tapered cylinder standing on 'base', with an underside skirt for the needle tiers
static func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, seg: int, c0: Color, c1: Color, skirt: bool, rot := 0.0, droop := 0.0) -> void:
	var top := base + Vector3(0, h, 0)
	for k in seg:
		var a0 := rot + k * TAU / seg
		var a1 := rot + (k + 1) * TAU / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var j0 := 1.0 + sin(a0 * 3.0 + h) * droop
		var j1 := 1.0 + sin(a1 * 3.0 + h) * droop
		var b0 := base + d0 * r0 * j0 - Vector3(0, droop * r0 * 0.4 * j0, 0)
		var b1 := base + d1 * r0 * j1 - Vector3(0, droop * r0 * 0.4 * j1, 0)
		var t0 := top + d0 * r1
		var t1 := top + d1 * r1
		var n0 := (d0 * h + Vector3(0, r0 - r1, 0)).normalized()
		var n1 := (d1 * h + Vector3(0, r0 - r1, 0)).normalized()
		tri(st, [b0, t1, b1], [n0, n1, n1], [c0, c1, c0])
		if r1 > 0.0:
			tri(st, [b0, t0, t1], [n0, n0, n1], [c0, c1, c1])
		if skirt:
			# the underside of the tier, dark, so you can't see into it from below
			var mid := base + Vector3(0, h * 0.25, 0)
			var dk := c0.darkened(0.45)
			tri(st, [b0, b1, mid], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [dk, dk, c0.darkened(0.55)])

static func _limb(st: SurfaceTool, from: Vector3, dir: Vector3, length: float, r: float, c0: Color, c1: Color) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var to := from + dir * length
	for k in 4:
		var a0 := k * TAU / 4.0
		var a1 := (k + 1) * TAU / 4.0
		var o0 := (side * cos(a0) + up * sin(a0))
		var o1 := (side * cos(a1) + up * sin(a1))
		tri(st, [from + o0 * r, to + o1 * r * 0.2, from + o1 * r], [o0, o1, o1], [c0, c1, c0])
		tri(st, [from + o0 * r, to + o0 * r * 0.2, to + o1 * r * 0.2], [o0, o0, o1], [c0, c1, c1])

# one triangle, wound so its front faces the way its normals point (Godot's front faces are clockwise)
static func tri(st: SurfaceTool, p: Array, n: Array, c: Array) -> void:
	var nn: Vector3 = n[0] + n[1] + n[2]
	var order := [0, 1, 2]
	if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(nn) > 0.0:
		order = [0, 2, 1]
	for k in order:
		_v(st, p[k], n[k], c[k])

static func _v(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)
