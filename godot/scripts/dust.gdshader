// Blowing dust (scripts/atmos.gd). Soft round puffs drawn entirely in the shader: no texture and no alpha
// tricks, so phones on the mobile renderer don't turn them into hard tan cut-outs (they did: build 17 bug report).
// Puffs fade out as they come near the camera instead of filling the screen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.72, 0.52, 0.16);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float soft = 1.0 - smoothstep(0.0, 1.0, d);
	float near = smoothstep(3.0, 9.0, -VERTEX.z);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * soft * soft * near * COLOR.a;
}
