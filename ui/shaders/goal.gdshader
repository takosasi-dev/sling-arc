// ゴールの見た目。半径 ring_frac(矩形の半分を 1 とした割合)の輪が脈打ち、外へ波が広がる。
// 見た目だけで、当たりの判定は core/sim.gd が行う。
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.45, 1.0, 0.78, 1.0);
uniform float ring_frac = 0.5;
uniform float burst = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p) / ring_frac;
	float t = TIME;
	float ring = smoothstep(0.09, 0.0, abs(d - 1.0));
	float inner = smoothstep(1.0, 0.0, d) * (0.16 + 0.06 * sin(t * 3.0));
	float pulse = fract(t * 0.55);
	float wave = smoothstep(0.07, 0.0, abs(d - (1.0 + pulse * 0.9))) * (1.0 - pulse);
	float ang = atan(p.y, p.x);
	float dash = step(0.45, fract(ang / 6.2831853 * 14.0 + t * 0.25));
	float ring2 = smoothstep(0.05, 0.0, abs(d - 0.72)) * dash * 0.55;
	float glow = smoothstep(1.9, 1.0, d) * 0.22;
	float b = smoothstep(0.12, 0.0, abs(d - (1.0 + burst * 0.9))) * burst * 2.0;
	float a = clamp(ring + inner + wave * 0.65 + ring2 + glow + b, 0.0, 1.0);
	COLOR = vec4(color.rgb + vec3(b * 0.4), a * color.a);
}
