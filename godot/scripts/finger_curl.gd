# Closes a hand into a fist (first person, bare-handed): every finger joint bends about its own side axis, the thumb
# folds across. Runs after the animation, like ArmIK.
class_name FingerCurl
extends SkeletonModifier3D

var bones: Array = []      # [bone, angle]
static var AXIS := Vector3(1, 0, 0)

func setup(sk: Skeleton3D, side: String, amount := 1.5) -> void:
	for f in ["index", "middle", "ring", "pinky"]:
		for j in ["01", "02", "03"]:
			var b := sk.find_bone("%s_%s_%s" % [f, j, side])
			if b >= 0:
				bones.append([b, amount * (0.8 if j == "01" else 1.0)])
	for j in ["01", "02", "03"]:
		var b := sk.find_bone("thumb_%s_%s" % [j, side])
		if b >= 0:
			bones.append([b, amount * 0.45])

func _process_modification_with_delta(_d: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for e in bones:
		var rest: Quaternion = sk.get_bone_rest(e[0]).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(e[0], rest * Quaternion(AXIS, e[1]))
