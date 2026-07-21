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

# --- 병종(월드맵 아이콘 판별) ---

func test_is_ranged_true_for_archer_archetype() -> void:
	assert_true(_troop("light_archer").is_ranged(), "경궁병 아키타입 → 원거리 병종(클래스 기반)")

func test_is_ranged_false_for_melee_archetype() -> void:
	assert_false(_troop("light_infantry").is_ranged(), "경보병 아키타입 → 근접 병종")

func test_is_ranged_empty_party_defaults_false() -> void:
	assert_false(_party().is_ranged(), "아키타입 없는 부대는 근접(기본)")

func test_troop_type_defaults_empty() -> void:
	assert_eq(_party().troop_type, "", "생성 직후 병종은 빈 문자열")

func test_troop_type_settable() -> void:
	var p := _party()
	p.troop_type = "light_infantry"
	assert_eq(p.troop_type, "light_infantry", "병종을 설정할 수 있다")

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

func test_add_member_auto_commander() -> void:
	# 빈 부대에 첫 멤버 추가 시 지휘관 자동 지정(새 부대 편성으로 수비대 병사를 채울 때 필요).
	var p := _party()
	var a := _human()
	var b := _human()
	p.add_member(a)
	assert_eq(p.commander, a, "첫 멤버가 지휘관이 됨")
	p.add_member(b)
	assert_eq(p.commander, a, "이후 멤버 추가는 지휘관을 바꾸지 않음")

# --- 멤버 제거 (수비대 편성) ---

func test_remove_member() -> void:
	var p := _party()
	var h := _human()
	p.add_member(h)
	p.remove_member(h)
	assert_false(h in p.members, "제거 후 members에서 빠짐")

func test_remove_commander_reassigns() -> void:
	var p := _party()
	var a := _human()
	var b := _human()
	p.add_member(a)
	p.add_member(b)
	p.commander = a
	p.remove_member(a)
	assert_eq(p.commander, b, "지휘관 제거 시 남은 첫 멤버로 재지정")

func test_remove_last_member_commander_null() -> void:
	var p := _party()
	var h := _human()
	p.add_member(h)
	p.commander = h
	p.remove_member(h)
	assert_null(p.commander, "마지막 멤버 제거 시 지휘관 null")

func test_remove_member_not_present_noop() -> void:
	var p := _party()
	p.add_member(_human())
	p.remove_member(_human())   # 없는 멤버
	assert_eq(p.members.size(), 1, "없는 멤버 제거는 no-op")

# --- 병합 (merge_from) ---

func test_merge_from_combines() -> void:
	var a := _party()
	var b := _party()
	var a1 := _human()
	a.add_member(a1)
	b.add_member(_human())
	b.add_member(_human())
	a.merge_from(b)
	assert_eq(a.members.size(), 3, "a에 b 멤버가 합쳐짐(1+2)")
	assert_eq(b.members.size(), 0, "b는 빈 부대가 됨")
	assert_eq(a.commander, a1, "a 지휘관은 유지")

func test_merge_from_empty_noop() -> void:
	var a := _party()
	a.add_member(_human())
	a.merge_from(_party())   # 빈 부대 병합
	assert_eq(a.members.size(), 1, "빈 부대 병합은 변화 없음")

# --- 병합 가능 판정 (can_merge_with) ---

func _troop(archetype: String, count := 1) -> Node2D:
	# 지정 병종·인원의 일반부대. 같은/다른 병종·인원 상한 병합 판정용.
	var p := _party()
	p.kind = p.KIND_TROOP
	p.troop_type = archetype
	for i in count:
		p.add_member(_human())
	return p

func test_can_merge_same_troop_type() -> void:
	var a := _troop("light_infantry")
	var b := _troop("light_infantry")
	assert_true(a.can_merge_with(b), "같은 병종 일반부대끼리 → 병합 가능")

func test_cannot_merge_different_troop_type() -> void:
	var a := _troop("light_infantry")
	var b := _troop("light_archer")
	assert_false(a.can_merge_with(b), "다른 병종끼리 → 병합 불가")

func test_cannot_merge_when_self_is_hero() -> void:
	var a := _troop("light_infantry")
	a.kind = a.KIND_HERO
	var b := _troop("light_infantry")
	assert_false(a.can_merge_with(b), "자신이 영웅부대면 → 병합 불가(병종 같아도)")

func test_cannot_merge_when_other_is_hero() -> void:
	var a := _troop("light_infantry")
	var b := _troop("light_infantry")
	b.kind = b.KIND_HERO
	assert_false(a.can_merge_with(b), "상대가 영웅부대면 → 병합 불가(병종 같아도)")

func test_can_merge_within_capacity() -> void:
	var a := _troop("light_infantry", 4)
	var b := _troop("light_infantry", 6)
	assert_true(a.can_merge_with(b), "합계 4+6=10(상한 이하) → 병합 가능")

func test_can_merge_exactly_capacity() -> void:
	var a := _troop("light_infantry", 5)
	var b := _troop("light_infantry", 5)
	assert_true(a.can_merge_with(b), "합계 5+5=10(상한) → 병합 가능")

func test_cannot_merge_over_capacity() -> void:
	var a := _troop("light_infantry", 6)
	var b := _troop("light_infantry", 5)
	assert_false(a.can_merge_with(b), "합계 6+5=11(상한 초과) → 병합 불가")

func test_cannot_merge_with_null() -> void:
	assert_false(_troop("light_infantry").can_merge_with(null), "null 대상 → 병합 불가")

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

# --- 종류(kind) · 소속(lord) ---

func test_kind_defaults_troop() -> void:
	var p := _party()
	assert_eq(p.kind, p.KIND_TROOP, "생성 직후 kind = 일반부대(troop)")
	assert_false(p.is_hero(), "기본은 영웅부대 아님")

func test_kind_hero_settable() -> void:
	var p := _party()
	p.kind = p.KIND_HERO
	assert_true(p.is_hero(), "kind=hero면 is_hero() 참")

func test_lord_null_by_default() -> void:
	var p := _party()
	assert_null(p.lord, "생성 직후 소속 없음(null)")
	assert_false(p.has_lord(), "has_lord() 거짓")
	assert_eq(p.lord_name(), "—", "소속 없으면 대시")

func test_lord_name_from_hero() -> void:
	var troop := _party()
	var hero := _party()
	hero.kind = hero.KIND_HERO
	hero.add_member(_named_human("아젤"))
	troop.lord = hero
	assert_true(troop.has_lord(), "소속 지정 시 has_lord() 참")
	assert_eq(troop.lord_name(), "아젤", "소속 영웅 이름")

func test_lord_name_empty_hero_is_dash() -> void:
	var troop := _party()
	var hero := _party()   # 지휘관 없는 빈 부대
	troop.lord = hero
	assert_true(troop.has_lord(), "참조는 있음")
	assert_eq(troop.lord_name(), "—", "지휘관 없는 소속 → 대시")

func test_set_and_clear_lord() -> void:
	var troop := _party()
	var hero := _party()
	troop.set_lord(hero)
	assert_eq(troop.lord, hero, "set_lord로 소속 지정")
	assert_true(troop.has_lord(), "소속 보유")
	troop.clear_lord()
	assert_null(troop.lord, "clear_lord로 독립")
	assert_false(troop.has_lord(), "소속 없음")

# --- 인원수 배지 표시 여부(shows_member_count) ---

func test_shows_member_count_troop_with_members() -> void:
	var p := _party()
	p.kind = p.KIND_TROOP
	p.add_member(_human())
	assert_true(p.shows_member_count(), "멤버 있는 일반부대는 인원수 배지 표시")

func test_shows_member_count_hero_hidden() -> void:
	var p := _party()
	p.kind = p.KIND_HERO
	p.add_member(_human())
	assert_false(p.shows_member_count(), "영웅부대는 항상 1명이라 배지 생략")

func test_shows_member_count_empty_hidden() -> void:
	var p := _party()
	p.kind = p.KIND_TROOP
	assert_false(p.shows_member_count(), "멤버 없는 부대는 배지 없음(토큰도 안 그림)")

# --- 하이라이트(highlight) — NPC 공격 연출용 토큰 테두리 ---

func test_highlight_none_by_default() -> void:
	assert_eq(_party().highlight.a, 0.0, "생성 직후 하이라이트 없음(알파 0)")

func test_set_highlight() -> void:
	var p := _party()
	p.set_highlight(Color.RED)
	assert_eq(p.highlight, Color.RED, "set_highlight로 강조색 설정")
	p.set_highlight(Color(0, 0, 0, 0))
	assert_eq(p.highlight.a, 0.0, "알파 0으로 해제 가능")

# --- 지휘 범위(command_range) · 지휘 버프(command_buffed) ---

func test_command_range_from_class() -> void:
	# 지휘범위는 클래스 기반(lang cmd_range) — 영웅(클래스4)=4, 경보병(클래스1)=3. → game_units.gd
	var hero := _party()
	hero.kind = hero.KIND_HERO
	assert_eq(hero.command_range(), GameUnits.command_range("hero"), "영웅 지휘범위 = 클래스4 cmd_range(4)")
	assert_eq(_troop("light_infantry").command_range(), GameUnits.command_range("light_infantry"), "경보병 지휘범위 = 클래스1 cmd_range(3)")

func test_command_range_no_archetype() -> void:
	assert_eq(_party().command_range(), 0, "아키타입 없으면 0")

func test_command_buffed_false_by_default() -> void:
	assert_false(_party().command_buffed, "생성 직후 지휘 버프 없음")

# --- 이동력 · 시야 · 공격거리 (클래스 기반) → game_units.gd ---

func test_movement_from_class() -> void:
	var p := _troop("light_infantry")
	assert_eq(p.movement(), GameUnits.movement("light_infantry"), "이동력 = 클래스 mv(6)")
	assert_gt(p.movement(), 0, "유효 아키타입이면 이동력 > 0")

func test_movement_zero_without_archetype() -> void:
	assert_eq(_party().movement(), 0, "아키타입 없으면 이동력 0(클래스 0)")

func test_vision_from_class() -> void:
	assert_eq(_troop("light_infantry").vision(), GameUnits.vision("light_infantry"), "시야 = 클래스 카탈로그 시야")

func test_attack_range_ranged_vs_melee() -> void:
	assert_eq(_troop("light_archer").attack_range(), GameUnits.attack_range("light_archer"), "경궁병 공격거리 = 3(원거리)")
	assert_eq(_troop("light_infantry").attack_range(), 0, "경보병 공격거리 0(근접)")

func test_attack_range_empty_zero() -> void:
	assert_eq(_party().attack_range(), 0, "아키타입 없으면 공격거리 0")

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

# --- 휴식/대기 (행동 메뉴) ---

func test_can_rest_by_default() -> void:
	assert_true(_party().can_rest(), "생성 직후 휴식 가능")

func test_undo_move_restores_move() -> void:
	var p := _party()
	p.mark_moved()
	assert_false(p.can_move(), "이동 후 이동 불가")
	p.undo_move()
	assert_false(p.moved_this_turn, "undo_move 후 이동 안 함으로")
	assert_true(p.can_move(), "undo_move 후 다시 이동 가능")

func test_attacked_blocks_rest() -> void:
	var p := _party()
	p.mark_attacked()
	assert_false(p.can_rest(), "공격까지 마치면 휴식 불가")

func test_reset_turn_restores_rest() -> void:
	var p := _party()
	p.mark_attacked()
	p.reset_turn()
	assert_true(p.can_rest(), "reset 후 다시 행동 가능")

func test_end_turn_resets_party() -> void:
	var tm: Object = load("res://scenes/turn/turn_manager.gd").new()
	var p := _party()
	p.mark_moved()
	tm.end_turn([p], [])
	assert_false(p.moved_this_turn, "턴 종료 시 부대 이동 상태 리셋")

# --- 근·원거리 파워(교전 선호) → docs/spec/features/npc-movement.md ---

func test_melee_power_infantry() -> void:
	# 클래스 기반: 근접 병종 파워 = 클래스 AT × 병력수, 원거리 파워 0. → game_units.gd
	var p := _troop("light_infantry", 2)
	assert_eq(p.melee_power(), GameUnits.base_at("light_infantry") * 2, "경보병 근접 파워 = AT × 병력")
	assert_eq(p.ranged_power(), 0, "경보병 원거리 파워 0")

func test_ranged_power_archer() -> void:
	var p := _troop("light_archer", 3)
	assert_eq(p.ranged_power(), GameUnits.base_at("light_archer") * 3, "경궁병 원거리 파워 = AT × 병력")
	assert_eq(p.melee_power(), 0, "경궁병 근접 파워 0")

func test_power_no_archetype_zero() -> void:
	var p := _party()
	assert_eq(p.melee_power(), 0, "아키타입 없으면 근접 0")
	assert_eq(p.ranged_power(), 0, "아키타입 없으면 원거리 0")
