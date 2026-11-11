# Phase 2 だけの診断表示(§8.2)。§9.3 の固定値 6 行を core/sim.gd で計算し、コンソールと画面の隅に出す。
# Web(Pages)でも Windows・Linux と同じ結果になるかを確かめるためのもので、Phase 3 で消す。
extends Label

const Sim := preload("res://core/sim.gd")

const FIX := [
	["V1", [360, 240], [], 0, -450, 1440, "goal", 229, 360.000000, 271.250000],
	["V2", [300, 240], [[420, 700, 60]], 0, -720, 1440, "crash", 59, 371.667980, 738.974654],
	["V3", [360, 240], [[360, 700, 60]], 300, -300, 1440, "out", 402, 657.873683, -202.344354],
	["V4", [300, 240], [[330, 700, 60]], -290, -850, 1440, "goal", 110, 288.219403, 267.805211],
	["V5", [360, 240], [], 0, -450, 100, "timeout", 100, 360.000000, 755.000000],
	["V6", [360, 260], [[360, 700, 60]], 220, -600, 1440, "goal", 146, 357.489295, 293.817955],
]


func _ready() -> void:
	var lines := PackedStringArray()
	var all_ok := true
	for f in FIX:
		var s = Sim.simulate(Sim.make_goal(f[1]), Sim.make_planets(f[2]), float(f[3]), float(f[4]), f[5])
		var ok: bool = s.result == f[6] and s.steps == f[7] and absf(s.x - f[8]) <= 0.000001 and absf(s.y - f[9]) <= 0.000001
		all_ok = all_ok and ok
		var line := "%s %s %d (%.6f, %.6f) %s" % [f[0], s.result, s.steps, s.x, s.y, "OK" if ok else "NG"]
		lines.append(line)
		print("SLINGARC_DIAG " + line)
	print("SLINGARC_DIAG ALL " + ("OK" if all_ok else "NG"))
	text = "\n".join(lines)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 0.8) if all_ok else Color(1, 0.4, 0.4))
	position = Vector2(8, 1150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
