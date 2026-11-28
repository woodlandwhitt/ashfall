class_name Scorch
# Chests that have been through it (build 25: "chests look too shiny, make them more like a bomb went off near
# them"). Every chest, strongbox and footlocker you can loot is given a material that keeps its own colours and
# texture, but strips the shine off it (no gloss, the metal dulled), chars it black from one side and from the bottom up
# (the side the blast came from, chosen per chest), blisters and flakes the paint, lays soot in the cracks and ash and
# grit on top, and scorches the brass fittings.

static var _shader: Shader
static var _cache := {}

const CODE := """shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vcol = false;
uniform vec3 blast_dir = vec3(1.0, 0.0, 0.0);
uniform float seed = 0.0;
// 0: its own colours; 1: planks bound with iron straps (a chest whose texture never made it); 2: iron; 3: brass
uniform int kind = 0;
varying vec3 lp;
varying vec3 ln;
varying vec3 wp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p){ return vn(p) * 0.5 + vn(p * 2.1 + 5.3) * 0.3 + vn(p * 4.7 + 1.7) * 0.2; }
void vertex(){ lp = VERTEX; ln = NORMAL; wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec3 c = texture(albedo_tex, UV).rgb * tint.rgb * (vcol ? COLOR.rgb : vec3(1.0));
	vec2 side = abs(ln.x) > abs(ln.z) ? lp.zy : lp.xy;
	side += seed;
	if (kind == 1) {
		// planks running the length of the chest, grain and seams, under iron straps and corner bands
		float plank = floor(lp.y * 11.0 + lp.z * 0.0);
		vec3 wood = vec3(0.34, 0.23, 0.14) * (0.8 + 0.3 * h(vec2(plank, 3.0)));
		wood *= 0.82 + 0.3 * vn(vec2(lp.x * 2.0 + plank * 7.0, lp.y * 60.0));
		wood *= 1.0 - 0.45 * smoothstep(0.42, 0.5, abs(fract(lp.y * 11.0) - 0.5));
		float ax = abs(lp.x);
		float strap = step(abs(ax - 0.3), 0.035) + step(0.43, ax);
		c = mix(wood, vec3(0.17, 0.16, 0.16), clamp(strap, 0.0, 1.0));
	} else if (kind == 2) {
		c = vec3(0.18, 0.17, 0.17);
	} else if (kind == 3) {
		c = vec3(0.4, 0.31, 0.15);
	}
	// bleached and dirtied all over
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l), c, 0.62) * 0.82;
	// charred: the face towards the blast and the lower half, in ragged tongues
	float facing = clamp(dot(normalize(ln), normalize(blast_dir)) * 0.5 + 0.5, 0.0, 1.0);
	float low = clamp(1.0 - (lp.y + 0.1) * 1.6, 0.0, 1.0);
	float tongues = fbm(vec2(side.x * 3.5, side.y * 1.2 - lp.y * 2.0));
	float burn = smoothstep(0.35, 0.85, facing * 0.75 + low * 0.45 + tongues * 0.45 - 0.25);
	c = mix(c, c * 0.25 + vec3(0.03, 0.025, 0.02), burn * 0.85);
	// a hot edge where the char stops: a brown scorch line
	float edge = smoothstep(0.25, 0.5, burn) * (1.0 - smoothstep(0.5, 0.75, burn));
	c = mix(c, vec3(0.28, 0.15, 0.06), edge * 0.45);
	// blistered, flaking paint: bare grey patches
	float fl = vn(side * 14.0 + 3.1);
	c = mix(c, vec3(0.2, 0.19, 0.18), step(0.8, fl) * 0.55);
	// soot in streaks running up from the burn, and grit and ash on whatever faces the sky
	float soot = fbm(vec2(side.x * 9.0, side.y * 0.8));
	c *= mix(1.0, 0.7, smoothstep(0.55, 0.8, soot) * burn);
	float up = smoothstep(0.55, 0.95, ln.y);
	float ash = fbm(wp.xz * 6.0 + seed);
	c = mix(c, vec3(0.42, 0.4, 0.37), up * smoothstep(0.3, 0.75, ash) * 0.6);
	// pitting: shrapnel nicks
	float pit = h(floor(side * 40.0));
	c = mix(c, c * 0.35, step(0.965, pit) * 0.8);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	METALLIC = 0.05;
	SPECULAR = 0.2;
}
"""

static func _white() -> Texture2D:
	if _cache.has("_white"):
		return _cache["_white"]
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	var t := ImageTexture.create_from_image(img)
	_cache["_white"] = t
	return t

static func material_for(src: Material, seed: float, kind := 0) -> Material:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var tex: Texture2D = null
	var col := Color.WHITE
	var vc := false
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		col = (src as BaseMaterial3D).albedo_color
		vc = (src as BaseMaterial3D).vertex_color_use_as_albedo
	elif src is ShaderMaterial:
		var t = (src as ShaderMaterial).get_shader_parameter("albedo_tex")
		if t is Texture2D:
			tex = t
		var tn = (src as ShaderMaterial).get_shader_parameter("tint")
		if tn is Color:
			col = tn
	var k := "%s|%s|%s|%d|%d" % [str(tex.get_rid()) if tex else "-", col.to_html(), str(vc), int(seed) % 4, kind]
	if _cache.has(k):
		return _cache[k]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_tex", tex if tex else _white())
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("vcol", vc)
	# the blast came from one of four sides
	var a := (int(seed) % 4) * PI * 0.5 + 0.6
	m.set_shader_parameter("blast_dir", Vector3(cos(a), -0.2, sin(a)))
	m.set_shader_parameter("seed", float(int(seed) % 4) * 3.7)
	m.set_shader_parameter("kind", kind)
	_cache[k] = m
	return m

# everything drawn under a node (a chest, a footlocker, a safe), blasted
# chest: the old chest model, whose texture never made it into the game (it came out plain white and glossy): its
# body and lid become planks under iron straps, its handles iron, its lock brass, all of it blasted
static func apply(root: Node, seed := 0.0, chest := false) -> void:
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	for n in list:
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.get_meta("scorched", false):
			continue
		mi.set_meta("scorched", true)
		var kind := 0
		if chest:
			var sz := mi.get_aabb().size
			kind = 1 if sz.x > 0.5 else (3 if sz.z < 0.03 else 2)
		if mi.material_override:
			mi.material_override = material_for(mi.material_override, seed, kind)
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			mi.set_surface_override_material(s, material_for(src, seed, kind))
