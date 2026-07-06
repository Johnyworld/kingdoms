extends Control
## 타이틀(메인) 메뉴. 시작 / 설정 / 종료 버튼을 제공한다.
## 게임플레이 씬과 설정 씬은 아직 없으므로 시작/설정은 임시 동작.

@onready var _start_button: Button = $Menu/StartButton
@onready var _settings_button: Button = $Menu/SettingsButton
@onready var _quit_button: Button = $Menu/QuitButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# 모바일에서는 종료 버튼을 숨긴다(iOS 정책 및 모바일 UX 관례).
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		_quit_button.hide()

	# 게임패드/키보드 기본 포커스
	_start_button.grab_focus()

func _on_start_pressed() -> void:
	# TODO: 게임플레이 씬이 준비되면 SceneManager.change_scene(...) 로 연결
	print("[Title] 시작 - 게임플레이 씬 준비 중")

func _on_settings_pressed() -> void:
	# TODO: 설정 화면 연결
	print("[Title] 설정 - 준비 중")

func _on_quit_pressed() -> void:
	get_tree().quit()
