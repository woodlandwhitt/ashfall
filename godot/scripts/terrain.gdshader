// Ground shader: the same recipe as the WebView build's terrain. Sand everywhere, worn dirt where the mask's green
// says so, rock on slopes and high ground, asphalt on roads (mask red), sick green near the glowing pools (mask blue).
shader_type spatial;
render_mode cull_back;

uniform sampler2D t_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_sand_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_rock_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_mask : filter_linear, repeat_disable;
uniform sampler2D t_tint : source_color, filter_linear, repeat_disable;
uniform vec4 region;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
}

void fragment() {
	vec2 uvw = wp.xz;
	vec2 mu = (uvw - region.xy) / region.zw;
	vec4 mk = texture(t_mask, mu);
	vec3 tint = texture(t_tint, mu).rgb * 1.275;
	if (dot(tint, vec3(1.0)) < 0.05) tint = vec3(1.0);
	float mac = vnoise(uvw * 0.035) * 0.6 + vnoise(uvw * 0.11) * 0.4;
	vec3 sA = texture(t_sand, uvw / 6.3).rgb;
	vec3 sB = texture(t_sand, uvw / 41.0).rgb;
	float mac2 = sB.g * 1.6 - 0.75;
	vec3 alb = sA * (0.37 + sB * 0.47) * tint;
	vec3 dC = texture(t_dirt, uvw / 5.1).rgb;
	float gW = smoothstep(0.25, 0.7, mk.g + (mac2 - 0.5) * 0.5);
	alb = mix(alb, dC * vec3(0.82, 0.7, 0.5) * (0.75 + mac * 0.5), gW * 0.85);
	vec3 n0 = normalize(wn);
	vec3 rC = texture(t_rock, uvw / 8.3).rgb;
	float rW = smoothstep(0.2, 0.55, (1.0 - n0.y) * 3.2 + (rC.g - 0.5) * 0.5 + smoothstep(20.0, 36.0, wp.y) * 0.6);
	alb = mix(alb, rC * vec3(0.64, 0.52, 0.42), rW);
	vec3 aC = texture(t_road, uvw / 5.7).rgb;
	float roW = smoothstep(0.42, 0.6, mk.r + (aC.g - 0.4) * 1.1 * (1.0 - mk.r) * step(0.02, mk.r));
	alb = mix(alb, aC * vec3(1.0, 0.97, 0.93), roW);
	alb *= 0.82 + mac * 0.36;
	alb = mix(alb, alb * vec3(0.7, 1.08, 0.5), mk.b * 0.7);
	ALBEDO = alb;
	vec3 nS = texture(t_sand_n, uvw / 6.3).rgb;
	vec3 nR = texture(t_rock_n, uvw / 8.3).rgb;
	NORMAL_MAP = mix(nS, nR, rW);
	NORMAL_MAP_DEPTH = mix(0.9, 1.4, rW) * (1.0 - roW * 0.6);
	ROUGHNESS = mix(0.95, 0.88, rW);
	METALLIC = 0.0;
}
