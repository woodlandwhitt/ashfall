# prints each model's bounds: godot --headless --path . -s res://tools/bounds.gd -- res://guns/x.glb ...
extends SceneTree
func _init():
	for p in OS.get_cmdline_user_args():
		var n := (load(p) as PackedScene).instantiate() as Node3D
		root.add_child(n)
		var bb := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var t := Transform3D.IDENTITY
			var x: Node = m
			while x != n:
				t = (x as Node3D).transform * t
				x = x.get_parent()
			var b := t * m.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		print(p.get_file(), " pos ", bb.position.snapped(Vector3.ONE*0.001), " size ", bb.size.snapped(Vector3.ONE*0.001))
		n.free()
	quit()
