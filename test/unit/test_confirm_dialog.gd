extends GutTest
## 확인 다이얼로그(ConfirmDialog) — 범용 확인 모달. open(메시지) → [확인]/[취소] → 시그널.

var dialog: CanvasLayer

func before_each() -> void:
	dialog = load("res://scenes/game/confirm_dialog.gd").new()
	add_child_autofree(dialog)

func test_hidden_at_start() -> void:
	assert_false(dialog.visible, "생성 직후 숨김")

func test_open_shows_message() -> void:
	dialog.open("정말?")
	assert_true(dialog.visible, "open 후 표시")
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
	assert_false(dialog.visible, "확인 후 닫힘")

func test_cancel_emits_and_closes() -> void:
	dialog.open("정말?")
	watch_signals(dialog)
	dialog._cancel_btn.pressed.emit()
	assert_signal_emitted(dialog, "cancelled", "취소 → cancelled 방출")
	assert_false(dialog.visible, "취소 후 닫힘")

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
