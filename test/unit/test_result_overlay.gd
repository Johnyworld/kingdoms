extends GutTest
## 결과 화면(ResultOverlay) 테스트 — 코드로 구성한 CanvasLayer 오버레이.
## 제목·부제 표시, 생성 직후 숨김, dismiss 시 dismissed 시그널 방출.

var overlay: CanvasLayer

func before_each() -> void:
	overlay = load("res://scenes/result/result_overlay.gd").new()
	add_child_autofree(overlay)

func test_hidden_at_start() -> void:
	assert_false(overlay.visible, "생성 직후 숨김")

func test_show_result_fills_labels_and_shows() -> void:
	overlay.show_result("패배", "아젤 하르윈 부대가 전멸했다")
	assert_eq(overlay._title.text, "패배", "제목 라벨 = 패배")
	assert_eq(overlay._subtitle.text, "아젤 하르윈 부대가 전멸했다", "부제 라벨 채워짐")
	assert_true(overlay.visible, "show_result 후 표시")

func test_dismiss_emits_signal() -> void:
	watch_signals(overlay)
	overlay.show_result("패배", "…")
	overlay.dismiss()
	assert_signal_emitted(overlay, "dismissed", "dismiss() → dismissed 방출")
