extends GutTest
## 장비 관리 모달(EquipMenu) — 공용 Modal 기반. 부대 노획 장비를 멤버에게 장착·탈착.
## 멤버 목록·장착 슬롯·인벤토리 갱신과 닫기 정리 검증. 데이터 API는 test_party 참조.

const EquipMenuScript = preload("res://scenes/equip/equip_menu.gd")

var menu

func before_each() -> void:
	# 싱글턴 모달 스택 격리.
	while ModalStack.top() != null:
		ModalStack.top().close()
	menu = EquipMenuScript.new()
	add_child_autofree(menu)

func after_each() -> void:
	if is_instance_valid(menu) and menu.is_open():
		menu.close()

func _human(p_name: String) -> Object:
	return load("res://scenes/human/human.gd").new(p_name)

func _party(member_names: Array, loot := []) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = "테스트부대"
	for n in member_names:
		p.add_member(_human(n))
	p.loot_items = loot.duplicate()
	return p

func test_open_shows_modal_and_title() -> void:
	menu.open(_party(["갑"]))
	assert_true(menu.is_open(), "open 후 모달 열림")
	assert_string_contains(menu._modal.title, "테스트부대", "제목에 부대명 포함")

func test_member_buttons_count() -> void:
	menu.open(_party(["갑", "을", "병"]))
	assert_eq(menu._member_list.get_child_count(), 3, "멤버 버튼 = 멤버 수")

func test_first_member_auto_selected() -> void:
	var p := _party(["갑", "을"])
	menu.open(p)
	assert_eq(menu._selected, p.members[0], "첫 멤버 자동 선택")
	assert_string_contains((menu._equipped_list.get_child(0) as Label).text, "무기", "장착 슬롯 라벨 표시")

func _equipped_text() -> String:
	# _equipped_list의 라벨 + 행(HBox 첫 자식 라벨) 텍스트를 모은다.
	# queue_free()는 프레임 끝에 반영되므로, 재렌더 직후엔 삭제 예정 노드를 건너뛴다.
	var parts: Array = []
	for c in menu._equipped_list.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Label:
			parts.append(c.text)
		elif c.get_child_count() > 0 and c.get_child(0) is Label:
			parts.append((c.get_child(0) as Label).text)
	return "\n".join(parts)

func test_select_other_member_rerenders_equipped() -> void:
	var p := _party(["갑", "을"])
	p.members[0].weapons = ["sword"]   # 검
	p.members[1].weapons = ["bow"]     # 단궁
	menu.open(p)
	assert_string_contains(_equipped_text(), "검", "첫 멤버 무기 표시")
	(menu._member_list.get_child(1) as Button).emit_signal("pressed")
	assert_eq(menu._selected, p.members[1], "다른 멤버 버튼 클릭 시 선택 이동")
	var t := _equipped_text()
	assert_string_contains(t, "단궁", "선택 멤버 무기로 장착 목록 갱신")
	assert_false("검" in t, "이전 멤버 무기는 사라짐")

func test_no_selection_when_empty_party_disables_equip() -> void:
	var p := _party([], ["sword"])
	menu.open(p)
	assert_null(menu._selected, "멤버 없으면 선택 없음")
	assert_false(menu._can_equip("sword"), "미선택이면 장착 불가")

func test_equip_from_inventory() -> void:
	var p := _party(["갑"], ["sword"])
	menu.open(p)
	menu._on_equip("sword")
	assert_true("sword" in p.members[0].weapons, "무기 슬롯에 장착")
	assert_false("sword" in p.loot_items, "인벤토리에서 제거")

func test_unequip_to_inventory() -> void:
	var p := _party(["갑"])
	p.members[0].weapons = ["sword"]
	menu.open(p)
	menu._on_unequip("sword")
	assert_true("sword" in p.loot_items, "탈착 시 인벤토리로 복귀")
	assert_false("sword" in p.members[0].weapons, "멤버 슬롯에서 제거")

func test_empty_inventory_placeholder() -> void:
	menu.open(_party(["갑"], []))
	var found := false
	for c in menu._inv_list.get_children():
		if c is Label and "(없음)" in c.text:
			found = true
	assert_true(found, "빈 인벤토리는 (없음) 표시")

func test_full_slot_disables_equip() -> void:
	var p := _party(["갑"], ["sword"])
	p.members[0].weapons = ["sword", "sword", "sword"]   # MAX_WEAPONS=3 꽉 참
	menu.open(p)
	assert_false(menu._can_equip("sword"), "슬롯이 꽉 차면 장착 불가")

func test_close_clears_party() -> void:
	var p := _party(["갑"])
	menu.open(p)
	menu.close()
	assert_false(menu.is_open(), "close 후 닫힘")
	assert_null(menu._party, "닫으면 부대 참조 정리")
