extends GutTest
## 부대(Party) 테스트 — 순수 class+count 모델(soldiers·commander_name) · 이동력·시야·공격거리(클래스 기반) · 턴당 1이동.
## 개별 병사(Human)는 없다 — 부대는 아키타입 + 병력수(soldiers)로 표현된다.

func _party() -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	return p

func _troop(archetype: String, count := 1) -> Node2D:
	# 지정 병종·병력의 일반부대. 병합·파워 판정용.
	var p := _party()
	p.kind = p.KIND_TROOP
	p.troop_type = archetype
	p.soldiers = count
	return p

# --- 이름 ---

func test_party_name_defaults_empty() -> void:
	assert_eq(_party().party_name, "", "기본 이름은 빈 문자열")

func test_party_name_settable() -> void:
	var p := _party()
	p.party_name = "주인공 부대"
	assert_eq(p.party_name, "주인공 부대", "이름을 설정할 수 있다")

# --- 맵 토큰 스프라이트 필터(픽셀 선명) ---

func test_sprite_uses_nearest_filter() -> void:
	# 축소 렌더 시 Linear면 흐릿 → NEAREST로 픽셀 선명(전투 화면과 동일). → Party.md 맵 토큰 외형
	var p := _party()
	assert_eq(p._sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
		"맵 토큰 스프라이트는 NEAREST 필터(흐릿함 방지)")

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

# --- 병력(soldiers) ---

func test_soldiers_zero_at_start() -> void:
	var p := _party()
	assert_eq(p.soldiers, 0, "생성 직후 병력 0")

func test_soldiers_settable() -> void:
	var p := _troop("light_infantry", 10)
	assert_eq(p.soldiers, 10, "병력수 설정 가능")

# --- 병합 (merge_from) ---

func test_merge_from_combines() -> void:
	var a := _troop("light_infantry", 1)
	a.commander_name = "A대"
	var b := _troop("light_infantry", 2)
	a.merge_from(b)
	assert_eq(a.soldiers, 3, "a에 b 병력이 합쳐짐(1+2)")
	assert_eq(b.soldiers, 0, "b는 병력 0이 됨")
	assert_eq(a.commander_name, "A대", "a 지휘관 이름은 유지")

func test_merge_from_empty_noop() -> void:
	var a := _troop("light_infantry", 1)
	a.merge_from(_troop("light_infantry", 0))   # 빈 부대 병합
	assert_eq(a.soldiers, 1, "빈 부대 병합은 변화 없음")

# --- 병합 가능 판정 (can_merge_with) ---

func test_can_merge_same_troop_type() -> void:
	assert_true(_troop("light_infantry").can_merge_with(_troop("light_infantry")), "같은 병종 일반부대끼리 → 병합 가능")

func test_cannot_merge_different_troop_type() -> void:
	assert_false(_troop("light_infantry").can_merge_with(_troop("light_archer")), "다른 병종끼리 → 병합 불가")

func test_cannot_merge_when_self_is_hero() -> void:
	var a := _troop("light_infantry")
	a.kind = a.KIND_HERO
	assert_false(a.can_merge_with(_troop("light_infantry")), "자신이 영웅부대면 → 병합 불가")

func test_cannot_merge_when_other_is_hero() -> void:
	var b := _troop("light_infantry")
	b.kind = b.KIND_HERO
	assert_false(_troop("light_infantry").can_merge_with(b), "상대가 영웅부대면 → 병합 불가")

func test_can_merge_within_capacity() -> void:
	assert_true(_troop("light_infantry", 4).can_merge_with(_troop("light_infantry", 6)), "합계 4+6=10(상한 이하) → 병합 가능")

func test_can_merge_exactly_capacity() -> void:
	assert_true(_troop("light_infantry", 5).can_merge_with(_troop("light_infantry", 5)), "합계 5+5=10(상한) → 병합 가능")

func test_cannot_merge_over_capacity() -> void:
	assert_false(_troop("light_infantry", 6).can_merge_with(_troop("light_infantry", 5)), "합계 6+5=11(상한 초과) → 병합 불가")

func test_cannot_merge_with_null() -> void:
	assert_false(_troop("light_infantry").can_merge_with(null), "null 대상 → 병합 불가")

# --- 지휘관 이름(commander_name) ---

func test_commander_name_empty_by_default() -> void:
	assert_eq(_party().commander_name, "", "생성 직후 지휘관 이름 빈 문자열")

func test_commander_name_settable() -> void:
	var p := _party()
	p.commander_name = "테스트맨"
	assert_eq(p.commander_name, "테스트맨", "지휘관 이름 설정 가능")

# --- 전투 파워(power) ---

func test_power_equals_soldiers() -> void:
	assert_eq(_troop("light_infantry", 7).power(), 7, "전투 파워 = 병력수")

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
	hero.commander_name = "아젤"
	troop.lord = hero
	assert_true(troop.has_lord(), "소속 지정 시 has_lord() 참")
	assert_eq(troop.lord_name(), "아젤", "소속 영웅 이름")

func test_set_and_clear_lord() -> void:
	var troop := _party()
	var hero := _party()
	troop.set_lord(hero)
	assert_eq(troop.lord, hero, "set_lord로 소속 지정")
	assert_true(troop.has_lord(), "소속 보유")
	troop.clear_lord()
	assert_null(troop.lord, "clear_lord로 독립")
	assert_false(troop.has_lord(), "소속 없음")

# --- 병력수 배지 표시 여부(shows_member_count) ---

func test_shows_member_count_troop_with_soldiers() -> void:
	assert_true(_troop("light_infantry", 5).shows_member_count(), "병력 있는 일반부대는 배지 표시")

func test_shows_member_count_hero_hidden() -> void:
	var p := _troop("light_infantry", 5)
	p.kind = p.KIND_HERO
	assert_false(p.shows_member_count(), "영웅부대는 단독이라 배지 생략")

func test_shows_member_count_empty_hidden() -> void:
	var p := _party()
	p.kind = p.KIND_TROOP
	assert_false(p.shows_member_count(), "병력 0인 부대는 배지 없음(토큰도 안 그림)")

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
	var hero := _party()
	hero.kind = hero.KIND_HERO
	assert_eq(hero.command_range(), UnitTypes.command_range("hero"), "영웅 지휘범위 = 클래스4 cmd_range")
	assert_eq(_troop("light_infantry").command_range(), UnitTypes.command_range("light_infantry"), "경보병 지휘범위 = 클래스1 cmd_range")

func test_command_range_no_archetype() -> void:
	assert_eq(_party().command_range(), 0, "아키타입 없으면 0")

func test_command_buffed_false_by_default() -> void:
	assert_false(_party().command_buffed, "생성 직후 지휘 버프 없음")

# --- 이동력 · 시야 · 공격거리 (클래스 기반) → unit_types.gd ---

func test_movement_from_class() -> void:
	var p := _troop("light_infantry")
	assert_eq(p.movement(), UnitTypes.movement("light_infantry"), "이동력 = 클래스 mv")
	assert_gt(p.movement(), 0, "유효 아키타입이면 이동력 > 0")

func test_movement_zero_without_archetype() -> void:
	assert_eq(_party().movement(), 0, "아키타입 없으면 이동력 0(클래스 0)")

func test_vision_from_class() -> void:
	assert_eq(_troop("light_infantry").vision(), UnitTypes.vision("light_infantry"), "시야 = 클래스 카탈로그 시야")

func test_attack_range_ranged_vs_melee() -> void:
	assert_eq(_troop("light_archer").attack_range(), UnitTypes.attack_range("light_archer"), "경궁병 공격거리 = 3(원거리)")
	assert_eq(_troop("light_infantry").attack_range(), 0, "경보병 공격거리 0(근접)")

func test_attack_range_empty_zero() -> void:
	assert_eq(_party().attack_range(), 0, "아키타입 없으면 공격거리 0")

# --- 이동력 풀 (move_points) → turn.md · selection-and-movement.md ---

func _mover() -> Node2D:
	# 이동력 있는 부대(경보병 mv). reset_turn으로 턴 시작 이동력을 채운다.
	var p := _troop("light_infantry")
	p.reset_turn()
	return p

func test_reset_turn_fills_move_points() -> void:
	var p := _mover()
	assert_eq(p.move_points, p.movement(), "reset_turn 후 이동력이 movement()만큼 채워짐")
	assert_true(p.can_move(), "이동력 있으면 이동 가능")
	assert_true(p.can_attack(), "리셋 직후 공격 가능")

func test_spend_movement_partial_keeps_moving() -> void:
	var p := _mover()
	var full: int = p.movement()
	p.spend_movement(2)
	assert_eq(p.move_points, full - 2, "이동력 2 소모")
	assert_true(p.can_move(), "이동력 남으면 계속 이동 가능(다중 클릭)")
	assert_true(p.can_attack(), "이동해도 공격은 별개")

func test_spend_movement_all_blocks_move() -> void:
	var p := _mover()
	p.spend_movement(p.movement())
	assert_eq(p.move_points, 0, "이동력 전부 소모")
	assert_false(p.can_move(), "이동력 0이면 이동 불가")

func test_spend_movement_clamps_at_zero() -> void:
	var p := _mover()
	p.spend_movement(p.movement() + 5)   # 남은 것보다 크게
	assert_eq(p.move_points, 0, "이동력은 음수로 내려가지 않음(0에서 멈춤)")

func test_mark_moved_zeroes_move_points() -> void:
	var p := _mover()
	p.mark_moved()
	assert_eq(p.move_points, 0, "mark_moved는 이동력을 0으로(NPC·공격 접근 종료)")
	assert_false(p.can_move(), "이동 종료 → 이동 불가")
	assert_true(p.can_attack(), "이동 종료해도 공격은 여전히 가능")

# --- 공격 상태 (이동력 풀 + 공격 1) ---

func test_attack_defaults() -> void:
	var p := _mover()
	assert_false(p.attacked_this_turn, "리셋 직후 공격 안 함")
	assert_true(p.can_attack(), "리셋 직후 공격 가능")

func test_attack_independent_of_move() -> void:
	var p := _mover()
	p.mark_attacked()
	assert_false(p.can_attack(), "공격 후 재공격 불가")
	assert_true(p.can_move(), "공격해도 이동력 남으면 이동 가능(이동·공격 독립)")

func test_move_then_still_can_attack() -> void:
	var p := _mover()
	p.spend_movement(p.movement())   # 이동력 소진
	assert_false(p.can_move(), "이동력 0 → 이동 불가")
	assert_true(p.can_attack(), "이동 다 써도 공격은 가능(독립)")

func test_reset_turn_restores_after_actions() -> void:
	var p := _mover()
	p.mark_moved()
	p.mark_attacked()
	p.reset_turn()
	assert_eq(p.move_points, p.movement(), "reset 후 이동력 회복")
	assert_true(p.can_move(), "reset 후 이동 가능")
	assert_true(p.can_attack(), "reset 후 공격 가능")

# --- 대기/행동 가능(can_rest = 선택 판정) ---

func test_can_rest_by_default() -> void:
	assert_true(_mover().can_rest(), "행동 전 can_rest 참")

func test_attacked_blocks_rest() -> void:
	var p := _mover()
	p.mark_attacked()
	assert_false(p.can_rest(), "공격까지 마치면 행동 불가")

func test_reset_turn_restores_rest() -> void:
	var p := _mover()
	p.mark_attacked()
	p.reset_turn()
	assert_true(p.can_rest(), "reset 후 다시 행동 가능")

func test_end_turn_refills_move_points() -> void:
	var tm: Object = load("res://scenes/turn/turn_manager.gd").new()
	var p := _mover()
	p.spend_movement(p.movement())   # 소진(0)
	assert_eq(p.move_points, 0, "선행: 이동력 0")
	tm.end_turn([p], [])
	assert_eq(p.move_points, p.movement(), "턴 종료 시 이동력 회복")

# --- 지휘 설정(따라옴·전투 스탠스) — 지속 → squad-stance.md ---

func test_command_flags_default() -> void:
	var p := _party()
	assert_false(p.command_follow, "기본 직접명령(command_follow=false)")
	assert_false(p.command_engage, "기본 전투회피(command_engage=false)")

func test_command_flags_persist_across_reset() -> void:
	var p := _party()
	p.command_follow = true
	p.command_engage = true
	p.reset_turn()
	assert_true(p.command_follow, "지휘 설정은 reset_turn에서 유지(따라옴)")
	assert_true(p.command_engage, "지휘 설정은 reset_turn에서 유지(전투우선)")

# --- 이동 목표(move_goal) — 지속(계속 이동) → selection-and-movement.md ---

func test_move_goal_default_none() -> void:
	assert_eq(_party().move_goal, Vector2i(-1, -1), "생성 직후 이동 목표 없음")

func test_move_goal_persists_across_reset() -> void:
	var p := _party()
	p.move_goal = Vector2i(9, 4)
	p.reset_turn()
	assert_eq(p.move_goal, Vector2i(9, 4), "이동 목표는 reset_turn에서 유지(다음 턴 계속 이동)")

# --- 소진 표시(exhausted, "E") → selection-and-movement.md ---

func test_exhausted_default_false() -> void:
	assert_false(_party().exhausted, "생성 직후 소진 아님")

func test_set_exhausted() -> void:
	var p := _party()
	p.set_exhausted(true)
	assert_true(p.exhausted, "set_exhausted(true) 후 소진 참")
	p.set_exhausted(false)
	assert_false(p.exhausted, "set_exhausted(false) 후 거짓")

# --- 근·원거리 파워(교전 선호) → docs/spec/features/npc-movement.md ---

func test_melee_power_infantry() -> void:
	var p := _troop("light_infantry", 2)
	assert_eq(p.melee_power(), UnitTypes.base_at("light_infantry") * 2, "경보병 근접 파워 = AT × 병력")
	assert_eq(p.ranged_power(), 0, "경보병 원거리 파워 0")

func test_ranged_power_archer() -> void:
	var p := _troop("light_archer", 3)
	assert_eq(p.ranged_power(), UnitTypes.base_at("light_archer") * 3, "경궁병 원거리 파워 = AT × 병력")
	assert_eq(p.melee_power(), 0, "경궁병 근접 파워 0")
