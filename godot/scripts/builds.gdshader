// Surfaces of the frontier buildings (scripts/frontier.gd), all from world position so boxes need no UVs:
//   mode 0  weathered boards, laid flat (walls)      mode 1  boards standing up (fences, doors)
//   mode 2  corrugated sheet metal, rust creeping in  mode 3  canvas and hide
//   mode 4  bark (palisade logs, posts)               mode 5  cast concrete, stained and cracked
shader_type spatial;
render_mode cull_back;

uniform int mode = 0;
uniform vec3 base : source_color = vec3(0.52, 0.4, 0.28);
uniform vec3 alt : source_color = vec3(0.38, 0.29, 0.2);
uniform float rust = 0.5;
uniform bool two_sided = false;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.3) * 0.3 + vn(p * 5.1) * 0.15; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wn);
	vec2 uv;
	vec3 ax;      // the world direction uv.x runs along
	if (an.y > 0.6) { uv = wp.xz; ax = vec3(1, 0, 0); }
	else if (an.x > an.z) { uv = vec2(wp.z, wp.y); ax = vec3(0, 0, 1); }
	else { uv = vec2(wp.x, wp.y); ax = vec3(1, 0, 0); }
	vec3 col = base;
	float rough = 0.88;
	float metal = 0.0;
	vec3 nw = wn;
	if (mode == 0 || mode == 1) {
		vec2 p = mode == 0 ? uv : uv.yx;
		float w = 0.21;
		float row = floor(p.y / w);
		float f = fract(p.y / w);
		float off = hash(vec2(row, 3.1)) * 9.0;
		float seg = floor((p.x + off) / 2.6);
		float id = hash(vec2(row, seg));
		col = mix(base, alt, id) * (0.85 + hash(vec2(seg, row * 1.3)) * 0.25);
		float grain = vn(vec2((p.x + off) * 1.2, p.y * 34.0 + id * 9.0));
		col *= 0.78 + grain * 0.4;
		float gap = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
		float jx = fract((p.x + off) / 2.6);
		float joint = smoothstep(0.0, 0.008, jx) * smoothstep(1.0, 0.992, jx);
		col *= mix(0.3, 1.0, gap * joint);
		// nail heads at the board ends
		vec2 nl = vec2(jx * 2.6, f * w);
		float nail = 1.0 - smoothstep(0.012, 0.02, length(nl - vec2(0.07, w * 0.5)));
		col = mix(col, vec3(0.16, 0.12, 0.1), nail * 0.8);
		// sun-bleached grey in blotches
		float bl = fbm(uv * 0.45);
		col = mix(col, vec3(dot(col, vec3(0.3, 0.4, 0.3))) * 1.15, smoothstep(0.35, 0.8, bl) * 0.55);
		nw = normalize(wn + (mode == 0 ? vec3(0, 1, 0) : ax) * (1.0 - gap) * 0.35);
	} else if (mode == 2) {
		float k = uv.x * 6.2831 / 0.13;
		float r = fbm(uv * 0.7 + 3.0);
		float streak = vn(vec2(uv.x * 3.0, uv.y * 0.3));
		float rw = smoothstep(0.62 - rust * 0.35, 0.85 - rust * 0.3, r * 0.75 + streak * 0.35);
		col = base * (0.85 + sin(k) * 0.08);
		col = mix(col, mix(vec3(0.42, 0.2, 0.09), vec3(0.6, 0.32, 0.12), vn(uv * 9.0)), rw);
		metal = mix(0.55, 0.0, rw);
		rough = mix(0.45, 0.95, rw);
		// panel overlaps every 0.9 m
		float pj = fract(uv.x / 0.9);
		col *= mix(0.55, 1.0, smoothstep(0.0, 0.02, pj));
		nw = normalize(wn + ax * cos(k) * 0.45);
	} else if (mode == 3) {
		float n = fbm(uv * 2.5);
		col = base * (0.82 + n * 0.3);
		float stain = smoothstep(0.55, 0.8, fbm(uv * 0.5 + 7.0));
		col = mix(col, alt, stain * 0.6);
		float weave = sin(uv.x * 400.0) * sin(uv.y * 400.0) * 0.03;
		col += weave;
		rough = 0.95;
	} else if (mode == 4) {
		vec2 p = uv;
		float strip = vn(vec2(p.x * 9.0, p.y * 0.6));
		col = mix(alt, base, strip) * (0.8 + vn(p * vec2(3.0, 12.0)) * 0.3);
		rough = 0.95;
		nw = normalize(wn + ax * (strip - 0.5) * 0.5);
	} else if (mode == 5) {
		float n = fbm(uv * 1.3);
		col = base * (0.78 + n * 0.35);
		float stain = smoothstep(0.5, 0.85, fbm(vec2(uv.x * 1.5, uv.y * 0.25) + 11.0));
		col = mix(col, col * vec3(0.55, 0.5, 0.45), stain);
		float crack = smoothstep(0.02, 0.0, abs(vn(uv * 1.7) - 0.5)) * step(0.55, vn(uv * 0.3));
		col *= 1.0 - crack * 0.6;
		rough = 0.95;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	vec3 vn_ = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	NORMAL = (two_sided && !FRONT_FACING) ? -vn_ : vn_;
}
