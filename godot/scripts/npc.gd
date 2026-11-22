# A townsperson: a Quaternius body dressed and coloured from the original game's look for them, idling, wandering
# and talking with the Universal Animation Library. Animals keep their original model. Turns to face you when you talk.
# Recruited companions (Jory, Sable, Biscuit the dog) follow you, pick fights with whatever is hunting you, get
# knocked down instead of dying and get back up, and walk out if your karma crosses their line.
extends CharacterBody3D

const ANIMALS := ["biscuit"]

var id := ""
var display_name := ""
var model: Node3D
var ap: AnimationPlayer
var rig: Rig
var home := Vector3.ZERO
var wander_r := 0.0
var target := Vector3.ZERO
var wait := 0.0
var face_yaw := 0.0
var talking := false
var t := 0.0
var moving := false
var near := true
# companion state
var comp: Dictionary = {}
var follow := false
var cstate := "follow"   # or "wait"
var hp := 100.0
var maxhp := 100.0
var down := 0.0
var cool := 0.0
var tgt = null
var think := 0.0
var bark_t := 0.0
var los := false
var held: Node3D = null
var idle_anim := "Idle"

static func look_colors(look: Dictionary) -> Array:
	var cloth := Color(0.85, 0.8, 0.72)
	if look.get("body"):
		cloth = Color(1, 1, 1).lerp(Color(look.body).lightened(0.3), 0.6)
	var skin := Color(1.0, 0.9, 0.82)
	if look.get("skin"):
		var c := Color(look.skin)
		skin = Color(clampf(c.r / 0.62, 0.45, 1.6), clampf(c.g / 0.45, 0.4, 1.6), clampf(c.b / 0.34, 0.35, 1.6))
	return [cloth, skin]

func setup(d: Dictionary) -> void:
	id = d.id
	display_name = Game.DIALOGUE[id].name if Game.DIALOGUE.has(id) else String(d.name).capitalize()
	position = Vector3(d.x, Game.height(d.x, d.z), d.z)
	home = position
	face_yaw = float(d.rot)
	if d.wander:
		wander_r = float(d.wander.r)
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	look = d.get("look", {})
	if id in ANIMALS:
		model = (load(Game.char_path("npc_" + id + ".glb")) as PackedScene).instantiate()
		rig = Rig.new(model, true)
	else:
		var role := ""
		if id in ["sheriff", "deputy", "guard12", "lamp1"] or id.begins_with("guard"):
			role = "guard"
		elif id in ["mayor", "overseer", "brannock", "boss", "cass"]:
			role = "boss"
		elif id in ["preacher", "doc_osei", "halloran", "teacher", "wick"]:
			role = "robe"
		model = Humanoid.person(look, hash(id), role)
		ap = model.get_node("AnimationPlayer")
		idle_anim = Humanoid.IDLES[absi(hash(id + "i")) % Humanoid.IDLES.size()]
	add_child(model)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 140.0
	model.rotation.y = face_yaw
	if ap:
		ap.play(idle_anim)
		ap.seek(randf() * 2.0, true)
	target = home

func _physics_process(d: float) -> void:
	t += d
	if follow:
		_companion(d)
		return
	var pd := 1e9
	if Game.player:
		pd = global_position.distance_squared_to(Game.player.global_position)
	# far away: no physics, no animation
	var is_near := pd < 2025.0
	if is_near != near:
		near = is_near
		if ap:
			ap.active = near
	if pd > 8100.0:
		return
	var spd := 0.0
	if talking and Game.player:
		var to := Game.player.global_position - global_position
		face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-6.0 * d))
	elif wander_r > 0.0:
		wait -= d
		var to := target - global_position
		to.y = 0
		if to.length() < 0.6 or wait < -14.0:
			if wait <= 0.0 and wait > -14.0 and to.length() < 0.6:
				wait = randf_range(2.0, 6.0)
			var a := randf() * TAU
			target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_r
		elif wait <= 0.0:
			var v := to.normalized() * 1.25
			velocity = Vector3(v.x, velocity.y, v.z)
			spd = 1.25
			face_yaw = lerp_angle(face_yaw, atan2(v.x, v.z), 1.0 - exp(-5.0 * d))
	moving = spd > 0.0
	# a standing person doesn't need the physics step at all
	if moving or not is_on_floor():
		if not moving:
			velocity.x = 0
			velocity.z = 0
		velocity.y = -6.0 if not is_on_floor() else -0.5
		move_and_slide()
	model.rotation.y = face_yaw
	if not near:
		return
	if ap:
		Humanoid.play(ap, "Idle_Talking" if talking else ("Walk" if moving else idle_anim))
	elif rig:
		rig.animate(d, spd, t)


# ---------------------------------------------------------------- companions (main.js updParty)
# shot, stabbed or blown up: the town turns on you (main.provoke)
var hostile := false
var look: Dictionary = {}

func hit(dmg: float, _at: Vector3, dir: Vector3) -> void:
	if follow or hostile or Game.main == null:
		return
	Game.main.provoke(self, dmg, dir)

func join(c: Dictionary, st: String) -> void:
	comp = c
	follow = true
	cstate = st
	maxhp = float(c.get("hp", 150))
	hp = maxhp
	down = 0.0
	wander_r = 0.0
	collision_layer = 0
	if ap and c.get("ranged", false) and held == null:
		held = Humanoid.hold_gun(model, load("res://guns/Pistol_4.glb"), Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121))

func leave() -> void:
	follow = false
	comp = {}
	tgt = null
	collision_layer = 4
	position = home
	model.rotation = Vector3(0, face_yaw, 0)
	if held:
		held.queue_free()
		held = null

func say(kind: String) -> void:
	bark_t = 0.0
	if comp.get("dog", false):
		Sfx.play_at("o_bark1", global_position + Vector3.UP * 0.5, 0.0)
		return
	var lines = comp.get("barks", {}).get(kind)
	if lines == null:
		return
	var line := String(lines if lines is String else lines[randi() % lines.size()])
	Game.msg(String(comp.n) + ": \"" + line + "\"")
	if Game.main:
		Game.main.speak(line, id)

func hurt(dmg: float) -> void:
	if down > 0.0:
		return
	hp -= dmg * (1.0 if comp.get("dog", false) else 0.8)
	if hp <= 0.0:
		hp = 0.0
		down = 16.0
		tgt = null
		Game.msg(String(comp.n) + " is down! They'll get back up.")
		say("hurt")
		if ap:
			ap.play("Death01", 0.15)
	elif hp < maxhp * 0.4 and bark_t > 9.0:
		say("hurt")

func _companion(d: float) -> void:
	bark_t += d
	var P = Game.player
	if P == null:
		return
	var pp: Vector3 = P.global_position
	if down > 0.0:
		down -= d
		if rig:
			model.rotation.z = lerpf(model.rotation.z, 1.4, minf(1.0, d * 6.0))
		if down <= 0.0:
			hp = maxhp * 0.4
			model.rotation.z = 0.0
			Game.msg(String(comp.n) + " is back on their feet.")
		return
	# your karma crossed their line
	if not comp.get("dog", false) and not comp.get("loyal", false) and ((comp.has("minKarma") and Game.karma < int(comp.minKarma)) or (comp.has("maxKarma") and Game.karma > int(comp.maxKarma))):
		say("leave")
		Game.main.dismiss(id, true)
		return
	cool -= d
	think -= d
	if think <= 0.0:
		think = 0.6
		if tgt != null and (not is_instance_valid(tgt) or tgt.dead or not tgt.hostile or tgt.global_position.distance_to(global_position) > 38.0):
			tgt = null
		if tgt == null:
			var best = null
			var bd := 32.0
			for e in Game.main.enemies:
				if e.dead or not e.hostile:
					continue
				var ed: float = e.global_position.distance_to(global_position)
				if (e.state == "chase" or e.global_position.distance_to(pp) < 22.0) and ed < bd:
					bd = ed
					best = e
			if best and bark_t > 12.0:
				say("combat")
			tgt = best
		if tgt and comp.get("ranged", false):
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.45, tgt.global_position + Vector3.UP * 1.0, 1)
			los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var mv := Vector3.ZERO
	var spd := 0.0
	var aiming := false
	var rng := float(comp.get("range", 30))
	var cspd := float(comp.get("spd", 5.5))
	if tgt and (cstate == "follow" or tgt.global_position.distance_to(global_position) < rng + 2.0):
		var to: Vector3 = tgt.global_position - global_position
		to.y = 0
		var ad := maxf(0.01, to.length())
		face_yaw = atan2(to.x, to.z)
		if comp.get("ranged", false):
			aiming = true
			if cstate == "follow" and (not los or ad > rng * 0.65):
				mv = to / ad
				spd = cspd
			elif ad < 5.0:
				mv = -to / ad
				spd = cspd * 0.6
			if cool <= 0.0 and los and ad < rng:
				cool = float(comp.get("atk", 0.8)) * randf_range(0.8, 1.2)
				_shoot(ad)
		else:
			if ad > rng * 0.8:
				mv = to / ad
				spd = cspd
			if ad < rng + 0.6 and cool <= 0.0:
				cool = float(comp.get("atk", 0.85))
				Sfx.play_at("o_bark2", global_position + Vector3.UP * 0.5, 0.0)
				tgt.hit(float(comp.get("dmg", 15)) * randf_range(0.85, 1.15), tgt.global_position + Vector3.UP * 0.6, to / ad)
	elif cstate == "follow":
		var side := -1.0 if comp.get("dog", false) else 1.0
		var fwd := Vector3(-sin(P.yaw), 0, -cos(P.yaw))
		var right := Vector3(cos(P.yaw), 0, -sin(P.yaw))
		var goal: Vector3 = pp - fwd * 2.4 + right * side * 1.5
		var to := goal - global_position
		to.y = 0
		var dd := to.length()
		if dd > 40.0:
			global_position = Vector3(goal.x, Game.height(goal.x, goal.z) + 0.2, goal.z)
		elif dd > 1.1:
			mv = to / dd
			spd = cspd if dd > 6.0 else (cspd * 0.7 if dd > 2.5 else cspd * 0.4)
			face_yaw = atan2(to.x, to.z)
		else:
			var tp := pp - global_position
			face_yaw = lerp_angle(face_yaw, atan2(tp.x, tp.z), minf(1.0, d * 2.0))
		if bark_t > 95.0 and randf() < d * 0.01 and not comp.get("dog", false):
			say("idle")
	velocity.x = mv.x * spd
	velocity.z = mv.z * spd
	velocity.y = -6.0 if not is_on_floor() else -0.5
	move_and_slide()
	model.rotation.y = face_yaw
	if ap:
		var a := "Idle"
		if spd > 3.0:
			a = "Jog_Fwd"
		elif spd > 0.3:
			a = "Walk"
		elif aiming:
			a = "Pistol_Aim_Neutral"
		Humanoid.play(ap, a)
	elif rig:
		rig.animate(d, spd, t)

func _shoot(ad: float) -> void:
	var from := global_position + Vector3.UP * 1.45 + Vector3(sin(face_yaw), 0, cos(face_yaw)) * 0.5
	var at: Vector3 = tgt.global_position + Vector3.UP * 1.0
	var ok := randf() < clampf(0.82 - ad / float(comp.get("range", 30)) * 0.4, 0.25, 0.85)
	if ap:
		ap.play("Pistol_Shoot", 0.05)
	Sfx.play_at("pistol_far" if global_position.distance_to(Game.player.global_position) > 14.0 else "pistol", from, -4.0, randf_range(0.85, 0.95))
	Game.main.tracer(from, at + (Vector3.ZERO if ok else Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 2.0), Color(1.0, 0.82, 0.5))
	if ok:
		tgt.hit(float(comp.get("dmg", 13)) * randf_range(0.85, 1.15), at, (at - from).normalized())
