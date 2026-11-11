# 結果画面(FR-12・FR-15)。合計・ホールごとの打数・コース番号・共有テキストの欄とボタンを出す。
# コピーは試すだけで、成功したとは出さない(INV-11・E-13)。
extends Control

signal retry_pressed
signal title_pressed

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var _course := ""
var _daily := false
var _scores: Array = []
var _share := ""
var _total_label: Label
var _msg: Label


func setup(course: String, daily: bool, scores: Array, share: String) -> void:
	_course = course
	_daily = daily
	_scores = scores
	_share = share


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := 0
	for s in _scores:
		total += int(s)

	var head := Kit.label(S.RESULT_TITLE, 56, 800, Kit.C_TEXT, Color(Kit.C_GOAL, 0.5))
	head.position = Vector2(0, 90)
	head.size = Vector2(B.FIELD_W, 80)
	add_child(head)
	var kind := Kit.label((S.RESULT_DAILY if _daily else S.RESULT_RANDOM) + "  " + _course, 32, 700, Kit.C_ACCENT)
	kind.position = Vector2(0, 175)
	kind.size = Vector2(B.FIELD_W, 50)
	add_child(kind)

	_total_label = Kit.label(S.SHOTS_FMT % 0, 150, 900, Kit.C_GOLD, Color(1.0, 0.7, 0.3, 0.30))
	_total_label.position = Vector2(0, 240)
	_total_label.size = Vector2(B.FIELD_W, 200)
	add_child(_total_label)
	var cap := Kit.label(S.HUD_TOTAL, 28, 500, Kit.C_DIM)
	cap.position = Vector2(0, 230)
	cap.size = Vector2(B.FIELD_W, 40)
	add_child(cap)
	var tw := create_tween()
	tw.tween_method(func(v: float): _total_label.text = S.SHOTS_FMT % int(round(v)), 0.0, float(total), 0.9).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# ホールごとの打数
	var n := _scores.size()
	var w := 112.0
	var x0 := (B.FIELD_W - w * n - 12.0 * (n - 1)) / 2.0
	for i in n:
		var s := int(_scores[i])
		var chip := Panel.new()
		var sb := StyleBoxFlat.new()
		var col := Kit.C_WARN if s >= B.GIVEUP_SCORE else (Kit.C_GOLD if s == 1 else Kit.C_GOAL)
		sb.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.2, 0.9)
		sb.border_color = Color(col, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		chip.add_theme_stylebox_override("panel", sb)
		chip.position = Vector2(x0 + i * (w + 12.0), 470)
		chip.size = Vector2(w, 130)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		var hl := Kit.label("%d" % (i + 1), 22, 500, Kit.C_DIM)
		hl.position = Vector2(0, 8)
		hl.size = Vector2(w, 30)
		chip.add_child(hl)
		var sl := Kit.label(str(s), 54, 800, col)
		sl.position = Vector2(0, 40)
		sl.size = Vector2(w, 80)
		chip.add_child(sl)
		Kit.rise_in(chip, 0.6 + 0.09 * i, 30.0)

	var share := TextEdit.new()
	share.text = _share
	share.editable = false
	share.position = Vector2(70, 820)
	share.size = Vector2(580, 150)
	share.add_theme_font_override("font", Kit.font(500))
	share.add_theme_font_size_override("font_size", 26)
	share.add_theme_color_override("font_readonly_color", Kit.C_TEXT)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.03, 0.05, 0.12, 0.85)
	tsb.border_color = Color(Kit.C_ACCENT, 0.35)
	tsb.set_border_width_all(2)
	tsb.set_corner_radius_all(16)
	tsb.content_margin_left = 18
	tsb.content_margin_top = 14
	share.add_theme_stylebox_override("read_only", tsb)
	share.add_theme_stylebox_override("normal", tsb)
	share.add_theme_stylebox_override("focus", tsb)
	add_child(share)

	var copy := Kit.button(S.BTN_COPY, 32, true)
	copy.position = Vector2(170, 640)
	copy.size = Vector2(380, 88)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_share)
		_msg.text = S.COPY_TRIED
		_msg.modulate.a = 0.0
		_msg.create_tween().tween_property(_msg, "modulate:a", 1.0, 0.25))
	add_child(copy)
	_msg = Kit.label("", 21, 500, Kit.C_DIM)
	_msg.position = Vector2(30, 738)
	_msg.size = Vector2(B.FIELD_W - 60, 76)
	_msg.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	add_child(_msg)

	var retry := Kit.button(S.BTN_RETRY, 34)
	retry.position = Vector2(70, 1050)
	retry.size = Vector2(280, 96)
	retry.pressed.connect(func(): retry_pressed.emit())
	add_child(retry)
	var back := Kit.button(S.BTN_TITLE, 34)
	back.position = Vector2(370, 1050)
	back.size = Vector2(280, 96)
	back.pressed.connect(func(): title_pressed.emit())
	add_child(back)

	var i := 0
	for c in [head, kind, copy, share, retry, back]:
		Kit.rise_in(c, 0.05 + 0.08 * i)
		i += 1
