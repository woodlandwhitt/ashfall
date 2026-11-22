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
var dialog_id := ""
var dialog_node := ""
var pending_trade := ""
var objects: WorldObjects
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

func _ready() -> void:
	Game.main = self
	var R: Dictionary = Game.region
	_environment()
	_terrain()
	if vault_dress:
		chunks.on_built = vault_dress.brighten
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
	objects = WorldObjects.new()
	add_child(objects)
	objects.setup(self)
	events = RoadEvents.new()
	add_child(events)
	events.setup(self)
	forge = Forge.new()
	add_child(forge)
	forge.setup.call_deferred(self)
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
	chunks.load_now(start_pos)
	if Game.area != "khole":
		_restore_party()
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self)
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
			if live_npc.has(i) or Game.flags.has("npcDead_" + String(Game.region.npcs[i].id)):
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
			if not ResourceLoader.exists(Game.char_path("enemy_" + d.type + ".glb")) or not Game.region.etypes.has(d.type):
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
				dismiss(p.id, true)
				Game.msg(String(p.comp.n) + " heads home. You can only bring one person along.")
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
	n.join(c, st)
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

func provoke(n, dmg: float, dir: Vector3, chain := false) -> void:
	if n.hostile or n.follow or String(n.id) in CHILDREN or not n.visible:
		return
	if dialog_npc == n:
		end_dialog()
	n.hostile = true
	n.visible = false
	n.collision_layer = 0
	n.set_physics_process(false)
	var guard: bool = String(n.id) in GUARDS
	var type := "townguard" if guard else "townsfolk"
	var src: Dictionary = Game.DB.enemies.get(type, {})
	var td := {"hp": src.get("hp", 65), "name": n.display_name, "dmg": src.get("dmg", 6), "speed": src.get("spd", 4.0), "range": src.get("range", 2.0),
		"xp": src.get("xp", 10), "ranged": src.get("ranged", false), "quad": false, "scale": 1}
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
	if not (String(n.id) in GUARDS):
		Game.add_karma(-10, "Murdered " + String(n.display_name))
	Game.msg(String(n.display_name) + " is dead.")
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
	if args.has("forgetest"):
		await _forge_test()
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
		hud.toggle_pip()
		hud.pip.show_tab(String(args.pip))
	if args.has("tod"):
		Game.time = float(args.tod)
	if args.has("wx") and atmos:
		atmos.set_weather(String(args.wx), true)
		atmos.cur = Atmos.WX[String(args.wx)].duplicate()
	if args.has("weapon"):
		Game.give(String(args.weapon), 1)
		Game.weapon = String(args.weapon)
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
	if args.has("shot"):
		for i in int(args.get("frames", "40")):
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
	for l in out:
		print("TEST ", l)
	get_tree().quit()

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
		out.append("terminal open %s '%s'" % [hud.screens.mode, hud.screens.term_text.substr(0, 50)])
		hud.screens.close()
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
		env.background_color = Color(0.02, 0.018, 0.015)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.95, 0.87, 0.75)
		env.ambient_light_energy = 0.95
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.fog_enabled = false
		sun.visible = false
		sun.shadow_enabled = false
		var cy := float(Game.L.consts.CELLS.y)
		for C in Game.CELLS:
			var n := 1 if float(C.D2) < 16.0 else 2
			for k in n:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.84, 0.64)
				l.light_energy = 2.3
				l.omni_range = maxf(float(C.W2), float(C.D2) / n) * 0.8
				l.omni_attenuation = 0.8
				l.shadow_enabled = false
				add_child(l)
				var dz := 0.0 if n == 1 else (k - 0.5) * float(C.D2) * 0.5
				l.global_position = Vector3(float(C.ox), cy + 3.2, float(C.oz) + dz)
	elif Game.area == "vault":
		# underground: no sky, no sun, cool strip lights along the corridors
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.025, 0.03)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.74, 0.78)
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.fog_enabled = false
		sun.visible = false
		sun.shadow_enabled = false
		env.ambient_light_energy = 1.5
		env.ambient_light_color = Color(0.78, 0.8, 0.82)
		# metal reflects a soft grey room rather than black
		env.background_color = Color(0.45, 0.47, 0.48)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
		env.glow_intensity = 0.8
		env.glow_bloom = 0.1
		env.tonemap_exposure = 1.05
		vault_dress = VaultDress.new()
		add_child(vault_dress)
		vault_dress.setup(self)

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
	set_quality((quality + 1) % 3)
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
		b.size = Vector3(maxf(0.05, s[1] - s[0]), maxf(0.05, s[5] - s[4]), maxf(0.05, s[3] - s[2]))
		cs.shape = b
		cs.position = Vector3((s[0] + s[1]) * 0.5, (s[4] + s[5]) * 0.5, (s[2] + s[3]) * 0.5)
		bodies[k].add_child(cs)

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
	var pp: Vector3 = player.global_position
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var best := {}
	var bd := 3.6
	for n in npcs:
		var to: Vector3 = n.global_position - pp
		to.y = 0
		var d := to.length()
		if d < 3.2 and (d < 1.2 or fwd.dot(to / d) > 0.5) and d < bd:
			bd = d
			best = {"k": "npc", "o": n, "label": "Talk: " + String(n.display_name)}
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
	if not ob.is_empty():
		best = ob
		bd = float(ob.d)
	if buggy and not buggy.driving:
		var to := buggy.global_position - pp
		to.y = 0
		var d := to.length()
		if d < 3.3 and d < bd + 0.5 and (d < 1.5 or fwd.dot(to / d) > 0.4):
			best = {"k": "buggy", "o": buggy, "label": buggy.label()}
	return best

func interact() -> void:
	if in_dialog() or Game.hp <= 0 or hud.screens.is_open():
		return
	if buggy and buggy.driving:
		buggy.exit()
		return
	var t := _best_target()
	if t.is_empty():
		return
	match t.k:
		"npc": start_dialog(t.o, String(t.o.id))
		"talk": start_dialog(t.o, String(t.o.eid))
		"loot":
			var e = t.o
			if e.loot == null:
				e.loot = loot_for(e.type)
			hud.screens.open_loot(String(e.def.get("name", e.type)), e.loot, func(empty): e.looted = empty)
		"obj": objects.use(t.o)
		"buggy": buggy.use()

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
	speak(String(r.t), "overseer")

func set_radio(on: bool) -> void:
	radio_on = on
	if on and radio_loop == null:
		radio_loop = Sfx.loop("static", -22.0)
		radio_t = 1.5
	elif not on and radio_loop:
		radio_loop.queue_free()
		radio_loop = null
		DisplayServer.tts_stop()

func radio_tick(dt: float) -> void:
	if Game.flags.has("radio") and not hud.screens.is_open() and not in_dialog():
		var k := String(Game.flags.radio)
		Game.flags.erase("radio")
		broadcast(k)
	if radio_on:
		radio_t -= dt
		if radio_t <= 0.0:
			radio_t = randf_range(28.0, 45.0)
			var lines: Array = DJ.duplicate()
			for k in Game.flags.get("heard", []):
				var r: Dictionary = Game.L.radio.get(k, {})
				if r.has("t"):
					lines.append(String(r.t).split("\n\n")[-1])
			var line: String = lines[randi() % lines.size()]
			Game.msg("RADIO: " + line)
			speak(line, "radio")

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

func _process(d: float) -> void:
	if player == null or hud == null:
		return
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
	Game.reset()
	get_tree().reload_current_scene()

# reload the scene but keep Game's state (used by Load)
func restart_keep() -> void:
	Game.nav_ready = false
	get_tree().paused = false
	Game.paused = false
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
