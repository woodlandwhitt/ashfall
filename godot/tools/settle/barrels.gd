# The WebView build's explosive drums were baked into the chunk files as plain scenery (a red drum with a glowing
# yellow plate) that bullets passed through. This finds each drum's triangles in the chunks around it and writes them
# to data/settle.json to be folded away; scripts/barrels.gd puts live drums in their place.
#   godot --headless --path . -s tools/settle/barrels.gd
extends SceneTree
func _init():
	var B: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/barrels.json"))
	var out: Dictionary = {}
	if FileAccess.file_exists("res://data/settle.json"):
		out = JSON.parse_string(FileAccess.get_file_as_string("res://data/settle.json"))
	# drop earlier drum picks so the tool can run twice
	for f in out:
		for key in out[f]:
			out[f][key] = (out[f][key] as Array).filter(func(p): return p.size() < 3)
	var by_file := {}
	for b in B:
		var i := int(floor((float(b.x) + 500.0) / 64.0))
		var j := int(floor((float(b.z) + 500.0) / 64.0))
		for di in [-1, 0, 1]:
			for dj in [-1, 0, 1]:
				by_file.get_or_add("c_%d_%d" % [i + di, j + dj], []).append(b)
	var found := {}
	for fname in by_file:
		if not FileAccess.file_exists("res://data/world/%s.glb" % fname):
			continue
		var n: Node3D = (load("res://data/world/%s.glb" % fname) as PackedScene).instantiate()
		for c in n.find_children("s_*", "MeshInstance3D", true, false):
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
				for b in by_file[fname]:
					var bx := float(b.x)
					var bz := float(b.z)
					var by := float(b.y)
					for ti in range(0, I.size(), 3):
						var ok := true
						for k in 3:
							var p: Vector3 = t * V[I[ti + k]]
							if Vector2(p.x - bx, p.z - bz).length() > 0.42 or p.y < by - 0.15 or p.y > by + 1.2:
								ok = false
								break
						if ok:
							for k in 3:
								picked[int(I[ti + k])] = true
							found[b.id] = int(found.get(b.id, 0)) + 1
				if not picked.is_empty():
					var key := String(n.get_path_to(mi)) + "#" + str(si)
					(out.get_or_add(fname, {}) as Dictionary).get_or_add(key, []).append([picked.keys(), 0, "hide"])
					print("DRUM ", fname, " ", key, " vertices ", picked.size())
		n.free()
	for b in B:
		print("barrel ", b.id, " triangles ", found.get(b.id, 0))
	var f := FileAccess.open("res://data/settle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
