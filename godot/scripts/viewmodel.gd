# First-person arms: the player's own body (a Quaternius outfit, sleeves dyed vault-suit blue) seen from inside the
# head, holding the pistol with the Universal Animation Library's aim / shoot / reload motions. Only the arms are
# drawn. The rig is placed so the head bone sits at the camera.
class_name Viewmodel
extends Node3D

var rig: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var gun: Node3D
var muzzle: Node3D
var base_pos := Vector3.ZERO
var state := ""
static var GRIP := Vector3(0.0, -0.05, 0.07)
const OFFSET := Vector3(0.06, 0.05, -0.05)

func setup(gun_scene: PackedScene) -> void:
	rig = Humanoid.build("Male_Peasant", Color(0.42, 0.55, 0.95), Color(0.9, 0.78, 0.7))
	add_child(rig)
	skel = rig.find_child("Skeleton3D", true, false)
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		m.visible = String(m.name).ends_with("_Arms")
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 2.0
	ap = rig.get_node("AnimationPlayer")
	ap.playback_default_blend_time = 0.12
	# face the rig away from the camera (characters face +Z, cameras look down -Z) and put its eyes at the camera
	rig.rotation.y = PI
	ap.play("Pistol_Aim_Neutral")
	ap.seek(0.0, true)
	gun = Humanoid.hold_aligned(rig, gun_scene, Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121), GRIP)
	for c in gun.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the muzzle is the front of the gun model's bounds, near the top; undo the model's scale for the flash
	var bb := AABB()
	var first := true
	for c in gun.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != gun:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	muzzle = Node3D.new()
	muzzle.position = Vector3(bb.end.x, bb.end.y - bb.size.y * 0.18, bb.get_center().z)   # the model points down +X before its fit
	muzzle.scale = Vector3.ONE / 0.121
	gun.add_child(muzzle)
	skel.force_update_all_bone_transforms()
	var head := skel.find_bone("Head")
	var eye_local: Vector3 = skel.get_bone_global_pose(head).origin + Vector3(0, 0.07, 0.09)
	var eye_in_rig: Vector3 = (skel.global_transform if skel.is_inside_tree() else skel.transform) * eye_local
	if skel.is_inside_tree():
		eye_in_rig = rig.global_transform.affine_inverse() * eye_in_rig
	base_pos = -(Basis(Vector3.UP, PI) * eye_in_rig) + OFFSET
	rig.position = base_pos
	state = "aim"

func shoot() -> void:
	ap.play("Pistol_Shoot", 0.03)
	ap.seek(0.0, true)
	state = "shoot"

func reload(dur: float) -> void:
	var a := ap.get_animation("Pistol_Reload")
	ap.play("Pistol_Reload", 0.1, a.length / dur)
	state = "reload"

func _process(_d: float) -> void:
	if state != "aim" and not ap.is_playing():
		ap.play("Pistol_Aim_Neutral", 0.15)
		state = "aim"

func muzzle_pos() -> Vector3:
	return muzzle.global_position
