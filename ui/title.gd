# タイトル画面。Phase 0 では日本語の題名と版だけを出す。
# 文言は core/strings.gd、版は project.godot の application/config/version から読む。
extends Control

const Strings := preload("res://core/strings.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	box.add_child(_label(Strings.TITLE, 96))
	box.add_child(_label(Strings.SUBTITLE, 48))
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	box.add_child(_label(Strings.VERSION_PREFIX + version, 28))


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l
