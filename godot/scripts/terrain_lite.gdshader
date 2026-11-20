// Cheap ground for the Low preset: two texture reads (sand, rock), road and dirt from the mask, no normal maps.
shader_type spatial;
render_mode cull_back;

uniform sampler2D t_sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_mask : filter_linear, repeat_disable;
uniform vec4 region;

varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
}
void fragment() {
	vec2 mu = (wp.xz - region.xy) / region.zw;
	vec4 mk = texture(t_mask, mu);
	vec3 s = texture(t_sand, wp.xz / 6.3).rgb * 0.75;
	vec3 r = texture(t_rock, wp.xz / 8.3).rgb * vec3(0.64, 0.52, 0.42);
	float rw = smoothstep(0.2, 0.55, (1.0 - normalize(wn).y) * 3.2);
	vec3 alb = mix(s, r, rw);
	alb = mix(alb, s * vec3(0.7, 0.6, 0.45), smoothstep(0.3, 0.7, mk.g) * 0.8);
	alb = mix(alb, vec3(0.2, 0.19, 0.18), smoothstep(0.42, 0.6, mk.r));
	alb = mix(alb, alb * vec3(0.7, 1.08, 0.5), mk.b * 0.7);
	ALBEDO = alb;
	ROUGHNESS = 0.95;
}
