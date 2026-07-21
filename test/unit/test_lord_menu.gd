extends GutTest
## 소속 모달(LordMenu) — 공용 Modal 기반. 일반부대의 소속 영웅부대 설정/해제. → party-lord.md
## 후보(인접 아군 영웅) 버튼 + [독립] 구성과 선택 시 set_lord/clear_lord·changed 방출 검증.

const LordMenuScript = preload("res://scenes/party/lord_menu.gd")
const PartyScript = preload("res://scenes/party/party.gd")

var menu

func before_each() -> void:
	while ModalStack.top() != null:
		ModalStack.top().close()
	menu = LordMenuScript.new()
	add_child_autofree(menu)

func after_each() -> void:
	if is_instance_valid(menu) and menu.is_open():
		menu.close()

func _hero(cmd_name: String) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.kind = p.KIND_HERO
	p.commander_name = cmd_name
	return p

func _troop() -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.kind = p.KIND_TROOP
	return p

func _buttons() -> Array:
	var out: Array = []
	for c in menu._list.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out

func _button(text: String) -> Button:
	for b in _buttons():
		if b.text == text:
			return b
	return null

func test_open_lists_candidates_and_independent() -> void:
	var t := _troop()
	menu.open(t, [_hero("아젤"), _hero("로엔")])
	assert_true(menu.is_open(), "open 후 모달 열림")
	assert_not_null(_button("아젤"), "후보 영웅 버튼 아젤")
	assert_not_null(_button("로엔"), "후보 영웅 버튼 로엔")
	assert_not_null(_button("독립"), "[독립] 버튼")

func test_pick_sets_lord_and_emits() -> void:
	var t := _troop()
	var h := _hero("아젤")
	watch_signals(menu)
	menu.open(t, [h])
	menu._on_pick(h)
	assert_eq(t.lord, h, "후보 클릭 시 소속 지정")
	assert_signal_emitted(menu, "changed", "changed 방출")

func test_current_lord_button_disabled() -> void:
	var t := _troop()
	var hA := _hero("아젤")
	var hB := _hero("로엔")
	t.set_lord(hA)
	menu.open(t, [hA, hB])
	assert_true(_button("아젤").disabled, "이미 소속인 영웅 버튼 비활성")
	assert_false(_button("로엔").disabled, "다른 영웅 버튼 활성")
	assert_false(_button("독립").disabled, "소속 보유 시 [독립] 활성")

func test_independent_clears_and_emits() -> void:
	var t := _troop()
	var h := _hero("아젤")
	t.set_lord(h)
	watch_signals(menu)
	menu.open(t, [h])
	menu._on_independent()
	assert_null(t.lord, "[독립]으로 소속 해제")
	assert_signal_emitted(menu, "changed", "changed 방출")

func test_independent_disabled_when_no_lord() -> void:
	var t := _troop()
	menu.open(t, [_hero("아젤")])
	assert_true(_button("독립").disabled, "소속 없으면 [독립] 비활성")

func test_empty_candidates_only_independent() -> void:
	var t := _troop()
	t.set_lord(_hero("아젤"))
	menu.open(t, [])
	assert_eq(_button("아젤"), null, "후보 버튼 없음")
	assert_not_null(_button("독립"), "[독립]은 있음")
	assert_false(_button("독립").disabled, "소속 보유 → [독립] 활성")

func test_close_clears_troop() -> void:
	var t := _troop()
	menu.open(t, [_hero("아젤")])
	menu.close()
	assert_false(menu.is_open(), "close 후 닫힘")
	assert_null(menu._troop, "닫으면 부대 참조 정리")
