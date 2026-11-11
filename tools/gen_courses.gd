# コース生成ツール(§9.5)。開発機で godot --headless --script res://tools/gen_courses.gd を動かし、出力をコミットする。
# 引数: -- [--count N] [--out パス]。sin・cos を使うので、別の OS では違うファイルになることがある(コミットした物を正とする)。
extends SceneTree

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Sim := preload("res://core/sim.gd")

const MAX_CANDIDATES := 200
const MAX_PLACE_TRIES := 60
const ANGLE_MIN := 20
const ANGLE_MAX := 160
const POWERS := 8  # 0.3〜1.0 を 0.1 刻み

var rng: Rng
var discarded := 0


func _initialize() -> void:
	var count := B.N_COURSES
	var out_path := "res://data/courses.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--count":
			count = int(args[i + 1])
		elif args[i] == "--out":
			out_path = args[i + 1]
	rng = Rng.new(Rng.fnv1a(B.GEN + ":courses"))
	var t_all := Time.get_ticks_msec()
	var courses: Array = []
	for c in count:
		var t0 := Time.get_ticks_msec()
		var d0 := discarded
		var holes: Array = []
		for h in B.HOLES_PER_COURSE:
			var hole := _make_hole(h)
			if hole.is_empty():
				printerr("コース %d ホール %d: 候補が %d 個を超えた" % [c, h, MAX_CANDIDATES])
				quit(1)
				return
			holes.append(hole)
		courses.append(holes)
		print("course %d: %d ms, discarded %d" % [c, Time.get_ticks_msec() - t0, discarded - d0])
	var text := _to_json(courses)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("書けない: " + out_path)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("done: %d courses, %d ms, discarded %d, %d bytes -> %s" % [count, Time.get_ticks_msec() - t_all, discarded, text.to_utf8_buffer().size(), out_path])
	quit(0)


func _make_hole(h: int) -> Dictionary:
	for cand in MAX_CANDIDATES:
		var hole := _candidate(B.PLANETS_PER_HOLE[h])
		if not hole.is_empty():
			var sol := _check(hole, h)
			if not sol.is_empty():
				hole["solution"] = sol
				return hole
		discarded += 1
	return {}


# 2. 候補を 1 つ作る。置けなかったら空。
func _candidate(n_planets: int) -> Dictionary:
	var gx := 140 + rng.next_int(441)
	var gy := 150 + rng.next_int(181)
	var planets: Array = []
	for k in n_planets:
		var placed := false
		for t in MAX_PLACE_TRIES:
			var r := 36 + rng.next_int(45)
			var px := (r + 20) + rng.next_int(720 - 2 * (r + 20) + 1)
			var py := 380 + rng.next_int(571)
			if _too_close(px, py, int(B.PAD_X), int(B.PAD_Y), r + 140):
				continue
			if _too_close(px, py, gx, gy, r + int(B.GOAL_R) + 60):
				continue
			var ok := true
			for p in planets:
				if _too_close(px, py, p[0], p[1], r + p[2] + 50):
					ok = false
					break
			if ok:
				planets.append([px, py, r])
				placed = true
				break
		if not placed:
			return {}
	return {"goal": [gx, gy], "planets": planets}


static func _too_close(ax: int, ay: int, bx: int, by: int, dist: int) -> bool:
	var dx := ax - bx
	var dy := ay - by
	return dx * dx + dy * dy < dist * dist


static func _velocity(angle_deg: int, power_i: int) -> Array:
	var p := float(power_i + 3) / 10.0
	var rad := deg_to_rad(float(angle_deg))
	return [p * B.V_MAX * cos(rad), -p * B.V_MAX * sin(rad)]


# 3〜4. 試し撃ちと採否。採るなら整数の solution、捨てるなら空。
func _check(hole: Dictionary, h: int) -> Array:
	var goal := Sim.make_goal(hole["goal"])
	var planets := Sim.make_planets(hole["planets"])
	var n_angles := ANGLE_MAX - ANGLE_MIN + 1
	var hit := {}  # [power_i * n_angles + angle_i] -> true
	var done := {}
	# (b) を先に見る(結果は同じで、早く捨てられる)
	if h >= 1:
		var direct := rad_to_deg(atan2(B.PAD_Y - float(hole["goal"][1]), float(hole["goal"][0]) - B.PAD_X))
		for a in range(ANGLE_MIN, ANGLE_MAX + 1):
			if absf(float(a) - direct) > 3.0:
				continue
			for pi in POWERS:
				var v := _velocity(a, pi)
				var key: int = pi * n_angles + (a - ANGLE_MIN)
				done[key] = true
				if Sim.simulate(goal, planets, v[0], v[1], B.MAX_STEPS).result == "goal":
					return []
	for pi in POWERS:
		for a in range(ANGLE_MIN, ANGLE_MAX + 1):
			var key: int = pi * n_angles + (a - ANGLE_MIN)
			if done.has(key):
				continue
			var v := _velocity(a, pi)
			if Sim.simulate(goal, planets, v[0], v[1], B.MAX_STEPS).result == "goal":
				hit[key] = true
	# (a)(c) 一番長い並び。同じ長さなら強さが小さい方、それも同じなら角度が小さい方
	var best_len := 0
	var best_pi := -1
	var best_start := -1
	for pi in POWERS:
		var run := 0
		for ai in n_angles + 1:
			if ai < n_angles and hit.has(pi * n_angles + ai):
				run += 1
				continue
			if run > best_len:
				best_len = run
				best_pi = pi
				best_start = ai - run
			run = 0
	if best_len < 3:
		return []
	var mid := ANGLE_MIN + best_start + best_len / 2
	var v := _velocity(mid, best_pi)
	var ivx := int(roundf(v[0]))
	var ivy := int(roundf(v[1]))
	for ox in [-5, 0, 5]:
		for oy in [-5, 0, 5]:
			if Sim.simulate(goal, planets, float(ivx + ox), float(ivy + oy), B.MAX_STEPS).result != "goal":
				return []
	return [ivx, ivy]


static func _ints(a: Array) -> String:
	var parts := PackedStringArray()
	for e in a:
		parts.append(str(int(e)))
	return "[" + ", ".join(parts) + "]"


# キーの順と空白を固定して書く(同じ入力なら同じバイト列)。
static func _to_json(courses: Array) -> String:
	var p := B.physics_dict()
	var lines := PackedStringArray()
	lines.append("{")
	lines.append('  "version": 1,')
	lines.append('  "gen": "%s",' % B.GEN)
	lines.append('  "physics": { "surface_g": %d, "v_max": %d, "probe_r": %d, "goal_r": %d, "out_margin": %d, "max_steps": %d, "dt_den": %d },' % [p["surface_g"], p["v_max"], p["probe_r"], p["goal_r"], p["out_margin"], p["max_steps"], p["dt_den"]])
	lines.append('  "courses": [')
	for c in courses.size():
		lines.append('    { "id": %d, "holes": [' % c)
		var holes: Array = courses[c]
		for h in holes.size():
			var hole: Dictionary = holes[h]
			var ps := PackedStringArray()
			for pl in hole["planets"]:
				ps.append(_ints(pl))
			var tail := "," if h < holes.size() - 1 else ""
			lines.append('      { "goal": %s, "planets": [%s], "solution": %s }%s' % [_ints(hole["goal"]), ", ".join(ps), _ints(hole["solution"]), tail])
		lines.append("    ] }" + ("," if c < courses.size() - 1 else ""))
	lines.append("  ]")
	lines.append("}")
	return "\n".join(lines) + "\n"
