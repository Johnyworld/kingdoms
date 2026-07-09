extends GutTest
## 부대 정보 패널 — 부대 클릭 시 우측 상단에 이름·이동력·시야·멤버를 표시.

var panel: CanvasLayer

func before_each() -> void:
	panel = load("res://scenes/party/party_info.gd").new()
	add_child_autofree(panel)

func _human(p_name: String, mv: int, vis: int) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new(p_name)
	h.movement = mv
	h.vision = vis
	return h

func _party(members: Array) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = "주인공 부대"
	for m in members:
		p.add_member(m)
	return p

func _sample_party() -> Node2D:
	return _party([_human("테스트맨", 3, 5), _human("짐꾼", 2, 5)])

func test_shows_party_name() -> void:
	panel.open(_sample_party())
	assert_eq(panel._title.text, "주인공 부대", "제목 라벨 = 부대 이름")

func test_shows_faction_name() -> void:
	var p := _sample_party()
	p.faction_name = "푸른 왕국"
	panel.open(p)
	assert_eq(panel._faction.text, "푸른 왕국", "세력 라벨 = 부대 세력명")
	assert_true(panel._faction.visible, "세력명이 있으면 세력 라벨 표시")

func test_hides_faction_when_empty() -> void:
	panel.open(_sample_party())  # faction_name 기본 ""
	assert_false(panel._faction.visible, "세력명이 비면 세력 라벨 숨김")

func test_summary_shows_movement_and_vision() -> void:
	panel.open(_sample_party())
	assert_eq(panel._summary.text, "이동력 2 · 시야 5", "요약 = 집계 이동력(min)·시야(max)")

func test_member_list_count() -> void:
	panel.open(_sample_party())
	assert_eq(panel._member_list.get_child_count(), 2, "멤버 리스트 자식 수 = 멤버 수")

func test_member_label_has_name_and_stats() -> void:
	panel.open(_sample_party())
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "테스트맨", "멤버 라벨에 이름 포함")
	assert_string_contains(text, "3", "멤버 라벨에 이동력 포함")
	assert_string_contains(text, "5", "멤버 라벨에 시야 포함")

func test_member_label_shows_equipment() -> void:
	var h := _human("전사", 3, 5)
	h.strength = 78
	h.weapons = ["sword"]                    # 공격력 14, AT = 14 + floor(78/5) = 29
	h.armor = ["leather_armor"]              # 방어력 8
	panel.open(_party([h]))
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "검", "장비 줄에 무기 이름 포함")
	assert_string_contains(text, "29", "장비 줄에 공격(AT) 포함")
	assert_string_contains(text, "8", "장비 줄에 방어(DF) 포함")

func test_member_label_shows_secondary_weapon() -> void:
	var h := _human("궁사겸용", 3, 5)
	h.weapons = ["sword", "bow"]             # 주무기 검 + 보조 활
	panel.open(_party([h]))
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "검", "주무기 이름 포함")
	assert_string_contains(text, "단궁", "보조무기(활) 이름도 표시")

func test_member_label_shows_barehand() -> void:
	panel.open(_party([_human("맨손이", 3, 5)]))   # weapon "" → 맨손
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "맨손", "무기 없으면 '맨손' 표시")

func test_member_label_shows_evasion() -> void:
	panel.open(_sample_party())
	assert_string_contains((panel._member_list.get_child(0) as Label).text, "회피", "전투 스탯 줄에 회피 표시")

func test_member_label_shows_armor_pieces() -> void:
	var h := _human("갑옷병", 3, 5)
	h.armor = ["leather_helm", "leather_armor"]
	panel.open(_party([h]))
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "방어구:", "방어구 줄 표시")
	assert_string_contains(text, "가죽 투구", "조각 이름 포함")
	assert_string_contains(text, "가죽 갑옷", "조각 이름 포함")

func test_member_label_no_armor_no_line() -> void:
	panel.open(_party([_human("맨몸이", 3, 5)]))   # armor []
	assert_false("방어구:" in (panel._member_list.get_child(0) as Label).text, "맨몸이면 방어구 줄 없음")

func test_member_label_shows_shield_block() -> void:
	var shielded := _human("방패병", 3, 5)
	shielded.shield = "tower_shield"   # 막기 40%
	panel.open(_party([shielded]))
	assert_string_contains((panel._member_list.get_child(0) as Label).text, "막기", "방패 들면 막기 표시")

func test_member_label_no_shield_no_block() -> void:
	panel.open(_party([_human("무방패", 3, 5)]))   # shield ""
	assert_false("막기" in (panel._member_list.get_child(0) as Label).text, "방패 없으면 막기 미표시")

func test_empty_party() -> void:
	panel.open(_party([]))
	assert_eq(panel._summary.text, "이동력 0 · 시야 0", "멤버 없으면 이동력·시야 0")
	assert_eq(panel._member_list.get_child_count(), 0, "멤버 리스트 비어 있음")

func test_reopen_replaces_members() -> void:
	panel.open(_sample_party())
	panel.open(_party([_human("혼자", 4, 6)]))
	assert_eq(panel._member_list.get_child_count(), 1, "재오픈 시 멤버 리스트 교체(1명)")

func test_open_shows_close_hides() -> void:
	panel.open(_sample_party())
	assert_true(panel.visible, "open 후 표시")
	panel.close()
	assert_false(panel.visible, "close 후 숨김")
