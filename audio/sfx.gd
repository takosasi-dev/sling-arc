# 効果音の再生(FR-18)。assets/sfx/*.wav を読み、enabled が偽なら鳴らさない。
# ファイルが読めないときは音なしで続ける(E-16)。
extends Node

const NAMES := ["launch", "crash", "goal", "complete"]

var enabled := true
var _players := {}


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -4.0
		add_child(p)
		_players[n] = p


func play(sound_name: String) -> void:
	if enabled and _players.has(sound_name):
		_players[sound_name].play()
