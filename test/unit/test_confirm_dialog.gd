extends GutTest
## 확인 다이얼로그(ConfirmDialog) — 범용 확인 모달. open(메시지) → [확인]/[취소] → 시그널.
## chrome은 공용 Modal에 위임 — 개폐는 is_open()(내부 Modal)으로 검증한다.

var dialog: CanvasLayer

func before_each() -> void:
	dialog = load("res://scenes/game/confirm_dialog.gd").new()
	add_child_autofree(dialog)

func test_hidden_at_start() -> void:
	assert_false(dialog.is_open(), "생성 직후 닫힘")

func test_open_shows_message() -> void:
	dialog.open("정말?")
	assert_true(dialog.is_open(), "open 후 열림(ModalStack 등록)")
	assert_eq(dialog._message.text, "정말?", "메시지 라벨에 텍스트")

func test_open_sets_confirm_label() -> void:
	dialog.open("철거할까요?", "철거")
	assert_eq(dialog._confirm_btn.text, "철거", "확인 버튼 라벨 = confirm_label")
	assert_eq(dialog._cancel_btn.text, "취소", "취소 버튼은 항상 취소")

func test_confirm_emits_and_closes() -> void:
	dialog.open("정말?")
	watch_signals(dialog)
	dialog._confirm_btn.pressed.emit()
	assert_signal_emitted(dialog, "confirmed", "확인 → confirmed 방출")
	assert_signal_not_emitted(dialog, "cancelled", "확인 경로는 cancelled 미방출(_confirming 가드)")
	assert_false(dialog.is_open(), "확인 후 닫힘")

func test_cancel_emits_and_closes() -> void:
	dialog.open("정말?")
	watch_signals(dialog)
	dialog._cancel_btn.pressed.emit()
	assert_signal_emitted(dialog, "cancelled", "취소 → cancelled 방출")
	assert_false(dialog.is_open(), "취소 후 닫힘")

func test_modal_close_routes_to_cancel() -> void:
	# X·배경 좌클릭·ESC는 전부 Modal.close()로 수렴 — 취소 경로여야 한다.
	_cb_hits = 0
	dialog.open("정말?", "확인", Callable(), _bump)
	watch_signals(dialog)
	dialog._modal.close()
	assert_signal_emitted(dialog, "cancelled", "Modal 닫힘(X·배경·ESC) → cancelled 방출")
	assert_eq(_cb_hits, 1, "on_cancel 콜백 1회 호출")

var _cb_hits := 0
func _bump() -> void:
	_cb_hits += 1

func test_confirm_calls_on_confirm_callback() -> void:
	_cb_hits = 0
	dialog.open("정말?", "확인", _bump)
	dialog._confirm_btn.pressed.emit()
	assert_eq(_cb_hits, 1, "확인 시 on_confirm 콜백 1회 호출")

func test_cancel_does_not_call_confirm_callback() -> void:
	_cb_hits = 0
	dialog.open("정말?", "확인", _bump)
	dialog._cancel_btn.pressed.emit()
	assert_eq(_cb_hits, 0, "취소 시 on_confirm 콜백 미호출")
