extends Control
## 스플래시 화면: 로고를 페이드 인 → 유지 → 페이드 아웃 후 타이틀로 전환.
## 아무 입력이나 들어오면 즉시 스킵한다.

const TITLE_SCENE := "res://scenes/title/title.tscn"

@onready var _logo: Control = $Logo

var _done := false

func _ready() -> void:
	_logo.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, 0.6)  # 페이드 인
	tween.tween_interval(1.0)                              # 유지
	tween.tween_property(_logo, "modulate:a", 0.0, 0.6)   # 페이드 아웃
	tween.tween_callback(_go_to_title)

func _unhandled_input(event: InputEvent) -> void:
	# 키/마우스/터치 등 실제 눌림에 대해서만 스킵
	if event.is_pressed() and not event.is_echo():
		_go_to_title()

func _go_to_title() -> void:
	if _done:
		return
	_done = true
	SceneManager.change_scene(TITLE_SCENE)
