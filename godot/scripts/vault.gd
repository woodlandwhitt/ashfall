# Haven 12 dressed properly: panelled ceilings with strip lights over the rooms and the tall entry atrium, sliding
# blast doors in every doorway off the central corridor (they part as people come near), and the great cog door
# itself: a steel wheel with its teeth, frame and number that rolls aside when the vault opens.
class_name VaultDress
extends Node3D

const WH := 3.6
var O := Vector3.ZERO           # the vault's origin (VAULT_O), floor height
var doors: Array = []           # [left leaf, right leaf, centre, axis, half width, open 0..1]
var cog: Node3D
var main

func setup(m) -> void:
	main = m
	var VO: Dictionary = Game.L.consts.VAULT_O
	O = Vector3(float(VO.x), -60.0, float(VO.z))
	_ceilings()
	_lights()
	_doors()
	_walls()
	_locker()
	_great_door()

func P(x: float, y: float, z: float) -> Vector3:
	return O + Vector3(x, y, z)

static func mat(c: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# no sky down here to reflect, so real metal reads as black: paint it instead
	m.metallic = minf(metal, 0.25)
	m.roughness = rough
	return m

func box(size: Vector3, at: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	(parent if parent else self).add_child(mi)
	return mi

# the exported furniture was lit by the WebView build's lamps and looks coal-black under ours: lift it
var seen := {}
var wall_mat: ShaderMaterial
# the exported walls were cream plaster; a shelter is built of painted steel plate: replace them with panels
const PLASTER := "4eae9bc5-e2e7"
func _wall_material() -> ShaderMaterial:
	if wall_mat:
		return wall_mat
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 paint : source_color = vec3(0.4, 0.45, 0.43);
uniform float floor_y = -60.0;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	float u = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	float y = wp.y - floor_y;
	vec2 p = vec2(u / 1.5, y / 1.2);
	vec2 cell = floor(p);
	vec2 f = abs(fract(p) - 0.5);
	float seam = smoothstep(0.475, 0.5, max(f.x, f.y));
	float n = h(cell);
	vec3 c = paint * (0.9 + n * 0.12);
	// a lighter cap rail at shoulder height, grime collecting low down
	c = mix(c, paint * 1.18, smoothstep(1.98, 2.0, y) * (1.0 - smoothstep(2.12, 2.14, y)));
	c *= mix(0.78, 1.0, smoothstep(0.0, 1.4, y));
	c = mix(c, paint * 0.42, seam);
	float rivet = 1.0 - step(0.022, length(vec2(abs(fract(p.x) - 0.5) - 0.44, abs(fract(p.y) - 0.5) - 0.42) * vec2(1.5, 1.2)));
	c = mix(c, paint * 0.6, rivet);
	ALBEDO = c;
	METALLIC = 0.25;
	ROUGHNESS = 0.65 + n * 0.15;
	SPECULAR = 0.3;
}"""
	wall_mat = ShaderMaterial.new()
	wall_mat.shader = sh
	wall_mat.set_shader_parameter("floor_y", O.y)
	return wall_mat

func brighten(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture and PLASTER in (m as StandardMaterial3D).albedo_texture.resource_path:
				(mi as MeshInstance3D).set_surface_override_material(i, _wall_material())
				continue
			if m is StandardMaterial3D and not seen.has(m):
				seen[m] = true
				var sm := m as StandardMaterial3D
				# walls built for one side only show the void from the other: draw every face both ways
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
				if sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					sm.albedo_color = sm.albedo_color * 0.82
					continue
				sm.albedo_color = sm.albedo_color * 1.2
				sm.metallic = minf(sm.metallic, 0.2)

# ---------------------------------------------------------------- ceilings
func _ceilings() -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 base : source_color = vec3(0.3, 0.32, 0.33);
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz / vec2(1.2, 2.4);
	vec2 f = abs(fract(p) - 0.5);
	float seam = smoothstep(0.47, 0.5, max(f.x, f.y));
	float n = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = base * (0.92 + n * 0.12);
	c = mix(c, base * 0.45, seam);
	float rivet = step(length(f - vec2(0.44, 0.44)), 0.025);
	ALBEDO = mix(c, base * 0.7, rivet);
	METALLIC = 0.25;
	ROUGHNESS = 0.6;
}"""
	var cm := ShaderMaterial.new()
	cm.shader = sh
	# a linoleum tile floor laid over the bare slab (the painted stripes and rugs stay on top)
	var fsh := Shader.new()
	fsh.code = """shader_type spatial;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz / 1.0;
	vec2 f = abs(fract(p) - 0.5);
	float seam = smoothstep(0.475, 0.5, max(f.x, f.y));
	float n = fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
	float chk = mod(floor(p.x) + floor(p.y), 2.0);
	vec3 c = mix(vec3(0.25, 0.26, 0.26), vec3(0.19, 0.21, 0.22), chk) * (0.94 + n * 0.08);
	ALBEDO = mix(c, vec3(0.2), seam);
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
}"""
	var fm := ShaderMaterial.new()
	fm.shader = fsh
	box(Vector3(54.0, 0.004, 76.0), P(0, 0.003, 38.0), fm)
	box(Vector3(24.4, 0.004, 17.6), P(0, 0.003, 83.6), fm)
	# rooms and corridor under one 3.6 m ceiling; the entry atrium is twice as tall
	box(Vector3(54.0, 0.04, 76.0), P(0, WH - 0.03, 38.0), cm)
	box(Vector3(24.4, 0.04, 17.6), P(0, 7.17, 83.6), cm)

# ---------------------------------------------------------------- strip lights (main.js light(): VAULT.lights)
const LIGHTS := [[-14, 9], [-14, 21], [-14, 32], [-14, 44, 1], [-14, 56, 1], [-14, 68], [10, 8], [18, 8], [14, 16, 1], [14, 28], [14, 38],
	[14, 46], [13, 56], [14, 68], [0, 12], [0, 30], [0, 48], [0, 66]]

func _lights() -> void:
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1.25, 1.28, 1.3)
	for L in LIGHTS:
		var warm: bool = L.size() > 2
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.9, 0.75) if warm else Color(0.9, 0.95, 1.0)
		l.light_energy = 1.2
		l.omni_range = 12.0
		l.omni_attenuation = 0.8
		l.shadow_enabled = false
		add_child(l)
		l.position = P(float(L[0]), WH - 0.5, float(L[1]))
	for a in [[-6, 80, 7.2], [6, 80, 7.2], [0, 86, 7.2], [0, 89.5, 5.4]]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.95, 0.96, 1.0)
		l.light_energy = 1.6
		l.omni_range = 14.0
		add_child(l)
		l.position = P(float(a[0]), float(a[2]) - 0.6, float(a[1]))
	# light boxes in the atrium ceiling
	for x in [-6.0, 0.0, 6.0]:
		for z in [79.0, 84.0, 89.0]:
			box(Vector3(1.4, 0.06, 0.5), P(x, 7.12, z), lm)

# ---------------------------------------------------------------- sliding doors
const DOORWAYS := [[-2, 10], [-2, 21], [-2, 32], [-2, 44], [-2, 56], [-2, 68], [2, 28], [2, 42], [2, 56], [2, 68]]

func _doors() -> void:
	var leaf := mat(Color(0.36, 0.5, 0.5), 0.45, 0.45)
	var stripe := mat(Color(0.85, 0.68, 0.2), 0.2, 0.6)
	var dark := mat(Color(0.16, 0.17, 0.18), 0.5, 0.5)
	for d in DOORWAYS:
		var c := P(float(d[0]), 0, float(d[1]))
		var halves: Array = []
		for s in [-1.0, 1.0]:
			var h := Node3D.new()
			add_child(h)
			h.position = c + Vector3(0, 0, s * 0.4)
			box(Vector3(0.08, 2.36, 0.8), Vector3(0, 1.18, 0), leaf, h)
			box(Vector3(0.1, 0.12, 0.8), Vector3(0, 1.25, 0), stripe, h)
			box(Vector3(0.1, 0.5, 0.06), Vector3(0, 1.2, -s * 0.37), dark, h)
			halves.append(h)
		doors.append({"l": halves[0], "r": halves[1], "c": c, "open": 0.0})

# the security locker with your gear in it (the original drew it separately, so it never reached the export)
func _locker() -> void:
	var body := mat(Color(0.32, 0.38, 0.36), 0.6, 0.45)
	var trim := mat(Color(0.85, 0.68, 0.2), 0.2, 0.6)
	var dark := mat(Color(0.1, 0.1, 0.11), 0.5, 0.5)
	var g := Node3D.new()
	add_child(g)
	g.position = P(-19.0, 0.0, 73.4)
	g.rotation.y = PI    # doors toward the room, back to the wall
	box(Vector3(1.6, 2.0, 0.55), Vector3(0, 1.0, 0), body, g)
	for x in [-0.4, 0.4]:
		box(Vector3(0.76, 1.9, 0.02), Vector3(x, 1.0, 0.285), mat(Color(0.36, 0.43, 0.41), 0.6, 0.4), g)
		for y in [1.7, 1.62, 1.54]:
			box(Vector3(0.5, 0.025, 0.03), Vector3(x, y, 0.3), dark, g)
		box(Vector3(0.04, 0.22, 0.05), Vector3(x + (0.3 if x < 0 else -0.3), 1.0, 0.31), dark, g)
	box(Vector3(1.62, 0.12, 0.57), Vector3(0, 2.0, 0), trim, g)
	var l := Label3D.new()
	l.text = "SECURITY"
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = Color(0.1, 0.08, 0.02)
	l.outline_size = 0
	l.position = Vector3(0, 2.0, 0.29)
	g.add_child(l)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.0, 0.55)
	cs.shape = bs
	cs.position.y = 1.0
	sb.add_child(cs)
	g.add_child(sb)

# steel ribs down the corridor walls between the doors, and up the atrium's tall sides
func _walls() -> void:
	var steel := mat(Color(0.5, 0.53, 0.55), 0.55, 0.45)
	var cap := mat(Color(0.2, 0.42, 0.42), 0.3, 0.55)
	var z := 4.0
	while z <= 72.0:
		for sx in [-1.0, 1.0]:
			var clear := true
			for d in DOORWAYS:
				if signf(float(d[0])) == sx and absf(z - float(d[1])) < 1.3:
					clear = false
			if clear:
				box(Vector3(0.12, WH - 0.05, 0.22), P(sx * 1.93, (WH - 0.05) * 0.5, z), steel)
				box(Vector3(0.16, 0.14, 0.26), P(sx * 1.91, 0.07, z), cap)
		z += 3.0
	for sx in [-1.0, 1.0]:
		var az := 76.0
		while az <= 91.0:
			box(Vector3(0.16, 7.1, 0.3), P(sx * 12.1, 3.55, az), steel)
			az += 2.5

func _process(dt: float) -> void:
	var who: Array = [Game.player] + main.npcs
	for d in doors:
		var want := 0.0
		for n in who:
			if is_instance_valid(n) and Vector2(n.global_position.x - d.c.x, n.global_position.z - d.c.z).length() < 2.8:
				want = 1.0
				break
		if want > d.open and d.open == 0.0:
			Sfx.play_at("o_hatch_open", d.c + Vector3.UP, -10.0, 1.3)
		d.open = move_toward(d.open, want, dt * 2.2)
		var o: float = d.open * 0.78
		d.l.position.z = d.c.z - 0.4 - o
		d.r.position.z = d.c.z + 0.4 + o

# ---------------------------------------------------------------- the great door
func _great_door() -> void:
	var steel := mat(Color(0.5, 0.53, 0.54), 0.55, 0.45)
	var dark := mat(Color(0.25, 0.27, 0.28), 0.5, 0.5)
	var yel := mat(Color(0.85, 0.66, 0.16), 0.2, 0.55)
	var void_m := StandardMaterial3D.new()
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_m.albedo_color = Color(0.01, 0.01, 0.012)
	var centre := P(0, 3.05, 90.75)
	# the dark tunnel behind the wheel, and the frame round it
	var hole := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 3.05
	hc.bottom_radius = 3.05
	hc.height = 0.02
	hc.radial_segments = 40
	hole.mesh = hc
	hole.material_override = void_m
	hole.rotation.x = PI / 2
	hole.position = P(0, 3.05, 91.08)
	add_child(hole)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.1
	tm.outer_radius = 3.55
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = dark
	ring.rotation.x = PI / 2
	ring.position = P(0, 3.05, 91.0)
	add_child(ring)
	# the wheel
	cog = Node3D.new()
	add_child(cog)
	cog.position = centre
	var disc := CylinderMesh.new()
	disc.top_radius = 2.95
	disc.bottom_radius = 2.95
	disc.height = 0.5
	disc.radial_segments = 48
	var dm := MeshInstance3D.new()
	dm.mesh = disc
	dm.material_override = steel
	dm.rotation.x = PI / 2
	cog.add_child(dm)
	for i in 12:
		var a := i / 12.0 * TAU
		var t := box(Vector3(0.55, 0.42, 0.5), Vector3(cos(a) * 3.05, sin(a) * 3.05, 0), steel, cog)
		t.rotation.z = a
	# raised rings and the hub
	for r in [[2.5, 0.12], [1.15, 0.2]]:
		var rr := MeshInstance3D.new()
		var t2 := TorusMesh.new()
		t2.inner_radius = r[0] - r[1]
		t2.outer_radius = r[0] + r[1]
		t2.rings = 40
		t2.ring_segments = 6
		rr.mesh = t2
		rr.material_override = dark
		rr.rotation.x = PI / 2
		rr.position.z = -0.27
		cog.add_child(rr)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.75
	hub.bottom_radius = 0.9
	hub.height = 0.35
	var hm := MeshInstance3D.new()
	hm.mesh = hub
	hm.material_override = dark
	hm.rotation.x = -PI / 2
	hm.position.z = -0.35
	cog.add_child(hm)
	for i in 3:
		var a := i / 3.0 * TAU + 0.52
		var spoke := box(Vector3(1.6, 0.32, 0.12), Vector3(cos(a) * 1.85, sin(a) * 1.85, -0.3), dark, cog)
		spoke.rotation.z = a
	# the painted number
	var num := Label3D.new()
	num.text = "12"
	num.font_size = 256
	num.pixel_size = 0.006
	num.modulate = Color(0.9, 0.72, 0.2)
	num.outline_size = 0
	num.position = Vector3(0, -1.75, -0.27)
	num.rotation.y = PI
	cog.add_child(num)
	# a hazard band across the floor in front of the door rail
	box(Vector3(7.0, 0.3, 0.6), P(0, 0.15, 90.6), yel).visible = false

# the wheel pulls out of its seat and rolls aside on its rail
func open_great_door() -> void:
	if cog == null:
		return
	Sfx.play("o_bigdoor")
	var tw := create_tween()
	tw.tween_property(cog, "position", cog.position + Vector3(0, 0, -0.7), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cog, "position", cog.position + Vector3(6.4, 0, -0.7), 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(cog, "rotation:z", -6.4 / 3.0, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
