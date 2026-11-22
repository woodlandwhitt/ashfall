# Things that happen on the road between places (main.js evTick/startEvent): raiders hitting a caravan (save it for a
# reward), a wandering trader with her ox, a stranded traveller who needs help (or can be robbed), a dead scavenger
# with something still in his pack and the hounds that killed him. Plus karma's company (huntTick): bounty hunters
# track down the wicked, and Kess sends hired guns after the good.
class_name RoadEvents
extends Node

const KINDS := ["caravan", "trader", "stranger", "scav", "radstorm", "caravan", "stranger", "scav"]
var main
var t := 150.0
var cur: Dictionary = {}
var amb_n := 0

func setup(m) -> void:
	main = m

func _physics_process(dt: float) -> void:
	if Game.interior() or Game.paused or Game.player == null or not Game.booted and not OS.get_cmdline_user_args().has("--events"):
		return
	_hunt(dt)
	var pp: Vector3 = Game.player.global_position
	if not cur.is_empty():
		cur.t += dt
		var d := Vector2(float(cur.x) - pp.x, float(cur.z) - pp.z).length()
		if not cur.seen and d < 55.0:
			cur.seen = true
			match String(cur.kind):
				"caravan":
					Game.msg("Gunfire ahead: raiders are hitting a caravan!")
					Game.start("caravan_rescue")
					if not Game.flags.get("track_manual", false):
						Game.flags["track"] = "caravan_rescue"
				"trader": Game.msg("A trader's cart sits by the road, ox dozing in the traces.")
				"stranger": Game.msg("Someone is waving at you from beside a burnt-out cart.")
				"scav": Game.msg("Vultures circle over something ahead.")
		if cur.kind == "caravan" and not Game.flags.get("evClear") and not cur.foes.is_empty():
			var all_dead := true
			for e in cur.foes:
				if is_instance_valid(e) and not e.dead:
					all_dead = false
			if all_dead:
				Game.flags["evClear"] = true
				Game.check_quests()
				main.speak("You saved our wagons. Here, take this, and our thanks.", "trader")
		if cur.kind == "radstorm":
			if cur.t > cur.dur:
				main.atmos.set_weather("cloudy")
				Game.msg("The green light fades. The radstorm has passed.")
				clear()
				t = randf_range(150.0, 280.0)
			return
		if d > 190.0 or (cur.t > 600.0 and d > 70.0):
			clear()
			t = randf_range(120.0, 240.0)
		return
	t -= dt
	if t <= 0.0:
		t = randf_range(150.0, 280.0)
		start(KINDS[randi() % KINDS.size()])

# a flat, open spot 45-75 m from you, away from every settlement
func spot() -> Variant:
	var pp: Vector3 = Game.player.global_position
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for i in 30:
		var a := randf() * TAU
		var dd := randf_range(45.0, 75.0)
		var x := pp.x + sin(a) * dd
		var z := pp.z + cos(a) * dd
		if absf(x) > 460.0 or absf(z) > 460.0:
			continue
		var near_town := false
		for k in Game.DB.locs:
			var L: Dictionary = Game.DB.locs[k]
			if Vector2(float(L.x) - x, float(L.z) - z).length() < float(L.get("r", 30)) + 25.0:
				near_town = true
				break
		if near_town:
			continue
		var h := Game.height(x, z)
		if absf(Game.height(x + 3, z) - h) > 1.4 or absf(Game.height(x, z + 3) - h) > 1.4:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 2.5
		q.shape = sh
		q.transform = Transform3D(Basis(), Vector3(x, h + 3.0, z))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		return Vector2(x, z)
	return null

func start(kind: String, at = null) -> bool:
	clear()
	var sp = at if at != null else spot()
	if sp == null:
		return false
	cur = {"kind": kind, "x": sp.x, "z": sp.y, "npcs": [], "props": [], "foes": [], "chests": [], "t": 0.0, "seen": false, "dur": 0.0}
	var x: float = sp.x
	var z: float = sp.y
	match kind:
		"radstorm":
			if main.atmos == null:
				return false
			main.atmos.set_weather("radstorm", true)
			cur.seen = true
			cur.dur = randf_range(80.0, 130.0)
			Game.msg("Radstorm! The sky is turning green. Get under a roof.")
			Game.banner("RADSTORM", "Find shelter")
			Sfx.play("o_drone", -4.0)
		"caravan":
			cur.props.append(_wagon(x, z, false))
			cur.npcs.append(_npc("trader", x + 2.2, z + 1.2))
			Game.flags.erase("evClear")
			Game.flags["evPos"] = {"x": x, "z": z}
			for i in 3 + (1 if Game.level > 4 else 0):
				var a := i / 4.0 * TAU
				var e = _enemy("heavy" if Game.level > 6 and i == 0 else "raider", x + sin(a) * 9.0, z + cos(a) * 9.0, true)
				if e:
					cur.foes.append(e)
		"trader":
			cur.npcs.append(_npc("trader", x, z))
			var ox = _enemy("ox", x + 2.5, z + 1.0, false)
			if ox:
				cur.foes.append(ox)
		"stranger":
			Game.flags.erase("evHelped")
			cur.npcs.append(_npc("stranger", x, z))
			cur.props.append(_wagon(x + 3.0, z - 1.0, true))
		"scav":
			var body := _body(x, z)
			cur.props.append(body)
			var ch := {"_k": "chest", "id": "ev_body" + str(Time.get_ticks_msec() % 1000000), "x": x, "z": z, "y": Game.height(x, z),
				"tier": "rare" if randf() < 0.3 else "common", "name": "Dead Scavenger", "fixed": [["caps", 15 + randi() % 40]]}
			main.objects.add_dynamic(ch)
			cur.chests.append(ch)
			var tp := "stalker" if Game.level > 5 and Game.region.etypes.has("stalker") else "hound"
			for i in 2 + (1 if randf() < 0.5 else 0):
				var e = _enemy(tp, x + 6.0 + i * 2.0, z - 5.0, true)
				if e:
					cur.foes.append(e)
	return true

func clear() -> void:
	if cur.is_empty():
		return
	for n in cur.npcs:
		if is_instance_valid(n) and n != main.dialog_npc:
			main.npcs.erase(n)
			n.queue_free()
	for p in cur.props:
		if is_instance_valid(p):
			p.queue_free()
	for e in cur.foes:
		if is_instance_valid(e) and not e.dead:
			main.enemies.erase(e)
			e.queue_free()
	for ch in cur.chests:
		main.objects.remove_dynamic(ch)
	cur = {}

func _npc(id: String, x: float, z: float):
	var n = preload("res://scripts/npc.gd").new()
	main.add_child(n)
	var look := {}
	for d in Game.region.npcs:
		if String(d.id) == id:
			look = d.get("look", {})
	n.setup({"id": id, "name": id, "x": x, "z": z, "rot": randf() * TAU, "wander": null, "look": look})
	main.npcs.append(n)
	return n

func _enemy(type: String, x: float, z: float, hostile: bool):
	if not Game.region.etypes.has(type):
		type = "raider"
	var e = preload("res://scripts/enemy.gd").new()
	main.add_child(e)
	amb_n += 1
	e.setup({"type": type, "x": x, "z": z, "y": Game.height(x, z), "hostile": hostile, "id": "ev_" + type + str(amb_n)}, Game.region.etypes[type])
	main.enemies.append(e)
	return e

# a covered wagon (or a burnt-out one)
func _wagon(x: float, z: float, burnt: bool) -> Node3D:
	var g := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.23, 0.16, 0.1) if burnt else Color(0.54, 0.42, 0.28)
	wood.roughness = 0.85
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.29, 0.27, 0.23) if burnt else Color(0.85, 0.8, 0.69)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bed := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.5, 3.2)
	bed.mesh = bm
	bed.material_override = wood
	bed.position.y = 0.9
	g.add_child(bed)
	if not burnt:
		var arc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.95
		cm.bottom_radius = 0.95
		cm.height = 3.0
		arc.mesh = cm
		arc.material_override = cloth
		arc.rotation = Vector3(PI / 2, 0, 0)
		arc.position.y = 1.15
		arc.scale = Vector3(1, 1, 0.75)
		g.add_child(arc)
	for w in [[-0.95, 1.0], [0.95, 1.0], [-0.95, -1.0], [0.95, -1.0]]:
		var wh := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.55
		wm.bottom_radius = 0.55
		wm.height = 0.12
		wh.mesh = wm
		wh.material_override = wood
		wh.rotation.z = PI / 2
		wh.position = Vector3(w[0], 0.55, w[1])
		g.add_child(wh)
	main.add_child(g)
	g.global_position = Vector3(x, Game.height(x, z), z)
	g.rotation.y = randf() * TAU
	if burnt:
		g.rotation.z = 0.25
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.9, 1.6, 3.2)
	cs.shape = bx
	cs.position.y = 0.8
	sb.add_child(cs)
	g.add_child(sb)
	return g

# what's left of a scavenger
func _body(x: float, z: float) -> Node3D:
	var m := Humanoid.build("Male_Peasant", Color(0.55, 0.48, 0.4), Color(0.8, 0.7, 0.6))
	main.add_child(m)
	m.global_position = Vector3(x, Game.height(x, z) + 0.15, z)
	m.rotation = Vector3(0, randf() * TAU, PI / 2)
	var ap: AnimationPlayer = m.get_node_or_null("AnimationPlayer")
	if ap:
		ap.play("Idle")
		ap.pause()
	return m

# karma brings company
func _hunt(dt: float) -> void:
	var bad := Game.karma <= -40
	var good: bool = Game.karma >= 40 and not Game.flags.get("kessFriend")
	if not bad and not good:
		return
	var pp: Vector3 = Game.player.global_position
	for k in Game.DB.locs:
		var L: Dictionary = Game.DB.locs[k]
		if Vector2(pp.x - float(L.x), pp.z - float(L.z)).length() < float(L.get("r", 30)) * 1.3:
			return
	Game.flags["huntT"] = float(Game.flags.get("huntT", 240.0)) - dt
	if float(Game.flags.huntT) > 0.0:
		return
	Game.flags["huntT"] = randf_range(420.0, 780.0)
	var type := "sniper" if bad else "raider"
	var n := 2 + (1 if randf() < 0.4 else 0)
	var a: float = Game.player.yaw + PI + randf_range(-0.5, 0.5)
	for i in n:
		var x := clampf(pp.x - sin(a) * 48.0 + randf_range(-5, 5), -460, 460)
		var z := clampf(pp.z - cos(a) * 48.0 + randf_range(-5, 5), -460, 460)
		var e = _enemy(type, x, z, true)
		e.state = "chase"
	Game.banner("HUNTED" if bad else "AMBUSH", "Bounty hunters have tracked you down" if bad else "Kess has sent hired guns to stop you")
	Sfx.play("o_creature1", -2.0)
