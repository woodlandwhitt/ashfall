# The rad vulture, redone: a big carrion bird built from simple shapes (dark ragged plumage, a pale ruff, a bald red
# head and a hooked beak, long fingered wings) that flies. It wheels high over its patch on thermals, glides and
# flaps, and when it spots you it circles lower and stoops on you, rakes, and climbs away to come round again.
# Shot down, it tumbles out of the sky.
class_name Vulture

static func model() -> Node3D:
	var root := Node3D.new()
	root.name = "Vulture"
	var feather := _m(Color(0.13, 0.11, 0.1), 0.85)
	var ruff := _m(Color(0.62, 0.58, 0.52), 0.9)
	var skin := _m(Color(0.62, 0.27, 0.24), 0.6)
	var beak := _m(Color(0.78, 0.72, 0.55), 0.5)
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 0.3
	root.add_child(body)
	_ell(body, Vector3(0.28, 0.24, 0.62), Vector3(0, 0, 0), feather)
	_ell(body, Vector3(0.24, 0.2, 0.2), Vector3(0, 0.04, 0.3), ruff)
	_ell(body, Vector3(0.09, 0.09, 0.22), Vector3(0, 0.1, 0.44), skin, Vector3(-0.4, 0, 0))
	_ell(body, Vector3(0.11, 0.1, 0.14), Vector3(0, 0.16, 0.56), skin)
	var bk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.035
	cm.height = 0.1
	bk.mesh = cm
	bk.material_override = beak
	bk.rotation = Vector3(PI / 2 + 0.4, 0, 0)
	bk.position = Vector3(0, 0.14, 0.66)
	body.add_child(bk)
	# a fanned tail
	for i in 5:
		var tf := _box(body, Vector3(0.07, 0.015, 0.3), Vector3((i - 2) * 0.05, 0.0, -0.42), feather)
		tf.rotation.y = (i - 2) * 0.16
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if side < 0 else "WingR"
		w.position = Vector3(side * 0.12, 0.06, 0.08)
		body.add_child(w)
		# inner wing, outer wing on its own joint, and the splayed primary "fingers" at the tip
		_box(w, Vector3(0.6, 0.03, 0.42), Vector3(side * 0.3, 0, -0.04), feather)
		var outer := Node3D.new()
		outer.name = "Outer"
		outer.position = Vector3(side * 0.6, 0, 0)
		w.add_child(outer)
		_box(outer, Vector3(0.5, 0.025, 0.34), Vector3(side * 0.25, 0, -0.06), feather)
		for f in 5:
			var p := _box(outer, Vector3(0.28, 0.012, 0.05), Vector3(side * (0.6 + 0.02 * f), 0, 0.08 - f * 0.065), feather)
			p.rotation.y = -side * (0.1 * f - 0.15)
		_box(w, Vector3(0.55, 0.035, 0.1), Vector3(side * 0.28, 0.01, 0.15), ruff)
	# legs tucked up under it
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.04, 0.04, 0.16), Vector3(side * 0.07, -0.13, -0.12), skin)
	root.scale = Vector3.ONE * 1.25
	return root

static func _m(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

static func _ell(p: Node3D, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 12
	s.rings = 8
	mi.mesh = s
	mi.scale = size
	mi.position = at
	mi.rotation = rot
	mi.material_override = m
	p.add_child(mi)
	return mi

static func _box(p: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	p.add_child(mi)
	return mi

# wings: a slow glide most of the time, deep beats when climbing; 'bank' rolls the body into a turn
static func pose(model: Node3D, t: float, flap: float, bank: float, pitch: float) -> void:
	var body := model.get_node_or_null("Body") as Node3D
	if body == null:
		return
	body.rotation = Vector3(-pitch, 0, -bank)
	var beat := sin(t * (3.0 + flap * 5.0))
	var a := 0.12 + beat * (0.06 + flap * 0.55)
	for side in [-1.0, 1.0]:
		var w := body.get_node_or_null("WingL" if side < 0 else "WingR") as Node3D
		if w:
			w.rotation.z = side * a
			var o := w.get_node_or_null("Outer") as Node3D
			if o:
				o.rotation.z = side * (a * 0.6 - 0.05 + flap * 0.1 * beat)
