# 引っ張りの長さと向きから初速を出す(§9.4)。
# 押し始め S から今の位置 C を引いた向きへ撃つ。DEAD_ZONE 未満は取り消しで、空の配列を返す。
extends RefCounted

const B := preload("res://core/balance.gd")


# 戻り値: [vx, vy, p](p は 0〜1 の強さ)。取り消しなら []。
static func pull_to_velocity(sx: float, sy: float, cx: float, cy: float) -> Array:
	var dx := sx - cx
	var dy := sy - cy
	var l := sqrt(dx * dx + dy * dy)
	if l < B.DEAD_ZONE:
		return []
	var p := clampf(l / B.PULL_MAX, B.P_MIN, 1.0)
	return [p * B.V_MAX * dx / l, p * B.V_MAX * dy / l, p]
