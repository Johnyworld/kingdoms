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

func test_merge_from_combines_loot() -> void:
	# 병합 시 노획 장비도 합쳐져 소실되지 않는다.
	var a := _party()
	a.add_member(_human())
	a.loot_items = ["sword"]
	var b := _party()
	b.add_member(_human())
	b.loot_items = ["bow", "buckler"]
	a.merge_from(b)
	assert_eq(a.loot_items, ["sword", "bow", "buckler"], "노획 장비 합쳐짐")
	assert_true(b.loot_items.is_empty(), "b 노획 장비는 비워짐(이관)")

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

func test_command_range_from_leadership() -> void:
	var hero := _party()
	var h := _human()
	hero.add_member(h)   # 첫 멤버가 지휘관
	h.leadership = 88
	assert_eq(hero.command_range(), 4, "88 → 2+floor(88/30)=4")
	h.leadership = 42
	assert_eq(hero.command_range(), 3, "42 → 2+floor(42/30)=3")
	h.leadership = 28
	assert_eq(hero.command_range(), 2, "28 → 2+floor(28/30)=2")

func test_command_range_no_commander() -> void:
	assert_eq(_party().command_range(), 0, "지휘관 없으면 0")

func test_command_buffed_false_by_default() -> void:
	assert_false(_party().command_buffed, "생성 직후 지휘 버프 없음")

# --- 이동력(min) · 시야(max) 집계 ---

func test_movement_is_min_of_members() -> void:
	var p := _party()
	p.add_member(_human(3, 5))
	p.add_member(_human(2, 5))
	assert_eq(p.movement(), 2, "이동력은 멤버 중 최소값(가장 느린 멤버)")

func test_movement_zero_without_members() -> void:
	var p := _party()
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

# --- 부대 분할 분배 (transfer_loot_to) ---

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

# --- 공성 유닛 · 견인 이동 → docs/spec/features/siege-engines.md ---

var SiegeUnit = load("res://scenes/siege/siege_unit.gd")

## 사람 n명(각 이동력 mv)인 부대.
func _party_of(n: int, mv := 4) -> Node2D:
	var p := _party()
	for i in n:
		p.add_member(_human(mv))
	return p

func test_siege_units_empty_on_create() -> void:
	var p := _party()
	assert_eq(p.siege_units.size(), 0, "생성 직후 공성 유닛 없음")
	assert_false(p.has_siege(), "has_siege 거짓")

func test_add_siege_unit() -> void:
	var p := _party()
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.siege_units.size(), 1, "공성 유닛 1대")
	assert_true(p.has_siege(), "has_siege 참")

func test_siege_haul_caps_movement() -> void:
	var p := _party_of(4, 4)   # 사람 이동력 4
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.movement(), 2, "투석기 견인 속도 2로 상한")

func test_siege_crew_gate_blocks_move() -> void:
	var p := _party_of(3, 4)   # 사람 3명 < CREW_MIN 4
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.movement(), 0, "견인 인력 부족 → 이동 불가")

func test_siege_haul_takes_min_when_crew_slower() -> void:
	# 사람 기준 이동력이 견인 속도(2)보다 느리면 그 낮은 값이 유지된다.
	var p := _party_of(4, 1)   # 사람 4명, 이동력 1
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.movement(), 1, "min(사람 기준 1, 견인 2) = 1")

func test_siege_does_not_affect_vision_range_members() -> void:
	var p := _party_of(4, 4)   # 사람 이동력·시야 기본
	var vis_before: int = p.vision()
	var range_before: int = p.attack_range()
	var members_before: int = p.members.size()
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.vision(), vis_before, "시야 불변(인구 비소모)")
	assert_eq(p.attack_range(), range_before, "공격거리 불변")
	assert_eq(p.members.size(), members_before, "멤버 수 불변")

func test_siege_ranges_and_attack() -> void:
	var p := _party_of(4, 4)
	assert_eq(p.siege_fire_range(), 0, "공성 유닛 없으면 최대 사거리 0")
	assert_eq(p.siege_min_range(), 0, "공성 유닛 없으면 최소 사거리 0")
	assert_eq(p.siege_attack(), 0, "공성 유닛 없으면 공격력 0")
	p.add_siege_unit(SiegeUnit.new())
	assert_eq(p.siege_fire_range(), 5, "투석기 최대 사거리 5")
	assert_eq(p.siege_min_range(), 4, "투석기 최소 사거리 4")
	assert_eq(p.siege_attack(), 50, "투석기 공격력 50")

func test_prune_destroyed_siege() -> void:
	var p := _party_of(4, 4)
	var alive = SiegeUnit.new()
	var dead = SiegeUnit.new()
	dead.hit_points = 0   # 파괴됨
	p.add_siege_unit(alive)
	p.add_siege_unit(dead)
	assert_eq(p.prune_destroyed_siege(), 1, "hp≤0 투석기 1대 제거·반환")
	assert_eq(p.siege_units.size(), 1, "생존 1대만 남음")
	assert_true(alive in p.siege_units, "hp>0 투석기 유지")
	assert_eq(p.prune_destroyed_siege(), 0, "파괴 없으면 0·불변")

# --- 충차(5h, 근접 대성벽 공성) → docs/spec/features/siege-engines.md ---

func test_ram_haul_caps_movement() -> void:
	var p := _party_of(4, 4)
	p.add_siege_unit(SiegeUnit.new("battering_ram"))
	assert_eq(p.movement(), 1, "충차 견인 속도 1로 상한")

func test_ram_crew_gate_blocks_move() -> void:
	var p := _party_of(3, 4)   # 사람 3명 < CREW_MIN 4
	p.add_siege_unit(SiegeUnit.new("battering_ram"))
	assert_eq(p.movement(), 0, "견인 인력 부족 → 이동 불가")

func test_ram_ranges_and_attack() -> void:
	var p := _party_of(4, 4)
	p.add_siege_unit(SiegeUnit.new("battering_ram"))
	assert_eq(p.siege_fire_range(), 1, "충차 최대 사거리 1")
	assert_eq(p.siege_min_range(), 1, "충차 최소 사거리 1")
	assert_eq(p.siege_attack(), 90, "충차 공격력 90")

func test_siege_can_bombard_none() -> void:
	var p := _party_of(4, 4)
	assert_false(p.siege_can_bombard("unit"), "공성 유닛 없으면 unit false")
	assert_false(p.siege_can_bombard("wall"), "wall false")
	assert_false(p.siege_can_bombard("gate"), "gate false")

func test_siege_can_bombard_catapult() -> void:
	var p := _party_of(4, 4)
	p.add_siege_unit(SiegeUnit.new())   # 투석기
	assert_true(p.siege_can_bombard("unit"), "투석기 unit")
	assert_true(p.siege_can_bombard("wall"), "투석기 wall")
	assert_true(p.siege_can_bombard("gate"), "투석기 gate")

func test_siege_can_bombard_ram_only() -> void:
	var p := _party_of(4, 4)
	p.add_siege_unit(SiegeUnit.new("battering_ram"))
	assert_true(p.siege_can_bombard("gate"), "충차 gate")
	assert_false(p.siege_can_bombard("wall"), "충차는 성벽 못 침")
	assert_false(p.siege_can_bombard("unit"), "충차는 유닛 못 침")

func test_siege_can_bombard_mixed() -> void:
	var p := _party_of(4, 4)
	p.add_siege_unit(SiegeUnit.new("battering_ram"))
	p.add_siege_unit(SiegeUnit.new())   # 투석기 혼합
	assert_true(p.siege_can_bombard("unit"), "혼합 unit")
	assert_true(p.siege_can_bombard("gate"), "혼합 gate")

# --- 근·원거리 파워(교전 선호) → docs/spec/features/npc-movement.md ---

func test_melee_power_sums_best_melee() -> void:
	var p := _party()
	p.add_member(_equipped_human(["sword"], []))   # 검 공격력 14
	p.add_member(_equipped_human(["sword"], []))
	assert_eq(p.melee_power(), 28, "검 든 두 멤버 → 근접 파워 28")
	assert_eq(p.ranged_power(), 0, "원거리 무기 없음 → 원거리 파워 0")

func test_ranged_power_sums_best_ranged() -> void:
	var p := _party()
	p.add_member(_equipped_human(["bow"], []))   # 활 공격력 12, 근접 없음
	assert_eq(p.ranged_power(), 12, "활 든 멤버 → 원거리 파워 12")
	assert_eq(p.melee_power(), 0, "근접 무기 없음 → 근접 파워 0")

func test_power_mixed_weapons_count_both() -> void:
	var p := _party()
	p.add_member(_equipped_human(["sword", "bow"], []))   # 근접 14 + 원거리 12
	assert_eq(p.melee_power(), 14, "검+활 → 근접 파워 14(검)")
	assert_eq(p.ranged_power(), 12, "검+활 → 원거리 파워 12(활)")

func test_power_empty_party_zero() -> void:
	var p := _party()
	assert_eq(p.melee_power(), 0, "멤버 없으면 근접 0")
	assert_eq(p.ranged_power(), 0, "멤버 없으면 원거리 0")
