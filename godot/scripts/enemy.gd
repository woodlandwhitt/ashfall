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
var foe = null           # the companion it is fighting, or null for you
var crip := {}           # FOCUS hits: crippled legs slow it, crippled arms spoil its aim

# outfit, cloth tint, skin tint for the human hostiles
const PEOPLE := {
	"raider": ["Male_Ranger", Color(0.62, 0.5, 0.44), Color(1.0, 0.85, 0.75)],
	"jackal": ["Male_Peasant", Color(0.7, 0.58, 0.4), Color(0.85, 0.7, 0.6)],
	"heavy": ["Male_Ranger", Color(0.38, 0.38, 0.42), Color(0.8, 0.66, 0.56)],
	"marauder": ["Female_Ranger", Color(0.6, 0.32, 0.28), Color(1.0, 0.86, 0.78)],
	"pyro": ["Male_Peasant", Color(0.4, 0.37, 0.34), Color(0.75, 0.6, 0.5)],
	"ghoul": ["Male_Peasant", Color(0.48, 0.48, 0.4), Color(0.7, 0.85, 0.55)],
	"tollking": ["Male_Ranger", Color(0.75, 0.62, 0.3), Color(0.9, 0.75, 0.65)],
}

func setup(d: Dictionary, td: Dictionary) -> void:
	type = d.type
	def = td
	quad = bool(td.get("quad", false))
	ranged = bool(td.get("ranged", false)) and not quad
	hp_max = float(td.get("hp", 40)) if td.get("hp") != null else 40.0
	hp = hp_max
	speed = (float(td.speed) if td.get("speed") != null else 3.2) * (1.0 if quad else 0.85)
	speed = clampf(speed, 2.2, 6.5)
	dmg = float(td.dmg) if td.get("dmg") != null else 8.0
	hostile = bool(d.get("hostile", true))
	eid = String(d.get("id", "")) if d.get("id") != null else ""
	group = String(d.get("group", "")) if d.get("group") != null else ""
	position = Vector3(d.x, Game.height(d.x, d.z), d.z)
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
	if PEOPLE.has(type) and not quad:
		var p: Array = PEOPLE[type]
		model = Humanoid.build(p[0], p[1], p[2])
		if type == "heavy":
			model.scale = Vector3.ONE * 1.12
		add_child(model)
		ap = model.get_node("AnimationPlayer")
		if ranged:
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			Humanoid.hold_aligned(model, load("res://guns/Pistol_4.glb"), Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121), Vector3(0.0, -0.05, 0.07))
		ap.play("Pistol_Idle" if ranged else "Idle")
		ap.seek(randf() * 2.0, true)
	else:
		var ps: PackedScene = load(Game.char_path("enemy_" + type + ".glb"))
		model = ps.instantiate()
		add_child(model)
		rig = Rig.new(model, quad)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 150.0
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.2
	agent.radius = 0.5
	add_child(agent)
	target = home

func hit(amount: float, at: Vector3, dir: Vector3) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	if ap and hp > 0.0:
		_one_shot(["Hit_Chest", "Hit_Head"][randi() % 2], 0.45)
	Game.main.blood(at, dir)
	Sfx.play_at(("o_bark2" if quad else ["o_mhurt1", "o_mhurt2"][randi() % 2]), at, 0.0, randf_range(0.9, 1.1))
	if hp <= 0.0:
		die(dir)
	else:
		state = "chase"
		if not hostile and eid != "" and Game.main:
			hostile = true
			Game.main.make_hostile(eid)
		hostile = true
		velocity += dir * 2.0

func die(dir: Vector3) -> void:
	dead = true
	if idx >= 0:
		Game.dead[str(idx)] = true
	state = "dead"
	collision_layer = 0
	Sfx.play_at("o_creature2" if quad else ["o_mdie1", "o_mdie2"][randi() % 2], global_position + Vector3.UP)
	if ap:
		ap.active = true
		ap.play("Death01", 0.1)
		Game.on_kill(type, eid)
		Game.add_xp(int(def.get("xp", 40)) if def.get("xp") != null else 40)
		return
	var tw := create_tween()
	var side := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(model, "rotation:z", side * PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.25 if quad else 0.3, 0.45)
	Game.on_kill(type, eid)
	Game.add_xp(int(def.get("xp", 25 if quad else 40)) if def.get("xp") != null else (25 if quad else 40))

func hear(at: Vector3) -> void:
	if not dead and hostile and global_position.distance_to(at) < 60.0:
		state = "chase"

func can_see(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, p + Vector3.UP * 1.3, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(d: float) -> void:
	t += d
	if flash > 0.0:
		flash -= d
	if dead:
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
			wait -= d
			if wait <= 0.0:
				var a := randf() * TAU
				target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 10.0)
				wait = randf_range(4.0, 9.0)
			if global_position.distance_to(target) > 1.0:
				spd = _move_to(target, speed * 0.35, d)
			if hostile and Game.hp > 0.0 and dist < (24.0 if quad else 30.0) and int(t * 4.0) % 2 == 0 and can_see(pp):
				state = "chase"
				if bark_cd <= 0.0:
					bark_cd = 4.0
					Sfx.play_at("o_bark1" if quad else "o_creature1", global_position + Vector3.UP, -2.0)
		"chase":
			if dist > 70.0:
				state = "idle"
			var reach := 1.7 if quad else (18.0 if ranged else 1.8)
			var sees := dist < reach + 4.0 and can_see(pp)
			if dist > reach or not sees:
				spd = _move_to(pp, speed * (0.55 if crip.has("legs") else 1.0), d)
			else:
				_face(pp, d)
			if ranged and dist < 26.0 and sees:
				aim = true
			if atk_cd <= 0.0 and dist <= reach and sees:
				atk_cd = 1.1 if quad else (1.3 if ranged else 1.0)
				_attack(dist)
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
				if spd > 2.0:
					a = "Jog_Fwd"
				elif spd > 0.3:
					a = "Walk"
				elif aim:
					a = "Pistol_Aim_Neutral"
				elif ranged:
					a = "Pistol_Idle"
				Humanoid.play(ap, a, clampf(spd / 3.2, 0.8, 1.4) if spd > 2.0 else 1.0)
		else:
			rig.animate(d, spd, t, aim)

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
	velocity.x = lerpf(velocity.x, v.x, 1.0 - exp(-8.0 * d))
	velocity.z = lerpf(velocity.z, v.z, 1.0 - exp(-8.0 * d))
	face_yaw = lerp_angle(face_yaw, atan2(v.x, v.z), 1.0 - exp(-8.0 * d))
	return Vector2(velocity.x, velocity.z).length()

func _attack(dist: float) -> void:
	if not quad and not ranged:
		_one_shot(["Punch_Jab", "Punch_Cross"][randi() % 2], 0.55)
	if quad or not ranged:
		Sfx.play_at("o_bark2" if quad else "x_flesh1", global_position + Vector3.UP, 0.0, randf_range(0.9, 1.1))
		if foe:
			foe.hurt(dmg * randf_range(0.7, 1.2))
		else:
			Game.hurt(dmg * randf_range(0.7, 1.2))
		return
	_one_shot("Pistol_Shoot", 0.35)
	Sfx.play_at("pistol_far" if dist > 14.0 else "pistol", global_position + Vector3.UP * 1.4, -2.0, randf_range(0.9, 1.05))
	var tp: Vector3 = (foe.global_position if foe else Game.player.global_position) + Vector3.UP * 1.3
	Game.main.tracer(global_position + Vector3.UP * 1.4 + Vector3(sin(face_yaw), 0, cos(face_yaw)) * 0.5, tp + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 1.5)
	var chance := clampf(0.75 - dist * 0.022, 0.2, 0.75) * (0.6 if crip.has("arms") else 1.0)
	if randf() < chance:
		if foe:
			foe.hurt(dmg * randf_range(0.7, 1.1))
		else:
			Game.hurt(dmg * randf_range(0.7, 1.1))
