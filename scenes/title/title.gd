extends Control
## 타이틀(메인) 메뉴. 시작 / 설정 / 종료 버튼을 제공한다.
## 게임플레이 씬과 설정 씬은 아직 없으므로 시작/설정은 임시 동작.

@onready var _new_game_button: Button = $NewGameButton
@onready var _start_button: Button = $Menu/StartButton
@onready var _settings_button: Button = $Menu/SettingsButton
@onready var _quit_button: Button = $Menu/QuitButton

func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# 모바일에서는 종료 버튼을 숨긴다(iOS 정책 및 모바일 UX 관례).
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		_quit_button.hide()

	# 게임패드/키보드 기본 포커스
	_new_game_button.grab_focus()

## 전투 테스트: 양 진영 병종·숫자·교전 방식을 고르는 설정 화면으로 진입.
func _on_new_game_pressed() -> void:
	SceneManager.change_scene("res://scenes/lang_setup/lang_setup.tscn")

func _on_start_pressed() -> void:
	SceneManager.change_scene("res://scenes/game/game.tscn")

func _on_settings_pressed() -> void:
	# TODO: 설정 화면 연결
	print("[Title] 설정 - 준비 중")

func _on_quit_pressed() -> void:
	get_tree().quit()
