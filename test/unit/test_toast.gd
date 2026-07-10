extends GutTest
## 알림(Toast) — 상단 중앙 메시지. show_message로 텍스트를 채우고 표시한다.

var toast: CanvasLayer

func before_each() -> void:
	toast = load("res://scenes/game/toast.gd").new()
	add_child_autofree(toast)

func test_hidden_at_start() -> void:
	assert_false(toast.visible, "생성 직후 숨김")

func test_show_message_sets_text_and_shows() -> void:
	toast.show_message("창천성 함락!")
	assert_eq(toast._label.text, "창천성 함락!", "메시지 텍스트 표시")
	assert_true(toast.visible, "show_message 후 표시")

func test_show_message_replaces_text() -> void:
	toast.show_message("알사바흐 점령!")
	toast.show_message("흑요요새 파괴!")
	assert_eq(toast._label.text, "흑요요새 파괴!", "새 메시지로 교체")
