# 1 コースの進行(ホール・打数・合計)を持つ。練習のときは打数の上限が無い。
# 画面には依存しない。打った結果を record_shot に渡し、返ってきた出来事で画面を動かす。
extends RefCounted

const B := preload("res://core/balance.gd")

var holes: Array = []
var hole_index := 0
var shots := 0
var scores: Array = []
var tutorial := false


func _init(p_holes: Array, p_tutorial: bool = false) -> void:
	holes = p_holes
	tutorial = p_tutorial


func current_hole() -> Dictionary:
	return holes[hole_index]


# result は sim の結果("goal" / "crash" / "out" / "timeout")。
# 戻り値: "goal"(入った)/ "giveup"(上限に達した)/ "miss"(続ける)。
func record_shot(result: String) -> String:
	shots += 1
	if result == "goal":
		scores.append(shots)
		return "goal"
	if not tutorial and shots >= B.MAX_SHOTS:
		scores.append(B.GIVEUP_SCORE)
		return "giveup"
	return "miss"


func next_hole() -> void:
	hole_index += 1
	shots = 0


func is_finished() -> bool:
	return scores.size() >= holes.size()


func is_last_hole() -> bool:
	return hole_index >= holes.size() - 1


func total() -> int:
	var t := 0
	for s in scores:
		t += s
	return t


# 今のホールの打数も含めた合計(画面の表示用)。
func running_total() -> int:
	return total() + (shots if scores.size() <= hole_index else 0)
