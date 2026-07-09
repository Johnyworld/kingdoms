extends GutTest
## 부대(Party) 테스트 — 멤버 보유 · 이동력(min)·시야(max) 집계 · 턴당 1이동 상태.
## 맵에서 실제로 움직이는 유닛은 부대이며, 이동력은 가장 느린 멤버를 따라간다.

func _party() -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	return p

func _human(mv := 3, vis := 5) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.movement = mv
	h.vision = vis
	return h

func _named_human(p_name: String) -> Object:
	return load("res://scenes/human/human.gd").new(p_name)

# --- 이름 ---

func test_party_name_defaults_empty() -> void:
	assert_eq(_party().party_name, "", "기본 이름은 빈 문자열")

func test_party_name_settable() -> void:
	var p := _party()
	p.party_name = "주인공 부대"
	assert_eq(p.party_name, "주인공 부대", "이름을 설정할 수 있다")

# --- 소속 세력 ---

func test_faction_name_defaults_empty() -> void:
	assert_eq(_party().faction_name, "", "기본 세력명은 빈 문자열")

func test_faction_name_settable() -> void:
	var p := _party()
	p.faction_name = "푸른 왕국"
	assert_eq(p.faction_name, "푸른 왕국", "세력명을 설정할 수 있다")

# --- 토큰 색 ---

func test_token_color_default_gold() -> void:
	assert_eq(_party().token_color, Color(0.92, 0.78, 0.35), "기본 토큰 색은 금색")

func test_token_color_settable() -> void:
	var p := _party()
	p.token_color = Color(1, 0, 0)
	assert_eq(p.token_color, Color(1, 0, 0), "토큰 색을 설정할 수 있다")

# --- 멤버 ---

func test_members_empty_at_start() -> void:
	var p := _party()
	assert_eq(p.members.size(), 0, "생성 직후 멤버 없음")
	assert_eq(p.movement(), 0, "멤버 없으면 이동력 0")
	assert_eq(p.vision(), 0, "멤버 없으면 시야 0")

func test_add_member() -> void:
	var p := _party()
	p.add_member(_human())
	assert_eq(p.members.size(), 1, "멤버 추가됨")

func test_add_member_no_duplicate() -> void:
	var p := _party()
	var h := _human()
	p.add_member(h)
	p.add_member(h)
	assert_eq(p.members.size(), 1, "같은 멤버 중복 추가 방지")

# --- 지휘관(commander) ---

func test_commander_null_by_default() -> void:
	var p := _party()
	assert_null(p.commander, "생성 직후 지휘관 없음(null)")
	assert_eq(p.commander_name(), "—", "지휘관 없으면 이름은 대시")

func test_commander_name_from_member() -> void:
	var p := _party()
	var leader := _named_human("테스트맨")
	p.add_member(leader)
	p.commander = leader
	assert_eq(p.commander_name(), "테스트맨", "지휘관 이름 = 지정한 멤버의 human_name")

# --- 이동력(min) · 시야(max) 집계 ---

func test_movement_is_min_of_members() -> void:
	var p := _party()
	p.add_member(_human(3, 5))
	p.add_member(_human(2, 5))
	assert_eq(p.movement(), 2, "이동력은 멤버 중 최소값(가장 느린 멤버)")

func test_vision_is_max_of_members() -> void:
	var p := _party()
	p.add_member(_human(3, 5))
	p.add_member(_human(2, 2))
	assert_eq(p.vision(), 5, "시야는 멤버 중 최대값")

# --- 턴당 1이동 상태 ---

func test_can_move_by_default() -> void:
	var p := _party()
	assert_false(p.moved_this_turn, "생성 직후 이동 안 함")
	assert_true(p.can_move(), "생성 직후 이동 가능")

func test_mark_moved_blocks_move() -> void:
	var p := _party()
	p.mark_moved()
	assert_true(p.moved_this_turn, "mark_moved 후 이동함 표시")
	assert_false(p.can_move(), "이동한 부대는 이동 불가")

func test_reset_turn_restores_move() -> void:
	var p := _party()
	p.mark_moved()
	p.reset_turn()
	assert_false(p.moved_this_turn, "reset_turn 후 이동 안 함으로 리셋")
	assert_true(p.can_move(), "reset_turn 후 다시 이동 가능")

# --- 공격 상태 (이동 1 + 공격 1) ---

func test_attack_defaults() -> void:
	var p := _party()
	assert_false(p.attacked_this_turn, "생성 직후 공격 안 함")
	assert_true(p.can_attack(), "생성 직후 공격 가능")

func test_moved_still_can_attack() -> void:
	var p := _party()
	p.mark_moved()
	assert_false(p.can_move(), "이동 후 재이동 불가")
	assert_true(p.can_attack(), "이동해도 공격은 아직 가능")

func test_attacked_ends_actions() -> void:
	var p := _party()
	p.mark_attacked()
	assert_false(p.can_attack(), "공격 후 재공격 불가")
	assert_false(p.can_move(), "공격이 이동도 끝냄")

func test_reset_turn_restores_attack() -> void:
	var p := _party()
	p.mark_moved()
	p.mark_attacked()
	p.reset_turn()
	assert_true(p.can_move(), "reset 후 이동 가능")
	assert_true(p.can_attack(), "reset 후 공격 가능")

func test_end_turn_resets_party() -> void:
	var tm: Object = load("res://scenes/turn/turn_manager.gd").new()
	var p := _party()
	p.mark_moved()
	tm.end_turn([p], [])
	assert_false(p.moved_this_turn, "턴 종료 시 부대 이동 상태 리셋")
