// The irradiated pools: murky green water that glows faintly from below and ripples.
shader_type spatial;
render_mode cull_disabled;

uniform float radius = 5.0;

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
	float r = length(UV - 0.5) * 2.0;
	float n = vnoise(p * 1.3 + TIME * 0.4) * 0.5 + vnoise(p * 3.1 - TIME * 0.6) * 0.5;
	vec3 deep = vec3(0.12, 0.3, 0.06);
	vec3 glow = vec3(0.45, 0.95, 0.2);
	ALBEDO = mix(deep, glow * 0.6, n * 0.35);
	EMISSION = glow * (0.18 + 0.25 * (1.0 - r) + n * 0.12) * (0.8 + 0.2 * sin(TIME * 1.7));
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.7;
	float e = 0.06;
	NORMAL_MAP = normalize(vec3(vnoise(p * 2.0 + TIME) - vnoise(p * 2.0 + TIME + e), vnoise(p * 2.0 - TIME) - vnoise(p * 2.0 - TIME + e), 0.25)) * 0.5 + 0.5;
	ALPHA = smoothstep(1.0, 0.85, r) * 0.92;
}
