# タイトル画面(FR-2)。題名・軌道の飾り・今日のコース番号・3 つのボタン・版を出す。
# データが読めないときはエラーを出し、開始ボタンを押せなくする(E-12)。
extends Control

signal daily_pressed
signal random_pressed
signal sound_toggled(on: bool)

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var _course := ""
var _error := false
var _sound := true
var _first := -1
var _t := 0.0
var _orbit_pts: Array = []
var _sound_btn: Button

const ORBIT_C := Vector2(360, 520)


func setup(course: String, error: bool, sound_on: bool, first_total: int) -> void:
	_course = course
	_error = error
	_sound = sound_on
	_first = first_total


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var planet := Kit.shader_rect("res://ui/shaders/planet.gdshader", Rect2(ORBIT_C - Vector2(110, 110), Vector2(220, 220)))
	var m: ShaderMaterial = planet.material
	m.set_shader_parameter("base_color", Color(0.45, 0.70, 1.0))
	m.set_shader_parameter("shade_color", Color(0.10, 0.12, 0.40))
	m.set_shader_parameter("glow_color", Color(0.45, 0.75, 1.0, 0.9))
	m.set_shader_parameter("radius_frac", 0.55)
	m.set_shader_parameter("seed", 3.0)
	add_child(planet)

	var title := Kit.label(S.TITLE, 124, 800, Kit.C_TEXT, Color(Kit.C_ACCENT, 0.7))
	title.position = Vector2(0, 120)
	title.size = Vector2(B.FIELD_W, 170)
	add_child(title)
	var sub := Kit.label(S.SUBTITLE, 40, 500, Kit.C_DIM)
	sub.position = Vector2(0, 280)
	sub.size = Vector2(B.FIELD_W, 60)
	add_child(sub)

	var info := Kit.label("", 34, 700, Kit.C_ACCENT)
	info.position = Vector2(0, 730)
	info.size = Vector2(B.FIELD_W, 50)
	if _error:
		info.text = S.DATA_ERROR
		info.add_theme_color_override("font_color", Kit.C_WARN)
	else:
		info.text = S.TODAY_IS + " " + _course
	add_child(info)
	if _first >= 0 and not _error:
		var done := Kit.label(S.DAILY_DONE % _first, 26, 500, Kit.C_GOLD)
		done.position = Vector2(0, 775)
		done.size = Vector2(B.FIELD_W, 40)
		add_child(done)

	var daily := Kit.button(S.BTN_DAILY, 44, true)
	daily.position = Vector2(150, 830)
	daily.size = Vector2(420, 110)
	daily.disabled = _error
	daily.pressed.connect(func(): daily_pressed.emit())
	add_child(daily)
	var rnd := Kit.button(S.BTN_RANDOM, 38)
	rnd.position = Vector2(150, 965)
	rnd.size = Vector2(420, 96)
	rnd.disabled = _error
	rnd.pressed.connect(func(): random_pressed.emit())
	add_child(rnd)
	_sound_btn = Kit.button("", 28)
	_sound_btn.position = Vector2(260, 1090)
	_sound_btn.size = Vector2(200, 72)
	_sound_btn.pressed.connect(func():
		_sound = not _sound
		_update_sound()
		sound_toggled.emit(_sound))
	_update_sound()
	add_child(_sound_btn)

	var ver: String = ProjectSettings.get_setting("application/config/version", "")
	var v := Kit.label(S.VERSION_PREFIX + ver, 24, 400, Kit.C_DIM)
	v.position = Vector2(0, 1210)
	v.size = Vector2(B.FIELD_W, 40)
	add_child(v)

	var i := 0
	for c in [title, sub, info, daily, rnd, _sound_btn]:
		Kit.rise_in(c, 0.05 + 0.07 * i)
		i += 1


func _update_sound() -> void:
	_sound_btn.text = S.SOUND_ON if _sound else S.SOUND_OFF


# 飾りの軌道(楕円)。見た目だけで、ゲームの計算とは関係ない。
func _process(delta: float) -> void:
	_t += delta
	var a := _t * 1.3
	var p := ORBIT_C + Vector2(cos(a) * 230.0, sin(a) * 90.0).rotated(-0.35)
	_orbit_pts.append(p)
	if _orbit_pts.size() > 70:
		_orbit_pts.pop_front()
	queue_redraw()


func _draw() -> void:
	var ell := PackedVector2Array()
	for k in 97:
		var a := TAU * k / 96.0
		ell.append(ORBIT_C + Vector2(cos(a) * 230.0, sin(a) * 90.0).rotated(-0.35))
	draw_polyline(ell, Color(Kit.C_ACCENT, 0.12), 2.0, true)
	var n := _orbit_pts.size()
	for i in range(1, n):
		var k := float(i) / float(n)
		draw_line(_orbit_pts[i - 1], _orbit_pts[i], Color(Kit.C_ACCENT, 0.7 * k), 2.0 + 3.0 * k, true)
	if n > 0:
		var p: Vector2 = _orbit_pts[n - 1]
		# 惑星の手前か奥か(奥なら少し暗く)
		var front := sin(_t * 1.3) > 0.0
		var alpha := 1.0 if front else 0.45
		draw_circle(p, 18.0, Color(0.5, 0.9, 1.0, 0.15 * alpha))
		draw_circle(p, 8.0, Color(0.8, 0.95, 1.0, alpha))
