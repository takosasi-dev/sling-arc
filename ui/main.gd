# 画面の切り替え(タイトル → 練習 → コース → 結果)と、保存・コースのデータ・効果音を持つ。
# 日付とコース番号はコースを始めたときに決め、終わるまで変えない(E-9)。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const DayIndex := preload("res://core/day_index.gd")
const CourseStore := preload("res://core/course_store.gd")
const Rng := preload("res://core/rng.gd")
const ShareText := preload("res://core/share_text.gd")
const SaveStore := preload("res://save/save_store.gd")
const Sfx := preload("res://audio/sfx.gd")
const Kit := preload("res://ui/kit.gd")
const Title := preload("res://ui/title.gd")
const Play := preload("res://ui/play.gd")
const Result := preload("res://ui/result.gd")

var save: SaveStore
var courses: Array = []
var data_error := ""
var sfx: Node
var bg: ColorRect
var holder: Control
var fade: ColorRect
var busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 引っ張りは play.gd の _unhandled_input で受けるので、ここで止めない
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	save = SaveStore.new()
	var loaded := CourseStore.load_file()
	if loaded["ok"]:
		courses = loaded["courses"]
	else:
		data_error = loaded["error"]
		push_warning("courses.json: " + data_error)
	bg = Kit.shader_rect("res://ui/shaders/space.gdshader", Rect2(0, 0, B.FIELD_W, B.FIELD_H))
	add_child(bg)
	holder = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	fade = ColorRect.new()
	fade.color = Kit.C_BG
	fade.size = Vector2(B.FIELD_W, B.FIELD_H)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.enabled = save.sound_on()
	add_child(preload("res://ui/diag.gd").new())  # Phase 2 だけ
	show_title()


func today_info() -> Dictionary:
	var t := DayIndex.today()
	var days := DayIndex.days_since_epoch(t[0], t[1], t[2])
	return {"date": DayIndex.date_string(t[0], t[1], t[2]), "id": DayIndex.course_id(days, B.N_COURSES)}


func course_text(id: int) -> String:
	return S.COURSE_PREFIX + DayIndex.label(id)


func _set_bg_seed(id: int) -> void:
	bg.material.set_shader_parameter("seed", float(id + 1))


# 画面を暗転で入れ替える。切り替え中の入力は受けない(E-1・E-17)。
func _swap(screen: Control) -> void:
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.18 if holder.get_child_count() > 0 else 0.0)
	tw.tween_callback(func():
		for c in holder.get_children():
			c.queue_free()
		holder.add_child(screen))
	tw.tween_property(fade, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		busy = false)


func show_title() -> void:
	var today := today_info()
	_set_bg_seed(today["id"])
	var t := Title.new()
	var first := -1
	var e = save.data["daily"].get(today["date"])
	if e != null:
		first = int(e["first_total"])
	t.setup(course_text(today["id"]), data_error != "", save.sound_on(), first)
	t.daily_pressed.connect(func(): _start(true))
	t.random_pressed.connect(func(): _start(false))
	t.sound_toggled.connect(func(on: bool):
		save.set_sound_on(on)
		sfx.enabled = on)
	_swap(t)


func _start(is_daily: bool) -> void:
	if busy or data_error != "":
		return
	var today := today_info()
	var id: int = today["id"]
	if not is_daily:
		id = Rng.pick_other_course(Rng.random_seed_now(), id, B.N_COURSES)
	var run := {"id": id, "daily": is_daily, "date": today["date"]}
	if save.tutorial_done():
		_play_course(run)
	else:
		_play_tutorial(run)


func _play_tutorial(run: Dictionary) -> void:
	_set_bg_seed(-1)
	var p := Play.new()
	p.setup(sfx, B.TUTORIAL_HOLES, true, S.TUTORIAL_TAG)
	var done := func():
		save.mark_tutorial_done()
		_play_course(run)
	p.finished.connect(func(_scores): done.call())
	p.skipped.connect(done)
	_swap(p)


func _play_course(run: Dictionary) -> void:
	_set_bg_seed(run["id"])
	var p := Play.new()
	p.setup(sfx, courses[run["id"]]["holes"], false, course_text(run["id"]))
	p.finished.connect(func(scores: Array): _finish(run, scores))
	_swap(p)


func _finish(run: Dictionary, scores: Array) -> void:
	sfx.play("complete")
	var before := 0
	var total := 0
	for s in scores:
		total += int(s)
	if run["daily"]:
		before = save.attempts(run["date"])
		save.record_daily(run["date"], run["id"], total, scores)
	var share := ShareText.build(run["id"], run["daily"], run["date"], before, scores, B.SHARE_URL)
	var r := Result.new()
	r.setup(course_text(run["id"]), run["daily"], scores, share)
	r.retry_pressed.connect(func():
		if not busy:
			_play_course(run))
	r.title_pressed.connect(func():
		if not busy:
			show_title())
	_swap(r)
