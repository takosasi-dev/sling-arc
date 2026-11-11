# 調整値をまとめる(§9.7・INV-10)。数値はここだけに置く。
# 物理の値を変えたら courses.json を作り直し、GEN を上げ、§9.3 の固定値を計算し直す。
extends RefCounted

# --- 物理の値(courses.json の physics と一致しないと起動時にエラー) ---
const DT_DEN := 120
const DT := 1.0 / 120.0
const SURFACE_G := 6000.0
const V_MAX := 900.0
const PROBE_R := 8.0
const GOAL_R := 34.0
const OUT_MARGIN := 200.0
const MAX_STEPS := 1440

# --- 盤面 ---
const FIELD_W := 720.0
const FIELD_H := 1280.0
const PAD_X := 360.0
const PAD_Y := 1130.0

# --- 飛行の進め方(INV-3) ---
const MAX_FRAME_DELTA := 0.1
const MAX_STEPS_PER_FRAME := 48

# --- 調整してよい値(§8.3 で決め直す) ---
const PULL_MAX := 300.0
const P_MIN := 0.15
const DEAD_ZONE := 24.0
const PREVIEW_STEPS := 60
const MAX_SHOTS := 9
const GIVEUP_SCORE := 10
const FAST_FORWARD := 4.0
const PANEL_GUARD_SEC := 0.5
const N_COURSES := 100
const SHARE_URL := "https://takosasi-dev.github.io/sling-arc/"

# --- コース ---
const GEN := "SA1"
const HOLES_PER_COURSE := 5
const PLANETS_PER_HOLE := [1, 2, 2, 3, 3]
const EPOCH_DAYS := 20454  # 2026-01-01 の 1970-01-01 からの通し日数

# 練習の 2 ホール(§9.5)。courses.json には入れない。
const TUTORIAL_HOLES := [
	{"goal": [360, 300], "planets": []},
	{"goal": [360, 260], "planets": [[360, 700, 60]]},
]


static func physics_dict() -> Dictionary:
	return {
		"surface_g": int(SURFACE_G), "v_max": int(V_MAX), "probe_r": int(PROBE_R),
		"goal_r": int(GOAL_R), "out_margin": int(OUT_MARGIN), "max_steps": MAX_STEPS,
		"dt_den": DT_DEN,
	}
