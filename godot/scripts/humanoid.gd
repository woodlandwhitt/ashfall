# People, built from CC0 Quaternius parts that share one 65-bone skeleton: a Modular Outfit (peasant or ranger, male
# or female), a head cut from the Universal Base Character, and the Universal Animation Library's 45 motions
# (idle, walk, jog, sprint, talk, pistol aim/shoot/reload, hit, death, sitting, crouching...).
class_name Humanoid
extends RefCounted

static var _lib: AnimationLibrary
static var _mats: Dictionary = {}

const OUTFITS := ["Male_Peasant", "Male_Ranger", "Female_Peasant", "Female_Ranger"]

static func anim_library() -> AnimationLibrary:
	if _lib == null:
		var ual: Node = (load("res://chars/UAL1_Standard.glb") as PackedScene).instantiate()
		var ap := ual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_lib = ap.get_animation_library("")   # Godot's importer already loops the *_Loop clips (and drops the suffix)
		ual.free()
	return _lib

static func _mat(key: String, make: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]

# outfit: one of OUTFITS. cloth tints the outfit (dusty wasteland colours), skin tints face and hands.
static func build(outfit: String, cloth: Color, skin: Color, quality_lod := true) -> Node3D:
	var root := (load("res://chars/" + outfit + ".gltf") as PackedScene).instantiate() as Node3D
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var female := outfit.begins_with("Female")
	var skin_key := "skin_%s_%s" % [female, skin.to_html()]
	var skin_mat := _mat(skin_key, func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://chars/T_Regular_%s_Dark_BaseColor.png" % ("Female" if female else "Male"))
		m.normal_enabled = true
		m.normal_texture = load("res://chars/T_Regular_%s_Normal.png" % ("Female" if female else "Male"))
		m.roughness_texture = load("res://chars/T_Regular_%s_Roughness.png" % ("Female" if female else "Male"))
		m.albedo_color = skin
		return m)
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if src and String(src.resource_name).begins_with("MI_Regular"):
				m.set_surface_override_material(s, skin_mat)
			elif src is StandardMaterial3D:
				var key := "cloth_%s_%s" % [src.resource_name, cloth.to_html()]
				m.set_surface_override_material(s, _mat(key, func():
					var c := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					c.albedo_color = cloth
					return c))
	# the head (and eyes, brows) moves onto the outfit's skeleton; bones are matched by name
	var head := (load("res://chars/head_%s.glb" % ("female" if female else "male")) as PackedScene).instantiate()
	var hskel := head.find_child("Skeleton3D", true, false)
	var hood := outfit.ends_with("Ranger")
	for mi in hskel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		hskel.remove_child(m)
		skel.add_child(m)
		m.skeleton = NodePath("..")
		var nm := String(m.name)
		if nm == "Eyes":
			m.material_override = _mat("eyes", func():
				var e := StandardMaterial3D.new()
				e.albedo_texture = load("res://chars/T_Eye_Brown.png")
				e.roughness = 0.2
				return e)
		elif nm == "Eyebrows" or nm == "Face":
			m.material_override = _mat("brows", func():
				var b := StandardMaterial3D.new()
				b.albedo_color = Color(0.12, 0.08, 0.05)
				b.roughness = 0.9
				return b)
		else:
			m.material_override = skin_mat
	head.free()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", anim_library())
	ap.playback_default_blend_time = 0.25
	return root

static func play(ap: AnimationPlayer, anim: String, speed := 1.0) -> void:
	if ap.current_animation != anim:
		ap.play(anim)
	ap.speed_scale = speed

# a weapon in the right hand, lined up with the body's forward direction in the current pose (call after posing)
# fit: the gun model's own fix-up (its muzzle ends up along -Z); grip: where its origin sits, in the body's frame
# (x left, y up, z forward) relative to the right wrist
static func hold_aligned(root: Node3D, scene: PackedScene, fit: Basis, grip: Vector3) -> Node3D:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	skel.force_update_all_bone_transforms()
	var hb := skel.get_bone_global_pose(skel.find_bone("hand_r"))
	var D := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var xf := Transform3D(hb.basis.inverse() * D * fit, hb.basis.inverse() * grip)
	return hold(root, scene, xf)

# a weapon in the right hand
static func hold(root: Node3D, scene: PackedScene, xf: Transform3D) -> Node3D:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.bone_name = "hand_r"
	skel.add_child(ba)
	var g := scene.instantiate() as Node3D
	g.transform = xf
	ba.add_child(g)
	return g
