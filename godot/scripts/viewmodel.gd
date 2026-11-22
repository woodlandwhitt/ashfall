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
		if m.visible and m.mesh:
			# only what actually touches the lens dissolves (the arms themselves stay solid)
			var fade := func(src: Material) -> Material:
				if not src is StandardMaterial3D:
					return src
				var mm := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				mm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				mm.distance_fade_min_distance = 0.04
				mm.distance_fade_max_distance = 0.09
				return mm
			if m.material_override:
				m.material_override = fade.call(m.material_override)
			else:
				for i in m.mesh.get_surface_count():
					var src: Material = m.get_surface_override_material(i)
					m.set_surface_override_material(i, fade.call(src if src else m.mesh.surface_get_material(i)))
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
	# long guns sit a little higher and closer than they did, so the hand on the grip stays in view
	var want := Vector3(0.19, -0.15 + float(gf.get("sight", 0.07)), -0.47 + float(gf.get("rear", 0.07)))
	if not long:
		# a handgun is held out at arm's length, a little lower, so you see along the top of the slide
		want += Vector3(0.01, -0.05, -0.13)
	rig.position += Vector3(want.x - centre.x, want.y - rear_top.y, want.z - rear_top.z)
	# tip the muzzle down a touch about the back of the gun: held level, a gun below the eye looks to point up
	var pivot := want
	var tip := Basis(Vector3.RIGHT, -0.06 if long else -0.14)
	rig.transform = Transform3D(tip, pivot - tip * pivot) * rig.transform
	base_pos = rig.position
	rotation = Vector3.ZERO
	_mount(sk, long, bb, fit, gf)

# The gun comes off the hand bone onto a mount fixed in front of the camera, and both hands are pinned to it with IK
# (the right on the grip, the left on the handguard or wrapped round the right), so animations can't pull the hands
# off the gun. Recoil and reloading move the mount; the arms follow.
var mount: Node3D
var kick: Node3D
var k_back := Vector3.BACK
var k_up := Vector3.UP
var k_right := Vector3.RIGHT
var guard_t: Node3D

func _mount(sk: Transform3D, long: bool, bb: AABB, fit: Basis, gf: Dictionary) -> void:
	skel.force_update_all_bone_transforms()
	var hb0 := skel.get_bone_global_pose(skel.find_bone("hand_r"))
	if OS.get_cmdline_user_args().has("--ikdbg"):
		var hr := skel.find_bone("hand_r")
		for i in skel.get_bone_count():
			if skel.get_bone_parent(i) == hr:
				print("IKDBG child ", skel.get_bone_name(i), " local ", hb0.affine_inverse() * skel.get_bone_global_pose(i).origin)
	var hl0 := skel.get_bone_global_pose(skel.find_bone("hand_l"))
	var mg: Transform3D = hb0 * gun.transform
	gun.get_parent().remove_child(gun)
	kick = Node3D.new()
	skel.add_child(kick)
	mount = Node3D.new()
	kick.add_child(mount)
	mount.transform = Transform3D(mg.basis.orthonormalized(), mg.origin)
	mount.add_child(gun)
	gun.transform = mount.transform.affine_inverse() * mg
	# camera-space directions in the skeleton's space
	var sk_from_vm: Transform3D = (rig.transform * sk).affine_inverse()
	var unit := (sk_from_vm.basis * Vector3(0, 0, 1)).length()
	k_back = sk_from_vm.basis * Vector3(0, 0, 1)
	k_up = sk_from_vm.basis * Vector3(0, 1, 0)
	k_right = sk_from_vm.basis * Vector3(1, 0, 0)
	# the right hand closes round the grip: back of the hand to the right, knuckles forward, thumb up (hand bones:
	# fingers along +Y, thumb side +Z, palm towards -X), the palm's centre on the grip point
	var vm_from_sk: Transform3D = rig.transform * sk
	var grip_vm: Vector3 = vm_from_sk * (mg * Humanoid.grip_fit(bb, fit, gf))
	var hy := Vector3(-0.22, 0.12 if long else 0.18, -1.0).normalized()
	var hx := Vector3(1.0, 0.0, -0.15)
	hx = (hx - hy * hx.dot(hy)).normalized()
	var hand_vm := Basis(hx, hy, hx.cross(hy).normalized())
	var wrist_vm := grip_vm - hand_vm * Vector3(-0.03, 0.065, 0.0)
	var rt := Node3D.new()
	mount.add_child(rt)
	var want_sk: Transform3D = sk_from_vm * Transform3D(hand_vm, wrist_vm)
	rt.transform = mount.transform.affine_inverse() * Transform3D(want_sk.basis.orthonormalized(), want_sk.origin)
	var ikr := ArmIK.new()
	skel.add_child(ikr)
	ikr.setup(skel, "r", rt)
	ikr.pin_rotation = true
	var lt := Node3D.new()
	if long:
		# a long gun comes back to the shoulder, the support hand under the handguard
		gun.add_child(lt)
		lt.position = Humanoid.guard_fit(bb, fit, gf)
		lt.rotation = Vector3.ZERO
		mount.position += sk_from_vm.basis * Vector3(-0.04, 0.0, 0.2)
	else:
		# a handgun is held two-handed: the left hand cups the right from below
		mount.add_child(lt)
		var cup: Vector3 = sk_from_vm * (grip_vm + Vector3(-0.05, -0.045, 0.02))
		lt.transform = mount.transform.affine_inverse() * Transform3D(Basis(), cup)
	var ikl := ArmIK.new()
	skel.add_child(ikl)
	ikl.setup(skel, "l", lt)
	ikl.pin_rotation = long
	if long:
		# palm up against the underside of the handguard, fingers wrapping round its far side
		var sgn := -1.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--lpalm="):
				sgn = float(a.trim_prefix("--lpalm="))
		var fy := Vector3(0.55, 0.45, -0.7).normalized()
		var palm := Vector3(0.45, 0.9, 0.0)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--lfy="):
				var v := a.trim_prefix("--lfy=").split(",")
				fy = Vector3(float(v[0]), float(v[1]), float(v[2])).normalized()
			if a.begins_with("--lpv="):
				var v := a.trim_prefix("--lpv=").split(",")
				palm = Vector3(float(v[0]), float(v[1]), float(v[2]))
		palm = (palm - fy * palm.dot(fy)).normalized()
		var lhx := palm * sgn
		var lb_vm := Basis(lhx, fy, lhx.cross(fy).normalized())
		var lw: Transform3D = sk_from_vm * Transform3D(lb_vm, Vector3.ZERO)
		var gb: Basis = (mount.transform * gun.transform).basis
		lt.basis = (gb.inverse() * lw.basis.orthonormalized()).orthonormalized()
		# the wrist sits back from where the palm meets the gun
		lt.position -= (gb.inverse() * (sk_from_vm.basis * (lb_vm * Vector3(0, 0.07, 0)))) 
	# the support hand reaches the handguard however far forward it is: the shoulder (out of sight) comes with it
	ikl.stretch = long
	guard_t = lt
	ik_tgt = lt
	if unit < 1e-6:
		k_back = Vector3.BACK

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

# melee: a blade or club (or a bare fist) held out in front, right hand pinned to the handle with IK. The weapon and the
# hand share a pivot at the grip, so a swing (or a jab) moves both together.
var melee_kind := ""
var melee_m0 := Transform3D.IDENTITY
var melee_off := Transform3D.IDENTITY
var melee_holder: Node3D
var melee_hand := -1
var fist_l: Node3D
var fist_r: Node3D
var jab_left := false

func setup_melee(armed: bool, id: String) -> void:
	_make_rig()
	can_reload = false
	idle_anim = "Pistol_Aim_Neutral"
	attack_anim = "Pistol_Aim_Neutral"
	ap.play("Pistol_Aim_Neutral")
	ap.seek(0.0, true)
	_place()
	rotation = Vector3.ZERO
	# the aiming pose leaves the shoulders behind the eye; bring the body forward so the arm reaches out in front
	rig.position += Vector3(0.0, 0.02, -0.2)
	base_pos = rig.position
	skel.force_update_all_bone_transforms()
	var sk := Transform3D.IDENTITY
	var n: Node = skel
	while n != rig and n is Node3D:
		sk = (n as Node3D).transform * sk
		n = n.get_parent()
	var vm_from_sk: Transform3D = rig.transform * sk
	var sk_from_vm := vm_from_sk.affine_inverse()
	melee_kind = id if armed and id != "" and id != "fists" else "fist"
	var two: bool = id in ["sledge", "bat"] or bool(Game.item(id).get("two", false))
	var grip_vm := Vector3(0.2, -0.24, -0.38) if not two else Vector3(0.17, -0.27, -0.36)
	if melee_kind == "fist":
		grip_vm = Vector3(0.15, -0.19, -0.36)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--curl="):
			var c := a.trim_prefix("--curl=").split(",")
			FingerCurl.AXIS = Vector3(float(c[0]), float(c[1]), float(c[2]))
	kick = Node3D.new()
	skel.add_child(kick)
	mount = Node3D.new()
	kick.add_child(mount)
	mount.transform = sk_from_vm * Transform3D(Basis(), grip_vm)
	melee_m0 = mount.transform
	k_back = sk_from_vm.basis * Vector3(0, 0, 1)
	k_up = sk_from_vm.basis * Vector3(0, 1, 0)
	k_right = sk_from_vm.basis * Vector3(1, 0, 0)
	var to_mount := func(x_vm: Transform3D) -> Transform3D:
		var w: Transform3D = sk_from_vm * x_vm
		return mount.transform.affine_inverse() * Transform3D(w.basis.orthonormalized(), w.origin)
	# the fist round the handle: same hand pose as a pistol grip (fingers along +Y, thumb +Z, palm -X)
	var hy := Vector3(-0.22, 0.1, -1.0).normalized()
	var hx := Vector3(1.0, 0.0, -0.15)
	hx = (hx - hy * hx.dot(hy)).normalized()
	var hand_vm := Basis(hx, hy, hx.cross(hy).normalized())
	var rt := Node3D.new()
	mount.add_child(rt)
	rt.transform = to_mount.call(Transform3D(hand_vm, grip_vm - hand_vm * Vector3(-0.03, 0.065, 0.0)))
	var ikr := ArmIK.new()
	skel.add_child(ikr)
	ikr.setup(skel, "r", rt)
	ikr.pin_rotation = true
	var lt := Node3D.new()
	var ikl := ArmIK.new()
	if melee_kind == "fist":
		# bare hands: both fists up in a guard, knuckles forward
		mount.add_child(lt)
		var lfy := Vector3(0.22, 0.1, -1.0).normalized()
		var lfx := Vector3(-1.0, 0.0, -0.15)
		lfx = (lfx - lfy * lfx.dot(lfy)).normalized()
		# turned half a turn about the fingers so it mirrors the right fist (it showed its palm before)
		var lhand := Basis(lfy, PI) * Basis(lfx, lfy, lfx.cross(lfy).normalized())
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--lrot="):
				lhand = Basis(lfy, float(a.trim_prefix("--lrot="))) * lhand
		var lgrip := Vector3(-grip_vm.x + 0.02, grip_vm.y + 0.02, grip_vm.z - 0.03)
		lt.transform = to_mount.call(Transform3D(lhand, lgrip - lhand * Vector3(-0.03, 0.065, 0.0)))
		ikl.pin_rotation = true
		fist_l = lt
		fist_r = rt
		for side in ["r", "l"]:
			var fc := FingerCurl.new()
			skel.add_child(fc)
			fc.setup(skel, side)
	else:
		skel.add_child(lt)
		lt.position = sk_from_vm * Vector3(-0.3, -0.75, -0.05)
	skel.add_child(ikl)
	ikl.setup(skel, "l", lt)
	# the weapon, built along +Y (handle at the origin) and turned so it rises up and forward out of the fist
	var w := _melee_mesh(melee_kind)
	var up := Vector3(0.05, 0.78, -0.62).normalized() if not two else Vector3(-0.25, 0.62, -0.75).normalized()
	var side := Vector3(1, 0, 0)
	side = (side - up * side.dot(up)).normalized()
	var wb := Basis(side, up, side.cross(up).normalized())
	var holder := Node3D.new()
	mount.add_child(holder)
	holder.transform = to_mount.call(Transform3D(wb, grip_vm))
	holder.add_child(w)
	_no_shadow(holder)
	# keep the weapon in the fist wherever the arm actually ends up
	melee_off = rt.transform.affine_inverse() * holder.transform
	melee_holder = holder
	melee_hand = skel.find_bone("hand_r")
	skel.skeleton_updated.connect(_follow_hand)
	gun = holder
	muzzle = Node3D.new()
	holder.add_child(muzzle)
	muzzle.position = Vector3(0, 0.3, 0)
	state = "aim"

func _melee_mesh(k: String) -> Node3D:
	var root := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.74, 0.77)
	metal.metallic = 0.8
	metal.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.1, 0.09)
	dark.roughness = 0.8
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.36, 0.22)
	wood.roughness = 0.75
	var part := func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		root.add_child(mi)
	var bx := func(x: float, y: float, z: float) -> BoxMesh:
		var b := BoxMesh.new()
		b.size = Vector3(x, y, z)
		return b
	var cy := func(r0: float, r1: float, h: float) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = r0
		c.bottom_radius = r1
		c.height = h
		c.radial_segments = 10
		return c
	var it := Game.item(k)
	if it.has("mglb"):
		# a modelled tool or blade (built along +Y with the handle at the origin), held a hand's width up the handle
		var w := (load("res://guns/" + String(it.mglb) + ".glb") as PackedScene).instantiate() as Node3D
		var ms := float(it.get("ms", 1.0))
		w.scale = Vector3.ONE * ms
		w.position.y = -0.05 * ms * (0.4 if ms < 1.5 else 0.6)
		Weathering.apply(w, 0.6, false, true)
		root.add_child(w)
		return root
	match k:
		"lead_pipe":
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.36, 0.37, 0.38)
			pm.metallic = 0.25
			pm.roughness = 0.55
			part.call(cy.call(0.016, 0.016, 0.62), pm, Vector3(0, 0.24, 0))
			part.call(cy.call(0.024, 0.024, 0.06), pm, Vector3(0, 0.54, 0))
			part.call(bx.call(0.032, 0.09, 0.032), dark, Vector3(0, 0.0, 0))
		"combat_knife", "knife":
			part.call(bx.call(0.026, 0.12, 0.032), dark, Vector3(0, 0.0, 0))
			part.call(bx.call(0.03, 0.012, 0.075), metal, Vector3(0, 0.066, 0.006))
			part.call(bx.call(0.006, 0.15, 0.03), metal, Vector3(0, 0.147, 0.004))
			var tip := PrismMesh.new()
			tip.size = Vector3(0.03, 0.045, 0.006)
			part.call(tip, metal, Vector3(0, 0.244, 0.004), Vector3(0, PI / 2, 0))
		"machete":
			part.call(bx.call(0.03, 0.13, 0.035), dark, Vector3.ZERO)
			part.call(bx.call(0.005, 0.42, 0.055), metal, Vector3(0, 0.275, 0.01))
			part.call(bx.call(0.005, 0.06, 0.07), metal, Vector3(0, 0.47, 0.018))
		"bat":
			part.call(cy.call(0.045, 0.02, 0.8), wood, Vector3(0, 0.3, 0))
		"sledge":
			part.call(cy.call(0.018, 0.018, 0.78), wood, Vector3(0, 0.3, 0))
			part.call(bx.call(0.09, 0.09, 0.2), dark, Vector3(0, 0.68, 0))
		"piston_fist":
			part.call(bx.call(0.1, 0.08, 0.12), dark, Vector3(0, 0.02, -0.02))
			part.call(cy.call(0.02, 0.02, 0.16), metal, Vector3(0.04, 0.02, 0.0), Vector3(PI / 2, 0, 0))
		_:
			pass
	return root

func _melee_swing() -> void:
	if kick_tw:
		kick_tw.kill()
	mount.transform = melee_m0
	var B0 := melee_m0.basis
	var O0 := melee_m0.origin
	var pose := func(rx: float, rz: float, off: Vector3) -> Transform3D:
		# rotations about camera-space axes, offsets in camera space
		var r := Basis(Vector3(1, 0, 0), rx) * Basis(Vector3(0, 0, 1), rz)
		return Transform3D(B0 * r, O0 + B0 * off)
	kick_tw = create_tween()
	if melee_kind == "fist" and fist_l:
		# jab, alternating hands: the punching fist drives forward and in, then snaps back
		jab_left = not jab_left
		var f: Node3D = fist_l if jab_left else fist_r
		var p0 := f.position
		var fwd := (mount.transform.basis.inverse() * k_back).normalized() * -1.0
		var inward := (mount.transform.basis.inverse() * k_right).normalized() * (0.06 if jab_left else -0.06)
		kick_tw.tween_property(f, "position", p0 + fwd * 0.2 + inward, 0.07).set_ease(Tween.EASE_OUT)
		kick_tw.tween_property(f, "position", p0, 0.16).set_trans(Tween.TRANS_QUAD)
		return
	if melee_kind == "fist" or melee_kind == "piston_fist":
		kick_tw.tween_property(mount, "transform", pose.call(-0.25, 0.0, Vector3(-0.1, 0.06, -0.22)), 0.07).set_ease(Tween.EASE_OUT)
		kick_tw.tween_property(mount, "transform", melee_m0, 0.18).set_trans(Tween.TRANS_QUAD)
		return
	# a backhand slash: wind up high and right, cut down and across to the left, come back
	kick_tw.tween_property(mount, "transform", pose.call(0.5, -0.5, Vector3(0.06, 0.1, 0.04)), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick_tw.tween_property(mount, "transform", pose.call(-0.9, 0.9, Vector3(-0.2, -0.06, -0.12)), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	kick_tw.tween_property(mount, "transform", melee_m0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

var kick_tw: Tween

func shoot() -> void:
	if melee_kind != "":
		_melee_swing()
		return
	if kick == null:
		ap.play(attack_anim, 0.03)
		ap.seek(0.0, true)
		state = "shoot"
		return
	# kick back and up, then settle
	if kick_tw:
		kick_tw.kill()
	kick.position = Vector3.ZERO
	kick_tw = create_tween()
	kick_tw.tween_property(kick, "position", k_back * 0.045 + k_up * 0.012, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick_tw.tween_property(kick, "position", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func reload(dur: float) -> void:
	if not can_reload:
		return
	if kick == null:
		var a := ap.get_animation("Pistol_Reload")
		ap.play("Pistol_Reload", 0.1, a.length / dur)
		state = "reload"
		return
	# dip the gun and tip it towards you, work it, bring it back up
	if kick_tw:
		kick_tw.kill()
	var m0 := mount.transform
	var tipped := Transform3D(Basis(k_back.normalized(), -0.5) * Basis(k_right.normalized(), 0.35), Vector3.ZERO) * m0
	tipped.origin = m0.origin - k_up * 0.1 + k_back * 0.04
	kick_tw = create_tween()
	kick_tw.tween_property(mount, "transform", tipped, dur * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick_tw.tween_property(kick, "position", -k_up * 0.02, dur * 0.2)
	kick_tw.tween_property(kick, "position", Vector3.ZERO, dur * 0.15)
	kick_tw.tween_property(mount, "transform", m0, dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

var dbg_t := 0
var ik_tgt: Node3D
# runs once the skeleton has its final (IK-adjusted) pose for the frame
func _follow_hand() -> void:
	if melee_holder and melee_hand >= 0:
		# hand pose in the mount's space, then the weapon at its fixed offset from it
		var hb: Transform3D = skel.get_bone_global_pose(melee_hand)
		var in_mount: Transform3D = (kick.transform * mount.transform).affine_inverse() * hb
		melee_holder.transform = in_mount * melee_off

func _process(_d: float) -> void:
	dbg_t += 1
	if dbg_t == 15 and melee_holder and OS.get_cmdline_user_args().has("--ikdbg"):
		var hb2 := skel.global_transform * skel.get_bone_global_pose(melee_hand)
		var ua2 := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("upperarm_r"))
		var tg: Node3D = null
		for c in mount.get_children():
			if c != melee_holder:
				tg = c
		print("IKDBG melee tgt ", to_local(tg.global_position), " hand ", to_local(hb2.origin), " shoulder ", to_local(ua2.origin), " reach ", ua2.origin.distance_to(tg.global_position))
	if dbg_t == 15 and ik_tgt and OS.get_cmdline_user_args().has("--ikdbg"):
		var hl := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand_l"))
		var ua := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("upperarm_l"))
		print("IKDBG tgt ", to_local(ik_tgt.global_position), " hand_l ", to_local(hl.origin), " upperarm_l ", to_local(ua.origin), " reach ", ua.origin.distance_to(ik_tgt.global_position))
	if state != "aim" and not ap.is_playing():
		ap.play(idle_anim, 0.15)
		state = "aim"

func muzzle_pos() -> Vector3:
	return muzzle.global_position
