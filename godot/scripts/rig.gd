# Limb animation for the characters exported from the WebView build. Their limbs are named nodes (armL, legR, ...)
# pivoting at the joint, so walking is a swing of each one around its own x axis, as in the original.
class_name Rig
extends RefCounted

var parts: Dictionary = {}
var base: Dictionary = {}
var quad := false
var phase := 0.0

func _init(root: Node, is_quad: bool) -> void:
	quad = is_quad
	for k in ["armL", "armR", "foreL", "foreR", "legL", "legR", "shinL", "shinR", "head", "chest", "up"]:
		var n := root.find_child(k, true, false) as Node3D
		if n:
			parts[k] = n
			base[k] = n.rotation

func pose(k: String, rx: float, rz: float = 0.0) -> void:
	if parts.has(k):
		var b: Vector3 = base[k]
		parts[k].rotation = Vector3(b.x + rx, b.y, b.z + rz)

func animate(d: float, speed: float, t: float, aim: bool = false) -> void:
	var amt := clampf(speed / 3.0, 0.0, 1.4)
	phase += d * (2.2 + speed * 1.9)
	var s := sin(phase)
	if quad:
		pose("legL", s * 0.7 * amt)
		pose("legR", -s * 0.7 * amt)
		pose("armL", -s * 0.7 * amt)
		pose("armR", s * 0.7 * amt)
		pose("head", sin(t * 1.3) * 0.08)
		return
	pose("legL", s * 0.62 * amt)
	pose("legR", -s * 0.62 * amt)
	pose("shinL", maxf(0.0, -cos(phase)) * 0.7 * amt)
	pose("shinR", maxf(0.0, cos(phase)) * 0.7 * amt)
	if aim:
		pose("armR", -1.45)
		pose("foreR", 0.0)
		pose("armL", -1.2, 0.35)
		pose("foreL", -0.3)
	else:
		pose("armL", -s * 0.5 * amt + sin(t * 1.1) * 0.03)
		pose("armR", s * 0.5 * amt - sin(t * 1.1) * 0.03)
		pose("foreL", -0.15 - 0.25 * amt)
		pose("foreR", -0.15 - 0.25 * amt)
	pose("chest", sin(t * 1.6) * 0.015)
	pose("head", sin(t * 0.37) * 0.05)
