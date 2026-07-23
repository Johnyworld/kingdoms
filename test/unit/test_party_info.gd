extends GutTest
## 부대 정보 패널 — 부대 클릭 시 우측 상단에 이름·이동력·시야·지휘관·병력을 표시(순수 class+count).

var panel: CanvasLayer

func before_each() -> void:
	panel = load("res://scenes/party/party_info.gd").new()
	add_child_autofree(panel)

func _party(soldiers := 2, cmdr := "경보병") -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = "주인공 부대"
	p.kind = p.KIND_TROOP
	p.troop_type = "light_infantry"   # 이동력·시야는 클래스 기반 → unit_types.gd
	p.soldiers = soldiers
	p.commander_name = cmdr
	return p

func test_shows_party_name() -> void:
	panel.open(_party())
	assert_eq(panel._title.text, "주인공 부대", "제목 라벨 = 부대 이름")

func test_shows_faction_name() -> void:
	var p := _party()
	p.faction_name = "푸른 왕국"
	panel.open(p)
	assert_eq(panel._faction.text, "푸른 왕국", "세력 라벨 = 부대 세력명")
	assert_true(panel._faction.visible, "세력명이 있으면 세력 라벨 표시")

func test_hides_faction_when_empty() -> void:
	panel.open(_party())  # faction_name 기본 ""
	assert_false(panel._faction.visible, "세력명이 비면 세력 라벨 숨김")

func test_summary_shows_movement_and_vision() -> void:
	panel.open(_party())
	var expected := "이동력 %d · 시야 %d · 사거리 근접" % [UnitTypes.movement("light_infantry"), UnitTypes.vision("light_infantry")]
	assert_eq(panel._summary.text, expected, "요약 = 클래스 이동력·시야·사거리(근접)")

func test_shows_commander_and_soldiers() -> void:
	panel.open(_party(7, "경보병"))
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "경보병", "지휘관 이름 표시")
	assert_string_contains(text, "7", "병력수 표시")

func test_summary_class_based_regardless_of_soldiers() -> void:
	# 스탯은 클래스 기반이라 병력수와 무관(병력 0이어도 클래스 이동력·시야).
	panel.open(_party(0))
	var expected := "이동력 %d · 시야 %d · 사거리 근접" % [UnitTypes.movement("light_infantry"), UnitTypes.vision("light_infantry")]
	assert_eq(panel._summary.text, expected, "스탯은 클래스 기반(병력 없어도 클래스값)")

func test_reopen_replaces_line() -> void:
	panel.open(_party(5, "경보병"))
	panel.open(_party(3, "경궁병"))
	assert_eq(panel._member_list.get_child_count(), 1, "재오픈 시 한 줄로 교체")
	assert_string_contains((panel._member_list.get_child(0) as Label).text, "경궁병", "새 부대 정보로 교체")

func test_open_shows_close_hides() -> void:
	panel.open(_party())
	assert_true(panel.visible, "open 후 표시")
	panel.close()
	assert_false(panel.visible, "close 후 숨김")

# --- 행동 버튼 줄 (open의 actions) → party-lord.md · party-action-menu.md ---

func test_actions_hidden_by_default() -> void:
	panel.open(_party())   # actions 기본 []
	assert_false(panel._actions.visible, "actions 없으면 행동 버튼 줄 숨김")

func test_action_button_shown_and_emits() -> void:
	watch_signals(panel)
	panel.open(_party(), [{"id": "lord", "label": "소속"}])
	assert_true(panel._actions.visible, "actions 있으면 버튼 줄 표시")
	assert_eq(panel._actions.get_child_count(), 1, "버튼 1개")
	var btn := panel._actions.get_child(0) as Button
	assert_eq(btn.text, "소속", "버튼 라벨 = 소속")
	btn.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "action_selected", ["lord"])

func test_reopen_clears_actions() -> void:
	panel.open(_party(), [{"id": "lord", "label": "소속"}])
	panel.open(_party())   # actions 없이 재오픈
	assert_false(panel._actions.visible, "재오픈(빈 actions) 시 버튼 줄 숨김")
	assert_eq(panel._actions.get_child_count(), 0, "이전 버튼 제거")

# --- 지휘 토글 인라인 (영웅부대, show_command) → squad-stance.md ---

func _hero(cmdr := "아젤") -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = "영웅 부대"
	p.kind = p.KIND_HERO
	p.commander_name = cmdr
	return p

func test_command_hidden_by_default() -> void:
	panel.open(_hero())   # show_command 기본 false
	assert_false(panel._command_box.visible, "show_command 없으면 지휘 토글 숨김")

func test_command_hidden_for_troop() -> void:
	panel.open(_party(), [], true)   # 일반부대는 show_command=true여도 숨김
	assert_false(panel._command_box.visible, "일반부대는 지휘 토글 숨김")

func test_command_shows_toggles() -> void:
	panel.open(_hero(), [], true)
	assert_true(panel._command_box.visible, "영웅+show_command면 지휘 토글 표시")
	assert_not_null(panel._follow_btn, "[따라옴] 버튼")
	assert_not_null(panel._direct_btn, "[직접명령] 버튼")
	assert_not_null(panel._engage_btn, "[전투우선] 버튼")
	assert_not_null(panel._avoid_btn, "[전투회피] 버튼")

func test_command_current_side_highlighted() -> void:
	panel.open(_hero(), [], true)   # 기본 직접명령·전투회피
	# 선택된 쪽은 밝게(불투명 1.0), 반대쪽은 흐리게(<1.0). disabled로 표시하지 않는다.
	assert_eq(panel._direct_btn.modulate.a, 1.0, "현재=직접명령 → [직접명령] 밝게(선택 표시)")
	assert_lt(panel._follow_btn.modulate.a, 1.0, "[따라옴]은 흐리게")
	assert_eq(panel._avoid_btn.modulate.a, 1.0, "현재=전투회피 → [전투회피] 밝게")
	assert_lt(panel._engage_btn.modulate.a, 1.0, "[전투우선]은 흐리게")
	assert_false(panel._direct_btn.disabled, "선택 표시는 밝기로 — 버튼은 비활성이 아니다")

func test_command_reflects_current_values() -> void:
	var h := _hero()
	h.command_follow = true
	h.command_engage = true
	panel.open(h, [], true)
	assert_eq(panel._follow_btn.modulate.a, 1.0, "현재=따라옴 → [따라옴] 밝게")
	assert_lt(panel._direct_btn.modulate.a, 1.0, "[직접명령]은 흐리게")
	assert_eq(panel._engage_btn.modulate.a, 1.0, "현재=전투우선 → [전투우선] 밝게")
	assert_lt(panel._avoid_btn.modulate.a, 1.0, "[전투회피]는 흐리게")

func test_follow_button_emits() -> void:
	watch_signals(panel)
	panel.open(_hero(), [], true)
	panel._follow_btn.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "command_changed", ["follow", true])

func test_direct_button_emits() -> void:
	watch_signals(panel)
	panel.open(_hero(), [], true)
	panel._direct_btn.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "command_changed", ["follow", false])

func test_engage_button_emits() -> void:
	watch_signals(panel)
	panel.open(_hero(), [], true)
	panel._engage_btn.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "command_changed", ["engage", true])

func test_avoid_button_emits() -> void:
	watch_signals(panel)
	panel.open(_hero(), [], true)
	panel._avoid_btn.pressed.emit()
	assert_signal_emitted_with_parameters(panel, "command_changed", ["engage", false])
