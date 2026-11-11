# 画面の共通部品(色・太さ違いのフォント・ラベル・ボタン・テーマ)。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"

const C_BG := Color(0.02, 0.03, 0.08)
const C_TEXT := Color(0.92, 0.95, 1.0)
const C_DIM := Color(0.62, 0.70, 0.86)
const C_ACCENT := Color(0.42, 0.86, 1.0)
const C_GOAL := Color(0.45, 1.0, 0.78)
const C_WARN := Color(1.0, 0.55, 0.42)
const C_GOLD := Color(1.0, 0.84, 0.45)

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(FONT_PATH)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size: int, weight: int = 400, color: Color = C_TEXT, glow: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if glow.a > 0.0:
		l.add_theme_color_override("font_shadow_color", glow)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", clampi(size / 9, 4, 14))
	return l


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(22)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(border.r, border.g, border.b, 0.28)
	s.shadow_size = 14
	s.anti_aliasing = true
	return s


# primary は塗りの強い主ボタン。押すと少し縮む。
static func button(text: String, size: int = 36, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	var base := C_ACCENT if primary else Color(0.55, 0.62, 0.95)
	var fill := Color(base.r * 0.22, base.g * 0.22, base.b * 0.32, 0.92)
	b.add_theme_stylebox_override("normal", _box(fill, Color(base, 0.75), 2))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.10), base, 3))
	b.add_theme_stylebox_override("pressed", _box(fill.lightened(0.25), base.lightened(0.3), 3))
	b.add_theme_stylebox_override("disabled", _box(Color(0.08, 0.09, 0.14, 0.7), Color(0.3, 0.32, 0.4, 0.6), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.58))
	b.button_down.connect(func(): _squash(b, 0.94))
	b.button_up.connect(func(): _squash(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	return b


static func _squash(c: Control, s: float) -> void:
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(s, s), 0.08).set_trans(Tween.TRANS_QUAD)


# 子を下から浮かび上がらせる演出。
static func rise_in(c: CanvasItem, delay: float, dist: float = 40.0) -> void:
	c.modulate.a = 0.0
	var start: Vector2 = c.position
	c.position = start + Vector2(0, dist)
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.45).set_delay(delay)
	t.tween_property(c, "position", start, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shader_rect(path: String, rect: Rect2) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(path)
	r.material = m
	return r
