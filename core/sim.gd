# 軌道の計算(§9.3・INV-1・INV-2)。1 歩は step() だけが計算し、飛行・予測線・生成・テストが同じ関数を呼ぶ。
# 位置と速度は float の変数 4 つで持ち、四則と sqrt だけを §9.3 の順で使う。
extends RefCounted

const B := preload("res://core/balance.gd")


class State:
	extends RefCounted
	var x: float = B.PAD_X
	var y: float = B.PAD_Y
	var vx: float = 0.0
	var vy: float = 0.0
	var steps: int = 0
	var result: String = ""


# ホールの盤面を計算用の平らな配列にする。goal は [gx, gy]、planets は [px, py, r, px, py, r, ...]。
static func make_goal(goal: Array) -> PackedFloat64Array:
	return PackedFloat64Array([float(goal[0]), float(goal[1])])


static func make_planets(planets: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for p in planets:
		out.append(float(p[0]))
		out.append(float(p[1]))
		out.append(float(p[2]))
	return out


static func start(vx: float, vy: float) -> State:
	var s := State.new()
	s.vx = vx
	s.vy = vy
	return s


# 1 歩進める。結果が決まったら s.result に入れて返す(続くなら空文字)。
static func step(s: State, goal: PackedFloat64Array, planets: PackedFloat64Array, max_steps: int) -> String:
	var x := s.x
	var y := s.y
	var ax := 0.0
	var ay := 0.0
	var n := planets.size()
	var i := 0
	while i < n:
		var r := planets[i + 2]
		var dx := planets[i] - x
		var dy := planets[i + 1] - y
		var d2 := dx * dx + dy * dy
		var d := sqrt(d2)
		var a := B.SURFACE_G * r * r / d2
		ax = ax + a * dx / d
		ay = ay + a * dy / d
		i += 3
	var vx := s.vx + ax * B.DT
	var vy := s.vy + ay * B.DT
	x = x + vx * B.DT
	y = y + vy * B.DT
	s.x = x
	s.y = y
	s.vx = vx
	s.vy = vy
	s.steps = s.steps + 1
	i = 0
	while i < n:
		var r := planets[i + 2]
		var dx := planets[i] - x
		var dy := planets[i + 1] - y
		var hit := r + B.PROBE_R
		if dx * dx + dy * dy <= hit * hit:
			s.result = "crash"
			return s.result
		i += 3
	var gx := goal[0] - x
	var gy := goal[1] - y
	if gx * gx + gy * gy <= B.GOAL_R * B.GOAL_R:
		s.result = "goal"
		return s.result
	if x < -B.OUT_MARGIN or x > B.FIELD_W + B.OUT_MARGIN or y < -B.OUT_MARGIN or y > B.FIELD_H + B.OUT_MARGIN:
		s.result = "out"
		return s.result
	if s.steps == max_steps:
		s.result = "timeout"
		return s.result
	return ""


# 結果が決まるまで step を繰り返す。
static func simulate(goal: PackedFloat64Array, planets: PackedFloat64Array, vx: float, vy: float, max_steps: int) -> State:
	var s := start(vx, vy)
	while step(s, goal, planets, max_steps) == "":
		pass
	return s


# 画面の飛行で 1 フレームに進める歩数(§9.3 末尾・INV-3)。[歩数, 新しい bank] を返す。
static func frame_steps(bank: float, delta: float, mult: float) -> Array:
	bank = bank + minf(delta, B.MAX_FRAME_DELTA) * float(B.DT_DEN) * mult
	var whole := floorf(bank)
	var n := mini(int(whole), B.MAX_STEPS_PER_FRAME)
	return [n, bank - whole]
