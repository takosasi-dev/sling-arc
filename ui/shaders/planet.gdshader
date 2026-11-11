// 惑星 1 個の見た目。矩形の中心に半径 radius_frac(矩形の半分を 1 とした割合)の球を描き、外側に大気の光を出す。
// 見た目だけで、軌道の計算には関わらない。
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.9, 0.55, 0.35, 1.0);
uniform vec4 shade_color : source_color = vec4(0.35, 0.12, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.4, 0.8);
uniform float radius_frac = 0.6;
uniform float seed = 0.0;
uniform float band_freq = 5.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p) / radius_frac;
	vec4 outc = vec4(glow_color.rgb, 0.0);
	if (d > 1.0) {
		float g = smoothstep(1.0 / radius_frac, 1.0, d);
		outc.a = glow_color.a * g * g * 0.55;
	} else {
		vec2 q = p / radius_frac;
		float z = sqrt(max(0.0, 1.0 - dot(q, q)));
		vec3 n = vec3(q, z);
		vec3 l = normalize(vec3(-0.55, -0.6, 0.6));
		float diff = clamp(dot(n, l), 0.0, 1.0);
		float swirl = sin(q.x * 3.1 + seed * 1.7 + TIME * 0.15) * 0.35;
		float band = sin((q.y + swirl) * band_freq + seed) * 0.5 + 0.5;
		vec3 col = mix(shade_color.rgb, base_color.rgb, band * 0.55 + 0.45);
		col *= 0.18 + 0.95 * diff;
		float rim = pow(1.0 - z, 2.5);
		col += glow_color.rgb * rim * 0.85;
		float spec = pow(clamp(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 24.0);
		col += vec3(spec * 0.25);
		float aa = smoothstep(1.0, 0.96, d);
		outc = mix(vec4(glow_color.rgb, glow_color.a * 0.55), vec4(col, 1.0), aa);
	}
	COLOR = outc;
}
