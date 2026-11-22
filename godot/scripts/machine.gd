# Bodies that aren't flesh. Built on the same rigged people (so they move and aim the same way) and refinished:
#   synth     a Meridian replica: seamless pale grey polymer, no hair, eyes that glow cold blue
#   guardbot  a prewar security robot: gunmetal plating, a visor bar for a face, an amber lamp on its chest
#   warden    an Iron Warden in power armour: thick olive-drab plate over the whole body, a helmet with a lit slit visor
class_name Machine

static var _mats := {}

static func dress(model: Node3D, kind: String) -> void:
	var m := _mat(kind)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var head := BoneAttachment3D.new()
	head.bone_name = "Head" if skel.find_bone("Head") >= 0 else "head"
	skel.add_child(head)
	var chest := BoneAttachment3D.new()
	chest.bone_name = "spine_03" if skel.find_bone("spine_03") >= 0 else ("Chest" if skel.find_bone("Chest") >= 0 else "Spine")
	skel.add_child(chest)
	match kind:
		"synth":
			for x in [-0.033, 0.033]:
				var e := _box(Vector3(0.022, 0.008, 0.012), _glow(Color(0.4, 0.75, 1.0)))
				e.position = Vector3(x, 0.07, 0.085)
				head.add_child(e)
			var l := OmniLight3D.new()
			l.light_color = Color(0.4, 0.75, 1.0)
			l.light_energy = 0.4
			l.omni_range = 1.5
			l.position = Vector3(0, 0.08, 0.2)
			head.add_child(l)
		"guardbot":
			var visor := _box(Vector3(0.2, 0.05, 0.05), _glow(Color(1.0, 0.25, 0.15)))
			visor.position = Vector3(0, 0.08, 0.1)
			head.add_child(visor)
			var lamp := _box(Vector3(0.07, 0.07, 0.03), _glow(Color(1.0, 0.65, 0.2)))
			lamp.position = Vector3(0, 0.05, 0.16)
			chest.add_child(lamp)
		"warden":
			var slit := _box(Vector3(0.14, 0.025, 0.02), _glow(Color(1.0, 0.8, 0.35)))
			slit.position = Vector3(0, 0.09, 0.13)
			head.add_child(slit)
			var pack := _box(Vector3(0.3, 0.34, 0.14), _mat("warden"))
			pack.position = Vector3(0, 0.02, -0.2)
			chest.add_child(pack)
			for x in [-0.22, 0.22]:
				var pad := _box(Vector3(0.14, 0.09, 0.18), _mat("warden"))
				pad.position = Vector3(x, 0.12, 0.0)
				chest.add_child(pad)

static func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	return mi

static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * 1.6
	return m

static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"synth":
			m.albedo_color = Color(0.5, 0.52, 0.54)
			m.roughness = 0.3
			m.metallic = 0.1
		"guardbot":
			m.albedo_color = Color(0.3, 0.32, 0.34)
			m.roughness = 0.4
			m.metallic = 0.25
		_:
			m.albedo_color = Color(0.3, 0.33, 0.24)
			m.roughness = 0.6
			m.metallic = 0.2
	_mats[kind] = Weathering.material_for(m, 0.7, false, true) if kind != "synth" else m
	return _mats[kind]
