# 日付から通し日数とコース番号を出す(§9.6)。整数の計算だけで、グレゴリオ暦のうるう年を含む。
# 日付は端末のローカルの日付(D-12)。
extends RefCounted

const B := preload("res://core/balance.gd")


# 1970-01-01 からの通し日数(H. Hinnant の days_from_civil)。
@warning_ignore("integer_division")
static func days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func days_since_epoch(y: int, m: int, d: int) -> int:
	return days_from_civil(y, m, d) - B.EPOCH_DAYS


static func course_id(days: int, n: int) -> int:
	return ((days % n) + n) % n


static func label(id: int) -> String:
	return "%03d" % (id + 1)


static func date_string(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]


# 端末のローカルの日付 [y, m, d]。
static func today() -> Array:
	var t := Time.get_date_dict_from_system()
	return [int(t["year"]), int(t["month"]), int(t["day"])]
