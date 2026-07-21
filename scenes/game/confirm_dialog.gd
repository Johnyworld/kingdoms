class_name ConfirmDialog
extends CanvasLayer
## 확인 다이얼로그. 되돌리기 어려운 동작 전에 사용자에게 확인받는 범용 모달([Confirm Dialog](../../docs/spec/features/confirm-dialog.md)).
## chrome(딤 배경·제목 바·X·ESC·지도 입력 차단)은 공용 Modal에 위임하고, 콘텐츠(메시지 + 버튼)만 주입한다.
## 다른 Modal(캠프 메뉴 등) 위에서 열려도 ModalStack 깊이로 항상 맨 위에 그려진다. → docs/spec/features/modal.md
## [취소]·X·배경 좌클릭·ESC는 모두 취소 경로(cancelled)로 수렴한다.

## 확인 시 방출. 호출부가 실제 동작을 실행한다.
signal confirmed
## 취소([취소]·X·배경·ESC) 시 방출. 호출부가 대기 상태를 정리한다.
signal cancelled

const ModalScript = preload("res://scenes/modal/modal.gd")

var _modal: Modal
var _message: Label
var _confirm_btn: Button
var _cancel_btn: Button
var _on_confirm_cb: Callable = Callable()   # 확인 시 호출(open이 지정). 호출부별 동작을 이걸로 넘겨 재사용 안전.
var _on_cancel_cb: Callable = Callable()     # 취소 시 호출(선택).
var _confirming := false   # [확인] 처리 중 가드 — Modal.closed를 취소로 라우팅하지 않도록.

func _ready() -> void:
	_build()

## UI 트리를 코드로 구성한다. chrome은 Modal, 콘텐츠는 메시지 + 버튼 행.
func _build() -> void:
	_modal = ModalScript.new()
	_modal.title = "확인"
	_modal.closed.connect(_on_modal_closed)
	add_child(_modal)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(300, 0)
	box.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)

	_confirm_btn = Button.new()
	_confirm_btn.text = "확인"
	_confirm_btn.pressed.connect(_on_confirm)
	buttons.add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "취소"
	_cancel_btn.pressed.connect(func() -> void: _modal.close())   # 취소 = Modal 닫힘 → _on_modal_closed
	buttons.add_child(_cancel_btn)

	_modal.set_content(box)

## 메시지를 채우고 모달을 연다. 확인 버튼 라벨은 confirm_label(취소는 항상 "취소").
## on_confirm/on_cancel을 넘기면 그 동작을 확인/취소 시 호출한다(호출부별 라우팅 — 영구 시그널 연결 없이 재사용 안전).
## 이미 열려 있으면 내용·콜백만 마지막 호출로 갱신된다(한 번에 하나).
func open(message: String, confirm_label := "확인", on_confirm := Callable(), on_cancel := Callable()) -> void:
	_message.text = message
	_confirm_btn.text = confirm_label
	_on_confirm_cb = on_confirm
	_on_cancel_cb = on_cancel
	_modal.open()

## 다이얼로그가 열려 있는지.
func is_open() -> bool:
	return _modal.is_open()

## [확인]: Modal을 닫되(_confirming 가드로 취소 라우팅 차단) 확인 경로로 마무리한다.
func _on_confirm() -> void:
	if not _modal.is_open():
		return
	_confirming = true
	_modal.close()
	_confirming = false
	var cb := _on_confirm_cb
	_clear_callbacks()
	confirmed.emit()
	if cb.is_valid():
		cb.call()

## Modal이 닫히면([취소]·X·배경 좌클릭·ESC 모두 수렴) 취소 경로. [확인] 처리 중이면 무시.
func _on_modal_closed() -> void:
	if _confirming:
		return
	var cb := _on_cancel_cb
	_clear_callbacks()
	cancelled.emit()
	if cb.is_valid():
		cb.call()

## 콜백을 비운다(닫힌 뒤 1회만 호출 — 다음 open까지 남지 않음).
func _clear_callbacks() -> void:
	_on_confirm_cb = Callable()
	_on_cancel_cb = Callable()
