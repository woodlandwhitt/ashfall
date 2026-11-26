// Stillwater Reservoir (build 16): still, brown-green water over a silted bed, a slow ripple, the sky in it
// at a glancing angle. The edge fades out where the shallows meet the shore.
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec2 radii = vec2(120.0, 85.0);
uniform vec2 centre = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wp.xz;
	float n = vnoise(p * 0.25 + TIME * 0.05) * 0.6 + vnoise(p * 0.9 - TIME * 0.08) * 0.4;
	vec3 deep = vec3(0.09, 0.13, 0.11);
	vec3 shallow = vec3(0.22, 0.24, 0.17);
	float d = length((p - centre) / radii);
	ALBEDO = mix(deep, shallow, smoothstep(0.6, 1.0, d) * 0.7 + n * 0.15);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	float e = 0.08;
	vec2 q = p * 0.6;
	NORMAL_MAP = normalize(vec3(vnoise(q + TIME * 0.3) - vnoise(q + TIME * 0.3 + vec2(e, 0)), vnoise(q - TIME * 0.25) - vnoise(q - TIME * 0.25 + vec2(0, e)), 0.6)) * 0.5 + 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(0.82 + fres * 0.12, 0.0, 0.95) * smoothstep(1.06, 0.97, d);
}
