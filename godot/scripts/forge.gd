# Forge mode (in the spirit of Halo's Forge and the Creation Kit): fly about the world and build in it. Walls,
# floors, ramps, stairs, doorways, cover, crates, barrels, lamps and signs; enemy spawn points that come alive when
# you leave Forge; loot containers and items to pick up. Objects snap to a grid, turn, scale and take a finish
# (concrete, steel, rust, wood, Haven teal and more). Everything you build is kept with your save, per area, and a
# layout can be saved to one of three map slots and loaded anywhere.
#
# Touch: FIRE places, USE picks up what you're looking at (to move it), NADE deletes it, RLD turns, SWAP cycles the
# object, FOCUS opens the palette, JUMP / RUN fly up and down. Keyboard: click or F places, E picks up, X deletes,
# R turns, Q / Tab cycles, B opens the palette, Page Up / Page Down raise and lower, + / - scale, Z undoes, F2 exits.
class_name Forge
extends Node3D

const MATS := [["Concrete", Color(0.6, 0.58, 0.54), 0.0, 0.9, "res://data/vault/world/tex/486a0094-ebfb.webp"],
	["Steel", Color(0.62, 0.66, 0.7), 0.75, 0.35, ""], ["Rust", Color(0.8, 0.8, 0.8), 0.3, 0.8, "res://data/vault/world/tex/d91d753e-ac87.webp"],
	["Wood", Color(0.95, 0.9, 0.85), 0.0, 0.8, "res://data/vault/world/tex/be81f7fd-3416.webp"], ["Haven teal", Color(0.2, 0.47, 0.46), 0.35, 0.5, ""],
	["Cream", Color(0.86, 0.81, 0.7), 0.0, 0.7, ""], ["Brick", Color(0.95, 0.92, 0.9), 0.0, 0.85, "res://data/world/tex/b9d5ff70-8b72.webp"], ["Black", Color(0.08, 0.08, 0.09), 0.3, 0.6, ""],
	["Hazard yellow", Color(0.92, 0.72, 0.15), 0.1, 0.6, ""], ["Sand", Color(0.72, 0.62, 0.45), 0.0, 0.95, ""],
	["Roof tile", Color(0.95, 0.92, 0.9), 0.0, 0.8, "res://data/world/tex/e75a405d-997f.webp"], ["Brick red", Color(0.6, 0.25, 0.18), 0.0, 0.85, ""]]
# kind: [name, category, default finish]
const KINDS := {
	"wall": ["Wall 4 m", "BUILD", 0], "wall_low": ["Low wall", "BUILD", 0], "wall_door": ["Doorway", "BUILD", 0], "wall_window": ["Window wall", "BUILD", 0],
	"floor": ["Floor 4x4", "BUILD", 0], "floor_big": ["Floor 8x8", "BUILD", 0], "block": ["Block 2 m", "BUILD", 0], "pillar": ["Pillar", "BUILD", 1],
	"ramp": ["Ramp", "BUILD", 0], "stairs": ["Stairs", "BUILD", 0], "roof": ["Roof slab", "BUILD", 1],
	"crate": ["Crate", "PROPS", 3], "barrel": ["Barrel", "PROPS", 2], "sandbags": ["Sandbags", "PROPS", 9], "fence": ["Fence", "PROPS", 1],
	"table": ["Table", "PROPS", 3], "lamp": ["Lamp post", "PROPS", 7], "light": ["Ceiling light", "PROPS", 1], "sign": ["Sign", "PROPS", 3],
	"loot_common": ["Footlocker", "GAMEPLAY", 4], "loot_rare": ["Weapons crate", "GAMEPLAY", 8], "item_stims": ["Stim Shots", "GAMEPLAY", 0],
	"item_ammo": ["Ammo pile", "GAMEPLAY", 0], "bench": ["Workbench", "GAMEPLAY", 3],
}
var main
var active := false
var objs: Array = []          # {k, p:[x,y,z], r, s, m, n (node)}
var undo: Array = []
var kinds: Array = []
var cur := 0
var mat := -1                 # -1: the object's own finish
var rot := 0.0
var scl := 1.0
var lift := 0.0
var grid := 0.5
var ghost: Node3D
var ghost_mat: StandardMaterial3D
var held = null               # an object picked up to move (its record)
var hud_panel: PanelContainer
var info: Label
var palette: PanelContainer
var spawned := false
var materials := {}
var map_slot := "1"

func setup(m) -> void:
	main = m
	kinds = KINDS.keys()
	for f in Furniture.CAT:
		if Furniture.scene(f):
			kinds.append("f_" + f)
	for et in Game.region.etypes:
		kinds.append("spawn_" + et)
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.4, 1.0, 0.6, 0.38)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.no_depth_test = false
	for d in Game.flags.get("forge_" + Game.area, []):
		_add(d, false)
	_spawn_all()

func _key() -> String:
	return "forge_" + Game.area

func _save() -> void:
	Game.flags[_key()] = objs.map(func(o): return {"k": o.k, "p": o.p, "r": o.r, "s": o.s, "m": o.m, "id": o.id})

# ---------------------------------------------------------------- materials and meshes
func _material(i: int) -> StandardMaterial3D:
	if materials.has(i):
		return materials[i]
	var M: Array = MATS[clampi(i, 0, MATS.size() - 1)]
	var sm := StandardMaterial3D.new()
	sm.albedo_color = M[1]
	sm.metallic = M[2]
	sm.roughness = M[3]
	if M[4] != "" and ResourceLoader.exists(M[4]):
		sm.albedo_texture = load(M[4])
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		sm.uv1_scale = Vector3(0.35, 0.35, 0.35)
	materials[i] = sm
	return sm

func _box(root: Node3D, size: Vector3, at: Vector3, m: Material, solid := true, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation.x = rot_x
	root.add_child(mi)
	if solid:
		_collide(root, BoxShape3D.new(), size, at, rot_x)

func _cyl(root: Node3D, r: float, h: float, at: Vector3, m: Material, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	root.add_child(mi)
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = r
		cs.height = h
		_collide(root, cs, Vector3.ZERO, at, 0.0)

func _collide(root: Node3D, sh: Shape3D, size: Vector3, at: Vector3, rot_x: float) -> void:
	var body: StaticBody3D = root.get_node_or_null("Body")
	if body == null:
		body = StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		root.add_child(body)
	if sh is BoxShape3D:
		(sh as BoxShape3D).size = size
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = at
	cs.rotation.x = rot_x
	body.add_child(cs)

# build one object, origin at the bottom centre, facing +Z
func build(k: String, mi: int) -> Node3D:
	if k.begins_with("f_"):
		return Furniture.make(k.substr(2), true, 1)
	var root := Node3D.new()
	var m := _material(mi if mi >= 0 else int(KINDS.get(k, ["", "", 0])[2]))
	match k:
		"wall": _box(root, Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), m)
		"wall_low": _box(root, Vector3(4, 1.2, 0.3), Vector3(0, 0.6, 0), m)
		"wall_door":
			_box(root, Vector3(1.4, 3, 0.3), Vector3(-1.3, 1.5, 0), m)
			_box(root, Vector3(1.4, 3, 0.3), Vector3(1.3, 1.5, 0), m)
			_box(root, Vector3(1.2, 0.6, 0.3), Vector3(0, 2.7, 0), m)
		"wall_window":
			_box(root, Vector3(4, 1.0, 0.3), Vector3(0, 0.5, 0), m)
			_box(root, Vector3(4, 0.8, 0.3), Vector3(0, 2.6, 0), m)
			_box(root, Vector3(1.2, 1.2, 0.3), Vector3(-1.4, 1.6, 0), m)
			_box(root, Vector3(1.2, 1.2, 0.3), Vector3(1.4, 1.6, 0), m)
		"floor": _box(root, Vector3(4, 0.2, 4), Vector3(0, 0.1, 0), m)
		"floor_big": _box(root, Vector3(8, 0.2, 8), Vector3(0, 0.1, 0), m)
		"roof": _box(root, Vector3(4, 0.25, 4), Vector3(0, 3.0, 0), m)
		"block": _box(root, Vector3(2, 2, 2), Vector3(0, 1, 0), m)
		"pillar": _box(root, Vector3(0.6, 3, 0.6), Vector3(0, 1.5, 0), m)
		"ramp":
			var a := atan2(2.0, 4.0)
			_box(root, Vector3(3, 0.2, sqrt(20.0)), Vector3(0, 1.0, 0), m, true, a)
		"stairs":
			for i in 10:
				_box(root, Vector3(2, 0.3 * (i + 1), 0.4), Vector3(0, 0.15 * (i + 1), 1.8 - i * 0.4), m)
		"crate":
			_box(root, Vector3(1, 1, 1), Vector3(0, 0.5, 0), m)
		"barrel": _cyl(root, 0.36, 0.95, Vector3(0, 0.475, 0), m)
		"sandbags":
			for i in 3:
				_box(root, Vector3(2.0 - i * 0.3, 0.3, 0.7 - i * 0.08), Vector3(0, 0.15 + i * 0.3, 0), m, i == 0)
			_collide(root, BoxShape3D.new(), Vector3(2, 0.9, 0.7), Vector3(0, 0.45, 0), 0.0)
		"fence":
			for x in [-2.0, 0.0, 2.0]:
				_box(root, Vector3(0.1, 1.6, 0.1), Vector3(x, 0.8, 0), m, false)
			for y in [0.4, 1.0, 1.5]:
				_box(root, Vector3(4, 0.08, 0.05), Vector3(0, y, 0), m, false)
			_collide(root, BoxShape3D.new(), Vector3(4, 1.6, 0.15), Vector3(0, 0.8, 0), 0.0)
		"table":
			_box(root, Vector3(1.6, 0.08, 0.9), Vector3(0, 0.78, 0), m)
			for c in [Vector2(-0.7, -0.38), Vector2(0.7, -0.38), Vector2(-0.7, 0.38), Vector2(0.7, 0.38)]:
				_box(root, Vector3(0.07, 0.76, 0.07), Vector3(c.x, 0.38, c.y), m, false)
		"lamp":
			_cyl(root, 0.07, 3.6, Vector3(0, 1.8, 0), m)
			_box(root, Vector3(0.6, 0.12, 0.3), Vector3(0, 3.6, 0.15), m, false)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.85, 0.6)
			l.light_energy = 2.2
			l.omni_range = 11.0
			l.position = Vector3(0, 3.4, 0.2)
			root.add_child(l)
		"light":
			_box(root, Vector3(1.2, 0.08, 0.25), Vector3(0, 2.9, 0), _material(5), false)
			var l2 := OmniLight3D.new()
			l2.light_color = Color(0.9, 0.95, 1.0)
			l2.light_energy = 1.8
			l2.omni_range = 9.0
			l2.position = Vector3(0, 2.7, 0)
			root.add_child(l2)
		"sign":
			_box(root, Vector3(0.08, 1.4, 0.08), Vector3(0, 0.7, 0), _material(1), false)
			_box(root, Vector3(1.4, 0.7, 0.06), Vector3(0, 1.6, 0), m)
			var lb := Label3D.new()
			lb.text = "KEEP OUT"
			lb.font_size = 64
			lb.pixel_size = 0.006
			lb.modulate = Color(0.1, 0.08, 0.06)
			lb.position = Vector3(0, 1.6, 0.04)
			lb.outline_size = 0
			root.add_child(lb)
		"loot_common":
			_box(root, Vector3(0.9, 0.5, 0.5), Vector3(0, 0.25, 0), m)
		"loot_rare":
			_box(root, Vector3(1.3, 0.55, 0.6), Vector3(0, 0.275, 0), m)
			_box(root, Vector3(1.32, 0.08, 0.62), Vector3(0, 0.45, 0), _material(1), false)
		"item_stims", "item_ammo":
			_box(root, Vector3(0.3, 0.15, 0.2), Vector3(0, 0.075, 0), _material(6 if k == "item_stims" else 8), false)
		"bench":
			_box(root, Vector3(1.8, 0.9, 0.8), Vector3(0, 0.45, 0), m)
			_box(root, Vector3(1.8, 0.6, 0.06), Vector3(0, 1.2, -0.37), _material(1), false)
		_:
			if k.begins_with("spawn_"):
				# a spawn point: only seen in Forge
				var mk := MeshInstance3D.new()
				var cap := CapsuleMesh.new()
				cap.radius = 0.4
				cap.height = 1.8
				mk.mesh = cap
				var sm := StandardMaterial3D.new()
				sm.albedo_color = Color(1.0, 0.2, 0.15, 0.45)
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mk.material_override = sm
				mk.position.y = 0.9
				mk.name = "Marker"
				root.add_child(mk)
				var lb2 := Label3D.new()
				lb2.text = k.trim_prefix("spawn_").to_upper()
				lb2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lb2.position.y = 2.2
				lb2.font_size = 48
				lb2.pixel_size = 0.008
				lb2.name = "MarkerLabel"
				root.add_child(lb2)
				# a hit box so it can be picked up and deleted (not solid to anyone walking)
				var area := StaticBody3D.new()
				area.name = "Body"
				area.collision_layer = 8
				var cs := CollisionShape3D.new()
				var sh := CapsuleShape3D.new()
				sh.radius = 0.4
				sh.height = 1.8
				cs.shape = sh
				cs.position.y = 0.9
				area.add_child(cs)
				root.add_child(area)
	return root

func name_of(k: String) -> String:
	if KINDS.has(k):
		return String(KINDS[k][0])
	if k.begins_with("f_"):
		return String(Furniture.CAT.get(k.substr(2), [k])[0])
	if k.begins_with("spawn_"):
		return "Spawn: " + String(Game.region.etypes.get(k.trim_prefix("spawn_"), {}).get("name", k.trim_prefix("spawn_"))).capitalize()
	return k

# ---------------------------------------------------------------- placing
var next_id := 0
func _add(d: Dictionary, record := true) -> Dictionary:
	var o := {"k": String(d.k), "p": d.p, "r": float(d.get("r", 0.0)), "s": float(d.get("s", 1.0)), "m": int(d.get("m", -1)), "id": String(d.get("id", ""))}
	if o.id == "":
		next_id += 1
		o.id = "f%d_%d" % [Time.get_ticks_msec() % 100000, next_id]
	var n := build(o.k, o.m)
	add_child(n)
	n.global_position = Vector3(float(o.p[0]), float(o.p[1]), float(o.p[2]))
	n.rotation.y = o.r
	n.scale = Vector3.ONE * o.s
	var body: Node = n.get_node_or_null("Body")
	if body:
		body.set_meta("forge", o.id)
	o.n = n
	_marker_vis(o)
	# gameplay pieces join the world's objects
	var gid := "forge_%s_%s" % [Game.area, o.id]
	match o.k:
		"loot_common", "loot_rare":
			o.obj = {"_k": "chest", "id": gid, "x": n.global_position.x, "z": n.global_position.z, "y": n.global_position.y, "tier": "rare" if o.k == "loot_rare" else "common", "name": name_of(o.k)}
		"item_stims":
			o.obj = {"_k": "pickup", "id": gid, "item": "stimpak", "qty": 2, "x": n.global_position.x, "z": n.global_position.z, "y": n.global_position.y}
		"item_ammo":
			o.obj = {"_k": "pickup", "id": gid, "item": String(Game.item(Game.weapon).get("ammo", "ammo_9")), "qty": 24, "x": n.global_position.x, "z": n.global_position.z, "y": n.global_position.y}
		"bench":
			o.obj = {"_k": "bench", "x": n.global_position.x, "z": n.global_position.z, "y": n.global_position.y}
	if o.has("obj") and main.objects.has_method("add_dynamic"):
		main.objects.add_dynamic(o.obj)
	objs.append(o)
	if record:
		undo.append(["add", o.id])
		_save()
	return o

func _remove(o: Dictionary, record := true) -> void:
	if o.has("obj"):
		main.objects.remove_dynamic(o.obj)
	if is_instance_valid(o.n):
		o.n.queue_free()
	objs.erase(o)
	if record:
		undo.append(["del", {"k": o.k, "p": o.p, "r": o.r, "s": o.s, "m": o.m, "id": o.id}])
		_save()

func _find(id: String):
	for o in objs:
		if o.id == id:
			return o
	return null

func _marker_vis(o: Dictionary) -> void:
	if not is_instance_valid(o.n):
		return
	for nm in ["Marker", "MarkerLabel"]:
		var mk = o.n.get_node_or_null(nm)
		if mk:
			mk.visible = active

# enemy spawn points come alive outside Forge (once each time the area loads, or each time you leave Forge)
func _spawn_all() -> void:
	for o in objs:
		if String(o.k).begins_with("spawn_"):
			var t := String(o.k).trim_prefix("spawn_")
			var e = main.events._enemy(t, float(o.p[0]), float(o.p[2]), true)
			if e:
				e.set_meta("forge", true)

func _despawn_all() -> void:
	for e in main.enemies.duplicate():
		if is_instance_valid(e) and e.has_meta("forge"):
			main.enemies.erase(e)
			e.queue_free()

# ---------------------------------------------------------------- the mode
func toggle() -> void:
	active = not active
	if active:
		Game.dev.noclip = false
		_despawn_all()
		_make_ui()
		_make_ghost()
		Game.msg("FORGE: build with FIRE, pick up with USE, delete with NADE, turn with RLD. FOCUS opens the palette.")
	else:
		if held != null:
			_drop_held()
		if ghost:
			ghost.queue_free()
			ghost = null
		if hud_panel:
			hud_panel.queue_free()
			hud_panel = null
		if palette:
			palette.queue_free()
			palette = null
		_spawn_all()
		Game.msg("Forge closed. Spawn points are live.")
	for o in objs:
		_marker_vis(o)
	if Game.player and Game.player.gun:
		Game.player.gun.visible = not active
	main.hud.touch.queue_redraw()

func button_label(k: String, def: String) -> String:
	return {"fire": "PLACE", "use": "GRAB", "nade": "DEL", "reload": "TURN", "swap": "NEXT", "focus": "MENU", "jump": "UP", "run": "DOWN"}.get(k, def)

func touch(k: String, on: bool) -> void:
	if not on:
		return
	match k:
		"fire": place()
		"use": grab()
		"nade": delete_aimed()
		"reload": turn(PI / 4.0)
		"swap": cycle(1)
		"focus": toggle_palette()

func _unhandled_input(e: InputEvent) -> void:
	if not active or Game.paused:
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		match e.button_index:
			MOUSE_BUTTON_LEFT: place()
			MOUSE_BUTTON_RIGHT: grab()
			MOUSE_BUTTON_WHEEL_UP: turn(PI / 12.0)
			MOUSE_BUTTON_WHEEL_DOWN: turn(-PI / 12.0)
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F: place()
			KEY_E: grab()
			KEY_X, KEY_DELETE: delete_aimed()
			KEY_R: turn(PI / 4.0)
			KEY_Q, KEY_TAB: cycle(1)
			KEY_B: toggle_palette()
			KEY_PAGEUP: lift += 0.25
			KEY_PAGEDOWN: lift -= 0.25
			KEY_EQUAL, KEY_KP_ADD: scl = minf(4.0, scl + 0.25)
			KEY_MINUS, KEY_KP_SUBTRACT: scl = maxf(0.25, scl - 0.25)
			KEY_Z: undo_last()
			_: return
		get_viewport().set_input_as_handled()

func _make_ghost() -> void:
	if ghost:
		ghost.queue_free()
	var k: String = held.k if held != null else kinds[cur]
	ghost = build(k, mat)
	var body: Node = ghost.get_node_or_null("Body")
	if body:
		body.queue_free()
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = ghost_mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for l in ghost.find_children("*", "Light3D", true, false):
		l.queue_free()
	add_child(ghost)

func _aim() -> Dictionary:
	var cam: Camera3D = Game.player.cam
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 40.0, 1 | 8)
	q.exclude = [Game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _target_pos() -> Vector3:
	var h := _aim()
	var cam: Camera3D = Game.player.cam
	var p: Vector3 = h.position if h else cam.global_position - cam.global_basis.z * 8.0
	if grid > 0.0:
		p.x = snappedf(p.x, grid)
		p.z = snappedf(p.z, grid)
	p.y += lift
	return p

func _physics_process(_d: float) -> void:
	if not active or ghost == null or Game.player == null:
		return
	ghost.global_position = _target_pos()
	ghost.rotation.y = rot
	ghost.scale = Vector3.ONE * scl
	if info:
		var k: String = held.k if held != null else kinds[cur]
		info.text = "FORGE   %s%s   finish: %s   turn %d°   scale x%.2f   lift %+.2f m   grid %s   objects %d" % [
			"MOVING " if held != null else "", name_of(k), "own" if mat < 0 else String(MATS[mat][0]), int(round(rad_to_deg(rot))) % 360, scl, lift,
			("%.2f m" % grid) if grid > 0.0 else "off", objs.size()]

func place() -> void:
	var k: String = held.k if held != null else kinds[cur]
	var p := ghost.global_position if ghost else _target_pos()
	var d := {"k": k, "p": [p.x, p.y, p.z], "r": rot, "s": scl, "m": mat if held == null or mat >= 0 else held.m}
	if held != null:
		d.id = held.id
		held = null
	_add(d)
	Sfx.play("k_metal_click", -6.0)
	_make_ghost()

func _aimed():
	var h := _aim()
	if h and h.collider and h.collider.has_meta("forge"):
		return _find(String(h.collider.get_meta("forge")))
	return null

func grab() -> void:
	if held != null:
		place()
		return
	var o = _aimed()
	if o == null:
		Game.msg("Look at something you built to pick it up.")
		return
	rot = o.r
	scl = o.s
	mat = o.m
	_remove(o, false)
	undo.append(["del", {"k": o.k, "p": o.p, "r": o.r, "s": o.s, "m": o.m, "id": o.id}])
	held = {"k": o.k, "m": o.m, "id": o.id}
	Sfx.play("k_switch", -6.0)
	_make_ghost()

func _drop_held() -> void:
	place()

func delete_aimed() -> void:
	var o = _aimed()
	if o == null:
		if held != null:
			held = null
			_make_ghost()
		return
	_remove(o)
	Sfx.play("k_drop", -4.0)

func turn(a: float) -> void:
	rot = fposmod(rot + a, TAU)

func cycle(n: int) -> void:
	if held != null:
		return
	cur = posmod(cur + n, kinds.size())
	_make_ghost()

func undo_last() -> void:
	if undo.is_empty():
		return
	var u: Array = undo.pop_back()
	if u[0] == "add":
		var o = _find(String(u[1]))
		if o:
			_remove(o, false)
	else:
		_add(u[1], false)
	_save()

func clear_all() -> void:
	for o in objs.duplicate():
		_remove(o, false)
	undo.clear()
	_save()

# map slots: a layout you can take anywhere (saved apart from the game)
func save_map(slot: String) -> void:
	var f := FileAccess.open("user://forge_map_%s.json" % slot, FileAccess.WRITE)
	if f == null:
		return
	var pp: Vector3 = Game.player.global_position
	# positions relative to where you stand, so a layout can be dropped elsewhere
	f.store_string(JSON.stringify({"area": Game.area, "objs": objs.map(func(o): return {"k": o.k, "p": [float(o.p[0]) - pp.x, float(o.p[1]) - pp.y, float(o.p[2]) - pp.z], "r": o.r, "s": o.s, "m": o.m})}))
	Game.msg("Map saved to slot %s (%d objects), relative to where you stand." % [slot, objs.size()])

func load_map(slot: String) -> void:
	var f := FileAccess.open("user://forge_map_%s.json" % slot, FileAccess.READ)
	if f == null:
		Game.msg("Slot %s is empty." % slot)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	var pp: Vector3 = Game.player.global_position
	for o in d.get("objs", []):
		_add({"k": o.k, "p": [float(o.p[0]) + pp.x, float(o.p[1]) + pp.y, float(o.p[2]) + pp.z], "r": o.r, "s": o.s, "m": o.m}, false)
	_save()
	Game.msg("Loaded map %s here (%d objects)." % [slot, d.get("objs", []).size()])

# ---------------------------------------------------------------- the screen
func _make_ui() -> void:
	if hud_panel:
		hud_panel.queue_free()
	hud_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.07, 0.1, 0.8)
	sb.border_color = Color(0.4, 0.85, 1.0, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	hud_panel.add_theme_stylebox_override("panel", sb)
	hud_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_panel.offset_top = 48
	hud_panel.offset_left = 10
	hud_panel.offset_right = -10
	main.hud.root.add_child(hud_panel)
	var v := VBoxContainer.new()
	hud_panel.add_child(v)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	v.add_child(row)
	var b := func(t: String, f: Callable) -> void:
		var x := Button.new()
		x.text = t
		x.custom_minimum_size = Vector2(0, 40)
		x.add_theme_font_size_override("font_size", 15)
		x.pressed.connect(f)
		row.add_child(x)
	b.call("PALETTE", toggle_palette)
	b.call("FINISH", func():
		mat = mat + 1 if mat + 1 < MATS.size() else -1
		_make_ghost())
	b.call("GRID", func():
		var g := [0.0, 0.25, 0.5, 1.0, 2.0]
		grid = g[(g.find(grid) + 1) % g.size()])
	b.call("TURN 15°", func(): turn(PI / 12.0))
	b.call("TURN 90°", func(): turn(PI / 2.0))
	b.call("COPY AIMED", func():
		var a = _aimed()
		if a:
			cur = maxi(0, kinds.find(a.k))
			rot = float(a.get("r", 0.0))
			scl = float(a.get("s", 1.0))
			mat = int(a.get("m", -1))
			_make_ghost()
			Game.msg("Copied: " + name_of(String(a.k))))
	b.call("PREV", func(): cycle(-1))
	b.call("NEXT", func(): cycle(1))
	b.call("LIFT +", func(): lift += 0.25)
	b.call("LIFT -", func(): lift -= 0.25)
	b.call("SCALE +", func(): scl = minf(4.0, scl + 0.25))
	b.call("SCALE -", func(): scl = maxf(0.25, scl - 0.25))
	b.call("RESET", func():
		rot = 0.0
		scl = 1.0
		lift = 0.0
		mat = -1
		_make_ghost())
	b.call("UNDO", undo_last)
	b.call("SAVE MAP", func(): save_map(map_slot))
	b.call("LOAD MAP", func(): load_map(map_slot))
	b.call("SLOT " + map_slot, func():
		map_slot = str(int(map_slot) % 3 + 1)
		_make_ui())
	b.call("CLEAR ALL", clear_all)
	b.call("EXIT FORGE", toggle)

func toggle_palette() -> void:
	if palette:
		palette.queue_free()
		palette = null
		return
	palette = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.09, 0.96)
	sb.border_color = Color(0.4, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	palette.add_theme_stylebox_override("panel", sb)
	palette.set_anchors_preset(Control.PRESET_FULL_RECT)
	palette.offset_left = 60
	palette.offset_right = -60
	palette.offset_top = 150
	palette.offset_bottom = -40
	main.hud.root.add_child(palette)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for cat in ["BUILD", "PROPS", "FURNITURE: TABLES", "FURNITURE: SEATS", "FURNITURE: STORAGE", "FURNITURE: CLUTTER", "FURNITURE: WALLS", "FURNITURE: LIGHTS", "GAMEPLAY", "SPAWN POINTS"]:
		var l := Label.new()
		l.text = cat
		l.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
		l.add_theme_font_size_override("font_size", 18)
		v.add_child(l)
		var g := HFlowContainer.new()
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		v.add_child(g)
		for i in kinds.size():
			var k: String = kinds[i]
			var c := "SPAWN POINTS" if k.begins_with("spawn_") else ("FURNITURE: " + String(Furniture.CAT.get(k.substr(2), ["", ""])[1]).to_upper() if k.begins_with("f_") else String(KINDS.get(k, ["", ""])[1]))
			if c != cat:
				continue
			var b := Button.new()
			b.text = name_of(k).trim_prefix("Spawn: ")
			b.custom_minimum_size = Vector2(0, 44)
			if i == cur:
				b.modulate = Color(0.6, 1.0, 1.0)
			b.pressed.connect(func():
				cur = i
				held = null
				_make_ghost()
				toggle_palette())
			g.add_child(b)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(toggle_palette)
	v.add_child(close)
