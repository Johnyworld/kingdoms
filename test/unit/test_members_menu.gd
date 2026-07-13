extends GutTest
## 구성원 메뉴(MembersMenu) — 좌측 하단 버튼 + 우리 세력 전 군인 명단 오버레이 + 상세 패널.
## 명단 표는 MemberList 위젯 재사용. 세력 멤버 수집은 정적 헬퍼로 분리(테스트 대상).

var menu   # MembersMenu (extends CanvasLayer)

func before_each() -> void:
	menu = MembersMenu.new()
	add_child_autofree(menu)

func _human(p_name: String) -> Object:
	return load("res://scenes/human/human.gd").new(p_name)

func _party(p_faction: String, member_names: Array) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.faction_name = p_faction
	for n in member_names:
		p.add_member(_human(n))
	return p

# --- 세력 멤버 수집(정적 헬퍼) ---

func test_collect_only_matching_faction() -> void:
	var mine := _party("푸른", ["갑", "을"])
	var enemy := _party("붉은", ["적1"])
	var out: Array = MembersMenu.collect_faction_members([mine, enemy], "푸른")
	var names := []
	for h in out:
		names.append(h.human_name)
	assert_eq(names, ["갑", "을"], "일치 세력 부대의 members만 수집")

func test_collect_merges_multiple_parties() -> void:
	var p1 := _party("푸른", ["갑"])
	var p2 := _party("푸른", ["을", "병"])
	var out: Array = MembersMenu.collect_faction_members([p1, p2], "푸른")
	assert_eq(out.size(), 3, "같은 세력 부대 2개 → members 합집합")

func test_collect_dedupes() -> void:
	var shared := _human("공유")
	var p1: Node2D = load("res://scenes/party/party.gd").new()
	var p2: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p1)
	add_child_autofree(p2)
	p1.faction_name = "푸른"
	p2.faction_name = "푸른"
	p1.add_member(shared)
	p2.members.append(shared)   # 동일 Human을 두 부대에 (중복 상황 강제)
	var out: Array = MembersMenu.collect_faction_members([p1, p2], "푸른")
	assert_eq(out.size(), 1, "동일 Human 중복 제거")

# --- 오버레이 ---

func test_open_populates_list() -> void:
	menu.open([_human("갑"), _human("을")])
	var root = menu._list.get_root()
	assert_eq(root.get_child_count(), 2, "명단 행 수 = 멤버 수")

func test_open_hides_button_close_shows_it() -> void:
	menu.open([_human("갑")])
	assert_false(menu._open_button.visible, "오버레이 열리면 좌측 하단 버튼 숨김")
	menu.close()
	assert_true(menu._open_button.visible, "닫으면 버튼 다시 표시")

func test_button_emits_open_requested() -> void:
	watch_signals(menu)
	menu._open_button.emit_signal("pressed")
	assert_signal_emitted(menu, "open_requested", "버튼 누르면 open_requested 방출")

func test_open_auto_selects_first_and_shows_detail() -> void:
	menu.open([_human("첫째"), _human("둘째")])
	assert_eq(menu._list.selected_member().human_name, "첫째", "첫 행 자동 선택")
	assert_string_contains(menu._detail_text(), "첫째", "상세 패널에 선택 군인 이름 표시")

func test_is_open_reflects_overlay() -> void:
	assert_false(menu.is_open(), "기본은 닫힘")
	menu.open([_human("갑")])
	assert_true(menu.is_open(), "open 후 열림")
	menu.close()
	assert_false(menu.is_open(), "close 후 닫힘")

func _mouse_button(button_index: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	ev.pressed = true
	return ev

func test_background_left_click_closes() -> void:
	menu.open([_human("갑")])
	menu._on_bg_input(_mouse_button(MOUSE_BUTTON_LEFT))
	assert_false(menu.is_open(), "배경 좌클릭 시 닫힘")

func test_background_right_click_and_wheel_ignored() -> void:
	menu.open([_human("갑")])
	menu._on_bg_input(_mouse_button(MOUSE_BUTTON_RIGHT))
	assert_true(menu.is_open(), "우클릭은 무시")
	menu._on_bg_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP))
	assert_true(menu.is_open(), "휠은 무시")

func test_open_empty_shows_placeholder() -> void:
	menu.open([])
	var root = menu._list.get_root()
	assert_eq(0 if root == null else root.get_child_count(), 0, "빈 명단은 행 0")
	assert_eq(menu._list.selected_member(), null, "선택 없음")
