# Walking one way while looking another. The animation library only has forward walks and jogs, so when someone
# moves sideways (a gunman strafing, a companion keeping pace beside you) the hips turn toward where the feet are
# going and the spine turns back by the same amount, so the chest, head and gun stay on the target. Moving away
# from where they face plays the walk backwards (a backpedal) instead. Runs after the animation, like ArmIK.
class_name LegTwist
extends SkeletonModifier3D

var pelvis := -1
var root_b := -1
var spine: Array = []
var twist := 0.0          # radians, hips relative to the body's facing
var target := 0.0

func setup(sk: Skeleton3D) -> void:
	pelvis = sk.find_bone("pelvis")
	root_b = sk.get_bone_parent(pelvis) if pelvis >= 0 else -1
	for n in ["spine_01", "spine_02", "spine_03"]:
		var b := sk.find_bone(n)
		if b >= 0:
			spine.append(b)

func _process_modification_with_delta(d: float) -> void:
	twist = lerp_angle(twist, target, 1.0 - exp(-10.0 * d))
	var sk := get_skeleton()
	if sk == null or pelvis < 0 or absf(twist) < 0.01:
		return
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	_turn(sk, pelvis, up, twist)
	for b in spine:
		_turn(sk, b, up, -twist / float(spine.size()))

# turn one bone about the body's up axis, keeping its children attached
func _turn(sk: Skeleton3D, b: int, up: Vector3, a: float) -> void:
	var p := sk.get_bone_parent(b)
	var g: Transform3D = sk.get_bone_global_pose(b)
	var pg: Transform3D = sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
	var ng := Basis(up, a) * g.basis
	sk.set_bone_pose_rotation(b, (pg.basis.inverse() * ng).get_rotation_quaternion())

# pick the walk for a body facing face_yaw that is moving with velocity v; returns the playback speed sign
static func drive(lt: LegTwist, face_yaw: float, v: Vector3) -> float:
	if lt == null:
		return 1.0
	var flat := Vector2(v.x, v.z)
	if flat.length() < 0.3:
		lt.target = 0.0
		return 1.0
	var rel := wrapf(atan2(v.x, v.z) - face_yaw, -PI, PI)
	var sgn := 1.0
	if absf(rel) > 1.95:
		# mostly backwards: walk backwards, hips turned by what's left over
		sgn = -1.0
		rel = wrapf(rel - PI, -PI, PI)
	lt.target = clampf(rel, -1.25, 1.25)
	return sgn
