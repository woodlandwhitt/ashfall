# Third-person view (a setting): your own body in the vault suit, seen over the right shoulder. It walks, jogs,
# crouches, strafes (hips turning toward where you're going, chest on where you're aiming), raises the gun when you
# have one out and holds it in the right hand. The camera swings round with your aim and pulls in rather than
# going through a wall. The crosshair still aims from the centre of the screen, so shooting works as in first person.
class_name ThirdPerson
extends Node3D

const OFFSET := Vector3(0.55, 0.32, 2.7)
var p                       # the player
var on := false
var body: Node3D
var ap: AnimationPlayer
var lt: LegTwist
var held: Node3D
var held_id := ""
var cam_d := 2.7

static func load_on() -> bool:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		return bool(cf.get_value("view", "third", false))
	return false

static func save_on(v: bool) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("view", "third", v)
	cf.save("user://settings.cfg")

func setup(player) -> void:
	p = player
	body = Humanoid.build("Male_Peasant", Color(0.2, 0.33, 0.62), Color(0.95, 0.8, 0.68))
	Humanoid.add_hair(body, Humanoid.HAIR_M[1], Color(0.25, 0.18, 0.12))
	add_child(body)
	body.rotation.y = PI
	ap = body.get_node("AnimationPlayer")
	var sk := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		lt = LegTwist.new()
		sk.add_child(lt)
		lt.setup(sk)
	body.visible = false

func set_on(v: bool) -> void:
	on = v
	body.visible = v
	p.gun.visible = not v
	if not v:
		p.cam.position = Vector3(0, p.eye_h, 0)

func _weapon() -> void:
	if held_id == Game.weapon:
		return
	held_id = Game.weapon
	if held:
		held.queue_free()
		held = null
	var it := Game.item(Game.weapon)
	if Game.weapon != "" and String(it.get("kind", "")) != "melee":
		var mdl: Array = p.world_model(Game.weapon)
		if not mdl.is_empty():
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			held = Humanoid.hold_gun(body, load(mdl[0]), mdl[1], mdl[2])

func update(d: float) -> void:
	if not on:
		return
	_weapon()
	# the camera, over the right shoulder, pitched with your aim, pulled in where a wall would be in the way
	var pivot := Vector3(0, p.eye_h - 0.05, 0)
	var off: Vector3 = Basis(Vector3.RIGHT, p.pitch) * OFFSET
	var from: Vector3 = p.global_transform * pivot
	var to: Vector3 = p.global_transform * (pivot + off)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [p.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var want := OFFSET.length()
	if not hit.is_empty():
		want = maxf(0.4, from.distance_to(hit.position) - 0.25)
	cam_d = lerpf(cam_d, want, 1.0 - exp(-(20.0 if want < cam_d else 4.0) * d))
	p.cam.position = pivot + off.normalized() * cam_d
	# the body: what it's doing
	var v: Vector3 = p.velocity
	var hs := Vector2(v.x, v.z).length()
	var armed: bool = held != null
	var a := "Idle"
	if p.crouch:
		a = "Crouch_Fwd" if hs > 0.4 else "Crouch_Idle"
	elif not p.is_on_floor():
		a = "Jump"
	elif hs > 4.5:
		a = "Jog_Fwd"
	elif hs > 0.4:
		a = "Walk"
	elif armed:
		a = "Pistol_Aim_Neutral" if p.trigger or p.fire_cd > 0.0 else "Pistol_Idle"
	if not ap.has_animation(a):
		a = a + "_Loop" if ap.has_animation(a + "_Loop") else "Idle"
	# body faces where you aim; moving sideways or back turns the hips (or plays the walk backwards)
	var face: float = p.yaw + PI
	var sgn := LegTwist.drive(lt, face, v if hs > 0.4 else Vector3.ZERO)
	Humanoid.play(ap, a, (clampf(hs / 3.2, 0.8, 1.5) if hs > 0.4 else 1.0) * sgn)
