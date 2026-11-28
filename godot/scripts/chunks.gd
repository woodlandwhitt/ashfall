# World streaming. The map is a grid of 64 m chunks. Every chunk always has a coarse 8 m ground mesh (cheap, for
# the horizon). Chunks near the player also get a detailed 2 m ground mesh, grass, their buildings and props (one
# GLB each, loaded on a worker thread) and their people (spawned by main). Chunks that fall out of range are freed.
extends Node3D

const SIZE := 64.0
var files: Dictionary = {}       # "i_j" -> world GLB path
var loaded: Dictionary = {}      # "i_j" -> Node3D holding that chunk's detail
var pending: Dictionary = {}     # "i_j" -> path (threaded load requested)
var queue: Array = []            # keys waiting to be built, nearest first
var ready_scenes: Dictionary = {}
var load_r := 2
var on_built: Callable    # called with each chunk's node once its models are in (interiors relight them)
var small_range := 70.0
var big_range := 320.0
var grass_range := 38.0
var check_t := 0.0
var nx := 0
var nz := 0
var coarse: Dictionary = {}      # "i_j" -> MeshInstance3D (8 m ground)
var mask_img: Image
var terrain_mat: Material
var grass_mesh: Mesh
var on_enter: Callable           # main spawns people for a chunk
var on_leave: Callable

func setup(mat: Material, mask: Image, grass: Mesh) -> void:
	terrain_mat = mat
	mask_img = mask
	grass_mesh = grass
	nx = int(ceil((Game.hw - 1) / SIZE))
	nz = int(ceil((Game.hd - 1) / SIZE))
	# the world's chunk files are named on the grid of the map they were exported with; the map has since grown
	# north (build 16), so their row numbers move by however many chunks it grew
	var go: Array = Game.region.get("glb_origin", [Game.x0, Game.z0])
	var di := roundi((float(go[0]) - Game.x0) / SIZE)
	var dj := roundi((float(go[1]) - Game.z0) / SIZE)
	var dir := DirAccess.open(Game.dir() + "world")
	if dir:
		for f in dir.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.ends_with(".glb") and f.begins_with("c_"):
				var ij := f.trim_prefix("c_").trim_suffix(".glb").split("_")
				files[str(int(ij[0]) + di) + "_" + str(int(ij[1]) + dj)] = Game.dir() + "world/" + f
	# the coarse ground of every chunk: its node now, its mesh (and far trees) a few at a time over the next frames,
	# nearest first (build 24: building them all at once froze the loading screen for seconds)
	for j in nz:
		for i in nx:
			var k := str(i) + "_" + str(j)
			var mi := MeshInstance3D.new()
			if Game.interior():
				mi.visible = false
				add_child(mi)
				coarse[k] = mi
				continue
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			coarse[k] = mi
			coarse_todo.append(k)
	# under the test hooks (no loading screen to wait behind) it's all built now, as before
	if LoadScreen.quiet():
		build_coarse(Vector3.ZERO, 1000000)

var coarse_todo: Array = []
var coarse_total := 0
# build the coarse ground for up to a few milliseconds' worth of chunks, the ones nearest p first
func build_coarse(p: Vector3, budget_ms := 6) -> void:
	if coarse_todo.is_empty():
		return
	if coarse_total == 0:
		coarse_total = coarse_todo.size()
		coarse_todo.sort_custom(func(x, y): return _dist(x, p) < _dist(y, p))
	var t0 := Time.get_ticks_msec()
	while not coarse_todo.is_empty() and Time.get_ticks_msec() - t0 < budget_ms:
		var k: String = coarse_todo.pop_front()
		var ij := k.split("_")
		var mi: MeshInstance3D = coarse[k]
		mi.mesh = _ground(int(ij[0]), int(ij[1]), 8)
		if Game.area == "world":
			Flora.far(mi, int(ij[0]), int(ij[1]), SIZE, mask_img)

func set_material(mat: Material) -> void:
	terrain_mat = mat
	for k in coarse:
		coarse[k].material_override = mat
	for k in loaded:
		var g: MeshInstance3D = loaded[k].get_node_or_null("Ground")
		if g:
			g.material_override = mat

func configure(radius: int, small_r: float, big_r: float, grass_r: float) -> void:
	load_r = radius
	small_range = small_r
	big_range = big_r
	grass_range = grass_r
	for k in loaded:
		_tune(loaded[k])
	check_t = 0.0

# a ground mesh for one chunk at the given grid step (metres), in world coordinates
func _ground(i: int, j: int, step: int) -> ArrayMesh:
	var x0 := Game.x0 + i * SIZE
	var z0 := Game.z0 + j * SIZE
	var n := int(SIZE / step) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for b in n:
		for a in n:
			var x := x0 + a * step
			var z := z0 + b * step
			var k := b * n + a
			verts[k] = Vector3(x, Game.height(x, z), z)
			norms[k] = Vector3(Game.height(x - 1.0, z) - Game.height(x + 1.0, z), 2.0, Game.height(x, z - 1.0) - Game.height(x, z + 1.0)).normalized()
			uvs[k] = Vector2(x, z)
	var idx := PackedInt32Array()
	for b in n - 1:
		for a in n - 1:
			var q := b * n + a
			idx.append_array([q, q + 1, q + n, q + 1, q + n + 1, q + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_tangents()
	return st.commit()

# rooms that sit in the open map with a floor of their own (the Silver Spur's sunken hall): no grass through the carpet
const NO_GRASS := [[2.6, 21.4, 59.1, 72.9]]
static func _no_grass(x: float, z: float) -> bool:
	for r in NO_GRASS:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]:
			return true
	return false

func _grass(i: int, j: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + j * 104729
	var xf := PackedFloat32Array()
	var n := 0
	for s in 2200:
		var x := Game.x0 + i * SIZE + rng.randf() * SIZE
		var z := Game.z0 + j * SIZE + rng.randf() * SIZE
		var mk := mask_img.get_pixel(clampi(int(x - Game.x0), 0, mask_img.get_width() - 1), clampi(int(z - Game.z0), 0, mask_img.get_height() - 1))
		if mk.r > 0.15 or mk.g > 0.5:
			continue
		if _no_grass(x, z):
			continue
		var clump := sin(x * 0.13) * cos(z * 0.11) + sin(x * 0.041 + z * 0.037)
		if clump < -0.2 + rng.randf() * 0.6:
			continue
		var h := Game.height(x, z)
		if absf(Game.height(x + 1.0, z) - h) > 0.6 or absf(Game.height(x, z + 1.0) - h) > 0.6:
			continue
		var sc := rng.randf_range(0.7, 1.3)
		var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc))
		xf.append_array([bs.x.x, bs.y.x, bs.z.x, x, bs.x.y, bs.y.y, bs.z.y, h - 0.03, bs.x.z, bs.y.z, bs.z.z, z])
		var c := rng.randf_range(0.75, 1.1)
		xf.append_array([c, c * rng.randf_range(0.92, 1.05), c * 0.9, 1.0])
		n += 1
	if n == 0:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = grass_mesh
	mm.instance_count = n
	mm.buffer = xf
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _key_at(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - Game.x0) / SIZE)), int(floor((p.z - Game.z0) / SIZE)))

func loaded_keys() -> Array:
	return loaded.keys()

func key_of(p: Vector3) -> String:
	var c := _key_at(p)
	return str(c.x) + "_" + str(c.y)

func wanted(p: Vector3) -> Array:
	var c := _key_at(p)
	var out: Array = []
	for j in range(-load_r, load_r + 1):
		for i in range(-load_r, load_r + 1):
			var a := c.x + i
			var b := c.y + j
			if a >= 0 and b >= 0 and a < nx and b < nz:
				out.append(str(a) + "_" + str(b))
	out.sort_custom(func(x, y): return _dist(x, p) < _dist(y, p))
	return out

func _dist(k: String, p: Vector3) -> float:
	var ij := k.split("_")
	return Vector2(Game.x0 + (int(ij[0]) + 0.5) * SIZE - p.x, Game.z0 + (int(ij[1]) + 0.5) * SIZE - p.z).length()

# blocking build of everything around a spot (start and after travel, behind the loading screen)
func load_now(p: Vector3, near_only := false) -> void:
	var c0 := _key_at(p)
	for k in wanted(p):
		if loaded.has(k):
			continue
		if near_only:
			# the ground you stand on and round you now; the rest streams in behind the loading screen
			var ij0: PackedStringArray = String(k).split("_")
			if absi(int(ij0[0]) - c0.x) > 1 or absi(int(ij0[1]) - c0.y) > 1:
				if not queue.has(k):
					if files.has(k) and not pending.has(k) and not ready_scenes.has(k):
						pending[k] = files[k]
						ResourceLoader.load_threaded_request(files[k], "PackedScene", true)
					queue.append(k)
				continue
		var ps: PackedScene = null
		if pending.has(k):
			# already loading on a worker thread: wait for that load rather than starting a second one
			ps = ResourceLoader.load_threaded_get(pending[k])
			pending.erase(k)
		elif ready_scenes.has(k):
			ps = ready_scenes[k]
			ready_scenes.erase(k)
		elif files.has(k):
			ps = load(files[k])
		queue.erase(k)
		_build(k, ps)

func _build(k: String, ps: PackedScene) -> void:
	if loaded.has(k):
		return
	var ij := k.split("_")
	var i := int(ij[0])
	var j := int(ij[1])
	var root := Node3D.new()
	root.name = "C" + k
	if not Game.interior():
		var g := MeshInstance3D.new()
		g.name = "Ground"
		# the same 1 m grid the heightmap (and so every prop, pickup and footstep) sits on, so nothing floats or sinks
		g.mesh = _ground(i, j, 1)
		g.material_override = terrain_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(g)
	if grass_range > 0.0 and not Game.interior():
		var gr := _grass(i, j)
		if gr:
			root.add_child(gr)
	if ps:
		root.add_child(ps.instantiate())
		if on_built.is_valid():
			on_built.call(root)
	if Game.area == "world":
		Flora.plant(root, i, j, SIZE, mask_img)
	add_child(root)
	if ps and Game.area == "world" and (Game.region.has("cut") or Game.region.has("cuts")):
		_settle_cut(root)
	if ps and Game.area == "world":
		_settle_slabs(root, String(files.get(k, "")).get_file().get_basename())
		DeadTree.plant(root, String(files.get(k, "")).get_file().get_basename())
	loaded[k] = root
	coarse[k].visible = false
	_tune(root)
	if on_enter.is_valid():
		on_enter.call(k)

# build 15 cut a road through the old east wall: the rocks and scrub that stood on the ground taken away there come
# down with it, and great slabs of the old cliff are hidden (region.cut: how far the ground dropped, 4 m grid, dm)
static func cut_at(x: float, z: float) -> float:
	var lo := _cut_one(Game.region.get("cut", {}), x, z)
	for C in Game.region.get("cuts", []):
		lo = maxf(lo, _cut_one(C, x, z))
	return lo

static func _cut_one(C: Dictionary, x: float, z: float) -> float:
	if C.is_empty():
		return 0.0
	var st := float(C.step)
	var fx := (x - float(C.x0)) / st
	var fz := (z - float(C.z0)) / st
	var w := int(C.w)
	var d := int(C.d)
	if fx < 0.0 or fz < 0.0 or fx > w - 1 or fz > d - 1:
		return 0.0
	var ix := mini(int(fx), w - 2)
	var iz := mini(int(fz), d - 2)
	var tx := fx - ix
	var tz := fz - iz
	var v: Array = C.v
	var a := lerpf(float(v[iz * w + ix]), float(v[iz * w + ix + 1]), tx)
	var b := lerpf(float(v[(iz + 1) * w + ix]), float(v[(iz + 1) * w + ix + 1]), tx)
	return lerpf(a, b, tz) * 0.1

# roof slabs the export left in mid-air come down onto whatever is under them (data/settle.json, from --roofscan:
# per chunk file, per mesh and surface, the vertices of each loose slab and how far it drops)
static var settle: Dictionary = {}
static var settle_loaded := false
func _settle_slabs(root: Node3D, fname: String) -> void:
	if not settle_loaded:
		settle_loaded = true
		if FileAccess.file_exists("res://data/settle.json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/settle.json"))
			if j is Dictionary:
				settle = j
	if not settle.has(fname):
		return
	for key in settle[fname]:
		# a whole prop that floats: lowered as one (build 24, --propscan)
		if String(key).begins_with("@"):
			for c in root.get_children():
				var pn := c.get_node_or_null(NodePath(String(key).substr(1)))
				if pn is Node3D:
					# straight down in the world, whatever its parents' frames
					var t := Transform3D.IDENTITY
					var x: Node = (pn as Node3D).get_parent()
					while x != null and x != root and x is Node3D:
						t = (x as Node3D).transform * t
						x = x.get_parent()
					(pn as Node3D).position += t.basis.inverse() * Vector3(0, -float(settle[fname][key]), 0)
					break
			continue
		var parts := String(key).split("#")
		var mi: Node = null
		for c in root.get_children():
			mi = c.get_node_or_null(NodePath(String(parts[0])))
			if mi:
				break
		if mi == null or not (mi is MeshInstance3D):
			continue
		var m: Mesh = (mi as MeshInstance3D).mesh
		var si := int(parts[1])
		# baked explosive drums: the whole little mesh is the drum, so it just goes (live drums replace them)
		var hide := false
		for piece in settle[fname][key]:
			if piece.size() > 2 and String(piece[2]) == "hide" and m.get_surface_count() == 1 and (piece[0] as Array).size() >= m.surface_get_array_len(0):
				hide = true
		if hide:
			mi.queue_free()
			continue
		var am := ArrayMesh.new()
		var inv := (mi as MeshInstance3D).global_transform.basis.inverse()
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			if s == si:
				var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for piece in settle[fname][key]:
					if piece.size() > 2:
						var at: Vector3 = V[int(piece[0][0])]
						for i in piece[0]:
							V[int(i)] = at
						continue
					var off: Vector3 = inv * Vector3(0, -float(piece[1]), 0)
					for i in piece[0]:
						V[int(i)] += off
				arr[Mesh.ARRAY_VERTEX] = V
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(s, m.surface_get_material(s))
		(mi as MeshInstance3D).mesh = am

func _settle_cut(root: Node3D) -> void:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.name == "Ground" or mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		var cc := ab.get_center()
		if maxf(ab.size.x, ab.size.z) > 12.0:
			var worst := 0.0
			for fx in [0.0, 0.5, 1.0]:
				for fz in [0.0, 0.5, 1.0]:
					worst = maxf(worst, cut_at(ab.position.x + ab.size.x * fx, ab.position.z + ab.size.z * fz))
			if worst > 3.0:
				mi.visible = false
			continue
		var lo := cut_at(cc.x, cc.z)
		if lo > 0.4:
			mi.global_position.y -= lo

func _tune(n: Node) -> void:
	if Game.area == "world":
		Weathering.apply(n)
		FireFX.dress(n)
	elif Game.area == "cells":
		# indoors only the painted props age; floors and walls have their own finish
		Weathering.apply(n, 0.6, true)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.name == "Ground":
			continue
		var small := mi.name.begins_with("s_")
		mi.visibility_range_end = small_range if small else big_range
		mi.visibility_range_end_margin = 6.0 if small else 20.0
		if small:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gr: Node = n.get_node_or_null("Grass")
	if gr:
		gr.visible = grass_range > 0.0
		gr.visibility_range_end = grass_range

func _unload(k: String) -> void:
	if on_leave.is_valid():
		on_leave.call(k)
	loaded[k].queue_free()
	loaded.erase(k)
	coarse[k].visible = true

func _process(d: float) -> void:
	if not coarse_todo.is_empty():
		var behind := LoadScreen._it != null and is_instance_valid(LoadScreen._it) and LoadScreen._it.visible
		build_coarse(Game.player.global_position if Game.player else Vector3.ZERO, 24 if behind else 5)
	# one chunk is built per frame, so streaming never costs more than one chunk's work in a frame
	if not queue.is_empty():
		var k: String = queue.pop_front()
		if not loaded.has(k):
			if files.has(k) and not ready_scenes.has(k):
				queue.push_front(k)   # its GLB is still loading
				_poll()
				return
			_build(k, ready_scenes.get(k))
			ready_scenes.erase(k)
	_poll()
	check_t -= d
	if check_t > 0.0 or Game.player == null:
		return
	check_t = 0.4
	var p: Vector3 = Game.player.global_position
	for k in wanted(p):
		if loaded.has(k) or queue.has(k):
			continue
		if files.has(k) and not pending.has(k) and not ready_scenes.has(k):
			pending[k] = files[k]
			ResourceLoader.load_threaded_request(files[k], "PackedScene", true)
		queue.append(k)
	queue.sort_custom(func(x, y): return _dist(x, p) < _dist(y, p))
	var c := _key_at(p)
	for k in loaded.keys():
		var ij: PackedStringArray = k.split("_")
		if absi(int(ij[0]) - c.x) > load_r + 1 or absi(int(ij[1]) - c.y) > load_r + 1:
			_unload(k)

func _poll() -> void:
	for k in pending.keys():
		var st := ResourceLoader.load_threaded_get_status(pending[k])
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			ready_scenes[k] = ResourceLoader.load_threaded_get(pending[k])
			pending.erase(k)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ready_scenes[k] = null
			pending.erase(k)

func count() -> int:
	return loaded.size()

# finish any GLB still loading on a worker thread before this node goes (scene reload on Load, or quit)
func _exit_tree() -> void:
	for k in pending.keys():
		ResourceLoader.load_threaded_get(pending[k])
	pending.clear()
