# Character lab: a lineup of the Quaternius-built people for screenshots (not part of the game).
extends Node3D
func _ready():
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.5, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.66, 0.6)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-150), 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.6, 0.52, 0.4); floor.material_override = fm
	add_child(floor)
	var anims := ["Idle_Loop", "Walk_Loop", "Pistol_Aim_Neutral", "Idle_Talking_Loop"]
	var cloths := [Color(0.75, 0.68, 0.55), Color(0.55, 0.45, 0.4), Color(0.8, 0.72, 0.62), Color(0.5, 0.5, 0.45)]
	var skins := [Color(1, 0.92, 0.85), Color(0.75, 0.6, 0.5), Color(1.05, 0.95, 0.9), Color(0.6, 0.45, 0.38)]
	for i in 4:
		var h := Humanoid.build(Humanoid.OUTFITS[i], cloths[i], skins[i])
		h.position = Vector3(-2.4 + i * 1.6, 0, 0)
		add_child(h)
		var ap := h.get_node("AnimationPlayer") as AnimationPlayer
		ap.play(anims[i])
		ap.seek(0.6, true)
		if i == 2:
			Humanoid.hold(h, load("res://guns/Pistol_4.glb"), Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121), Vector3.ZERO))
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 4.6)
	cam.rotation.x = -0.08
	cam.fov = 55
	add_child(cam)
	cam.current = true
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
