# 保存の読み書き(§9.8・E-10・E-11)。
# 読めない・壊れている・version が違うときは既定値で始め、書けなくてもエラーで止めない。
# 置き場: Web はブラウザの localStorage(このゲームだけのキー)、それ以外は user://save.json。
# Web で user:// を使わないのは、user:// の実体(IndexedDB の /userfs)が同じサイトの Godot のゲーム全部で 1 つだからで、
# どれかのタブが書くと、そのタブが起動した時の写しで全体を書き戻す(別のタブ・別のゲームの新しい保存が古い物に戻る・消える)。
# 同じゲームを 2 つのタブで開いた時は、最後に書いた方が勝つ(書く前に読み直して合わせることはしない)。
extends RefCounted

const PATH := "user://save.json"
const KEEP_DAYS := 7
const WEB_KEY := "sling-arc/save"
# 使えない時(保存を止めたブラウザなど)は投げずに null / false を返す
const JS_READ := "(() => { try { return localStorage.getItem('%s'); } catch (e) { return null; } })()" % WEB_KEY
const JS_WRITE := "(() => { try { localStorage.setItem('%s', %%s); return true; } catch (e) { return false; } })()" % WEB_KEY

var path: String
var data: Dictionary = {}
var _web := OS.has_feature("web")


func _init(p_path: String = PATH) -> void:
	path = p_path
	load_data()


static func defaults() -> Dictionary:
	return {"version": 1, "tutorial_done": false, "sound_on": true, "daily": {}}


func load_data() -> void:
	data = defaults()
	var text: Variant = _read_text()
	if text == null:
		return
	var j := JSON.new()
	var v = j.data if j.parse(text) == OK else null
	if typeof(v) != TYPE_DICTIONARY or v.get("version") != 1.0:
		return
	data["tutorial_done"] = v.get("tutorial_done") == true
	data["sound_on"] = v.get("sound_on") != false
	var daily = v.get("daily")
	if typeof(daily) == TYPE_DICTIONARY:
		for k in daily:
			var e = daily[k]
			if typeof(e) == TYPE_DICTIONARY:
				data["daily"][str(k)] = {
					"course_id": int(e.get("course_id", 0)), "attempts": int(e.get("attempts", 0)),
					"first_total": int(e.get("first_total", 0)), "first_holes": _int_array(e.get("first_holes", [])),
				}


# 保存の文字。無ければ null。
func _read_text() -> Variant:
	if _web:
		var v: Variant = JavaScriptBridge.eval(JS_READ, true)
		if v is String:
			return v
		# まだ localStorage に無い。v0.1.0 の保存(user://save.json)があれば、それを読む(次に書く時に localStorage へ移る)
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func save_data() -> bool:
	var text := JSON.stringify(data, "", false)
	if _web:
		var ok: Variant = JavaScriptBridge.eval(JS_WRITE % JSON.stringify(text), true)
		return ok is bool and ok
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func tutorial_done() -> bool:
	return data["tutorial_done"]


func mark_tutorial_done() -> void:
	data["tutorial_done"] = true
	save_data()


func sound_on() -> bool:
	return data["sound_on"]


func set_sound_on(on: bool) -> void:
	data["sound_on"] = on
	save_data()


func attempts(date_str: String) -> int:
	var e = data["daily"].get(date_str)
	return 0 if e == null else int(e["attempts"])


# 日替わりを 5 ホール終えたときに呼ぶ。初回の結果だけを first_* に残す。
func record_daily(date_str: String, course_id: int, total: int, holes: Array) -> void:
	var daily: Dictionary = data["daily"]
	if not daily.has(date_str):
		daily[date_str] = {"course_id": course_id, "attempts": 0, "first_total": total, "first_holes": _int_array(holes)}
	daily[date_str]["attempts"] = int(daily[date_str]["attempts"]) + 1
	var keys := daily.keys()
	keys.sort()
	while keys.size() > KEEP_DAYS:
		daily.erase(keys.pop_front())
	save_data()


static func _int_array(v) -> Array:
	var out: Array = []
	if typeof(v) == TYPE_ARRAY:
		for e in v:
			out.append(int(e))
	return out
