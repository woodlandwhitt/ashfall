# Every gun in first person, one image each (not part of the game): godot --path . res://tools/fpall.tscn -- OUTDIR [ids]
extends Node3D
func _ready():
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.66, 0.6); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-150), 0); sun.light_energy = 1.3; add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.6, 0.52, 0.4); floor.material_override = fm; add_child(floor)
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.62, 0); cam.fov = 75; cam.near = 0.03; add_child(cam); cam.current = true
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var ids: Array = []
	if args.size() > 1:
		ids = Array(args[1].split(","))
	else:
		for k in Game.DB.items:
			var it: Dictionary = Game.DB.items[k]
			if String(it.get("t", "")) == "weapon":
				ids.append(k)
	for id in ids:
		var vm := Viewmodel.new(); cam.add_child(vm)
		var mdl: Array = preload("res://scripts/player.gd").model_for(id)
		if mdl.is_empty():
			vm.setup_melee(true, id)
		else:
			vm.setup(load(mdl[0]), mdl[1], mdl[2])
		for i in 6: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "/fp_" + id + ".png")
		vm.queue_free()
		await get_tree().process_frame
	get_tree().quit()
