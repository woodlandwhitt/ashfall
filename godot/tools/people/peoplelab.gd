# People lab: a lineup of townsfolk and raiders as the game dresses them, for checking how clothes fit (not part of the game).
# args after --: out.png mode(npc|raider) seed0 [anim]
extends Node3D
func _ready():
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/people.png"
	var mode := args[1] if args.size() > 1 else "npc"
	var s0 := int(args[2]) if args.size() > 2 else 1
	var anim := args[3] if args.size() > 3 else "Idle"
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.5, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.66, 0.6)
	env.ambient_light_energy = 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-160), 0)
	sun.light_energy = 1.3
	add_child(sun)
	var n := int(args[4]) if args.size() > 4 else 6
	for i in n:
		var h: Node3D
		var seed := s0 * 100 + i
		if mode == "npc":
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var look := {"fem": rng.randf() < 0.4, "body": Color.from_hsv(rng.randf(), 0.3, 0.6).to_html(), "skin": ["#9e7356", "#c8a080", "#6e4c36", "#b58a68"][i % 4]}
			if i % 3 == 1:
				look["hat"] = ["wide", "cap", "hood"][rng.randi() % 3]
			h = Humanoid.person(look, seed)
		else:
			var P: Dictionary = (load("res://scripts/enemy.gd") as GDScript).get_script_constant_map()["PEOPLE"]
			h = Humanoid.enemy_person(mode, P[mode], seed)
		h.position = Vector3(-((n - 1) * 0.5) * 0.95 + i * 0.95, 0, 0)
		h.set_meta("i", i)
		h.rotation.y = 0.35 if i % 2 == 0 else -0.35
		add_child(h)
		var ap := h.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			Humanoid.play(ap, anim)
			ap.seek(0.5, true)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.4 if n > 3 else 1.9)
	cam.rotation.x = -0.05
	if args.size() > 5 and args[5] == "head":
		cam.position = Vector3(0, 1.55, 1.25)
		cam.rotation.x = -0.0
	cam.fov = 50
	add_child(cam)
	cam.current = true
	for k in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
