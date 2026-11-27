# Two-bone IK for an arm (upper arm, forearm, hand), run after the animation each frame: puts the hand on a target
# (the support hand on a long gun's handguard) while keeping the elbow bending the way the animation bends it.
class_name ArmIK
extends SkeletonModifier3D

var upper := -1
var lower := -1
var hand := -1
var target: Node3D
var pin_rotation := false   # the hand takes the target's orientation (a grip), not the animation's
var stretch := false        # move the shoulder towards a target the arm can't reach (first person only: unseen)
var use_pole := false       # turn the arm about the shoulder-hand line so the elbow points towards 'pole' (skeleton
var pole := Vector3.ZERO    # space): a support arm's elbow down and out, not up and across the view (build 24)
var shoulder := Vector3.ZERO  # first person: the shoulder dropped out of sight by this much (skeleton space), so the
                              # upper arm rises into view from below rather than lying across the bottom of it

func setup(sk: Skeleton3D, side: String, tgt: Node3D) -> void:
	upper = sk.find_bone("upperarm_" + side)
	lower = sk.find_bone("lowerarm_" + side)
	hand = sk.find_bone("hand_" + side)
	target = tgt

func _process_modification_with_delta(_d: float) -> void:
	var sk := get_skeleton()
	if sk == null or upper < 0 or lower < 0 or hand < 0 or not is_instance_valid(target) or not sk.is_inside_tree() or not target.is_inside_tree():
		return
	var t: Vector3 = sk.global_transform.affine_inverse() * target.global_position
	if shoulder != Vector3.ZERO:
		var pu1 := sk.get_bone_parent(upper)
		var pb1: Basis = sk.get_bone_global_pose(pu1).basis if pu1 >= 0 else Basis()
		sk.set_bone_pose_position(upper, sk.get_bone_pose_position(upper) + pb1.inverse() * shoulder)
	if stretch:
		var u0 := sk.get_bone_global_pose(upper).origin
		var full := u0.distance_to(sk.get_bone_global_pose(lower).origin) + sk.get_bone_global_pose(lower).origin.distance_to(sk.get_bone_global_pose(hand).origin)
		var excess := u0.distance_to(t) - full * 0.96
		if excess > 0.0:
			var pu0 := sk.get_bone_parent(upper)
			var pb: Basis = sk.get_bone_global_pose(pu0).basis if pu0 >= 0 else Basis()
			sk.set_bone_pose_position(upper, sk.get_bone_pose_position(upper) + pb.inverse() * ((t - u0).normalized() * excess))
	var ua := sk.get_bone_global_pose(upper)
	var la := sk.get_bone_global_pose(lower)
	var hd := sk.get_bone_global_pose(hand)
	var a := ua.origin
	var b := la.origin
	var c := hd.origin
	var lab := a.distance_to(b)
	var lbc := b.distance_to(c)
	if lab < 1e-5 or lbc < 1e-5:
		return
	var lat := clampf(a.distance_to(t), 1e-4, (lab + lbc) * 0.999)
	var ac0 := acos(clampf((c - a).normalized().dot((b - a).normalized()), -1.0, 1.0))
	var ba0 := acos(clampf((a - b).normalized().dot((c - b).normalized()), -1.0, 1.0))
	var ac1 := acos(clampf((lbc * lbc - lab * lab - lat * lat) / (-2.0 * lab * lat), -1.0, 1.0))
	var ba1 := acos(clampf((lat * lat - lab * lab - lbc * lbc) / (-2.0 * lab * lbc), -1.0, 1.0))
	var axis := (c - a).cross(b - a)
	if axis.length() < 1e-6:
		axis = Vector3(0, 0, 1).cross(b - a)
	axis = axis.normalized()
	var r0 := Quaternion(axis, ac1 - ac0)
	var r1 := Quaternion(axis, ba1 - ba0)
	# where the hand ends up after bending, then swing the whole arm onto the target
	var b1 := a + r0 * (b - a)
	var c1 := b1 + (r0 * r1) * (c - b)
	var r2 := Quaternion((c1 - a).normalized(), (t - a).normalized()) if (c1 - a).length() > 1e-5 else Quaternion.IDENTITY
	var r3 := Quaternion.IDENTITY
	if use_pole:
		# the elbow swung round the line from the shoulder to the hand until it points as near the pole as it can
		var ax := (t - a)
		if ax.length() > 1e-4:
			ax = ax.normalized()
			var e := r2 * (b1 - a)
			var pv := pole - a
			e -= ax * e.dot(ax)
			pv -= ax * pv.dot(ax)
			if e.length() > 1e-4 and pv.length() > 1e-4:
				var ang := e.signed_angle_to(pv, ax)
				r3 = Quaternion(ax, ang)
	var ua_rot := r3 * r2 * r0 * ua.basis.get_rotation_quaternion()
	var la_rot := r3 * r2 * r0 * r1 * la.basis.get_rotation_quaternion()
	var hd_rot := r3 * r2 * r0 * r1 * hd.basis.get_rotation_quaternion()
	if pin_rotation:
		hd_rot = (sk.global_transform.affine_inverse() * target.global_transform).basis.get_rotation_quaternion()
	var pu := sk.get_bone_parent(upper)
	var parent_rot := sk.get_bone_global_pose(pu).basis.get_rotation_quaternion() if pu >= 0 else Quaternion.IDENTITY
	sk.set_bone_pose_rotation(upper, parent_rot.inverse() * ua_rot)
	sk.set_bone_pose_rotation(lower, ua_rot.inverse() * la_rot)
	sk.set_bone_pose_rotation(hand, la_rot.inverse() * hd_rot)
