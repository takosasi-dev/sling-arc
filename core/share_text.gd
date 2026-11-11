# 結果画面の共有テキストを組み立てる(§9.9)。絵文字は使わない。
# 文言は strings.gd から取る。
extends RefCounted

const S := preload("res://core/strings.gd")
const DayIndex := preload("res://core/day_index.gd")


# attempts_before: この回を記録する前に保存されていた、その日付の完走回数。
static func build(course_id: int, is_daily: bool, date_str: String, attempts_before: int, scores: Array, share_url: String) -> String:
	var head := S.GAME_NAME + " " + S.COURSE_PREFIX + DayIndex.label(course_id)
	if is_daily:
		var tail := S.SHARE_FIRST if attempts_before == 0 else S.SHARE_NTH % (attempts_before + 1)
		head += " (" + date_str + ") " + tail
	else:
		head += " " + S.SHARE_RANDOM
	var parts := PackedStringArray()
	var total := 0
	for s in scores:
		parts.append(str(s))
		total += int(s)
	var lines := PackedStringArray([head, S.SHARE_TOTAL % [total, "-".join(parts)]])
	if share_url != "":
		lines.append(share_url)
	return "\n".join(lines)
