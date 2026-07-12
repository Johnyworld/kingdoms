class_name ConfirmDialog
extends CanvasLayer
## 확인 다이얼로그. 되돌리기 어려운 동작 전에 사용자에게 확인받는 범용 모달([Confirm Dialog](../../docs/spec/features/confirm-dialog.md)).
## 화면 중앙에 메시지 + [확인]/[취소]. UI는 코드로 구성한다(result_overlay·loot_menu와 같은 패턴, 별도 .tscn 없음).

## 확인 시 방출. 호출부가 실제 동작을 실행한다.
signal confirmed
## 취소/배경 클릭 시 방출. 호출부가 대기 상태를 정리한다.
signal cancelled

var _root: Control
var _message: Label
var _confirm_btn: Button
var _cancel_btn: Button
var _on_confirm_cb: Callable = Callable()   # 확인 시 호출(open이 지정). 호출부별 동작을 이걸로 넘겨 재사용 안전.
var _on_cancel_cb: Callable = Callable()     # 취소 시 호출(선택).

func _ready() -> void:
	layer = 80   # 다른 패널(캠프 메뉴 64·행동 메뉴 50)보다 위.
	_build()
	hide()

## UI 트리를 코드로 구성한다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 반투명 배경 — 클릭하면 취소.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

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
	_cancel_btn.pressed.connect(_on_cancel)
	buttons.add_child(_cancel_btn)

## 메시지를 채우고 모달을 연다. 확인 버튼 라벨은 confirm_label(취소는 항상 "취소").
## on_confirm/on_cancel을 넘기면 그 동작을 확인/취소 시 호출한다(호출부별 라우팅 — 영구 시그널 연결 없이 재사용 안전).
func open(message: String, confirm_label := "확인", on_confirm := Callable(), on_cancel := Callable()) -> void:
	_message.text = message
	_confirm_btn.text = confirm_label
	_on_confirm_cb = on_confirm
	_on_cancel_cb = on_cancel
	show()

func _on_confirm() -> void:
	if not visible:
		return
	hide()
	var cb := _on_confirm_cb
	_on_confirm_cb = Callable()
	_on_cancel_cb = Callable()
	confirmed.emit()
	if cb.is_valid():
		cb.call()

func _on_cancel() -> void:
	if not visible:
		return
	hide()
	var cb := _on_cancel_cb
	_on_confirm_cb = Callable()
	_on_cancel_cb = Callable()
	cancelled.emit()
	if cb.is_valid():
		cb.call()

## 배경 좌클릭 → 취소.
func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel()
