// 背景の宇宙。星の位置は seed(コース番号)で決まり動かない(FR-21)。瞬きと星雲の明暗だけが時間で揺れる。
shader_type canvas_item;

uniform float seed = 0.0;
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec4 top_color : source_color = vec4(0.012, 0.02, 0.06, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.05, 0.025, 0.11, 1.0);
uniform vec4 nebula_a : source_color = vec4(0.42, 0.16, 0.62, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.06, 0.42, 0.62, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + vec2(seed * 0.1234, seed * 0.0731));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	float drift = TIME * 0.006;
	float n1 = fbm(px / 300.0 + vec2(seed * 0.37, drift));
	float n2 = fbm(px / 170.0 - vec2(seed * 0.21, drift * 1.3));
	col += nebula_a.rgb * smoothstep(0.48, 0.92, n1) * 0.30;
	col += nebula_b.rgb * smoothstep(0.52, 0.96, n2) * 0.22;
	for (int layer = 0; layer < 3; layer++) {
		float cell = 24.0 + float(layer) * 26.0;
		vec2 g = floor(px / cell) + float(layer) * 31.0;
		vec2 f = fract(px / cell);
		float h = hash(g);
		if (h > 0.80) {
			vec2 pos = vec2(hash(g + 3.1), hash(g + 7.7)) * 0.8 + 0.1;
			float d = length(f - pos) * cell;
			float br = (h - 0.80) / 0.20;
			float tw = 0.7 + 0.3 * sin(TIME * (0.8 + h * 2.5) + h * 40.0);
			vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(g + 1.3));
			col += tint * br * tw * (smoothstep(1.4 + float(layer) * 0.4, 0.0, d) + 0.18 * smoothstep(6.0, 0.0, d));
		}
	}
	COLOR = vec4(col, 1.0);
}
