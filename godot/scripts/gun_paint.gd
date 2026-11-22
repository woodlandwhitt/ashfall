# A gun's finish. The zee and Kenney models come in bright toy paint (orange furniture, purple and yellow blasters);
# this repaints the saturated parts in a worn wasteland finish (gunmetal, rust, nickel, olive drab, bone, black or
# gold), darkens the light greys to steel, and adds grime, so each weapon looks used and looks like itself.
class_name GunPaint

const FINISH := {
	"": Color(0.27, 0.26, 0.25), "rust": Color(0.4, 0.22, 0.12), "nickel": Color(0.72, 0.73, 0.75), "gold": Color(0.74, 0.56, 0.22),
	"black": Color(0.1, 0.1, 0.11), "olive": Color(0.29, 0.32, 0.19), "bone": Color(0.62, 0.56, 0.45), "energy": Color(0.2, 0.25, 0.27),
}
static var _shader: Shader
static var _cache := {}

static func apply(root: Node, gf: Dictionary) -> void:
	var glb := String(gf.get("glb", ""))
	if not (glb.begins_with("lp_") or glb.begins_with("bl/") or gf.has("finish")):
		return
	var fin := String(gf.get("finish", ""))
	var toy := glb.begins_with("bl/")
	if fin == "" and toy:
		fin = "energy"
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			if src is StandardMaterial3D:
				m.set_surface_override_material(s, _mat(src as StandardMaterial3D, fin, toy))

static func _mat(src: StandardMaterial3D, fin: String, toy: bool) -> ShaderMaterial:
	var key := "%d|%s|%s" % [src.get_instance_id(), fin, toy]
	if _cache.has(key):
		return _cache[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("base", src.albedo_color)
	m.set_shader_parameter("use_tex", src.albedo_texture != null)
	if src.albedo_texture:
		m.set_shader_parameter("tex", src.albedo_texture)
	var c: Color = FINISH.get(fin, FINISH[""])
	m.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("paint", 0.92 if toy else 0.85)
	m.set_shader_parameter("band", Vector2(0.1, 0.3) if toy else Vector2(0.38, 0.6))
	m.set_shader_parameter("steel", 0.5 if toy else 0.85)
	m.set_shader_parameter("shine", 0.75 if fin in ["nickel", "gold"] else 0.25)
	m.set_shader_parameter("grime", 0.12 if fin in ["nickel", "gold"] else 0.3)
	_cache[key] = m
	return m

const CODE := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform vec4 base : source_color = vec4(1.0);
uniform vec3 tint = vec3(0.3);
uniform float paint = 0.85;
uniform vec2 band = vec2(0.1, 0.3);
uniform float steel = 0.8;
uniform float shine = 0.25;
uniform float grime = 0.3;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void fragment() {
	vec3 c = base.rgb;
	if (use_tex) c *= texture(tex, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float k = paint * smoothstep(band.x, band.y, sat);
	vec3 painted = tint * (0.6 + l * 0.8);
	// the rest keeps its colour (wood, steel, olive), darkened a little; the toys' light greys go to steel
	c = mix(c * steel, painted, k);
	float n = h(floor(lp * 55.0)) * 0.6 + h(floor(lp * 13.0)) * 0.4;
	c *= 1.0 - grime * (0.15 + 0.5 * n * n);
	ALBEDO = c;
	METALLIC = mix(0.55, shine, k);
	ROUGHNESS = mix(0.45, 0.7 - shine * 0.4, k) + n * 0.1;
}
"""
