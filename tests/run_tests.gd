# 自前のテストランナー(D-13)。godot --headless --script res://tests/run_tests.gd で動かす。
# test_ で始まる関数を順に呼び、空文字なら成功、それ以外は失敗の理由。1 件でも失敗なら終了コード 1。
extends SceneTree

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Sim := preload("res://core/sim.gd")
const Aim := preload("res://core/aim.gd")
const DayIndex := preload("res://core/day_index.gd")
const RoundState := preload("res://core/round_state.gd")
const ShareText := preload("res://core/share_text.gd")
const SaveStore := preload("res://save/save_store.gd")
const CourseStore := preload("res://core/course_store.gd")

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const STRINGS_PATH := "res://core/strings.gd"

# §9.3 の固定値: [名前, goal, planets, vx, vy, max_steps, 結果, 歩数, x, y]
const SIM_FIXTURES := [
	["V1", [360, 240], [], 0, -450, 1440, "goal", 229, 360.000000, 271.250000],
	["V2", [300, 240], [[420, 700, 60]], 0, -720, 1440, "crash", 59, 371.667980, 738.974654],
	["V3", [360, 240], [[360, 700, 60]], 300, -300, 1440, "out", 402, 657.873683, -202.344354],
	["V4", [300, 240], [[330, 700, 60]], -290, -850, 1440, "goal", 110, 288.219403, 267.805211],
	["V5", [360, 240], [], 0, -450, 100, "timeout", 100, 360.000000, 755.000000],
	["V6", [360, 260], [[360, 700, 60]], 220, -600, 1440, "goal", 146, 357.489295, 293.817955],
]


func _initialize() -> void:
	var failed := 0
	var total := 0
	for m in get_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		total += 1
		var t0 := Time.get_ticks_msec()
		var err: String = call(name)
		var ms := Time.get_ticks_msec() - t0
		if err == "":
			print("PASS %s (%d ms)" % [name, ms])
		else:
			failed += 1
			printerr("FAIL ", name, ": ", err)
	print("%d passed, %d failed" % [total - failed, failed])
	quit(1 if failed > 0 or total == 0 else 0)


# AC-16: strings.gd の全文字と ASCII の印字可能文字を、同梱フォントが持つ。
func test_font_covers_strings_and_ascii() -> String:
	var font: Font = load(FONT_PATH)
	if font == null:
		return "フォントを読めない: " + FONT_PATH
	var codes := {}
	for c in range(0x20, 0x7F):
		codes[c] = true
	var consts: Dictionary = load(STRINGS_PATH).get_script_constant_map()
	for v in consts.values():
		if v is String:
			for i in v.length():
				codes[v.unicode_at(i)] = true
	var missing := PackedStringArray()
	for c in codes:
		if not font.has_char(c):
			missing.append("U+%04X" % c)
	return "" if missing.is_empty() else "フォントに無い文字: " + ", ".join(missing)


# AC-5: §9.2 の固定値。
func test_rng_fixed_values() -> String:
	var want := {"a": 3826002220, "abc": 440920331, "SA1:courses": 2755766696}
	for k in want:
		if Rng.fnv1a(k) != want[k]:
			return "FNV-1a(%s) = %d" % [k, Rng.fnv1a(k)]
	var r := Rng.new(1)
	var got := []
	for i in 5:
		got.append(r.next())
	if got != [270369, 67634689, 2647435461, 307599695, 2398689233]:
		return "xorshift32 種 1: " + str(got)
	if Rng.new(0).state != 1:
		return "種 0 が 1 にならない"
	return ""


# AC-6: §9.3 の固定値 6 行。結果と歩数は完全一致、位置は 0.000001 以内。
func test_sim_fixed_values() -> String:
	for f in SIM_FIXTURES:
		var s := Sim.simulate(Sim.make_goal(f[1]), Sim.make_planets(f[2]), float(f[3]), float(f[4]), f[5])
		if s.result != f[6] or s.steps != f[7] or absf(s.x - f[8]) > 0.000001 or absf(s.y - f[9]) > 0.000001:
			return "%s: %s %d (%.6f, %.6f)" % [f[0], s.result, s.steps, s.x, s.y]
	return ""


# AC-7: simulate と step の手での繰り返しがビットまで同じ(V4)。
func test_simulate_equals_manual_steps() -> String:
	var f: Array = SIM_FIXTURES[3]
	var goal := Sim.make_goal(f[1])
	var planets := Sim.make_planets(f[2])
	var a := Sim.simulate(goal, planets, float(f[3]), float(f[4]), f[5])
	var b := Sim.start(float(f[3]), float(f[4]))
	for i in a.steps:
		Sim.step(b, goal, planets, f[5])
	if a.x != b.x or a.y != b.y or a.vx != b.vx or a.vy != b.vy or a.result != b.result:
		return "simulate と step が食い違う"
	return ""


# AC-8: §9.4 の固定値 5 つ。
func test_aim_fixed_values() -> String:
	var cases := [[400, 1050, [0, -450]], [400, 1500, [0, -900]], [400, 930, [0, -135]], [400, 920, []], [700, 900, [-900, 0]]]
	for c in cases:
		var v := Aim.pull_to_velocity(400, 900, c[0], c[1])
		if c[2].is_empty():
			if not v.is_empty():
				return "C=(%d,%d) が取り消しにならない" % [c[0], c[1]]
			continue
		if v.is_empty() or absf(v[0] - c[2][0]) > 1e-9 or absf(v[1] - c[2][1]) > 1e-9:
			return "C=(%d,%d): %s" % [c[0], c[1], str(v)]
	if not Aim.pull_to_velocity(400, 900, 400, 900).is_empty():
		return "長さ 0 が取り消しにならない(E-5)"
	return ""


# AC-9: §9.6 の固定値と、ランダムの選択が今日を返さないこと。
func test_day_index_and_random_pick() -> String:
	var cases := [[2026, 1, 1, 0, 0], [2026, 11, 10, 313, 13], [2027, 1, 1, 365, 65], [2025, 12, 31, -1, 99], [2028, 2, 29, 789, 89]]
	for c in cases:
		var days := DayIndex.days_since_epoch(c[0], c[1], c[2])
		var id := DayIndex.course_id(days, 100)
		if days != c[3] or id != c[4]:
			return "%d-%d-%d: days %d id %d" % [c[0], c[1], c[2], days, id]
	if DayIndex.label(13) != "014":
		return "表示の番号: " + DayIndex.label(13)
	for seed_value in range(1, 201):
		for today in 100:
			var id := Rng.pick_other_course(seed_value, today, 100)
			if id == today or id < 0 or id > 99:
				return "種 %d 今日 %d で %d" % [seed_value, today, id]
	return ""


# AC-12: 打数の上限と合計。
func test_round_progress() -> String:
	var holes := [{}, {}, {}, {}, {}]
	var rs := RoundState.new(holes)
	for i in B.MAX_SHOTS - 1:
		if rs.record_shot("out") != "miss":
			return "上限の前に終わった"
	if rs.record_shot("crash") != "giveup" or rs.scores != [B.GIVEUP_SCORE]:
		return "上限で GIVEUP_SCORE にならない: " + str(rs.scores)
	rs.next_hole()
	if rs.hole_index != 1 or rs.shots != 0:
		return "次のホールにならない"
	var want := [B.GIVEUP_SCORE]
	for h in range(1, 5):
		for i in h:
			rs.record_shot("timeout")
		if rs.record_shot("goal") != "goal":
			return "入ったのに goal にならない"
		want.append(h + 1)
		if h < 4:
			rs.next_hole()
	if not rs.is_finished() or rs.scores != want or rs.total() != 10 + 2 + 3 + 4 + 5:
		return "合計が違う: %s %d" % [str(rs.scores), rs.total()]
	var tut := RoundState.new([{}], true)
	for i in 20:
		if tut.record_shot("out") != "miss":
			return "練習に上限がある"
	return ""


# AC-13: 飛行の進め方。
func test_frame_steps() -> String:
	var bank := 0.0
	var sum := 0
	for i in 10:
		var r := Sim.frame_steps(bank, 1.0 / 60.0, 1.0)
		sum += r[0]
		bank = r[1]
	if sum != 20:
		return "1/60 を 10 回で %d 歩" % sum
	if Sim.frame_steps(0.0, 5.0, 1.0)[0] != 12:
		return "delta 5.0 で 12 歩にならない"
	if Sim.frame_steps(0.0, 5.0, B.FAST_FORWARD)[0] != 48:
		return "早送りで 48 歩にならない"
	# 早送りでも、同じ初速の結果と歩数が変わらない
	var f: Array = SIM_FIXTURES[5]
	var goal := Sim.make_goal(f[1])
	var planets := Sim.make_planets(f[2])
	for mult in [1.0, B.FAST_FORWARD]:
		var s := Sim.start(float(f[3]), float(f[4]))
		bank = 0.0
		var done := false
		while not done:
			var r := Sim.frame_steps(bank, 1.0 / 60.0, mult)
			bank = r[1]
			for i in r[0]:
				if Sim.step(s, goal, planets, f[5]) != "":
					done = true
					break
		if s.result != f[6] or s.steps != f[7]:
			return "倍率 %s で %s %d" % [str(mult), s.result, s.steps]
	return ""


# AC-14: 共有テキスト。
func test_share_text() -> String:
	var a := ShareText.build(13, true, "2026-11-10", 0, [1, 2, 1, 3, 2], "https://example.github.io/sling-arc/")
	if a != "SlingArc コース014 (2026-11-10) 初回\n合計 9打 [1-2-1-3-2]\nhttps://example.github.io/sling-arc/":
		return "初回: " + a
	var b := ShareText.build(13, true, "2026-11-10", 1, [1, 2, 1, 3, 2], "")
	if b != "SlingArc コース014 (2026-11-10) 2回目\n合計 9打 [1-2-1-3-2]":
		return "2回目: " + b
	var c := ShareText.build(13, false, "2026-11-10", 0, [10, 2, 1, 3, 2], "")
	if c != "SlingArc コース014 ランダム\n合計 18打 [10-2-1-3-2]":
		return "ランダム: " + c
	return ""


# AC-15: 保存。
func test_save_store() -> String:
	var path := "user://_test_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s := SaveStore.new(path)
	if s.tutorial_done() or not s.sound_on() or not s.data["daily"].is_empty():
		return "既定値が違う"
	s.mark_tutorial_done()
	if not SaveStore.new(path).tutorial_done():
		return "tutorial_done が残らない"
	s.record_daily("2026-11-10", 13, 9, [1, 2, 1, 3, 2])
	var e: Dictionary = SaveStore.new(path).data["daily"]["2026-11-10"]
	if e["attempts"] != 1 or e["first_total"] != 9:
		return "1 回目: " + str(e)
	s.record_daily("2026-11-10", 13, 20, [4, 4, 4, 4, 4])
	e = SaveStore.new(path).data["daily"]["2026-11-10"]
	if e["attempts"] != 2 or e["first_total"] != 9 or e["first_holes"] != [1, 2, 1, 3, 2]:
		return "2 回目: " + str(e)
	for d in range(1, 9):
		s.record_daily("2026-12-%02d" % d, d, 5, [1, 1, 1, 1, 1])
	var daily: Dictionary = SaveStore.new(path).data["daily"]
	if daily.size() != 7 or daily.has("2026-11-10") or daily.has("2026-12-01"):
		return "7 件にならない: " + str(daily.keys())
	s.set_sound_on(false)
	if SaveStore.new(path).sound_on():
		return "音の設定が残らない"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var broken := SaveStore.new(path)
	if broken.tutorial_done() or not broken.sound_on() or not broken.data["daily"].is_empty():
		return "壊れた JSON で既定値にならない"
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 2, "tutorial_done": true}')
	f.close()
	if SaveStore.new(path).tutorial_done():
		return "version 違いで既定値にならない"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ""


# Web の置き場: localStorage に無い時は v0.1.0 の user:// のファイルを読み、user:// には書かない。
# ここ(Web でない)では localStorage が使えないので、書き込みは失敗を返すだけで止まらない。
func test_save_store_web_reads_legacy_file_only() -> String:
	var path := "user://_test_save_web.json"
	var old := '{"version": 1, "tutorial_done": true, "sound_on": false, "daily": {"2026-11-01": {"course_id": 5, "attempts": 2, "first_total": 12, "first_holes": [3, 2, 3, 2, 2]}}}'
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(old)
	f.close()
	var s := SaveStore.new(path)
	s._web = true
	s.load_data()
	if not s.tutorial_done() or s.sound_on() or s.attempts("2026-11-01") != 2:
		return "v0.1.0 のファイルを読めない: " + str(s.data)
	if s.save_data():
		return "Web でないのに localStorage へ書けたことになっている"
	s.set_sound_on(true)
	var after := FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if after != old:
		return "Web なのに user:// のファイルを書き換えた"
	return ""


# AC-10: 全ホールの solution と ±5 の 9 通りが入る。練習の 2 ホールも入る。
func test_course_solutions() -> String:
	var store := CourseStore.load_file()
	if not store["ok"]:
		return "courses.json: " + store["error"]
	for c in store["courses"]:
		for hi in c["holes"].size():
			var h: Dictionary = c["holes"][hi]
			var goal := Sim.make_goal(h["goal"])
			var planets := Sim.make_planets(h["planets"])
			for ox in [-5, 0, 5]:
				for oy in [-5, 0, 5]:
					var s := Sim.simulate(goal, planets, float(h["solution"][0] + ox), float(h["solution"][1] + oy), B.MAX_STEPS)
					if s.result != "goal":
						return "コース %d ホール %d (%+d, %+d): %s" % [c["id"], hi, ox, oy, s.result]
	var tut := [[0, -450], [220, -600]]
	for i in 2:
		var t: Dictionary = B.TUTORIAL_HOLES[i]
		var s := Sim.simulate(Sim.make_goal(t["goal"]), Sim.make_planets(t["planets"]), float(tut[i][0]), float(tut[i][1]), B.MAX_STEPS)
		if s.result != "goal":
			return "練習 T%d: %s" % [i + 1, s.result]
	return ""


# AC-11: courses.json の形と距離の条件。
func test_course_shape() -> String:
	var text := FileAccess.get_file_as_string(CourseStore.PATH)
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY or raw["courses"].size() != B.N_COURSES:
		return "本数が違う"
	var store := CourseStore.parse(text)  # 形・整数・physics は course_store が検査する
	if not store["ok"]:
		return store["error"]
	for c in store["courses"]:
		for hi in c["holes"].size():
			var h: Dictionary = c["holes"][hi]
			var g: Array = h["goal"]
			if g[0] < 140 or g[0] > 580 or g[1] < 150 or g[1] > 330:
				return "コース %d ホール %d: ゴールが範囲外" % [c["id"], hi]
			var placed := []
			for p in h["planets"]:
				var r: int = p[2]
				if _d2(p, [B.PAD_X, B.PAD_Y]) < (r + 140) * (r + 140):
					return "コース %d ホール %d: 発射台に近い" % [c["id"], hi]
				if _d2(p, g) < (r + int(B.GOAL_R) + 60) * (r + int(B.GOAL_R) + 60):
					return "コース %d ホール %d: ゴールに近い" % [c["id"], hi]
				for q in placed:
					if _d2(p, q) < (r + q[2] + 50) * (r + q[2] + 50):
						return "コース %d ホール %d: 惑星どうしが近い" % [c["id"], hi]
				placed.append(p)
	return ""


static func _d2(a: Array, b: Array) -> float:
	var dx := float(a[0]) - float(b[0])
	var dy := float(a[1]) - float(b[1])
	return dx * dx + dy * dy


# AC-18: 壊れた・本数の足りない・physics の違う courses.json でエラーを返し、落ちない。
func test_course_store_errors() -> String:
	var good := FileAccess.get_file_as_string(CourseStore.PATH)
	var cases := {
		"壊れた JSON": "{ not json",
		"本数が足りない": good.replace('"courses": [', '"courses": [ ] , "x": ['),
		"physics が違う": good.replace('"surface_g": 6000', '"surface_g": 6001'),
		"ホールが足りない": good.replace('{ "id": 0, "holes": [', '{ "id": 0, "holes": [ ], "h": ['),
	}
	for k in cases:
		var r := CourseStore.parse(cases[k])
		if r["ok"]:
			return k + " を読めてしまった"
	if not CourseStore.parse(good)["ok"]:
		return "正しい物が読めない"
	if CourseStore.load_file("res://data/_none.json")["ok"]:
		return "無いファイルを読めてしまった"
	return ""


# AC-17: 禁じた書き方がソースに無い。
func test_source_rules() -> String:
	var sim := FileAccess.get_file_as_string("res://core/sim.gd")
	var re := RegEx.create_from_string("\\b(Vector2|sin|cos|pow|length|normalized)\\b")
	var m := re.search(sim)
	if m:
		return "sim.gd に " + m.get_string()
	var banned := RegEx.create_from_string("\\b(randi|randf|randomize|RandomNumberGenerator|shuffle|pick_random)\\b")
	for dir in ["res://core", "res://tools"]:
		for file in _gd_files(dir):
			m = banned.search(FileAccess.get_file_as_string(file))
			if m:
				return file + " に " + m.get_string()
	for file in _gd_files("res://ui"):
		if FileAccess.get_file_as_string(file).contains("SURFACE_G"):
			return file + " に SURFACE_G"
	return ""


func _gd_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
