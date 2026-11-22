# Nothing in the wastes is new. The exported props (traffic cones, barriers, barrels, crates, signs, cars) are painted
# from flat-colour palette atlases and came out looking fresh from the factory; this swaps their material for one
# that bleaches the paint, lays grime and rust streaks down them, settles dust on every upward face and chips edges.
class_name Weathering

static var cache: Dictionary = {}
static var shader: Shader

const CODE := """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float wear = 1.0;
uniform bool vcol = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
varying vec3 wp;
varying vec3 wn;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p){ return vn(p) * 0.55 + vn(p * 2.3 + 7.1) * 0.3 + vn(p * 5.1 + 3.7) * 0.15; }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment(){
	vec3 c = texture(albedo_tex, UV).rgb * (vcol ? COLOR.rgb : vec3(1.0)) * tint.rgb;
	// sun-bleached: the loud colours fade most
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(l), c, mix(0.75, 0.5, sat) * wear + (1.0 - wear)) * mix(1.0, 0.8, wear);
	vec2 side = abs(wn.x) > abs(wn.z) ? wp.zy : wp.xy;
	// patchy grime
	float g = fbm(side * 1.6 + wp.xz * 0.7);
	c *= mix(1.0, mix(0.68, 1.02, smoothstep(0.25, 0.8, g)), wear);
	// rust and dirt running down from the top
	float st = fbm(vec2(side.x * 7.0, side.y * 0.6 + side.x * 0.3));
	c = mix(c, vec3(0.3, 0.17, 0.08), smoothstep(0.6, 0.86, st) * 0.6 * wear);
	// chips and scratches showing bare, dark material
	float ch = vn(side * 22.0 + wp.xz * 9.0);
	c = mix(c, c * 0.45 + vec3(0.05, 0.045, 0.04), step(0.88, ch) * 0.7 * wear);
	// dust settled on everything that faces the sky
	float up = smoothstep(0.35, 0.9, wn.y);
	c = mix(c, vec3(0.6, 0.51, 0.39), up * smoothstep(0.25, 0.75, fbm(wp.xz * 2.5)) * 0.55 * wear);
	ALBEDO = c;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; }
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}"""

# a weathered stand-in for a palette-painted material, or the original if it isn't one
static func material_for(src: Material, wear := 1.0, palettes_only := false, any_texture := false) -> Material:
	if not src is StandardMaterial3D:
		return src
	var sm := src as StandardMaterial3D
	if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return src
	var nm := String(sm.resource_name).to_lower()
	# small props batched with their colours in the vertices (cones, crates, barrels, signs)
	var by_vertex := sm.vertex_color_use_as_albedo and not palettes_only
	if not by_vertex and not any_texture and (sm.albedo_texture == null or not (nm.begins_with("atlas") or nm.begins_with("colormap") or nm.begins_with("q_") or nm.contains("palette"))):
		return src
	var key := str(sm.get_instance_id()) + ":" + str(wear)
	if cache.has(key):
		return cache[key]
	if shader == null:
		shader = Shader.new()
		shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("albedo_tex", sm.albedo_texture if sm.albedo_texture else _white())
	m.set_shader_parameter("vcol", by_vertex)
	if sm.normal_enabled and sm.normal_texture:
		m.set_shader_parameter("normal_tex", sm.normal_texture)
		m.set_shader_parameter("has_normal", true)
	m.set_shader_parameter("tint", sm.albedo_color)
	m.set_shader_parameter("wear", wear)
	cache[key] = m
	return m

static var white_tex: ImageTexture
static func _white() -> Texture2D:
	if white_tex == null:
		var im := Image.create(2, 2, false, Image.FORMAT_RGB8)
		im.fill(Color.WHITE)
		white_tex = ImageTexture.create_from_image(im)
	return white_tex

# weather every palette-painted surface under a node
static func apply(root: Node, wear := 1.0, palettes_only := false, any_texture := false) -> void:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.material_override != null:
			continue
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(i)
			if src == null:
				src = mi.mesh.surface_get_material(i)
			var w := material_for(src, wear, palettes_only, any_texture)
			if w != src:
				mi.set_surface_override_material(i, w)
