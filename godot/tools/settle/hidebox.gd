# Folds away every chunk triangle that lies wholly inside a world box (all chunk files that could hold it), writing
# data/settle.json "hide" pieces. Used where a building is rebuilt by hand (build 17: the Meridian reactor's north
# wall, opened into the new containment hall).
#   godot --headless --path . -s tools/settle/hidebox.gd -- x0 x1 z0 z1 y0 y1 [tag]
extends SceneTree
func _init():
	var a := OS.get_cmdline_user_args()
	var x0 := float(a[0]); var x1 := float(a[1]); var z0 := float(a[2]); var z1 := float(a[3]); var y0 := float(a[4]); var y1 := float(a[5])
	var tag := String(a[6]) if a.size() > 6 else "box"
	var out: Dictionary = {}
	if FileAccess.file_exists("res://data/settle.json"):
		out = JSON.parse_string(FileAccess.get_file_as_string("res://data/settle.json"))
	var files := {}
	for xx in [x0, x1]:
		for zz in [z0, z1]:
			var i := int(floor((xx + 500.0) / 64.0)); var j := int(floor((zz + 500.0) / 64.0))
			for di in [-1, 0, 1]:
				for dj in [-1, 0, 1]:
					files["c_%d_%d" % [i + di, j + dj]] = true
	for fname in files:
		if not FileAccess.file_exists("res://data/world/%s.glb" % fname):
			continue
		var n: Node3D = (load("res://data/world/%s.glb" % fname) as PackedScene).instantiate()
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var t := Transform3D.IDENTITY
			var x: Node = mi
			while x != null and x != n:
				t = (x as Node3D).transform * t
				x = x.get_parent()
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var I = arr[Mesh.ARRAY_INDEX]
				if I == null or I.is_empty():
					continue
				var picked := {}
				var tris := 0
				for ti in range(0, I.size(), 3):
					var ok := true
					for k in 3:
						var p: Vector3 = t * V[I[ti + k]]
						if p.x < x0 or p.x > x1 or p.z < z0 or p.z > z1 or p.y < y0 or p.y > y1:
							ok = false
							break
					if ok:
						tris += 1
						for k in 3:
							picked[int(I[ti + k])] = true
				if not picked.is_empty():
					# a vertex shared with a triangle outside the box would drag that one in too: leave those
					for ti in range(0, I.size(), 3):
						var inside := true
						for k in 3:
							var p: Vector3 = t * V[I[ti + k]]
							if p.x < x0 or p.x > x1 or p.z < z0 or p.z > z1 or p.y < y0 or p.y > y1:
								inside = false
						if not inside:
							for k in 3:
								picked.erase(int(I[ti + k]))
					var key := String(n.get_path_to(mi)) + "#" + str(si)
					var L: Array = (out.get_or_add(fname, {}) as Dictionary).get_or_add(key, [])
					L.assign(L.filter(func(p): return not (p.size() > 3 and String(p[3]) == tag)))
					if not picked.is_empty():
						L.append([picked.keys(), 0, "hide", tag])
					print("HIDE ", fname, " ", key, " tris ", tris, " verts ", picked.size(), " of ", V.size())
		n.free()
	var f := FileAccess.open("res://data/settle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
