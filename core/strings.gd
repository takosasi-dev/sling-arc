# 画面に出す文言をまとめる(INV-5)。文言はこのファイルにだけ置く。
# 同梱フォントがここの全文字を持つことを tests/run_tests.gd で確かめる。
extends RefCounted

const GAME_NAME := "SlingArc"
const TITLE := "SlingArc"
const SUBTITLE := "重力スリングショット"
const VERSION_PREFIX := "v"

# タイトル
const BTN_DAILY := "今日のコース"
const BTN_RANDOM := "ランダム"
const SOUND_ON := "音 入"
const SOUND_OFF := "音 切"
const COURSE_PREFIX := "コース"
const TODAY_IS := "今日は"
const DATA_ERROR := "コースのデータを読めませんでした"
const DAILY_DONE := "今日の初回 %d打"

# プレイ
const TUTORIAL_TAG := "練習"
const SKIP := "スキップ"
const HINT_PULL := "引っ張って、離す"
const HUD_HOLE := "ホール"
const HUD_SHOTS := "このホール"
const HUD_TOTAL := "合計"
const SHOTS_FMT := "%d打"
const PANEL_GOAL := "%d 打"
const PANEL_ACE := "一発で入った"
const PANEL_GIVEUP := "ここまで"
const PANEL_NEXT := "タップで次へ"
const MISS_CRASH := "衝突"
const MISS_OUT := "場外"
const MISS_TIMEOUT := "時間切れ"
const FAST_HINT := "押し続けると早送り"

# 結果
const RESULT_TITLE := "コース完了"
const RESULT_DAILY := "今日のコース"
const RESULT_RANDOM := "ランダム"
const BTN_COPY := "結果をコピー"
const COPY_TRIED := "コピーを試しました。貼れないときは下の文字を選んでコピーしてください"
const BTN_RETRY := "もう一度"
const BTN_TITLE := "タイトルへ"

# 共有テキスト(§9.9)
const SHARE_FIRST := "初回"
const SHARE_NTH := "%d回目"
const SHARE_RANDOM := "ランダム"
const SHARE_TOTAL := "合計 %d打 [%s]"
