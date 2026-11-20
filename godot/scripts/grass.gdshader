// Dry grass tufts (a MultiMesh of crossed blades) that sway in the wind and fade out at a distance.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_col : source_color = vec3(0.42, 0.38, 0.2);
uniform vec3 tip_col : source_color = vec3(0.78, 0.68, 0.4);

varying float h;
void vertex() {
	h = VERTEX.y;
	vec3 w = (MODEL_MATRIX * vec4(0, 0, 0, 1)).xyz;
	float sway = sin(TIME * 1.6 + w.x * 0.21 + w.z * 0.17) * 0.12 + sin(TIME * 3.3 + w.x) * 0.03;
	VERTEX.x += sway * h * h;
	VERTEX.z += sway * 0.6 * h * h;
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float blade = step(x, 1.0 - UV.y * 0.92);
	if (blade < 0.5) discard;
	ALBEDO = mix(base_col * 0.6, tip_col, clamp(h * 1.4, 0.0, 1.0)) * COLOR.rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.22, 0.1);
}
