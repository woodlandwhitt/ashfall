# What things look like lying on the ground (or a shelf): a dented tin of Mystery Meat with its faded label, a soda
# bottle, a stim syringe, a Rad Flush bag, pill bottles, ammo boxes, scrap, tape, wire, circuit boards, gear, a fuel
# can, folded clothes, the gun itself... built from simple shapes and a shared aged-paint shader (labels, stripes,
# rust, grime), so every item reads at a glance and none of them is a grey box.
class_name ItemModels

static var mats: Dictionary = {}
static var shader: Shader

const CODE := """shader_type spatial;
uniform vec4 base : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 band : source_color = vec4(0.8, 0.2, 0.1, 1.0);
uniform vec2 band_y = vec2(-1.0, -1.0);   // a printed label between these local heights
uniform float metal = 0.0;
uniform float rough = 0.7;
uniform float rust = 0.3;
uniform float stripe = 0.0;               // a second, thin stripe inside the label
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float alpha = 1.0;
varying vec3 lp;
varying vec3 wp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex(){ lp = VERTEX; wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec3 c = base.rgb;
	float lab = step(band_y.x, lp.y) * step(lp.y, band_y.y);
	vec3 lc = band.rgb;
	if (stripe > 0.0) {
		float mid = (band_y.x + band_y.y) * 0.5;
		lc = mix(lc, vec3(0.92, 0.86, 0.6), step(abs(lp.y - mid), stripe));
	}
	// the label is sun-faded and scuffed, with a torn edge
	float tear = vn(vec2(atan(lp.z, lp.x) * 6.0, lp.y * 40.0));
	c = mix(c, lc * mix(0.75, 1.0, vn(lp.xy * 60.0)), lab * step(0.18, tear));
	float n = vn(wp.xz * 40.0 + lp.y * 30.0);
	c = mix(c, vec3(0.32, 0.18, 0.08), smoothstep(0.62, 0.92, n) * rust);
	c *= mix(0.78, 1.04, vn(lp.xz * 25.0 + 3.0));
	ALBEDO = c;
	METALLIC = metal * (1.0 - lab);
	ROUGHNESS = mix(rough, 0.95, smoothstep(0.62, 0.92, n) * rust);
	EMISSION = glow.rgb;
	if (alpha < 1.0) { ALPHA = alpha; }
}"""

static func _m(key: String, p: Dictionary) -> Material:
	if mats.has(key):
		return mats[key]
	if shader == null:
		shader = Shader.new()
		shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in p:
		m.set_shader_parameter(k, p[k])
	if float(p.get("alpha", 1.0)) < 1.0:
		var sh2 := Shader.new()
		sh2.code = CODE.replace("shader_type spatial;", "shader_type spatial;\nrender_mode blend_mix, depth_draw_opaque, cull_back;")
		m.shader = sh2
	mats[key] = m
	return m

static func _mesh(root: Node3D, mesh: Mesh, at: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

static func _cyl(r: float, hgt: float, top := -1.0, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = hgt
	c.radial_segments = seg
	c.rings = 1
	return c

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func _sph(r: float, hgt := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if hgt < 0.0 else hgt
	s.radial_segments = 12
	s.rings = 6
	return s

const TIN := {"base": Color(0.62, 0.62, 0.6), "metal": 0.7, "rough": 0.45, "rust": 0.55}

# a tin can with a printed label (the whole can is one cylinder; the label is painted on by height)
static func _can(root: Node3D, label: Color, h := 0.11, r := 0.042, stripe := 0.012) -> void:
	var p := TIN.duplicate()
	p["band"] = label
	p["band_y"] = Vector2(-h * 0.36, h * 0.36)
	p["stripe"] = stripe
	_mesh(root, _cyl(r, h), Vector3(0, h * 0.5, 0), _m("can" + label.to_html(), p))
	_mesh(root, _cyl(r * 0.92, 0.006), Vector3(0, h + 0.002, 0), _m("lid", TIN))

static func _bottle(root: Node3D, glass: Color, liquid: Color, label: Color, h := 0.24) -> void:
	_mesh(root, _cyl(0.034, h * 0.6), Vector3(0, h * 0.3, 0), _m("liq" + liquid.to_html(), {"base": liquid, "band": label, "band_y": Vector2(-h * 0.12, h * 0.12), "rough": 0.2, "rust": 0.0}))
	_mesh(root, _cyl(0.036, h * 0.62), Vector3(0, h * 0.31, 0), _m("glass" + glass.to_html(), {"base": glass, "rough": 0.08, "metal": 0.1, "rust": 0.0, "alpha": 0.4}))
	_mesh(root, _cyl(0.013, h * 0.3, 0.036), Vector3(0, h * 0.62 + h * 0.15, 0), _m("glass" + glass.to_html(), {}))
	_mesh(root, _cyl(0.016, 0.02), Vector3(0, h * 0.93, 0), _m("cap", {"base": Color(0.7, 0.15, 0.1), "metal": 0.6, "rough": 0.4, "rust": 0.6}))

static func _syringe(root: Node3D, fluid: Color) -> void:
	var r := Node3D.new()
	root.add_child(r)
	r.rotation = Vector3(0, 0, PI * 0.5)
	r.position.y = 0.022
	_mesh(r, _cyl(0.016, 0.12), Vector3.ZERO, _m("syr" + fluid.to_html(), {"base": fluid, "rough": 0.15, "rust": 0.0, "glow": fluid * 0.25}))
	_mesh(r, _cyl(0.019, 0.13), Vector3.ZERO, _m("syrglass", {"base": Color(0.85, 0.9, 0.92), "rough": 0.05, "rust": 0.0, "alpha": 0.35}))
	_mesh(r, _cyl(0.004, 0.06), Vector3(0, 0.09, 0), _m("steel", {"base": Color(0.75, 0.76, 0.78), "metal": 0.9, "rough": 0.25, "rust": 0.1}))
	_mesh(r, _cyl(0.024, 0.012), Vector3(0, -0.07, 0), _m("plunger", {"base": Color(0.15, 0.15, 0.16), "rough": 0.6, "rust": 0.0}))
	_mesh(r, _cyl(0.005, 0.05), Vector3(0, -0.095, 0), _m("plunger", {}))

static func _pills(root: Node3D, body: Color) -> void:
	_mesh(root, _cyl(0.022, 0.07), Vector3(0, 0.035, 0), _m("pill" + body.to_html(), {"base": body, "band": Color(0.95, 0.93, 0.85), "band_y": Vector2(-0.02, 0.012), "rough": 0.3, "rust": 0.05, "alpha": 0.85}))
	_mesh(root, _cyl(0.024, 0.018), Vector3(0, 0.078, 0), _m("pillcap", {"base": Color(0.92, 0.92, 0.9), "rough": 0.5, "rust": 0.0}))

static func _bag(root: Node3D, col: Color) -> void:
	_mesh(root, _box(Vector3(0.13, 0.03, 0.18)), Vector3(0, 0.015, 0), _m("bag" + col.to_html(), {"base": col, "band": Color(0.95, 0.95, 0.9), "band_y": Vector2(0.005, 0.02), "rough": 0.25, "rust": 0.0}))
	_mesh(root, _cyl(0.005, 0.22), Vector3(0.0, 0.01, 0.15), _m("tube", {"base": Color(0.85, 0.85, 0.8), "rough": 0.3, "rust": 0.0}), Vector3(PI * 0.5, 0, 0.3))

static func _ammo(root: Node3D, col: Color, size := Vector3(0.16, 0.08, 0.1)) -> void:
	_mesh(root, _box(size), Vector3(0, size.y * 0.5, 0), _m("ammo" + col.to_html(), {"base": col, "band": Color(0.85, 0.7, 0.2), "band_y": Vector2(-size.y * 0.15, size.y * 0.15), "rough": 0.8, "rust": 0.35}))
	# a few loose rounds beside it
	for i in 3:
		_mesh(root, _cyl(0.006, 0.035), Vector3(size.x * 0.5 + 0.03 + i * 0.016, 0.006, -0.02 + i * 0.012), _m("brass", {"base": Color(0.78, 0.6, 0.25), "metal": 0.85, "rough": 0.3, "rust": 0.2}), Vector3(PI * 0.5, 0.4 * i, 0))

static func _scrap(root: Node3D, rng: RandomNumberGenerator) -> void:
	var m := _m("scrap", {"base": Color(0.5, 0.48, 0.45), "metal": 0.6, "rough": 0.6, "rust": 0.9})
	for i in 3:
		_mesh(root, _box(Vector3(rng.randf_range(0.12, 0.24), 0.008, rng.randf_range(0.06, 0.14))), Vector3(rng.randf_range(-0.05, 0.05), 0.01 + i * 0.012, rng.randf_range(-0.05, 0.05)), m, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
	_mesh(root, _cyl(0.012, 0.2), Vector3(0, 0.03, 0), m, Vector3(0, rng.randf() * TAU, PI * 0.5))

static func _torus(root: Node3D, inner: float, outer: float, col: Dictionary, key: String) -> void:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 18
	t.ring_segments = 8
	_mesh(root, t, Vector3(0, (outer - inner) * 0.5, 0), _m(key, col))

# the model for an item id (lying flat, origin on the ground)
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	var it: Dictionary = Game.item(id)
	var t := String(it.get("t", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"cram": _can(root, Color(0.66, 0.12, 0.1))
		"stew": _can(root, Color(0.25, 0.42, 0.2), 0.12, 0.05)
		"sun_pop": _bottle(root, Color(0.5, 0.75, 0.65), Color(0.85, 0.45, 0.1), Color(0.9, 0.85, 0.2))
		"k_fizz": _bottle(root, Color(0.5, 0.7, 0.8), Color(0.55, 0.25, 0.75), Color(0.2, 0.9, 0.7))
		"purified_water": _bottle(root, Color(0.75, 0.85, 0.95), Color(0.6, 0.75, 0.9), Color(0.2, 0.45, 0.85), 0.26)
		"dirty_water": _bottle(root, Color(0.6, 0.65, 0.55), Color(0.45, 0.5, 0.3), Color(0.5, 0.45, 0.3), 0.26)
		"moonshine", "rotgut": _bottle(root, Color(0.55, 0.45, 0.3), Color(0.75, 0.55, 0.25), Color(0.85, 0.8, 0.65), 0.28)
		"glowshine": _bottle(root, Color(0.5, 0.8, 0.5), Color(0.4, 1.0, 0.3), Color(0.15, 0.2, 0.1), 0.28)
		"lucky_sour", "prickly_pop": _bottle(root, Color(0.75, 0.8, 0.6), Color(0.95, 0.4, 0.6) if id == "prickly_pop" else Color(0.6, 0.9, 0.3), Color(0.9, 0.9, 0.85), 0.2)
		"stimpak": _syringe(root, Color(0.85, 0.08, 0.06))
		"super_stim": _syringe(root, Color(0.3, 0.95, 0.4))
		"ketarad", "jolt", "stillwater", "brightsight": _syringe(root, {"ketarad": Color(0.6, 0.3, 0.9), "jolt": Color(0.95, 0.7, 0.1), "stillwater": Color(0.3, 0.5, 0.95), "brightsight": Color(0.9, 0.9, 0.95)}[id])
		"radaway": _bag(root, Color(0.95, 0.55, 0.15))
		"rad_tabs", "painkiller", "bonecrete", "clean_slate": _pills(root, {"rad_tabs": Color(0.9, 0.5, 0.1), "painkiller": Color(0.85, 0.85, 0.8), "bonecrete": Color(0.6, 0.6, 0.62), "clean_slate": Color(0.4, 0.7, 0.9)}[id])
		"jerky", "ox_steak", "boar_chop":
			var col := Color(0.42, 0.22, 0.12) if id == "jerky" else Color(0.62, 0.25, 0.2)
			_mesh(root, _box(Vector3(0.16, 0.03, 0.09)), Vector3(0, 0.015, 0), _m("meat" + id, {"base": col, "rough": 0.6, "rust": 0.0}))
			_mesh(root, _box(Vector3(0.2, 0.004, 0.13)), Vector3(0, 0.002, 0), _m("paper", {"base": Color(0.78, 0.7, 0.55), "rough": 0.9, "rust": 0.3}))
		"dustweed", "med_herbs":
			for i in 5:
				_mesh(root, _cyl(0.008, 0.14), Vector3(rng.randf_range(-0.03, 0.03), 0.01, rng.randf_range(-0.03, 0.03)), _m("herb" + id, {"base": Color(0.35, 0.45, 0.2) if id == "med_herbs" else Color(0.5, 0.45, 0.25), "rough": 0.8, "rust": 0.0}), Vector3(0, rng.randf() * TAU, PI * 0.5))
			_mesh(root, _cyl(0.02, 0.02), Vector3(0, 0.012, 0), _m("twine", {"base": Color(0.7, 0.6, 0.4), "rough": 0.9, "rust": 0.0}), Vector3(0, 0, PI * 0.5))
		"frag":
			_mesh(root, _sph(0.04, 0.09), Vector3(0, 0.045, 0), _m("frag", {"base": Color(0.3, 0.35, 0.22), "metal": 0.4, "rough": 0.6, "rust": 0.4}))
			_mesh(root, _cyl(0.012, 0.03), Vector3(0, 0.1, 0), _m("steel", {}))
		"pipe_bomb":
			_mesh(root, _cyl(0.025, 0.16), Vector3(0, 0.025, 0), _m("pipe", {"base": Color(0.4, 0.4, 0.42), "metal": 0.7, "rough": 0.5, "rust": 0.8}), Vector3(0, 0, PI * 0.5))
			_mesh(root, _cyl(0.003, 0.06), Vector3(0.1, 0.03, 0), _m("fuse", {"base": Color(0.2, 0.15, 0.1), "rust": 0.0}), Vector3(0, 0, 1.0))
		"molotov":
			_bottle(root, Color(0.55, 0.6, 0.5), Color(0.7, 0.5, 0.2), Color(0.85, 0.8, 0.7), 0.25)
		"pulse_nade":
			_mesh(root, _sph(0.045), Vector3(0, 0.045, 0), _m("pulse", {"base": Color(0.3, 0.32, 0.35), "metal": 0.7, "rough": 0.4, "rust": 0.2, "glow": Color(0.1, 0.4, 0.8)}))
		"ammo_9": _ammo(root, Color(0.32, 0.38, 0.22))
		"ammo_44": _ammo(root, Color(0.45, 0.28, 0.18))
		"ammo_rifle": _ammo(root, Color(0.28, 0.33, 0.2), Vector3(0.22, 0.09, 0.12))
		"shells": _ammo(root, Color(0.6, 0.15, 0.12), Vector3(0.18, 0.08, 0.12))
		"cell":
			_mesh(root, _cyl(0.025, 0.11), Vector3(0, 0.025, 0), _m("cell", {"base": Color(0.45, 0.45, 0.48), "band": Color(0.2, 0.7, 0.95), "band_y": Vector2(-0.02, 0.02), "metal": 0.7, "rough": 0.35, "rust": 0.2, "glow": Color(0.05, 0.25, 0.4)}), Vector3(0, 0, PI * 0.5))
		"scrap_metal": _scrap(root, rng)
		"duct_tape": _torus(root, 0.025, 0.05, {"base": Color(0.55, 0.56, 0.58), "rough": 0.5, "rust": 0.1}, "tape")
		"copper_wire": _torus(root, 0.04, 0.06, {"base": Color(0.72, 0.42, 0.22), "metal": 0.85, "rough": 0.35, "rust": 0.4}, "copper")
		"circuit", "logic_core":
			_mesh(root, _box(Vector3(0.14, 0.008, 0.1)), Vector3(0, 0.004, 0), _m("pcb", {"base": Color(0.12, 0.38, 0.18), "rough": 0.5, "rust": 0.2}))
			for i in 4:
				_mesh(root, _box(Vector3(0.025, 0.008, 0.018)), Vector3(-0.045 + i * 0.03, 0.012, rng.randf_range(-0.03, 0.03)), _m("chip", {"base": Color(0.08, 0.08, 0.09), "rough": 0.4, "rust": 0.0, "glow": Color(0.0, 0.3, 0.5) if id == "logic_core" else Color.BLACK}))
		"gears":
			for i in 2:
				var g := _cyl(0.04 - i * 0.012, 0.012, -1.0, 12)
				_mesh(root, g, Vector3(i * 0.05, 0.006 + i * 0.012, 0), _m("gear", {"base": Color(0.55, 0.55, 0.52), "metal": 0.8, "rough": 0.4, "rust": 0.7}))
				for k in 10:
					var a := k * TAU / 10.0
					_mesh(root, _box(Vector3(0.012, 0.012, 0.012)), Vector3(i * 0.05 + cos(a) * (0.043 - i * 0.012), 0.006 + i * 0.012, sin(a) * (0.043 - i * 0.012)), _m("gear", {}), Vector3(0, -a, 0))
		"fuel_can":
			_mesh(root, _box(Vector3(0.2, 0.26, 0.1)), Vector3(0, 0.13, 0), _m("jerry", {"base": Color(0.55, 0.14, 0.1), "metal": 0.5, "rough": 0.5, "rust": 0.7}))
			_mesh(root, _cyl(0.018, 0.04), Vector3(0.06, 0.28, 0), _m("jerry", {}))
		"glow_fungus":
			for i in 4:
				_mesh(root, _sph(0.025 + rng.randf() * 0.015, 0.03), Vector3(rng.randf_range(-0.04, 0.04), 0.02 + rng.randf() * 0.02, rng.randf_range(-0.04, 0.04)), _m("fungus", {"base": Color(0.5, 0.85, 0.4), "rough": 0.6, "rust": 0.0, "glow": Color(0.2, 0.7, 0.2)}))
		"spur_chip", "medal":
			_mesh(root, _cyl(0.022, 0.006, -1.0, 18), Vector3(0, 0.003, 0), _m("coin" + id, {"base": Color(0.82, 0.82, 0.85) if id == "spur_chip" else Color(0.85, 0.65, 0.25), "metal": 0.95, "rough": 0.25, "rust": 0.15}))
		"bobby_pin":
			_mesh(root, _box(Vector3(0.05, 0.002, 0.004)), Vector3(0, 0.002, 0), _m("pin", {"base": Color(0.2, 0.2, 0.22), "metal": 0.8, "rough": 0.4, "rust": 0.1}))
			_mesh(root, _box(Vector3(0.05, 0.002, 0.004)), Vector3(0, 0.002, 0.008), _m("pin", {}), Vector3(0, 0.08, 0))
		"boar_hide", "vulture_quill":
			if id == "boar_hide":
				_mesh(root, _box(Vector3(0.3, 0.02, 0.22)), Vector3(0, 0.01, 0), _m("hide", {"base": Color(0.42, 0.3, 0.2), "rough": 0.95, "rust": 0.0}), Vector3(0, 0.3, 0.05))
			else:
				_mesh(root, _cyl(0.004, 0.25, 0.0005), Vector3(0, 0.005, 0), _m("quill", {"base": Color(0.25, 0.22, 0.2), "rough": 0.7, "rust": 0.0}), Vector3(0, 0.5, PI * 0.5))
		_:
			_generic(root, id, t, it, rng)
	return root

static func _generic(root: Node3D, id: String, t: String, it: Dictionary, rng: RandomNumberGenerator) -> void:
	match t:
		"weapon":
			var mdl: Array = preload("res://scripts/player.gd").model_for(id)
			if not mdl.is_empty():
				var g := (load(mdl[0]) as PackedScene).instantiate() as Node3D
				var holder := Node3D.new()
				root.add_child(holder)
				holder.add_child(g)
				g.transform = Transform3D(mdl[1], Vector3.ZERO)
				GunPaint.apply(g, mdl[2])
				# on its side, at life size
				holder.rotation = Vector3(0, rng.randf() * TAU, PI * 0.5)
				holder.scale = Vector3.ONE * 0.85
				holder.position.y = 0.03
				for c in g.find_children("*", "GeometryInstance3D", true, false):
					(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				return
			if it.has("mglb"):
				var w := (load("res://guns/" + String(it.mglb) + ".glb") as PackedScene).instantiate() as Node3D
				w.scale = Vector3.ONE * float(it.get("ms", 1.0))
				w.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0)
				w.position.y = 0.03
				root.add_child(w)
				return
			# a blade or club
			_mesh(root, _box(Vector3(0.42, 0.02, 0.04)), Vector3(0, 0.01, 0), _m("blade", {"base": Color(0.6, 0.6, 0.62), "metal": 0.8, "rough": 0.35, "rust": 0.4}), Vector3(0, rng.randf() * TAU, 0))
		"armor":
			# folded clothes
			var col := Color(0.32, 0.27, 0.2)
			if "vault" in id:
				col = Color(0.2, 0.3, 0.6)
			elif "hazmat" in id:
				col = Color(0.75, 0.65, 0.2)
			elif "robe" in id:
				col = Color(0.45, 0.38, 0.28)
			for i in 3:
				_mesh(root, _box(Vector3(0.36 - i * 0.02, 0.03, 0.28 - i * 0.015)), Vector3(0, 0.015 + i * 0.03, 0), _m("cloth" + id, {"base": col, "rough": 0.95, "rust": 0.25}), Vector3(0, i * 0.05, 0))
		"quest":
			if "key" in id or "card" in id or "badge" in id or "tags" in id:
				_mesh(root, _box(Vector3(0.085, 0.004, 0.055)), Vector3(0, 0.002, 0), _m("card" + id, {"base": Color(0.8, 0.75, 0.55) if "card" in id else Color(0.7, 0.7, 0.72), "band": Color(0.75, 0.15, 0.1), "metal": 0.5, "rough": 0.4, "rust": 0.2}))
			elif id in ["holotape", "black_box", "reactor_logs", "trade_ledger", "toll_ledger", "ledger_pages"]:
				_mesh(root, _box(Vector3(0.1, 0.025, 0.07)), Vector3(0, 0.0125, 0), _m("tape" + id, {"base": Color(0.18, 0.18, 0.2) if id != "black_box" else Color(0.85, 0.35, 0.1), "band": Color(0.85, 0.8, 0.6), "band_y": Vector2(-0.006, 0.006), "rough": 0.5, "rust": 0.2}))
			elif id in ["fusion_cell", "regulator", "water_chip", "fuel_injector"]:
				_mesh(root, _cyl(0.04, 0.16), Vector3(0, 0.04, 0), _m("part" + id, {"base": Color(0.5, 0.52, 0.55), "band": Color(0.95, 0.75, 0.15), "band_y": Vector2(-0.02, 0.02), "metal": 0.8, "rough": 0.35, "rust": 0.3, "glow": Color(0.1, 0.35, 0.1) if id == "fusion_cell" else Color.BLACK}), Vector3(0, 0, PI * 0.5))
			else:
				# a small wrapped parcel tied with string
				_mesh(root, _box(Vector3(0.14, 0.07, 0.1)), Vector3(0, 0.035, 0), _m("parcel", {"base": Color(0.62, 0.5, 0.34), "band": Color(0.85, 0.8, 0.65), "band_y": Vector2(-0.005, 0.005), "rough": 0.95, "rust": 0.2}))
		_:
			_mesh(root, _box(Vector3(0.18, 0.1, 0.14)), Vector3(0, 0.05, 0), _m("crate", {"base": Color(0.5, 0.4, 0.28), "band": Color(0.3, 0.3, 0.28), "band_y": Vector2(-0.01, 0.01), "rough": 0.9, "rust": 0.3}))
