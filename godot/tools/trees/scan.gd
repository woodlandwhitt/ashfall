extends SceneTree
# Finds the old map's dead trees (meshes wearing the mossy bark texture) in every chunk and works out where each tree
# stands and how tall it is, from the mesh's own vertices: its trunk base (the lowest ring of vertices) and its top.
# Writes res://data/deadtrees.json: {chunk: {"meshes": [node paths], "trees": [[x, y, z, height, yaw, lean], ...]}}
const BARK := "a527a144"
func _init() -> void:
	var out := {}
	var d := DirAccess.open("res://data/world")
	var files: Array = []
	for f in d.get_files():
		if f.begins_with("c_") and f.ends_with(".glb"):
			files.append(f)
	files.sort()
	var ntree := 0
	var nlog := 0
	for f in files:
		var ps := load("res://data/world/" + f) as PackedScene
		if ps == null:
			continue
		var root := ps.instantiate() as Node3D
		var meshes: Array = []
		var pts := PackedVector3Array()
		for c in root.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var bark := false
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture and String((m as StandardMaterial3D).albedo_texture.resource_path).contains(BARK):
					bark = true
				elif m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture and String((m as StandardMaterial3D).albedo_texture.resource_name).contains(BARK):
					bark = true
			if not bark:
				continue
			# its transform up to the chunk root
			var t := Transform3D.IDENTITY
			var x: Node = mi
			while x != null and x != root:
				t = (x as Node3D).transform * t
				x = x.get_parent()
			meshes.append(String(root.get_path_to(mi)))
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					pts.append(t * v)
		if meshes.is_empty():
			root.free()
			continue
		# trees by the ground plan: vertices binned on a 0.6 m grid, the bins joined into clumps; the trunk of each clump
		# is its lowest, tightest part
		var cell := 0.6
		var bins := {}
		for p in pts:
			var k := Vector2i(floori(p.x / cell), floori(p.z / cell))
			if not bins.has(k):
				bins[k] = [INF, -INF, 0, Vector3.ZERO]
			var b: Array = bins[k]
			b[0] = minf(b[0], p.y)
			b[1] = maxf(b[1], p.y)
			b[2] += 1
			b[3] += p
		# trunk bins: those holding vertices down at the clump's foot
		var trees: Array = []
		var used := {}
		var keys: Array = bins.keys()
		# lowest first
		keys.sort_custom(func(a, b): return bins[a][0] < bins[b][0])
		for k in keys:
			if used.has(k):
				continue
			# the clump round it: bins within 4.5 m
			var lo: float = bins[k][0]
			var hi: float = bins[k][1]
			var foot := Vector3.ZERO
			var fn := 0
			for dx in range(-8, 9):
				for dz in range(-8, 9):
					var kk := Vector2i(k.x + dx, k.y + dz)
					if not bins.has(kk) or used.has(kk):
						continue
					var b: Array = bins[kk]
					hi = maxf(hi, b[1])
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var kk := Vector2i(k.x + dx, k.y + dz)
					if bins.has(kk) and float(bins[kk][0]) < lo + 0.6:
						foot += Vector3((kk.x + 0.5) * cell, bins[kk][0], (kk.y + 0.5) * cell) * float(bins[kk][2])
						fn += int(bins[kk][2])
			for dx in range(-8, 9):
				for dz in range(-8, 9):
					used[Vector2i(k.x + dx, k.y + dz)] = true
			if fn == 0:
				continue
			foot /= fn
			var h := hi - lo
			if h < 2.0:
				nlog += 1
				trees.append([snappedf(foot.x, 0.01), snappedf(lo, 0.01), snappedf(foot.z, 0.01), snappedf(h, 0.01), 0])
				continue
			ntree += 1
			trees.append([snappedf(foot.x, 0.01), snappedf(lo, 0.01), snappedf(foot.z, 0.01), snappedf(h, 0.01), 1])
		out[f.get_basename()] = {"meshes": meshes, "trees": trees, "verts": pts.size()}
		root.free()
	var fo := FileAccess.open("res://data/deadtrees.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify(out))
	fo.close()
	print("TREES chunks %d, trees %d, short pieces %d" % [out.size(), ntree, nlog])
	quit()
