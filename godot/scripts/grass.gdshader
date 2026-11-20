// Dry grass tufts (a MultiMesh of crossed blades) that sway in the wind and fade out at a distance.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_col : source_color = vec3(0.3, 0.27, 0.16);
uniform vec3 tip_col : source_color = vec3(0.62, 0.55, 0.34);

varying float h;
void vertex() {
	h = VERTEX.y;
	vec3 w = (MODEL_MATRIX * vec4(0, 0, 0, 1)).xyz;
	float sway = sin(TIME * 1.6 + w.x * 0.21 + w.z * 0.17) * 0.12 + sin(TIME * 3.3 + w.x) * 0.03;
	VERTEX.x += sway * h * 2.0;
	VERTEX.z += sway * 1.2 * h;
}

void fragment() {
	ALBEDO = mix(base_col * 0.7, tip_col, clamp(h * 2.2, 0.0, 1.0)) * COLOR.rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.22, 0.1);
}
