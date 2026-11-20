# A townsperson: stands (or wanders), turns to face you when you talk, and has a dialogue tree in Game.DIALOGUE.
extends CharacterBody3D

var id := ""
var display_name := ""
var model: Node3D
var rig: Rig
var home := Vector3.ZERO
var wander_r := 0.0
var target := Vector3.ZERO
var wait := 0.0
var face_yaw := 0.0
var talking := false
var t := 0.0

func setup(d: Dictionary) -> void:
	id = d.id
	display_name = Game.DIALOGUE[id].name if Game.DIALOGUE.has(id) else String(d.name).capitalize()
	var y := Game.height(d.x, d.z)
	position = Vector3(d.x, y, d.z)
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
	var ps: PackedScene = load("res://data/chars/npc_" + id + ".glb")
	model = ps.instantiate()
	add_child(model)
	model.rotation.y = face_yaw
	rig = Rig.new(model, model.find_child("shinL", true, false) == null)
	target = home

func _physics_process(d: float) -> void:
	t += d
	if Game.player and global_position.distance_squared_to(Game.player.global_position) > 8100.0:
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
	if spd == 0.0:
		velocity.x = 0
		velocity.z = 0
	velocity.y = -6.0 if not is_on_floor() else -0.5
	move_and_slide()
	model.rotation.y = face_yaw
	# only animate characters near the camera
	if Game.player and global_position.distance_squared_to(Game.player.global_position) < 2500.0:
		rig.animate(d, spd, t)
