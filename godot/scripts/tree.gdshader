// Trees of the Ashwood (scripts/flora.gd): vertex-coloured low-poly pines and dead snags. Each instance's colour
// tints the whole tree; the crown sways a little more the higher up it is.
shader_type spatial;
render_mode cull_back;

uniform float sway_k = 1.0;
varying float hh;

void vertex() {
	hh = VERTEX.y;
	vec3 w = (MODEL_MATRIX * vec4(0, 0, 0, 1)).xyz;
	float s = sin(TIME * 0.9 + w.x * 0.07 + w.z * 0.05) * 0.035 + sin(TIME * 2.1 + w.z * 0.3) * 0.01;
	float k = max(0.0, VERTEX.y - 1.5) * sway_k;
	VERTEX.x += s * k;
	VERTEX.z += s * 0.6 * k;
}

void fragment() {
	// a little speckle so the cones don't read as flat plastic
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 q = wp * 7.0;
	float n = fract(sin(dot(floor(q), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float n2 = fract(sin(dot(floor(wp * 1.3), vec3(39.3, 11.1, 71.7))) * 24634.6345);
	ALBEDO = COLOR.rgb * (0.9 + n * 0.12) * (0.92 + n2 * 0.12) * (0.8 + clamp(hh * 0.03, 0.0, 0.3));
	ROUGHNESS = 0.92;
	BACKLIGHT = vec3(0.08, 0.1, 0.04) * COLOR.g;
}
