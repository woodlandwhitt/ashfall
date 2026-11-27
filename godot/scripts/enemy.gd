# A hostile: wanders near its spawn, notices you by sight or by gunfire, paths to you over Godot's navigation mesh
# (straight-line steering until the mesh has baked), then bites or shoots. Dead ones can be searched.
extends CharacterBody3D

var type := ""
var def: Dictionary = {}
var hp := 40.0
var hp_max := 40.0
var model: Node3D
var rig: Rig
var agent: NavigationAgent3D
var home := Vector3.ZERO
var state := "idle"
var target := Vector3.ZERO
var wait := 0.0
var face_yaw := 0.0
var atk_cd := 0.0
var repath := 0.0
var dead := false
var looted := false
var t := 0.0
var flash := 0.0
var quad := false
var ranged := false
var speed := 3.0
var dmg := 8.0
var hostile := true
var bark_cd := 0.0
var ap: AnimationPlayer   # people use Quaternius bodies; creatures keep their original models
var act_t := 0.0          # a one-shot animation (shoot, hit, punch) is playing
var near := true
var idx := -1
var eid := ""          # the spawn's id: quests ask whether a named enemy is dead
var group := ""        # neutral groups (Kess's crew, the herd) turn on you together
var loot = null          # what the body holds once searched
var npc = null           # a townsperson you provoked
var essential := false   # they yield instead of dying
var since_hit := 0.0
var lt: LegTwist          # hips follow the feet when it strafes or backs off
var aiming := false       # last frame it was aiming: it keeps facing you while it moves     # a provoked townsperson cools off when you stop hitting them and walk away
var town_hit := false
var you_hit := false     # only what you had a hand in killing pays XP (guards kill raiders too)
var foe = null           # the companion it is fighting, or null for you
var fly := false         # a vulture: airborne
var fly_c := Vector3.ZERO     # the point it wheels round
var fly_a := 0.0
var fly_mode := "wheel"   # wheel, stoop (diving on you), climb
var fly_t := 0.0
var stun := 0.0         # a flashbang: blind and staggering
var caged := false      # held in a cage until something opens it (the Meridian brute)
var slow := 0.0         # a cryo grenade: frozen to a crawl
var bleed: Array = []   # [damage per second, seconds left]: nails, burning, a glowing wound
var crip := {}           # FOCUS hits: crippled legs slow it, crippled arms spoil its aim
# tactics: what it is doing inside a fight
var tac := "advance"     # advance, strafe, cover, peek, flee, circle
var tac_t := 0.0
var strafe := 1.0
var cover := Vector3.ZERO
var burst := 0           # shots left in this burst
var windup := 0.0        # a melee blow on its way (you can step out of it)
var slot := 0.0          # the side it comes at you from, so a pack spreads out instead of stacking
var fled := false
var seen_t := 0.0        # how long you've been in its sight
var lost_t := 0.0        # how long since it last saw you while hunting
var look_t := 0.0
var saw := true
var last_seen := Vector3.ZERO

# outfit, cloth tint, skin tint for the human hostiles
const PEOPLE := {
	"raider": ["Male_Ranger", Color(0.62, 0.5, 0.44), Color(1.0, 0.85, 0.75)],
	"jackal": ["Male_Peasant", Color(0.7, 0.58, 0.4), Color(0.85, 0.7, 0.6)],
	"heavy": ["Male_Ranger", Color(0.38, 0.38, 0.42), Color(0.8, 0.66, 0.56)],
	"marauder": ["Female_Ranger", Color(0.6, 0.32, 0.28), Color(1.0, 0.86, 0.78)],
	"pyro": ["Male_Peasant", Color(0.4, 0.37, 0.34), Color(0.75, 0.6, 0.5)],
	"ghoul": ["Male_Peasant", Color(0.48, 0.48, 0.4), Color(0.8, 0.75, 0.6)],
	"glowhusk": ["Male_Peasant", Color(0.4, 0.44, 0.36), Color(0.62, 0.9, 0.5)],
	"tollking": ["Male_Ranger", Color(0.75, 0.62, 0.3), Color(0.9, 0.75, 0.65)],
	# build 14: the hill families, synths, guard robots and the Iron Wardens in power armour
	"hillfolk": ["Male_Peasant", Color(0.32, 0.38, 0.55), Color(1.0, 0.85, 0.75)],
	"hill_ma": ["Female_Peasant", Color(0.45, 0.3, 0.3), Color(1.0, 0.85, 0.75)],
	"synth": ["Male_Ranger", Color(0.8, 0.8, 0.82), Color(0.9, 0.9, 0.92)],
	"guardbot": ["Male_Knight_Cloth", Color(0.35, 0.37, 0.4), Color(0.4, 0.42, 0.45)],
	"warden": ["Male_Knight_Cloth", Color(0.3, 0.33, 0.25), Color(0.85, 0.7, 0.6)],
	# build 22: the last gunmen still on the old stick rig (the sharpshooter held his rifle straight up at the sky)
	"sniper": ["Male_Ranger", Color(0.36, 0.38, 0.3), Color(0.85, 0.7, 0.6)],
	"hunter": ["Male_Ranger", Color(0.5, 0.4, 0.28), Color(0.9, 0.75, 0.62)],
	"hired": ["Male_Peasant", Color(0.42, 0.42, 0.45), Color(0.95, 0.8, 0.68)],
	"warlord": ["Male_Ranger", Color(0.45, 0.2, 0.18), Color(0.9, 0.75, 0.62)],
}
const MACHINES := ["synth", "guardbot", "warden"]

func setup(d: Dictionary, td: Dictionary) -> void:
	_unwedge.call_deferred()
	type = d.type
	def = td
	if d.get("name") != null:
		def = td.duplicate()
		def["name"] = String(d.name)
	quad = bool(td.get("quad", false))
	fly = bool(Game.DB.enemies.get(type, {}).get("fly", false)) or type == "vulture"
	ranged = (bool(td.get("ranged", false)) or bool(d.get("ranged", false))) and not quad
	hp_max = float(td.get("hp", 40)) if td.get("hp") != null else 40.0
	hp = hp_max
	speed = (float(td.speed) if td.get("speed") != null else 3.2) * (1.0 if quad else 0.85)
	speed = clampf(speed, 2.2, 6.5)
	dmg = float(td.dmg) if td.get("dmg") != null else 8.0
	hostile = bool(d.get("hostile", true))
	eid = String(d.get("id", "")) if d.get("id") != null else ""
	group = String(d.get("group", "")) if d.get("group") != null else ""
	position = Vector3(d.x, maxf(Game.height(d.x, d.z), Frontier.floor_at(d.x, d.z)), d.z)
	home = position
	face_yaw = randf() * TAU
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	if quad:
		var b := BoxShape3D.new()
		b.size = Vector3(0.7, 0.9, 1.3)
		cs.shape = b
		cs.position.y = 0.45
	else:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.34
		cap.height = 1.75
		cs.shape = cap
		cs.position.y = 0.88
	add_child(cs)
	if d.has("look"):
		# a townsperson who turned on you keeps their own face and clothes
		model = Humanoid.person(d.look, hash(String(d.get("npc", ""))), "guard" if type == "townguard" else "")
		add_child(model)
		ap = model.get_node("AnimationPlayer")
		_twist_setup()
		if ranged:
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			_arm(d)
		ap.play("Idle")
	elif PEOPLE.has(type) and not quad:
		# every raider his own: cut, dye, skin, hair, beard, headgear (Humanoid.enemy_person)
		# the wreck's sentinel is the saucer's last crewman, in his pressure suit (build 24)
		if String(d.get("id", "")) == "sentinel":
			model = Humanoid.alien(hash("sentinel"), true)
		else:
			model = Humanoid.enemy_person(type, PEOPLE[type], hash(String(d.get("id", "")) + type + str(d.x)))
		add_child(model)
		ap = model.get_node("AnimationPlayer")
		_twist_setup()
		if ranged:
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			_arm(d)
		ap.play("Idle")
		ap.seek(randf() * 2.0, true)
	else:
		if fly:
			model = Vulture.model()
			add_child(model)
		else:
			var ps: PackedScene = load(Game.char_path("enemy_" + type + ".glb"))
			model = ps.instantiate()
			add_child(model)
			rig = Rig.new(model, quad)
			_fit_shape(cs)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 150.0
	slot = float(absi(hash(eid + str(d.x) + str(d.z))) % 6283) / 1000.0
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.2
	agent.radius = 0.5
	add_child(agent)
	target = home

# the big ones (the Glow Brute stands near 3.5 m) used to keep a man-sized capsule, so shots at the chest and head
# went straight past them (build 17 report: "cannot shoot brute"); the shape now fits the model
func _fit_shape(cs: CollisionShape3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf: Transform3D = global_transform.affine_inverse() * m.global_transform if is_inside_tree() else _rel(m)
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	if quad:
		if box.size.y > 1.2 or maxf(box.size.x, box.size.z) > 1.6:
			var bs := BoxShape3D.new()
			bs.size = Vector3(clampf(box.size.x * 0.8, 0.5, 3.0), clampf(box.size.y * 0.9, 0.6, 3.0), clampf(box.size.z * 0.8, 0.6, 4.0))
			cs.shape = bs
			cs.position = Vector3(0, bs.size.y * 0.5, 0)
		return
	if box.size.y < 2.1:
		return
	var cap := CapsuleShape3D.new()
	cap.radius = clampf(minf(box.size.x, box.size.z) * 0.38, 0.34, 1.1)
	cap.height = maxf(box.size.y * 0.97, cap.radius * 2.0)
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	if OS.get_cmdline_user_args().has("--fitlog"):
		print("FIT ", type, " h ", cap.height, " r ", cap.radius)

func _rel(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != self:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t

# a gun of their own (a handgun: the aiming pose is one-handed), and the arms held on it in a fight
const SIDEARMS := {"raider": ["Pistol_4", "lp_pistol", "lp_machine_pistol", "Revolver_3", "lp_derringer"], "warlord": ["lp_revolver"],
	"hired": ["lp_pistol", "Pistol_4"], "townguard": ["lp_revolver", "Revolver_3"], "townsfolk": ["lp_pistol", "Pistol_4"],
	"marauder": ["lp_machine_pistol", "Pistol_4"], "tollking": ["lp_revolver"], "sniper": ["Sniper_Rifle_West", "SniperRifle_4"], "hunter": ["Revolver_3"]}
var aim_hold: AimHold
func _arm(d: Dictionary) -> void:
	var list: Array = SIDEARMS.get(type, ["Pistol_4"])
	var glb: String = list[absi(hash(String(d.get("id", "")) + str(d.x))) % list.size()]
	var f: Dictionary = Game.DB.gunfit.get(glb, {})
	var fit := Basis(Vector3.UP, float(f.get("ry", 0.0))).scaled(preload("res://scripts/player.gd")._kv(f) if f.has("k") else Vector3.ONE)
	var gf := f.duplicate()
	gf["glb"] = glb
	if type == "warlord" or type == "tollking":
		gf["finish"] = "gold"
	if not glb.begins_with("lp_") and not glb.begins_with("Pistol") and not glb.begins_with("Revolver"):
		gf["pistol"] = false
	else:
		gf["pistol"] = true
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		sk.force_update_all_bone_transforms()
		aim_hold = AimHold.new()
		sk.add_child(aim_hold)
		aim_hold.capture(sk)
	# a rifle to the shoulder in both hands (build 22: the sharpshooter used to carry a pistol)
	if gf.pistol:
		Humanoid.hold_gun(model, load("res://guns/" + glb + ".glb"), fit, gf)
	else:
		Humanoid.shoulder_gun(model, load("res://guns/" + glb + ".glb"), fit, gf)

# spawned inside a boulder or a wreck: step out to clear ground first
func _unwedge() -> void:
	if not is_inside_tree():
		return
	var tr := get_tree()
	await tr.physics_frame
	await tr.physics_frame
	if not is_inside_tree() or dead:
		return
	var c := ClearSpot.near(get_world_3d().direct_space_state, global_position, 0.32, 1.4, [get_rid()], 4.0)
	if c != Vector3.INF and c.distance_to(global_position) > 0.01:
		global_position = c + Vector3.UP * 0.1

# ---------------------------------------------------------------- flying (vultures)
func _fly(d: float) -> void:
	var P := Game.player
	var pp: Vector3 = P.global_position
	var dist := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
	if dist > 140.0 and state != "chase" and fly_c != Vector3.ZERO:
		return
	fly_t -= d
	atk_cd -= d
	if fly_c == Vector3.ZERO:
		fly_c = home
		fly_a = randf() * TAU
		global_position = home + Vector3.UP * randf_range(9.0, 14.0)
		collision_mask = 0
	if hostile and state != "chase" and dist < float(Game.DB.enemies.get(type, {}).get("detect", 42)) and stun <= 0.0:
		state = "chase"
		Sfx.play_at("o_creature2", global_position, 2.0, 1.6)
	var want := Vector3.ZERO
	var flap := 0.1
	var spd := 7.5 * (0.4 if slow > 0.0 else 1.0)
	var centre := fly_c
	var alt := 12.0
	var rad := 12.0
	if state == "chase" and not Game.dev.invis:
		centre = pp
		alt = 7.0
		rad = 9.0
	match fly_mode:
		"wheel":
			fly_a += d * spd / rad
			var gy: float = Game.height(centre.x + cos(fly_a) * rad, centre.z + sin(fly_a) * rad)
			want = Vector3(centre.x + cos(fly_a) * rad, maxf(gy, centre.y) + alt + sin(t * 0.4) * 1.2, centre.z + sin(fly_a) * rad)
			if state == "chase" and fly_t <= 0.0 and atk_cd <= 0.0 and stun <= 0.0:
				fly_mode = "stoop"
				fly_t = 4.0
		"stoop":
			want = pp + Vector3.UP * 1.2
			spd = 13.0 * (0.4 if slow > 0.0 else 1.0)
			flap = 0.0
			if global_position.distance_to(want) < 1.6:
				if not Game.dev.invis:
					Game.main.hud.hurt_from(global_position)
					Game.hurt(dmg * randf_range(0.8, 1.2))
					Sfx.play_at("o_bark2", global_position, 0.0, 1.5)
				atk_cd = float(Game.DB.enemies.get(type, {}).get("atk", 1.4)) + randf_range(2.0, 4.0)
				fly_mode = "climb"
				fly_t = 2.2
			elif fly_t <= 0.0:
				fly_mode = "climb"
				fly_t = 2.0
		"climb":
			var away := (global_position - pp)
			away.y = 0
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			want = global_position + away * 6.0 + Vector3.UP * 5.0
			flap = 1.0
			if fly_t <= 0.0:
				fly_mode = "wheel"
				fly_a = atan2(global_position.z - centre.z, global_position.x - centre.x)
				fly_t = randf_range(3.0, 7.0)
	var to := want - global_position
	var v := to.normalized() * minf(spd, to.length() * 2.0) if to.length() > 0.05 else Vector3.ZERO
	var prev := velocity
	velocity = velocity.lerp(v, 1.0 - exp(-2.5 * d))
	global_position += velocity * d
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.3:
		face_yaw = lerp_angle(face_yaw, atan2(velocity.x, velocity.z), 1.0 - exp(-4.0 * d))
	var turn := wrapf(atan2(velocity.x, velocity.z) - atan2(prev.x, prev.z), -PI, PI) / maxf(d, 0.001)
	model.rotation.y = face_yaw
	Vulture.pose(model, t, flap if velocity.y < 1.0 else 1.0, clampf(turn * 0.25, -0.6, 0.6), clampf(atan2(velocity.y, hv.length() + 0.01), -0.9, 0.6))

func _fall_from_sky() -> void:
	var g: float = Game.height(global_position.x, global_position.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 60.0, 1))
	if not hit.is_empty():
		g = maxf(g, float(hit.position.y))
	var tw := create_tween()
	var tt := sqrt(maxf(0.1, global_position.y - g) / 6.0)
	tw.tween_property(self, "global_position:y", g + 0.15, tt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "rotation:z", PI * 0.9, tt)
	Vulture.pose(model, 0.0, 0.0, 0.0, 0.0)

func _twist_setup() -> void:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		lt = LegTwist.new()
		sk.add_child(lt)
		lt.setup(sk)

func hit(amount: float, at: Vector3, dir: Vector3) -> void:
	if dead:
		return
	if Game.dev.onehit:
		amount = maxf(amount, hp + 1.0)
	hp -= amount
	since_hit = 0.0
	flash = 0.12
	if Game.main and Game.main.town_shot:
		town_hit = true
	else:
		you_hit = true
	if ap and hp > 0.0:
		_one_shot(["Hit_Chest", "Hit_Head"][randi() % 2], 0.45)
	if def.get("robot", false) or type in MACHINES:
		# machines spark and ring instead of bleeding
		Game.main._puff(at, -dir, Color(1.0, 0.8, 0.35, 0.95), 10, 3.0)
		Sfx.play_at("k_metal_click", at, -2.0, randf_range(1.2, 1.6))
	else:
		Game.main.blood(at, dir)
	Sfx.play_at(("o_bark2" if quad else ["o_mhurt1", "o_mhurt2"][randi() % 2]), at, 0.0, randf_range(0.9, 1.1))
	if hp <= 0.0 and essential:
		if hostile:
			Game.main.npc_yield(self)
		hp = 1.0
		return
	if hp <= 0.0:
		die(dir)
	else:
		if state != "chase":
			alert()
		state = "chase"
		if not hostile and eid != "" and Game.main:
			hostile = true
			Game.main.make_hostile(eid)
		hostile = true
		velocity += dir * 2.0

func _give_up() -> void:
	state = "idle"
	tac = "advance"
	lost_t = 0.0
	last_seen = Vector3.ZERO
	aiming = false
	target = home
	wait = randf_range(6.0, 10.0)
	if bark_cd <= 0.0 and not quad:
		bark_cd = 6.0
		Sfx.play_at("o_creature1", global_position + Vector3.UP, -6.0, 1.2)

# a gang that watches its own fall loses heart: the ones near a death may break and run for a few seconds (the
# mindless don't: ghouls, glow-husks, machines; nor bosses)
func _morale_hit(at: Vector3) -> void:
	if dead or not hostile or state != "chase" or def.get("boss", false) or def.get("robot", false) or type in ["ghoul", "glowhusk", "brute"]:
		return
	if global_position.distance_to(at) > 22.0:
		return
	var fallen := 0
	var standing := 0
	for e in Game.main.enemies:
		if is_instance_valid(e) and e.global_position.distance_to(at) < 25.0 and e.type == type:
			if e.dead:
				fallen += 1
			else:
				standing += 1
	var p := 0.12 + 0.18 * fallen - 0.06 * standing + (0.25 if hp / hp_max < 0.5 else 0.0)
	if randf() < p:
		tac = "flee"
		tac_t = randf_range(3.0, 6.0)

func die(dir: Vector3) -> void:
	dead = true
	if Game.main:
		for e in Game.main.enemies:
			if e != self and is_instance_valid(e):
				e._morale_hit(global_position)
	if Game.perks.has("bloody_mess") and Game.main and not def.get("robot", false):
		for i in 4:
			Game.main.blood(global_position + Vector3(randf() - 0.5, 0.6 + randf(), randf() - 0.5), Vector3(randf() - 0.5, 0.8, randf() - 0.5).normalized())
	if npc != null and Game.main:
		Game.main.npc_died(self)
	if idx >= 0:
		Game.dead[str(idx)] = true
	state = "dead"
	if fly:
		collision_layer = 0
		Sfx.play_at("o_creature2", global_position, 0.0, 1.3)
		_fall_from_sky()
		Game.on_kill(type, eid)
		if you_hit or not town_hit:
			Game.add_xp(int(def.get("xp", 24)) if def.get("xp") != null else 24)
		return
	collision_layer = 0
	Sfx.play_at("o_creature2" if quad else ["o_mdie1", "o_mdie2"][randi() % 2], global_position + Vector3.UP)
	# the pose helpers stop holding the body up: the aim on the arms, the twist through the hips and legs
	# (left running, they kept some of the dead standing - build 17 report)
	if aim_hold:
		aim_hold.active = false
	if lt:
		lt.active = false
	velocity = Vector3.ZERO
	if ap:
		ap.active = true
		ap.speed_scale = 1.0
		ap.play("Death01", 0.1)
		ap.seek(0.0, true)
		Game.on_kill(type, eid)
		if you_hit or not town_hit:
			Game.add_xp(int(def.get("xp", 40)) if def.get("xp") != null else 40)
		return
	var tw := create_tween()
	var side := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(model, "rotation:z", side * PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.25 if quad else 0.3, 0.45)
	Game.on_kill(type, eid)
	if you_hit or not town_hit:
		Game.add_xp(int(def.get("xp", 25 if quad else 40)) if def.get("xp") != null else (25 if quad else 40))

func hear(at: Vector3) -> void:
	if not dead and hostile and global_position.distance_to(at) < 60.0:
		state = "chase"

# line of sight through the world (not through you or itself: both sit on the world's collision layer)
func can_see(p: Vector3, from := Vector3.INF) -> bool:
	if Game.dev.invis:
		return false
	var a := (global_position if from == Vector3.INF else from) + Vector3.UP * 1.2
	if Nade.Cloud.blocks(a, p + Vector3.UP * 1.3):
		return false
	var q := PhysicsRayQueryParameters3D.create(a, p + Vector3.UP * 1.3, 1)
	q.exclude = [get_rid(), Game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# a shout brings the rest of its group (or anything hostile close by) into the fight
# the shout carries, but not everyone drops what they're doing at once: the nearest come first, the rest a beat
# later, and anything far off only if it can actually hear
func alert() -> void:
	for e in Game.main.enemies:
		if e != self and is_instance_valid(e) and not e.dead and e.hostile and e.state != "chase":
			var dd: float = e.global_position.distance_to(global_position)
			if dd < 18.0:
				e._join_later(0.2 + dd * 0.12 + randf() * 1.2)

var joining := false
func _join_later(delay: float) -> void:
	if joining:
		return
	joining = true
	await get_tree().create_timer(delay, false).timeout
	joining = false
	if is_instance_valid(self) and not dead and state != "chase":
		state = "chase"
		tac = "advance"

# only a few can be on you at once: the others hang back in a loose ring, waiting for a gap, as a real pack or gang
# would (and the gunmen take turns rather than all firing together)
static func _closers(pp: Vector3, me) -> int:
	var n := 0
	for e in Game.main.enemies:
		if e != me and is_instance_valid(e) and not e.dead and e.hostile and e.state == "chase" and not e.ranged and e.global_position.distance_to(pp) < 4.5:
			n += 1
	return n

static var shots: Array = []   # recent shot times, all gunmen together
static func _may_fire() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	while not shots.is_empty() and now - float(shots[0]) > 1.2:
		shots.pop_front()
	return shots.size() < 4

func _fired() -> void:
	shots.append(Time.get_ticks_msec() / 1000.0)

func _physics_process(d: float) -> void:
	if Game.dev.noai and not dead:
		velocity = Vector3.ZERO
		return
	t += d
	if flash > 0.0:
		flash -= d
	if dead:
		return
	if not bleed.is_empty():
		bleed[1] = float(bleed[1]) - d
		hp -= float(bleed[0]) * d
		if hp <= 0.0:
			die(Vector3.UP)
			return
		if float(bleed[1]) <= 0.0:
			bleed = []
	slow = maxf(0.0, slow - d)
	if fly:
		_fly(d)
		return
	if caged:
		# pacing the cage, watching you
		velocity = Vector3(0, -0.5 if is_on_floor() else -6.0, 0)
		move_and_slide()
		var to := Game.player.global_position - global_position
		face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-3.0 * d))
		if model:
			model.rotation.y = face_yaw
		if rig:
			rig.animate(d, 0.4 + 0.4 * sin(t * 1.7), t, false)
		return
	if stun > 0.0:
		# reeling: no shooting, no chasing, a stagger on the spot
		stun -= d
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-6.0 * d))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-6.0 * d))
		velocity.y = -6.0 if not is_on_floor() else -0.5
		move_and_slide()
		if ap:
			Humanoid.play(ap, "Hit_Head" if ap.has_animation("Hit_Head") else "Idle", 0.6)
		if aim_hold:
			aim_hold.target_w = 0.0
		return
	var P := Game.player
	var pp := P.global_position
	var dist := global_position.distance_to(pp)
	# a companion closer than you draws the fight
	foe = null
	if state == "chase" and hostile:
		for c in Game.main.party:
			if c.down <= 0.0:
				var cd: float = global_position.distance_to(c.global_position)
				if cd < dist * 0.8 and cd < 30.0:
					foe = c
					pp = c.global_position
					dist = cd
		# and so does a town guard who's shooting at it (build 19)
		for c in Game.main.defenders:
			if is_instance_valid(c) and c.visible and c.down <= 0.0 and not c.hostile:
				var cd: float = global_position.distance_to(c.global_position)
				if cd < dist * 0.8 and cd < 34.0:
					foe = c
					pp = c.global_position
					dist = cd
	var is_near := dist < 55.0
	if ap and is_near != near:
		near = is_near
		ap.active = near
	if dist > 90.0 and state != "chase":
		return
	act_t -= d
	atk_cd -= d
	bark_cd -= d
	var spd := 0.0
	var aim := false
	if Game.hp <= 0.0 and state == "chase":
		state = "idle"
	match state:
		"idle":
			aiming = false
			wait -= d
			if wait <= 0.0:
				var a := randf() * TAU
				target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 10.0)
				wait = randf_range(4.0, 9.0)
			if global_position.distance_to(target) > 1.0:
				spd = _move_to(target, speed * 0.35, d)
			# what it notices depends on you: sneaking, standing still and being behind it all help
			var vis: float = Game.player.visibility() if Game.player and foe == null else 1.0
			var facev := Vector3(sin(face_yaw), 0, cos(face_yaw))
			var tov := pp - global_position
			tov.y = 0.0
			if tov.length() > 0.1 and facev.dot(tov.normalized()) < -0.2:
				vis *= 0.55
			if hostile and Game.hp > 0.0 and dist < (24.0 if quad else 30.0) * vis and int(t * 4.0) % 2 == 0 and can_see(pp):
				state = "chase"
				tac = "advance"
				alert()
				if bark_cd <= 0.0:
					bark_cd = 4.0
					Sfx.play_at("o_bark1" if quad else "o_creature1", global_position + Vector3.UP, -2.0)
		"chase":
			if dist > 70.0:
				state = "idle"
			# it hunts what it last saw, not you through the walls; lose it long enough, far enough from home,
			# and it gives up and goes back (build 17: "mobs swarm you relentlessly")
			look_t -= d
			if look_t <= 0.0:
				look_t = 0.25
				saw = dist < 4.0 or foe != null or can_see(pp)
			if saw:
				lost_t = 0.0
				last_seen = pp
			else:
				lost_t += d
			if lost_t > 2.5 and last_seen != Vector3.ZERO:
				pp = last_seen
				dist = global_position.distance_to(pp)
				if dist < 2.0 and lost_t > 6.0 or lost_t > 16.0 or global_position.distance_to(home) > 110.0 and lost_t > 4.0:
					_give_up()
			var r := _tactics(d, pp, dist)
			spd = r[0]
			aim = r[1]
	if spd == 0.0:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * d))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * d))
	# a hostile standing still on the ground skips the physics step
	if spd > 0.0 or not is_on_floor() or Vector2(velocity.x, velocity.z).length() > 0.05:
		velocity.y = -6.0 if not is_on_floor() else -0.5
		move_and_slide()
	model.rotation.y = face_yaw
	if dist < 55.0:
		if ap:
			if act_t <= 0.0:
				var a := "Idle"
				var zed: bool = type in ["ghoul", "glowhusk"]
				if spd > 2.0:
					a = "Jog_Fwd" if not zed or spd > 3.8 else "Zombie_Walk_Fwd"
				elif spd > 0.3:
					a = "Walk" if not zed else "Zombie_Walk_Fwd"
				elif zed:
					a = "Zombie_Idle"
				elif aim:
					a = "Crouch_Idle_Loop" if (def.get("sniper", false) or type == "sniper") and ap.has_animation("Crouch_Idle_Loop") else "Pistol_Aim_Neutral"
				var sgn := LegTwist.drive(lt, face_yaw, velocity) if spd > 0.3 else LegTwist.drive(lt, face_yaw, Vector3.ZERO)
				Humanoid.play(ap, a, (clampf(spd / 3.2, 0.8, 1.4) if spd > 2.0 else 1.0) * sgn)
			if aim_hold:
				# in a fight the gun stays up and on you, whatever the legs are doing
				# (only while it's actually facing you to shoot: held up while it walked somewhere else, the gun pointed
				# wherever its feet were going - build 17 report)
				var off := absf(wrapf(atan2(Game.player.global_position.x - global_position.x, Game.player.global_position.z - global_position.z) - face_yaw, -PI, PI))
				var fighting: bool = hostile and state == "chase" and aiming and off < 0.6
				aim_hold.target_w = 1.0 if fighting and act_t <= 0.0 else 0.0
				var tp: Vector3 = (foe.global_position if foe else Game.player.global_position) + Vector3.UP * 1.2
				var fp := global_position + Vector3.UP * 1.4
				aim_hold.pitch = atan2(tp.y - fp.y, Vector2(tp.x - fp.x, tp.z - fp.z).length()) if fighting else 0.0
		else:
			rig.animate(d, spd, t, aim)

# ---------------------------------------------------------------- fighting
# Animals and brawlers come at you from different sides, circle out of reach between bites and wind up each blow
# (step back and it misses). Gunmen keep a working distance, strafe while they shoot in bursts, back off when you
# close in, duck behind cover to recover when hurt, and break and run when nearly dead.
func _tactics(d: float, pp: Vector3, dist: float) -> Array:
	var spd := 0.0
	var aim := false
	tac_t -= d
	var sees := can_see(pp)
	seen_t = seen_t + d if sees else 0.0
	var leg := (0.55 if crip.has("legs") else 1.0) * (0.35 if slow > 0.0 else 1.0)
	var to := pp - global_position
	to.y = 0.0
	var dirv := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-dirv.z, 0, dirv.x)
	var hurt := hp / hp_max
	# nearly dead: run (bosses and the essential never do)
	if not fled and hurt < 0.22 and not def.get("boss", false) and not essential and randf() < 0.6:
		fled = true
		tac = "flee"
		tac_t = randf_range(4.0, 7.0)
	if tac == "flee":
		aiming = false
		if tac_t <= 0.0:
			tac = "advance"
		else:
			return [_move_to(global_position - dirv * 8.0 + side * strafe * 3.0, speed * leg, d), false]
	if windup > 0.0:
		windup -= d
		_face(pp, d)
		if windup <= 0.0:
			var reach := (1.9 if quad else 2.0) + 0.4
			if dist <= reach:
				_deal(dmg * randf_range(0.7, 1.2))
			atk_cd = 1.0 if quad else 1.1
			if quad or randf() < 0.5:
				tac = "circle"
				tac_t = randf_range(0.8, 1.6)
				strafe = 1.0 if randf() < 0.5 else -1.0
		return [0.0, false]
	if not ranged:
		aiming = false
		var reach := 1.9 if quad else 2.0
		if tac == "circle" and tac_t > 0.0:
			# back off a little and circle, then come again
			var ring := pp - dirv * 3.2 + side * strafe * 2.5
			return [_move_to(ring, speed * 0.8 * leg, d), false]
		tac = "advance"
		var crowd := _closers(pp, self)
		if dist > reach and dist < 7.5 and crowd >= (3 if quad else 2):
			# too many already on you: hold a loose ring, edge round, wait for a gap
			var ring2 := pp - dirv * randf_range(5.0, 6.0) + side * sin(t * 0.7 + slot) * 2.5
			_face(pp, d)
			return [_move_to(ring2, speed * 0.45 * leg, d), false]
		if dist > reach:
			# from far away, straight in; close up, come round to its own side of you
			var goal := pp
			if dist < 7.0:
				var off := Vector3(cos(slot), 0, sin(slot))
				goal = pp + off * reach * 0.8
				if goal.distance_to(global_position) < 0.6:
					goal = pp
			# zig-zag when you're pointing a gun at it
			var aimed := (-Game.player.global_transform.basis.z).dot(-dirv) > 0.96
			if aimed and dist > 4.0:
				goal += side * sin(t * 3.0 + slot) * 2.5
			spd = _move_to(goal, speed * leg * (1.15 if dist < 6.0 else 1.0), d)
		else:
			_face(pp, d)
		if atk_cd <= 0.0 and dist <= reach and sees:
			windup = 0.32 if quad else 0.4
			if not quad:
				_one_shot("Zombie_Scratch" if type in ["ghoul", "glowhusk"] and ap.has_animation("Zombie_Scratch") else ["Punch_Jab", "Punch_Cross"][randi() % 2], 0.6)
			Sfx.play_at("o_bark1" if quad else "k_cloth1", global_position + Vector3.UP, -3.0, randf_range(0.9, 1.1))
		return [spd, false]
	# ---- gunmen
	var want_lo := 7.0
	var want_hi := 20.0
	var reach_aim := 28.0
	var sniper: bool = def.get("sniper", false) or type == "sniper"
	if sniper:
		# a sharpshooter keeps far off and works from where it is (build 22: it used to run up on you like the rest)
		want_lo = 26.0
		want_hi = 58.0
		reach_aim = minf(float(def.get("range", 75.0)) - 5.0, 70.0)
	if hurt < 0.5 and tac != "cover" and tac != "peek" and tac_t <= 0.0 and randf() < 0.5:
		var c = _find_cover(pp)
		if c != null:
			cover = c
			tac = "cover"
			tac_t = randf_range(5.0, 8.0)
	match tac:
		"cover":
			if global_position.distance_to(cover) > 0.8:
				spd = _move_to(cover, speed * 1.1 * leg, d)
				# shoot back on the way if it can
				aim = sees and dist < 26.0
			else:
				_face(pp, d)
				hp = minf(hp_max, hp + hp_max * 0.03 * d)   # catching its breath behind the wall
				if tac_t <= 2.5 or (tac_t <= 4.0 and randf() < d):
					tac = "peek"
					tac_t = randf_range(2.0, 3.5)
					burst = 3
			if tac_t <= 0.0:
				tac = "strafe"
		"peek":
			# step out sideways until it can see you, empty a burst, then back
			if not sees:
				spd = _move_to(cover + side * strafe * 2.0, speed * leg, d)
			else:
				_face(pp, d)
				aim = true
			if tac_t <= 0.0 or burst <= 0:
				tac = "cover" if hurt < 0.5 else "strafe"
				tac_t = randf_range(2.5, 4.0)
		_:
			if sniper and dist < want_lo:
				# a sharpshooter caught close breaks off and runs for distance, then turns to shoot again
				spd = _move_to(global_position - dirv * 6.0 + side * strafe * 2.0, speed * 1.1 * leg, d)
				aim = dist > 14.0 and sees
			elif sniper and sees and dist <= want_hi:
				# in its spot: still, low, the rifle on you
				_face(pp, d)
				aim = true
			elif not sees or dist > want_hi:
				tac = "advance"
				# a sharpshooter only edges round for a line on you, never closer than its range
				var goal := pp if not sniper else global_position + side * strafe * 4.0 + dirv * (2.0 if dist > want_hi else 0.0)
				spd = _move_to(goal, speed * (0.6 if sniper else 1.0) * leg, d)
				aim = sees and dist < reach_aim
			elif dist < want_lo:
				# too close for comfort: give ground while shooting
				spd = _move_to(global_position - dirv * 3.0 + side * strafe, speed * 0.85 * leg, d)
				aim = true
			else:
				if tac != "strafe" or tac_t <= 0.0:
					tac = "strafe"
					tac_t = randf_range(1.2, 2.8)
					strafe = -strafe if randf() < 0.7 else strafe
				var sgoal := global_position + side * strafe * 2.0
				if can_see(pp, sgoal):
					spd = _move_to(sgoal, speed * 0.55 * leg, d)
				else:
					strafe = -strafe
				aim = true
			if spd < 0.5:
				_face(pp, d)
	aiming = aim and sees and dist < reach_aim
	if aiming:
		face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-12.0 * d))
		# it takes a moment to find you, then fires in bursts, and only down the barrel: never over its shoulder
		var off := absf(wrapf(atan2(to.x, to.z) - face_yaw, -PI, PI))
		if atk_cd <= 0.0 and seen_t > 0.35 and off < 0.35 and (burst > 0 or _may_fire()):
			if burst <= 0:
				burst = 2 + randi() % 2
			burst -= 1
			atk_cd = 0.35 if burst > 0 else randf_range(1.5, 2.3)
			_fired()
			_attack(dist, spd)
	return [spd, aim]

# somewhere 4-12 m away that a wall or a rock hides from you
func _find_cover(pp: Vector3) -> Variant:
	var best = null
	var bd := 1e9
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(4.0, 12.0)
		var c := global_position + Vector3(cos(a), 0, sin(a)) * r
		c.y = Game.height(c.x, c.z)
		if c.distance_to(pp) < 6.0 or absf(c.y - global_position.y) > 2.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 1.5, c + Vector3.UP * 1.0, 1)
		q.exclude = [get_rid(), Game.player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var sc := c.distance_to(global_position) - c.distance_to(pp) * 0.3
		if sc < bd:
			bd = sc
			best = c
	return best

func _deal(amount: float) -> void:
	if foe and is_instance_valid(foe):
		foe.hurt(amount)
	else:
		if Game.main and Game.main.hud:
			Game.main.hud.hurt_from(global_position + Vector3.UP * 1.2)
		Game.hurt(amount)
	if not ranged:
		Sfx.play_at("o_bark2" if quad else "x_flesh1", global_position + Vector3.UP, 0.0, randf_range(0.9, 1.1))

func _one_shot(anim: String, dur: float) -> void:
	if ap == null:
		return
	ap.play(anim, 0.06)
	ap.seek(0.0, true)
	act_t = dur

func _face(p: Vector3, d: float) -> void:
	var to := p - global_position
	face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-8.0 * d))

func _move_to(p: Vector3, spd: float, d: float) -> float:
	var next := p
	if Game.nav_ready:
		repath -= d
		if repath <= 0.0:
			agent.target_position = p
			repath = 0.4
		if not agent.is_navigation_finished():
			next = agent.get_next_path_position()
	var to := next - global_position
	to.y = 0
	if to.length() < 0.05:
		return 0.0
	var v := to.normalized() * spd
	# keep a little room between pack members
	for e in Game.main.enemies:
		if e != self and is_instance_valid(e) and not e.dead:
			var aw: Vector3 = global_position - e.global_position
			aw.y = 0.0
			var l := aw.length()
			if l < 1.7 and l > 0.01:
				v += aw / l * (1.7 - l) * spd * 1.6
	velocity.x = lerpf(velocity.x, v.x, 1.0 - exp(-8.0 * d))
	velocity.z = lerpf(velocity.z, v.z, 1.0 - exp(-8.0 * d))
	if not aiming:
		face_yaw = lerp_angle(face_yaw, atan2(v.x, v.z), 1.0 - exp(-8.0 * d))
	return Vector2(velocity.x, velocity.z).length()

func _attack(dist: float, moving := 0.0) -> void:
	_one_shot("Pistol_Shoot", 0.3)
	Sfx.play_at("pistol_far" if dist > 14.0 else "pistol", global_position + Vector3.UP * 1.4, -2.0, randf_range(0.9, 1.05))
	var tp: Vector3 = (foe.global_position if foe else Game.player.global_position) + Vector3.UP * 1.3
	var miss := 1.5
	# harder to hit you when you're moving fast, and it shoots worse on the move
	var pv: Vector3 = Game.player.velocity if not foe else Vector3.ZERO
	var you_move := clampf(Vector2(pv.x, pv.z).length() / 6.0, 0.0, 1.0)
	var chance := clampf(0.78 - dist * 0.02, 0.22, 0.78) * (0.6 if crip.has("arms") else 1.0) * (1.0 - you_move * 0.35) * (0.8 if moving > 0.5 else 1.0)
	var hit_it := randf() < chance
	var from := global_position + Vector3.UP * 1.4 + Vector3(sin(face_yaw), 0, cos(face_yaw)) * 0.5
	var to := tp + (Vector3.ZERO if hit_it else Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * miss * 2.0)
	Game.main.tracer(from, to)
	# build 23: its muzzle flashes and smokes, and a miss kicks up whatever it lands in behind you
	GunFX.muzzle_at(Game.main, from, to - from, 1.0)
	if not hit_it:
		var q := PhysicsRayQueryParameters3D.create(from, from + (to - from).normalized() * 60.0, 1)
		q.exclude = [get_rid(), Game.player.get_rid()]
		var mh := get_world_3d().direct_space_state.intersect_ray(q)
		if mh:
			GunFX.impact(Game.main, mh.position, mh.normal, GunFX.surface(mh))
	if hit_it:
		_deal(dmg * randf_range(0.7, 1.1))
