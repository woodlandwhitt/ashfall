# The Hole (the Lattice): where a second dose of ketarad drops you, for as long as the K-hole lasts (khole.js). Everything
# here is drawn and animated by this node: rolling ground in moving rainbow bands, a swirling sky with blinking stars,
# impossible architecture (spinning rings, stairs to nowhere, doors that swing on their own, an eye in the sky, trees
# hanging upside down, glyph stones), and creatures that are mostly other creatures (stilt-whales, jelly-moths,
# eye-snakes, clock-deer). It also runs the clock: when it reaches zero, main.khole_end() brings you back.
class_name KHole
extends Node3D

const X := -2500.0
const Z := 0.0
const R := 250.0
const Y := -30.0
const GLYPHS := ["OLLOM", "VESH", "KRR", "TIKKA", "VOON", "ZHAA", "NE", "POR", "UUL"]

var main
var ground_mat: ShaderMaterial
var flash := 0.0
var tt := 0.0
var statics: Array = []      # [node, spin vector] or [door, index]
var eye: Node3D
var creatures: Array = []
var shards: Dictionary = {}  # point id -> mesh
var timer_lbl: Label
var dressed: Dictionary = {}
var ending := false

static func kh(x: float, z: float) -> float:
	var lx := x - X
	var lz := z - Z
	var d := sqrt(lx * lx + lz * lz)
	return Y + 2.4 * sin(lx * 0.035) * cos(lz * 0.03) + 1.1 * sin((lx + lz) * 0.08) + 0.5 * sin(lx * 0.21 + cos(lz * 0.13) * 2.0) + pow(maxf(0.0, d - R * 0.78), 2.0) * 0.012

static func pastel(h: float) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), 0.45, 0.85)

static func glow(c: Color, e := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.roughness = 0.4
	return m

static func plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m

# the sky and light of the Hole (main._environment calls this in place of the valley's)
static func environment(env: Environment, sun: DirectionalLight3D) -> void:
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type sky;
vec3 pal(float t){return .5+.5*cos(6.2832*(vec3(.1,.4,.7)+t));}
float h(vec3 p){return fract(sin(dot(p,vec3(12.9,78.2,37.7)))*43758.5);}
void sky(){vec3 d=EYEDIR;float a=atan(d.z,d.x),e=d.y;float sw=sin(a*3.+e*6.-TIME*.15)+sin(a*5.-e*9.+TIME*.1)*.5;
 vec3 c=pal(sw*.15+e*.4+TIME*.01)*.7;c=mix(c,vec3(.05,.02,.12),smoothstep(.2,.9,e));
 vec3 q=floor(d*120.);float st=step(.996,h(q))*(.5+.5*sin(TIME*3.+h(q+1.)*40.));COLOR=c+st;}"""
	sm.shader = sh
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.8, 0.95)
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.55, 0.85)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	sun.light_color = Color(1.0, 0.92, 1.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	sun.rotation = Vector3(deg_to_rad(-60.0), deg_to_rad(30.0), 0)

func setup(m) -> void:
	main = m
	_ground()
	_architecture()
	_creatures()
	_shards()
	timer_lbl = Label.new()
	timer_lbl.add_theme_font_size_override("font_size", 22)
	timer_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.42, 0.85))
	timer_lbl.add_theme_constant_override("outline_size", 6)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_lbl.position = Vector2(-120, 64)
	timer_lbl.size = Vector2(240, 30)
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.hud.root.add_child(timer_lbl)

func pulse() -> void:
	flash = 0.35

# ---------------------------------------------------------------- ground
func _ground() -> void:
	var E := R + 80.0
	var n := 181
	var step := E * 2.0 / (n - 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for b in n:
		for a in n:
			var x := X - E + a * step
			var z := Z - E + b * step
			verts[b * n + a] = Vector3(x, kh(x, z), z)
			norms[b * n + a] = Vector3(kh(x - 1, z) - kh(x + 1, z), 2.0, kh(x, z - 1) - kh(x, z + 1)).normalized()
	var idx := PackedInt32Array()
	for b in n - 1:
		for a in n - 1:
			var q := b * n + a
			idx.append_array([q, q + 1, q + n, q + 1, q + n + 1, q + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float flash = 0.0;
varying vec3 wp;
varying vec3 wn;
vec3 pal(float t){return .55+.45*cos(6.2832*(vec3(0.,.33,.67)+t));}
void vertex(){wp=VERTEX;wn=NORMAL;}
void fragment(){float t=dot(wp.xz,vec2(.012,.009))+wp.y*.06+TIME*.035;vec3 c=pal(t)*.75+pal(t*2.3+.4)*.25;
 vec2 g=abs(fract(wp.xz*.125+vec2(sin(TIME*.2),cos(TIME*.17))*.1)-.5);float line=smoothstep(.47,.5,max(g.x,g.y));c+=vec3(.9,1.,1.)*line*.35;
 float l=.55+.45*max(0.,dot(normalize(wn),normalize(vec3(.3,1.,.2))));c*=l;
 float d=distance(wp.xz,CAMERA_POSITION_WORLD.xz);vec3 hz=pal(TIME*.02+.6)*.6+.25;c=mix(c,hz,smoothstep(60.,220.,d));c+=flash;
 ALBEDO=c;}"""
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 50.0
	add_child(mi)

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi

static func box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func ball(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

static func cyl(top: float, bot: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	c.radial_segments = seg
	return c

# ---------------------------------------------------------------- impossible architecture
func _architecture() -> void:
	for i in 7:
		var tm := TorusMesh.new()
		tm.inner_radius = 8.0 + i * 3.0 - (0.5 + i * 0.12)
		tm.outer_radius = 8.0 + i * 3.0 + (0.5 + i * 0.12)
		tm.rings = 48
		tm.ring_segments = 10
		var t := _mesh(tm, glow(pastel(i * 0.13), 0.8), Vector3(X + cos(i * 0.9) * 90.0, Y + 20.0 + i * 6.0, Z + sin(i * 0.9) * 90.0))
		statics.append([t, Vector3(0.1 + i * 0.03, 0.07, 0.05 * i)])
	# stairs to nowhere
	for s in 3:
		var a := s * 2.1 + 0.4
		var bx := X + cos(a) * 55.0
		var bz := Z + sin(a) * 55.0
		var g := Node3D.new()
		add_child(g)
		g.position = Vector3(bx, kh(bx, bz) + (6.0 if s == 1 else 0.0), bz)
		g.rotation.y = -a + PI / 2
		for k in 16:
			_mesh(box(Vector3(3, 0.4, 1.2)), glow(pastel(0.6 + k * 0.02), 0.25), Vector3(0, k * 0.55, -k * 1.1), g)
	# doors that open onto nothing
	for d in 6:
		var a := d * 1.05
		var dx := X + cos(a) * (30.0 + d * 9.0)
		var dz := Z + sin(a) * (30.0 + d * 9.0)
		var fr := Node3D.new()
		add_child(fr)
		fr.position = Vector3(dx, kh(dx, dz), dz)
		fr.rotation.y = a
		var wood := plain(pastel(d * 0.17).darkened(0.3))
		for sx in [-0.6, 0.6]:
			_mesh(box(Vector3(0.15, 2.4, 0.15)), wood, Vector3(sx, 1.2, 0), fr)
		_mesh(box(Vector3(1.35, 0.15, 0.15)), wood, Vector3(0, 2.4, 0), fr)
		var hinge := Node3D.new()
		hinge.position = Vector3(0.5, 0, 0)
		fr.add_child(hinge)
		var dm := glow(Color.WHITE, 0.9)
		dm.emission = pastel(d * 0.21)
		_mesh(box(Vector3(1.05, 2.3, 0.08)), dm, Vector3(-0.5, 1.15, 0), hinge)
		statics.append([hinge, d])
	# the eye in the sky watches you
	eye = Node3D.new()
	add_child(eye)
	eye.position = Vector3(X + 20.0, Y + 55.0, Z - 110.0)
	var em := plain(Color(0.97, 0.94, 0.94))
	em.emission_enabled = true
	em.emission = Color(0.27, 0.13, 0.27)
	_mesh(ball(9.0, 32), em, Vector3.ZERO, eye)
	var iris := CylinderMesh.new()
	iris.top_radius = 4.0
	iris.bottom_radius = 4.0
	iris.height = 0.1
	var im := StandardMaterial3D.new()
	im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	im.albedo_color = Color(0.48, 0.23, 1.0)
	_mesh(iris, im, Vector3(0, 0, -8.95), eye).rotation.x = PI / 2
	var pu := cyl(1.8, 1.8, 0.12, 24)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.02, 0, 0.03)
	_mesh(pu, pm, Vector3(0, 0, -9.0), eye).rotation.x = PI / 2
	# upside-down trees hanging from nothing
	for i in 12:
		var a := i * 0.52
		var r := 70.0 + (i % 3) * 25.0
		var tx := X + cos(a) * r
		var tz := Z + sin(a) * r
		var ty := kh(tx, tz) + 18.0 + (i % 4) * 4.0
		_mesh(cyl(0.35, 0.6, 7.0, 7), plain(pastel(0.05 + i * 0.03).darkened(0.4)), Vector3(tx, ty, tz))
		var cr := _mesh(cyl(0.0, 3.4, 6.0, 9), glow(pastel(0.3 + i * 0.05), 0.4), Vector3(tx, ty - 6.0, tz))
		cr.rotation.x = PI
	# glyph monoliths
	for i in 8:
		var a := i * 0.79 + 0.3
		var r := 40.0 + (i % 2) * 30.0
		var mx := X + cos(a) * r
		var mz := Z + sin(a) * r
		var mono := Node3D.new()
		add_child(mono)
		mono.position = Vector3(mx, kh(mx, mz) + 4.2, mz)
		mono.rotation = Vector3(0, -a, (i % 3 - 1) * 0.12)
		var mm := plain(Color(0.16, 0.14, 0.25))
		mm.emission_enabled = true
		mm.emission = Color(0.13, 0.09, 0.27)
		_mesh(box(Vector3(2.4, 9, 1)), mm, Vector3.ZERO, mono)
		for sd in [1, -1]:
			var l := Label3D.new()
			l.text = "\n".join(GLYPHS[i % GLYPHS.size()].split(""))
			l.font_size = 96
			l.pixel_size = 0.012
			l.modulate = Color(0.6, 1.0, 0.92)
			l.outline_size = 0
			l.position = Vector3(0, 0.5, 0.51 * sd)
			l.rotation.y = 0.0 if sd > 0 else PI
			mono.add_child(l)
	# the glyph stone (a terminal of sorts)
	var gs := plain(Color(0.29, 0.23, 0.42))
	gs.emission_enabled = true
	gs.emission = Color(0.15, 0.1, 0.3)
	_mesh(box(Vector3(1.4, 2.4, 0.5)), gs, Vector3(X - 8.0, kh(X - 8.0, Z - 6.0) - 0.3 + 1.2, Z - 5.6))

# ---------------------------------------------------------------- creatures
func _creatures() -> void:
	# stilt-whales: a whale body walking very slowly on four impossibly long legs
	for i in 4:
		var g := Node3D.new()
		add_child(g)
		var body := _mesh(ball(1.0, 20), plain(pastel(0.55 + i * 0.07)), Vector3(0, 11, 0), g)
		body.scale = Vector3(4.5, 1.6, 1.8)
		var legs: Array = []
		for lp in [[-2.4, -0.9], [-2.4, 0.9], [2.4, -0.9], [2.4, 0.9]]:
			var L := Node3D.new()
			L.position = Vector3(lp[0], 11, lp[1])
			g.add_child(L)
			_mesh(cyl(0.09, 0.06, 11.0, 5), plain(Color(0.91, 0.88, 0.94)), Vector3(0, -5.5, 0), L)
			legs.append(L)
		for sd in [-1, 1]:
			_mesh(ball(0.25, 8), plain(Color(0.07, 0.07, 0.07)), Vector3(4.1, 11.3, sd * 0.9), g)
		creatures.append({"k": "whale", "o": g, "body": body, "legs": legs, "a": i * 1.6, "r": 60.0 + i * 22.0, "sp": 0.035 + i * 0.008, "ph": float(i)})
	# jelly-moths: glowing bells drifting a few metres up, trailing tentacles
	for i in 10:
		var g := Node3D.new()
		add_child(g)
		var c := pastel(0.8 + i * 0.05)
		var bm := glow(c, 0.7)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color.a = 0.7
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bell := SphereMesh.new()
		bell.radius = 0.9
		bell.height = 0.9
		bell.is_hemisphere = true
		_mesh(bell, bm, Vector3.ZERO, g)
		var tent: Array = []
		var tmat := glow(c, 0.5)
		for k in 6:
			var a := k / 6.0 * TAU
			var piv := Node3D.new()
			piv.position = Vector3(cos(a) * 0.6, 0, sin(a) * 0.6)
			g.add_child(piv)
			_mesh(cyl(0.03, 0.01, 2.4, 4), tmat, Vector3(0, -1.2, 0), piv)
			tent.append(piv)
		creatures.append({"k": "jelly", "o": g, "tent": tent, "x": X + randf_range(-80, 80), "z": Z + randf_range(-80, 80), "ph": i * 1.3})
	# eye-snakes: a string of beads that slides over the ground, led by a single eye
	for i in 5:
		var segs: Array = []
		for k in 12:
			segs.append(_mesh(ball(0.5 - k * 0.025, 10), plain(pastel(0.1 + k * 0.04 + i * 0.2)), Vector3.ZERO))
		var ey := StandardMaterial3D.new()
		ey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh(ball(0.22, 8), ey, Vector3(0, 0.25, 0.35), segs[0])
		creatures.append({"k": "snake", "segs": segs, "cx": X + randf_range(-60, 60), "cz": Z + randf_range(-60, 60), "ph": i * 2.0, "trail": []})
	# clock-deer: boxy deer whose heads are clocks running backwards
	for i in 5:
		var g := Node3D.new()
		add_child(g)
		var m := plain(pastel(0.12 + i * 0.1))
		_mesh(box(Vector3(1.6, 0.7, 0.6)), m, Vector3(0, 1.3, 0), g)
		var legs: Array = []
		for lp in [[-0.6, -0.22], [-0.6, 0.22], [0.6, -0.22], [0.6, 0.22]]:
			var L := Node3D.new()
			L.position = Vector3(lp[0], 1.05, lp[1])
			g.add_child(L)
			_mesh(box(Vector3(0.12, 1, 0.12)), m, Vector3(0, -0.5, 0), L)
			legs.append(L)
		_mesh(box(Vector3(0.2, 0.8, 0.2)), m, Vector3(0.85, 1.8, 0), g).rotation.z = -0.4
		var face := Node3D.new()
		face.position = Vector3(1.15, 2.25, 0)
		g.add_child(face)
		_mesh(cyl(0.42, 0.42, 0.12, 24), m, Vector3.ZERO, face).rotation.z = PI / 2
		var dial := StandardMaterial3D.new()
		dial.albedo_color = Color(0.96, 0.93, 0.85)
		dial.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh(cyl(0.38, 0.38, 0.02, 24), dial, Vector3(0.065, 0, 0), face).rotation.z = PI / 2
		for h in range(1, 13):
			var l := Label3D.new()
			l.text = str(13 - h)
			l.font_size = 32
			l.pixel_size = 0.004
			l.modulate = Color(0.16, 0.16, 0.16)
			l.outline_size = 0
			var a := h / 12.0 * TAU
			l.position = Vector3(0.08, cos(a) * 0.29, -sin(a) * 0.29)
			l.rotation.y = PI / 2
			face.add_child(l)
		var hand := Node3D.new()
		hand.position = Vector3(0.09, 0, 0)
		face.add_child(hand)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.07, 0.07, 0.07)
		_mesh(box(Vector3(0.02, 0.32, 0.03)), hm, Vector3(0, 0.16, 0), hand)
		creatures.append({"k": "deer", "o": g, "legs": legs, "hand": hand, "x": X + randf_range(-70, 70), "z": Z + randf_range(-70, 70), "h": randf() * TAU, "t": 0.0})

# ---------------------------------------------------------------- echo shards (the visible side of the 'echoa..e' points)
func _shards() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.84
	sm.radial_segments = 4
	sm.rings = 1
	var mat := glow(Color(0.6, 1.0, 1.0), 1.4)
	mat.emission = Color(0.4, 1.0, 0.93)
	mat.metallic = 0.3
	mat.roughness = 0.2
	for p in Game.W.get("points", []):
		if p.get("echo") == null:
			continue
		var m := _mesh(sm, mat, Vector3(float(p.x), float(p.y), float(p.z)))
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.95)
		l.light_energy = 1.2
		l.omni_range = 5.0
		m.add_child(l)
		shards[String(p.id)] = [m, int(p.echo)]

# the Hole's people get their odd looks once they're spawned
func _dress(n) -> void:
	dressed[n] = true
	var lk: Dictionary = n.look if n.look is Dictionary else {}
	var sc := float(lk.get("scale", 1.0))
	n.model.scale *= sc
	if lk.get("glow"):
		var l := OmniLight3D.new()
		l.light_color = Color(String(lk.glow))
		l.light_energy = 1.4
		l.omni_range = 4.0
		l.position = Vector3(0, 1.6 * sc, 0.4)
		n.add_child(l)
	if n.id == "gnorl":
		n.model.rotation.z = PI
		n.model.position.y += 1.85
	if n.id == "committee":
		var skel := n.model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel:
			var ba := BoneAttachment3D.new()
			ba.bone_name = "Head"
			skel.add_child(ba)
			var skin := plain(Color(String(lk.get("skin", "#9ad8a8"))).lightened(0.2))
			for sd in [-1, 1]:
				var h := _mesh(ball(0.13, 14), skin, Vector3(sd * 0.3, 0.1, 0), ba)
				h.scale = Vector3(1, 1.15, 1)
				h.rotation.z = sd * 0.35
				for ex in [-0.045, 0.045]:
					_mesh(ball(0.02, 6), plain(Color(1.0, 0.67, 0.13)), Vector3(ex, 0.02, 0.115), h)

func _process(dt: float) -> void:
	tt += dt
	flash = maxf(0.0, flash - dt * 1.5)
	ground_mat.set_shader_parameter("flash", flash)
	for n in main.npcs:
		if is_instance_valid(n) and not dressed.has(n) and n.model:
			_dress(n)
	for s in statics:
		if s[1] is Vector3:
			s[0].rotation += s[1] * dt
		else:
			s[0].rotation.y = sin(tt * 0.6 + s[1]) * 1.2 - 0.6
	var cam := get_viewport().get_camera_3d()
	if cam:
		eye.look_at(cam.global_position)
	for c in creatures:
		match c.k:
			"whale":
				c.a += dt * c.sp
				var x: float = X + cos(c.a) * c.r
				var z: float = Z + sin(c.a) * c.r
				c.o.position = Vector3(x, kh(x, z), z)
				c.o.rotation.y = -c.a + PI / 2
				for i in 4:
					c.legs[i].rotation.z = sin(tt * 1.1 + c.ph + i * 1.57) * 0.28
				c.body.position.y = 11.0 + sin(tt * 1.1 + c.ph) * 0.3
			"jelly":
				c.x += sin(tt * 0.1 + c.ph) * dt * 1.2
				c.z += cos(tt * 0.13 + c.ph) * dt * 1.2
				c.o.position = Vector3(c.x, kh(c.x, c.z) + 4.0 + sin(tt * 0.9 + c.ph) * 1.2, c.z)
				var sq := 1.0 + sin(tt * 2.4 + c.ph) * 0.14
				c.o.scale = Vector3(sq, 2.0 - sq, sq)
				for i in c.tent.size():
					c.tent[i].rotation = Vector3(sin(tt * 2.0 + i + c.ph) * 0.3, 0, cos(tt * 1.7 + i) * 0.3)
			"snake":
				var hx: float = c.cx + sin(tt * 0.35 + c.ph) * 16.0 + sin(tt * 0.9 + c.ph) * 3.0
				var hz: float = c.cz + cos(tt * 0.27 + c.ph) * 16.0
				c.trail.push_front(Vector2(hx, hz))
				if c.trail.size() > 140:
					c.trail.pop_back()
				for k in c.segs.size():
					var p: Vector2 = c.trail[mini(c.trail.size() - 1, k * 6)]
					c.segs[k].position = Vector3(p.x, kh(p.x, p.y) + 0.45 + sin(tt * 4.0 - k * 0.6) * 0.12, p.y)
				if c.trail.size() > 6:
					var a: Vector2 = c.trail[0]
					var b: Vector2 = c.trail[6]
					c.segs[0].rotation.y = atan2(a.x - b.x, a.y - b.y)
			"deer":
				c.t -= dt
				if c.t < 0.0:
					c.h += randf_range(-1.0, 1.0)
					c.t = randf_range(2.0, 6.0)
				c.x += cos(c.h) * dt * 1.4
				c.z += sin(c.h) * dt * 1.4
				if Vector2(c.x - X, c.z - Z).length() > R * 0.7:
					c.h = atan2(Z - c.z, X - c.x)
				c.o.position = Vector3(c.x, kh(c.x, c.z), c.z)
				c.o.rotation.y = -c.h
				for i in 4:
					c.legs[i].rotation.z = sin(tt * 6.0 + i * PI) * 0.4
				c.hand.rotation.x = -tt * 2.0
	for id in shards:
		var m: MeshInstance3D = shards[id][0]
		m.visible = not Game.flags.get("echo_" + str(shards[id][1]))
		if m.visible:
			m.rotation.y += dt * 1.6
			m.rotation.x = sin(tt + m.position.x) * 0.4
	# the Hole has an edge, and you can't walk past it
	var pl = Game.player
	if pl:
		var off := Vector2(pl.global_position.x - X, pl.global_position.z - Z)
		var lim := R * 0.8
		if off.length() > lim:
			off = off.normalized() * lim
			pl.global_position.x = X + off.x
			pl.global_position.z = Z + off.y
	# the clock
	if Game.paused or ending:
		return
	var t := float(Game.flags.get("khT", 120.0)) - dt
	Game.flags["khT"] = t
	var s := maxi(0, ceili(t))
	timer_lbl.text = "K-HOLE  %d:%02d" % [s / 60, s % 60]
	timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.85) if s <= 15 else Color(0.78, 1.0, 0.94))
	if t <= 0.0:
		ending = true
		main.khole_end()
