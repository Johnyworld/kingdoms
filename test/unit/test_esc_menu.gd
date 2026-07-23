extends GutTest
## ESC(시스템) 메뉴(EscMenu) — 취소할 게 없을 때 ESC로 열리는 시스템 메뉴.
## chrome은 공용 Modal에 위임 — 개폐는 is_open()(내부 Modal)으로 검증한다. → docs/spec/features/esc-menu.md

var menu: CanvasLayer

func before_each() -> void:
	menu = load("res://scenes/game/esc_menu.gd").new()
	add_child_autofree(menu)

## 메뉴 트리에서 라벨이 일치하는 버튼을 재귀로 찾는다(없으면 null). Modal 내부 구조에 의존하지 않는다.
func _button(label: String) -> Button:
	return _find_button(menu, label)

func _find_button(node: Node, label: String) -> Button:
	for c in node.get_children():
		if c is Button and c.text == label:
			return c
		var found := _find_button(c, label)
		if found != null:
			return found
	return null

func test_hidden_at_start() -> void:
	assert_false(menu.is_open(), "생성 직후 닫힘")

func test_open_shows() -> void:
	menu.open()
	assert_true(menu.is_open(), "open 후 열림(ModalStack 등록)")

func test_resume_closes_without_signal() -> void:
	menu.open()
	watch_signals(menu)
	_button("계속하기").pressed.emit()
	assert_false(menu.is_open(), "계속하기 → 닫힘")
	assert_signal_not_emitted(menu, "action_selected", "계속하기는 action_selected 미방출")

func test_title_emits_action() -> void:
	menu.open()
	watch_signals(menu)
	_button("타이틀로").pressed.emit()
	assert_signal_emitted_with_parameters(menu, "action_selected", ["title"], "타이틀로 → action_selected(\"title\")")

func test_quit_emits_action() -> void:
	# 데스크톱(테스트 환경)에서는 종료 버튼이 존재한다.
	menu.open()
	watch_signals(menu)
	_button("게임 종료").pressed.emit()
	assert_signal_emitted_with_parameters(menu, "action_selected", ["quit"], "게임 종료 → action_selected(\"quit\")")

func test_deferred_buttons_disabled() -> void:
	assert_true(_button("게임 저장").disabled, "게임 저장 비활성(미구현)")
	assert_true(_button("게임 불러오기").disabled, "게임 불러오기 비활성(미구현)")
	assert_true(_button("설정").disabled, "설정 비활성(미구현)")
