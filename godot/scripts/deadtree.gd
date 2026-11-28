class_name DeadTree
# The old map's dead trees, remade (build 24). Their branches were flat boards stood off the trunk, so they read as
# broken. Each one is now a grown tree: a tapering, slightly crooked trunk, limbs that start inside it and taper out
# and up, forks at their ends, a snapped-off top, all in the same mossy bark, wrapped round rather than stretched.
# Where they stand and how tall comes from the old meshes themselves (data/deadtrees.json, tools/trees/scan.gd).

const BARK := "res://data/world/tex/a527a144-e699.webp"
const VARIANTS := 5
static var _meshes: Array = []
static var _stump: Mesh
static var _mat: StandardMaterial3D
static var _data: Dictionary = {}
static var _loaded := false

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists("res://data/deadtrees.json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/deadtrees.json"))
			if j is Dictionary:
				_data = j
	return _data

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load(BARK)
		_mat.albedo_color = Color(0.86, 0.84, 0.8)
		_mat.roughness = 0.95
		_mat.vertex_color_use_as_albedo = true
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _mat

# a tree 1 m tall (scaled to the old one's height where it's planted)
static func mesh(v: int) -> Mesh:
	if _meshes.is_empty():
		for i in VARIANTS:
			_meshes.append(_grow(i))
	return _meshes[v % VARIANTS]

static func stump() -> Mesh:
	if _stump == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		_tube(st, [Vector3(0, -0.15, 0), Vector3(0.02, 0.5, 0.01), Vector3(0.03, 1.0, 0.0)], [0.34, 0.27, 0.22], 9, rng, 0.0, true)
		st.generate_normals()
		st.generate_tangents()
		_stump = st.commit()
		_stump.surface_set_material(0, material())
	return _stump

static func _grow(seed_i: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + seed_i * 97
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the trunk: a crooked spine, thick at the foot (a flare into the ground) and narrowing to a snapped top
	var spine: Array = []
	var radii: Array = []
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.0, 0.05)
	var p := Vector3(0, -0.06, 0)
	var segs := 7
	for i in segs + 1:
		var f := float(i) / segs
		spine.append(p)
		var r := lerpf(0.055, 0.012, pow(f, 0.8))
		if i == 0:
			r *= 1.5
		radii.append(r)
		p += Vector3(0, 1.0 / segs, 0) + lean / segs + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 0.018
	_tube(st, spine, radii, 9, rng, 0.0, false)
	# limbs out of the trunk, round it in a spiral, each from inside the bark, tapering, bending upward
	var n := rng.randi_range(6, 9)
	var a0 := rng.randf() * TAU
	for b in n:
		var f := lerpf(0.32, 0.86, float(b) / maxf(1, n - 1)) + rng.randf_range(-0.04, 0.04)
		var at := _along(spine, f)
		var rr := lerpf(0.055, 0.012, pow(f, 0.8))
		var ang := a0 + b * 2.4 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0, sin(ang))
		var up := rng.randf_range(0.35, 1.1)
		var dir := (out + Vector3.UP * up).normalized()
		var length := lerpf(0.5, 0.2, f) * rng.randf_range(0.8, 1.2)
		var r0 := rr * rng.randf_range(0.55, 0.75)
		_limb(st, at - out * rr * 0.5, dir, length, r0, rng, 2)
	# a couple of twigs high up, where the top snapped
	for t in 2:
		var at2 := _along(spine, rng.randf_range(0.9, 0.98))
		var ang2 := rng.randf() * TAU
		_limb(st, at2, (Vector3(cos(ang2), 1.3, sin(ang2))).normalized(), rng.randf_range(0.08, 0.14), 0.008, rng, 0)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, material())
	return m

static func _along(spine: Array, f: float) -> Vector3:
	var x := f * (spine.size() - 1)
	var i := clampi(int(x), 0, spine.size() - 2)
	return (spine[i] as Vector3).lerp(spine[i + 1], x - i)

# a limb: a few bent segments, tapering, and on longer ones a fork or two near the end
static func _limb(st: SurfaceTool, from: Vector3, dir: Vector3, length: float, r0: float, rng: RandomNumberGenerator, forks: int) -> void:
	var pts: Array = [from]
	var rs: Array = [r0]
	var d := dir
	var p := from
	var segs := 4
	for i in segs:
		d = (d + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, 0.18), rng.randf_range(-0.25, 0.25))).normalized()
		p += d * length / segs
		pts.append(p)
		rs.append(lerpf(r0, r0 * 0.12, float(i + 1) / segs))
	_tube(st, pts, rs, 6, rng, 0.0, false)
	for k in forks:
		var f := rng.randf_range(0.45, 0.8)
		var at := _along(pts, f)
		var side := d.cross(Vector3.UP).normalized() * (1.0 if k % 2 == 0 else -1.0)
		var fd := (d + side * rng.randf_range(0.6, 1.1) + Vector3.UP * 0.4).normalized()
		_limb(st, at, fd, length * rng.randf_range(0.3, 0.45), lerpf(r0, r0 * 0.12, f) * 0.8, rng, 0)

# a tube along points with radii, closed at the far end with a point; bark wraps round it (u) and runs along it (v)
static func _tube(st: SurfaceTool, pts: Array, rs: Array, sides: int, rng: RandomNumberGenerator, _twist: float, cap_top: bool) -> void:
	var rings: Array = []
	var vlen := 0.0
	var vs: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		if i > 0:
			vlen += (pts[i] as Vector3).distance_to(pts[i - 1])
		vs.append(vlen)
		var ref := Vector3.RIGHT if absf(t.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var nx := t.cross(ref).normalized()
		var nz := t.cross(nx).normalized()
		var ring: Array = []
		var r: float = rs[i]
		for s in sides + 1:
			var a := TAU * s / sides
			# bark isn't round: a little knobbly
			var rr := r * (1.0 + 0.08 * sin(a * 3.0 + i * 1.7))
			ring.append(p + (nx * cos(a) + nz * sin(a)) * rr)
		rings.append(ring)
	# the bark's scale: one wrap of the texture round about 0.35 of a unit of girth
	var circ: float = TAU * float(rs[0])
	var u_scale := maxf(0.25, circ / 0.18)
	for i in pts.size() - 1:
		var shade0 := lerpf(0.72, 1.0, clampf(float(i) / maxf(1, pts.size() - 2), 0.0, 1.0))
		var shade1 := lerpf(0.72, 1.0, clampf(float(i + 1) / maxf(1, pts.size() - 2), 0.0, 1.0))
		for s in sides:
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][s + 1]
			var c: Vector3 = rings[i + 1][s + 1]
			var dd: Vector3 = rings[i + 1][s]
			var u0 := float(s) / sides * u_scale
			var u1 := float(s + 1) / sides * u_scale
			var v0: float = vs[i] * 2.2
			var v1: float = vs[i + 1] * 2.2
			_vx(st, a, Vector2(u0, v0), shade0)
			_vx(st, c, Vector2(u1, v1), shade1)
			_vx(st, b, Vector2(u1, v0), shade0)
			_vx(st, a, Vector2(u0, v0), shade0)
			_vx(st, dd, Vector2(u0, v1), shade1)
			_vx(st, c, Vector2(u1, v1), shade1)
	# the end: drawn to a point (a limb) or a flat broken top (a stump)
	var last: Array = rings[rings.size() - 1]
	var tip: Vector3 = pts[pts.size() - 1]
	if not cap_top:
		var t2: Vector3 = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		tip += t2 * float(rs[rs.size() - 1]) * 2.0
	for s in sides:
		_vx(st, last[s], Vector2(float(s) / sides, 0), 1.0)
		_vx(st, last[s + 1], Vector2(float(s + 1) / sides, 0), 1.0)
		_vx(st, tip, Vector2(0.5, 0.15), 0.9)

static func _vx(st: SurfaceTool, p: Vector3, uv: Vector2, shade: float) -> void:
	st.set_color(Color(shade, shade, shade))
	st.set_uv(uv)
	st.add_vertex(p)

# a chunk's dead trees: the old meshes hidden, the new trees planted where they stood
static func plant(root: Node3D, fname: String) -> void:
	var D := data()
	if not D.has(fname):
		return
	var e: Dictionary = D[fname]
	for path in e.get("meshes", []):
		for c in root.get_children():
			var n := c.get_node_or_null(NodePath(String(path)))
			if n is MeshInstance3D:
				(n as MeshInstance3D).visible = false
				break
	var by: Array = []
	for v in VARIANTS + 1:
		by.append([])
	for t in e.get("trees", []):
		var h := float(t[3])
		var x := float(t[0])
		var z := float(t[2])
		var hsh := absi(int(x * 7.0) * 31 + int(z * 13.0))
		var yaw := float(hsh % 628) / 100.0
		var b := Basis(Vector3.UP, yaw)
		var pos := Vector3(x, float(t[1]), z)
		if int(t[4]) == 1:
			# as tall as the old tree, a touch thicker for the taller ones so they don't go spindly
			var sx := h * (1.0 + clampf((h - 8.0) * 0.02, -0.1, 0.15))
			by[hsh % VARIANTS].append(Transform3D(b.scaled(Vector3(sx, h, sx)), pos))
		elif h >= 0.5:
			by[VARIANTS].append(Transform3D(b.scaled(Vector3(1.0, clampf(h, 0.5, 1.8), 1.0)), pos))
	for v in by.size():
		var list: Array = by[v]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = stump() if v == VARIANTS else mesh(v)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "DeadTrees%d" % v
		mmi.multimesh = mm
		mmi.visibility_range_end = 420.0
		root.add_child(mmi)
