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

func test_merge_from_combines_cargo() -> void:
	# 병합 시 화물도 합쳐져 소실되지 않는다(합산이라 용량 초과 허용).
	var a := _party()
	a.add_member(_human())
	a.add_cargo("목재", 30)
	var b := _party()
	b.add_member(_human())
	b.add_cargo("목재", 30)
	b.add_cargo("석재", 10)
	a.merge_from(b)
	assert_eq(a.cargo["목재"], 60, "목재 30+30 합산(용량 50 초과 허용)")
	assert_eq(a.cargo["석재"], 10, "석재도 합쳐짐")
	assert_true(b.cargo.is_empty(), "b 화물은 비워짐(소실 아님, 이관)")

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

# --- 과적 이동력 감소 (overload_penalty) ---

func test_no_overload_when_within_capacity() -> void:
	var p := _party()
	p.add_member(_human(3, 5))
	p.add_cargo("목재", 50)   # 용량 딱 채움
	assert_eq(p.overload_penalty(), 0, "용량 이하면 페널티 0")
	assert_eq(p.movement(), 3, "이동력 기본과 같음")

func test_overload_reduces_movement() -> void:
	# 기본 3, 화물 67(초과 17, step 50/3≈16.7) → 페널티 1. 과적은 병합/약탈로 용량 초과된 상태(직접 세팅).
	var p := _party()
	p.add_member(_human(3, 5))
	p.cargo["목재"] = 67
	assert_eq(p.overload_penalty(), 1, "초과 17 → 페널티 1")
	assert_eq(p.movement(), 2, "3 − 1 = 2")

func test_overload_stops_at_double_capacity() -> void:
	# 기본 3, 화물 100(용량 2배, 초과 50) → 페널티 3 → 이동력 0(정지).
	var p := _party()
	p.add_member(_human(3, 5))
	p.cargo["목재"] = 100
	assert_eq(p.overload_penalty(), 3, "초과 50 → 페널티 3")
	assert_eq(p.movement(), 0, "2배 용량이면 정지")

func test_faster_party_tolerates_more_overload() -> void:
	# 기본 5, 화물 60(초과 10, step 50/5=10) → 페널티 1 → 이동력 4.
	var p := _party()
	p.add_member(_human(5, 5))
	p.cargo["목재"] = 60
	assert_eq(p.overload_penalty(), 1, "초과 10 · step 10 → 페널티 1")
	assert_eq(p.movement(), 4, "5 − 1 = 4")

func test_overload_penalty_zero_without_members() -> void:
	var p := _party()
	assert_eq(p.overload_penalty(), 0, "멤버 없으면 페널티 0")
	assert_eq(p.movement(), 0, "멤버 없으면 이동력 0")

func test_vision_is_max_of_members() -> void:
	var p := _party()
	p.add_member(_human(3, 5))
	p.add_member(_human(2, 2))
	assert_eq(p.vision(), 5, "시야는 멤버 중 최대값")

func test_attack_range_is_max_of_members() -> void:
	var p := _party()
	var melee := _human()
	melee.weapons = ["sword"]        # 공격거리 1
	var archer := _human()
	archer.weapons = ["sword", "bow"]   # 근접+활 → 최대 사거리 3
	p.add_member(melee)
	p.add_member(archer)
	assert_eq(p.attack_range(), 3, "공격거리는 멤버별 최대 무기 사거리 중 최대")

func test_attack_range_empty_zero() -> void:
	assert_eq(_party().attack_range(), 0, "멤버 없으면 공격거리 0")

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

func test_mark_rested_ends_actions() -> void:
	var p := _party()
	p.mark_rested()
	assert_true(p.rested_this_turn, "mark_rested 후 휴식함 표시")
	assert_true(p.attacked_this_turn, "휴식은 행동을 끝낸다")
	assert_false(p.can_rest(), "휴식 후 재휴식 불가")
	assert_false(p.can_attack(), "휴식 후 공격 불가")

func test_mark_rested_keeps_moved() -> void:
	# 이동 후 대기 → moved 유지(회복 슬라이스에서 이동/대기 구분에 쓰인다).
	var p := _party()
	p.mark_moved()
	p.mark_rested()
	assert_true(p.moved_this_turn, "이동 후 대기는 moved 유지")

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
	p.mark_rested()
	p.reset_turn()
	assert_false(p.rested_this_turn, "reset 후 휴식 안 함으로 리셋")
	assert_true(p.can_rest(), "reset 후 다시 휴식 가능")

func test_end_turn_resets_party() -> void:
	var tm: Object = load("res://scenes/turn/turn_manager.gd").new()
	var p := _party()
	p.mark_moved()
	tm.end_turn([p], [])
	assert_false(p.moved_this_turn, "턴 종료 시 부대 이동 상태 리셋")

# --- 화물 (캐러반) ---

func test_cargo_empty_at_start() -> void:
	var p := _party()
	assert_eq(p.cargo.size(), 0, "생성 직후 화물 비어 있음")
	assert_eq(p.cargo_total(), 0, "총량 0")
	assert_eq(p.cargo_space(), 50, "여유 = 용량 50")

func test_add_cargo() -> void:
	var p := _party()
	assert_eq(p.add_cargo("목재", 10), 10, "실은 양 10 반환")
	assert_eq(p.cargo["목재"], 10, "화물에 목재 10")
	assert_eq(p.cargo_total(), 10, "총량 10")

func test_add_cargo_capped_by_capacity() -> void:
	var p := _party()
	p.add_cargo("목재", 45)
	assert_eq(p.add_cargo("밀", 10), 5, "여유 5만 실림")
	assert_eq(p.cargo_total(), 50, "총량 상한 50")

func test_add_cargo_negative_is_noop() -> void:
	var p := _party()
	assert_eq(p.add_cargo("목재", -5), 0, "음수는 0")
	assert_eq(p.cargo_total(), 0, "변화 없음")

func test_remove_cargo() -> void:
	var p := _party()
	p.add_cargo("목재", 10)
	assert_eq(p.remove_cargo("목재", 4), 4, "내린 양 4 반환")
	assert_eq(p.cargo["목재"], 6, "남은 6")

func test_remove_cargo_clamps_and_erases() -> void:
	var p := _party()
	p.add_cargo("목재", 3)
	assert_eq(p.remove_cargo("목재", 10), 3, "보유분(3)만 내림")
	assert_false(p.cargo.has("목재"), "0이 되면 키 삭제")

# --- 약탈 (take_loot / take_all_loot) ---

func test_take_loot_moves_between_parties() -> void:
	# 승자가 패자 화물에서 자원을 옮긴다.
	var winner := _party()
	var loser := _party()
	loser.add_cargo("목재", 20)
	assert_eq(winner.take_loot(loser, "목재", 5), 5, "옮긴 양 5 반환")
	assert_eq(winner.cargo["목재"], 5, "승자에 목재 5")
	assert_eq(loser.cargo["목재"], 15, "패자 목재 15로 감소")

func test_take_loot_clamps_to_source_and_erases() -> void:
	var winner := _party()
	var loser := _party()
	loser.add_cargo("목재", 3)
	assert_eq(winner.take_loot(loser, "목재", 10), 3, "패자 보유분(3)까지만")
	assert_false(loser.cargo.has("목재"), "패자 화물 0이면 키 삭제")

func test_take_loot_allows_overflow() -> void:
	# 약탈은 승자 용량(50)을 넘겨도 다 실린다(병합과 동일).
	var winner := _party()
	winner.add_cargo("목재", 48)
	var loser := _party()
	loser.add_cargo("석재", 10)
	assert_eq(winner.take_loot(loser, "석재", 10), 10, "전량 이전")
	assert_eq(winner.cargo_total(), 58, "용량 초과 허용(58 > 50)")

func test_take_loot_negative_or_missing_is_noop() -> void:
	var winner := _party()
	var loser := _party()
	loser.add_cargo("목재", 5)
	assert_eq(winner.take_loot(loser, "목재", -3), 0, "음수는 0")
	assert_eq(winner.take_loot(loser, "석재", 5), 0, "없는 자원은 0")
	assert_eq(loser.cargo["목재"], 5, "패자 화물 변화 없음")
	assert_true(winner.cargo.is_empty(), "승자 화물 변화 없음")

func test_take_all_loot_moves_everything() -> void:
	var winner := _party()
	var loser := _party()
	loser.add_cargo("목재", 10)
	loser.add_cargo("식량", 5)
	winner.take_all_loot(loser)
	assert_eq(winner.cargo["목재"], 10, "목재 전량 이전")
	assert_eq(winner.cargo["식량"], 5, "식량 전량 이전")
	assert_true(loser.cargo.is_empty(), "패자 화물 비워짐")

func test_take_all_loot_empty_source_noop() -> void:
	var winner := _party()
	winner.add_cargo("목재", 5)
	winner.take_all_loot(_party())   # 빈 부대 약탈
	assert_eq(winner.cargo_total(), 5, "빈 source 약탈은 변화 없음")

# --- 노획 장비 (equipment_ids / take_all_equipment) ---

func _equipped_human(weapons: Array, armor: Array, shield := "") -> Object:
	var h := _human()
	h.weapons = weapons
	h.armor = armor
	h.shield = shield
	return h

func test_loot_items_empty_at_start() -> void:
	assert_eq(_party().loot_items.size(), 0, "생성 직후 노획 장비 없음")

func test_equipment_ids_flattens_member_gear() -> void:
	var p := _party()
	p.add_member(_equipped_human(["sword", "bow"], ["leather_armor"], "buckler"))
	assert_eq(p.equipment_ids(), ["sword", "bow", "leather_armor", "buckler"], "무기+방어구+방패 평탄·순서 유지")

func test_equipment_ids_excludes_empty_shield() -> void:
	var p := _party()
	p.add_member(_equipped_human(["sword"], [], ""))   # 방패 없음
	assert_eq(p.equipment_ids(), ["sword"], "빈 방패는 제외")

func test_equipment_ids_keeps_duplicates() -> void:
	var p := _party()
	p.add_member(_equipped_human(["sword"], [], ""))
	p.add_member(_equipped_human(["sword"], [], ""))   # 같은 무기
	assert_eq(p.equipment_ids(), ["sword", "sword"], "중복 id는 각각 유지")

func test_equipment_ids_empty_when_no_members() -> void:
	assert_eq(_party().equipment_ids(), [], "멤버 없으면 빈 목록")

func test_take_all_equipment_collects_into_loot() -> void:
	var winner := _party()
	var loser := _party()
	loser.add_member(_equipped_human(["sword"], ["chain_mail"], "kite_shield"))
	loser.add_member(_equipped_human(["bow"], [], ""))
	winner.take_all_equipment(loser)
	assert_eq(winner.loot_items, ["sword", "chain_mail", "kite_shield", "bow"], "패자 장비 전부 loot_items로")
	assert_eq(loser.equipment_ids(), ["sword", "chain_mail", "kite_shield", "bow"], "source(패자) 장비는 불변")

func test_take_all_equipment_empty_source_noop() -> void:
	var winner := _party()
	winner.loot_items = ["sword"]
	winner.take_all_equipment(_party())   # 멤버 없는 부대
	assert_eq(winner.loot_items, ["sword"], "장비 없는 source면 변화 없음")

# --- 장비 장착·탈착 (equip_from_loot / unequip_to_loot) ---

func test_can_equip_from_loot_dry_run() -> void:
	var p := _party()
	var m := _human()
	p.add_member(m)
	p.loot_items = ["sword"]
	assert_true(p.can_equip_from_loot(m, "sword"), "인벤토리에 있고 빈 슬롯 → 가능")
	assert_false(p.can_equip_from_loot(m, "bow"), "인벤토리에 없으면 불가")
	assert_eq(m.weapons, [], "판정만 — 멤버 변화 없음")
	assert_eq(p.loot_items, ["sword"], "판정만 — 인벤토리 변화 없음")
	var full := _equipped_human(["sword", "spear", "bow"], [], "")
	p.add_member(full)
	assert_false(p.can_equip_from_loot(full, "sword"), "무기 3개면 불가")

func test_equip_weapon_from_loot() -> void:
	var p := _party()
	var m := _human()   # 무기 비어 있음
	p.add_member(m)
	p.loot_items = ["sword"]
	assert_true(p.equip_from_loot(m, "sword"), "빈 무기 슬롯에 장착 성공")
	assert_eq(m.weapons, ["sword"], "멤버 무기에 검")
	assert_false("sword" in p.loot_items, "인벤토리에서 제거")

func test_equip_armor_and_shield_from_loot() -> void:
	var p := _party()
	var m := _human()
	p.add_member(m)
	p.loot_items = ["chain_mail", "buckler"]
	assert_true(p.equip_from_loot(m, "chain_mail"), "방어구 장착")
	assert_true(p.equip_from_loot(m, "buckler"), "방패 장착(빈 슬롯)")
	assert_eq(m.armor, ["chain_mail"], "멤버 방어구에 사슬 갑옷")
	assert_eq(m.shield, "buckler", "멤버 방패에 버클러")
	assert_eq(p.loot_items, [], "인벤토리 비워짐")

func test_equip_fails_when_slot_full() -> void:
	var p := _party()
	var m := _equipped_human(["sword", "spear", "bow"], [], "round_shield")  # 무기 3(꽉), 방패 있음
	p.add_member(m)
	p.loot_items = ["mace", "kite_shield"]
	assert_false(p.equip_from_loot(m, "mace"), "무기 3개면 4번째 장착 실패")
	assert_false(p.equip_from_loot(m, "kite_shield"), "방패 있으면 장착 실패")
	assert_eq(p.loot_items, ["mace", "kite_shield"], "실패 시 인벤토리 변화 없음")
	assert_eq(m.weapons.size(), 3, "무기 그대로 3개")

func test_equip_fails_when_not_in_loot_or_unknown() -> void:
	var p := _party()
	var m := _human()
	p.add_member(m)
	p.loot_items = ["sword"]
	assert_false(p.equip_from_loot(m, "bow"), "인벤토리에 없는 장비 실패")
	assert_false(p.equip_from_loot(m, "없는아이템"), "카탈로그에 없는 id 실패")
	assert_eq(m.weapons, [], "멤버 무기 변화 없음")

func test_unequip_weapon_to_loot() -> void:
	var p := _party()
	var m := _equipped_human(["sword", "bow"], [], "")
	p.add_member(m)
	assert_true(p.unequip_to_loot(m, "sword"), "무기 탈착 성공")
	assert_eq(m.weapons, ["bow"], "검 빠지고 활이 주무기")
	assert_true("sword" in p.loot_items, "인벤토리로 반환")

func test_unequip_shield_to_loot() -> void:
	var p := _party()
	var m := _equipped_human(["sword"], [], "buckler")
	p.add_member(m)
	assert_true(p.unequip_to_loot(m, "buckler"), "방패 탈착 성공")
	assert_eq(m.shield, "", "방패 빔")
	assert_true("buckler" in p.loot_items, "인벤토리로 반환")

func test_unequip_fails_when_not_equipped() -> void:
	var p := _party()
	var m := _equipped_human(["sword"], [], "")
	p.add_member(m)
	assert_false(p.unequip_to_loot(m, "bow"), "멤버가 안 가진 장비 탈착 실패")
	assert_eq(p.loot_items, [], "인벤토리 변화 없음")

# --- 부대 분할 분배 (transfer_cargo_to / transfer_loot_to) ---

func test_transfer_cargo_to() -> void:
	var a := _party()
	var b := _party()
	a.add_cargo("목재", 20)
	assert_eq(a.transfer_cargo_to(b, "목재", 5), 5, "옮긴 양 5")
	assert_eq(a.cargo["목재"], 15, "A 15로 감소")
	assert_eq(b.cargo["목재"], 5, "B 5로 증가")

func test_transfer_cargo_to_clamps_to_holding() -> void:
	var a := _party()
	var b := _party()
	a.add_cargo("목재", 3)
	assert_eq(a.transfer_cargo_to(b, "목재", 10), 3, "보유분(3)까지만")
	assert_false(a.cargo.has("목재"), "A 0이면 키 삭제")
	assert_eq(b.cargo["목재"], 3, "B에 3")

func test_transfer_cargo_to_allows_overflow() -> void:
	# 초과 허용(병합·약탈과 동일) — 받는 부대 용량 무시.
	var a := _party()
	var b := _party()
	a.add_cargo("목재", 5)
	b.add_cargo("석재", 48)
	assert_eq(a.transfer_cargo_to(b, "목재", 5), 5, "전량 이동")
	assert_eq(b.cargo_total(), 53, "받는 부대 용량 초과 허용(53 > 50)")

func test_transfer_cargo_to_negative_or_missing() -> void:
	var a := _party()
	var b := _party()
	a.add_cargo("목재", 5)
	assert_eq(a.transfer_cargo_to(b, "목재", -3), 0, "음수는 0")
	assert_eq(a.transfer_cargo_to(b, "석재", 5), 0, "미보유 자원은 0")
	assert_eq(a.cargo["목재"], 5, "A 변화 없음")
	assert_true(b.cargo.is_empty(), "B 변화 없음")

func test_transfer_loot_to() -> void:
	var a := _party()
	var b := _party()
	a.loot_items = ["sword", "bow"]
	assert_true(a.transfer_loot_to(b, "sword"), "장비 1개 이동 성공")
	assert_eq(a.loot_items, ["bow"], "A에서 sword 빠짐")
	assert_eq(b.loot_items, ["sword"], "B에 sword")

func test_transfer_loot_to_not_held() -> void:
	var a := _party()
	var b := _party()
	a.loot_items = ["sword"]
	assert_false(a.transfer_loot_to(b, "bow"), "미보유 id는 false")
	assert_eq(a.loot_items, ["sword"], "A 변화 없음")
	assert_true(b.loot_items.is_empty(), "B 변화 없음")
