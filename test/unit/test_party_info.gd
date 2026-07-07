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
