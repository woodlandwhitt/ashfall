# First-person arms: the player's own body (a Quaternius outfit, sleeves dyed vault-suit blue) seen from inside the
# head, holding the equipped weapon with the Universal Animation Library's motions (pistol aim / shoot / reload for
# guns, sword idle / attack for blades and clubs, punches bare-handed). Only the arms are drawn. The rig is placed
# so the head bone sits at the camera.
class_name Viewmodel
extends Node3D

var rig: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var gun: Node3D
var muzzle: Node3D
var base_pos := Vector3.ZERO
var state := ""
var idle_anim := "Pistol_Aim_Neutral"
var attack_anim := "Pistol_Shoot"
var can_reload := true
static var GRIP := Vector3(0.0, -0.05, 0.07)
const OFFSET := Vector3(0.0, 0.0, 0.0)
# turn the arms about the eye: down and to the right, so you look over the gun instead of at the back of your hands
const TILT := Vector3(-0.04, -0.07, 0.0)

func _make_rig() -> void:
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
	# characters face +Z, cameras look down -Z
	rig.rotation.y = PI

# put the head bone (in the current pose) at the camera, then nudge the arms down and right
func _place() -> void:
	skel.force_update_all_bone_transforms()
	var head := skel.find_bone("Head")
	var eye_local: Vector3 = skel.get_bone_global_pose(head).origin + Vector3(0, 0.07, 0.09)
	var eye_in_rig: Vector3 = skel.transform * eye_local
	var n: Node = skel.get_parent()
	while n != rig and n is Node3D:
		eye_in_rig = (n as Node3D).transform * eye_in_rig
		n = n.get_parent()
	base_pos = -(Basis(Vector3.UP, PI) * eye_in_rig) + OFFSET
	rig.position = base_pos
	rotation = TILT
	state = "aim"

# turn and move the whole rig (arms and gun together) so the gun points straight at the crosshair and sits where the
# WebView build put it: centred 0.2 m right of the eye, its top at 'sight' over and its back at 'rear' behind the
# hip-fire spot (0.2, -0.17, -0.5) in camera space (entities.js makeGun / GUNFIT). The hands keep their grip.
func _align(fit: Basis, bb: AABB, gf: Dictionary) -> void:
	skel.force_update_all_bone_transforms()
	var hb := skel.get_bone_global_pose(skel.find_bone("hand_r"))
	var sk := Transform3D.IDENTITY
	var n: Node = skel
	while n != rig and n is Node3D:
		sk = (n as Node3D).transform * sk
		n = n.get_parent()
	var g_vm: Transform3D = rig.transform * sk * hb * gun.transform
	var inv := fit.orthonormalized().inverse()
	var fwd_m := (inv * Vector3(0, 0, -1)).normalized()
	var up_m := (inv * Vector3.UP).normalized()
	var f := (g_vm.basis * fwd_m).normalized()
	var u := (g_vm.basis * up_m).normalized()
	u = (u - f * u.dot(f)).normalized()
	var zc := -f
	var xc := u.cross(zc).normalized()
	var R := Basis(xc, u, zc).transposed()
	rig.transform = Transform3D(R, Vector3.ZERO) * rig.transform
	g_vm = Transform3D(R, Vector3.ZERO) * g_vm
	var c := bb.get_center()
	var half_len := absf(fwd_m.dot(bb.size)) * 0.5
	var half_h := absf(up_m.dot(bb.size)) * 0.5
	var rear_top: Vector3 = g_vm * (c - fwd_m * half_len + up_m * half_h)
	var centre: Vector3 = g_vm * c
	var long: bool = not gf.get("pistol", false)
	# long guns come back to the shoulder (our arms are shorter than the WebView build's floating ones)
	var want := Vector3(0.17 if long else 0.2, -0.17 + float(gf.get("sight", 0.07)) + (0.03 if long else 0.0), -0.5 + float(gf.get("rear", 0.07)) + (0.24 if long else 0.0))
	rig.position += Vector3(want.x - centre.x, want.y - rear_top.y, want.z - rear_top.z)
	base_pos = rig.position
	rotation = Vector3.ZERO
	# long guns: the left hand goes out to the handguard (IK on the left arm, run after the animation each frame)
	if not gf.get("pistol", false) and skel.find_bone("upperarm_l") >= 0:
		var tgt := Node3D.new()
		gun.add_child(tgt)
		var sc := fit.get_scale().x
		tgt.position = Humanoid.guard_fit(bb, fit, gf)
		var ik := ArmIK.new()
		skel.add_child(ik)
		ik.setup(skel, "l", tgt)
		if OS.get_cmdline_user_args().has("--ikdbg"):
			var names := []
			for i in [skel.find_bone("upperarm_l"), skel.find_bone("lowerarm_l"), skel.find_bone("hand_l")]:
				names.append(skel.get_bone_name(skel.get_bone_parent(i)))
			print("IKDBG parents ", names)
		ik_tgt = tgt

func _no_shadow(n: Node) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# a gun: fit turns the model so its muzzle points down -Z at real size (from the WebView build's GUNFIT table)
func setup(gun_scene: PackedScene, fit: Basis, gf: Dictionary = {}) -> void:
	_make_rig()
	ap.play("Pistol_Aim_Neutral")
	ap.seek(0.0, true)
	gun = Humanoid.hold_gun(rig, gun_scene, fit, gf)
	_no_shadow(gun)
	# the muzzle is the front of the model's bounds along its own forward axis, near the top
	var bb := AABB()
	var first := true
	for c in gun.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != gun:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	muzzle = Node3D.new()
	var fwd := (fit.inverse() * Vector3(0, 0, -1)).normalized()
	var c := bb.get_center()
	var top := bb.end.y - bb.size.y * 0.18
	if absf(fwd.x) > 0.7:
		muzzle.position = Vector3(bb.end.x if fwd.x > 0 else bb.position.x, top, c.z)
	elif absf(fwd.z) > 0.7:
		muzzle.position = Vector3(c.x, top, bb.end.z if fwd.z > 0 else bb.position.z)
	else:
		muzzle.position = c
	muzzle.scale = Vector3.ONE / maxf(0.001, fit.get_scale().x)
	gun.add_child(muzzle)
	idle_anim = "Pistol_Aim_Neutral"
	attack_anim = "Pistol_Shoot"
	_place()
	_align(fit, bb, gf)

# melee: a blade or club (or bare fists) in the right hand
func setup_melee(armed: bool, id: String) -> void:
	_make_rig()
	idle_anim = "Sword_Idle" if armed else "Pistol_Aim_Neutral"
	attack_anim = "Sword_Attack" if armed else "Punch_Jab"
	can_reload = false
	ap.play("Pistol_Aim_Neutral")
	ap.seek(0.0, true)
	if armed:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var long: bool = id in ["machete", "sledge", "bat"]
		bm.size = Vector3(0.03, 0.09 if id == "sledge" else 0.03, 0.7 if long else 0.28)
		blade.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.42, 0.3) if id in ["bat", "sledge"] else Color(0.7, 0.72, 0.75)
		m.metallic = 0.0 if id == "bat" else 0.7
		m.roughness = 0.5
		blade.material_override = m
		blade.position = Vector3(0, 0, -bm.size.z * 0.5)
		var holder := Node3D.new()
		holder.add_child(blade)
		var ba := BoneAttachment3D.new()
		ba.bone_name = "hand_r"
		skel.add_child(ba)
		skel.force_update_all_bone_transforms()
		var hb := skel.get_bone_global_pose(skel.find_bone("hand_r"))
		holder.transform = Transform3D(hb.basis.inverse() * Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), hb.basis.inverse() * Vector3(0, -0.02, 0.06))
		ba.add_child(holder)
		_no_shadow(holder)
		gun = holder
	muzzle = Node3D.new()
	(gun if gun else rig).add_child(muzzle)
	_place()
	ap.play(idle_anim)

func shoot() -> void:
	ap.play(attack_anim, 0.03)
	ap.seek(0.0, true)
	state = "shoot"

func reload(dur: float) -> void:
	if not can_reload:
		return
	var a := ap.get_animation("Pistol_Reload")
	ap.play("Pistol_Reload", 0.1, a.length / dur)
	state = "reload"

var dbg_t := 0
var ik_tgt: Node3D
func _process(_d: float) -> void:
	dbg_t += 1
	if dbg_t == 15 and ik_tgt and OS.get_cmdline_user_args().has("--ikdbg"):
		var hl := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand_l"))
		var ua := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("upperarm_l"))
		print("IKDBG tgt ", to_local(ik_tgt.global_position), " hand_l ", to_local(hl.origin), " upperarm_l ", to_local(ua.origin), " reach ", ua.origin.distance_to(ik_tgt.global_position))
	if state != "aim" and not ap.is_playing():
		ap.play(idle_anim, 0.15)
		state = "aim"

func muzzle_pos() -> Vector3:
	return muzzle.global_position
