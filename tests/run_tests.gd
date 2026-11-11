# 自前のテストランナー(D-13)。godot --headless --script res://tests/run_tests.gd で動かす。
# test_ で始まる関数を順に呼び、空文字なら成功、それ以外は失敗の理由。1 件でも失敗なら終了コード 1。
extends SceneTree

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const STRINGS_PATH := "res://core/strings.gd"


func _initialize() -> void:
	var failed := 0
	var total := 0
	for m in get_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		total += 1
		var err: String = call(name)
		if err == "":
			print("PASS ", name)
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
