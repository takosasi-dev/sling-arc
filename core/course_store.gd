# data/courses.json を読み込み、形と物理の値を検査する(§9.5・INV-10・E-12)。
# 壊れていてもエラーを返すだけで、例外で落ちない。
extends RefCounted

const B := preload("res://core/balance.gd")
const PATH := "res://data/courses.json"


# 戻り値: {"ok": bool, "error": String, "courses": Array}
static func load_file(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("ファイルが無い: " + path)
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> Dictionary:
	var j := JSON.new()
	var data = j.data if j.parse(text) == OK else null
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("JSON として読めない")
	if data.get("version") != 1.0 or data.get("gen") != B.GEN:
		return _fail("version か gen が違う")
	var phys = data.get("physics")
	if typeof(phys) != TYPE_DICTIONARY:
		return _fail("physics が無い")
	var want := B.physics_dict()
	for k in want:
		if not phys.has(k) or not _is_int(phys[k]) or int(phys[k]) != want[k]:
			return _fail("physics が balance.gd と違う: " + k)
	var courses = data.get("courses")
	if typeof(courses) != TYPE_ARRAY or courses.size() != B.N_COURSES:
		return _fail("コースの本数が違う")
	var out: Array = []
	for ci in courses.size():
		var c = courses[ci]
		if typeof(c) != TYPE_DICTIONARY or not _is_int(c.get("id")) or int(c["id"]) != ci:
			return _fail("コース %d の id が違う" % ci)
		var holes = c.get("holes")
		if typeof(holes) != TYPE_ARRAY or holes.size() != B.HOLES_PER_COURSE:
			return _fail("コース %d のホール数が違う" % ci)
		var hs: Array = []
		for hi in holes.size():
			var h = _hole(holes[hi], B.PLANETS_PER_HOLE[hi])
			if h.is_empty():
				return _fail("コース %d ホール %d が壊れている" % [ci, hi])
			hs.append(h)
		out.append({"id": ci, "holes": hs})
	return {"ok": true, "error": "", "courses": out}


static func _hole(h, n_planets: int) -> Dictionary:
	if typeof(h) != TYPE_DICTIONARY:
		return {}
	var goal = _ints(h.get("goal"), 2)
	var sol = _ints(h.get("solution"), 2)
	var ps = h.get("planets")
	if goal.is_empty() or sol.is_empty() or typeof(ps) != TYPE_ARRAY or ps.size() != n_planets:
		return {}
	var planets: Array = []
	for p in ps:
		var pi = _ints(p, 3)
		if pi.is_empty():
			return {}
		planets.append(pi)
	return {"goal": goal, "planets": planets, "solution": sol}


static func _ints(v, n: int) -> Array:
	if typeof(v) != TYPE_ARRAY or v.size() != n:
		return []
	var out: Array = []
	for e in v:
		if not _is_int(e):
			return []
		out.append(int(e))
	return out


static func _is_int(v) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) == floorf(float(v))


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "courses": []}
