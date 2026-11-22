# Keeps a gunman's arms in the aiming pose whatever the legs are doing. The animation library only aims standing
# still; walking or jogging swings the gun arm, so a raider strafing round you used to point his pistol at the sky or
# the dirt. This copies the aiming pose's arm and shoulder rotations over the walk while they're in a fight, and tilts
# the chest up or down toward whoever they're shooting at. Runs after the animation, like LegTwist.
class_name AimHold
extends SkeletonModifier3D

const BONES := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"]
var ids: Array = []
var rots: Array = []
var weight := 0.0
var target_w := 0.0
var pitch := 0.0              # radians, + looks up
var spine := -1

# call while the skeleton stands in the aiming pose (Pistol_Aim_Neutral at time 0)
func capture(sk: Skeleton3D) -> void:
	ids.clear()
	rots.clear()
	for n in BONES:
		var b := sk.find_bone(n)
		if b >= 0:
			ids.append(b)
			rots.append(sk.get_bone_pose_rotation(b))
	spine = sk.find_bone("spine_03")

func _process_modification_with_delta(d: float) -> void:
	weight = move_toward(weight, target_w, d * 4.0)
	var sk := get_skeleton()
	if sk == null or weight < 0.01:
		return
	for i in ids.size():
		var b: int = ids[i]
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(rots[i], weight))
	if spine >= 0 and absf(pitch) > 0.01:
		# tilt the chest about the body's right axis
		# bodies face +Z, so turning about +X by -pitch lifts the chest
		var right := Vector3.RIGHT
		var p := sk.get_bone_parent(spine)
		var g: Transform3D = sk.get_bone_global_pose(spine)
		var pg: Transform3D = sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
		var ng := Basis(right, -clampf(pitch, -0.6, 0.6) * weight) * g.basis
		sk.set_bone_pose_rotation(spine, (pg.basis.inverse() * ng).get_rotation_quaternion())
