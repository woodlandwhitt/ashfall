# A townsperson: a Quaternius body dressed and coloured from the original game's look for them, idling, wandering
# and talking with the Universal Animation Library. Animals keep their original model. Turns to face you when you talk.
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
	var look: Dictionary = d.get("look", {})
	if id in ANIMALS:
		model = (load("res://data/chars/npc_" + id + ".glb") as PackedScene).instantiate()
		rig = Rig.new(model, true)
	else:
		var fem: bool = look.get("fem", false)
		var hooded: bool = look.get("hat") == "hood" or look.get("coat") != null
		var cols := look_colors(look)
		model = Humanoid.build(("Female_" if fem else "Male_") + ("Ranger" if hooded else "Peasant"), cols[0], cols[1])
		model.scale = Vector3.ONE * float(look.get("bulk", 1.0)) if float(look.get("bulk", 1.0)) > 1.0 else Vector3.ONE
		ap = model.get_node("AnimationPlayer")
	add_child(model)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 140.0
	model.rotation.y = face_yaw
	if ap:
		ap.play("Idle")
		ap.seek(randf() * 2.0, true)
	target = home

func _physics_process(d: float) -> void:
	t += d
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
		Humanoid.play(ap, "Idle_Talking" if talking else ("Walk" if moving else "Idle"))
	elif rig:
		rig.animate(d, spd, t)
