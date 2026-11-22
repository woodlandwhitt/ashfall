# Gun lab: each gun model side-on (muzzle to the right) with its bounds divided into tenths, for reading off where the
# hands go (Humanoid.GRIPS). Not part of the game. Run: godot --path . res://tools/gunside.tscn -- OUTDIR
extends Node3D
func _ready():
	var out: String = OS.get_cmdline_user_args()[0]
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.85, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.9, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = Color(1, 0, 0, 0.55)
	line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.no_depth_test = true
	var gf: Dictionary = Game.DB.gunfit
	for glb in gf:
		var f: Dictionary = gf[glb]
		var fit := Basis.IDENTITY
		if f.has("k"):
			fit = Basis(Vector3.UP, float(f.get("ry", 0.0))).scaled(Vector3.ONE * float(f.k))
		var holder := Node3D.new()
		add_child(holder)
		var g := (load("res://guns/" + glb + ".glb") as PackedScene).instantiate() as Node3D
		g.transform = Transform3D(fit, Vector3.ZERO)
		holder.add_child(g)
		var bb := Humanoid.gun_bounds(g)
		bb = Transform3D(fit, Vector3.ZERO) * bb
		# muzzle is -Z: look from +X so -Z is to the right
		var L := bb.size.z
		var H := bb.size.y
		cam.size = maxf(L, H * 1.78) * 1.08
		cam.rotation = Vector3(0, PI / 2, 0)
		cam.position = Vector3(bb.end.x + 2.0, bb.get_center().y, bb.get_center().z)
		for i in 11:
			var v := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.001, H, L * 0.004)
			v.mesh = bm
			v.material_override = line
			v.position = Vector3(bb.end.x + 0.5, bb.get_center().y, bb.end.z - L * i / 10.0)   # i/10 from the rear (+Z end)
			holder.add_child(v)
			var h := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.001, H * 0.006, L)
			h.mesh = hm
			h.material_override = line
			h.position = Vector3(bb.end.x + 0.5, bb.end.y - H * i / 10.0, bb.get_center().z)
			holder.add_child(h)
		for _i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "/side_" + glb + ".png")
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()
