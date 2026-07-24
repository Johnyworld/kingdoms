extends GutTest
## 부대 일람(Party Roster) — 우측 상단 상시 목록. 부대당 버튼 한 줄(이름·지휘관·병력).
## 항목 클릭 시 party_selected 시그널로 그 부대를 실어 방출한다(카메라 이동은 game.gd 담당).

var roster: CanvasLayer

func before_each() -> void:
	roster = load("res://scenes/party/party_roster.gd").new()
	add_child_autofree(roster)

func _party(p_name: String, soldiers: int, cmdr := "", kind := Party.KIND_HERO) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = p_name
	p.soldiers = soldiers
	p.commander_name = cmdr
	p.kind = kind   # 일람은 영웅부대만 표시 → 기본 헬퍼는 영웅부대로 생성
	return p

func _sample_party() -> Node2D:
	return _party("주인공 부대", 2, "테스트맨")

func test_lists_one_party() -> void:
	roster.set_parties([_sample_party()])
	assert_eq(roster._list.get_child_count(), 1, "부대 리스트 자식 수 = 부대 수")

func test_button_has_name_commander_and_count() -> void:
	roster.set_parties([_sample_party()])
	var text: String = (roster._list.get_child(0) as Button).text
	assert_string_contains(text, "주인공 부대", "버튼에 부대 이름 포함")
	assert_string_contains(text, "테스트맨", "버튼에 지휘관 이름 포함")
	assert_string_contains(text, "2", "버튼에 병력수 포함")

func test_set_parties_replaces_list() -> void:
	roster.set_parties([_sample_party(), _party("2부대", 2, "갑")])
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
	# 병력 0(전멸)인 부대는 일람에서 제외한다.
	roster.set_parties([_sample_party(), _party("빈 부대", 0)])
	assert_eq(roster._list.get_child_count(), 1, "병력 0 부대는 일람에서 제외")

func test_troop_party_not_listed() -> void:
	# 일반부대(하위·거점 방어)는 영웅부대가 아니므로 일람에서 제외한다.
	roster.set_parties([_sample_party(), _party("경보병", 10, "경보병", Party.KIND_TROOP)])
	assert_eq(roster._list.get_child_count(), 1, "일반부대는 일람에서 제외(영웅부대만)")
