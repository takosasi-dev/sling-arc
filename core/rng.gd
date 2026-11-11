# 進行に関わる乱数(§9.2・INV-13)。xorshift32 と FNV-1a(32 ビット)だけを持つ。
# 端末や版で結果が変わらないよう、Godot の乱数関数は使わない。
extends RefCounted

const MASK := 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = seed_value & MASK
	if state == 0:
		state = 1


func next() -> int:
	var x := state
	x = x ^ ((x << 13) & MASK)
	x = x ^ (x >> 17)
	x = x ^ ((x << 5) & MASK)
	state = x
	return x


func next_int(n: int) -> int:
	return next() % n


static func fnv1a(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = h ^ b
		h = (h * 16777619) & MASK
	return h


# ランダムの入口(FR-14): 今日のコース以外から 1 本を選ぶ。
static func pick_other_course(seed_value: int, today_id: int, n_courses: int) -> int:
	var r := new(seed_value)
	var id := r.next_int(n_courses - 1)
	if id >= today_id:
		id += 1
	return id


static func random_seed_now() -> int:
	var unix := int(Time.get_unix_time_from_system())
	return fnv1a("SAR:" + str(unix) + ":" + str(Time.get_ticks_usec()))
