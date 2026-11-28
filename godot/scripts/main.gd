# The Dustwell slice: builds the region exported from the WebView build (terrain, buildings and props, colliders,
# pools, lamps, grass), spawns the player, townsfolk and hostiles, bakes a navigation mesh, and runs interaction,
# dialogue and the little bits of effects (impacts, blood, tracers).
extends Node3D

var hud
var player
var npcs: Array = []
var enemies: Array = []
var defenders: Array = []   # townspeople shooting at something right now (enemies fight back)
var town_shot := false     # the hit being dealt is a guard's: no XP for you if it kills
var sun: DirectionalLight3D
var env: Environment
var nav_region: NavigationRegion3D
var dialog_npc = null
var dialog_id := ""
var dialog_node := ""
var pending_trade := ""
var objects: WorldObjects
var pockets: Pockets
var barrels: Barrels
var reactor: Reactor
var silo: Silo9
var events: RoadEvents
var forge: Forge
var atmos: Atmos
var buggy: Buggy
var khole: KHole
var look_t := 0.0
var vault_dress: VaultDress
var party: Array = []        # companions travelling with you (one person and Biscuit)
var dialog_opts: Array = []
var pools: Array = []
var start_pos := Vector3.ZERO
var talk_cd := 0.0
var chunks
var grass_nodes: Array = []
var quality := 1
var lamp_nodes: Array = []
var lamp_detail := 1:
	set(v):
		lamp_detail = v
		for o in lamp_nodes:
			if is_instance_valid(o):
				(o as OmniLight3D).distance_fade_begin = [22.0, 50.0, 95.0][clampi(v, 0, 2)]
var terrain_mi: MeshInstance3D
var terrain_full: ShaderMaterial
var terrain_lite: ShaderMaterial
var people: Dictionary = {}      # chunk key -> [["n"|"e", index]]
var live_npc: Dictionary = {}
var live_enemy: Dictionary = {}
var nav_center := Vector3(1e9, 0, 1e9)
var nav_busy := false
var disc_t := 1.0
var auto_t := 180.0

var town: TownLife
var frontier: Frontier
func _ready() -> void:
	Game.main = self
	var R: Dictionary = Game.region
	town = TownLife.new()
	add_child(town)
	_environment()
	Reactor.level_ground()
	Frontier.level_ground()
	_terrain()
	if vault_dress:
		chunks.on_built = vault_dress.brighten
	elif Game.area == "cells":
		chunks.on_built = _dress_cell
	# build 15: the Ashwood's towns and ruins stand in the collision and the navigation from the start
	Frontier.prepare()
	Reactor.prepare()
	Silo9.prepare()
	_colliders()
	_pools()
	_lamps()
	start_pos = Vector3(R.start.x, Game.height(R.start.x, R.start.z) + 0.2, R.start.z)
	var start_yaw := PI
	if Game.pending_pos != null:
		var pp: Array = Game.pending_pos
		start_pos = Vector3(pp[0], Game.height(pp[0], pp[2]) + 0.2, pp[2])
		start_yaw = float(pp[3])
		Game.pending_pos = null
	# townsfolk and hostiles are spawned chunk by chunk as the world streams in
	for i in R.npcs.size():
		var d: Dictionary = R.npcs[i]
		var k: String = chunks.key_of(Vector3(d.x, 0, d.z))
		if not people.has(k):
			people[k] = []
		people[k].append(["n", i])
	for i in R.enemies.size():
		var d: Dictionary = R.enemies[i]
		var k: String = chunks.key_of(Vector3(d.x, 0, d.z))
		if not people.has(k):
			people[k] = []
		people[k].append(["e", i])
	pockets = Pockets.new(self)
	barrels = Barrels.new(self)
	add_child(barrels)
	objects = WorldObjects.new()
	add_child(objects)
	objects.setup(self)
	# the spots a quest wants searched glint (build 24)
	add_child(QuestGlint.new())
	events = RoadEvents.new()
	add_child(events)
	events.setup(self)
	_place_stealables.call_deferred()
	if Game.area == "world":
		for pr in Game.STORY.get("props", []):
			if String(pr.kind) == "wagon_burnt":
				var w: Node3D = events._wagon(float(pr.x), float(pr.z), true)
				w.rotation.y = float(pr.get("rot", 0.0))
	forge = Forge.new()
	add_child(forge)
	# story scenery built from the forge's pieces (Coyle's camp)
	if Game.area == "world":
		for pr in Game.STORY.get("props", []) + Game.ARSENAL.get("props", []):
			if String(pr.kind) == "campfire":
				var cf := FireFX.make_pit(1.0, String(pr.get("pit", FireFX.pit_kind(float(pr.x), float(pr.z)))))
				add_child(cf)
				cf.global_position = Vector3(float(pr.x), Game.height(float(pr.x), float(pr.z)), float(pr.z))
				town.add_fire(cf.global_position, 1.0)
				continue
			if Forge.KINDS.has(String(pr.kind)):
				var pn: Node3D = forge.build(String(pr.kind), -1)
				add_child(pn)
				pn.global_position = Vector3(float(pr.x), Game.height(float(pr.x), float(pr.z)), float(pr.z))
				pn.rotation.y = float(pr.get("rot", 0.0))
	forge.setup.call_deferred(self)
	if Game.area == "world":
		frontier = Frontier.new()
		frontier.name = "Frontier"
		add_child(frontier)
		frontier.setup(self)
		reactor = Reactor.new(self)
		add_child(reactor)
		silo = Silo9.new(self)
		add_child(silo)
	chunks.on_enter = _spawn_chunk
	chunks.on_leave = _despawn_chunk
	player = preload("res://scripts/player.gd").new()
	player.position = start_pos
	player.yaw = start_yaw
	add_child(player)
	Game.player = player
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	set_quality(Quality.load_level())
	chunks.load_now(start_pos, true)
	if Game.area != "khole":
		_restore_party()
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self)
	if Game.area == "world":
		var hv := Havoc.new()
		hv.name = "Havoc"
		add_child(hv)
		hv.setup(self)
	if not Game.interior():
		buggy = Buggy.new()
		add_child(buggy)
		buggy.setup(self)
	if Game.area == "khole":
		khole = KHole.new()
		add_child(khole)
		khole.setup(self)
		_khole_arrive.call_deferred()
	elif Game.flags.has("khBack"):
		_khole_back.call_deferred()
	if Game.flags.has("cellOutSpot") and Game.area == "world":
		_cell_step_out.call_deferred()
	if Game.flags.has("cellFade"):
		Game.flags.erase("cellFade")
		_fade.call_deferred(false, Color.BLACK, 0.45)
		Sfx.play.call_deferred("k_door_close", -6.0)
	if Game.pending_new:
		Game.pending_new = false
		_opening.call_deferred()
	elif not Game.flags.has("met_sheriff") and not Game.interior() and Game.booted:
		Game.msg("Dustwell. Find Sheriff Voss in the square.")
	if not Game.booted and OS.get_cmdline_user_args().is_empty():
		hud.screens.open_title.call_deferred()
	_test_hooks.call_deferred()

# ---------------------------------------------------------------- Haven 12
func _opening() -> void:
	Game.banner("HAVEN 12", "Day 1 of 9")
	Game.start("exodus")
	Game.msg("Follow the diamond on the compass.")
	await get_tree().create_timer(2.0).timeout
	speak("Attention, Haven 12. Water rationing is now in effect. " + Game.player_name + ", report to the Overseer's office immediately.", "overseer")
	await get_tree().create_timer(5.0).timeout
	Game.msg("Tap USE to talk to people and open things.")

func leave_vault() -> void:
	speak("Haven 12 door opening. Stand clear of the rails.", "core")
	Game.flags["leftVault"] = 1
	Game.discovered["vault"] = 1
	Game.complete("exodus")
	Game.start("daylight")
	var L: Dictionary = Game.DB.locs.vault
	if vault_dress:
		await vault_dress.open_great_door()
	await _fade(true)
	Game.travel_area("world", float(L.x), float(L.z) - 7.0, 0.0)

func vault_travel(inward: bool) -> void:
	if not inward and vault_dress:
		await vault_dress.open_great_door()
	else:
		Sfx.play("o_bigdoor")
	await _fade(true)
	if inward:
		var sp: Array = Game.L.consts.VSPOT.door
		Game.travel_area("vault", float(Game.L.consts.VAULT_O.x) + float(sp[0]) - 4.5, float(Game.L.consts.VAULT_O.z) + float(sp[1]) - 6.0, 0.0)
	else:
		var L: Dictionary = Game.DB.locs.vault
		Game.travel_area("world", float(L.x), float(L.z) - 7.0, 0.0)

# through a building's front door, in either direction (main.js cellTravel)
func cell_travel(i: int, inward: bool) -> void:
	if i < 0 or i >= Game.CELLS.size():
		return
	var C: Dictionary = Game.CELLS[i]
	Sfx.play("k_door_open", -4.0)
	Game.flags["cellFade"] = 1
	await _fade(true, Color.BLACK, 0.35)
	if inward:
		Game.travel_area("cells", float(C.ox), float(C.oz) + float(C.D2) / 2.0 - 1.7, 0.0)
		return
	var o: Dictionary = C.get("out", {})
	var nx := float(o.get("nx", 0))
	var nz := float(o.get("nz", 1))
	Game.flags["cellOutSpot"] = [float(o.x), float(o.z), nx, nz]
	Game.travel_area("world", float(o.x) + nx * 0.6, float(o.z) + nz * 0.6, atan2(-nx, -nz))

# out on the street: step onto the first clear spot in front of the door (porches, posts and crates crowd some of them)
func _cell_step_out() -> void:
	var c: Array = Game.flags.get("cellOutSpot")
	Game.flags.erase("cellOutSpot")
	var space := get_world_3d().direct_space_state
	for k in [0.6, 0.0, 1.2, -0.5, 2.0]:
		for l in [0.0, 0.7, -0.7, 1.4, -1.4]:
			var x: float = c[0] + c[2] * k + c[3] * l
			var z: float = c[1] + c[3] * k - c[2] * l
			var q := PhysicsShapeQueryParameters3D.new()
			var sh := CapsuleShape3D.new()
			sh.radius = 0.42
			sh.height = 1.6
			q.shape = sh
			q.transform = Transform3D(Basis(), Vector3(x, Game.height(x, z) + 1.0, z))
			q.collision_mask = 1
			if space.intersect_shape(q, 1).is_empty():
				player.global_position = Vector3(x, Game.height(x, z) + 0.1, z)
				return

# Things left lying around where people live and work: on a trader's counter, a table, a shelf. Taking them is
# stealing (world_objects._steal): unseen it costs a little karma, seen it costs more and the owner's people notice.
var _stealables_done := false
func _place_stealables() -> void:
	if _stealables_done:
		return
	_stealables_done = true
	await get_tree().create_timer(1.5, false).timeout
	var pool: Array = []
	for k in Game.DB.items:
		var it: Dictionary = Game.DB.items[k]
		if String(it.get("t", "")) in ["aid", "junk", "ammo"] and float(it.get("v", 0)) >= 8.0 and float(it.get("v", 0)) <= 110.0 and not it.get("quest", false):
			pool.append(k)
	pool.sort()
	if pool.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for d in Game.region.npcs:
		var id := String(d.id)
		if not (Game.L.get("vendors", {}).has(id) or Game.STORY.get("npc_faction", {}).has(id)):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id + Game.area)
		var placed := 0
		if not Game.L.get("vendors", {}).has(id) and rng.randf() < 0.5:
			continue
		for tries in 14:
			if placed >= (2 if Game.L.get("vendors", {}).has(id) else 1):
				break
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.2, 3.0)
			var x := float(d.x) + cos(a) * r
			var z := float(d.z) + sin(a) * r
			var top := float(d.get("y", Game.height(x, z))) + 2.2
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, top - 3.5, z), 1)
			var h := space.intersect_ray(q)
			if h.is_empty() or h.normal.y < 0.8:
				continue
			# not inside a closed building's shell (traders stand at their doors; the room behind is its own interior)
			var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(h.position + Vector3.UP * 0.3, h.position + Vector3.UP * 12.0, 1))
			if not up.is_empty() and Game.area == "world":
				continue
			# and in plain view of its owner
			var seen := space.intersect_ray(PhysicsRayQueryParameters3D.create(h.position + Vector3.UP * 0.3, Vector3(float(d.x), float(d.get("y", h.position.y)) + 1.2, float(d.z)), 1))
			if not seen.is_empty():
				continue
			# on something flat and clear (a counter, a table, the floor), not in a wall
			var sq := PhysicsShapeQueryParameters3D.new()
			var sh := SphereShape3D.new()
			sh.radius = 0.15
			sq.shape = sh
			sq.transform = Transform3D(Basis(), h.position + Vector3.UP * 0.2)
			sq.collision_mask = 1
			if not space.intersect_shape(sq, 1).is_empty():
				continue
			var item: String = pool[rng.randi() % pool.size()]
			var o := {"id": "steal_%s_%s_%d" % [Game.area, id, placed], "item": item, "qty": (rng.randi_range(6, 18) if String(Game.item(item).get("t", "")) == "ammo" else 1),
				"x": h.position.x, "z": h.position.z, "y": h.position.y, "owned": id}
			if not Game.looted.has("pk_" + o.id):
				objects.add_pickup_now(o)
			placed += 1

# The town's rooms: walls drawn both ways (nothing shows the void), and the bare plaster papered over: faded
# striped wallpaper, a different pattern and colour in each building, aged and grimy, the plaster showing through.
const PLASTER_TEX := "3634cc61-1562"
var _paper: ShaderMaterial
func _dress_cell(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if not m is StandardMaterial3D:
				continue
			var sm := m as StandardMaterial3D
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			if sm.albedo_texture and PLASTER_TEX in sm.albedo_texture.resource_path:
				if _paper == null:
					var sh := Shader.new()
					sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D plaster : source_color, filter_linear_mipmap, repeat_enable;
uniform float floor_y = -60.0;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void fragment(){
	vec2 room = floor((wp.xz - vec2(2000.0, -500.0)) / 115.0);
	float r = h(room);
	vec3 pal[6] = vec3[6](vec3(0.42,0.5,0.4), vec3(0.58,0.42,0.42), vec3(0.62,0.54,0.33), vec3(0.4,0.46,0.55), vec3(0.6,0.56,0.46), vec3(0.47,0.38,0.5));
	vec3 base = pal[int(r * 6.0)];
	float u = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	float y = wp.y - floor_y;
	float stripe = smoothstep(0.42, 0.5, abs(fract(u * (1.6 + r * 1.4)) - 0.5));
	vec2 dp = vec2(u * 3.2, y * 3.2);
	float dot_ = 1.0 - smoothstep(0.08, 0.13, length(fract(dp + vec2(0.5 * mod(floor(dp.y), 2.0), 0.0)) - 0.5));
	vec3 c = mix(base, base * 1.18, stripe * 0.6);
	c = mix(c, base * 0.72, dot_ * (r > 0.5 ? 0.6 : 0.0));
	vec3 pl = texture(plaster, vec2(u, y) * 0.35).rgb;
	float age = smoothstep(0.62, 0.92, vn(vec2(u, y) * 0.8 + room * 7.0) * 0.75 + pl.r * 0.3);
	c = mix(c, base * 0.55 + pl * 0.25, age * 0.45);
	c *= 0.92 + pl.r * 0.12;
	c *= mix(0.62, 1.0, smoothstep(0.0, 1.2, y)) * mix(1.0, 0.75, smoothstep(2.6, 3.6, y));
	// floors, rugs and table-tops that shared the plaster keep a plain worn finish
	ALBEDO = mix(c * 0.9, pl * vec3(0.62, 0.58, 0.52), step(0.6, abs(wn.y)));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}"""
					_paper = ShaderMaterial.new()
					_paper.shader = sh
					_paper.set_shader_parameter("plaster", sm.albedo_texture)
					_paper.set_shader_parameter("floor_y", float(Game.L.consts.CELLS.y))
				(mi as MeshInstance3D).set_surface_override_material(i, _paper)

func _fade(out: bool, col := Color.BLACK, secs := 1.2) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0 if out else 1.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 1.0 if out else 0.0, secs)
	await tw.finished
	if not out:
		r.queue_free()
	return r

# ---------------------------------------------------------------- the K-hole (main.js kholeStart / kholeEnd)
# A second dose of ketarad while the first still runs drops you through the floor of the world. Either you black out for
# thirty seconds and come to somewhere random in the wastes, or you fall into the Hole, which lasts two minutes (three
# with the Lattice Key). When it ends you surface where you fell, or (without the key) sometimes somewhere else entirely.
const KH_LINES := ["...the floor is a lid...", "ollom vesh. ollom vesh.", "somebody is counting your teeth from the inside", "you are a hallway",
	"the television is still on. it is watching the chairs.", "krr tikka voon", "you remember being a door", "kilo. kilo. the word kilo.",
	"there is a goose here and it is the sky", "you have been here for a very long minute", "zhaa ne por uul", "the ground says your name wrong, on purpose"]
var kh_busy := false

func khole_start(force := "") -> bool:
	if kh_busy or Game.interior() or not Game.flags.get("leftVault") or (buggy and buggy.driving):
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--khole=") and force == "":
			force = a.trim_prefix("--khole=")
	var kind := force if force != "" else ("black" if randf() < (0.15 if Game.flags.get("latticeKey") else 0.4) else "hole")
	kh_busy = true
	Game.flags["kholes"] = int(Game.flags.get("kholes", 0)) + 1
	if party.size():
		Game.msg("Your companions can't follow you where you're going.")
	_khole_go(kind)
	return true

func _khole_go(kind: String) -> void:
	var fast := OS.get_cmdline_user_args().has("--khfast")
	if kind == "black":
		Game.msg("The floor tilts. Then the floor leaves.")
		Sfx.play("heart")
		var r: ColorRect = await _fade(true, Color.BLACK, 2.5)
		var lines := VBoxContainer.new()
		lines.set_anchors_preset(Control.PRESET_FULL_RECT)
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(lines)
		var t := 0.0
		var total := 1.2 if fast else 30.0
		while t < total:
			var l := Label.new()
			l.text = KH_LINES[randi() % KH_LINES.size()]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", Color(0.72, 0.63, 0.85))
			l.modulate.a = 0.0
			lines.add_child(l)
			var tw := l.create_tween()
			tw.tween_property(l, "modulate:a", 0.85, 2.0)
			tw.tween_interval(3.0)
			tw.tween_property(l, "modulate:a", 0.0, 2.5)
			tw.tween_callback(l.queue_free)
			var wait := minf(2.6, total - t)
			await get_tree().create_timer(wait, false).timeout
			t += wait
		lines.queue_free()
		var s := wake_spot()
		player.global_position = Vector3(s.x, Game.height(s.x, s.y) + 0.3, s.y)
		player.velocity = Vector3.ZERO
		player.yaw = randf() * TAU
		chunks.load_now(player.global_position)
		var tw2 := r.create_tween()
		tw2.tween_property(r, "color:a", 0.0, 4.0)
		tw2.tween_callback(r.queue_free)
		Game.banner("...WHERE?", "You come to somewhere else")
		Game.msg("You come to with grit in your mouth and no memory of the walk. Thirty seconds, or a day?")
		Game.save_game("auto")
		kh_busy = false
		return
	Game.msg("The floor is thin. You go through it.")
	await _fade(true, Color.WHITE, 1.8)
	Game.flags["khRet"] = {"x": player.global_position.x, "z": player.global_position.z, "yaw": player.yaw}
	Game.flags["khT"] = 8.0 if fast else (180.0 if Game.flags.get("latticeKey") else 120.0)
	Game.travel_area("khole", KHole.X + 4.0, KHole.Z + 24.0, 0.0)

func _khole_arrive() -> void:
	_fade(false, Color.WHITE, 2.6)
	khole.pulse()
	Game.banner("THE HOLE", "Under the floor of the world. It will not last.")
	speak("Ollom vesh. Ollom vesh. A visitor. A visitor with a clock.", "ferryman")
	await get_tree().create_timer(3.5, false).timeout
	Game.msg("Talk to things. Collect what glows. When the clock runs out, so do you.")

func khole_end() -> void:
	if dialog_npc != null or dialog_id != "":
		end_dialog()
	Game.msg("The Hole is closing. It was never open.")
	await _fade(true, Color.WHITE, 2.0)
	var away: bool = not Game.flags.get("latticeKey") and randf() < 0.3
	if OS.get_cmdline_user_args().has("--khaway"):
		away = true
	var ret: Dictionary = Game.flags.get("khRet", {})
	if ret.is_empty():
		var D: Dictionary = Game.DB.locs.dustwell
		ret = {"x": float(D.x) + 6.0, "z": float(D.z) + 6.0, "yaw": 0.0}
	Game.flags.erase("khT")
	Game.flags.erase("khRet")
	Game.flags["khBack"] = "away" if away else "back"
	Game.travel_area("world", float(ret.x), float(ret.z), float(ret.get("yaw", 0.0)))

func _khole_back() -> void:
	var away := String(Game.flags.get("khBack")) == "away"
	Game.flags.erase("khBack")
	if away:
		var s := wake_spot()
		player.global_position = Vector3(s.x, Game.height(s.x, s.y) + 0.3, s.y)
		chunks.load_now(player.global_position)
	_fade(false, Color.WHITE, 3.0)
	Game.banner("ELSEWHERE" if away else "BACK", "You surface somewhere you have never been" if away else "You surface where you fell")
	Game.msg("The Hole spits you out miles from where you went in." if away else "Nobody noticed you were gone. Your mouth tastes of pennies.")
	Game.check_quests()
	Game.save_game("auto")

# somewhere flat and open in the wastes, away from water and walls (main.js wakeSpot)
func wake_spot() -> Vector2:
	var space := get_world_3d().direct_space_state
	for i in 80:
		var x := randf_range(-440.0, 440.0)
		var z := randf_range(-440.0, 440.0)
		var wet := false
		for p in Game.region.pools:
			if Vector2(float(p.x) - x, float(p.z) - z).length() < float(p.r) + 3.0:
				wet = true
		if wet:
			continue
		var h := Game.height(x, z)
		if absf(Game.height(x + 2, z) - h) > 0.9 or absf(Game.height(x, z + 2) - h) > 0.9:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.4
		q.shape = sh
		q.transform = Transform3D(Basis(), Vector3(x, h + 1.6, z))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var roofed := false
		for s in Game.region.solids:
			if x > float(s[0]) - 1.0 and x < float(s[1]) + 1.0 and z > float(s[2]) - 1.0 and z < float(s[3]) + 1.0 and float(s[5]) > h + 0.4:
				roofed = true
				break
		if roofed:
			continue
		return Vector2(x, z)
	var D: Dictionary = Game.DB.locs.dustwell
	return Vector2(float(D.x) + 6.0, float(D.z) + 6.0)

# people belonging to a chunk come and go with it; the dead stay dead
func _spawn_chunk(k: String) -> void:
	objects.spawn_chunk(k)
	for it in people.get(k, []):
		var i: int = it[1]
		if it[0] == "n":
			var d: Dictionary = Game.region.npcs[i]
			if live_npc.has(i) or Game.flags.has("npcDead_" + String(Game.region.npcs[i].id)) or not Game.flag_allowed(d):
				continue
			var n = preload("res://scripts/npc.gd").new()
			add_child(n)
			n.setup(d)
			n.set_meta("idx", i)
			npcs.append(n)
			live_npc[i] = n
		else:
			var d: Dictionary = Game.region.enemies[i]
			if live_enemy.has(i) or Game.dead.has(str(i)) or Game.killed.has(String(d.get("id", "-"))) or not Game.spawn_allowed(d):
				continue
			if not Game.region.etypes.has(d.type) or not (ResourceLoader.exists(Game.char_path("enemy_" + d.type + ".glb")) or preload("res://scripts/enemy.gd").PEOPLE.has(String(d.type))):
				continue
			var e = preload("res://scripts/enemy.gd").new()
			add_child(e)
			e.setup(d, Game.region.etypes[d.type])
			e.idx = i
			enemies.append(e)
			live_enemy[i] = e

func _despawn_chunk(k: String) -> void:
	objects.despawn_chunk(k)
	for it in people.get(k, []):
		var i: int = it[1]
		if it[0] == "n" and live_npc.has(i):
			var n = live_npc[i]
			if n == dialog_npc or n.follow:
				continue
			npcs.erase(n)
			live_npc.erase(i)
			n.queue_free()
		elif it[0] == "e" and live_enemy.has(i):
			var e = live_enemy[i]
			if e.state == "chase" and not e.dead:
				continue
			enemies.erase(e)
			live_enemy.erase(i)
			e.queue_free()

# ---------------------------------------------------------------- companions
func _npc_index(id: String) -> int:
	for i in Game.region.npcs.size():
		if String(Game.region.npcs[i].id) == id:
			return i
	# companions follow you indoors: borrow them from the valley's people
	if Game.area == "cells" and Game.L.get("companions", {}).has(id):
		for d in Game._json("res://data/region.json").get("npcs", []):
			if String(d.id) == id:
				Game.region.npcs.append(d)
				return Game.region.npcs.size() - 1
	return -1

func recruit(id: String, silent := false) -> void:
	var c: Dictionary = Game.L.get("companions", {}).get(id, {})
	var i := _npc_index(id)
	if c.is_empty() or i < 0:
		return
	for p in party:
		if p.id == id:
			return
	if not c.get("dog", false):
		for p in party.duplicate():
			if not p.comp.get("dog", false):
				var gone := String(p.comp.get("n", p.id))
				dismiss(p.id, true)
				Game.msg(gone + " heads home. You can only bring one person along.")
	var n = live_npc.get(i)
	if n == null:
		n = preload("res://scripts/npc.gd").new()
		add_child(n)
		n.setup(Game.region.npcs[i])
		n.set_meta("idx", i)
		npcs.append(n)
		live_npc[i] = n
		var a: Vector3 = player.global_position + Vector3(1.5, 0.3, 1.5)
		n.global_position = Vector3(a.x, Game.height(a.x, a.z) + 0.2, a.z)
	if not Game.flags.has("party") or not (Game.flags.party is Dictionary):
		Game.flags["party"] = {}
	var st: String = Game.flags.party.get(id, {}).get("state", "follow")
	n.join(_comp_stats(id, c), st)
	if not c.get("dog", false) and not Game.flags.has("appr_" + id):
		Game.flags["appr_" + id] = 0
	party.append(n)
	Game.flags.party[id] = {"state": st}
	if id == "biscuit":
		Game.flags["biscuit"] = 1
		if not Game.known("good_boy"):
			Game.start("good_boy")
	if not silent:
		Game.banner("COMPANION", String(c.n) + " joins you")
		Sfx.play("o_quest")
	Game.check_quests()

# loyal companions hit harder and take more punishment
func _comp_stats(id: String, c: Dictionary) -> Dictionary:
	if c.get("dog", false):
		# build 20: Biscuit took most things down in two bites; a little gentler, a little slower between bites
		var dg := c.duplicate(true)
		dg["dmg"] = float(c.get("dmg", 16)) * 0.75
		dg["atk"] = float(c.get("atk", 0.85)) * 1.15
		return dg
	if not Game.is_loyal(id):
		return c
	var d := c.duplicate(true)
	d["dmg"] = float(c.get("dmg", 12)) * 1.3
	d["hp"] = float(c.get("hp", 150)) * 1.25
	d["loyal"] = true
	return d

func refresh_party() -> void:
	for p in party:
		var c: Dictionary = Game.L.companions.get(String(p.id), {})
		if not c.is_empty():
			var frac: float = p.hp / maxf(1.0, p.maxhp)
			p.join(_comp_stats(String(p.id), c), p.cstate)
			p.hp = p.maxhp * frac

func dismiss(id: String, quiet := false) -> void:
	for p in party:
		if p.id == id:
			party.erase(p)
			p.leave()
			if Game.flags.get("party") is Dictionary:
				Game.flags.party.erase(id)
			if not quiet:
				Game.msg(String(Game.L.companions[id].n) + " heads home.")
			return

func party_state(id: String):
	for p in party:
		if p.id == id:
			return p.cstate
	return null

func party_cmd(id: String, st: String) -> void:
	for p in party:
		if p.id == id:
			p.cstate = st
			Game.flags.party[id] = {"state": st}

# companions saved in the game come back with you
func _restore_party() -> void:
	var pd = Game.flags.get("party")
	if pd is Dictionary:
		for id in pd.keys():
			recruit(String(id), true)

# ---------------------------------------------------------------- townsfolk can be attacked (main.js provokeNpc)
# Essential people (the story, town leaders) fight back but yield at zero health; guards nearby join in; children
# can't be hurt. Attacking costs karma, murder more.
const ESSENTIAL := ["overseer", "pell", "nan", "cass", "brannock", "wick", "halloran", "sheriff", "ines", "vex", "finch", "maren", "core"]
const GUARDS := ["saltguard", "knuckles", "sheriff", "guard12", "renn2", "kess"]
const CHILDREN := ["pip"]

func provoke(n, dmg: float, dir: Vector3, chain := false, story := false) -> void:
	if n.hostile or n.follow or String(n.id) in CHILDREN or not n.visible:
		return
	if dialog_npc == n:
		end_dialog()
	n.hostile = true
	n.visible = false
	n.collision_layer = 0
	n.set_physics_process(false)
	var guard: bool = String(n.id) in GUARDS or String(n.id) in Game.STORY.get("guards", [])
	var type := "townguard" if guard else "townsfolk"
	var src: Dictionary = Game.DB.enemies.get(type, {})
	var td := {"hp": src.get("hp", 65), "name": n.display_name, "dmg": src.get("dmg", 6), "speed": src.get("spd", 4.0), "range": src.get("range", 2.0),
		"xp": src.get("xp", 10), "ranged": src.get("ranged", false), "quad": false, "scale": 1}
	# someone the story arms properly (a gang boss, a cornered zealot)
	var fs = null
	for sn in Game.STORY.get("npcs", []):
		if String(sn.id) == String(n.id) and sn.has("fight"):
			fs = sn.fight
	if fs != null:
		td.hp = float(fs.get("hp", td.hp))
		td.dmg = float(fs.get("dmg", td.dmg))
		td.ranged = bool(fs.get("ranged", false))
		td.range = 36.0 if td.ranged else 2.0
		td.xp = int(td.hp * 0.6)
		guard = guard or td.ranged
	var e = preload("res://scripts/enemy.gd").new()
	add_child(e)
	e.setup({"type": type, "x": n.global_position.x, "z": n.global_position.z, "y": n.global_position.y, "hostile": true, "id": "npc_" + String(n.id),
		"look": n.look, "npc": String(n.id), "ranged": guard}, td)
	e.npc = n
	e.essential = String(n.id) in ESSENTIAL
	e.state = "chase"
	e.face_yaw = n.face_yaw
	enemies.append(e)
	if not chain:
		if not story:
			Game.add_karma(-6, "Attacked " + String(n.display_name))
		Game.msg(String(n.display_name) + " turns on you!")
		for o in npcs.duplicate():
			if o != n and not o.hostile and not o.follow and o.visible and String(o.id) in GUARDS and o.global_position.distance_to(n.global_position) < 40.0:
				provoke(o, 0.0, Vector3.ZERO, true)
	if dmg > 0.0:
		e.hit(dmg, e.global_position + Vector3.UP * 1.2, dir if dir != Vector3.ZERO else Vector3.FORWARD)

# an essential person at zero health drops their guard and gives up; after a moment they (and anyone who joined
# in nearby) go back to being townsfolk
func npc_yield(e) -> void:
	e.hp = 1.0
	e.hostile = false
	e.state = "idle"
	var n = e.npc
	Game.banner(String(n.display_name).to_upper() + " YIELDS", "Essential: they can't be killed")
	speak(["Enough! Enough. I give up.", "Stop! Please, I yield.", "You win. Put it down. Please."][randi() % 3], String(n.id))
	await get_tree().create_timer(4.0).timeout
	for o in enemies.duplicate():
		if is_instance_valid(o) and o.get("npc") != null and not o.dead and o.global_position.distance_to(e.global_position) < 45.0:
			_calm(o)
	if is_instance_valid(e) and not e.dead:
		_calm(e)

# townsfolk you provoked don't stay angry forever: once you've stopped hitting them for a while and kept your
# distance (or simply left them alone long enough), they go back to their lives and their quests carry on
var _forgive_t := 0.0
func _forgive_tick(d: float) -> void:
	_forgive_t -= d
	if _forgive_t > 0.0:
		return
	_forgive_t = 1.0
	_unstick()
	_furnish_tick()
	_terminal_desks()
	_chest_shells()
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dead or e.get("npc") == null:
			continue
		e.since_hit += 1.0
		var far: bool = e.global_position.distance_to(player.global_position) > 30.0
		if (far and e.since_hit > 25.0) or e.since_hit > 120.0:
			var nm := String(e.npc.display_name) if is_instance_valid(e.npc) else "They"
			_calm(e)
			Game.msg(nm + " has calmed down.")
			Game.flags["forgiven_" + String(e.get("npc_id") if e.get("npc_id") else nm)] = Game.day

# a terminal the original game stood on a desk it drew by itself (so the desk never reached the export) floats in
# the air: once its chunk is in, look under the terminal's own meshes, and if nothing holds them up, build a steel desk
var _desked := {}
func _terminal_desks() -> void:
	for t in Game.W.get("terminals", []):
		var id := String(t.id)
		if _desked.has(id):
			continue
		var tp := Vector3(float(t.x), float(t.get("y", Game.height(float(t.x), float(t.z)))), float(t.z))
		if Vector2(tp.x - player.global_position.x, tp.z - player.global_position.z).length() > 45.0:
			continue
		var ck: String = chunks.key_of(tp)
		if not chunks.loaded.has(ck):
			continue
		_desked[id] = true
		var floor_y: float = Game.height(tp.x, tp.z)
		var hit0 := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tp + Vector3.UP * 0.2, tp + Vector3.DOWN * 3.0, 1))
		if not hit0.is_empty():
			floor_y = maxf(floor_y, float(hit0.position.y)) if hit0.position.y < tp.y - 0.4 else floor_y
		var box := AABB()
		var first := true
		var others: Array = []
		for c in (chunks.loaded[ck] as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var ab: AABB = mi.global_transform * mi.get_aabb()
			if ab.size.length() > 6.0:
				continue
			var cc := ab.get_center()
			if Vector2(cc.x - tp.x, cc.z - tp.z).length() < 0.6 and ab.position.y > floor_y + 0.3 and ab.position.y < tp.y + 0.6:
				box = ab if first else box.merge(ab)
				first = false
			else:
				others.append(ab)
		if first:
			continue
		var bottom := box.position.y
		if bottom - floor_y < 0.35:
			continue
		var c2 := box.get_center()
		var probe := Vector3(c2.x, bottom - 0.06, c2.z)
		var held := not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.05, probe + Vector3.DOWN * 0.12, 1)).is_empty()
		for ab in others:
			if (ab as AABB).grow(0.02).has_point(probe):
				held = true
		if held:
			continue
		var w := maxf(box.size.x + 0.3, 0.9)
		var dd := maxf(box.size.z + 0.3, 0.6)
		var h := bottom - floor_y
		var desk := Node3D.new()
		desk.name = "TermDesk_" + id
		add_child(desk)
		desk.global_position = Vector3(c2.x, floor_y, c2.z)
		var steel := VaultDress.mat(Color(0.34, 0.36, 0.35), 0.25, 0.55)
		var dark := VaultDress.mat(Color(0.18, 0.19, 0.19), 0.2, 0.6)
		var part := func(sz: Vector3, at: Vector3, m: Material) -> void:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = sz
			mi.mesh = bm
			mi.material_override = m
			mi.position = at
			desk.add_child(mi)
		part.call(Vector3(w, 0.04, dd), Vector3(0, h - 0.02, 0), steel)
		part.call(Vector3(w * 0.42, h - 0.1, dd - 0.06), Vector3(-w * 0.27, (h - 0.1) * 0.5 + 0.06, 0), dark)
		for sx in [-1.0, 1.0]:
			part.call(Vector3(0.05, h - 0.04, dd - 0.08), Vector3(sx * (w * 0.5 - 0.04), (h - 0.04) * 0.5, 0), steel)
		Weathering.apply(desk, 0.6, false, true)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, h, dd)
		cs.shape = bs
		cs.position.y = h * 0.5
		sb.add_child(cs)
		desk.add_child(sb)

# a container with nothing to show for it (its mesh never made the export, or a later build's walls took its place):
# give it a body you can see, a squat safe if it's locked, a footlocker if not (build 20: "invisible safes")
var _shelled := {}
func _chest_shells() -> void:
	if Game.interior():
		return
	for c in Game.W.get("chests", []):
		var id := String(c.id)
		if _shelled.has(id):
			continue
		var cp := Vector3(float(c.x), float(c.get("y", Game.height(float(c.x), float(c.z)))), float(c.z))
		if Vector2(cp.x - player.global_position.x, cp.z - player.global_position.z).length() > 40.0:
			continue
		var ck: String = chunks.key_of(cp)
		if not chunks.loaded.has(ck):
			continue
		_shelled[id] = true
		var seen := false
		var roots: Array = [chunks.loaded[ck]]
		if frontier:
			roots.append(frontier)
		for r in roots:
			for m in (r as Node).find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if not mi.is_visible_in_tree():
					continue
				var ab: AABB = mi.global_transform * mi.get_aabb()
				if ab.size.length() > 4.0 or ab.size.length() < 0.2:
					continue
				var cc := ab.get_center()
				if Vector2(cc.x - cp.x, cc.z - cp.z).length() < 0.7 and ab.end.y > cp.y - 0.2 and ab.position.y < cp.y + 1.0:
					seen = true
					break
			if seen:
				break
		if seen:
			continue
		# stand it on whatever floor is under it
		var fy := Game.height(cp.x, cp.z)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cp + Vector3.UP * 0.8, cp + Vector3.DOWN * 3.0, 1, [player.get_rid()]))
		if not hit.is_empty():
			fy = float(hit.position.y)
		var body := Node3D.new()
		body.name = "Shell_" + id
		add_child(body)
		body.global_position = Vector3(cp.x, fy, cp.z)
		body.rotation.y = float(hash(id) % 4) * PI * 0.5
		var locked: bool = c.get("lock") != null
		var steel := VaultDress.mat(Color(0.24, 0.27, 0.26) if locked else Color(0.3, 0.33, 0.25), 0.35, 0.6)
		var dark := VaultDress.mat(Color(0.08, 0.08, 0.08), 0.3, 0.5)
		var brass := VaultDress.mat(Color(0.62, 0.5, 0.26), 0.6, 0.4)
		var part := func(sz: Vector3, at: Vector3, m: Material, cyl := false) -> void:
			var mi := MeshInstance3D.new()
			if cyl:
				var cm := CylinderMesh.new()
				cm.top_radius = sz.x
				cm.bottom_radius = sz.x
				cm.height = sz.y
				cm.radial_segments = 14
				mi.mesh = cm
				mi.rotation.x = PI * 0.5
			else:
				var bm := BoxMesh.new()
				bm.size = sz
				mi.mesh = bm
			mi.material_override = m
			mi.position = at
			body.add_child(mi)
		var sz := Vector3(0.7, 0.85, 0.6) if locked else Vector3(0.95, 0.5, 0.55)
		part.call(sz, Vector3(0, sz.y * 0.5, 0), steel)
		if locked:
			part.call(Vector3(0.6, 0.72, 0.02), Vector3(0, 0.44, 0.305), dark)
			part.call(Vector3(0.09, 0.04, 0), Vector3(0.05, 0.5, 0.33), brass, true)
			part.call(Vector3(0.14, 0.03, 0.03), Vector3(-0.18, 0.42, 0.33), brass)
			for hy in [0.2, 0.68]:
				part.call(Vector3(0.04, 0.12, 0.05), Vector3(0.33, hy, 0.31), dark)
		else:
			for bx in [-0.3, 0.3]:
				part.call(Vector3(0.06, 0.52, 0.57), Vector3(bx, 0.26, 0), dark)
			part.call(Vector3(0.12, 0.1, 0.03), Vector3(0, 0.4, 0.285), brass)
		Weathering.apply(body, 0.7, false, true)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position.y = sz.y * 0.5
		sb.add_child(cs)
		body.add_child(sb)
		# the label's anchor follows the body (the prompt and the safe are one thing)
		c["y"] = fy + 0.1

# the room you're standing in gets its furniture (and the one you left gives it back)
var furnished := -1
var cell_lights: Array = []
var furnish_node: Node3D
func _furnish_tick() -> void:
	if Game.area != "cells":
		return
	var c := Game.cell_at(player.global_position.x, player.global_position.z)
	if c == furnished or c < 0:
		return
	if furnish_node and is_instance_valid(furnish_node):
		furnish_node.queue_free()
	town.forget("cell%d" % furnished)
	furnished = c
	furnish_node = Furnish.room(self, Game.CELLS[c], "cell%d" % c)
	# the room you're in casts shadows from its lamps; the others don't need to
	for i in cell_lights.size():
		for l in cell_lights[i]:
			(l as OmniLight3D).shadow_enabled = i == c and int(Quality.current(quality).shadow) > 0
	_bake_cell.call_deferred(c)

# the room's walkable floor, once its furniture's collision is in
func _bake_cell(c: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if c != furnished:
		return
	var C: Dictionary = Game.CELLS[c]
	var y := float(Game.L.consts.CELLS.y)
	town.bake_box("cell%d" % c, AABB(Vector3(float(C.ox) - float(C.W2) * 0.5 - 1.0, y - 1.0, float(C.oz) - float(C.D2) * 0.5 - 1.0), Vector3(float(C.W2) + 2.0, 4.5, float(C.D2) + 2.0)))

# wedged inside a solid (a wall you slipped through, a tank you spawned into)? step out of its nearest side
func _unstick() -> void:
	if Game.dev.get("noclip", false) or (buggy and buggy.driving) or Game.area != "world":
		return
	var p: Vector3 = player.global_position + Vector3.UP * 0.9
	for s in Game.region.solids:
		if p.x > float(s[0]) + 0.05 and p.x < float(s[1]) - 0.05 and p.z > float(s[2]) + 0.05 and p.z < float(s[3]) - 0.05 and p.y > float(s[4]) and p.y < float(s[5]) - 0.2:
			var opts := [[p.x - float(s[0]), Vector3(float(s[0]) - 0.6, 0, p.z)], [float(s[1]) - p.x, Vector3(float(s[1]) + 0.6, 0, p.z)],
				[p.z - float(s[2]), Vector3(p.x, 0, float(s[2]) - 0.6)], [float(s[3]) - p.z, Vector3(p.x, 0, float(s[3]) + 0.6)]]
			opts.sort_custom(func(a, b): return a[0] < b[0])
			var o: Vector3 = opts[0][1]
			player.global_position = Vector3(o.x, Game.height(o.x, o.z) + 0.2, o.z)
			return

func _calm(o) -> void:
	var m = o.npc
	enemies.erase(o)
	if is_instance_valid(m):
		m.global_position = o.global_position
		m.hostile = false
		m.visible = true
		m.collision_layer = 4
		m.set_physics_process(true)
	o.queue_free()

func npc_died(e) -> void:
	var n = e.npc
	Game.flags["npcDead_" + String(n.id)] = 1
	if not (String(n.id) in GUARDS) and not n.has_meta("story_fight"):
		Game.add_karma(-10, "Murdered " + String(n.display_name))
	Game.msg(String(n.display_name) + " is dead.")
	Game.npc_lost(String(n.id))
	npcs.erase(n)
	for i in live_npc.keys():
		if live_npc[i] == n:
			live_npc.erase(i)
	n.queue_free()

# a quest started or finished: anyone it summons appears if their chunk is already loaded
func refresh_spawns() -> void:
	if chunks == null:
		return
	for k in chunks.loaded_keys():
		_spawn_chunk(k)

# a flag changed: people whose story says they've gone, go (unless they're talking to you or in a fight), and
# anybody who should now be here appears
func refresh_people() -> void:
	if chunks == null:
		return
	for i in live_npc.keys():
		var n = live_npc[i]
		if Game.flag_allowed(Game.region.npcs[i]) or n == dialog_npc or n.follow or n.hostile:
			continue
		npcs.erase(n)
		live_npc.erase(i)
		n.queue_free()
	for i in live_enemy.keys():
		var e = live_enemy[i]
		if Game.flag_allowed(Game.region.enemies[i]) or (e.hostile and e.state == "chase"):
			continue
		enemies.erase(e)
		live_enemy.erase(i)
		e.queue_free()
	refresh_spawns()

# a conversation that ends with someone drawing on you: they fight with their own numbers if the story gives them
func story_fight(id: String) -> void:
	for n in npcs:
		if String(n.id) == id and not n.hostile:
			n.set_meta("story_fight", true)
			provoke(n, 0.0, Vector3.ZERO, false, true)
			return

func make_hostile(id: String) -> void:
	for e in enemies:
		if String(e.get("eid")) == id and not e.dead:
			e.hostile = true
			e.state = "chase"
			for o in enemies:
				if o != e and not o.dead and o.group != "" and o.group == e.group:
					o.hostile = true
					o.state = "chase"

func nearest_pool() -> Variant:
	var best = null
	var bd := 1e9
	for p in Game.region.pools:
		var d := Vector2(float(p.x) - player.global_position.x, float(p.z) - player.global_position.z).length()
		if p.get("glow", false) and d < bd:
			bd = d
			best = {"x": p.x, "z": p.z}
	return best

func nearest_pickup(item: String, fallback: String) -> Variant:
	var best = null
	var bd := 1e9
	for p in Game.W.get("pickups", []):
		if String(p.item) == item and not Game.looted.has("pk_" + String(p.id)):
			var d := Vector2(float(p.x) - player.global_position.x, float(p.z) - player.global_position.z).length()
			if d < bd:
				bd = d
				best = {"x": p.x, "z": p.z}
	return best if best != null else Game.DB.locs.get(fallback)

func queue_trade(id: String) -> void:
	pending_trade = id

# the Spur's tables open once the dialogue that offered them has closed
var pending_casino: Array = []
func queue_casino(g: String, m: int) -> void:
	if in_dialog():
		pending_casino = [g, m]
	else:
		hud.casino.open(g, m)

# ---------------------------------------------------------------- command-line hooks for automated checks:
#   -- --shot=/path.png --at=x,z,yaw,pitch   render a few frames from a spot, save a screenshot, quit
#   -- --selftest                            play the slice's quests through and print the results
func _test_hooks() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("area") and Game.area != String(args.area):
		Game.booted = true
		var v := String(args.get("at", "-19,554,-1.57")).split(",")
		Game.load_area(String(args.area))
		Game.pending_pos = [float(v[0]), Game.height(float(v[0]), float(v[1])), float(v[1]), float(v[2]) if v.size() > 2 else 0.0]
		restart_keep()
		return
	if args.has("at") and (not args.has("area") or Game.area == String(args.area)):
		var v := String(args.at).split(",")
		player.global_position = Vector3(float(v[0]), Game.height(float(v[0]), float(v[1])) + 0.1, float(v[1]))
		player.yaw = float(v[2]) if v.size() > 2 else 0.0
		player.pitch = float(v[3]) if v.size() > 3 else 0.0
		# a fifth number: that high above the ground (on a tower, a roof)
		if v.size() > 4:
			player.global_position.y += float(v[4])
	if args.has("trade"):
		await _wait(5)
		Game.caps = 900
		hud.screens.open_trade(String(args.trade))
		if args.has("tradesel"):
			hud.screens.shop_sel = String(args.tradesel)
			hud.screens._render_trade()
	if args.has("loadscreen"):
		await _wait(5)
		hud.screens.open_load(hud.screens.close)
	if args.has("pausemenu"):
		await _wait(5)
		hud.toggle_pause()
	if args.has("silo"):
		# Silo 9's launch or scuttle on a short fuse, for looking at
		Game.flags["gb_hello"] = 1
		await _wait(20)
		Game.flags.erase("radio")
		hud.screens.close()
		Game.dev["god"] = true
		Game.flags["silo_end"] = "launched" if String(args.silo) == "launch" else "blown"
		Game.flags["silo_seq"] = "launch" if String(args.silo) == "launch" else "scuttle"
		Game.flags["silo_count"] = float(args.get("silocount", "3"))
		if args.has("siloburst"):
			Game.flags.erase("silo_seq")
			silo._burst()
	if args.has("startq"):
		for q in String(args.startq).split(","):
			Game.start(q)
	if args.has("selftest"):
		await _selftest()
	if args.has("newgame"):
		await _newgame_test()
	if args.has("gungrid"):
		await _gun_grid()
	if args.has("aitest"):
		await _ai_test()
	if args.has("khtest"):
		await _khole_test()
	if args.has("northtest"):
		await _north_test()
	if args.has("b17test"):
		await _b17_test()
	if args.has("b18test"):
		await _b18_test()
	if args.has("b19test"):
		await _b19_test()
	if args.has("heights"):
		var hv := String(args.heights).split(",")
		for zz in range(int(hv[1]), int(hv[3]) + 1, int(hv[4])):
			var row := ""
			for xx in range(int(hv[0]), int(hv[2]) + 1, int(hv[4])):
				row += "%6.1f" % Game.height(xx, zz)
			print("H ", zz, " ", row)
		get_tree().quit()
	if args.has("floataudit"):
		_float_audit()
	if args.has("towertest"):
		await _tower_test()
	if args.has("doortest"):
		await _door_test()
	if args.has("b20test"):
		await _b20_test()
	if args.has("b21test"):
		await _b21_test()
	if args.has("b22test"):
		await _b22_test()
	if args.has("b23test"):
		await _b23_test()
	if args.has("b24test"):
		await _b24_test()
	if args.has("ashtest"):
		await _ash_test()
	if args.has("storytest"):
		await _story_test()
	if args.has("forgetest"):
		await _forge_test()
	if args.has("term"):
		# the terminal screen: open, or locked (term=lock level)
		var lv := int(String(args.term)) if String(args.term) != "" else 0
		var te := [["Record 1 of 3", "Shift 4. Coolant pressure low again. Halloran says it's the gauge."], ["Record 2 of 3", "Shift 5. It is not the gauge."], ["Record 3 of 3", "Shift 6. Evacuation ordered."]]
		for i in int(args.get("termn", "0")):
			te.append(["Extra record %d" % (i + 1), "Filler entry."])
		hud.term.open("MERIDIAN REACTOR // SHIFT LOG", te, lv, "test_term")
		await _wait(40)
		if lv > 0 and args.has("guess"):
			hud.term._guess("XXXXX")
			await _wait(20)
	if args.has("lineup"):
		# a row of people/creatures in front of you, frozen, facing you (checking how they look)
		Game.dev.noai = true
		var ts := String(args.lineup).split(",")
		var f := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
		var r := Vector3(cos(player.yaw), 0, -sin(player.yaw))
		for i in ts.size():
			var p: Vector3 = player.global_position + f * 4.5 + r * (i - (ts.size() - 1) * 0.5) * 1.3
			var e = events._enemy(ts[i], p.x, p.z, false)
			if e:
				e.face_yaw = atan2(-f.x, -f.z)
				e.model.rotation.y = e.face_yaw
	if args.has("aimprobe"):
		# where each gunman's muzzle points, against where you are, through a fight
		get_tree().create_timer(2.5, false).timeout.connect(func():
			for k in 14:
				await get_tree().create_timer(0.4, false).timeout
				for e in enemies:
					if not is_instance_valid(e) or e.dead or e.ap == null:
						continue
					# the gun arm: from the shoulder to the hand, against the line from the shoulder to you
					var sk := e.model.find_child("Skeleton3D", true, false) as Skeleton3D
					if sk == null:
						continue
					var sh: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin
					var hd: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_r")).origin
					var fwd: Vector3 = (hd - sh).normalized()
					var to: Vector3 = (player.global_position + Vector3.UP * 1.3 - sh).normalized()
					var faceoff := rad_to_deg(absf(wrapf(atan2(player.global_position.x - e.global_position.x, player.global_position.z - e.global_position.z) - e.face_yaw, -PI, PI)))
					var mf: Vector3 = e.model.global_basis.z
					print("AIMP %s st=%s anim=%s act=%.2f w=%.2f ang=%.0f up=%.2f face=%.0f tw=%.2f modelz=%s fy=%.2f" % [e.type, e.state, e.ap.current_animation, e.act_t, e.aim_hold.weight if e.aim_hold else -1.0, rad_to_deg(fwd.angle_to(to)), fwd.y, faceoff, e.lt.twist if e.lt else 0.0, str(mf.snapped(Vector3.ONE * 0.01)), e.face_yaw])
			get_tree().quit())
	if args.has("shootdrum"):
		# the nearest fuel drum takes a bullet after a delay (checking the burn, the blast and the chain)
		get_tree().create_timer(float(args.shootdrum), false).timeout.connect(func():
			var ds := barrels.find_at(player.global_position, 40.0)
			print("DRUMS near ", ds.size(), " of ", barrels.all.size())
			if not ds.is_empty():
				ds[0].hit(5.0, ds[0].global_position + Vector3.UP * 0.5, Vector3.FORWARD))
	if args.has("killall"):
		# everything in the lineup or the fight dies a second later (checking how they fall)
		get_tree().create_timer(float(args.killall), false).timeout.connect(func():
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead:
					e.hit(9999.0, e.global_position + Vector3.UP, Vector3.FORWARD))
	if args.has("fight"):
		# hostiles a little way off, coming for you (god mode on): checking how they move, aim and shoot
		Game.dev.god = true
		var ts := String(args.fight).split(",")
		var f := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
		var r := Vector3(cos(player.yaw), 0, -sin(player.yaw))
		for i in ts.size():
			var p: Vector3 = player.global_position + f * float(args.get("fightd", 11.0)) + r * (i - (ts.size() - 1) * 0.5) * 2.5
			var e = events._enemy(ts[i], p.x, p.z, true)
			if e:
				e.state = "chase"
	if args.has("third"):
		player.tp.set_on(true)
	if args.has("itemgrid"):
		# every item's ground model in rows in front of you (checking how they read)
		var ids := ["cram", "stew", "sun_pop", "purified_water", "dirty_water", "rotgut", "glowshine", "k_fizz", "stimpak", "super_stim", "radaway", "rad_tabs",
			"jerky", "ox_steak", "med_herbs", "frag", "pipe_bomb", "pulse_nade", "ammo_9", "ammo_44", "shells", "cell", "scrap_metal", "duct_tape",
			"copper_wire", "circuit", "gears", "fuel_can", "glow_fungus", "spur_chip", "keycard", "holotape", "fusion_cell", "leather_jacket", "pipe_pistol", "hunting_rifle"]
		var f := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
		var r := Vector3(cos(player.yaw), 0, -sin(player.yaw))
		for i in ids.size():
			var m := ItemModels.build(ids[i])
			add_child(m)
			var p: Vector3 = player.global_position + f * (1.3 + (i / 6) * 0.42) + r * ((i % 6) - 2.5) * 0.42
			m.global_position = Vector3(p.x, Game.height(p.x, p.z), p.z)
			m.scale = Vector3.ONE * 1.25
	if args.has("gfxmenu"):
		await _wait(5)
		hud.toggle_pause()
		hud._open_gfx()
	if args.has("navshow"):
		TownLife.debug_on = true
	if args.has("lifelog"):
		_lifelog()
	if args.has("raytest"):
		await _wait(40)
		for e in enemies:
			var from: Vector3 = e.global_position + Vector3(4, 1.6, 0)
			var q := PhysicsRayQueryParameters3D.create(from, e.global_position + Vector3.UP * 1.0, 1 | 2 | 4)
			var h := get_world_3d().direct_space_state.intersect_ray(q)
			print("RAY ", e.type, " layer ", e.collision_layer, " shapes ", e.get_child_count(), " hit ", (h.collider.name if h else "nothing"), " pos ", e.global_position)
		get_tree().quit()
	if args.has("floatscan"):
		_floatscan()
	if args.has("roofscan"):
		await _roofscan()
	if args.has("propscan"):
		await _propscan()
	if args.has("opendoor") and vault_dress:
		vault_dress.open_great_door()
	if args.has("topdown"):
		# an overhead orthographic view (checking a room's layout), ceilings hidden by the near plane
		var v := String(args.topdown).split(",")
		var tc := Camera3D.new()
		add_child(tc)
		tc.projection = Camera3D.PROJECTION_ORTHOGONAL
		tc.size = float(v[3]) if v.size() > 3 else 24.0
		tc.global_position = Vector3(float(v[0]), float(v[2]), float(v[1]))
		tc.rotation = Vector3(-PI / 2.0, 0, 0)
		tc.near = 0.6
		tc.current = true
	if args.has("matdump"):
		# list the meshes and materials around a spot (finding which exported material a prop uses)
		var v := String(args.matdump).split(",")
		var c := Vector3(float(v[0]), 0, float(v[1]))
		await _wait(20)
		for mi in find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var cc := ab.get_center()
			if Vector2(cc.x - c.x, cc.z - c.z).length() < float(v[2]) or (ab.size.length() >= 30.0 and ab.grow(0.5).has_point(Vector3(c.x, ab.get_center().y, c.z))):
				for i in mi.mesh.get_surface_count():
					var m = mi.get_active_material(i)
					print("MAT %s %s size %s surf %d mat %s %s vc %s tex %s" % [mi.name, str(cc.snapped(Vector3.ONE * 0.1)), str(ab.size.snapped(Vector3.ONE * 0.1)), i, str(m.resource_name) if m else "-", m.get_class() if m else "", str(m.vertex_color_use_as_albedo if m is StandardMaterial3D else "") + (" alb " + str(m.albedo_color) + " sh " + str(m.shading_mode) if m is StandardMaterial3D else ""), str(m.albedo_texture.resource_path if m is StandardMaterial3D and m.albedo_texture else "")])
		get_tree().quit()
	if args.has("casinotest"):
		await _casino_test()
	if args.has("casino"):
		Game.caps = maxi(Game.caps, 800)
		var cz := String(args.casino).split(":")
		hud.casino.open(cz[0], int(cz[1]) if cz.size() > 1 else 0)
		match cz[0]:
			"blackjack":
				hud.casino.fast = true
				await hud.casino.deal()
				hud.casino.fast = false
			"roulette":
				for k in ["17", "RED", "2nd 12", "0"]:
					hud.casino.place_rl(k)
				hud.casino.rl.hist = [3, 26, 0, 17, 32, 8]
				hud.casino.rl.last = 8
			"dice":
				hud.casino.place_dc("pass")
				hud.casino.place_dc("field")
				hud.casino.dc.point = 6
				hud.casino.dc.hist = [8, 4, 6]
				hud.casino._render()
	if args.has("dev"):
		hud.toggle_dev()
		hud.dev.show_page(String(args.dev))
	if args.has("forge"):
		forge.toggle()
		if String(args.forge) == "build":
			for i in 6:
				forge.cur = i
				forge._make_ghost()
				player.yaw += 0.35
				await get_tree().physics_frame
				await get_tree().physics_frame
				forge.place()
	if args.has("furntest"):
		await _furn_test()
	if args.has("celltest"):
		await _cell_test(int(args.celltest) if String(args.celltest) != "" else 1)
	if args.has("perf"):
		await _perf_report()
	if args.has("pip"):
		Game.discover("dustwell")
		Game.give("magnum", 1)
		Game.give("combat_knife", 1)
		Game.give("ketarad", 1)
		Game.give("stimpak", 3)
		Game.start("caravan_rescue")
		Game.on_kill("raider")
		Game.on_kill("raider")
		Game.on_kill("hound")
		Game.flags["read_sheriff"] = 1
		Game.rad = 18.0
		Game.buffs["dr"] = {"amt": 10.0, "t": 60.0}
		if String(args.pip) == "PARTY":
			Game.flags["leftVault"] = 1
			recruit("jory", true)
			Game.flags["appr_jory"] = 34
			Game.flags["appr_sable"] = -18
			Game.start("jory_wagon")
		if String(args.pip) == "GUNSMITH":
			Game.give("hunting_rifle", 1)
			Game.give("scrap_metal", 12)
			Game.give("gears", 5)
			Game.give("circuit", 3)
			Game.fit_mod("hunting_rifle", "scope")
			hud.pip.at_bench = true
			hud.pip.sel_gun = "hunting_rifle"
		hud.toggle_pip()
		hud.pip.show_tab(String(args.pip))
	if args.has("geodump"):
		# every drawn thing near a spot, whatever it is (finding a stray mesh)
		var v := String(args.geodump).split(",")
		var c := Vector3(float(v[0]), 0, float(v[1]))
		await _wait(40)
		for gi in find_children("*", "GeometryInstance3D", true, false):
			var g := gi as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var ab: AABB = g.global_transform * g.get_aabb()
			if Vector2(ab.get_center().x - c.x, ab.get_center().z - c.z).length() < float(v[2]) and ab.size.length() < 30.0:
				var col := ""
				if g is MeshInstance3D and (g as MeshInstance3D).mesh:
					var m = g.material_override if g.material_override else (g as MeshInstance3D).get_active_material(0)
					col = str((m as StandardMaterial3D).albedo_color) if m is StandardMaterial3D else str(m)
				if g is CPUParticles3D:
					var cp := g as CPUParticles3D
					col = "amount %d color %s mesh %s local %s emit %s gpos %s meta %s" % [cp.amount, str(cp.color), str(cp.mesh), str(cp.local_coords), str(cp.emitting), str(cp.global_position.snapped(Vector3.ONE * 0.1)), str(cp.get_meta_list())]
				print("GEO ", g.get_class(), " ", g.get_path(), " c ", ab.get_center().snapped(Vector3.ONE * 0.1), " s ", ab.size.snapped(Vector3.ONE * 0.1), " ", col)
		get_tree().quit()
	if args.has("reddump"):
		# anything drawn in red within reach of the camera (finding a stray red streak)
		await _wait(60)
		var cp0: Vector3 = player.cam.global_position
		for gi in find_children("*", "GeometryInstance3D", true, false):
			var g := gi as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var ab: AABB = g.global_transform * g.get_aabb()
			if ab.grow(1.0).has_point(cp0) or ab.get_center().distance_to(cp0) < 25.0:
				var cols: Array = []
				if g is MeshInstance3D and (g as MeshInstance3D).mesh:
					for si in (g as MeshInstance3D).mesh.get_surface_count():
						var m = g.material_override if g.material_override else (g as MeshInstance3D).get_active_material(si)
						if m is StandardMaterial3D:
							cols.append((m as StandardMaterial3D).albedo_color)
						elif m is ShaderMaterial:
							cols.append(str((m as ShaderMaterial).shader.resource_path) if (m as ShaderMaterial).shader else "shader")
				print("RED ", g.get_class(), " ", g.get_path(), " c ", ab.get_center().snapped(Vector3.ONE * 0.1), " s ", ab.size.snapped(Vector3.ONE * 0.1), " ", cols)
		get_tree().quit()
	if args.has("vmdump"):
		await _wait(30)
		for mi in player.gun.find_children("*", "GeometryInstance3D", true, false):
			var gi := mi as GeometryInstance3D
			var col := ""
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
				for si in (gi as MeshInstance3D).mesh.get_surface_count():
					var m = (gi as MeshInstance3D).get_active_material(si)
					col += " " + (str((m as StandardMaterial3D).albedo_color) if m is StandardMaterial3D else str(m))
			print("VM ", gi.get_path(), " vis ", gi.is_visible_in_tree(), " at ", gi.global_position - player.cam.global_position, " ", col)
		get_tree().quit()
	if args.has("quest"):
		# start a quest for a screenshot (--quest=lights_over_ridge)
		for q in String(args.quest).split(","):
			Game.start(q)
	if args.has("tonemap"):
		env.tonemap_mode = {"filmic": Environment.TONE_MAPPER_FILMIC, "aces": Environment.TONE_MAPPER_ACES, "agx": Environment.TONE_MAPPER_AGX}.get(String(args.tonemap), env.tonemap_mode)
		if args.has("white"):
			env.tonemap_white = float(args.white)
	if args.has("tod"):
		Game.time = float(args.tod)
	if args.has("quality"):
		set_quality(int(args.quality))
	if args.has("wx") and atmos:
		atmos.set_weather(String(args.wx), true)
		atmos.cur = Atmos.WX[String(args.wx)].duplicate()
	if args.has("weapon"):
		if String(args.weapon) != "none":
			Game.give(String(args.weapon), 1)
		Game.weapon = "" if String(args.weapon) == "none" else String(args.weapon)
		player.weapon_changed()
		if args.has("sidecam"):
			# look at the hands from the right side, to check the grip
			var sc := Camera3D.new()
			add_child(sc)
			await _wait(3)
			var sk: Skeleton3D = player.vm.skel
			var gp: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_r")).origin
			var sd := -1.0 if String(args.sidecam) == "left" else 1.0
			sc.global_position = gp + player.cam.global_basis.x * 0.9 * sd + player.cam.global_basis.y * 0.15
			sc.look_at(gp, Vector3.UP)
			sc.fov = 40.0
			sc.near = 0.01
			sc.current = true
	if args.has("screen"):
		var sv := String(args.screen).split(":")
		match sv[0]:
			"trade": hud.screens.open_trade(sv[1] if sv.size() > 1 else "cass")
			"lock":
				Game.give("bobby_pin", 4)
				Game.stats.agility = 7
				hud.screens.open_lock(1, "Footlocker", func(_ok): pass)
				hud.screens.lp.pin = 0.5
				hud.screens.lp.turn = 0.4
			"term":
				var l: Dictionary = Game.DB.lore.values()[0]
				hud.screens.open_term(String(l.h), String(l.t))
				hud.screens.term_i = String(l.t).length() - 2
			"loot": hud.screens.open_loot("Footlocker", [["stimpak", 2], ["ammo_9", 24], ["caps", 35], ["scrap_metal", 3]], func(_e): pass)
			"craft":
				Game.give("scrap_metal", 6)
				Game.give("duct_tape", 3)
				hud.open_craft(true)
			"dialog":
				var who := sv[1] if sv.size() > 1 else "cass"
				var found = null
				for n in npcs:
					if n.id == who:
						found = n
				start_dialog(found, who)
				if sv.size() > 2:
					show_node(sv[2])
			"banner": Game.banner("QUEST COMPLETE", "Bad Water")
			"title": hud.screens.open_title()
			"loader":
				var LS := LoadScreen.it()
				await _wait(2)
				if sv.size() > 1 and sv[1] == "splash":
					# the picture for the native boot splash: the intro's last frame without the bar and the words
					LS.play_intro(func(): pass)
					LS.t = 30.0
					for c in [LS.bar, LS.status, LS.tip, LS.stages, LS.skip_l, LS.card, LS.card_sub]:
						c.visible = false
					LS.ash.preprocess = 20.0
				elif sv.size() > 1 and sv[1] == "intro":
					LS.play_intro(func(): pass)
					LS.t = float(sv[2]) if sv.size() > 2 else 1.0
					LS.target = 0.35
					LS.shown_p = 0.35
				else:
					LS._show("Loading slot 1")
					LS.target = 0.64
					LS.shown_p = 0.64
				await _wait(5)
			"menu":
				MainMenu.it().open()
				await _wait(30)
				if sv.size() > 1:
					MainMenu.it().call("_page_" + sv[1])
					await _wait(10)
			"drive":
				Game.flags["buggy"] = {"fixed": true}
				Game.give("buggy_key", 1)
				buggy.queue_free()
				buggy = Buggy.new()
				add_child(buggy)
				buggy.setup(self)
				await _wait(3)
				buggy.enter()
				for i in 40:
					buggy.drive(1.0 / 60.0, Vector2(0.3, -1.0))
					await get_tree().physics_frame
			"create":
				hud.screens.open_title()
				hud.screens._create()
			"focus":
				await _wait(10)
				hud.focus.enter()
			"caravan":
				Game.booted = true
				events.start("caravan", Vector2(player.global_position.x + 14.0, player.global_position.z - 14.0))
				Game.G.recruit("jory")
				await _wait(30)
	if args.has("sidecam_e") or args.has("tpside"):
		# a camera beside the first fighter (or beside you in third person), following it: checking how they hold a gun
		var scam := Camera3D.new()
		scam.fov = 45.0
		add_child(scam)
		scam.current = true
		var who: Node3D = player
		var follow := func():
			var e0 = null
			for e in enemies:
				if is_instance_valid(e) and not e.dead and (not args.has("fight") or String(e.type) in String(args.fight).split(",")):
					e0 = e
					break
			var tgt: Node3D = e0 if args.has("sidecam_e") and e0 else player
			var fw: Vector3 = Vector3(-sin(player.yaw), 0, -cos(player.yaw)) if tgt == player else Vector3(sin(tgt.model.rotation.y), 0, cos(tgt.model.rotation.y))
			var rt := fw.cross(Vector3.UP).normalized()
			var ang := float(args.get("camang", "90")) / 180.0 * PI
			var off: Vector3 = (rt * cos(ang - PI * 0.5) * -1.0 + fw * sin(ang - PI * 0.5)).normalized() if false else (fw.rotated(Vector3.UP, ang)) * float(args.get("camd", "2.6"))
			scam.global_position = tgt.global_position + off + Vector3.UP * 1.45
			scam.look_at(tgt.global_position + Vector3.UP * 1.25, Vector3.UP)
		get_tree().process_frame.connect(func(): if is_instance_valid(scam): follow.call())
	if args.has("shot"):
		var fire_at := int(args.get("fireat", "-1"))
		for i in int(args.get("frames", "40")):
			# --fireat=N: pull the trigger N frames before the picture (--fireat2 for a second shot earlier)
			if i == int(args.get("frames", "40")) - fire_at or (args.has("fireat2") and i == int(args.get("frames", "40")) - int(args.fireat2)):
				Game.mag = maxi(Game.mag, 5)
				player.fire_cd = 0.0
				player.fire()
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(args.shot)
		print("SHOT ", args.shot, " fps ", Engine.get_frames_per_second())
		get_tree().quit()
	elif args.has("selftest"):
		get_tree().quit()

# render statistics from where the player stands, split by what is being drawn
func _perf_report() -> void:
	for i in 20:
		await get_tree().process_frame
	var cam: Camera3D = player.cam
	var groups := {"characters": 0, "chunk_small": 0, "chunk_big": 0, "grass": 0, "other": 0}
	var tris := {"characters": 0, "chunk_small": 0, "chunk_big": 0, "grass": 0, "other": 0}
	var mats := {}
	for n in find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var aabb: AABB = g.global_transform * g.get_aabb()
		var d := aabb.get_center().distance_to(cam.global_position)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end:
			continue
		if not cam.is_position_in_frustum(aabb.get_center()) and d > aabb.size.length():
			continue
		var k := "other"
		var p := g.get_parent()
		while p:
			if p is CharacterBody3D:
				k = "characters"
				break
			if p == chunks:
				k = "chunk_small" if g.name.begins_with("s_") else "chunk_big"
				break
			p = p.get_parent()
		if g is MultiMeshInstance3D:
			k = "grass"
		var surf := 1
		var t := 0
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var m: Mesh = (g as MeshInstance3D).mesh
			surf = m.get_surface_count()
			for si in surf:
				var a := m.surface_get_arrays(si) if m is ArrayMesh else []
				if a.size() > 0 and a[Mesh.ARRAY_INDEX] != null:
					t += a[Mesh.ARRAY_INDEX].size() / 3
		groups[k] += surf
		tris[k] += t
	print("PERF draw-surfaces ", groups)
	print("PERF triangles ", tris)
	print("PERF engine draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " primitives ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("PERF chunks loaded ", chunks.count(), " characters ", npcs.size() + enemies.size(), " physics bodies active ", enemies.filter(func(e): return e.global_position.distance_to(player.global_position) < 90.0).size())

func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _goto(p: Vector3, face: Vector3) -> void:
	player.global_position = p + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	var to := face - p
	player.yaw = atan2(-to.x, -to.z)
	await _wait(4)

# a new game from registration to the surface: wake in Haven 12, see the Overseer, draw your gear, open the great door
func _newgame_test() -> void:
	var out: Array = Game.test_log
	if Game.area == "world" and not Game.flags.get("leftVault"):
		Game.booted = true
		hud.screens.open_title()
		out.append("title mode " + hud.screens.mode)
		hud.screens._intro(0)
		hud.screens._create()
		hud.screens.cre.stats.agility = 7
		hud.screens.cre.points = 1
		hud.screens.cre_name.text = "Tess"
		out.append("create mode %s stats %s" % [hud.screens.mode, str(hud.screens.cre.stats)])
		hud.screens.close()
		Game.new_game("Tess", hud.screens.cre.stats, 1)
		return
	if Game.area == "vault":
		await _wait(20)
		out.append("in vault: area %s at %s name %s weapon '%s' (%s) quests %s objective %s" % [Game.area, str(player.global_position.snapped(Vector3.ONE * 0.1)), Game.player_name, Game.weapon, Game.iname(Game.weapon), str(Game.quests), str(Game.current_objective())])
		out.append("vault people %s, chunks %d" % [str(npcs.map(func(n): return n.id)), chunks.loaded.size()])
		out.append("door says: " + str(objects.point_label(_obj_point("vaultExit"))))
		out.append(await _talk("overseer", ["What happened", "So what", "I'll go", "Understood"]))
		out.append("exodus stage %d metOverseer %s target %s" % [Game.stage("exodus"), str(Game.flags.get("metOverseer")), str(quest_target())])
		var lk = _obj_near("chest")
		await _goto(_obj_pos(lk) + Vector3(0, 0, -1.3), _obj_pos(lk))
		out.append("at locker: " + str(_best_target().get("label", "nothing")))
		interact()
		if hud.screens.mode == "loot":
			hud.screens._take_all()
		Game.equip("pipe_pistol")
		out.append("gear: pistol %s knife %s stage %d weapon %s" % [Game.has("pipe_pistol"), Game.has("combat_knife"), Game.stage("exodus"), Game.weapon])
		var door = _obj_point("vaultExit")
		await _goto(_obj_pos(door) + Vector3(0, 0, -1.5), _obj_pos(door))
		out.append("at door: " + str(_best_target().get("label", "nothing")))
		interact()
		return
	await _wait(20)
	out.append("outside: area %s at %s leftVault %s exodus done %s daylight %s, objective %s" % [Game.area, str(player.global_position.snapped(Vector3.ONE * 0.1)), str(Game.flags.get("leftVault")), Game.is_done("exodus"), str(Game.quests.get("daylight")), str(Game.current_objective())])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

# the K-hole both ways: a blackout (via a second dose), then the Hole (shards, a talk, the clock running out, the way back)
func _khole_test() -> void:
	var out: Array = Game.test_log
	if Game.area == "world" and out.is_empty():
		Game.booted = true
		Game.flags["leftVault"] = 1
		await _wait(10)
		var p0: Vector3 = player.global_position
		Game.give("ketarad", 2)
		Game.use_item("ketarad")
		Game.use_item("ketarad")
		out.append("double dose: busy %s kholes %s drug %s" % [kh_busy, str(Game.flags.get("kholes")), str(Game.drugs.keys())])
		while kh_busy and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree() or Game.area != "world":
			return
		out.append("blackout: moved %.0f m to %s" % [p0.distance_to(player.global_position), str(player.global_position.snapped(Vector3.ONE))])
		Game.flags["khRetTest"] = {"x": player.global_position.x, "z": player.global_position.z}
		out.append("hole start: " + str(khole_start("hole")))
		return
	if Game.area == "khole":
		await _wait(20)
		out.append("in the hole at %s, timer %.1f, people %s, shards %d, label %s" % [str(player.global_position.snapped(Vector3.ONE)), float(Game.flags.get("khT", -1)),
			str(npcs.map(func(n): return n.id)), khole.shards.size(), khole.timer_lbl.text])
		var sh = _obj_point("echoa")
		if sh:
			await _goto(_obj_pos(sh) + Vector3(0, 0, -1.2), _obj_pos(sh))
			out.append("at shard: " + str(_best_target().get("label", "nothing")))
			objects.point_use(sh)
		out.append("echo_0 %s shards held %d" % [str(Game.flags.get("echo_0")), int(Game.inv.get("echo_shard", 0))])
		for n in npcs:
			if n.id == "ferryman":
				out.append("ferryman scale %.2f" % n.model.scale.y)
			if n.id == "gnorl":
				out.append("gnorl flipped %s" % str(absf(n.model.rotation.z - PI) < 0.01))
		out.append(await _talk("ferryman", []))
		out.append("waiting for the clock (%.1f s)" % float(Game.flags.get("khT", 0)))
		return
	await _wait(20)
	var r: Dictionary = Game.flags.get("khRetTest", {})
	out.append("back: area %s at %s, %.0f m from where we fell, khT %s, kholes %s" % [Game.area, str(player.global_position.snapped(Vector3.ONE)),
		Vector2(float(r.get("x", 0)) - player.global_position.x, float(r.get("z", 0)) - player.global_position.z).length(), str(Game.flags.get("khT")), str(Game.flags.get("kholes"))])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

# through a street door into a building and back out
# every room furnished in turn (the town's cells, or Haven 12's rooms): is any way through cut off? (build 23)
func _furn_test() -> void:
	await _wait(30)
	if Game.area == "cells":
		for i in Game.CELLS.size():
			var C: Dictionary = Game.CELLS[i]
			player.global_position = Vector3(float(C.ox), float(Game.L.consts.CELLS.y) + 0.3, float(C.oz))
			await get_tree().create_timer(2.2).timeout
	await _wait(10)
	for l in Furnish.audit:
		print("FURN ", l)
	print("FURN %d rooms furnished, %d mapped for the way through; the most floor left cut off anywhere %.2f m2 (%s)" % [Furnish.audit.size(), Furnish.rooms_checked, Furnish.worst, "ok" if Furnish.worst < 1.0 else "FAIL"])
	get_tree().quit()

func _cell_test(i: int) -> void:
	var out: Array = Game.test_log
	if Game.area == "world" and out.is_empty():
		Game.booted = true
		Game.flags["leftVault"] = 1
		var door = null
		for k in objects.grid:
			for o in objects.grid[k]:
				if o._k == "point" and String(o.id) == "cellin" and int(o.get("cellIn", -1)) == i:
					door = o
		if door == null:
			var o: Dictionary = Game.CELLS[i].out
			player.global_position = Vector3(float(o.x), Game.height(float(o.x), float(o.z)) + 0.2, float(o.z))
			await _wait(10)
			for k in objects.grid:
				for o2 in objects.grid[k]:
					if o2._k == "point" and String(o2.id) == "cellin" and int(o2.get("cellIn", -1)) == i:
						door = o2
		if door == null:
			out.append("no street door for cell %d" % i)
			for l in out:
				print("TEST ", l)
			get_tree().quit()
			return
		var o: Dictionary = Game.CELLS[i].out
		await _goto(_obj_pos(door) + Vector3(float(o.nx), 0, float(o.nz)) * 1.0, _obj_pos(door))
		out.append("street door %d: %s" % [i, str(_best_target().get("label", "nothing"))])
		Game.flags["cellTestFrom"] = [player.global_position.x, player.global_position.z]
		objects.point_use(door)
		return
	if Game.area == "cells":
		await _wait(20)
		out.append("inside at %s, people %s, chunks %d" % [str(player.global_position.snapped(Vector3.ONE * 0.1)), str(npcs.map(func(n): return n.id)), chunks.loaded.size()])
		var ex = null
		for k in objects.grid:
			for o in objects.grid[k]:
				if o._k == "point" and String(o.id) == "cellout" and int(o.get("cellOut", -1)) == i:
					ex = o
		out.append("exit: " + (str(objects.point_label(ex)) + " at " + str(_obj_pos(ex).snapped(Vector3.ONE * 0.1)) if ex else "none"))
		if ex:
			objects.point_use(ex)
		return
	await _wait(20)
	var f: Array = Game.flags.get("cellTestFrom", [0, 0])
	out.append("outside again at %s, %.1f m from where we went in, yaw %.2f" % [str(player.global_position.snapped(Vector3.ONE * 0.1)), Vector2(f[0] - player.global_position.x, f[1] - player.global_position.z).length(), player.yaw])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

# a fight on open ground: do the hostiles see you, hurt you, spread out, take cover, run?
func _ai_test() -> void:
	Game.booted = true
	Game.flags["leftVault"] = 1
	await _wait(30)
	var pp: Vector3 = player.global_position
	var foes: Array = []
	for sp in [["raider", 15.0, 0.0], ["raider", 13.0, 1.2], ["hound", 11.0, -1.0], ["hound", 12.0, 2.4]]:
		var a: float = sp[2]
		var e = events._enemy(String(sp[0]), pp.x + sin(a) * float(sp[1]), pp.z + cos(a) * float(sp[1]), true)
		foes.append(e)
	var hp0 := Game.hp
	Game.hp = 9999.0
	var tacs := {}
	var min_gap := 99.0
	for i in 60 * 12:
		await get_tree().physics_frame
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				tacs[e.type + ":" + e.tac] = 1
		var hs: Array = foes.filter(func(e): return e.type == "hound" and is_instance_valid(e))
		if hs.size() == 2:
			min_gap = minf(min_gap, hs[0].global_position.distance_to(hs[1].global_position))
		if i == 60 * 6:
			# hurt the first raider badly: it should look for cover or run
			foes[0].hit(foes[0].hp_max * 0.6, foes[0].global_position + Vector3.UP, Vector3.FORWARD)
	var lost := 9999.0 - Game.hp
	Game.hp = hp0
	var out: Array = []
	out.append("AI: damage taken %.0f in 12 s, states %s, hound spacing %.1f m" % [lost, str(tacs.keys()), min_gap])
	for e in foes:
		out.append("  %s %s hp %.0f/%.0f at %.1f m, sees %s" % [e.type, e.state, e.hp, e.hp_max, e.global_position.distance_to(player.global_position), str(e.can_see(player.global_position))])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

# every gun model side by side, with the grip (red) and the support hand (blue) marked
func _gun_grid() -> void:
	var models := {}
	for k in Game.DB.items:
		var it: Dictionary = Game.DB.items[k]
		if it.get("glb") and not models.has(it.glb):
			models[it.glb] = k
	var root := Node3D.new()
	add_child(root)
	var base: Vector3 = player.global_position + Vector3(0, 40, 0)
	root.global_position = base
	var i := 0
	var names := models.keys()
	names.sort()
	for glb in names:
		var mdl: Array = player.model_for(String(models[glb]))
		var holder := Node3D.new()
		root.add_child(holder)
		holder.position = Vector3((i % 4) * 1.25, -(i / 4) * 0.55, 0)
		var g: Node3D = (load(mdl[0]) as PackedScene).instantiate()
		holder.add_child(g)
		var fit: Basis = mdl[1]
		# muzzle to the right (+X), up +Y
		g.transform = Transform3D(Basis(Vector3.UP, -PI / 2) * fit, Vector3.ZERO)
		var bb := Humanoid.gun_bounds(g)
		var grip := Humanoid.grip_fit(bb, fit, mdl[2])
		var hg := Humanoid.guard_fit(bb, fit, mdl[2])
		for pc in [[grip, Color.RED], [hg, Color.BLUE]]:
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.025 / fit.get_scale().x
			sm.height = sm.radius * 2
			m.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = pc[1]
			mat.no_depth_test = true
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material_override = mat
			g.add_child(m)
			m.position = pc[0]
		var l := Label3D.new()
		l.text = String(glb)
		l.pixel_size = 0.0015
		l.position = Vector3(0, 0.2, 0)
		holder.add_child(l)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = base + Vector3(1.9, -0.9, 3.2)
	cam.fov = 55.0
	cam.current = true
	sun.rotation = Vector3(-0.6, 0.0, 0)

# forge: build, pick up and move, delete, undo, save with the game, a map slot, and spawn points going live
func _casino_test() -> void:
	var out: Array = []
	Game.booted = true
	await _wait(10)
	var cz: Casino = hud.casino
	cz.fast = true
	Game.caps = 5000
	Game.flags.erase("casinoBan")
	cz.open("blackjack")
	out.append("open: %s paused %s game %s" % [str(cz.is_open()), str(get_tree().paused), cz.game])
	# blackjack: scripted hands from a stacked shoe, listed in the order they are dealt (player, dealer, player, dealer, then hits)
	var stack := func(seq: Array, filler: String) -> void:
		cz.shoe = []
		for i in 80:
			cz.shoe.append({"r": filler, "s": 0})
		var rev := seq.duplicate()
		rev.reverse()
		for r in rev:
			cz.shoe.append({"r": String(r), "s": 1})
	cz.bet = 100
	stack.call(["K", "10", "7", "9"], "2")
	var c0 := Game.caps
	await cz.deal()
	await cz.stand()
	out.append("bj 17 v 19: %s, caps %+d" % [cz.bj.hands[0].res, Game.caps - c0])
	stack.call(["K", "6", "A", "5"], "2")
	c0 = Game.caps
	await cz.deal()
	out.append("bj natural: %s, caps %+d" % [cz.bj.hands[0].res, Game.caps - c0])
	stack.call(["8", "6", "8", "10", "3", "K"], "9")
	c0 = Game.caps
	await cz.deal()
	await cz.split()
	out.append("split eights: %d hands, cards %s" % [cz.bj.hands.size(), str(cz.bj.hands.map(func(h): return h.cards.map(func(c): return c.r)))])
	await cz.stand()
	await cz.stand()
	out.append("split result: %s dealer %d, caps %+d" % [str(cz.bj.hands.map(func(h): return h.res)), int(Casino.total(cz.bj.dealer).t), Game.caps - c0])
	stack.call(["6", "9", "5", "7", "10", "2"], "2")
	c0 = Game.caps
	await cz.deal()
	await cz.dbl()
	out.append("double on 11: bet %d total %d v dealer %d: %s, caps %+d" % [int(cz.bj.hands[0].bet), int(Casino.total(cz.bj.hands[0].cards).t), int(Casino.total(cz.bj.dealer).t), cz.bj.hands[0].res, Game.caps - c0])
	# roulette: every bet kind against a forced number
	cz.game = "roulette"
	cz._render()
	cz.bet = 10
	for k in ["17", "RED", "BLACK", "ODD", "2nd 12", "1-18", "0"]:
		cz.place_rl(k)
	var staked := cz._rl_staked()
	var win := 0
	for k in cz.rl.bets:
		if String(k) == "17":
			win += 360
		for o in Casino.OUTSIDE:
			if o[0] == k and Casino.outside_wins(String(k), 17):
				win += 10 * int(o[1])
	out.append("roulette on 17: staked %d, would pay %d (17 x36, BLACK, ODD, 2nd 12, 1-18)" % [staked, win])
	c0 = Game.caps
	await cz.spin()
	out.append("spin landed %d, bets cleared %s, caps %+d" % [int(cz.rl.last), str(cz.rl.bets.is_empty()), Game.caps - c0])
	cz.place_rl("RED")
	cz.vip()
	out.append("roulette table limit holds: %s" % str(cz._rl_staked() <= (2000 if cz.vip() else 500)))
	cz.rl.bets = {}
	# dice: come-out natural, then a point made, then a seven-out
	cz.game = "dice"
	cz._render()
	c0 = Game.caps
	cz.place_dc("pass")
	cz.resolve_roll(5, 6)
	out.append("dice 11 on come-out: caps %+d, point %d" % [Game.caps - c0, cz.dc.point])
	c0 = Game.caps
	cz.place_dc("pass")
	cz.resolve_roll(4, 4)
	out.append("dice 8 sets the point: %d" % cz.dc.point)
	cz.place_dc("field")
	cz.resolve_roll(1, 1)
	out.append("field on 2 pays double; still on %d" % cz.dc.point)
	cz.resolve_roll(5, 3)
	out.append("point made: caps %+d, point %d, bets %s" % [Game.caps - c0, cz.dc.point, str(cz.dc.bets)])
	c0 = Game.caps
	cz.place_dc("dont")
	cz.resolve_roll(6, 6)
	out.append("don't pass on 12: push, caps %+d" % [Game.caps - c0])
	cz.dc.bets = {}
	# slots: scoring and the governor chip's effect on Old Patsy
	out.append("score 777 %d, BARBAR? %d, rad rad x %d, 7 anywhere %d, none %d" % [Casino.score([5, 5, 5]), Casino.score([4, 4, 0]), Casino.score([3, 3, 1]), Casino.score([0, 1, 5]), Casino.score([0, 1, 2])])
	cz.game = "slots"
	for mood in ["", "fair", "mine"]:
		Game.flags["patsy"] = mood
		cz.machine = 0
		var tot := 0.0
		for i in 20000:
			tot += Casino.score([cz.spin_sym(), cz.spin_sym(), cz.spin_sym()])
		out.append("Old Patsy (%s) payback %.2f" % [cz.mood(), tot / 20000.0])
	Game.flags.erase("patsy")
	c0 = Game.caps
	await cz.pull()
	out.append("pull: reels %s, caps %+d" % [str(cz.sl.reels.map(func(r): return r[1])), Game.caps - c0])
	# the house limit: a big night gets you walked out
	Game.flags["casinoNet"] = {"day": Game.day, "net": cz.limit() - 50}
	cz.game = "roulette"
	cz.rl.bets = {}
	cz.place_rl("RED")
	cz.rl.bets = {}
	cz.payout(100)
	await cz.check_limit()
	out.append("past the limit: banned %s, open %s" % [str(Game.flags.get("casinoBan") == Game.day), str(cz.is_open())])
	cz.open("dice")
	out.append("banned tonight: opens %s" % str(cz.is_open()))
	out.append("high roller net tonight: %d" % int(Game.flags.casinoNet.net))
	Game.flags.erase("casinoBan")
	# through the dialogue, like Vex offers it
	Game.G.casino("roulette")
	out.append("gapi casino opens: %s %s" % [str(cz.is_open()), cz.game])
	cz.close()
	out.append("closed: paused %s" % str(get_tree().paused))
	# walking up to the tables in the Spur's hall
	if Game.area == "world":
		cz.fast = false
		player.global_position = Vector3(12, -4.4, 66)
		chunks.load_now(player.global_position)
		await _wait(20)
		for id in ["blackjack", "roulette", "dice", "slots0", "slots2"]:
			var pt = _obj_point(id)
			if pt == null:
				out.append("no point " + id)
				continue
			out.append("%s: label '%s'" % [id, str(objects.point_label(pt))])
			objects.point_use(pt)
			out.append("  opens %s game %s machine %d" % [str(cz.is_open()), cz.game, cz.machine])
			cz.close()
		out.append(_dlg("lou", ["Deal me in"]))
		out.append("  Lou deals: open %s game %s, dialogue %s" % [str(cz.is_open()), cz.game, str(in_dialog())])
		cz.close()
		out.append(_dlg("lou", ["Roll the dice"]))
		out.append("  dice: open %s game %s" % [str(cz.is_open()), cz.game])
		cz.close()
		out.append("hall ambience: music %s crowd %s mix %.2f" % [str(spur_music != null and spur_music.playing), str(spur_crowd != null and spur_crowd.playing), spur_mix])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

func _forge_test() -> void:
	var out: Array = []
	Game.booted = true
	await _wait(20)
	forge.toggle()
	out.append("forge on: %s, kinds %d, ghost %s" % [forge.active, forge.kinds.size(), str(forge.ghost != null)])
	player.pitch = -0.5
	for k in ["wall", "floor", "crate", "lamp", "loot_rare", "spawn_raider"]:
		forge.cur = forge.kinds.find(k)
		forge._make_ghost()
		player.yaw += 0.6
		await get_tree().physics_frame
		await get_tree().physics_frame
		forge.place()
	out.append("placed %d: %s" % [forge.objs.size(), str(forge.objs.map(func(o): return o.k))])
	var saved: Array = Game.flags.get("forge_" + Game.area, [])
	out.append("kept with the save: %d" % saved.size())
	# look straight at the last thing placed (the spawn marker) and pick it up
	var last: Dictionary = forge.objs[-1]
	var tp: Vector3 = last.n.global_position + Vector3.UP * 0.9
	player.global_position = tp + Vector3(0, 0.0, 3.0) - Vector3(0, player.cam.position.y, 0)
	player.yaw = 0.0
	player.pitch = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var aimed = forge._aimed()
	out.append("aimed at: %s" % (aimed.k if aimed else "nothing"))
	forge.grab()
	out.append("holding %s, objects %d" % [str(forge.held.k) if forge.held else "nothing", forge.objs.size()])
	player.yaw = 0.4
	await get_tree().physics_frame
	forge.place()
	out.append("moved it: objects %d" % forge.objs.size())
	forge.undo_last()
	out.append("undo: objects %d" % forge.objs.size())
	forge.save_map("3")
	var n0: int = forge.objs.size()
	forge.clear_all()
	out.append("cleared: %d" % forge.objs.size())
	forge.load_map("3")
	out.append("map loaded: %d (was %d)" % [forge.objs.size(), n0])
	var e0 := enemies.size()
	forge.toggle()
	out.append("forge off: spawned %d enemies, markers hidden %s" % [enemies.size() - e0, str(not forge.objs.filter(func(o): return o.k.begins_with("spawn_"))[0].n.get_node("Marker").visible) if not forge.objs.filter(func(o): return o.k.begins_with("spawn_")).is_empty() else "n/a"])
	# the dev console
	out.append("console: " + hud.dev.run("give stimpak 3").replace("\n", " | "))
	out.append("console: " + hud.dev.run("spawn hound 2"))
	out.append("console: " + hud.dev.run("god"))
	var hp0 := Game.hp
	Game.hurt(50.0)
	out.append("god mode hurt: %.0f -> %.0f" % [hp0, Game.hp])
	out.append("console: " + hud.dev.run("quest hounds advance"))
	out.append("console: " + hud.dev.run("tp saltreach"))
	out.append("console: " + hud.dev.run("nonsense"))
	out.append("voice key: " + voice_key("Hal and Benny. Good boys, too young for it, {name}."))
	speak(DJ[0], "radio")
	out.append("radio voice: %s %s" % [str(voice_player.playing), voice_player.stream.resource_path if voice_player.stream else "none"])
	var vn := 0
	var vt := 0
	for id in Game.DIALOGUE:
		for nk in Game.DIALOGUE[id].get("nodes", {}):
			vt += 1
			if ResourceLoader.exists(voice_path(Game.subst(Game.dlg_say(id, nk)), id)):
				vn += 1
	out.append("conversation lines with a recorded voice (current state): %d of %d" % [vn, vt])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

# a conversation run from anywhere (the story test): picks are the starts of option texts
func _dlg(id: String, picks: Array) -> String:
	start_dialog(null, id)
	var said := [dialog_node]
	for pk in picks:
		var idx := -1
		for i in dialog_opts.size():
			if String(dialog_opts[i].t).begins_with(pk):
				idx = i
		if idx < 0:
			var at := dialog_node
			var opts: Array = dialog_opts.map(func(o): return o.t)
			end_dialog()
			return "%s: no option '%s' at %s %s" % [id, pk, at, str(opts)]
		choose(idx)
		said.append(dialog_node if in_dialog() else "end")
	end_dialog()
	return id + " ok " + str(said)

# a conversation by option text (any part of it: skill checks put their stat in front)
func _dlg2(id: String, picks: Array) -> String:
	start_dialog(null, id)
	var said := [dialog_node]
	for pk in picks:
		var idx := -1
		for i in dialog_opts.size():
			if String(dialog_opts[i].t).contains(pk):
				idx = i
				break
		if idx < 0:
			var at := dialog_node
			var opts: Array = dialog_opts.map(func(o): return o.t)
			end_dialog()
			return "%s: no option '%s' at %s %s" % [id, pk, at, str(opts)]
		choose(idx)
		said.append(dialog_node if in_dialog() else "end")
	end_dialog()
	return id + " ok " + str(said)

func _tp(x: float, z: float) -> void:
	player.global_position = Vector3(x, Game.height(x, z) + 0.3, z)
	chunks.load_now(player.global_position)
	await _wait(25)

func _live(ids: Array) -> String:
	var have: Array = []
	for n in npcs:
		if String(n.id) in ids:
			have.append(String(n.id))
	return "%d/%d %s" % [have.size(), ids.size(), str(have)]

# build 15: the Ashwood, its people and its four quests, start to finish
func _ash_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.dev["checks"] = true
	Game.caps = 1000
	await _wait(10)
	out.append("map %dx%d, region x %.0f..%.0f; locs %s" % [Game.hw, Game.hd, Game.x0, Game.x0 + Game.hw - 1, str(["cinder_gap", "ashborn", "lookout", "mercy_falls", "drivein"].filter(func(k): return Game.DB.locs.has(k)).size())])
	out.append("frontier: %d records, solids %d, chests %d, benches %d" % [Frontier.layout().size(), Game.region.solids.size(), Game.W.chests.filter(func(c): return String(c.id).begins_with("cg_") or String(c.id).begins_with("mf_") or String(c.id).begins_with("ab_") or String(c.id).begins_with("di_")).size(), Game.W.benches.size()])
	await _tp(815, -40)
	out.append("cinder gap people " + _live(["odile", "pike", "juno", "sorrel", "abe", "cg_guard1", "cg_guard2", "cg_folk1", "cg_folk2", "cg_folk3"]) + "; hester2 here %s" % str(_live(["hester2"]).begins_with("1")))
	out.append("trees in a forest chunk: %s" % str(_trees_at(1150, -150)))
	out.append(_dlg2("odile", ["You look like", "I'll find"]))
	out.append(_dlg2("sorrel", ["You look short", "I'll see"]))
	out.append(_dlg2("juno", ["You look like", "I'll bring", "I will"]))
	out.append("started: mercy_road %s, mercy_ledger %s, last_call %s" % [str(Game.known("mercy_road")), str(Game.known("mercy_ledger")), str(Game.known("last_call"))])
	await _tp(990, 168)
	var wr = _obj_point("mr_wreck")
	out.append("wreck point %s label %s" % [str(wr != null), str(objects.point_label(wr)) if wr else "-"])
	if wr:
		objects.point_use(wr)
	out.append("caravan log %d, mercy_road stage %d" % [Game.count("caravan_log"), Game.stage("mercy_road")])
	out.append(_dlg2("odile", ["About the caravans", "One more thing", "Only the last one", "I will"]))
	await _tp(690, 228)
	var rk := enemies.filter(func(e): return String(e.eid).begins_with("rk"))
	out.append("drive-in: kings %d (hostile %d), people %s" % [rk.size(), rk.filter(func(e): return e.hostile).size(), _live(["marquee", "dex"])])
	out.append(_dlg2("dex", ["She wants you home", "mother's ring", "Go on home"]))
	await _wait(5)
	out.append("dex gone from drive-in: %s, dexHome %s" % [str(not _live(["dex"]).begins_with("1")), str(Game.flags.get("dexHome"))])
	out.append(_dlg2("marquee", ["Cinder Gap's caravans", "A dead road", "Pleasure"]))
	out.append("rk_deal %s, mercy_road stage %d" % [str(Game.flags.get("rk_deal")), Game.stage("mercy_road")])
	await _tp(1128, 300)
	var mf := enemies.filter(func(e): return String(e.eid).begins_with("mf"))
	out.append("mercy falls: ghouls %d, hester %s" % [mf.size(), _live(["hester"])])
	await _tp(1124, 317)
	out.append(_dlg2("hester", ["What happened", "I'll get you out"]))
	var ph = _obj_point("mf_pharmacy")
	out.append("pharmacy point %s label %s" % [str(ph != null), str(objects.point_label(ph)) if ph else "-"])
	if ph:
		objects.point_use(ph)
	out.append("meds %d ledger %d, mercy_ledger stage %d, mercy_road stage %d" % [Game.count("mercy_meds"), Game.count("mercy_ledger"), Game.stage("mercy_ledger"), Game.stage("mercy_road")])
	for i in 6:
		Game.killed["mf%d" % i] = 1
	Game.check_quests()
	out.append("hospital cleared: mercy_road stage %d" % Game.stage("mercy_road"))
	out.append(_dlg2("hester", ["Go. It's clear", "Safe road"]))
	await _wait(5)
	out.append("hester left hospital %s" % str(not _live(["hester"]).begins_with("1")))
	await _tp(805, -45)
	out.append("back in town: " + _live(["hester2", "dex2"]))
	out.append(_dlg2("odile", ["I found Hester", "Tell them yourself"]))
	out.append(_dlg2("sorrel", ["I found the Mercy", "Glad"]))
	out.append(_dlg2("juno", ["Dex is home", "Glad"]))
	out.append("done: mercy_road %s (%s), mercy_ledger %s, last_call %s; cinder rep %d, karma %d" % [str(Game.is_done("mercy_road")), str(Game.flags.get("mr_end")), str(Game.is_done("mercy_ledger")), str(Game.is_done("last_call")), Game.rep_of("cinder"), Game.karma])
	await _tp(1296, -330)
	out.append("ashborn people " + _live(["saba", "tull", "ira", "ab_guard1", "ab_guard2", "ab_folk1", "ab_folk2"]))
	out.append(_dlg2("saba", ["Your wardens", "I'll go"]))
	await _tp(986, -238)
	out.append("lookout: " + _live(["crane"]))
	out.append(_dlg2("crane", ["The Ashborn call you", "Their Ember-Speaker", "You think it's arson", "I'll look"]))
	out.append("bm stage %d, bm_met %s, bm_hint %s" % [Game.stage("burning_man"), str(Game.flags.get("bm_met")), str(Game.flags.get("bm_hint"))])
	await _tp(1328, -334)
	var ca = _obj_point("bm_cache")
	out.append("cache point %s label %s" % [str(ca != null), str(objects.point_label(ca)) if ca else "-"])
	if ca:
		objects.point_use(ca)
	out.append("flint %d, bm stage %d" % [Game.count("tull_flint"), Game.stage("burning_man")])
	out.append(_dlg2("saba", ["I've been to the tower", "oil rags", "What happens now", "Goodbye"]))
	await _wait(5)
	out.append("burning_man done %s (%s); tull fighting %s; ashborn rep %d" % [str(Game.is_done("burning_man")), str(Game.flags.get("bm_end")), str(enemies.any(func(e): return String(e.eid) == "npc_tull" and e.hostile)), Game.rep_of("ashborn")])
	var ep: Array = Game.L.epilogue.filter(func(e): return e.has("if") and Game.vm.truthy(Game.vm.call_value(e["if"], [Game.G])))
	out.append("epilogue lines that would show: %d" % ep.size())
	for l in out:
		print("ASHTEST ", l)
	get_tree().quit()

# build 16: the north, its people and its three quests, with the silo deciding all of them
func _north_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.dev["checks"] = true
	Game.caps = 2000
	await _wait(10)
	out.append("map %dx%d z %.0f..%.0f; chunk files %d; locs %d/10" % [Game.hw, Game.hd, Game.z0, Game.z0 + Game.hd - 1, chunks.files.size(),
		["stillwater", "reservoir", "northgate", "old_meridian", "the_garage", "the_spire", "airfield_cut", "glass_bowl", "glass_camp", "silo9"].filter(func(k): return Game.DB.locs.has(k)).size()])
	# the old world still lines up: a chunk file under the start, and the ground under the player
	await _tp(-95, 108)
	out.append("old world at the start: chunk %s has a file %s; standing %.2f m above ground" % [chunks.key_of(player.global_position), str(chunks.files.has(chunks.key_of(player.global_position))), player.global_position.y - Game.height(-95, 108)])
	await _tp(-50, -748)
	out.append("stillwater people " + _live(["nell", "gus", "mara", "sw_guard", "sw_folk1", "sw_folk2"]))
	out.append("lake %s" % str(frontier.get_node_or_null("Lake") != null))
	out.append(_dlg2("nell", ["You look like", "I'll go"]))
	await _tp(-212, -850)
	var inl = _obj_point("sw_inlet")
	out.append("inlet point %s" % str(inl != null))
	if inl:
		objects.point_use(inl)
	out.append("sample %d, still_waters stage %d" % [Game.count("slag_sample"), Game.stage("still_waters")])
	await _tp(300, -700)
	out.append("garage people " + _live(["velma", "gr_guard"]))
	out.append(_dlg2("velma", ["Something wrong", "I'll get him"]))
	await _tp(445, -812)
	var hr := enemies.filter(func(e): return String(e.eid).begins_with("hr"))
	out.append("spire: highrisers %d (hostile %d), people %s" % [hr.size(), hr.filter(func(e): return e.hostile).size(), _live(["duchess", "tobiah"])])
	out.append(_dlg2("tobiah", ["Stillwater's water", "Where do I find"]))
	out.append("still_waters stage %d" % Game.stage("still_waters"))
	out.append(_dlg2("duchess", ["I'm here for Tobiah", "worth more to you grateful", "Pleasure"]))
	await _wait(5)
	out.append("tobiahFree %s codes %s; tobiah gone from spire %s" % [str(Game.flags.get("tobiahFree")), str(Game.flags.get("tobiahCodes")), str(not _live(["tobiah"]).begins_with("1"))])
	await _tp(300, -700)
	out.append(_dlg2("velma", ["Tobiah's out", "Glad"]))
	await _tp(1170, -604)
	out.append("glass camp people " + _live(["sel", "amon", "gc_folk1", "gc_folk2", "gc_guard"]))
	out.append(_dlg2("amon", ["I'm listening", "Give me the log"]))
	out.append(_dlg2("sel", ["Tell me about the Sleeper", "I see", "Your people are dying", "Take them out of the Bowl", "I'll tell her"]))
	await _wait(5)
	out.append("gc_end %s; camp emptied %s" % [str(Game.flags.get("gc_end")), str(not _live(["sel", "gc_folk1"]).begins_with("1") and _live(["sel", "gc_folk1"]).begins_with("0"))])
	out.append(_dlg2("amon", ["It's decided", "Goodbye"]))
	await _tp(1150, -790)
	var gb := enemies.filter(func(e): return String(e.eid).begins_with("gb") or String(e.eid) == "silobot")
	out.append("glass bowl: %d hostiles incl. the Iron Angel %s; pools %d" % [gb.size(), str(gb.any(func(e): return String(e.eid) == "silobot")), Game.region.pools.size()])
	await _tp(1146, -803)
	var desk = _obj_point("silo_desk")
	out.append("console point %s label %s" % [str(desk != null), str(objects.point_label(desk)) if desk else "-"])
	if desk:
		objects.point_use(desk)
		await _wait(3)
	out.append("console open %s at %s" % [str(in_dialog()), str(dialog_node)])
	if in_dialog():
		end_dialog()
	out.append(_dlg2("silo_console", ["Seal the coolant", "Step away"]))
	out.append("silo_end %s, still_waters stage %d" % [str(Game.flags.get("silo_end")), Game.stage("still_waters")])
	await _tp(-45, -735)
	out.append("stillwater again: " + _live(["tobiah2", "gc_folk3"]))
	out.append(_dlg2("nell", ["It's done", "Your water"]))
	out.append("done: still_waters %s, the_spire %s, children_of_glass %s; karma %d; rep stillwater %d children %d" % [str(Game.is_done("still_waters")), str(Game.is_done("the_spire")), str(Game.is_done("children_of_glass")), Game.karma, Game.rep_of("stillwater"), Game.rep_of("children")])
	var ep: Array = Game.L.epilogue.filter(func(e): return e.has("if") and Game.vm.truthy(Game.vm.call_value(e["if"], [Game.G])))
	out.append("epilogue lines that would show: %d" % ep.size())
	for l in out:
		print("NORTHTEST ", l)
	get_tree().quit()

# build 17: Lantern Row and the Quiet Hands, Starfall and the Visitor, and the main quest's third act
func _b17_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.dev["checks"] = true
	Game.caps = 3000
	Game.flags["radio_row"] = 1
	Game.flags["radio_starfall"] = 1
	await _wait(10)
	await _tp(600, 118)
	out.append("lantern row people " + _live(["magpie", "dace", "hesper", "bo", "lr_clerk", "lr_guard", "lr_folk1", "lr_folk2"]))
	out.append(_dlg2("magpie", ["I want work", "Easy"]))
	var clerk = npcs.filter(func(n): return n.id == "lr_clerk")
	out.append("clerk's pockets hold the watch: %s" % str(not clerk.is_empty() and pockets.items_of(clerk[0]).any(func(e): return String(e[0]) == "coyne_watch")))
	Game.give("coyne_watch", 1)
	out.append(_dlg2("magpie", ["Ezra's watch", "Glad"]))
	out.append(_dlg2("magpie", ["Anything else", "I'll get it"]))
	await _tp(329, 60)
	var sb = _obj_point("sr_strongbox")
	out.append("strongbox point %s label %s" % [str(sb != null), str(objects.point_label(sb)) if sb else "-"])
	Game.give("renn_slip", 1)
	if sb:
		objects.point_use(sb)
	out.append("ledger %d, collectors_safe stage %d" % [Game.count("salt_ledger"), Game.stage("collectors_safe")])
	await _tp(600, 95)
	out.append(_dlg2("magpie", ["About the salt ledger", "I burned it", "Thank you"]))
	out.append(_dlg2("magpie", ["It's dealt with", "One of the Hands"]))
	out.append("qh_member %s, collectors_safe done %s" % [str(Game.flags.get("qh_member")), str(Game.is_done("collectors_safe"))])
	out.append(_dlg2("magpie", ["What happened with Silas", "I'll get it back"]))
	await _tp(320, 300)
	out.append("pilgrim's rest: " + _live(["silas"]))
	out.append(_dlg2("silas", ["She wants the Book", "Kess got his", "Go somewhere"]))
	out.append("book %d, silas_gone %s" % [Game.count("qh_book"), str(Game.flags.get("silas_gone"))])
	await _tp(600, 95)
	out.append(_dlg2("magpie", ["The Book of Hands", "Thank you"]))
	out.append("quiet hands done: %s %s %s; rep %d" % [str(Game.is_done("light_fingers")), str(Game.is_done("collectors_safe")), str(Game.is_done("old_debts")), Game.rep_of("quiet_hands")])
	# Starfall
	await _tp(652, -400)
	out.append("orrin's camp: " + _live(["orrin"]))
	out.append(_dlg2("orrin", ["What happened last month", "I'll go"]))
	await _tp(678, -415)
	for id in ["ufo_breach", "ufo_pod", "ufo_cockpit"]:
		var pt = _obj_point(id)
		out.append("%s point %s label %s" % [id, str(pt != null), str(objects.point_label(pt)) if pt else "-"])
		if pt:
			objects.point_use(pt)
	out.append("lights stage %d" % Game.stage("lights_over_ridge"))
	await _tp(652, -400)
	out.append(_dlg2("orrin", ["About the wreck", "I'll look"]))
	await _tp(702, -438)
	var tr = _obj_point("ufo_trail")
	if tr:
		objects.point_use(tr)
	await _wait(5)
	await _tp(718, -455)
	out.append("visitor: " + _live(["visitor"]))
	Game.give("stimpak", 2)
	Game.give("radaway", 1)
	out.append(_dlg2("visitor", ["Kneel slowly", "Leave it"]))
	out.append(_dlg2("visitor", ["Splint the leg", "Nod"]))
	await _tp(652, -400)
	out.append(_dlg2("orrin", ["About the Visitor", "I will"]))
	await _tp(682, -420)
	var ck = _obj_point("ufo_cockpit")
	out.append("cockpit label now %s" % (str(objects.point_label(ck)) if ck else "-"))
	if ck:
		objects.point_use(ck)
	await _wait(5)
	out.append("sentinel up %s" % str(enemies.any(func(e): return String(e.eid) == "sentinel")))
	Game.killed["sentinel"] = 1
	Game.check_quests()
	await _tp(718, -455)
	out.append(_dlg2("visitor", ["Give it the power cell", "Take the beacon"]))
	await _tp(-166, -354)
	var mast = _obj_point("kdst_mast")
	if mast:
		objects.point_use(mast)
	out.append("beacon_set %s, signal_home stage %d" % [str(Game.flags.get("beacon_set")), Game.stage("signal_home")])
	await _tp(718, -455)
	out.append(_dlg2("visitor", ["Take its hand", "Watch the sky"]))
	out.append("starfall done: %s %s %s; blaster %d" % [str(Game.is_done("lights_over_ridge")), str(Game.is_done("not_alone")), str(Game.is_done("signal_home")), Game.count("stellar_blaster")])
	# act three
	Game.flags["ending"] = "home"
	Game.check_quests()
	out.append("door call on the radio: %s" % str(Game.flags.get("radio")))
	Game.flags.erase("radio")
	await _wait(5)
	await _tp(0, 212)
	out.append("haven's door: %s; cracked_housing known %s" % [_live(["ruth", "calder", "hd_folk1", "hd_folk2"]), str(Game.known("cracked_housing"))])
	out.append(_dlg2("ruth", ["What happened", "Show me"]))
	await _tp(-3, 217)
	out.append(_dlg2("hd_panel", ["Step back"]))
	out.append(_dlg2("ruth", ["What's the plan", "I'll get them"]))
	out.append("act three open: rig %s gaskets %s cast %s doubt %s" % [str(Game.known("calibration_rig")), str(Game.known("seals_and_gaskets")), str(Game.known("housing_cast")), str(Game.known("havens_doubt"))])
	await _tp(292, -320)
	var rg = _obj_point("kf_rig")
	if rg:
		objects.point_use(rg)
	Game.give("fusion_cell", 1)
	await _tp(604, 125)
	out.append(_dlg2("bo", ["Can you make gaskets", "I'll get them"]))
	Game.give("duct_tape", 2)
	Game.give("fuel_can", 1)
	out.append(_dlg2("bo", ["Here: two duct tape", "Tomorrow"]))
	Game.day += 1
	out.append(_dlg2("bo", ["Are the gaskets ready", "Thank you, Bo"]))
	Game.give("scrap_metal", 6)
	Game.give("fuel_can", 1)
	await _tp(158, 366)
	var fu = _obj_point("quarry_furnace")
	out.append("furnace point %s label %s" % [str(fu != null), str(objects.point_label(fu)) if fu else "-"])
	if fu:
		objects.point_use(fu)
	await _tp(0, 212)
	out.append(_dlg2("calder", ["You want people to leave", "I hear you"]))
	await _tp(-10, 209)
	var cc = _obj_point("hd_cache")
	if cc:
		objects.point_use(cc)
	out.append(_dlg2("calder", ["Someone's been cutting", "Then let them choose", "Don't tell her"]))
	out.append(_dlg2("ruth", ["Here's the calibration rig", "Ha"]))
	out.append(_dlg2("ruth", ["The rig's working", "Good"]))
	out.append(_dlg2("ruth", ["Bo's gaskets", "Two down"]))
	out.append(_dlg2("ruth", ["A new housing", "Three down"]))
	out.append(_dlg2("ruth", ["About Calder", "It's done"]))
	out.append(_dlg2("ruth", ["Let's build it", "Let them come"]))
	await _wait(10)
	var kr := enemies.filter(func(e): return String(e.eid).begins_with("kr"))
	out.append("raid: %d raiders (hostile %d)" % [kr.size(), kr.filter(func(e): return e.hostile).size()])
	for i in 6:
		Game.killed["kr%d" % i] = 1
	Game.check_quests()
	await _tp(-3, 217)
	out.append(_dlg2("hd_panel", ["Seat the new regulator", "Step back"]))
	Game.check_quests()
	out.append("haven on the radio: %s" % str(Game.flags.get("radio")))
	Game.flags.erase("radio")
	await _wait(5)
	out.append(_dlg2("ruth", ["It's running", "Thank you, Ruth"]))
	var main_q := ["exodus", "daylight", "bad_water", "signal", "keys", "council", "meridian", "cracked_housing", "calibration_rig", "seals_and_gaskets", "housing_cast", "havens_doubt", "last_nine_days"]
	var stages := 0
	for q in main_q:
		stages += (Game.qdef(q).get("stages", []) as Array).size()
	out.append("act three done: %s; main quest now %d quests, %d stages" % [str(["cracked_housing", "calibration_rig", "seals_and_gaskets", "housing_cast", "havens_doubt", "last_nine_days"].map(func(q): return Game.is_done(q))), main_q.size(), stages])
	out.append("radio news lines now: %d" % radio_news().size())
	for l in out:
		print("B17TEST ", l)
	get_tree().quit()

# build 18: Silo 9's console, its launch, and the Ash Wind
func _b18_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.flags["gb_hello"] = 1
	Game.dev["checks"] = true
	Game.dev["god"] = true
	await _wait(10)
	Game.start("still_waters")
	Game.give("slag_sample", 1)
	Game.flags["tobiahTalked"] = 1
	Game.flags["tobiahFree"] = 1
	Game.check_quests()
	Game.flags.erase("radio")
	out.append("still_waters stage %d, codes %s" % [Game.stage("still_waters"), str(Game.flags.get("tobiahCodes"))])
	await _tp(1146, -803)
	out.append(_dlg2("silo_console", ["Bring up the launch", "Back away"]))
	Game.give("silo_key", 1)
	out.append(_dlg2("silo_console", ["Bring up the launch", "Confirm"]))
	out.append("silo_end %s, seq %s, count %s, still_waters stage %d" % [str(Game.flags.get("silo_end")), str(Game.flags.get("silo_seq")), str(Game.flags.get("silo_count")), Game.stage("still_waters")])
	Game.flags["silo_count"] = 1.0
	await _wait(120)
	out.append("missile up %s, seq left %s" % [str(silo.missile != null), str(Game.flags.get("silo_seq"))])
	silo.mt = 30.0
	await _wait(10)
	out.append("burst: cloud %s, burst_day %s" % [str(silo.cloud != null), str(Game.flags.get("burst_day"))])
	silo.cloud_t = 31.0
	await _wait(10)
	out.append("ash_wind known %s, radio %s" % [str(Game.known("ash_wind")), str(Game.flags.get("radio"))])
	Game.flags.erase("radio")
	hud.screens.close()
	await _tp(-45, -735)
	out.append(_dlg2("nell", ["It's done", "Your water"]))
	out.append(_dlg2("nell", ["The flash in the north-east", "I'll shut it"]))
	await _tp(-209, -844)
	var sl = _obj_point("sw_sluice")
	out.append("sluice point %s label %s" % [str(sl != null), str(objects.point_label(sl)) if sl else "-"])
	if sl:
		objects.point_use(sl)
	await _tp(1163, -612)
	out.append(_dlg2("amon", ["The ash is coming", "Go. Quickly"]))
	Game.day += 1
	Game.check_quests()
	await _tp(-45, -735)
	out.append(_dlg2("nell", ["The ash has stopped", "Glad"]))
	out.append("done: still_waters %s, ash_wind %s; gc_end %s; news %d" % [str(Game.is_done("still_waters")), str(Game.is_done("ash_wind")), str(Game.flags.get("gc_end")), radio_news().size()])
	for l in out:
		print("B18TEST ", l)
	get_tree().quit()

# build 19: anything in the frontier layout standing on a slope steep enough that one side of it hangs in the air
func _float_audit() -> void:
	for d in Frontier.layout():
		var k := String(d.k)
		if not k in ["kit", "seat", "chest", "bench", "post", "log_seat", "tent", "tipi", "totem", "banner", "stall", "rack", "outhouse", "tower", "water_tower", "cage", "shrine", "strongbox", "rig_cart", "furnace"]:
			continue
		var r := 1.2
		if k == "kit":
			r = float(d.get("len", 2.0)) * 0.5
		elif k in ["tent", "tipi", "stall", "tower", "water_tower", "shrine"]:
			r = 1.8
		var g: float = Frontier._ground(d)
		var lo := INF
		for i in 8:
			var a := i * TAU / 8.0
			lo = minf(lo, Game.height(float(d.x) + cos(a) * r, float(d.z) + sin(a) * r))
		if g - lo > 0.3:
			print("FLOAT %s %s at %.1f,%.1f hangs %.2f m" % [k, String(d.get("id", "")), float(d.x), float(d.z), g - lo])
	print("FLOAT done")
	get_tree().quit()

# build 22: falls hurt, fires sit in pits, sharpshooters keep their distance and shoulder their rifles
# build 24: wrecks and loose things on the ground, the dead trees regrown, the quest glints, the loose junk you can
# knock about, the hit glow, the intro and the update packs
func _b24_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	await _wait(10)
	out.append("update: this build is its own base %s (build %s); the updater asks for %s" % [str(int(get_node("/root/Patcher").base_build) == int(get_node("/root/Patcher").build)), str(get_node("/root/Patcher").build), "patch-b%d.pck" % int(get_node("/root/Patcher").base_build)])
	# Cinder Gap: the truck on its slope, the seats and benches down on the ground
	await _tp(850.0, -60.0)
	await _wait(10)
	# whatever opened over the game on the way (a level-up page) is shut, so the world runs
	if hud.screens.is_open():
		out.append("(closed the %s screen that opened over the game)" % hud.screens.mode)
		hud.screens.close()
	get_tree().paused = false
	Game.paused = false
	await get_tree().create_timer(2.5).timeout
	await _wait(10)
	var worst_car := 0.0
	var worst_small := 0.0
	var n_car := 0
	var n_small := 0
	for c in frontier.get_children():
		if not (c is Node3D):
			continue
		var cp := (c as Node3D).global_position
		if Vector2(cp.x - 850.0, cp.z + 60.0).length() > 90.0:
			continue
		var box := AABB()
		var first := true
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			if g.mesh == null or not g.is_visible_in_tree():
				continue
			var b := g.global_transform * g.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first or box.size.x > 8.0 or box.size.z > 8.0 or box.size.y > 4.0:
			continue
		var lo := INF
		for fx in [0.2, 0.5, 0.8]:
			for fz in [0.2, 0.5, 0.8]:
				lo = minf(lo, Game.height(box.position.x + box.size.x * fx, box.position.z + box.size.z * fz))
		var gap := box.position.y - lo
		if maxf(box.size.x, box.size.z) > 3.0:
			n_car += 1
			worst_car = maxf(worst_car, gap)
		else:
			n_small += 1
			worst_small = maxf(worst_small, gap)
	out.append("Cinder Gap: %d wrecks, the most daylight under one %.2f m (on the ground: %s); %d smaller things, the worst %.2f m (%s)" % [n_car, worst_car, str(worst_car < 0.2), n_small, worst_small, str(worst_small < 0.12)])
	# loose junk to knock about: there, asleep till touched, and a bullet sends one off
	var bodies: Array = []
	if Havoc.inst:
		for k in Havoc.inst.live:
			for b in Havoc.inst.live[k]:
				if is_instance_valid(b):
					bodies.append(b)
	# all of it lying on something: the lowest point of each piece against the ground (or whatever is under it)
	var hang := 0.0
	var hung := ""
	for b in bodies:
		var bb := AABB()
		var f0 := true
		for mi in (b as Node).find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = ab if f0 else bb.merge(ab)
			f0 = false
		var down := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(bb.get_center(), bb.get_center() + Vector3.DOWN * 4.0, 1, [(b as RigidBody3D).get_rid()]))
		var under: float = float(down.position.y) if not down.is_empty() else Game.height(bb.get_center().x, bb.get_center().z)
		if bb.position.y - under > hang:
			hang = bb.position.y - under
			hung = String((b as Node).get_meta("kind", "?"))
	out.append("loose junk settled: the most air under any piece %.2f m (%s)" % [hang, hung])
	var moved := false
	if hud.screens.is_open():
		out.append("(closed the %s screen that opened over the game)" % hud.screens.mode)
		hud.screens.close()
	get_tree().paused = false
	Game.paused = false
	if not bodies.is_empty():
		# the lightest thing lying about (a can, a cone), shot from the player's side
		bodies.sort_custom(func(x, y): return (x as RigidBody3D).mass < (y as RigidBody3D).mass)
		var b: RigidBody3D = bodies[0]
		var p0 := b.global_position
		var sd: Vector3 = b.global_position - player.global_position
		sd.y = 0.0
		Havoc.shot(b, b.global_position + Vector3.UP * 0.1, sd.normalized(), 1.0)
		await _wait(30)
		moved = b.global_position.distance_to(p0) > 0.05 or b.linear_velocity.length() > 0.05
		out.append("(a %s shot: thrown %.2f m)" % [String(b.get_meta("kind", "?")), b.global_position.distance_to(p0)])
	out.append("loose junk round Cinder Gap: %d pieces; one shot shoves it %s" % [bodies.size(), str(moved)])
	# the dead trees on the hill above Haven's door: grown new, the old board-limbed ones hidden
	await _tp(-30.0, 140.0)
	await _wait(40)
	var mm := 0
	var trees := 0
	for n in chunks.find_children("DeadTrees*", "MultiMeshInstance3D", true, false):
		mm += 1
		trees += (n as MultiMeshInstance3D).multimesh.instance_count
	var old_shown := 0
	for k in chunks.loaded:
		var fname := String(chunks.files.get(k, "")).get_file().get_basename()
		var e: Dictionary = DeadTree.data().get(fname, {})
		for path in e.get("meshes", []):
			for c in (chunks.loaded[k] as Node).get_children():
				var mn := c.get_node_or_null(NodePath(String(path)))
				if mn is MeshInstance3D and (mn as MeshInstance3D).visible:
					old_shown += 1
	out.append("dead trees round Haven's door: %d grown in %d batches; old board-limbed ones still showing %d" % [trees, mm, old_shown])
	# Starfall: with the quest on, the places to search glint, and each can be searched
	Game.start("lights_over_ridge")
	await _tp(684.0, -398.0)
	if hud.screens.is_open():
		hud.screens.close()
	get_tree().paused = false
	Game.paused = false
	await _wait(40)
	var gl: QuestGlint = null
	for c in get_children():
		if c is QuestGlint:
			gl = c
	var lit := 0
	if gl:
		for e in gl.pool:
			if (e[0] as MeshInstance3D).visible:
				lit += 1
	var want: Array = []
	for k in objects.grid:
		for o in objects.grid[k]:
			if String(o.get("id", "")).begins_with("ufo_"):
				want.append("%s %s %.0f m" % [String(o.id), "wanted" if QuestGlint.wanted(o) else "not wanted", Vector2(float(o.x) - player.global_position.x, float(o.z) - player.global_position.z).length()])
	out.append("Starfall with Lights over the Ridge on: %d places glinting (%s) " % [lit, ", ".join(want)])
	# the hit glow: none in god mode
	Game.dev["god"] = true
	hud.dmgdir.hits.clear()
	hud.hurt_from(player.global_position + Vector3(5, 0, 0))
	var god_glow: int = hud.dmgdir.hits.size()
	Game.dev["god"] = false
	hud.hurt_from(player.global_position + Vector3(5, 0, 0))
	out.append("hit glow in god mode %d, out of it %d" % [god_glow, hud.dmgdir.hits.size()])
	# the intro: no engine card, no tap to skip, the tips
	var ls := LoadScreen.it()
	out.append("intro: %d tips; bottom line reads '%s'" % [LoadScreen.TIPS.size(), ls.skip_l.text if ls and ls.skip_l else "-"])
	for l in out:
		print("B24TEST ", l)
	get_tree().quit()

# build 23: gunfire (flash, brass, impacts), the view's width, the shacks' furniture and lamps, indoor light
func _b23_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	await _wait(10)
	# the field of view: a wide screen is held to 100 degrees across, the arms drawn as before
	var vs := get_viewport().get_visible_rect().size
	var v: float = player.view_fov(75.0)
	var across := rad_to_deg(2.0 * atan(tan(deg_to_rad(v * 0.5)) * vs.x / vs.y))
	out.append("view %.0fx%.0f: 75 tall asked, %.1f tall given, %.0f across (at most 100: %s); arms scaled %.2f" % [vs.x, vs.y, v, across, str(across <= 100.5), player.gun.scale.x])
	# a shot at the ground: a flash at the muzzle, a case thrown, a hole and dust where it hit
	await _tp(-40.0, 150.0)
	Game.give("pipe_pistol", 1)
	Game.weapon = "pipe_pistol"
	player.weapon_changed()
	await _wait(10)
	player.pitch = -0.6
	await _wait(5)
	var holes0: int = GunFX._holes.size()
	var kids0 := get_child_count()
	Game.mag = maxi(Game.mag, 5)
	player.fire_cd = 0.0
	player.fire()
	await _wait(2)
	var flash := 0
	for c in player.vm.muzzle.get_children():
		if c is Node3D and (c as Node3D).visible and c != player.flash_q and c != player.flash:
			flash += (c as Node3D).find_children("*", "MeshInstance3D", true, false).size()
	await _wait(20)
	out.append("one shot: %d flash pieces at the muzzle, %d hole(s) left in the ground, %d things added to the world (brass, dust)" % [flash, GunFX._holes.size() - holes0, get_child_count() - kids0])
	out.append("ground hit reads as: %s" % GunFX.surface({"collider": null, "normal": Vector3.UP, "position": Vector3(player.global_position.x, Game.height(player.global_position.x, player.global_position.z), player.global_position.z)}))
	# Cinder Gap's homes: a real table, the lantern on it; the store's lamp hung flush from the ceiling
	await _tp(789.0, -51.3)
	await _wait(30)
	var home: Node3D = null
	var best := 99.0
	for f in find_children("f_Lantern_01", "Node3D", true, false):
		var d := Vector2((f as Node3D).global_position.x - 789.0, (f as Node3D).global_position.z + 53.0).length()
		if d < best:
			best = d
			home = f
	if home:
		var tbl: Node3D = home.get_parent().find_child("f_WoodenTable_03", false, false)
		var top := (tbl.global_position.y + Furniture.aabb("WoodenTable_03").end.y) if tbl else -99.0
		out.append("home's lantern stands %.2f m above its table top (on it: %s)" % [home.global_position.y - top, str(absf(home.global_position.y - top) < 0.05)])
	else:
		out.append("home's lantern: missing")
	await _tp(802.0, -52.0)
	await _wait(30)
	var lamp: Node3D = null
	for f in find_children("hang_hanging_industrial_lamp", "Node3D", true, false):
		if Vector2((f as Node3D).global_position.x - 802.0, (f as Node3D).global_position.z + 54.0).length() < 6.0:
			lamp = f
	if lamp:
		# the ceiling boards' underside is at the walls' height
		var gap: float = 2.7 - lamp.position.y
		var low := lamp.global_position.y - Furniture.aabb("hanging_industrial_lamp").size.y * (lamp.get_child(0) as Node3D).scale.x - (lamp.get_parent() as Node3D).global_position.y
		out.append("store's lamp: %.2f m below the ceiling boards, its bottom %.2f m over the floor (hung flush %s, over head height %s)" % [gap, low, str(absf(gap) < 0.06), str(low > 1.9)])
	else:
		out.append("store's lamp: missing")
	# indoors the sky's light is turned down; it comes back when you step out
	await _wait(60)
	var amb_in := env.ambient_light_energy
	var enc_in := atmos.enclosed
	await _tp(802.0, -44.0)
	await _wait(90)
	out.append("inside the store: walls round you %s, ambient %.2f; outside: %s, ambient %.2f (darker inside %s)" % [str(enc_in), amb_in, str(atmos.enclosed), env.ambient_light_energy, str(amb_in < env.ambient_light_energy * 0.8)])
	for l in out:
		print("B23TEST ", l)
	get_tree().quit()

func _b22_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	await _wait(10)
	await _tp(-40.0, 150.0)
	await _wait(20)
	for h in [2.0, 6.0, 12.0]:
		Game.hp = Game.hp_max
		var gy := Game.height(player.global_position.x, player.global_position.z)
		player.global_position.y = gy + h
		player.velocity = Vector3.ZERO
		await _wait(5)
		for f in 240:
			await get_tree().physics_frame
			if player.is_on_floor():
				break
		await _wait(3)
		out.append("fell %.0f m: lost %.0f of %.0f health" % [h, Game.hp_max - Game.hp, Game.hp_max])
	Game.hp = Game.hp_max
	var hp0 := Game.hp
	Game.hurt(12.0)
	out.append("hurt sound played, hp %.0f -> %.0f" % [hp0, Game.hp])
	# the fire pits
	var kinds := {}
	for d in Frontier.layout():
		if String(d.k) == "campfire":
			var pk := String(d.get("pit", FireFX.pit_kind(float(d.x), float(d.z))))
			kinds[pk] = int(kinds.get(pk, 0)) + 1
	out.append("fire pits by kind: %s" % str(kinds))
	var pit := FireFX.make_pit(0.8, "stove")
	add_child(pit)
	out.append("a stove pit has %d pieces and its fire %s" % [pit.get_child_count(), str(pit.has_meta("fire"))])
	pit.queue_free()
	# a sharpshooter spawned close backs off; its rifle is shouldered
	Game.dev["god"] = true
	var f := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var sp: Vector3 = player.global_position + f * 12.0
	var sn = events._enemy("sniper", sp.x, sp.z, true)
	sn.state = "chase"
	await _wait(10)
	var d0: float = sn.global_position.distance_to(player.global_position)
	await _wait(360)
	var d1: float = sn.global_position.distance_to(player.global_position) if is_instance_valid(sn) else -1.0
	var shouldered := false
	for ba in sn.model.find_children("*", "BoneAttachment3D", true, false):
		if String((ba as BoneAttachment3D).bone_name) == "spine_03":
			shouldered = true
	out.append("sharpshooter %.0f m -> %.0f m after six seconds (keeps away %s); rifle shouldered %s" % [d0, d1, str(d1 > d0 + 4.0), str(shouldered)])
	for l in out:
		print("B22TEST ", l)
	get_tree().quit()

# build 21: the main menu, the options, and the three new places' quests
func _b21_test() -> void:
	var out: Array = []
	Game.flags.erase("radio")
	# the menu: up over the valley, the world paused under it, the options saved, gone again on RESUME
	MainMenu.it().open()
	await _wait(10)
	var mm := MainMenu.it()
	var items: Array = mm.list.get_children().filter(func(c): return c is Button).map(func(c): return String(c.text).strip_edges())
	out.append("menu open %s, paused %s, hud hidden %s, items %s" % [str(mm.is_open()), str(get_tree().paused), str(not hud.visible), str(items)])
	out.append("menu camera current %s" % str(mm.cam != null and mm.cam.current))
	var s0 := Settings.num("sens")
	Settings.set_num("sens", 1.5)
	var yaw0: float = player.yaw
	player.look(0.1, 0.0)
	out.append("sensitivity 1.5: look 0.1 turned %.2f" % (yaw0 - player.yaw))
	Settings.set_num("sens", s0)
	mm._page_options()
	await _wait(3)
	out.append("options rows %d" % mm.side_body.get_child_count())
	mm._page_load()
	mm._page_credits()
	await _wait(3)
	mm.close()
	await _wait(3)
	out.append("closed: paused %s, hud %s, player camera %s" % [str(get_tree().paused), str(hud.visible), str(player.cam.current)])
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.dev["god"] = true
	# the Toll Road
	await _tp(872.0, -680.0)
	await _wait(20)
	out.append(_dlg2("hob", ["Who runs", "clear the road"]))
	out.append("toll_road active %s" % str(Game.G.questActive("toll_road")))
	for i in 4:
		Game.killed["ws" + str(i)] = 1
	Game.check_quests()
	out.append(_dlg2("hob", ["It's done", "Drive safe"]))
	out.append("toll_road done %s, fuel can %d" % [str(Game.G.questDone("toll_road")), Game.count("fuel_can")])
	# Holloway Ground
	await _tp(-296.5, -565.0)
	await _wait(20)
	out.append(_dlg2("ada", ["What happened", "clear the fields"]))
	for i in 4:
		Game.killed["hf" + str(i)] = 1
	await _tp(-284.0, -594.5)
	await _wait(10)
	for o in objects.grid.values():
		for oo in o:
			if oo._k == "point" and String(oo.id) == "hf_graves":
				out.append("graves label: %s" % str(objects.point_label(oo)))
				objects.point_use(oo)
	Game.check_quests()
	await _tp(-296.5, -565.0)
	out.append(_dlg2("ada", ["The fields are clear", "Thank you"]))
	out.append("holloway_ground done %s" % str(Game.G.questDone("holloway_ground")))
	# Dead Air
	await _tp(1000.0, 104.0)
	await _wait(60)
	Game.check_quests()
	out.append("dead_air started on arrival %s" % str(Game.G.questKnown("dead_air")))
	for i in 2:
		Game.killed["rk" + str(i)] = 1
	Game.stats["intellect"] = 7
	for o in objects.grid.values():
		for oo in o:
			if oo._k == "point" and String(oo.id) == "rk_console":
				out.append("console label: %s" % str(objects.point_label(oo)))
				objects.point_use(oo)
	out.append("radio queued: %s" % str(Game.flags.get("radio")))
	Game.flags.erase("radio")
	await _wait(30)
	Game.check_quests()
	Game.check_quests()
	await _wait(5)
	out.append("dead_air done %s" % str(Game.G.questDone("dead_air")))
	for l in out:
		print("B21TEST ", l)
	get_tree().quit()

# build 20: containers you can see and must look at, a gentler dog, the new places
func _b20_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.dev["god"] = true
	await _wait(10)
	var c13 = null
	for c in Game.W.get("chests", []):
		if String(c.id) == "c13":
			c13 = c
	await _tp(float(c13.x) + 1.6, float(c13.z))
	await _wait(150)
	out.append("reactor safe c13 shell %s at y %.2f" % [str(get_node_or_null("Shell_c13") != null), float(c13.y)])
	# look at it, then away
	var cp := Vector3(float(c13.x), float(c13.y) + 0.4, float(c13.z))
	player.global_position = Vector3(float(c13.x) + 1.4, float(c13.y) + 0.1, float(c13.z))
	await _wait(5)
	var to: Vector3 = cp - (player.global_position + Vector3.UP * 1.5)
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _wait(5)
	out.append("looking at it: %s" % str(_best_target().get("label", "nothing")))
	player.yaw += PI
	await _wait(5)
	out.append("looking away: %s" % str(_best_target().get("label", "nothing")))
	player.yaw -= PI
	player.pitch = 1.2
	await _wait(5)
	out.append("looking at the sky: %s" % str(_best_target().get("label", "nothing")))
	# Biscuit
	recruit("biscuit", true)
	for p in party:
		if String(p.id) == "biscuit":
			out.append("biscuit dmg %.1f atk %.2f (was 16, 0.85)" % [float(p.comp.dmg), float(p.comp.atk)])
	dismiss("biscuit", true)
	# the new places: their pieces and their people
	var have := {}
	for d in Frontier.layout():
		if String(d.k) == "chest" and String(d.id) in ["ws_stash", "hf_cellar", "rk_locker"]:
			have[String(d.id)] = true
	out.append("new stashes %s; locs %s" % [str(have.keys()), str(["wayside", "holloway", "relay_k"].filter(func(k): return Game.DB.locs.has(k)))])
	var sp := 0
	for s0 in Game.W.get("spawns", []):
		if String(s0.id).substr(0, 2) in ["ws", "hf", "rk"]:
			sp += 1
	out.append("new spawns %d" % sp)
	await _tp(900, -625)
	await _wait(60)
	out.append("wayside foes near %d" % enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.global_position.distance_to(Vector3(900, e.global_position.y, -600)) < 40.0).size())
	out.append("run speed %.1f" % player.RUN)
	for l in out:
		print("B20TEST ", l)
	get_tree().quit()

# build 22: walk up the fire lookout's eight flights to the cab
func _tower_test() -> void:
	Game.booted = true
	Game.dev["god"] = true
	await _wait(10)
	var o := Vector3(997.0, 0, -236.0)
	var g0 := Frontier._ground({"k": "lookout", "x": 997.0, "z": -236.0, "r": 0})
	var pts: Array = [Vector2(-1.2, 0.8)]
	for i in 8:
		var dirx := 1.0 if i % 2 == 0 else -1.0
		var zs := 0.8 if i % 2 == 0 else -0.8
		pts.append(Vector2(1.6 * dirx, zs))
		pts.append(Vector2(2.2 * dirx, zs))
		if i < 7:
			pts.append(Vector2(2.2 * dirx, -zs))
	pts.append(Vector2(-2.2, 0.0))
	await _tp(o.x - 4.0, o.z + 0.8)
	var wi := 0
	var stuck := 0.0
	var last: Vector3 = player.global_position
	for f in 3000:
		await get_tree().physics_frame
		if wi >= pts.size():
			break
		var tgt: Vector2 = pts[wi]
		var to: Vector3 = Vector3(o.x + tgt.x, 0, o.z + tgt.y) - player.global_position
		to.y = 0
		if to.length() < 0.35:
			wi += 1
			continue
		player.yaw = atan2(-to.x, -to.z)
		Game.touch_move = Vector2(0, -0.6)
		if f % 60 == 0:
			print("TOWERTEST f %d wp %d pos %s" % [f, wi, str((player.global_position - o).snapped(Vector3.ONE * 0.1))])
			if player.global_position.distance_to(last) < 0.2:
				stuck += 1
				if stuck > 4:
					break
			else:
				stuck = 0
			last = player.global_position
	Game.touch_move = Vector2.ZERO
	print("TOWERTEST reached waypoint %d of %d, height above the base %.1f (the cab floor is at 12)" % [wi, pts.size(), player.global_position.y - g0])
	get_tree().quit()

# build 20: walk in through the door of every building the frontier puts up (doorsteps, porches, sloping ground)
func _door_test() -> void:
	Game.booted = true
	Game.dev["god"] = true
	await _wait(10)
	var ok := 0
	var bad: Array = []
	for d in Frontier.layout():
		var k := String(d.k)
		if not k in ["shack", "hall", "cabin"]:
			continue
		var hd := float(d.get("d", 5)) * 0.5
		var lx := float(d.get("door", 0.0)) if k != "cabin" else -0.8
		var b := Basis(Vector3.UP, int(d.r) * PI * 0.5)
		var out: Vector3 = b * Vector3(0, 0, 1)
		var start: Vector3 = Vector3(float(d.x), 0, float(d.z)) + b * Vector3(lx, 0, hd + (5.0 if k == "hall" else 3.5))
		var inside: Vector3 = Vector3(float(d.x), 0, float(d.z)) + b * Vector3(lx, 0, hd - 1.6)
		await _tp(start.x, start.z)
		player.yaw = atan2(out.x, out.z)
		Game.touch_move = Vector2(0, -1)
		for f in 200:
			await get_tree().physics_frame
			var to: Vector3 = inside - player.global_position
			to.y = 0
			player.yaw = atan2(-to.x, -to.z) if to.length() > 0.3 else player.yaw
			if to.length() < 0.5:
				break
		Game.touch_move = Vector2.ZERO
		var dd: float = Vector2(player.global_position.x - inside.x, player.global_position.z - inside.z).length()
		if dd < 1.0:
			ok += 1
		else:
			bad.append("%s %s at %d,%d r%d (stuck %.1f m short, y %.2f vs floor %.2f)" % [k, String(d.get("sign", d.get("role", ""))), int(d.x), int(d.z), int(d.r), dd, player.global_position.y, Frontier._ground(d) + 0.16])
	print("DOORTEST walked in %d, failed %d" % [ok, bad.size()])
	for l in bad:
		print("DOORTEST fail ", l)
	get_tree().quit()

# build 19: the towns fight back, and factions remember
func _b19_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	Game.flags["gb_hello"] = 1
	Game.dev["god"] = true
	Game.flags.erase("radio")
	await _wait(10)
	var g = null
	for n in npcs:
		if String(n.id) == "sheriff":
			g = n
	out.append("sheriff found %s, guard %s" % [str(g != null), str(g.guard if g else false)])
	if g == null:
		for l in out:
			print("B19TEST ", l)
		get_tree().quit()
		return
	await _tp(g.global_position.x + 5.0, g.global_position.z + 5.0)
	await _wait(30)
	var xp0 := Game.xp
	var civ = null
	for n in npcs:
		if n != g and not n.guard and n.ap and n.visible and n.global_position.distance_to(g.global_position) < 30.0:
			civ = n
	var civ0: Vector3 = civ.global_position if civ else Vector3.ZERO
	var away: Vector3 = ((civ0 - g.global_position) * Vector3(1, 0, 1)).normalized() if civ else Vector3.RIGHT
	var foes: Array = []
	for i in 3:
		var sp: Vector3 = (civ0 if civ else g.global_position) + away * 14.0 + Vector3(i * 2.0, 0, 0)
		var e = events._enemy("raider", sp.x, sp.z, true)
		e.state = "chase"
		foes.append(e)
	var shots := 0
	var drawn := false
	for f in 900:
		await get_tree().physics_frame
		if g.tgt != null:
			shots += 1
		for e in foes:
			if is_instance_valid(e) and not e.dead and e.foe == g:
				drawn = true
		if foes.all(func(e): return not is_instance_valid(e) or e.dead):
			break
	var dead := foes.filter(func(e): return not is_instance_valid(e) or e.dead).size()
	out.append("sheriff engaged %d frames, raiders dead %d/3, a raider fought the sheriff %s, sheriff hp %d down %s" % [shots, dead, str(drawn), int(g.hp), str(g.down > 0.0)])
	out.append("xp from guard kills: %d (want 0)" % (Game.xp - xp0))
	if civ:
		out.append("civilian %s moved %.1f m (fled %s)" % [String(civ.id), civ.global_position.distance_to(civ0), str(civ.fleeing or civ.global_position.distance_to(civ0) > 2.0)])
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.get("npc") == null and e.global_position.distance_to(player.global_position) < 90.0:
			enemies.erase(e)
			e.queue_free()
	await _wait(5)
	# a raid comes in on its own
	events.raid_t = 0.01
	await _wait(10)
	out.append("raid flag %s, hostiles near %d" % [str(Game.flags.get("raids")), enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.hostile and e.global_position.distance_to(player.global_position) < 70.0).size()])
	await _wait(1200)
	out.append("after the raid: %d still standing; guards down %s" % [enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.hostile and e.global_position.distance_to(player.global_position) < 90.0).size(),
		str(npcs.filter(func(n): return n.get("guard") and n.down > 0.0).map(func(n): return n.id))])
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.get("npc") == null and e.global_position.distance_to(player.global_position) < 120.0:
			enemies.erase(e)
			e.queue_free()
	# the new deputies are armed, and talk
	for n in npcs:
		if String(n.id) in ["dw_guard1", "dw_guard2"]:
			out.append("%s armed %s at %s" % [n.id, str(n.guard), str(n.global_position.snapped(Vector3.ONE))])
	out.append(_dlg2("dw_guard1", ["Raiders come", "Good to know"]))
	# hated: folk turn you away, vendors won't trade, guards open fire
	Game.flags["rep_dustwell"] = -9
	Game.flags["rep"] = 0
	var folk = null
	for n in npcs:
		if String(n.id) in ["duggan", "hollis"]:
			folk = n
	if folk:
		hud.screens.open_trade(String(folk.id))
		out.append("hated trade with %s refused %s" % [String(folk.id), str(hud.screens.shop_id != String(folk.id))])
	await _tp(g.global_position.x + 6.0, g.global_position.z)
	await _wait(60)
	out.append("hated: sheriff hostile %s" % str(g.hostile))
	for l in out:
		print("B19TEST ", l)
	get_tree().quit()

func _trees_at(x: float, z: float) -> int:
	var k: String = chunks.key_of(Vector3(x, 0, z))
	var ij := k.split("_")
	return Flora.spots(int(ij[0]), int(ij[1]), 64.0, 0.85, chunks.mask_img).size()

# build 10's story: the council and its pledge, both companion quests, factions and the epilogue
func _story_test() -> void:
	var out: Array = []
	Game.booted = true
	Game.flags["leftVault"] = 1
	await _wait(10)
	Game.flags["met_sheriff"] = 1
	Game.flags["met_ro"] = 1
	Game.start("keys")
	out.append("keys started -> council known %s, heard_haven %s, radio %s" % [str(Game.known("council")), str(Game.flags.get("heard_haven")), str(Game.flags.get("radio"))])
	out.append(_dlg_t("sheriff", ["Everyone wants the core", "And if Haven", "Understood"]))
	out.append(_dlg_t("ines", ["About the Meridian core", "I'll remember"]))
	out.append(_dlg_t("ro", ["Everyone's lining up", "I'll weigh"]))
	out.append("council stage %d (heard %s)" % [Game.stage("council"), str(["dustwell", "saltreach", "lamplight", "gantry", "haven"].filter(func(f): return Game.flags.get("heard_" + f)))])
	out.append(_dlg_t("sheriff", ["I've heard the claims", "Saltreach"]))
	out.append("pledge %s, council done %s, star %d, standing: %s" % [str(Game.flags.get("pledge")), str(Game.is_done("council")), Game.count("council_token"),
		str(["dustwell", "saltreach", "lamplight", "gantry", "haven", "spur"].map(func(f): return "%s %d" % [f, Game.rep_of(f)]))])
	Game.complete("salt_wagons")
	out.append("after Salt and Blood: saltreach %d (%s)" % [Game.rep_of("saltreach"), Game.rep_title(Game.rep_of("saltreach"))])
	# Jory
	Game.level = 4
	recruit("jory")
	out.append(_dlg_t("jory", ["Ever lose one", "Was anything left", "Then let's go"]))
	out.append("jory_wagon stage %d, spawns allowed %d" % [Game.stage("jory_wagon"), Game.region.enemies.filter(func(e): return String(e.get("id", "")).begins_with("jw_") and Game.spawn_allowed(e)).size()])
	player.global_position = Vector3(-262, Game.height(-262, 132) + 0.3, 132)
	chunks.load_now(player.global_position)
	await _wait(20)
	var box = _obj_point("jory_box")
	out.append("wreck: box point %s label %s, raiders near %d" % [str(box != null), str(objects.point_label(box)) if box else "-", enemies.filter(func(e): return String(e.eid).begins_with("jw_")).size()])
	if box:
		objects.point_use(box)
	out.append("strongbox %d, stage %d" % [Game.count("finch_strongbox"), Game.stage("jory_wagon")])
	out.append("finch nodes has f_box %s; screens open %s; opts %s" % [str(Game.DIALOGUE.finch.nodes.has("f_box")), str(hud.screens.is_open()), str(Game.dlg_options("finch", "hub").map(func(o): return o.t))])
	if hud.screens.is_open():
		hud.screens.close()
	out.append(_dlg_t("finch", ["Your lead wagon", "He'll be glad"]))
	out.append("jory_wagon done %s, jory_box %s, finchFriend %s" % [str(Game.is_done("jory_wagon")), str(Game.flags.get("jory_box")), str(Game.flags.get("finchFriend"))])
	# Sable
	Game.complete("signal")
	dismiss("jory", true)
	recruit("sable")
	out.append("party: %s" % str(party.map(func(p): return p.id)))
	out.append(_dlg_t("sable", ["Why did you leave", "So we take it"]))
	player.global_position = Vector3(133, Game.height(133, -2) + 0.3, -2)
	chunks.load_now(player.global_position)
	await _wait(20)
	var led = _obj_point("kess_ledger")
	out.append("ledger point %s label %s" % [str(led != null), str(objects.point_label(led)) if led else "-"])
	if led:
		objects.point_use(led)
	out.append(_dlg_t("sable", ["The ledger", "Burn it"]))
	out.append("sable_ledger done %s, ledger %s" % [str(Game.is_done("sable_ledger")), str(Game.flags.get("ledger"))])
	# build 11: approval and loyalty
	out.append("sable approval after the ledger: %d (%s)" % [Game.approval("sable"), Game.approval_title(Game.approval("sable"))])
	var a0 := Game.approval("sable")
	Game.add_karma(-5, "test")
	out.append("karma -5 -> sable approval %d -> %d" % [a0, Game.approval("sable")])
	Game.add_karma(5, "test")
	Game.flags["appr_sable"] = 35
	out.append(_dlg_t("sable", ["Still bored", "Your secret"]))
	var sb_n = party.filter(func(p): return p.id == "sable")
	out.append("sable loyal %s, dmg %s, hp %s" % [str(Game.is_loyal("sable")), str(sb_n[0].comp.get("dmg")) if sb_n.size() else "-", str(sb_n[0].maxhp) if sb_n.size() else "-"])
	# Renn: recruit, Old Colours, the choice, loyalty
	Game.flags["rennSafe"] = 1
	out.append(_dlg_t("renn2", ["Could Saltreach spare", "Welcome aboard"]))
	out.append("party: %s, renn approval %d" % [str(party.map(func(p): return p.id)), Game.approval("renn2")])
	out.append(_dlg_t("renn2", ["Something's eating", "Then we go", "Let's move"]))
	out.append("old_colours stage %d" % Game.stage("old_colours"))
	player.global_position = Vector3(-330, Game.height(-330, 246) + 0.3, 246)
	chunks.load_now(player.global_position)
	await _wait(30)
	var oc: Array = enemies.filter(func(e): return String(e.eid).begins_with("oc_"))
	out.append("Coyle's crew: %d (%s)" % [oc.size(), str(oc.map(func(e): return String(e.def.get("name", e.type))))])
	for e in oc:
		if not e.dead:
			e.hit(9999.0, e.global_position, Vector3.FORWARD)
	await _wait(5)
	Game.check_quests()
	out.append("crew down: stage %d" % Game.stage("old_colours"))
	var sat = _obj_point("oc_satchel")
	out.append("satchel %s label %s" % [str(sat != null), str(objects.point_label(sat)) if sat else "-"])
	if sat:
		objects.point_use(sat)
	out.append("routes %d, stage %d" % [Game.count("route_list"), Game.stage("old_colours")])
	out.append(_dlg_t("renn2", ["Coyle had a list", "We take this to Ines", "Let's go"]))
	out.append(_dlg_t("ines", ["Someone in Saltreach sold", "Fair."]))
	out.append("old_colours done %s, oc %s, renn approval %d, saltreach %d" % [str(Game.is_done("old_colours")), str(Game.flags.get("oc")), Game.approval("renn2"), Game.rep_of("saltreach")])
	Game.flags["appr_renn2"] = 32
	out.append(_dlg_t("renn2", ["You've changed", "Thank you"]))
	out.append("renn loyal %s, badge %d" % [str(Game.is_loyal("renn2")), Game.count("deputy_star")])
	# walking out: approval far enough down and they leave for good
	Game.flags.erase("loyal_renn2")
	Game.approve("renn2", -150, "test")
	out.append("renn after -150: in party %s, left %s, entry %s" % [str(party.any(func(p): return p.id == "renn2")), str(Game.flags.get("left_renn2")), str(Game.vm.val(Game.DIALOGUE.renn2.entry, [Game.G]))])
	Game.flags["loyal_renn2"] = 1
	# the ending and its epilogue (lamplight: matches a Saltreach pledge)
	Game.flags["ending"] = "lamplight"
	var lines: Array = []
	for ep in Game.L.epilogue:
		if not ep.has("if") or Game.vm.truthy(Game.vm.call_value(ep["if"], [Game.G])):
			lines.append(Game.vm.to_str(Game.vm.val(ep.get("t", ""), [Game.G])).substr(0, 70))
	out.append("epilogue (%d): %s" % [lines.size(), " || ".join(lines)])
	# radio: a song, then the DJ, the second station locked until Dead Air
	set_radio(true)
	out.append("radio on: state %s, station open kdst %s" % [radio_state, str(station_open(1))])
	radio_skip()
	out.append("radio skip: state %s now playing '%s' music playing %s" % [radio_state, now_playing, str(radio_music.playing)])
	Game.complete("dead_air")
	tune(1)
	await _wait(5)
	out.append("KDST: station %d state %s '%s'" % [station, radio_state, now_playing])
	set_radio(false)
	# stealing in Dustwell: owned things near the traders, taken unseen and seen
	player.global_position = Vector3(-95, Game.height(-95, 95) + 0.3, 95)
	chunks.load_now(player.global_position)
	await _wait(30)
	_place_stealables()
	await get_tree().create_timer(2.0).timeout
	var owned: Array = []
	for k in objects.grid:
		for o in objects.grid[k]:
			if o._k == "pickup" and o.get("owned"):
				owned.append(o)
	out.append("owned things placed: %d (%s)" % [owned.size(), str(owned.slice(0, 4).map(func(o): return "%s of %s" % [o.item, o.owned]))])
	if not owned.is_empty():
		var o: Dictionary = owned[0]
		var k0 := Game.karma
		player.crouch = true
		out.append("label: " + str(objects.label_of(o)))
		objects.use(o)
		out.append("stole %s: karma %d -> %d, caught %s" % [o.item, k0, Game.karma, str(Game.flags.get("caught", 0))])
	out.append("vm errors %d %s" % [Game.vm.errors, Game.vm.last_error])
	for l in out:
		print("TEST ", l)
	get_tree().quit()

func _dlg_t(id: String, picks: Array) -> String:
	return _dlg(id, picks)

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
	if hud.screens.is_open():
		hud.screens.close()
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

func _obj_point(id: String):
	for k in objects.grid:
		for o in objects.grid[k]:
			if o._k == "point" and String(o.id) == id:
				return o
	return null

func _obj_near(kind: String, sub := ""):
	var best = null
	var bd := 1e9
	for k in objects.grid:
		for o in objects.grid[k]:
			if o._k == kind and (sub == "" or String(o.get("kind", "")) == sub):
				var d := Vector2(float(o.x) - player.global_position.x, float(o.z) - player.global_position.z).length()
				if d < bd:
					bd = d
					best = o
	return best

func _obj_pos(o: Dictionary) -> Vector3:
	return Vector3(float(o.x), Game.height(float(o.x), float(o.z)), float(o.z))

func _selftest() -> void:
	await _wait(10)
	var out := []
	out.append("npcs %d enemies %d pools %d solids %d" % [npcs.size(), enemies.size(), pools.size(), Game.region.solids.size()])
	out.append(await _talk("sheriff", ["What happened", "I'll get him", "Thanks"]))
	out.append("bad_water stage %d daylight done %s stims %d track %s" % [Game.stage("bad_water"), Game.is_done("daylight"), int(Game.inv.get("stimpak", 0)), str(Game.flags.get("track"))])
	out.append("objective: " + str(Game.current_objective()))
	var wp = _obj_point("well")
	if wp:
		await _goto(_obj_pos(wp) + Vector3(1.2, 0, 0.4), _obj_pos(wp))
		out.append("at well: " + str(_best_target().get("label", "nothing")))
		interact()
	out.append("sample_well %s stage %d" % [Game.has("sample_well"), Game.stage("bad_water")])
	var pp = quest_target()
	out.append("pool target " + str(pp))
	if pp != null:
		var pool_c: Vector3 = pp
		for p in Game.region.pools:
			if Vector2(float(p.x) - pp.x, float(p.z) - pp.z).length() < 1.0:
				await _goto(pool_c + Vector3(float(p.r) + 1.0, 0, 0), pool_c)
		out.append("at pool: " + str(_best_target().get("label", "nothing")))
		interact()
	out.append("sample_glow %s stage %d target %s" % [Game.has("sample_glow"), Game.stage("bad_water"), str(quest_target())])
	# Halloran is at Bunker Nine; the quest marker points there
	fast_travel("bunker")
	await _wait(10)
	out.append(await _talk("halloran", ["Sheriff Voss sent"]))
	out.append("bad_water done %s, signal stage %d, caps %d xp %d" % [Game.is_done("bad_water"), Game.stage("signal"), Game.caps, Game.xp])
	# barter: buy from Halloran's dispensary, sell something back
	out.append(await _talk("halloran", ["Medicine"]))
	if hud.screens.mode == "trade":
		var st := Game.shop_state("halloran")
		var first: String = st.stock.keys()[0]
		var c0 := Game.caps
		Game.caps += 200
		hud.screens._trade(first)
		hud.screens.shop_tab = "sell"
		Game.give("scrap_metal", 3)
		hud.screens._trade("scrap_metal")
		out.append("trade: bought %s (%d ch), sold scrap, caps %d -> %d, info '%s'" % [first, hud.screens.buy_price(first), c0 + 200, Game.caps, hud.screens.shop_info])
		hud.screens.close()
	else:
		out.append("trade screen did not open: " + hud.screens.mode)
	# the workbench: craft something
	var bench = _obj_near("bench")
	if bench:
		await _goto(_obj_pos(bench) + Vector3(1.4, 0, 0), _obj_pos(bench))
		out.append("at bench: " + str(_best_target().get("label", "nothing")))
		interact()
		var r: Dictionary = {}
		for rc in Game.L.recipes:
			if rc.has("out") and not rc.has("flag"):
				r = rc
				break
		for k in r.need:
			Game.give(k, int(r.need[k]))
		var n0 := Game.count(String(r.out[0]))
		for k in r.need:
			Game.take(k, int(r.need[k]))
		Game.give(String(r.out[0]), int(r.out[1]))
		out.append("craft %s: %d -> %d, pip tab %s bench %s" % [r.n, n0, Game.count(String(r.out[0])), hud.pip.current, hud.pip.at_bench])
		hud.toggle_pip()
	# terminals: read the bunker's
	var term = _obj_near("term", "lore")
	if term:
		await _goto(_obj_pos(term) + Vector3(1.2, 0, 0), _obj_pos(term))
		out.append("at terminal: " + str(_best_target().get("label", "nothing")))
		interact()
		await _wait(90)
		out.append("terminal open %s: '%s'" % [str(hud.term.is_open()), hud.term.out.text.substr(0, 60).replace("\n", " / ")])
		hud.term.close()
	# containers: a locked one (pick it), then loot
	var locked = null
	var bd := 1e9
	for c in Game.W.get("chests", []):
		var d := Vector2(float(c.x) - player.global_position.x, float(c.z) - player.global_position.z).length()
		if c.get("lock") != null and int(c.lock) <= 1 and d < bd and in_region(float(c.x), float(c.z)):
			bd = d
			locked = c
	if locked:
		for o in objects.grid.get(objects.key_of(float(locked.x), float(locked.z)), []):
			if o.get("id") == locked.id:
				locked = o
		Game.give("bobby_pin", 3)
		Game.stats.agility = 6
		await _goto(_obj_pos(locked) + Vector3(1.0, 0, 0.3), _obj_pos(locked))
		out.append("at locked %s: %s" % [locked.id, str(_best_target().get("label", "nothing"))])
		objects.use(locked)
		out.append("lockpick open: " + hud.screens.mode)
		hud.screens.lp_solve()
		hud.screens.lp_hold = true
		for i in 40:
			if hud.screens.mode == "lockpick" and not hud.screens.lp.is_empty():
				hud.screens._lp_step(0.05)
		await get_tree().create_timer(0.8, true, false, true).timeout
		out.append("after picking: mode %s, unlocked %s, loot %s" % [hud.screens.mode, Game.opened.has("u_" + String(locked.id)), str(Game.opened.get(String(locked.id)))])
		if hud.screens.mode == "loot":
			hud.screens._take_all()
		hud.screens.close()
	out.append("vm errors %d %s" % [Game.vm.errors, Game.vm.last_error])
	fast_travel("dustwell")
	await _wait(10)
	out.append(await _talk("cass", ["Heard you have", "Consider"]))
	out.append("hounds stage %d" % [Game.stage("hounds")])
	var dens: Vector3 = Vector3(float(Game.DB.locs.dens.x), 0, float(Game.DB.locs.dens.z))
	for e in Game.region.enemies:
		pass
	player.global_position = dens + Vector3(0, Game.height(dens.x, dens.z) + 0.3, 0)
	chunks.load_now(player.global_position)
	await _wait(10)
	var nh := 0
	for e in enemies:
		if e.type == "hound" and not e.dead and Vector2(e.global_position.x - dens.x, e.global_position.z - dens.z).length() < 70.0:
			e.hit(9999.0, e.global_position + Vector3.UP, Vector3.FORWARD)
			nh += 1
	Game.check_quests()
	out.append("killed %d hounds: stage %d" % [nh, Game.stage("hounds")])
	fast_travel("dustwell")
	await _wait(10)
	out.append(await _talk("cass", ["The hounds are dead"]))
	out.append("hounds done %s level %d karma %d" % [Game.is_done("hounds"), Game.level, Game.karma])
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
		# physics frames can outrun drawn ones when the machine is slow: wait for the camera to take the pitch
		await get_tree().process_frame
		await get_tree().process_frame
		await _wait(2)
		var hp0: float = tgt.hp
		player.fire_cd = 0.0
		var from: Vector3 = player.cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + (-player.cam.global_transform.basis.z) * 60.0, 1 | 2 | 4)
		q.exclude = [player.get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		out.append("aim ray hits " + (str(h.collider.name) + " (" + h.collider.get_class() + ")" if h else "nothing") + " | target %s " % tgt.type + "%s at %s, me at %s yaw %.2f pitch %.2f dist %.1f" % [tgt.eid, str(tp.snapped(Vector3.ONE * 0.1)), str(player.global_position.snapped(Vector3.ONE * 0.1)), player.yaw, player.pitch, player.global_position.distance_to(tp)])
		player.fire()
		await _wait(2)
		out.append("shot a %s: hp %.0f -> %.0f, mag %d" % [tgt.type, hp0, tgt.hp, Game.mag])
	var others := []
	for n in npcs:
		if n.id != "sheriff" and n.id != "cass":
			others.append(n.id + ":" + ("ok" if Game.DIALOGUE.has(n.id) else "silent"))
	out.append("quests known %d, active %s" % [Game.quests.size(), str(Game.quests.keys().filter(func(q): return not Game.quests[q].done))])
	out.append("others " + " ".join(others))
	out.append("nav ready " + str(Game.nav_ready))
	# weapons: every kind fires and uses its own ammo
	for w in ["scatter_gun", "rattler", "arc_pistol", "magnum", "combat_knife", "hunting_rifle"]:
		Game.give(w, 1)
		var am = Game.item(w).get("ammo")
		if am:
			Game.give(am, 20)
		Game.equip(w)
		await _wait(2)
		player.reload_t = 0.0
		Game.mag = Game.mag_size
		var m0 := Game.mag
		player.fire_cd = 0.0
		player.fire()
		out.append("weapon %s (%s): mag %d -> %d, model %s" % [w, Game.item(w).kind, m0, Game.mag, "arms+" + ("gun" if player.vm.gun else "fists")])
	# ammo types: the 10mm pistol takes 10mm, and swapping to FMJ unloads the standard rounds back into the box
	Game.give("service_pistol", 1)
	Game.give("ammo_10", 20)
	Game.give("ammo_10_fmj", 10)
	Game.equip("service_pistol")
	await _wait(2)
	player.reload_t = 0.0
	Game.mag = 0
	Game.magt.erase("service_pistol")
	player.reload()
	player.reload_t = 0.001
	for i in 4:
		await get_tree().process_frame
	var a0 := "%s %d/%d" % [Game.loaded_ammo(), Game.mag, Game.count("ammo_10")]
	Game.cycle_ammo()
	player.reload()
	player.reload_t = 0.001
	for i in 4:
		await get_tree().process_frame
	out.append("ammo10 %s -> %s %d, std %d, fmj %d, shop %s" % [a0, Game.loaded_ammo(), Game.mag, Game.count("ammo_10"), Game.count("ammo_10_fmj"),
		str(Game.shop_state("brannock").stock.has("ridgeback")) + "/" + str(Game.shop_state("brannock").stock.has("ammo_10_fmj"))])
	Game.equip("pipe_pistol")
	# loot a corpse
	var corpse = null
	for e in enemies:
		if e.dead:
			corpse = e
	if corpse:
		out.append("loot: " + str(loot_for(corpse.type)))
	# aid
	Game.hp = 30.0
	var st0 := Game.count("stimpak")
	Game.use_item("stimpak")
	out.append("stimpak: hp %.0f, stims %d -> %d" % [Game.hp, st0, Game.count("stimpak")])
	# grenades: a frag dropped next to a living enemy, a molotov on another
	var live := enemies.filter(func(e): return not e.dead)
	if live.size() > 0:
		Game.give("frag", 1)
		Game.use_item("frag")
		var nt: Node3D = live[0]
		var hp0: float = nt.hp
		var n := Nade.throw_from(nt.global_position + Vector3(1.0, 1.5, 0), Vector3.ZERO, Game.nade_kind())
		Game.take("frag")
		n.vel = Vector3.ZERO
		n.fuse = 0.2   # creatures wander off during a real fuse
		for i in 30:
			await get_tree().physics_frame
		out.append("frag: hp %.0f -> %.0f dead %s" % [hp0, nt.hp, nt.dead])
		if live.size() > 1:
			var t2: Node3D = live[1]
			var h2: float = t2.hp
			Game.give("molotov", 1)
			var m := Nade.throw_from(t2.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, "molotov")
			m.vel = Vector3.ZERO
			for i in 120:
				await get_tree().physics_frame
			out.append("molotov: hp %.0f -> %.0f" % [h2, t2.hp])
	# FOCUS: queue torso shots at the nearest live enemy in front, play them out
	var fe = null
	for e in enemies:
		if not e.dead and (fe == null or e.global_position.distance_to(player.global_position) < fe.global_position.distance_to(player.global_position)):
			fe = e
	if fe:
		var to: Vector3 = fe.global_position - player.global_position
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = 0.0
		if to.length() > 25.0:
			player.global_position = fe.global_position - to.normalized() * 10.0 + Vector3.UP * 0.5
			player.yaw = atan2(-to.x, -to.z)
		await _wait(3)
		Game.ap = Game.ap_max
		Game.mag = Game.mag_size
		var hp0: float = fe.hp
		hud.focus.enter()
		out.append("focus open %s targets %d first %s, parts %s" % [hud.focus.visible, hud.focus.list.size(), fe.type if hud.focus.list.is_empty() else hud.focus.list[0].type, str(hud.focus.parts(hud.focus.list[0]).map(func(p): return [p.n, roundi(hud.focus.chance(hud.focus.list[0], p) * 100.0)])) if hud.focus.visible else ""])
		if hud.focus.visible:
			var ft = hud.focus.list[0]
			hp0 = ft.hp
			var torso: Dictionary = hud.focus.parts(ft)[1 if hud.focus.parts(ft).size() > 2 else 0]
			for i in 3:
				hud.focus.queue.append({"e": ft, "part": torso, "c": hud.focus.chance(ft, torso)})
			var ap0 := Game.ap
			hud.focus.execute()
			for i in 300:
				await get_tree().physics_frame
				if hud.focus.exec < 0:
					break
			out.append("focus executed: AP %d -> %d, %s hp %.0f -> %.0f dead %s, time scale %.2f" % [ap0, Game.ap, ft.type, hp0, ft.hp, ft.dead, Engine.time_scale])
	# companions: Jory joins, follows, fights; Biscuit too; commands; dismiss
	Game.G.recruit("jory")
	Game.G.recruit("biscuit")
	out.append("party %s, jory state %s, in party %s" % [str(party.map(func(p): return p.id)), str(Game.G.partyState("jory")), Game.G.inParty("jory")])
	var cfoe = null
	for e in enemies:
		if not e.dead and e.hostile:
			cfoe = e
			break
	if cfoe and party.size() > 0:
		var jory = party[0]
		cfoe.state = "chase"
		var hp1: float = cfoe.hp
		player.global_position = cfoe.global_position + Vector3(12, 0.5, 0)
		jory.global_position = cfoe.global_position + Vector3(14, 0.5, 2)
		for i in 240:
			await get_tree().physics_frame
		out.append("jory vs %s: hp %.0f -> %.0f (dead %s), jory hp %.0f down %.1f, target %s" % [cfoe.type, hp1, cfoe.hp, cfoe.dead, jory.hp, jory.down, str(jory.tgt != null)])
	Game.G.partyCmd("jory", "wait")
	out.append("after wait: %s; flags.party %s" % [str(Game.G.partyState("jory")), str(Game.flags.get("party"))])
	Game.G.dismiss("jory")
	out.append("after dismiss: party %s" % [str(party.map(func(p): return p.id))])
	# shooting a townsperson: Duggan turns on you; shooting the sheriff, who can't die, makes her yield
	fast_travel("dustwell")
	await _wait(10)
	var dug = null
	var sher = null
	for n in npcs:
		if n.id == "duggan":
			dug = n
		if n.id == "sheriff":
			sher = n
	if dug:
		var k0 := Game.karma
		dug.hit(10.0, dug.global_position + Vector3.UP, Vector3.FORWARD)
		var de = null
		for e in enemies:
			if e.get("npc") == dug:
				de = e
		out.append("provoked duggan: hidden %s enemy %s hp %.0f karma %d -> %d" % [not dug.visible, str(de != null), de.hp if de else -1.0, k0, Game.karma])
		if de:
			de.hit(9999.0, de.global_position + Vector3.UP, Vector3.FORWARD)
			out.append("duggan dead %s flag %s karma %d npcs has him %s" % [de.dead, str(Game.flags.get("npcDead_duggan")), Game.karma, npcs.has(dug)])
	if sher:
		sher.hit(5.0, sher.global_position + Vector3.UP, Vector3.FORWARD)
		var se = null
		for e in enemies:
			if e.get("npc") == sher:
				se = e
		if se:
			se.hit(9999.0, se.global_position + Vector3.UP, Vector3.FORWARD)
			out.append("sheriff after lethal hit: dead %s hp %.0f hostile %s" % [se.dead, se.hp, se.hostile])
			await get_tree().create_timer(4.5).timeout
			out.append("sheriff back: visible %s hostile %s" % [sher.visible, sher.hostile])
	# the Rust Runner: fixed, keyed, driven down the road, parked
	if buggy:
		Game.flags["buggy"] = {"fixed": true}
		Game.give("buggy_key", 1)
		player.global_position = buggy.global_position + Vector3(2.5, 0.5, 0)
		await _wait(3)
		var lab: String = buggy.label()
		var b0: Vector3 = buggy.global_position
		buggy.enter()
		for i in 150:
			buggy.drive(1.0 / 60.0, Vector2(0.15, -1.0))
			await get_tree().physics_frame
		out.append("buggy: '%s', drove %.1f m at %.1f m/s, driving %s" % [lab, buggy.global_position.distance_to(b0), absf(buggy.v), buggy.driving])
		buggy.exit()
		out.append("buggy exit: driving %s, player visible %s, saved %s" % [buggy.driving, player.visible, str(Game.flags.get("buggy")).substr(0, 60)])
	# chems, radiation, radio
	var sp0: float = Game.fx().speed
	Game.give("jolt", 1)
	Game.use_item("jolt")
	Game.body_tick(5.0)
	out.append("jolt: speed %.2f -> %.2f, agility %d, drugs %s" % [sp0, Game.fx().speed, Game.stats.agility, str(Game.drugs.keys())])
	Game.add_rad(30.0, false)
	out.append("rad %.0f, max hp %d" % [Game.rad, Game.hp_max])
	Game.give("radaway", 1)
	Game.use_item("radaway")
	out.append("after Rad Flush: rad %.0f, max hp %d" % [Game.rad, Game.hp_max])
	Game.flags["radio"] = "overseer"
	radio_tick(0.1)
	out.append("radio: screen %s heard %s" % [hud.screens.mode, str(Game.flags.get("heard"))])
	hud.screens.close()
	out.append("clock %s day %d weather %s" % [atmos.clock(), Game.day, atmos.kind])
	# road events: a caravan under attack, a dead scavenger, a stranded traveller
	Game.booted = true
	player.global_position = Vector3(-40.0, Game.height(-40.0, 60.0) + 0.5, 60.0)
	await _wait(5)
	var ok := events.start("caravan")
	out.append("caravan started %s at %s foes %d npcs %d" % [ok, str(Vector2(events.cur.get("x", 0), events.cur.get("z", 0)).snapped(Vector2.ONE)), events.cur.get("foes", []).size(), events.cur.get("npcs", []).size()])
	if ok:
		player.global_position = Vector3(float(events.cur.x) + 20.0, Game.height(float(events.cur.x) + 20.0, float(events.cur.z)) + 0.5, float(events.cur.z))
		for i in 30:
			await get_tree().physics_frame
		out.append("caravan seen %s, quest stage %d tracked %s" % [events.cur.seen, Game.stage("caravan_rescue"), str(Game.flags.get("track"))])
		for e in events.cur.foes:
			e.hit(9999.0, e.global_position + Vector3.UP, Vector3.FORWARD)
		for i in 10:
			await get_tree().physics_frame
		out.append("caravan saved: evClear %s, quest done %s" % [str(Game.flags.get("evClear")), Game.is_done("caravan_rescue")])
	ok = events.start("scav")
	if ok:
		var ch: Dictionary = events.cur.chests[0]
		out.append("scav body: %s label %s, foes %s" % [ch.id, str(objects.label_of(ch)), str(events.cur.foes.map(func(e): return e.type))])
	ok = events.start("stranger")
	if ok:
		player.global_position = Vector3(float(events.cur.x) + 2.0, Game.height(float(events.cur.x) + 2.0, float(events.cur.z)) + 0.5, float(events.cur.z))
		await _wait(3)
		Game.give("stimpak", 1)
		out.append(await _talk("stranger", ["Here, a stimpak"]))
		out.append("stranger helped %s karma %d" % [str(Game.flags.get("evHelped")), Game.karma])
	events.clear()
	# discovery, map and travel
	Game.discover("dustwell")
	var far_k := ""
	for k in Game.DB.locs:
		var L: Dictionary = Game.DB.locs[k]
		if k != "dustwell" and in_region(float(L.x), float(L.z)) and Vector2(float(L.x) - player.global_position.x, float(L.z) - player.global_position.z).length() > 150.0:
			far_k = k
	if far_k != "":
		Game.discover(far_k)
		for e in enemies:
			e.state = "idle"
		fast_travel(far_k)
		await _wait(10)
		out.append("travelled to %s: at %s, chunks %d, people %d" % [far_k, str(player.global_position.round()), chunks.count(), npcs.size() + enemies.size()])
	# save, change things, load back
	Game.save_game("3")
	var caps0 := Game.caps
	Game.caps = 1
	out.append("save slot 3: " + Game.save_info("3"))
	var f := FileAccess.open("user://save_3.json", FileAccess.READ)
	var sv = JSON.parse_string(f.get_as_text())
	out.append("saved caps %d (now %d), weapon %s, level %d" % [int(sv.caps), Game.caps, sv.weapon, int(sv.level)])
	Game.caps = caps0
	out.append("xp %d/%d level %d points %d carry %.0f/%.0f" % [Game.xp, Game.xp_need(), Game.level, Game.points, Game.carry_now(), Game.carry_max()])
	# every conversation line, option condition, quest stage text, check and marker, evaluated against the current state
	var e0: int = Game.vm.errors
	var nf := 0
	for id in Game.DIALOGUE:
		Game.dlg_entry(id)
		for nk in Game.DIALOGUE[id].get("nodes", {}):
			Game.dlg_say(id, nk)
			Game.dlg_options(id, nk)
			nf += 1
	for q in Game.L.quests:
		var d: Dictionary = Game.L.quests[q]
		Game.vm.val(d.get("desc", ""), [Game.G])
		Game.vm.val(d.get("reward"), [Game.G])
		for st in d.get("stages", []):
			Game.vm.val(st.get("txt", ""), [Game.G])
			if st.has("done"):
				Game.vm.call_value(st.done, [Game.G])
			if st.has("pos"):
				Game.vm.val(st.pos, [Game.G])
	for k in Game.L.points:
		if Game.L.points[k].has("label"):
			Game.vm.call_value(Game.L.points[k].label, [{"id": k, "echo": 0, "cellIn": 0}])
	out.append("evaluated %d dialogue nodes, %d quests, %d quest objects: %d errors %s" % [nf, Game.L.quests.size(), Game.L.points.size(), Game.vm.errors - e0, Game.vm.last_error])
	# every option's effect, run on a copy of the game state that is thrown away afterwards
	var keep := {}
	for k in ["inv", "flags", "quests", "kills", "killed", "shops", "upgrades", "opened", "looted", "discovered"]:
		keep[k] = Game.get(k).duplicate(true)
	for k in ["caps", "xp", "level", "points", "karma", "hp", "day"]:
		keep[k] = Game.get(k)
	var e1: int = Game.vm.errors
	var na := 0
	for id in Game.DIALOGUE:
		for nk in Game.DIALOGUE[id].get("nodes", {}):
			for o in Game.DIALOGUE[id].nodes[nk].get("opts", []):
				if o.has("act"):
					Game.vm.call_value(o.act, [Game.G])
					na += 1
	for k in Game.L.points:
		if Game.L.points[k].has("use"):
			Game.vm.call_value(Game.L.points[k].use, [{"id": k, "echo": 0, "cellIn": 0}])
			na += 1
	pending_trade = ""
	hud.screens.close()
	out.append("ran %d option and object effects: %d errors %s; quests now %d" % [na, Game.vm.errors - e1, Game.vm.last_error, Game.quests.size()])
	for k in keep:
		Game.set(k, keep[k])
	Game._vm_state()
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
	if Game.area == "khole":
		KHole.environment(env, sun)
	elif Game.area == "cells":
		# inside the town's buildings: lamplight and a little daylight from the windows
		env.background_mode = Environment.BG_COLOR
		# a pinhole between two wall pieces shows this, so make it the colour of the room, not a black void
		env.background_color = Color(0.26, 0.22, 0.18)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		# build 23: the flat fill turned down, so the room's own lamps light it, with shadows from the one you're under
		env.ambient_light_color = Color(0.9, 0.84, 0.76)
		env.ambient_light_energy = 0.55
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.fog_enabled = false
		sun.visible = false
		sun.shadow_enabled = false
		var cy := float(Game.L.consts.CELLS.y)
		cell_lights.clear()
		for C in Game.CELLS:
			var n := 1 if float(C.D2) < 16.0 else 2
			cell_lights.append([])
			for k in n:
				var l := OmniLight3D.new()
				cell_lights[-1].append(l)
				l.light_color = Color(1.0, 0.84, 0.64)
				l.light_energy = 2.4
				l.shadow_bias = 0.08
				l.shadow_blur = 1.5
				l.omni_range = maxf(float(C.W2), float(C.D2) / n) * 0.8
				l.omni_attenuation = 1.1
				l.shadow_enabled = false
				add_child(l)
				var dz := 0.0 if n == 1 else (k - 0.5) * float(C.D2) * 0.5
				l.global_position = Vector3(float(C.ox), cy + 3.2, float(C.oz) + dz)
	elif Game.area == "vault":
		# underground: no sky, no sun, cool strip lights along the corridors
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.24, 0.27, 0.26)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.74, 0.78)
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.fog_enabled = false
		sun.visible = false
		sun.shadow_enabled = false
		env.ambient_light_energy = 0.72
		env.ambient_light_color = Color(0.72, 0.75, 0.78)
		env.background_color = Color(0.24, 0.27, 0.26)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.glow_intensity = 0.5
		env.glow_bloom = 0.04
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.92
		vault_dress = VaultDress.new()
		add_child(vault_dress)
		vault_dress.setup(self)
		_furnish_vault.call_deferred()

# every chunk's meshes: wide flat pieces high off the ground with nothing under them (roofs that float)
func _floatscan() -> void:
	var found := 0
	for k in chunks.files:
		var ps: PackedScene = load(chunks.files[k])
		if ps == null:
			continue
		var n := ps.instantiate() as Node3D
		var boxes: Array = []
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var t := Transform3D.IDENTITY
			var x: Node = mi
			while x != null and x != n:
				t = (x as Node3D).transform * t
				x = x.get_parent()
			boxes.append([String(mi.name), t * mi.get_aabb()])
		for b in boxes:
			var ab: AABB = b[1]
			if ab.size.y > 1.5 or ab.size.x * ab.size.z < 4.0 or ab.size.x > 30.0 or ab.size.z > 30.0:
				continue
			var c := ab.get_center()
			var gy: float = Game.height(c.x, c.z)
			if ab.position.y - gy < 1.4:
				continue
			var held := false
			for o in boxes:
				var ob: AABB = o[1]
				if ob == ab:
					continue
				var top := ob.end.y
				if top < ab.position.y - 0.7 or ob.position.y > ab.position.y + 0.2:
					continue
				var ix := minf(ab.end.x, ob.end.x) - maxf(ab.position.x, ob.position.x)
				var iz := minf(ab.end.z, ob.end.z) - maxf(ab.position.z, ob.position.z)
				if ix > 0.0 and iz > 0.0 and ix * iz > ab.size.x * ab.size.z * 0.05:
					held = true
					break
			if not held:
				found += 1
				print("FLOAT %s chunk %s at %s size %s gap %.2f" % [b[0], k, str(c.snapped(Vector3.ONE * 0.1)), str(ab.size.snapped(Vector3.ONE * 0.1)), ab.position.y - gy])
		n.free()
	print("FLOATSCAN done ", found)
	get_tree().quit()

# build 17: roofs and slabs left hanging in the air by the export (a roof slab over Dustwell's brick ruin, south of
# the crossroads). The export merges every building's pieces into one mesh per material, so each mesh is split into
# its separate pieces (triangles joined by shared corners); a piece shaped like a slab is tested with rays down from
# round its underside against all the real geometry of the chunk and the ground. One that rests on nothing within
# reach is lowered onto the nearest thing under it. Results go to data/settle.json (file -> mesh -> [[vertex
# indices], drop]); chunks.gd moves those vertices as the chunk loads.
func _roofscan() -> void:
	var out := {}
	var found := 0
	var space := get_world_3d().direct_space_state
	var paths: Array = chunks.files.values()
	paths.sort()
	for path in paths:
		var ps: PackedScene = load(path)
		if ps == null:
			continue
		var fname := String(path).get_file().get_basename()
		var n := ps.instantiate() as Node3D
		add_child(n)
		var mis: Array = []
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			mis.append(mi)
			var sb := StaticBody3D.new()
			sb.collision_layer = 1 << 19
			var cs := CollisionShape3D.new()
			cs.shape = mi.mesh.create_trimesh_shape()
			sb.add_child(cs)
			mi.add_child(sb)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for mi in mis:
			var t: Transform3D = mi.global_transform
			for si in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var I = arr[Mesh.ARRAY_INDEX]
				var idx: PackedInt32Array = I if I != null and I.size() > 0 else PackedInt32Array(range(V.size()))
				# union the corners of each triangle, welding coincident positions
				var weld := {}
				var parent := PackedInt32Array()
				parent.resize(V.size())
				for i in V.size():
					var key := V[i].snapped(Vector3.ONE * 0.01)
					parent[i] = int(weld.get(key, i))
					if not weld.has(key):
						weld[key] = i
				var find := func(f: Callable, x: int) -> int:
					while parent[x] != x:
						parent[x] = parent[parent[x]]
						x = parent[x]
					return x
				for ti in range(0, idx.size(), 3):
					var r0: int = find.call(find, idx[ti])
					for k in [1, 2]:
						var rk: int = find.call(find, idx[ti + k])
						if rk != r0:
							parent[rk] = r0
				var groups := {}
				for i in V.size():
					var r: int = find.call(find, i)
					if not groups.has(r):
						groups[r] = PackedInt32Array()
					groups[r].append(i)
				for r in groups:
					var g: PackedInt32Array = groups[r]
					if g.size() < 8 or g.size() > 400:
						continue
					var pts := PackedVector3Array()
					for i in g:
						pts.append(t * V[i])
					var res := _slab_of(pts)
					if res.is_empty():
						continue
					# sweep a thin copy of the slab's underside straight down until it touches something
					var bs := BoxShape3D.new()
					bs.size = Vector3(res.size.x * 0.96, 0.1, res.size.z * 0.96)
					var sq := PhysicsShapeQueryParameters3D.new()
					sq.shape = bs
					sq.transform = Transform3D(res.basis, res.c - res.basis.y * (res.size.y * 0.5 + 0.08))
					sq.motion = Vector3(0, -25.0, 0)
					sq.collision_mask = (1 << 19) | 1
					var cm := space.cast_motion(sq)
					if cm.is_empty() or float(cm[0]) <= 0.0:
						continue
					var drop: float = float(cm[0]) * 25.0 + 0.11
					if drop > 0.3:
						var mp := String(n.get_path_to(mi))
						out.get_or_add(fname, {}).get_or_add(mp + "#" + str(si), []).append([Array(g), snappedf(drop, 0.01)])
						found += 1
						print("ROOF %s %s#%d at %s size %s -> drop %.2f" % [fname, mp, si, str(res.c.snapped(Vector3.ONE * 0.1)), str(res.size.snapped(Vector3.ONE * 0.1)), drop])
		n.queue_free()
		await get_tree().process_frame
	# candidates only: a report to look through (most are roofs resting on their walls); real fixes are picked
	# one by one with tools/settle/pick.gd into data/settle.json
	var f := FileAccess.open("user://roofscan.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("ROOFSCAN done ", found)
	get_tree().quit()

# build 24: whole props the export left hanging over the ground (a van a foot above the road, chairs, crates,
# barrels): every lone prop of a chunk (its own mesh, s_*) that touches nothing else and has only open air between
# it and the ground is lowered until it rests on the ground. Results to user://propscan.json (file -> {"@mesh": drop}),
# copied into data/settle.json, which chunks.gd applies as the chunk loads.
func _propscan() -> void:
	var out := {}
	var found := 0
	var space := get_world_3d().direct_space_state
	var paths: Array = chunks.files.values()
	paths.sort()
	for path in paths:
		var ps: PackedScene = load(path)
		if ps == null:
			continue
		var fname := String(path).get_file().get_basename()
		var n := ps.instantiate() as Node3D
		add_child(n)
		var mis: Array = []
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var sb := StaticBody3D.new()
			sb.collision_layer = 1 << 19
			var cs := CollisionShape3D.new()
			cs.shape = mi.mesh.create_trimesh_shape()
			sb.add_child(cs)
			mi.add_child(sb)
			mis.append([mi, sb])
		await get_tree().physics_frame
		await get_tree().physics_frame
		# roads, pads and ground cover lie under everything: touching them isn't being held by them
		var flats: Array = []
		for e in mis:
			var fab: AABB = (e[0] as MeshInstance3D).global_transform * (e[0] as MeshInstance3D).get_aabb()
			if fab.size.y < 1.0 and fab.size.x * fab.size.z > 20.0:
				flats.append((e[1] as StaticBody3D).get_rid())
		for e in mis:
			var mi: MeshInstance3D = e[0]
			if not String(mi.name).begins_with("s_"):
				continue
			var ab: AABB = mi.global_transform * mi.get_aabb()
			if ab.size.x > 12.0 or ab.size.z > 12.0 or ab.size.y > 8.0 or ab.size.length() < 0.3:
				continue
			# the ground under it, all round
			var gmax := -INF
			var gmin := INF
			for fx in [0.1, 0.5, 0.9]:
				for fz in [0.1, 0.5, 0.9]:
					var gy: float = Game.height(ab.position.x + ab.size.x * fx, ab.position.z + ab.size.z * fz)
					gmax = maxf(gmax, gy)
					gmin = minf(gmin, gy)
			var gap := ab.position.y - gmax
			if gap < 0.12 or gap > 6.0:
				continue
			# touching anything else (resting on a table, hung on a wall, part of something bigger)? then it's held
			var q := PhysicsShapeQueryParameters3D.new()
			var bs := BoxShape3D.new()
			bs.size = ab.size + Vector3.ONE * 0.08
			q.shape = bs
			q.transform = Transform3D(Basis(), ab.get_center())
			q.collision_mask = 1 << 19
			q.exclude = flats + [(e[1] as StaticBody3D).get_rid()]
			if ab.size.y < 0.05 or minf(ab.size.x, ab.size.z) < 0.03:
				continue
			var held := false
			for h in space.intersect_shape(q, 4):
				held = true
			if held:
				continue
			# and nothing under it but air (a sweep of its footprint straight down to the first thing it meets)
			var sq := PhysicsShapeQueryParameters3D.new()
			var fb := BoxShape3D.new()
			fb.size = Vector3(maxf(0.05, ab.size.x * 0.9), 0.05, maxf(0.05, ab.size.z * 0.9))
			sq.shape = fb
			sq.transform = Transform3D(Basis(), Vector3(ab.get_center().x, ab.position.y - 0.03, ab.get_center().z))
			sq.motion = Vector3(0, -(gap + 0.5), 0)
			sq.collision_mask = (1 << 19) | 1
			sq.exclude = [(e[1] as StaticBody3D).get_rid()]
			var cm := space.cast_motion(sq)
			var drop := gap
			if not cm.is_empty() and float(cm[0]) < 1.0:
				drop = minf(gap, float(cm[0]) * (gap + 0.5) + 0.03)
			if drop < 0.12:
				continue
			out.get_or_add(fname, {})["@" + String(n.get_path_to(mi))] = snappedf(drop, 0.01)
			found += 1
			print("PROP %s %s at %s size %s floats %.2f" % [fname, mi.name, str(ab.get_center().snapped(Vector3.ONE * 0.1)), str(ab.size.snapped(Vector3.ONE * 0.1)), drop])
		n.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open("user://propscan.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("PROPSCAN done ", found)
	get_tree().quit()

# a piece shaped like a slab (two long axes, one thin one, lying more flat than upright): its centre, size and
# eight points round the edge of its underside
func _slab_of(pts: PackedVector3Array) -> Dictionary:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	# the thin axis: the direction the points spread least along, found by trying a set of directions
	var best := Vector3.UP
	var best_s := INF
	for ix in 13:
		for iy in 13:
			var th := ix * PI / 12.0
			var ph := iy * PI / 12.0
			var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var lo := INF
			var hi := -INF
			for p in pts:
				var v := (p - c).dot(dir)
				lo = minf(lo, v)
				hi = maxf(hi, v)
			if hi - lo < best_s:
				best_s = hi - lo
				best = dir
	if best.y < 0.0:
		best = -best
	if best_s > 0.6 or best.y < 0.55:
		return {}
	var a := best.cross(Vector3.FORWARD if absf(best.z) < 0.9 else Vector3.RIGHT).normalized()
	var b := a.cross(best).normalized()        # (a, best, b) must be right-handed for the physics query
	var la := [INF, -INF]
	var lb := [INF, -INF]
	for p in pts:
		var va := (p - c).dot(a)
		var vb := (p - c).dot(b)
		la = [minf(la[0], va), maxf(la[1], va)]
		lb = [minf(lb[0], vb), maxf(lb[1], vb)]
	var sa: float = la[1] - la[0]
	var sb: float = lb[1] - lb[0]
	if sa < 1.5 or sb < 1.5 or sa > 16.0 or sb > 16.0:
		return {}
	var probes: Array = []
	for uv in [Vector2(0.04, 0.04), Vector2(0.5, 0.04), Vector2(0.96, 0.04), Vector2(0.96, 0.5), Vector2(0.96, 0.96), Vector2(0.5, 0.96), Vector2(0.04, 0.96), Vector2(0.04, 0.5)]:
		var p: Vector3 = c + a * lerpf(la[0], la[1], uv.x) + b * lerpf(lb[0], lb[1], uv.y) - best * best_s * 0.5
		probes.append(p)
	var cc: Vector3 = c + a * (la[0] + la[1]) * 0.5 + b * (lb[0] + lb[1]) * 0.5
	return {"c": cc, "size": Vector3(sa, best_s, sb), "probes": probes, "basis": Basis(a, best, b)}

func _lifelog() -> void:
	while true:
		await get_tree().create_timer(3.0).timeout
		var out := []
		for n in npcs:
			out.append("%s:%s/%s[%s]@%.0f,%.0f" % [n.id, n.life, String(n.spot.get("kind", "-")), n.beat_a if n.life == "act" else n.home_a, n.global_position.x, n.global_position.z])
		print("LIFE spots=%d keys=%s " % [town.spots.size(), str(town.ready_keys.keys())], " ".join(out))

# Haven 12's rooms get their furniture once the walls (and their collision) are in
func _furnish_vault() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	Furnish.vault(self, vault_dress.O)
	await get_tree().physics_frame
	await get_tree().physics_frame
	town.bake_box("vault", AABB(vault_dress.O + Vector3(-28.0, -1.0, -1.0), Vector3(56.0, 5.0, 95.0)))

# ---------------------------------------------------------------- terrain: streamed ground meshes, one physics heightfield
func _terrain() -> void:
	var w := Game.hw
	var dd := Game.hd
	terrain_full = ShaderMaterial.new()
	terrain_full.shader = preload("res://scripts/terrain.gdshader")
	for k in ["sand", "sand_n", "dirt", "rock", "rock_n"]:
		terrain_full.set_shader_parameter("t_" + k, load("res://tex/" + k + ".webp"))
	terrain_full.set_shader_parameter("t_road", load("res://tex/asphalt.webp"))
	terrain_full.set_shader_parameter("t_mask", load("res://data/mask.png"))
	terrain_full.set_shader_parameter("t_tint", load("res://data/tint.png"))
	terrain_full.set_shader_parameter("region", Vector4(Game.x0, Game.z0, w - 1, dd - 1))
	terrain_lite = ShaderMaterial.new()
	terrain_lite.shader = preload("res://scripts/terrain_lite.gdshader")
	for k in ["sand", "rock"]:
		terrain_lite.set_shader_parameter("t_" + k, load("res://tex/" + k + ".webp"))
	terrain_lite.set_shader_parameter("t_mask", load("res://data/mask.png"))
	terrain_lite.set_shader_parameter("region", Vector4(Game.x0, Game.z0, w - 1, dd - 1))
	var img: Image = (load("res://data/mask.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	Flora.far_on = Quality.load_level() > 0
	chunks = preload("res://scripts/chunks.gd").new()
	add_child(chunks)
	chunks.setup(terrain_full, img, _grass_mesh())
	# physics: one heightfield for the whole map, which Jolt handles far more cheaply than triangles
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

func _world() -> void:
	pass

func cam_far(d: float) -> void:
	if player:
		player.cam.far = d + 60.0

func set_quality(l: int) -> void:
	quality = l
	Quality.save_level(l)
	Quality.apply(self, l)
	chunks.set_material(terrain_lite if l == 0 else terrain_full)

func cycle_quality() -> String:
	Quality.custom = {}
	set_quality((quality + 1) % Quality.NAMES.size())
	return Quality.NAMES[quality]

func _colliders() -> void:
	var bodies := {}
	for s in Game.region.solids:
		var k: String = chunks.key_of(Vector3((s[0] + s[1]) * 0.5, 0, (s[2] + s[3]) * 0.5))
		if not bodies.has(k):
			var nb := StaticBody3D.new()
			nb.collision_layer = 1
			add_child(nb)
			bodies[k] = nb
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		var y0 := float(s[4])
		# anything standing on the ground reaches all the way down to it, even where the ground falls away
		# (otherwise there's a gap to crawl under and into the building, where nothing can follow you)
		if y0 > -900.0 and Game.area == "world":
			var hmin := 1e9
			for gx in [s[0], (s[0] + s[1]) * 0.5, s[1]]:
				for gz in [s[2], (s[2] + s[3]) * 0.5, s[3]]:
					hmin = minf(hmin, Game.height(float(gx), float(gz)))
			if y0 - hmin > 0.0 and y0 - hmin < 3.0:
				y0 = hmin - 0.3
		b.size = Vector3(maxf(0.05, s[1] - s[0]), maxf(0.05, s[5] - y0), maxf(0.05, s[3] - s[2]))
		cs.shape = b
		cs.position = Vector3((s[0] + s[1]) * 0.5, (y0 + s[5]) * 0.5, (s[2] + s[3]) * 0.5)
		bodies[k].add_child(cs)

func _pools() -> void:
	# wait for the collision to be in, so the pools can lie on concrete pads as well as on the ground
	for i in 2:
		if not is_inside_tree():
			return
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var sh := preload("res://scripts/water.gdshader")
	for p in Game.region.pools:
		var y := Game.height(p.x, p.z)
		# the water sits at the lowest ground under the pool, like the original
		for a in 8:
			var r := float(p.r) * 0.6
			y = minf(y, Game.height(p.x + cos(a * TAU / 8.0) * r, p.z + sin(a * TAU / 8.0) * r))
		var mi := MeshInstance3D.new()
		# a round sheet laid over whatever it lies on (ground, a concrete pad), a few centimetres up: it pools in the
		# dips and never hangs in the air over a slope
		mi.mesh = _pool_mesh(float(p.x), float(p.z), float(p.r), float(p.get("y", y)))
		var m := ShaderMaterial.new()
		m.shader = sh
		mi.material_override = m
		mi.position = Vector3(p.x, Game.height(p.x, p.z) + 0.25, p.z)
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

func _pool_mesh(cx: float, cz: float, r: float, top: float) -> ArrayMesh:
	var space := get_world_3d().direct_space_state
	var n := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_y := Game.height(cx, cz) + 0.25
	var ys := {}
	for i in n + 1:
		for j in n + 1:
			var u := float(i) / n
			var v := float(j) / n
			var x := (u - 0.5) * 2.0 * r
			var z := (v - 0.5) * 2.0 * r
			var gy := Game.height(cx + x, cz + z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(cx + x, maxf(top, gy) + 4.0, cz + z), Vector3(cx + x, gy - 2.0, cz + z), 1))
			if not hit.is_empty():
				gy = maxf(gy, hit.position.y)
			ys[Vector2i(i, j)] = gy + 0.05 - base_y
	for i in n:
		for j in n:
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for k in t:
					var c: Vector2i = q[k]
					var u := float(c.x) / n
					var v := float(c.y) / n
					st.set_uv(Vector2(u, v))
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3((u - 0.5) * 2.0 * r, ys[c], (v - 0.5) * 2.0 * r))
	return st.commit()

func _lamps() -> void:
	for l in Game.region.lamps:
		var o := OmniLight3D.new()
		o.light_color = Color.hex(int(l.c) << 8 | 0xff)
		o.light_energy = clampf(float(l.i) * 0.35, 0.2, 3.0)
		o.omni_range = float(l.d) if float(l.d) > 0.0 else 10.0
		o.position = Vector3(l.x, l.y, l.z)
		o.distance_fade_enabled = true
		o.distance_fade_begin = [22.0, 50.0, 95.0][clampi(lamp_detail, 0, 2)]
		o.distance_fade_length = 15.0
		add_child(o)
		lamp_nodes.append(o)

# one grass tuft: seven thin blades leaning out from the centre (chunks scatter them)
func _grass_mesh() -> Mesh:
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
	return blade

# ---------------------------------------------------------------- navigation: a 180 m square around the player, rebaked
# on a worker thread when the player has moved 60 m. The source is built directly from the heightfield and the
# collider boxes inside the square, so baking never walks the scene tree.
var nav_baking: NavigationMesh = null

func _bake_nav() -> void:
	if nav_busy or player == null:
		return
	var c: Vector3 = player.global_position
	if Vector2(c.x - nav_center.x, c.z - nav_center.z).length() < 60.0:
		return
	nav_busy = true
	nav_center = c
	if nav_region == null:
		nav_region = NavigationRegion3D.new()
		add_child(nav_region)
	var nm := NavigationMesh.new()
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 42.0
	var R := 90.0
	nm.filter_baking_aabb = AABB(Vector3(c.x - R, -200, c.z - R), Vector3(R * 2, 400, R * 2))
	var src := NavigationMeshSourceGeometryData3D.new()
	var f := PackedVector3Array()
	var step := 2.0
	var x := c.x - R
	while x < c.x + R:
		var z := c.z - R
		while z < c.z + R:
			var a := Vector3(x, Game.height(x, z), z)
			var b := Vector3(x + step, Game.height(x + step, z), z)
			var d := Vector3(x, Game.height(x, z + step), z + step)
			var e := Vector3(x + step, Game.height(x + step, z + step), z + step)
			f.append_array([a, b, d, b, e, d])
			z += step
		x += step
	src.add_faces(f, Transform3D.IDENTITY)
	for s in Game.region.solids:
		if s[1] < c.x - R or s[0] > c.x + R or s[3] < c.z - R or s[2] > c.z + R:
			continue
		src.add_faces(_box_faces(Vector3(s[0], s[4], s[2]), Vector3(s[1], s[5], s[3])), Transform3D.IDENTITY)
	nav_baking = nm
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _nav_done.bind(nm))

# the twelve triangles of an axis-aligned box, for the navigation baker (no render mesh to read back)
static func _box_faces(a: Vector3, b: Vector3) -> PackedVector3Array:
	var v := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var out := PackedVector3Array()
	# wound like the terrain's faces: the top is a floor, the bottom is not
	for q in [[3, 2, 1, 0], [4, 5, 6, 7], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		out.append_array([v[q[0]], v[q[1]], v[q[2]], v[q[0]], v[q[2]], v[q[3]]])
	return out

func _nav_done(nm: NavigationMesh) -> void:
	nav_baking = null
	if not is_inside_tree():
		return
	nav_region.navigation_mesh = nm
	Game.nav_ready = true
	nav_busy = false

# a bake still running on a worker thread must finish before the scene goes (Load reloads it; quitting frees it)
func _exit_tree() -> void:
	set_radio(false)
	var n := 0
	while nav_baking != null and NavigationServer3D.is_baking_navigation_mesh(nav_baking) and n < 500:
		OS.delay_msec(10)
		n += 1

# ---------------------------------------------------------------- interaction
func _best_target() -> Dictionary:
	var npc_dot := 0.0
	var pp: Vector3 = player.global_position
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var best := {}
	var bd := 3.6
	for n in npcs:
		# someone knocked down can't talk until they're back on their feet
		if float(n.down) > 0.0 or n.hostile:
			continue
		var to: Vector3 = n.global_position - pp
		to.y = 0
		var d := to.length()
		if d < 3.2 and (d < 1.2 or fwd.dot(to / d) > 0.5) and d < bd:
			bd = d
			best = {"k": "npc", "o": n, "label": "Talk: " + String(n.display_name)}
			# behind someone, sneaking: their pockets instead of their conversation
			if pockets.can_pick(n, player):
				best = {"k": "pocket", "o": n, "label": "Pickpocket: " + String(n.display_name)}
			npc_dot = fwd.dot(to / d) if d > 0.01 else 1.0
	for e in enemies:
		var d: float = e.global_position.distance_to(pp)
		if d >= bd:
			continue
		if e.dead and not e.looted:
			if d < 2.8:
				bd = d
				best = {"k": "loot", "o": e, "label": "Search the " + String(e.def.get("name", e.type)).to_lower()}
		elif not e.dead and not e.hostile and Game.DIALOGUE.has(String(e.eid)) and d < 3.4:
			bd = d
			best = {"k": "talk", "o": e, "label": "Talk: " + String(Game.DB.enemies.get(e.type, {}).get("n", e.type))}
	var ob := objects.best(pp, fwd, bd)
	# someone standing in a doorway is talked to when you're facing them; turn away from them to use the door
	var door_behind: bool = not ob.is_empty() and ob.o.get("_k") == "point" and String(ob.o.get("id", "")) in ["cellin", "cellout"] and best.get("k") == "npc" and npc_dot > 0.8
	if not ob.is_empty() and not door_behind:
		best = ob
		bd = float(ob.d)
	if best.is_empty() and town and player.seat.is_empty():
		var st := town.seat_near(pp, fwd, 1.9)
		if not st.is_empty():
			best = {"k": "seat", "o": st, "label": "Sit down"}
	if buggy and not buggy.driving:
		var to := buggy.global_position - pp
		to.y = 0
		var d := to.length()
		if d < 3.3 and d < bd + 0.5 and (d < 1.5 or fwd.dot(to / d) > 0.4):
			best = {"k": "buggy", "o": buggy, "label": buggy.label()}
	return best

func interact() -> void:
	if in_dialog() or Game.hp <= 0 or hud.screens.is_open() or hud.casino.is_open() or hud.term.is_open():
		return
	if buggy and buggy.driving:
		buggy.exit()
		return
	var t := _best_target()
	if t.is_empty():
		return
	match t.k:
		"npc": start_dialog(t.o, String(t.o.id))
		"pocket": pockets.open(t.o)
		"talk": start_dialog(t.o, String(t.o.eid))
		"loot":
			var e = t.o
			if e.loot == null:
				e.loot = loot_for(e.type)
			hud.screens.open_loot(String(e.def.get("name", e.type)), e.loot, func(empty): e.looted = empty)
		"obj": objects.use(t.o)
		"buggy": buggy.use()
		"seat": player.sit(t.o)

# what a dead enemy carries: caps, its own drops and rolls on the shared loot tables (data.js LOOT)
func loot_for(type: String) -> Array:
	var def: Dictionary = Game.DB.enemies.get(type, {})
	var got := {}
	if def.has("caps"):
		var c := randi_range(int(def.caps[0]), int(def.caps[1]))
		if c > 0:
			got["caps"] = c
	var add := func(id: String, n: int):
		if n > 0 and (id == "caps" or Game.DB.items.has(id)):
			got[id] = int(got.get(id, 0)) + n
	for dr in def.get("drops", []):
		if randf() < float(dr[3]):
			add.call(String(dr[0]), randi_range(int(dr[1]), int(dr[2])))
	for lt in def.get("loot", []):
		if randf() < float(lt[1]):
			var table: Array = Game.DB.loot.get(lt[0], [])
			if table.size() > 0:
				var e: Array = table[randi() % table.size()]
				add.call(String(e[0]), randi_range(int(e[1]), int(e[2])))
	if Game.perks.has("treasure_hunter"):
		for tname in ["uncommon", "common"]:
			var table: Array = Game.DB.loot.get(tname, [])
			if table.size() > 0:
				var e: Array = table[randi() % table.size()]
				add.call(String(e[0]), randi_range(int(e[1]), int(e[2])))
				break
	var out := []
	for k in got:
		out.append([k, got[k]])
	return out

func in_dialog() -> bool:
	return dialog_npc != null

func start_dialog(n, id: String) -> void:
	if not Game.DIALOGUE.has(id):
		Game.msg((String(n.display_name) if n else "They") + " has nothing to say.")
		return
	# a faction that hates you: its ordinary folk and guards won't give you the time of day (its leaders and the
	# people the story needs still will - they have their reasons)
	if n and n.has_method("faction") and not (id in ESSENTIAL):
		var f: String = n.faction()
		var plain: bool = "folk" in id or String(n.id) in GUARDS or String(n.id) in Game.STORY.get("guards", [])
		if f != "" and plain and Game.rep_of(f) <= -6 and not (Game.STORY.get("factions", {}).get(f, {}).get("leader", "") == n.display_name):
			var ln: String = ["Not a word. Not to you.", "Keep walking.", "We know what you did. Go.", "You're not welcome here."][randi() % 4]
			Game.msg(String(n.display_name) + ": \"" + ln + "\"")
			speak(ln, id)
			return
	dialog_npc = n if n else self
	dialog_id = id
	if n and "talking" in n:
		n.talking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.trigger = false
	Game.touch_move = Vector2.ZERO
	pending_trade = ""
	show_node(Game.dlg_entry(id))

func show_node(id: String) -> void:
	dialog_node = id
	dialog_opts = Game.dlg_options(dialog_id, id)
	if dialog_opts.is_empty():
		dialog_opts = [{"t": "Goodbye.", "o": {}, "off": false}]
	var say := Game.dlg_say(dialog_id, id)
	hud.show_dialogue(Game.subst(String(Game.DIALOGUE[dialog_id].get("name", dialog_id))), say, dialog_opts, choose)
	speak(say, dialog_id)

func choose(i: int) -> void:
	if dialog_npc == null or i >= dialog_opts.size() or dialog_opts[i].get("off", false):
		return
	var o: Dictionary = dialog_opts[i].o
	var at := dialog_id
	Sfx.play("k_click", -8.0)
	if o.has("act"):
		Game.vm.call_value(o.act, [Game.G])
		Game.check_quests()
	if pending_trade != "":
		var v := pending_trade
		pending_trade = ""
		end_dialog()
		hud.screens.open_trade(v)
		return
	if not pending_casino.is_empty():
		var cz := pending_casino
		pending_casino = []
		end_dialog()
		hud.casino.open(String(cz[0]), int(cz[1]))
		return
	if dialog_npc == null or dialog_id != at or hud.screens.is_open():
		if dialog_npc != null:
			end_dialog()
		return
	var go = o.get("go")
	if go != null and Game.DIALOGUE[dialog_id].nodes.has(String(go)):
		show_node(String(go))
	else:
		end_dialog()

func end_dialog() -> void:
	if dialog_npc and dialog_npc != self and "talking" in dialog_npc:
		dialog_npc.talking = false
	dialog_npc = null
	hud.hide_dialogue()
	stop_voice()

# the original speaks NPC lines with the device's voice; Godot can use the same text-to-speech
# ---------------------------------------------------------------- the radio
# a quest that ends with a broadcast (RADIO in the original) plays it on your wrist unit; the Pip RADIO tab keeps
# every one you've heard and can tune into Meridian Free Radio
const DJ := ["This is Meridian Free Radio, broadcasting from somewhere with a roof. Mostly a roof.",
	"Weather for the valley: dust, then more dust, with a chance of something green after dark. Stay under cover.",
	"A word to the caravans out of Saltreach: the Spur road is watched again. Travel in daylight. Travel in numbers.",
	"Dustwell says the well water tastes better this week. Dustwell says that every week.",
	"If you hear clicking and you aren't near a pool, that's your counter. Find Rad Flush. Find it soon.",
	"To whoever keeps leaving canned meat at the relay tower: thank you. To whoever keeps eating it: I know who you are.",
	"Reminder that the old reactor still hums. Do not go and listen to it. It is not singing to you.",
	"Night coming on. Lights off, doors barred, and if something knocks twice, don't answer."]
var radio_on := false
var radio_t := 6.0
var radio_loop: AudioStreamPlayer

# Meridian Free Radio's news desk: a line for each thing in the valley you've had a hand in, newest first
const NEWS := [
	["q:still_waters", "News from the north: Stillwater says the perch are back at the inlet. Somebody went down into the Glass Bowl and came back up. Drink up, valley."],
	["q:the_spire", "Word from Old Meridian: Tobiah Fenn is out of the Spire and back at the Garage. The Duchess is reported to be furious, or possibly fine. Hard to tell with her."],
	["q:children_of_glass", "The pilgrims on the Glass Bowl's rim have had a visitor. Whatever was said, the lanterns aren't lit the way they were."],
	["q:meridian", "The Meridian core's been decided. Depending who you ask, that's the best or the worst news this valley's had in seventy years. I'm asking everybody."],
	["q:council", "Five hands, one lever, and somebody finally pulled it. Sheriff Voss is still talking to everyone, which is more than most sheriffs do."],
	["q:bad_water", "Doc Halloran says he's traced the green in Dustwell's wells. If you've been drinking it, stop. If you haven't, smug is not a good look."],
	["q:signal", "That cold-start command through the relay? Somebody's following the trail. Our sources at the Burned Chapel are being very quiet about it."],
	["q:dead_air", "KDST is back on the air, folks. Lark's playing waltzes on the old transmitter. Tune across if you like your music with fewer guitars."],
	["q:toll_road", "The Underpass toll is down. You can walk under the highway without paying a man in a crown for the privilege. Progress."],
	["q:black_box", "The flight recorder from Hangar 2 is out of the airfield. Wick says the last thing on it is a pilot humming. Make of that what you like."],
	["q:light_fingers", "Lantern Row reports a run of very polite pickpocketing. Lock your pockets, everyone. Yes, pockets can lock now. No, I don't know how."],
	["q:collectors_safe", "Somebody cracked the counting house safe in Saltreach and left a lantern drawn on the door. That's the Quiet Hands' mark, if you believe in them."],
	["q:old_debts", "Silas Crow, late of the Quiet Hands, is no longer a problem for anyone. The Row is quieter. The Hands are louder. Funny how that works."],
	["q:lights_over_ridge", "Strange lights over the eastern ridge, and now a hole in the ground where they came down. Orrin Pike says it's visitors. Orrin Pike says a lot of things."],
	["q:not_alone", "Rumour from the east: something in the crash scrub is walking on two legs and it isn't a man. Folks, if it waves, be polite."],
	["q:signal_home", "A light went up from the KDST mast last night, straight up, and didn't come down. Lark swears she didn't do it. I believe her. Mostly."],
	["q:cracked_housing", "Haven 12's got the regulator home, and the regulator's got a crack in it. The vault folk are camped at their own front door. Spare a thought."],
	["q:calibration_rig", "Kestrel Airfield's old calibration rig has been hauled out of the tower. If you saw someone carrying a filing cabinet with dials on it across the flats, now you know."],
	["q:seals_and_gaskets", "Stillwater is making gaskets for a vault. Fish glue, apparently. The future is strange and smells of the lake."],
	["q:havens_doubt", "Inside Haven 12 there's been shouting. Some want out for good, some want the door shut forever. The Overseer is still the Overseer. Just."],
	["q:last_nine_days", "Haven 12's water recycler is running. Four hundred people won't die of thirst this year. Somebody walked a very long way for that."],
	["f:silo_launched", "Bulletin. Silo 9 is empty. Something went up out of the Glass Bowl on a tail of fire and burst over the old test range. If you're in the north, stay under a roof, cover your water, and say something nice to someone."],
	["f:silo_buried", "Silo 9 is gone. Folded into the ground like a tent with the pole pulled out. The Glass Bowl's floor is a mess of concrete and dust, and the Children say the Sleeper went back to sleep for good."],
	["q:ash_wind", "Stillwater rode out the ash. Grey snow for a day, and the lake kept clean behind its sluice. Nell Okafor says the drinks are on the harbour. One drink. Each."],
	["f:kess_raid", "Kess's Gantry boys hit the camp at Haven's door and came off worse. Sheriff Voss sends regards. Kess sends nothing, which is his way of saying ouch."],
]

func radio_news() -> Array:
	var out: Array = []
	for n in NEWS:
		var key: String = n[0]
		var ok := Game.is_done(key.substr(2)) if key.begins_with("q:") else bool(Game.flags.get(key.substr(2), false))
		if ok:
			out.push_front(String(n[1]))
	return out

func broadcast(k: String) -> void:
	var r: Dictionary = Game.L.get("radio", {}).get(k, {})
	if r.is_empty():
		return
	if not (Game.flags.get("heard") is Array):
		Game.flags["heard"] = []
	if not Game.flags.heard.has(k):
		Game.flags.heard.append(k)
	Sfx.play("o_quest")
	hud.screens.open_term(String(r.h), String(r.t))
	speak(String(r.t), String(r.get("who", "overseer")))

# Two stations. Meridian Free Radio from the start (blues and frontier tunes between the DJ's notices), and KDST
# Classics once Lark gets the old transmitter working (Dead Air): waltzes, and Lark between them. Music comes from
# filmmusic.io (Kevin MacLeod, Alexander Nakarada; attribution in CREDITS.md), played through a band-limited
# "radio" bus; the DJs' lines are recorded voices like everyone else's.
const DJ2 := ["That was a song. This is me. Between us we've got a radio station.",
	"Saltreach reports the salt is salty. More at eleven.",
	"Somebody at Tin Row is selling 'genuine pre-war water'. It's water. It's from a puddle. It's not pre-war.",
	"Kess's people are hiring again. They pay in caps and bruises. Mostly bruises.",
	"Lost: one goat, answers to Mayor. If found, do not elect.",
	"If the wind's from the reactor, close the shutters. If the wind's from the gulch, close them twice.",
	"To the Lamplighters out east: we see your lanterns. We'd see them better if you'd come down and buy a round.",
	"Hound season, friends. If it's got more teeth than you, walk the other way.",
	"Brannock says if your gun jams, it's your fault. Brannock says that about the weather, too.",
	"A reminder from Sheriff Voss: the well is for water. Not for wishes, not for coins, and not for Duggan.",
	"News from the Silver Spur: the house always wins. That's not news. That's a law of nature.",
	"Here's one for everybody walking the valley tonight. Keep your canteen full and your boots dry."]
const KDST := ["KDST, back on the air after eleven silent years. This is Lark. The sea is still out there. I checked the map.",
	"Here's a waltz. Somebody danced to this once in a room with a chandelier. Picture that. Go on.",
	"KDST Classics. Every record in this booth is older than your grandparents and twice as fussy.",
	"If you're out on the flats tonight, I'm playing this one for you. Mind the scuttlers.",
	"The counting woman's frequency is quiet tonight. I don't know if that's good. Here's a waltz anyway.",
	"Request line's open. It's a tin can on a string. Pull twice.",
	"That was the grand old dark waltz. Lights low, boots off. KDST.",
	"Somebody asked me why I play old music. Because it remembers being played to people who weren't scared."]
const STATIONS := [
	{"id": "mfr", "n": "Meridian Free Radio", "dj": "radio", "tracks": [["apocalypse_blues", "Apocalypse Blues", "Alexander Nakarada"],
		["sunset_fields", "Sunset Fields", "Alexander Nakarada"], ["horsemen_approach", "Horsemen Approach", "Alexander Nakarada, Kevin MacLeod"],
		["tavern_brawl", "Tavern Brawl", "Alexander Nakarada, Kevin MacLeod"], ["teller_of_the_tales", "Teller of the Tales", "Kevin MacLeod"],
		["northern_path", "The Northern Path", "Alexander Nakarada"]]},
	{"id": "kdst", "n": "KDST Classics", "dj": "lark", "req": "dead_air", "tracks": [["devonshire_waltz", "Devonshire Waltz Allegretto", "Kevin MacLeod"],
		["grand_dark_waltz", "Grand Dark Waltz Allegro", "Kevin MacLeod"], ["adeste_fideles_waltz", "Adeste Fideles Waltz", "Kevin MacLeod"],
		["waltz_primordial", "Waltz Primordial", "Kevin MacLeod, Alexander Nakarada"], ["suonatore_di_liuto", "Suonatore di Liuto", "Kevin MacLeod"]]},
]
var station := 0
var radio_music: AudioStreamPlayer
var radio_voice: AudioStreamPlayer
var radio_state := ""
var radio_order: Array = []
var now_playing := ""

func station_open(i: int) -> bool:
	var st: Dictionary = STATIONS[i]
	return not st.has("req") or Game.is_done(String(st.req)) or Game.dev.get("god", false)

func _radio_bus() -> String:
	if AudioServer.get_bus_index("Radio") < 0:
		AudioServer.add_bus()
		var b := AudioServer.bus_count - 1
		AudioServer.set_bus_name(b, "Radio")
		AudioServer.set_bus_send(b, "Master")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 180.0
		AudioServer.add_bus_effect(b, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 5200.0
		AudioServer.add_bus_effect(b, lp)
		var ds := AudioEffectDistortion.new()
		ds.mode = AudioEffectDistortion.MODE_LOFI
		ds.drive = 0.12
		ds.post_gain = -2.0
		AudioServer.add_bus_effect(b, ds)
		Settings.apply_audio()
	return "Radio"

func set_radio(on: bool) -> void:
	radio_on = on
	if on:
		if radio_music == null:
			radio_music = AudioStreamPlayer.new()
			radio_music.bus = _radio_bus()
			radio_music.process_mode = Node.PROCESS_MODE_ALWAYS
			radio_music.volume_db = -6.0
			add_child(radio_music)
			radio_voice = AudioStreamPlayer.new()
			radio_voice.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(radio_voice)
		if radio_loop == null:
			radio_loop = Sfx.loop("static", -34.0)
		radio_order = []
		_radio_next(true)
	else:
		if radio_loop:
			radio_loop.queue_free()
			radio_loop = null
		if radio_music:
			radio_music.stop()
			radio_voice.stop()
		radio_state = ""
		now_playing = ""
		DisplayServer.tts_stop()

func tune(i: int) -> void:
	if i < 0 or i >= STATIONS.size() or not station_open(i):
		return
	station = i
	Sfx.play("static", -14.0)
	if radio_on:
		radio_order = []
		_radio_next(true)
	else:
		set_radio(true)

func radio_skip() -> void:
	if radio_on:
		_radio_next(false)

func _radio_next(talk: bool) -> void:
	var st: Dictionary = STATIONS[station]
	radio_music.stop()
	radio_voice.stop()
	if talk:
		var lines: Array = (DJ + DJ2) if st.id == "mfr" else KDST.duplicate()
		if st.id == "mfr":
			for k in Game.flags.get("heard", []):
				var r: Dictionary = Game.L.radio.get(k, {})
				if r.has("t"):
					var paras: Array = Array(String(r.t).split("\n\n")).filter(func(x): return not String(x).strip_edges().begins_with(">"))
					if not paras.is_empty():
						lines.append(String(paras[-1]))
		# the news (build 17): what you've done gets talked about, and the newest gets talked about most
		if st.id == "mfr":
			var news := radio_news()
			if not news.is_empty() and randf() < 0.6:
				lines = news.slice(0, 3)
		var line: String = lines[randi() % lines.size()]
		radio_state = "talk"
		radio_t = 1.0
		var p := voice_path(line, String(st.dj))
		if ResourceLoader.exists(p):
			radio_voice.stream = load(p)
			radio_voice.play()
		else:
			speak(line, String(st.dj))
		Game.msg(("LARK: " if st.id == "kdst" else "RADIO: ") + line)
		return
	if radio_order.is_empty():
		radio_order = range(st.tracks.size())
		radio_order.shuffle()
	var t: Array = st.tracks[radio_order.pop_back()]
	var path := "res://music/%s.ogg" % t[0]
	if not ResourceLoader.exists(path):
		radio_state = "talk"
		radio_t = 3.0
		return
	radio_music.stream = load(path)
	radio_music.play()
	radio_state = "music"
	now_playing = "%s — %s" % [t[1], t[2]]
	Game.msg("♪ %s  ·  %s" % [now_playing, String(st.n)])

func radio_tick(dt: float) -> void:
	if Game.flags.has("radio") and not hud.screens.is_open() and not in_dialog():
		var k := String(Game.flags.radio)
		Game.flags.erase("radio")
		if radio_music:
			radio_music.stop()
			radio_voice.stop()
			radio_state = "talk"
			radio_t = 18.0
		broadcast(k)
	if not radio_on or radio_music == null:
		return
	# quieter under conversations and other voices
	var want := -18.0 if in_dialog() or (voice_player and voice_player.playing) else -6.0
	radio_music.volume_db = lerpf(radio_music.volume_db, want, minf(1.0, dt * 3.0))
	match radio_state:
		"music":
			if not radio_music.playing:
				_radio_next(randf() < 0.75)
		"talk":
			if not radio_voice.playing and not DisplayServer.tts_is_speaking():
				radio_t -= dt
				if radio_t <= 0.0:
					_radio_next(false)

# Spoken lines: every scripted line has a recorded voice (voice/<who>/<key>.ogg, made by tools/voice with Piper and
# its LibriTTS voices, one speaker per character); anything else falls back to the device's text-to-speech.
var voice_player: AudioStreamPlayer
var _voice_re: RegEx

static func voice_key(text: String) -> String:
	var t := text
	if Game.player_name != "" and Game.player_name.length() > 1:
		t = t.replace(Game.player_name, "{name}")
	if Game.main and Game.main._voice_re == null:
		Game.main._voice_re = RegEx.create_from_string("[^a-z0-9]")
	var re: RegEx = Game.main._voice_re if Game.main else RegEx.create_from_string("[^a-z0-9]")
	return re.sub(t.to_lower(), "", true).md5_text().substr(0, 16)

func voice_path(text: String, who: String) -> String:
	return "res://voice/%s/%s.ogg" % [who, voice_key(text)]

func speak(text: String, who: String) -> void:
	if voice_player == null:
		voice_player = AudioStreamPlayer.new()
		voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
		voice_player.volume_db = 1.0
		add_child(voice_player)
	var p := voice_path(text, who)
	if ResourceLoader.exists(p):
		DisplayServer.tts_stop()
		voice_player.stop()
		voice_player.stream = load(p)
		voice_player.play()
		return
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	voice_player.stop()
	DisplayServer.tts_stop()
	var v: String = voices[hash(who) % voices.size()]
	var pitch := 0.9 + float(hash(who + "p") % 30) / 100.0
	DisplayServer.tts_speak(text, v, 80, pitch, 1.05)

func stop_voice() -> void:
	if voice_player:
		voice_player.stop()
	DisplayServer.tts_stop()

func in_region(x: float, z: float) -> bool:
	return x > Game.x0 + 4.0 and z > Game.z0 + 4.0 and x < Game.x0 + Game.hw - 5.0 and z < Game.z0 + Game.hd - 5.0

# travel to a discovered place: the town fades out, the world around the destination is built, you arrive
func fast_travel(k: String) -> void:
	if in_dialog():
		return
	for e in enemies:
		if e.state == "chase" and not e.dead:
			Game.msg("You can't travel with enemies nearby.")
			return
	var L: Dictionary = Game.DB.locs[k]
	var p := Vector3(float(L.x), 0, float(L.z) + float(L.get("r", 20)) * 0.6)
	for t in 24:
		var a := t * 0.7
		var q := Vector3(float(L.x) + cos(a) * (6.0 + t), 0, float(L.z) + sin(a) * (6.0 + t))
		q.y = Game.height(q.x, q.z)
		var hit := get_world_3d().direct_space_state.intersect_shape(_probe(q))
		if hit.is_empty():
			p = q
			break
	p.y = Game.height(p.x, p.z) + 0.3
	if LoadScreen.it().begin("Travelling to " + String(L.name)):
		LoadScreen.it().progress(0.5)
		await get_tree().process_frame
		await get_tree().process_frame
	player.global_position = p
	player.velocity = Vector3.ZERO
	chunks.load_now(p)
	Game.msg("You travel to " + String(L.name) + ".")

func _probe(at: Vector3) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.4
	c.height = 1.7
	q.shape = c
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	q.collision_mask = 1
	return q

func npc_pos(id: String) -> Variant:
	for n in npcs:
		if n.id == id:
			return n.global_position
	for d in Game.region.npcs:
		if d.id == id:
			return Vector3(d.x, Game.height(d.x, d.z), d.z)
	return null

func quest_target() -> Variant:
	return Game.quest_target()

# the Silver Spur's hall: lounge music and a room full of people, fading in as you go down into it
var spur_music: AudioStreamPlayer
var spur_crowd: AudioStreamPlayer
var spur_mix := 0.0
func _spur_ambience(d: float) -> void:
	var pp: Vector3 = player.global_position
	var inside := Game.area == "world" and pp.y < 0.5 and pp.x > -2.0 and pp.x < 26.0 and pp.z > 55.0 and pp.z < 77.0
	spur_mix = move_toward(spur_mix, 1.0 if inside else 0.0, d * 0.7)
	if spur_mix <= 0.001:
		if spur_music and spur_music.playing:
			spur_music.stop()
			spur_crowd.stop()
		return
	if spur_music == null:
		spur_music = AudioStreamPlayer.new()
		spur_crowd = AudioStreamPlayer.new()
		for pl in [spur_music, spur_crowd]:
			pl.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(pl)
		var m: AudioStream = Sfx.stream("x_lounge")
		var c: AudioStream = Sfx.stream("o_crowd")
		if m is AudioStreamOggVorbis:
			m.loop = true
		if c is AudioStreamOggVorbis:
			c.loop = true
		spur_music.stream = m
		spur_crowd.stream = c
	if not spur_music.playing and spur_music.stream:
		spur_music.play()
	if not spur_crowd.playing and spur_crowd.stream:
		spur_crowd.play()
	var duck := 0.35 if radio_on else 1.0
	spur_music.volume_db = linear_to_db(maxf(0.0001, spur_mix * 0.32 * duck))
	spur_crowd.volume_db = linear_to_db(maxf(0.0001, spur_mix * 0.22))

func _process(d: float) -> void:
	if player == null or hud == null:
		return
	_spur_ambience(d)
	_forgive_tick(d)
	_bake_nav()
	disc_t -= d
	if disc_t <= 0.0:
		disc_t = 1.0
		var pp: Vector3 = player.global_position
		for k in Game.DB.locs:
			var L: Dictionary = Game.DB.locs[k]
			if not Game.discovered.has(k) and Vector2(pp.x - float(L.x), pp.z - float(L.z)).length() < float(L.get("r", 30)):
				Game.discover(k)
		# autosave every three minutes
		auto_t -= 1.0
		if auto_t <= 0.0 and not in_dialog() and Game.hp > 0:
			auto_t = 180.0
			Game.save_game("auto")
	var t := _best_target()
	hud.set_prompt("" if t.is_empty() else "[USE] " + String(t.label))
	# whatever hostile is under the crosshair gets its name and health shown
	look_t -= d
	if look_t <= 0.0 and player.cam:
		look_t = 0.15
		var cf: Vector3 = player.cam.global_position
		var q := PhysicsRayQueryParameters3D.create(cf, cf - player.cam.global_basis.z * 80.0, 1 | 2)
		q.exclude = [player.get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if h and h.collider and h.collider.get("hostile") == true and h.collider.get("hp_max") != null and not h.collider.dead:
			hud.track_target(h.collider, maxf(hud.tgt_t, 0.6))
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
var _hit_snd := 0
var _grunt_snd := 0
func on_player_hurt(d: float) -> void:
	hud.flash_hurt(0.12 + d * 0.012)
	player.hurt_fx(d)
	# build 22: the thump of the hit, and now and then a grunt (never a stream of them: radiation and fire hurt every frame)
	var now := Time.get_ticks_msec()
	if d >= 1.5 and now - _hit_snd > 220:
		_hit_snd = now
		Sfx.play("p_hit%d" % (1 + randi() % 4), -9.0 + minf(d, 25.0) * 0.25, randf_range(0.9, 1.08))
	if d >= 1.5 and now - _grunt_snd > 850 and (d >= 7.0 or randf() < 0.55):
		_grunt_snd = now
		Sfx.play("p_hurt%d" % (1 + randi() % 5), -5.0, randf_range(0.94, 1.06))
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
	Game.reset()
	get_tree().reload_current_scene()

# reload the scene but keep Game's state (used by Load)
func restart_keep() -> void:
	Game.nav_ready = false
	get_tree().paused = false
	Game.paused = false
	# the loading screen goes up and gets drawn before the frame freezes on the rebuild
	if not LoadScreen.quiet():
		if not LoadScreen.it().shown:
			LoadScreen.it().begin("Loading")
		LoadScreen.it().building()
		await get_tree().process_frame
		await get_tree().process_frame
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

func impact(pos: Vector3, normal: Vector3, kind := "") -> void:
	# build 23: by what was hit (dirt, stone, wood or metal), with a hole left behind
	if kind == "":
		kind = "dirt" if Game.area == "world" and absf(pos.y - Game.height(pos.x, pos.z)) < 0.25 else "stone"
	GunFX.impact(self, pos, normal, kind)

func blood(pos: Vector3, dir: Vector3) -> void:
	_puff(pos, -dir, Color(0.45, 0.02, 0.02, 0.95), 12, 2.5)
	Sfx.play_at(["x_flesh0", "x_flesh1"][randi() % 2], pos, -4.0)

# something is hunting you (action points come back slower)
func in_combat() -> bool:
	for e in enemies:
		if not e.dead and e.hostile and e.state == "chase":
			return true
	return false

# a word that floats up from a spot and fades (FOCUS misses)
func float_text(at: Vector3, t: String) -> void:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48
	l.modulate = Color(1.0, 0.9, 0.6)
	l.outline_size = 8
	add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", at + Vector3.UP * 0.8, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

func tracer(a: Vector3, b: Vector3, col: Color = Color(1.0, 0.85, 0.5, 0.8)) -> void:
	# build 23: a streak that travels, not a line drawn whole; beams stay lines (and get a streak too)
	GunFX.tracer(self, a, b, col, 0.02 if col.b > col.r else 0.01)
	if col.b <= col.r:
		return
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)
