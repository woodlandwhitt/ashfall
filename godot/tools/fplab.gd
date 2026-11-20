# First-person lab: what the player's arms look like, against a plain backdrop (not part of the game).
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
	var vm := Viewmodel.new(); cam.add_child(vm)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("grip="):
			var v := a.trim_prefix("grip=").split(",")
			Viewmodel.GRIP = Vector3(float(v[0]), float(v[1]), float(v[2]))
	vm.setup(load("res://guns/Pistol_4.glb"))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("off="):
			var v := a.trim_prefix("off=").split(",")
			vm.rig.position = vm.base_pos + Vector3(float(v[0]), float(v[1]), float(v[2]))
		if a.begins_with("pitch="):
			cam.rotation.x = float(a.trim_prefix("pitch="))
	if args.size() > 1:
		if args[1] == "reload": vm.reload(1.3)
		if args[1] == "shoot": vm.shoot()
	for i in 8: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
