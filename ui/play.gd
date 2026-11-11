# プレイ画面。引っ張り → 飛行 → 結果 → 次のホール、を回す(FR-4〜FR-11・FR-19・FR-20)。
# 軌道は core/sim.gd の step だけで進め、進行は core/round_state.gd に任せる。描画は field.gd。
extends Control

signal finished(scores: Array)
signal skipped

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Aim := preload("res://core/aim.gd")
const RoundState := preload("res://core/round_state.gd")
const Kit := preload("res://ui/kit.gd")
const Field := preload("res://ui/field.gd")

enum { AIM, DRAG, FLY, RESET, PANEL, DONE }

var sfx: Node
var rs: RoundState
var tutorial := false
var course_text := ""

var state := AIM
var field: Field
var goal_arr: PackedFloat64Array
var planets_arr: PackedFloat64Array
var sim_state
var bank := 0.0
var fast := false
var fly_time := 0.0
var drag_start := Vector2.ZERO
var aim_v: Array = []
var panel_at := 0.0
var shots_this_hole := 0

var hud_hole: Label
var hud_course: Label
var hud_shots: Label
var hud_total: Label
var hint_label: Label
var fast_label: Label
var toast: Label
var panel: Control
var panel_big: Label
var panel_sub: Label
var panel_next: Label
var banner: Label


func setup(p_sfx: Node, holes: Array, p_tutorial: bool, p_course_text: String) -> void:
	sfx = p_sfx
	rs = RoundState.new(holes, p_tutorial)
	tutorial = p_tutorial
	course_text = p_course_text


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	field = Field.new()
	add_child(field)
	_build_hud()
	_build_overlays()
	get_viewport().size_changed.connect(_cancel_drag)
	_load_hole()


func _build_hud() -> void:
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.55)
	sb.border_color = Color(Kit.C_ACCENT, 0.25)
	sb.border_width_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2.ZERO
	bar.size = Vector2(B.FIELD_W, 128)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var cap_hole := Kit.label(S.TUTORIAL_TAG if tutorial else S.HUD_HOLE, 22, 500, Kit.C_DIM)
	cap_hole.position = Vector2(24, 14)
	cap_hole.size = Vector2(150, 30)
	bar.add_child(cap_hole)
	hud_hole = Kit.label("", 52, 800, Kit.C_TEXT, Color(Kit.C_ACCENT, 0.5))
	hud_hole.position = Vector2(24, 44)
	hud_hole.size = Vector2(150, 70)
	bar.add_child(hud_hole)

	hud_course = Kit.label("" if tutorial else course_text, 28, 700, Kit.C_ACCENT)
	hud_course.position = Vector2(220, 40)
	hud_course.size = Vector2(280, 50)
	bar.add_child(hud_course)

	var cap_shots := Kit.label(S.HUD_SHOTS, 22, 500, Kit.C_DIM)
	cap_shots.position = Vector2(500, 14)
	cap_shots.size = Vector2(100, 30)
	bar.add_child(cap_shots)
	hud_shots = Kit.label("", 40, 800, Kit.C_TEXT)
	hud_shots.position = Vector2(500, 48)
	hud_shots.size = Vector2(100, 60)
	bar.add_child(hud_shots)
	var cap_total := Kit.label(S.HUD_TOTAL, 22, 500, Kit.C_DIM)
	cap_total.position = Vector2(600, 14)
	cap_total.size = Vector2(100, 30)
	bar.add_child(cap_total)
	hud_total = Kit.label("", 40, 800, Kit.C_GOLD)
	hud_total.position = Vector2(600, 48)
	hud_total.size = Vector2(100, 60)
	bar.add_child(hud_total)
	if tutorial:
		hud_total.visible = false
		cap_total.visible = false
		var skip := Kit.button(S.SKIP, 28)
		skip.position = Vector2(520, 146)
		skip.size = Vector2(180, 64)
		skip.pressed.connect(func():
			if state != DONE:
				state = DONE
				skipped.emit())
		add_child(skip)


func _build_overlays() -> void:
	hint_label = Kit.label(S.HINT_PULL, 44, 700, Kit.C_TEXT, Color(Kit.C_ACCENT, 0.6))
	hint_label.position = Vector2(0, 760)
	hint_label.size = Vector2(B.FIELD_W, 70)
	add_child(hint_label)

	fast_label = Kit.label(S.FAST_HINT, 24, 500, Kit.C_DIM)
	fast_label.position = Vector2(0, 1225)
	fast_label.size = Vector2(B.FIELD_W, 40)
	fast_label.modulate.a = 0.0
	add_child(fast_label)

	toast = Kit.label("", 40, 800, Kit.C_WARN, Color(Kit.C_WARN, 0.5))
	toast.position = Vector2(0, 560)
	toast.size = Vector2(B.FIELD_W, 70)
	toast.pivot_offset = toast.size / 2.0
	toast.modulate.a = 0.0
	add_child(toast)

	banner = Kit.label("", 120, 900, Color(1, 1, 1, 0.9), Color(Kit.C_ACCENT, 0.6))
	banner.position = Vector2(0, 520)
	banner.size = Vector2(B.FIELD_W, 160)
	banner.pivot_offset = banner.size / 2.0
	banner.modulate.a = 0.0
	add_child(banner)

	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.16, 0.88)
	sb.border_color = Color(Kit.C_GOAL, 0.7)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(36)
	sb.shadow_color = Color(Kit.C_GOAL, 0.25)
	sb.shadow_size = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(480, 330)
	panel.position = Vector2((B.FIELD_W - 480) / 2.0, 470)
	panel.pivot_offset = panel.size / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	panel_big = Kit.label("", 110, 900, Kit.C_GOAL, Color(Kit.C_GOAL, 0.55))
	panel_big.position = Vector2(0, 30)
	panel_big.size = Vector2(480, 140)
	panel.add_child(panel_big)
	panel_sub = Kit.label("", 32, 700, Kit.C_GOLD)
	panel_sub.position = Vector2(0, 175)
	panel_sub.size = Vector2(480, 50)
	panel.add_child(panel_sub)
	panel_next = Kit.label(S.PANEL_NEXT, 28, 500, Kit.C_DIM)
	panel_next.position = Vector2(0, 255)
	panel_next.size = Vector2(480, 50)
	panel.add_child(panel_next)


func _load_hole() -> void:
	var hole: Dictionary = rs.current_hole()
	goal_arr = Sim.make_goal(hole["goal"])
	planets_arr = Sim.make_planets(hole["planets"])
	field.set_hole(hole)
	shots_this_hole = 0
	state = AIM
	_update_hud()
	field.hint_active = tutorial and rs.hole_index == 0
	hint_label.visible = field.hint_active
	banner.text = "%d/%d" % [rs.hole_index + 1, rs.holes.size()]
	banner.scale = Vector2(1.4, 1.4)
	var tw := banner.create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.4).set_delay(0.5)


func _update_hud() -> void:
	hud_hole.text = "%d/%d" % [rs.hole_index + 1, rs.holes.size()]
	hud_shots.text = S.SHOTS_FMT % rs.shots
	hud_total.text = S.SHOTS_FMT % rs.running_total()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var local: InputEvent = make_input_local(event)
	var pos: Vector2 = local.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(pos)
		else:
			_on_release(pos)
	elif event is InputEventMouseMotion and state == DRAG:
		_on_drag(pos)


func _on_press(pos: Vector2) -> void:
	match state:
		AIM:
			state = DRAG
			field.hint_active = false
			hint_label.visible = false
			drag_start = pos
			_on_drag(pos)
		FLY:
			fast = true
		PANEL:
			if Time.get_ticks_msec() / 1000.0 - panel_at >= B.PANEL_GUARD_SEC:
				_advance()


func _on_release(pos: Vector2) -> void:
	if state == FLY:
		fast = false
		return
	if state != DRAG:
		return
	var inside := Rect2(Vector2.ZERO, Vector2(B.FIELD_W, B.FIELD_H)).has_point(pos)
	if not inside or aim_v.is_empty():
		_cancel_drag()
		return
	_fire(aim_v)


func _on_drag(pos: Vector2) -> void:
	field.aim_active = true
	field.aim_start = drag_start
	field.aim_cur = pos
	aim_v = Aim.pull_to_velocity(drag_start.x, drag_start.y, pos.x, pos.y)
	field.preview = PackedVector2Array()
	if aim_v.is_empty():
		field.aim_dir = Vector2.ZERO
		return
	field.aim_dir = Vector2(aim_v[0], aim_v[1]).normalized()
	field.aim_power = aim_v[2]
	var s = Sim.start(aim_v[0], aim_v[1])
	var pts := PackedVector2Array([field.pad])
	for i in B.PREVIEW_STEPS:
		var res := Sim.step(s, goal_arr, planets_arr, B.MAX_STEPS)
		pts.append(Vector2(s.x, s.y))
		if res != "":
			break
	field.preview = pts


func _cancel_drag() -> void:
	if state == DRAG:
		state = AIM
		if tutorial and rs.hole_index == 0 and rs.shots == 0:
			field.hint_active = true
			hint_label.visible = true
	field.aim_active = false
	aim_v = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()
		fast = false


func _fire(v: Array) -> void:
	field.aim_active = false
	field.last_dir = Vector2(v[0], v[1]).normalized()
	field.last_power = v[2]
	field.hint_active = false
	hint_label.visible = false
	sim_state = Sim.start(v[0], v[1])
	bank = 0.0
	fast = false
	fly_time = 0.0
	field.flight_points = PackedVector2Array([field.pad])
	state = FLY
	aim_v = []
	sfx.play("launch")


func _process(delta: float) -> void:
	if state != FLY:
		fast_label.modulate.a = move_toward(fast_label.modulate.a, 0.0, delta * 3.0)
		return
	fly_time += delta
	fast_label.modulate.a = move_toward(fast_label.modulate.a, 1.0 if fly_time > 1.2 else 0.0, delta * 2.0)
	var r := Sim.frame_steps(bank, delta, B.FAST_FORWARD if fast else 1.0)
	bank = r[1]
	var result := ""
	for i in r[0]:
		result = Sim.step(sim_state, goal_arr, planets_arr, B.MAX_STEPS)
		if sim_state.steps % 2 == 0 or result != "":
			field.flight_points.append(Vector2(sim_state.x, sim_state.y))
		if result != "":
			break
	field.probe_pos = Vector2(sim_state.x, sim_state.y)
	if result != "":
		_end_flight(result)


func _end_flight(result: String) -> void:
	field.add_trail(field.flight_points, result)
	field.flight_points = PackedVector2Array()
	var ev := rs.record_shot(result)
	_update_hud()
	var at := Vector2(sim_state.x, sim_state.y)
	match result:
		"crash":
			sfx.play("crash")
			field.burst(at, Kit.C_WARN, 22, 240.0)
			field.probe_visible = false
		"goal":
			sfx.play("goal")
			field.goal_flash()
			field.probe_visible = false
		_:
			field.probe_visible = false
	if ev == "goal" or ev == "giveup":
		_show_panel(ev)
		return
	_toast({"crash": S.MISS_CRASH, "out": S.MISS_OUT, "timeout": S.MISS_TIMEOUT}.get(result, ""))
	state = RESET
	get_tree().create_timer(0.45).timeout.connect(func():
		if state != RESET:
			return
		field.probe_pos = field.pad
		field.probe_visible = true
		field.burst(field.pad, Kit.C_ACCENT, 10, 90.0)
		state = AIM)


func _toast(text: String) -> void:
	toast.text = text
	toast.scale = Vector2(0.7, 0.7)
	var tw := toast.create_tween().set_parallel(true)
	tw.tween_property(toast, "modulate:a", 1.0, 0.12)
	tw.tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(toast, "modulate:a", 0.0, 0.4).set_delay(0.35)


func _show_panel(ev: String) -> void:
	state = PANEL
	fast = false
	panel_at = Time.get_ticks_msec() / 1000.0
	var good := ev == "goal"
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var col := Kit.C_GOAL if good else Kit.C_WARN
	sb.border_color = Color(col, 0.7)
	sb.shadow_color = Color(col, 0.25)
	panel_big.text = S.PANEL_GOAL % rs.scores.back() if good else S.PANEL_GIVEUP
	panel_big.add_theme_color_override("font_color", col)
	panel_big.add_theme_color_override("font_shadow_color", Color(col, 0.55))
	panel_sub.text = S.PANEL_ACE if good and rs.scores.back() == 1 else ""
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel_next.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2).set_delay(0.25)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_next, "modulate:a", 1.0, 0.3).set_delay(B.PANEL_GUARD_SEC + 0.1)


func _advance() -> void:
	if state != PANEL:
		return
	if rs.is_last_hole():
		state = DONE
		finished.emit(rs.scores)
		return
	state = RESET
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		panel.visible = false
		rs.next_hole()
		_load_hole())
