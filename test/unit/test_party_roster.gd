extends GutTest
## 부대 일람(Party Roster) — 우측 상단 상시 목록. 부대당 버튼 한 줄(이름·지휘관·인원).
## 항목 클릭 시 party_selected 시그널로 그 부대를 실어 방출한다(카메라 이동은 game.gd 담당).

var roster: CanvasLayer

func before_each() -> void:
	roster = load("res://scenes/party/party_roster.gd").new()
	add_child_autofree(roster)

func _human(p_name: String) -> Object:
	return load("res://scenes/human/human.gd").new(p_name)

func _party(p_name: String, member_names: Array, commander_name := "") -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = p_name
	for n in member_names:
		var h := _human(n)
		p.add_member(h)
		if n == commander_name:
			p.commander = h
	return p

func _sample_party() -> Node2D:
	return _party("주인공 부대", ["테스트맨", "짐꾼"], "테스트맨")

func test_lists_one_party() -> void:
	roster.set_parties([_sample_party()])
	assert_eq(roster._list.get_child_count(), 1, "부대 리스트 자식 수 = 부대 수")

func test_button_has_name_commander_and_count() -> void:
	roster.set_parties([_sample_party()])
	var text: String = (roster._list.get_child(0) as Button).text
	assert_string_contains(text, "주인공 부대", "버튼에 부대 이름 포함")
	assert_string_contains(text, "테스트맨", "버튼에 지휘관 이름 포함")
	assert_string_contains(text, "2", "버튼에 인원 수 포함")

func test_member_party_shows_auto_commander() -> void:
	# 멤버가 있으면 add_member가 지휘관을 자동 지정하므로, 일람에 뜨는 부대는 항상 지휘관 이름을 보인다.
	# (지휘관 없는 부대 = 멤버 0명이라 일람에서 제외됨 → "—"는 일람에 뜨지 않는다.)
	roster.set_parties([_party("무명 부대", ["병사"])])
	var text: String = (roster._list.get_child(0) as Button).text
	assert_string_contains(text, "병사", "멤버 있는 부대는 자동 지정 지휘관 이름 표시")

func test_set_parties_replaces_list() -> void:
	roster.set_parties([_sample_party(), _party("2부대", ["갑", "을"])])
	roster.set_parties([_sample_party()])
	assert_eq(roster._list.get_child_count(), 1, "재구성 시 리스트 교체(1개)")

func test_button_press_emits_party_selected() -> void:
	var p := _sample_party()
	roster.set_parties([p])
	watch_signals(roster)
	(roster._list.get_child(0) as Button).emit_signal("pressed")
	assert_signal_emitted_with_parameters(roster, "party_selected", [p], "클릭 시 그 부대를 실어 방출")

func test_visible_by_default() -> void:
	roster.set_parties([_sample_party()])
	assert_true(roster.visible, "기본은 표시 상태")

func test_empty_party_not_listed() -> void:
	# 수비대로 전부 옮겨 0명이 된 부대는 일람에서 제외한다.
	var empty := _party("빈 부대", [])
	roster.set_parties([_sample_party(), empty])
	assert_eq(roster._list.get_child_count(), 1, "멤버 0명 부대는 일람에서 제외")
