# Picks the loose pieces of a chunk file's merged meshes for data/settle.json: every triangle inside a box (world
# x0 x1 z0 z1, and higher than y_min), by mesh, with how far to drop them. Used for floating roofs reported in play.
#   godot --headless --path . -s tools/settle/pick.gd -- c_6_9 b_1097 -95.5 -84.5 113.5 124.5 -6.3 1.25
extends SceneTree
func _init():
	var a := OS.get_cmdline_user_args()
	var fname := a[0]
	var mesh := a[1]
	var x0 := float(a[2])
	var x1 := float(a[3])
	var z0 := float(a[4])
	var z1 := float(a[5])
	var ymin := float(a[6])
	var drop := float(a[7])
	var n: Node3D = (load("res://data/world/%s.glb" % fname) as PackedScene).instantiate()
	var out: Dictionary = {}
	if FileAccess.file_exists("res://data/settle.json"):
		out = JSON.parse_string(FileAccess.get_file_as_string("res://data/settle.json"))
	for c in n.find_children(mesh, "MeshInstance3D", true, false):
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
			var picked := {}
			for ti in range(0, I.size(), 3):
				var ok := true
				for k in 3:
					var p: Vector3 = t * V[I[ti + k]]
					if p.x < x0 or p.x > x1 or p.z < z0 or p.z > z1 or p.y < ymin:
						ok = false
				if ok:
					for k in 3:
						picked[int(I[ti + k])] = true
			if not picked.is_empty():
				var key := String(n.get_path_to(mi)) + "#" + str(si)
				out.get_or_add(fname, {})[key] = [[picked.keys(), drop]]
				print("SETTLE ", fname, " ", key, " vertices ", picked.size(), " drop ", drop)
	var f := FileAccess.open("res://data/settle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	n.free()
	quit()
