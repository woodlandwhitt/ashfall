# The Dustwell slice: builds the region exported from the WebView build (terrain, buildings and props, colliders,
# pools, lamps, grass), spawns the player, townsfolk and hostiles, bakes a navigation mesh, and runs interaction,
# dialogue and the little bits of effects (impacts, blood, tracers).
extends Node3D

var hud
var player
var npcs: Array = []
var enemies: Array = []
var sun: DirectionalLight3D
var env: Environment
var nav_region: NavigationRegion3D
var dialog_npc = null
var dialog_node := ""
var dialog_opts: Array = []
var pools: Array = []
var well := Vector3.ZERO
var dens := Vector3.ZERO
var start_pos := Vector3.ZERO
var talk_cd := 0.0

func _ready() -> void:
	Game.main = self
	var R: Dictionary = Game.region
	_environment()
	_terrain()
	_world()
	_colliders()
	_pools()
	_lamps()
	_grass()
	for p in R.points:
		if p.id == "well":
			well = Vector3(p.x, Game.height(p.x, p.z), p.z)
	if R.locs.has("dens"):
		dens = Vector3(R.locs.dens.x, Game.height(R.locs.dens.x, R.locs.dens.z), R.locs.dens.z)
	start_pos = Vector3(R.start.x, Game.height(R.start.x, R.start.z) + 0.2, R.start.z)
	player = preload("res://scripts/player.gd").new()
	player.position = start_pos
	player.yaw = PI
	add_child(player)
	Game.player = player
	for d in R.npcs:
		if not ResourceLoader.exists("res://data/chars/npc_" + d.id + ".glb"):
			continue
		var n = preload("res://scripts/npc.gd").new()
		add_child(n)
		n.setup(d)
		npcs.append(n)
	for d in R.enemies:
		if not ResourceLoader.exists("res://data/chars/enemy_" + d.type + ".glb"):
			continue
		var e = preload("res://scripts/enemy.gd").new()
		add_child(e)
		e.setup(d, R.etypes[d.type])
		enemies.append(e)
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	Sfx.loop("o_wind", -14.0)
	Game.msg("Dustwell. Find Sheriff Voss in the square.")
	_bake_nav.call_deferred()
	_test_hooks.call_deferred()

# ---------------------------------------------------------------- command-line hooks for automated checks:
#   -- --shot=/path.png --at=x,z,yaw,pitch   render a few frames from a spot, save a screenshot, quit
#   -- --selftest                            play the slice's quests through and print the results
func _test_hooks() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("at"):
		var v := String(args.at).split(",")
		player.global_position = Vector3(float(v[0]), Game.height(float(v[0]), float(v[1])) + 0.1, float(v[1]))
		player.yaw = float(v[2]) if v.size() > 2 else 0.0
		player.pitch = float(v[3]) if v.size() > 3 else 0.0
	if args.has("selftest"):
		await _selftest()
	if args.has("shot"):
		for i in int(args.get("frames", "40")):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(args.shot)
		print("SHOT ", args.shot, " fps ", Engine.get_frames_per_second())
		get_tree().quit()
	elif args.has("selftest"):
		get_tree().quit()

func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _goto(p: Vector3, face: Vector3) -> void:
	player.global_position = p + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	var to := face - p
	player.yaw = atan2(-to.x, -to.z)
	await _wait(4)

func _talk(id: String, picks: Array) -> String:
	var n = null
	for x in npcs:
		if x.id == id:
			n = x
	if n == null:
		return id + " missing"
	var f := Vector3(sin(n.face_yaw), 0, cos(n.face_yaw))
	await _goto(n.global_position + f * 1.8, n.global_position)
	var t := _best_target()
	if t.is_empty() or t.k != "npc" or t.o != n:
		return "can't reach " + id + " (" + str(t.get("label", "nothing")) + ")"
	interact()
	var said := [dialog_node]
	for pk in picks:
		var idx := -1
		for i in dialog_opts.size():
			if String(dialog_opts[i].t).begins_with(pk):
				idx = i
		if idx < 0:
			end_dialog()
			return id + ": no option '" + pk + "' at " + dialog_node + " " + str(dialog_opts.map(func(o): return o.t))
		choose(idx)
		said.append(dialog_node if in_dialog() else "end")
	end_dialog()
	return id + " ok " + str(said)

func _selftest() -> void:
	await _wait(10)
	var out := []
	out.append("npcs %d enemies %d pools %d solids %d" % [npcs.size(), enemies.size(), pools.size(), Game.region.solids.size()])
	out.append(await _talk("sheriff", ["What happened", "I'll get him", "Thanks"]))
	out.append("bad_water stage %d stims %d" % [Game.stage("bad_water"), int(Game.inv.get("stimpak", 0))])
	await _goto(well + Vector3(1.5, 0, 0), well)
	out.append("at well: " + str(_best_target().get("label", "nothing")))
	interact()
	out.append("sample_well %s stage %d" % [Game.has("sample_well"), Game.stage("bad_water")])
	var pp: Vector3 = quest_target()
	await _goto(pp + Vector3(2, 0, 0), pp)
	out.append("at pool: " + str(_best_target().get("label", "nothing")))
	interact()
	out.append("sample_glow %s stage %d" % [Game.has("sample_glow"), Game.stage("bad_water")])
	out.append(await _talk("sheriff", ["I have both"]))
	out.append("bad_water done %s caps %d xp %d" % [Game.is_done("bad_water"), Game.caps, Game.xp])
	out.append(await _talk("cass", ["Heard you have", "Consider"]))
	out.append("hounds stage %d, hounds at dens %d" % [Game.stage("hounds"), hounds_left()])
	for e in enemies:
		if e.quad and e.global_position.distance_to(dens) < 70.0:
			e.hit(9999.0, e.global_position + Vector3.UP, Vector3.FORWARD)
	Game.check_quests()
	out.append("after the dens: stage %d" % Game.stage("hounds"))
	out.append(await _talk("cass", ["The hounds are dead"]))
	out.append("hounds done %s level %d" % [Game.is_done("hounds"), Game.level])
	# shoot something: aim at the nearest live enemy and pull the trigger
	var tgt = null
	for e in enemies:
		if not e.dead and not e.quad:
			tgt = e
			break
	if tgt:
		var tp: Vector3 = tgt.global_position
		tgt.set_physics_process(false)
		for k in 8:
			var o := Vector3(sin(k * TAU / 8.0), 0, cos(k * TAU / 8.0)) * 6.0
			var sp := tp + o
			sp.y = Game.height(sp.x, sp.z)
			var q0 := PhysicsRayQueryParameters3D.create(sp + Vector3.UP * 1.62, tp + Vector3.UP * 1.0, 1)
			if get_world_3d().direct_space_state.intersect_ray(q0).is_empty():
				await _goto(sp, tp)
				break
		var dv: Vector3 = tp + Vector3.UP * 1.0 - player.cam.global_position
		player.pitch = atan2(dv.y, Vector2(dv.x, dv.z).length())
		await _wait(2)
		var hp0: float = tgt.hp
		player.fire_cd = 0.0
		var from: Vector3 = player.cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + (-player.cam.global_transform.basis.z) * 60.0, 1 | 2 | 4)
		q.exclude = [player.get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		out.append("aim ray hits " + (str(h.collider.name) + " (" + h.collider.get_class() + ")" if h else "nothing"))
		player.fire()
		await _wait(2)
		out.append("shot a %s: hp %.0f -> %.0f, mag %d" % [tgt.type, hp0, tgt.hp, Game.mag])
	var others := []
	for n in npcs:
		if n.id != "sheriff" and n.id != "cass":
			others.append(n.id + ":" + ("ok" if Game.DIALOGUE.has(n.id) else "silent"))
	out.append("others " + " ".join(others))
	out.append("nav ready " + str(Game.nav_ready))
	for l in out:
		print("TEST ", l)

# ---------------------------------------------------------------- environment
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.47, 0.6)
	sm.sky_horizon_color = Color(0.86, 0.74, 0.58)
	sm.ground_horizon_color = Color(0.7, 0.6, 0.48)
	sm.ground_bottom_color = Color(0.3, 0.25, 0.2)
	sm.sun_angle_max = 20.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.68, 0.55)
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-135.0), 0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.2
	add_child(sun)

# ---------------------------------------------------------------- terrain: a 2 m render mesh and a 1 m physics heightfield
func _terrain() -> void:
	var w := Game.hw
	var dd := Game.hd
	var step := 2
	var nx := int((w - 1) / step) + 1
	var nz := int((dd - 1) / step) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	uvs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := Game.x0 + i * step
			var z := Game.z0 + j * step
			var h := Game.height(x, z)
			var k := j * nx + i
			verts[k] = Vector3(x, h, z)
			var hl := Game.height(x - 1.0, z)
			var hr := Game.height(x + 1.0, z)
			var hdn := Game.height(x, z - 1.0)
			var hu := Game.height(x, z + 1.0)
			norms[k] = Vector3(hl - hr, 2.0, hdn - hu).normalized()
			uvs[k] = Vector2(x, z)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_tangents()
	mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/terrain.gdshader")
	for k in ["sand", "sand_n", "dirt", "rock", "rock_n"]:
		mat.set_shader_parameter("t_" + k, load("res://tex/" + k + ".webp"))
	mat.set_shader_parameter("t_road", load("res://tex/asphalt.webp"))
	mat.set_shader_parameter("t_mask", load("res://data/mask.png"))
	mat.set_shader_parameter("t_tint", load("res://data/tint.png"))
	mat.set_shader_parameter("region", Vector4(Game.x0, Game.z0, w - 1, dd - 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	# physics: a heightfield, which Jolt handles far more cheaply than a triangle mesh
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = w
	hs.map_depth = dd
	hs.map_data = Game.hm
	cs.shape = hs
	body.position = Vector3(Game.x0 + (w - 1) * 0.5, 0, Game.z0 + (dd - 1) * 0.5)
	body.add_child(cs)
	add_child(body)

# ---------------------------------------------------------------- buildings and props, exactly as placed in the WebView build
func _world() -> void:
	var ps: PackedScene = load("res://data/world.glb")
	var w := ps.instantiate()
	add_child(w)
	_tune_world(w)

func _tune_world(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var aabb := mi.get_aabb()
		# small clutter is not worth a shadow on a phone
		if aabb.size.length() < 6.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_tune_world(c)

func _colliders() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	for s in Game.region.solids:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(maxf(0.05, s[1] - s[0]), maxf(0.05, s[5] - s[4]), maxf(0.05, s[3] - s[2]))
		cs.shape = b
		cs.position = Vector3((s[0] + s[1]) * 0.5, (s[4] + s[5]) * 0.5, (s[2] + s[3]) * 0.5)
		body.add_child(cs)
	add_child(body)

func _pools() -> void:
	var sh := preload("res://scripts/water.gdshader")
	for p in Game.region.pools:
		var y := Game.height(p.x, p.z)
		# the water sits at the lowest ground under the pool, like the original
		for a in 8:
			var r := float(p.r) * 0.6
			y = minf(y, Game.height(p.x + cos(a * TAU / 8.0) * r, p.z + sin(a * TAU / 8.0) * r))
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(p.r * 2.0, p.r * 2.0)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = sh
		mi.material_override = m
		mi.position = Vector3(p.x, y + 0.25, p.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.3)
		l.light_energy = 0.8
		l.omni_range = float(p.r) * 2.2
		l.position = mi.position + Vector3.UP * 1.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 20.0
		add_child(l)
		pools.append({"pos": mi.position, "r": float(p.r)})

func _lamps() -> void:
	for l in Game.region.lamps:
		var o := OmniLight3D.new()
		o.light_color = Color.hex(int(l.c) << 8 | 0xff)
		o.light_energy = clampf(float(l.i) * 0.35, 0.2, 3.0)
		o.omni_range = float(l.d) if float(l.d) > 0.0 else 10.0
		o.position = Vector3(l.x, l.y, l.z)
		o.distance_fade_enabled = true
		o.distance_fade_begin = 50.0
		o.distance_fade_length = 15.0
		add_child(o)

# grass tufts in 32 m patches that are only drawn within ~55 m
func _grass() -> void:
	var img: Image = (load("res://data/mask.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var blade := ArrayMesh.new()
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	# one tuft: seven thin blades leaning out from the centre
	var brng := RandomNumberGenerator.new()
	brng.seed = 3
	for k in 7:
		var a := k * TAU / 7.0 + brng.randf() * 0.5
		var w := 0.035
		var hgt := brng.randf_range(0.28, 0.5)
		var lean := brng.randf_range(0.05, 0.16)
		var off := Vector3(cos(a), 0, sin(a)) * brng.randf_range(0.0, 0.08)
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var tip := off + Vector3(cos(a) * lean, hgt, sin(a) * lean)
		v.append_array([off - side, off + side, tip + side * 0.2, off - side, tip + side * 0.2, tip - side * 0.2])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
		for i in 6:
			nrm.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = nrm
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/grass.gdshader")
	blade.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var P := 32.0
	var cx := int(ceil((Game.hw - 1) / P))
	var cz := int(ceil((Game.hd - 1) / P))
	for j in cz:
		for i in cx:
			var xf := PackedFloat32Array()
			var n := 0
			for s in 900:
				var x := Game.x0 + i * P + rng.randf() * P
				var z := Game.z0 + j * P + rng.randf() * P
				var px := clampi(int(x - Game.x0), 0, img.get_width() - 1)
				var pz := clampi(int(z - Game.z0), 0, img.get_height() - 1)
				var mk := img.get_pixel(px, pz)
				if mk.r > 0.15 or mk.g > 0.5:
					continue
				var h := Game.height(x, z)
				if absf(Game.height(x + 1.0, z) - h) > 0.6 or absf(Game.height(x, z + 1.0) - h) > 0.6:
					continue
				var clump := sin(x * 0.13) * cos(z * 0.11) + sin(x * 0.041 + z * 0.037)
				if clump < -0.2 + rng.randf() * 0.6:
					continue
				var sc := rng.randf_range(0.7, 1.3)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc))
				xf.append_array([b.x.x, b.y.x, b.z.x, x, b.x.y, b.y.y, b.z.y, h - 0.03, b.x.z, b.y.z, b.z.z, z])
				var c := rng.randf_range(0.75, 1.1)
				xf.append_array([c, c * rng.randf_range(0.92, 1.05), c * 0.9, 1.0])
				n += 1
			if n == 0:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = blade
			mm.instance_count = n
			mm.buffer = xf
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 55.0
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)

# ---------------------------------------------------------------- navigation: baked once on a worker thread
func _bake_nav() -> void:
	nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 42.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var c := Vector3(-95, 0, 60)
	nm.filter_baking_aabb = AABB(Vector3(-210, -50, -60), Vector3(240, 200, 220))
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		nav_region.navigation_mesh = nm
		Game.nav_ready = true)

# ---------------------------------------------------------------- interaction
func _best_target() -> Dictionary:
	var pp: Vector3 = player.global_position
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var best := {}
	var bd := 1e9
	for n in npcs:
		var to: Vector3 = n.global_position - pp
		to.y = 0
		var d := to.length()
		if d < 3.2 and (d < 1.2 or fwd.dot(to / d) > 0.5) and d < bd:
			bd = d
			best = {"k": "npc", "o": n, "label": "Talk: " + String(n.display_name)}
	for e in enemies:
		if e.dead and not e.looted:
			var d: float = e.global_position.distance_to(pp)
			if d < 2.6 and d < bd:
				bd = d
				best = {"k": "loot", "o": e, "label": "Search the " + String(e.def.get("name", e.type)).to_lower()}
	if well != Vector3.ZERO and pp.distance_to(well) < 3.0:
		var lbl := "Draw a water sample" if (Game.stage("bad_water") == 0 and not Game.has("sample_well")) else "Drink from the well"
		if pp.distance_to(well) < bd:
			bd = pp.distance_to(well)
			best = {"k": "well", "label": lbl}
	for p in pools:
		var d := Vector2(pp.x - p.pos.x, pp.z - p.pos.z).length()
		if d < p.r + 1.5 and Game.stage("bad_water") == 1 and not Game.has("sample_glow"):
			best = {"k": "pool", "label": "Fill a flask from the glowing pool"}
	return best

func interact() -> void:
	if in_dialog() or Game.hp <= 0:
		return
	var t := _best_target()
	if t.is_empty():
		return
	match t.k:
		"npc": start_dialog(t.o)
		"loot":
			var e = t.o
			e.looted = true
			var c := randi_range(4, 18)
			Game.caps += c
			var a := randi_range(3, 9) if not e.quad else 0
			Game.reserve += a
			Sfx.play("o_coin")
			Game.msg("Found " + str(c) + " caps" + (" and " + str(a) + " rounds" if a > 0 else "") + ".")
			Game.stats_changed.emit()
		"well":
			if Game.stage("bad_water") == 0 and not Game.has("sample_well"):
				Game.give("sample_well")
				Sfx.play("o_splash")
				Game.msg("You fill a flask from the well. The water has a faint green cast.")
				Game.check_quests()
			else:
				Game.hp = minf(Game.hp_max, Game.hp + 10.0)
				Game.stats_changed.emit()
				Sfx.play("o_splash", -6.0)
				Game.msg("You drink. It tastes of pennies. (+10 HP)")
		"pool":
			Game.give("sample_glow")
			Sfx.play("o_splash")
			Game.msg("You hold your breath and fill a flask. It glows faintly in your hand.")
			Game.check_quests()

func in_dialog() -> bool:
	return dialog_npc != null

func start_dialog(n) -> void:
	if not Game.DIALOGUE.has(n.id):
		Game.msg(n.display_name + " has nothing to say.")
		return
	dialog_npc = n
	n.talking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.trigger = false
	Game.touch_move = Vector2.ZERO
	show_node(Game.entry_node(n.id))

func show_node(id: String) -> void:
	dialog_node = id
	var d: Dictionary = Game.DIALOGUE[dialog_npc.id]
	var node: Dictionary = d.nodes[id]
	dialog_opts = []
	for o in node.opts:
		if Game.cond(o.get("if")):
			dialog_opts.append(o)
	var say := String(node.say)
	hud.show_dialogue(String(d.name), say, dialog_opts, choose)
	speak(say, dialog_npc.id)

func choose(i: int) -> void:
	if dialog_npc == null or i >= dialog_opts.size():
		return
	var o: Dictionary = dialog_opts[i]
	Sfx.play("k_click", -8.0)
	Game.act(o.get("act"))
	if o.has("go"):
		show_node(o.go)
	else:
		end_dialog()

func end_dialog() -> void:
	if dialog_npc:
		dialog_npc.talking = false
	dialog_npc = null
	hud.hide_dialogue()
	DisplayServer.tts_stop()

# the original speaks NPC lines with the device's voice; Godot can use the same text-to-speech
func speak(text: String, who: String) -> void:
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	var v: String = voices[hash(who) % voices.size()]
	var pitch := 0.9 + float(hash(who + "p") % 30) / 100.0
	DisplayServer.tts_speak(text, v, 80, pitch, 1.05)

func quest_target() -> Variant:
	var sheriff = null
	for n in npcs:
		if n.id == "sheriff":
			sheriff = n
	match Game.stage("bad_water"):
		0: return well
		1:
			var best = null
			var bd := 1e9
			for p in pools:
				var d: float = p.pos.distance_to(player.global_position)
				if d < bd:
					bd = d
					best = p.pos
			return best
		2: return sheriff.global_position if sheriff else null
	match Game.stage("hounds"):
		0: return dens
		1:
			for n in npcs:
				if n.id == "cass":
					return n.global_position
			return null
	if not Game.flags.has("met_sheriff") and sheriff:
		return sheriff.global_position
	return null

func hounds_left() -> int:
	var n := 0
	for e in enemies:
		if not e.dead and e.quad and e.global_position.distance_to(dens) < 70.0:
			n += 1
	return n

func _process(d: float) -> void:
	if player == null or hud == null:
		return
	var t := _best_target()
	hud.set_prompt("" if t.is_empty() else "[USE] " + String(t.label))
	# gunfire wakes up anything that can hear it
	if player.flash.light_energy > 5.5:
		for e in enemies:
			e.hear(player.global_position)
	if Game.hp > 0 and Game.hp < Game.hp_max and Game.has("stimpak") and Game.hp < 35:
		Game.take("stimpak")
		Game.hp = minf(Game.hp_max, Game.hp + 45.0)
		Game.msg("You jab a Stim Shot. (+45 HP)")
		Game.stats_changed.emit()

# ---------------------------------------------------------------- damage, death
func on_player_hurt(d: float) -> void:
	hud.flash_hurt(0.12 + d * 0.012)
	player.hurt_fx(d)
	Sfx.play(["o_mhurt1", "o_mhurt2"][randi() % 2], -4.0)
	if Game.hp <= 0.0:
		end_dialog()
		hud.show_dead(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func respawn() -> void:
	Game.hp = Game.hp_max
	player.global_position = start_pos
	player.velocity = Vector3.ZERO
	hud.show_dead(false)
	Game.stats_changed.emit()
	Game.msg("You come to in Dustwell. Somebody dragged you back.")

func restart() -> void:
	Game.inv.clear()
	Game.flags.clear()
	Game.quests.clear()
	Game.kills.clear()
	Game.hp = 100.0
	Game.hp_max = 100.0
	Game.caps = 25
	Game.xp = 0
	Game.level = 1
	Game.mag = 12
	Game.reserve = 48
	Game.nav_ready = false
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- effects
func _puff(pos: Vector3, normal: Vector3, col: Color, n: int, spd: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func impact(pos: Vector3, normal: Vector3) -> void:
	_puff(pos + normal * 0.05, normal, Color(0.62, 0.53, 0.42, 0.9), 10, 3.0)
	Sfx.play_at(["x_rock0", "x_rock1"][randi() % 2], pos, -6.0)

func blood(pos: Vector3, dir: Vector3) -> void:
	_puff(pos, -dir, Color(0.45, 0.02, 0.02, 0.95), 12, 2.5)
	Sfx.play_at(["x_flesh0", "x_flesh1"][randi() % 2], pos, -4.0)

func tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)
