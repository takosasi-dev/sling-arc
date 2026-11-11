# 盤面の描画(発射台・惑星・ゴール・探査機・軌道の残像・矢印・予測線・演出)。
# 状態は play.gd が渡す。ここは描くだけで、軌道は計算しない(位置は play.gd が core/sim.gd から受け取る)。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const PLANET_SHADER := "res://ui/shaders/planet.gdshader"
const GOAL_SHADER := "res://ui/shaders/goal.gdshader"
const PALETTES := [
	[Color(0.95, 0.62, 0.38), Color(0.42, 0.13, 0.20), Color(1.0, 0.62, 0.40, 0.9)],
	[Color(0.45, 0.70, 1.00), Color(0.10, 0.16, 0.45), Color(0.45, 0.75, 1.0, 0.9)],
	[Color(0.80, 0.55, 0.95), Color(0.24, 0.10, 0.40), Color(0.85, 0.55, 1.0, 0.9)],
	[Color(0.55, 0.90, 0.70), Color(0.08, 0.30, 0.30), Color(0.50, 1.0, 0.80, 0.9)],
	[Color(0.98, 0.85, 0.50), Color(0.45, 0.25, 0.10), Color(1.0, 0.85, 0.45, 0.9)],
]
const RESULT_COLORS := {
	"goal": Color(0.45, 1.0, 0.78), "crash": Color(1.0, 0.55, 0.42),
	"out": Color(0.55, 0.70, 1.0), "timeout": Color(0.75, 0.65, 1.0),
}

var pad := Vector2(B.PAD_X, B.PAD_Y)
var goal_pos := Vector2.ZERO
var planets: Array = []  # [Vector2 中心, 半径]

# 軌道の残像: [{"points": PackedVector2Array, "result": String}]
var trails: Array = []
var flight_points := PackedVector2Array()
var probe_pos := pad
var probe_visible := true

# 照準: active のときだけ描く
var aim_active := false
var aim_start := Vector2.ZERO
var aim_cur := Vector2.ZERO
var aim_dir := Vector2.ZERO  # 単位ベクトル(撃つ向き)
var aim_power := 0.0
var preview := PackedVector2Array()
var last_dir := Vector2.ZERO
var last_power := 0.0

var hint_active := false
var _t := 0.0
var _particles: Array = []
var _rings: Array = []  # [{"pos", "age", "color"}]
var _nodes: Array = []
var _goal_rect: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(B.FIELD_W, B.FIELD_H)


func set_hole(hole: Dictionary) -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	trails.clear()
	flight_points.clear()
	_particles.clear()
	_rings.clear()
	last_dir = Vector2.ZERO
	aim_active = false
	probe_pos = pad
	probe_visible = true
	goal_pos = Vector2(hole["goal"][0], hole["goal"][1])
	planets.clear()
	for p in hole["planets"]:
		planets.append([Vector2(p[0], p[1]), float(p[2])])

	var half := B.GOAL_R * 2.2
	_goal_rect = Kit.shader_rect(GOAL_SHADER, Rect2(goal_pos - Vector2(half, half), Vector2(half, half) * 2.0))
	_goal_rect.material.set_shader_parameter("ring_frac", B.GOAL_R / half)
	add_child(_goal_rect)
	_nodes.append(_goal_rect)
	for i in planets.size():
		var c: Vector2 = planets[i][0]
		var r: float = planets[i][1]
		var h := r * 1.7
		var pr := Kit.shader_rect(PLANET_SHADER, Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0))
		var pal: Array = PALETTES[(int(c.x) * 7 + int(c.y) * 13 + int(r)) % PALETTES.size()]
		var m: ShaderMaterial = pr.material
		m.set_shader_parameter("base_color", pal[0])
		m.set_shader_parameter("shade_color", pal[1])
		m.set_shader_parameter("glow_color", pal[2])
		m.set_shader_parameter("radius_frac", r / h)
		m.set_shader_parameter("seed", float(int(c.x + c.y) % 97))
		m.set_shader_parameter("band_freq", 4.0 + float(int(r) % 5))
		add_child(pr)
		_nodes.append(pr)
		# 出てくるときに少し膨らむ
		pr.pivot_offset = pr.size / 2.0
		pr.scale = Vector2(0.6, 0.6)
		pr.modulate.a = 0.0
		var tw := pr.create_tween().set_parallel(true)
		tw.tween_property(pr, "scale", Vector2.ONE, 0.5).set_delay(0.08 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pr, "modulate:a", 1.0, 0.35).set_delay(0.08 * i)


func add_trail(points: PackedVector2Array, result: String) -> void:
	trails.append({"points": points, "result": result})


func burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + fmod(float(i) * 2.399, 1.0)
		var s := speed * (0.4 + 0.6 * fmod(float(i) * 0.618, 1.0))
		_particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * s, "life": 0.0, "max": 0.5 + 0.4 * fmod(float(i) * 0.37, 1.0), "color": color})
	_rings.append({"pos": pos, "age": 0.0, "color": color})


func goal_flash() -> void:
	burst(goal_pos, Kit.C_GOAL, 28, 260.0)
	if _goal_rect:
		var tw := create_tween()
		tw.tween_method(func(v): _goal_rect.material.set_shader_parameter("burst", v), 0.0, 1.0, 0.7)
		tw.tween_callback(func(): _goal_rect.material.set_shader_parameter("burst", 0.0))


func _process(delta: float) -> void:
	_t += delta
	for p in _particles:
		p["life"] += delta
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.94
	_particles = _particles.filter(func(p): return p["life"] < p["max"])
	for r in _rings:
		r["age"] += delta
	_rings = _rings.filter(func(r): return r["age"] < 0.6)
	queue_redraw()


func _draw() -> void:
	_draw_gravity_rings()
	_draw_pad()
	_draw_trails()
	if last_dir != Vector2.ZERO and not aim_active:
		_draw_arrow(last_dir, last_power, Color(1, 1, 1, 0.22), 4.0)
	if aim_active:
		_draw_aim()
	if hint_active:
		_draw_hint()
	if flight_points.size() >= 2:
		_draw_fading_line(flight_points, Kit.C_ACCENT, 5.0)
	if probe_visible:
		_draw_probe(probe_pos)
	for p in _particles:
		var k: float = 1.0 - p["life"] / p["max"]
		var c: Color = p["color"]
		draw_circle(p["pos"], 2.0 + 4.0 * k, Color(c, 0.25 * k))
		draw_circle(p["pos"], 1.0 + 2.0 * k, Color(c.lightened(0.4), 0.9 * k))
	for r in _rings:
		var k: float = r["age"] / 0.6
		draw_arc(r["pos"], 12.0 + 90.0 * k, 0, TAU, 48, Color(r["color"], 0.6 * (1.0 - k)), 3.0, true)


# 惑星の引く強さの目安。同じ強さの距離は半径に比例するので、半径の倍数で輪を描く。
func _draw_gravity_rings() -> void:
	for p in planets:
		var c: Vector2 = p[0]
		var r: float = p[1]
		for k: float in [1.7, 2.5, 3.6]:
			var rr: float = r * k
			var a := 0.13 / k
			var spin := _t * 0.08 / k
			var segs := 36
			for s in segs:
				if s % 2 == 0:
					var a0 := spin + TAU * float(s) / float(segs)
					draw_arc(c, rr, a0, a0 + TAU / float(segs), 4, Color(0.75, 0.85, 1.0, a), 1.5, true)


func _draw_pad() -> void:
	var glow := 0.5 + 0.2 * sin(_t * 2.4)
	draw_circle(pad + Vector2(0, 18), 64.0, Color(0.3, 0.7, 1.0, 0.05))
	draw_arc(pad, 30.0, 0, TAU, 48, Color(Kit.C_ACCENT, 0.35 * glow + 0.15), 2.0, true)
	draw_arc(pad, 44.0, PI * 0.15, PI * 0.85, 24, Color(Kit.C_ACCENT, 0.5), 4.0, true)
	for i in 3:
		var y := pad.y + 62.0 + i * 14.0
		draw_line(Vector2(pad.x - 30 + i * 6, y), Vector2(pad.x + 30 - i * 6, y), Color(Kit.C_ACCENT, 0.25 - i * 0.07), 3.0, true)


func _draw_trails() -> void:
	var n := trails.size()
	for i in n:
		var tr: Dictionary = trails[i]
		var age := n - 1 - i
		var a := maxf(0.10, 0.75 * pow(0.62, age))
		var col: Color = RESULT_COLORS.get(tr["result"], Kit.C_ACCENT)
		var pts: PackedVector2Array = tr["points"]
		if pts.size() < 2:
			continue
		draw_polyline(pts, Color(col, a * 0.25), 7.0, true)
		draw_polyline(pts, Color(col, a), 2.0, true)
		var end := pts[pts.size() - 1]
		if tr["result"] == "crash":
			var s := 7.0
			draw_line(end + Vector2(-s, -s), end + Vector2(s, s), Color(col, a), 3.0, true)
			draw_line(end + Vector2(-s, s), end + Vector2(s, -s), Color(col, a), 3.0, true)


func _draw_fading_line(pts: PackedVector2Array, col: Color, width: float) -> void:
	var colors := PackedColorArray()
	var n := pts.size()
	for i in n:
		var k := float(i) / float(n - 1)
		colors.append(Color(col, 0.15 + 0.85 * k))
	draw_polyline_colors(pts, colors, width, true)


func _draw_arrow(dir: Vector2, power: float, col: Color, width: float) -> void:
	var reach := 50.0 + power * 170.0
	var tip := pad + dir * reach
	draw_line(pad + dir * 36.0, tip, col, width, true)
	var side := dir.orthogonal() * 14.0
	draw_colored_polygon(PackedVector2Array([tip + dir * 18.0, tip + side, tip - side]), col)


func _draw_aim() -> void:
	# 引いている指から押し始めまでの線
	draw_dashed_line(aim_start, aim_cur, Color(1, 1, 1, 0.35), 2.0, 10.0, true, true)
	draw_arc(aim_start, 16.0, 0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	draw_circle(aim_cur, 10.0, Color(1, 1, 1, 0.55))
	if aim_dir == Vector2.ZERO:
		return
	var col := Kit.C_GOLD.lerp(Kit.C_WARN, aim_power)
	_draw_arrow(aim_dir, aim_power, Color(col, 0.25), 16.0)
	_draw_arrow(aim_dir, aim_power, col, 6.0)
	# 予測線: 点を間引いて、先ほど薄く
	var n := preview.size()
	for i in range(0, n, 3):
		var k := 1.0 - float(i) / float(maxi(n, 1))
		draw_circle(preview[i], 2.0 + 2.5 * k, Color(1, 1, 1, 0.75 * k))
	# 強さの目盛り
	var pct := "%d%%" % int(round(aim_power * 100.0))
	draw_string(Kit.font(700), pad + Vector2(-60, 130), pct, HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(col, 0.9))


func _draw_probe(p: Vector2) -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 9.0)
	draw_circle(p, 22.0, Color(0.4, 0.85, 1.0, 0.08 * pulse))
	draw_circle(p, 14.0, Color(0.4, 0.85, 1.0, 0.18 * pulse))
	draw_circle(p, B.PROBE_R, Color(0.75, 0.95, 1.0))
	draw_circle(p, 4.0, Color.WHITE)


# FR-20: 引っ張る動きを示す薄い指と矢印。
func _draw_hint() -> void:
	var cyc := fmod(_t, 2.6) / 2.6
	var pull := clampf(cyc / 0.6, 0.0, 1.0)
	var start := pad + Vector2(0, -150)
	var fade := 1.0 - clampf((cyc - 0.75) / 0.25, 0.0, 1.0)
	var finger := start + Vector2(0, 220) * _ease(pull)
	draw_dashed_line(start, finger, Color(1, 1, 1, 0.35 * fade), 2.0, 10.0, true, true)
	draw_circle(finger, 22.0, Color(1, 1, 1, 0.18 * fade))
	draw_arc(finger, 22.0, 0, TAU, 32, Color(1, 1, 1, 0.6 * fade), 2.5, true)
	if pull > 0.1:
		_draw_arrow(Vector2.UP, pull, Color(Kit.C_GOLD, 0.65 * fade), 6.0)


static func _ease(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)
