extends GutTest
## 공용 모달 기반(Modal) + 모달 스택(ModalStack).
## 딤 백드롭 + 제목바 + 우측 상단 X, 콘텐츠 주입(컴포지션). 스택으로 지도 입력 차단·ESC·중첩 관리.

const ModalScript = preload("res://scenes/modal/modal.gd")

var modal   # Modal

func before_each() -> void:
	# 싱글턴 스택 격리 — 이전 테스트에서 남은 모달 정리.
	while ModalStack.top() != null:
		ModalStack.top().close()
	modal = ModalScript.new()
	add_child_autofree(modal)

func after_each() -> void:
	if is_instance_valid(modal) and modal.is_open():
		modal.close()

func _content() -> Control:
	return Control.new()

func _new_modal() -> Node:
	var m = ModalScript.new()
	add_child_autofree(m)
	return m

func _mouse(button_index: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	ev.pressed = true
	return ev

func _escape() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	return ev

# --- set_content ---

func test_set_content_injects() -> void:
	var c := _content()
	modal.set_content(c)
	assert_eq(modal._content_area.get_child_count(), 1, "콘텐츠 영역 자식 1개")
	assert_eq(modal._content_area.get_child(0), c, "주입한 콘텐츠")

func test_set_content_replaces() -> void:
	modal.set_content(_content())
	var c2 := _content()
	modal.set_content(c2)
	assert_eq(modal._content_area.get_child_count(), 1, "재호출 시 교체")
	assert_eq(modal._content_area.get_child(0), c2, "새 콘텐츠로 교체됨")

# --- open / close ---

func test_open_sets_state_and_blocks() -> void:
	watch_signals(modal)
	modal.open()
	assert_true(modal.is_open(), "open 후 열림")
	assert_true(ModalStack.blocking(), "스택이 지도 입력 차단")
	assert_signal_emitted(modal, "opened", "opened 방출")

func test_close_clears_state() -> void:
	modal.open()
	watch_signals(modal)
	modal.close()
	assert_false(modal.is_open(), "close 후 닫힘")
	assert_false(ModalStack.blocking(), "스택 비면 차단 해제")
	assert_signal_emitted(modal, "closed", "closed 방출")

func test_title_reflected() -> void:
	modal.title = "제목X"
	modal.open()
	assert_eq(modal._title_label.text, "제목X", "제목 바에 반영")

# --- 닫기 입력 ---

func test_x_button_closes_even_if_not_dismissible() -> void:
	modal.dismissible = false
	modal.open()
	modal._close_button.emit_signal("pressed")
	assert_false(modal.is_open(), "X 버튼은 dismissible과 무관하게 닫음")

func test_bg_left_click_closes_when_dismissible() -> void:
	modal.open()   # dismissible 기본 true
	modal._on_bg_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_false(modal.is_open(), "배경 좌클릭 닫힘")

func test_bg_right_and_wheel_ignored() -> void:
	modal.open()
	modal._on_bg_input(_mouse(MOUSE_BUTTON_RIGHT))
	assert_true(modal.is_open(), "우클릭 무시")
	modal._on_bg_input(_mouse(MOUSE_BUTTON_WHEEL_UP))
	assert_true(modal.is_open(), "휠 무시")

func test_bg_click_ignored_when_not_dismissible() -> void:
	modal.dismissible = false
	modal.open()
	modal._on_bg_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_true(modal.is_open(), "강제 모달은 배경 클릭으로 안 닫힘")

# --- ESC + 스택 ---

func test_esc_closes_top_dismissible() -> void:
	modal.open()
	modal._unhandled_key_input(_escape())
	assert_false(modal.is_open(), "최상단 dismissible 모달은 ESC로 닫힘")

func test_esc_ignored_when_not_top() -> void:
	modal.open()
	var upper := _new_modal()
	upper.open()   # upper가 최상단
	modal._unhandled_key_input(_escape())
	assert_true(modal.is_open(), "최상단 아니면 ESC 무시")
	upper.close()

func test_stack_depth_and_top() -> void:
	modal.open()
	var m2 := _new_modal()
	m2.open()
	assert_eq(ModalStack.depth(), 2, "열린 모달 2개")
	assert_eq(ModalStack.top(), m2, "top은 나중에 연 것")
	m2.close()
	assert_eq(ModalStack.top(), modal, "pop 후 top 갱신")
	assert_eq(ModalStack.depth(), 1, "depth 1")
