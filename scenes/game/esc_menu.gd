class_name EscMenu
extends CanvasLayer
## ESC(시스템) 메뉴. 취소할 게 없을 때 ESC로 열리는 일시정지 성격의 메뉴([ESC 메뉴](../../docs/spec/features/esc-menu.md)).
## chrome(딤 배경·제목 바·X·ESC·지도 입력 차단)은 공용 Modal에 위임하고, 콘텐츠(버튼 세로 목록)만 주입한다.
## [계속하기]·X·배경 좌클릭·ESC는 모두 그냥 닫힘(= 계속하기)으로 수렴한다. → docs/spec/features/modal.md

## [타이틀로]("title")·[게임 종료]("quit") 선택 시 방출. 호출부가 확인 다이얼로그를 거쳐 실제 동작을 실행한다.
signal action_selected(id: String)

const ModalScript = preload("res://scenes/modal/modal.gd")

var _modal: Modal

func _ready() -> void:
	_build()

## UI 트리를 코드로 구성한다. chrome은 Modal, 콘텐츠는 버튼 세로 목록.
func _build() -> void:
	_modal = ModalScript.new()
	_modal.title = "메뉴"
	add_child(_modal)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(240, 0)

	_add_button(box, "계속하기", func() -> void: _modal.close())
	# 저장·불러오기·설정은 시스템 미구현 — 자리표시 버튼(비활성). 구현 시 disabled 해제 + 배선.
	_add_button(box, "게임 저장", Callable(), true)
	_add_button(box, "게임 불러오기", Callable(), true)
	_add_button(box, "설정", Callable(), true)
	_add_button(box, "타이틀로", func() -> void: action_selected.emit("title"))
	var quit_btn := _add_button(box, "게임 종료", func() -> void: action_selected.emit("quit"))
	# 모바일에서는 종료 버튼을 숨긴다(iOS 정책 및 모바일 UX 관례). → title.gd
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		quit_btn.hide()

	_modal.set_content(box)

## 버튼 하나를 만들어 box에 추가하고 반환한다. on_pressed가 유효하면 연결, disabled면 비활성.
func _add_button(box: VBoxContainer, label: String, on_pressed := Callable(), disabled := false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = disabled
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	box.add_child(btn)
	return btn

## 메뉴를 연다(Modal에 위임).
func open() -> void:
	_modal.open()

## 메뉴를 닫는다(Modal에 위임).
func close() -> void:
	_modal.close()

## 메뉴가 열려 있는지.
func is_open() -> bool:
	return _modal.is_open()
