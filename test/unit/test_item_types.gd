extends GutTest
## 아이템 카탈로그(ItemTypes) 테스트 — 무기·방어구 조회, 방어력 합산, 대표 분류, 상성표.

func test_weapon_attack_and_type() -> void:
	assert_eq(ItemTypes.weapon_attack("sword"), 14, "검 공격력 14")
	assert_eq(ItemTypes.weapon_damage_type("wand"), "마법", "완드 데미지 타입 마법")
	assert_eq(ItemTypes.weapon_name("sword"), "검", "검 이름")

func test_unknown_weapon_defaults() -> void:
	assert_eq(ItemTypes.weapon_attack(""), 0, "빈 무기 공격력 0")
	assert_eq(ItemTypes.weapon_attack("없음"), 0, "없는 무기 공격력 0")
	assert_eq(ItemTypes.weapon_damage_type(""), "", "빈 무기 데미지 타입 빈 문자열")
	assert_eq(ItemTypes.weapon_name(""), "", "빈 무기 이름 빈 문자열")

func test_armor_defense_and_class() -> void:
	assert_eq(ItemTypes.armor_defense("chain_mail"), 14, "사슬 갑옷 방어력 14")
	assert_eq(ItemTypes.armor_class("robe"), "천", "로브 분류 천")
	assert_eq(ItemTypes.armor_name("robe"), "로브", "로브 이름")

func test_unknown_armor_defaults() -> void:
	assert_eq(ItemTypes.armor_defense("없음"), 0, "없는 방어구 방어력 0")
	assert_eq(ItemTypes.armor_class(""), "", "빈 방어구 분류 빈 문자열")
	assert_eq(ItemTypes.armor_name(""), "", "빈 방어구 이름 빈 문자열")

func test_shield_stats() -> void:
	assert_eq(ItemTypes.shield_defense("tower_shield"), 12, "타워 실드 방어력 12")
	assert_eq(ItemTypes.shield_block("tower_shield"), 40, "타워 실드 막기 40%")
	assert_eq(ItemTypes.shield_name("buckler"), "버클러", "버클러 이름")

func test_unknown_shield_defaults() -> void:
	assert_eq(ItemTypes.shield_defense(""), 0, "빈 방패 방어력 0")
	assert_eq(ItemTypes.shield_block("없음"), 0, "없는 방패 막기 0")
	assert_eq(ItemTypes.shield_name(""), "", "빈 방패 이름 빈 문자열")

func test_weapon_range() -> void:
	assert_eq(ItemTypes.weapon_range("bow"), 3, "단궁 공격거리 3")
	assert_eq(ItemTypes.weapon_range("sword"), 0, "검은 근접(월드맵 사거리 0)")
	assert_eq(ItemTypes.weapon_range(""), 0, "맨손은 근접 0")

func test_range_label() -> void:
	assert_eq(ItemTypes.range_label(0), "근접", "0은 근접")
	assert_eq(ItemTypes.range_label(3), "사거리 3", "3은 사거리 3")
	assert_eq(ItemTypes.range_label(2), "사거리 2", "2는 사거리 2")

func test_weapon_reach() -> void:
	assert_almost_eq(ItemTypes.weapon_reach("spear"), 2.0, 0.001, "장창 리치 2.0(가장 김)")
	assert_almost_eq(ItemTypes.weapon_reach("sword"), 1.2, 0.001, "검 리치 1.2")
	assert_almost_eq(ItemTypes.weapon_reach("scimitar"), 1.1, 0.001, "곡도 리치 1.1")
	assert_almost_eq(ItemTypes.weapon_reach(""), 1.0, 0.001, "맨손 리치 1.0")

func test_weapon_attack_speed() -> void:
	assert_almost_eq(ItemTypes.weapon_attack_speed("sword"), 2.0, 0.001, "검 공격속도 2.0초")
	assert_almost_eq(ItemTypes.weapon_attack_speed("bow"), 3.3, 0.001, "단궁 공격속도 3.3초")
	assert_almost_eq(ItemTypes.weapon_attack_speed("scimitar"), 1.8, 0.001, "곡도 공격속도 1.8초")
	assert_almost_eq(ItemTypes.weapon_attack_speed(""), 2.0, 0.001, "맨손 기본 공격속도 2.0초")

func test_throw_range() -> void:
	assert_eq(ItemTypes.weapon_range("javelin"), 0, "투창은 월드맵 근접(사거리 0)")
	assert_eq(ItemTypes.weapon_throw_range("javelin"), 2, "투창 투척 사거리 2")
	assert_eq(ItemTypes.weapon_throw_range("sword"), 0, "검은 투척 불가 0")
	assert_eq(ItemTypes.weapon_throw_range(""), 0, "빈 무기 투척 0")

func test_throwing_weapon() -> void:
	assert_eq(ItemTypes.throwing_weapon(["scimitar", "javelin"]), "javelin", "목록 중 투척 무기")
	assert_eq(ItemTypes.throwing_weapon(["sword", "bow"]), "", "투척 무기 없으면 빈 문자열")

func test_primary_weapon() -> void:
	assert_eq(ItemTypes.primary_weapon(["sword", "bow"]), "sword", "주무기는 목록 첫 원소")
	assert_eq(ItemTypes.primary_weapon([]), "", "빈 목록이면 맨손")

func test_ranged_weapon() -> void:
	assert_eq(ItemTypes.ranged_weapon(["sword", "bow"]), "bow", "목록 중 원거리 무기(활)")
	assert_eq(ItemTypes.ranged_weapon(["wand", "sword"]), "wand", "완드도 원거리(사거리 2)")
	assert_eq(ItemTypes.ranged_weapon(["sword"]), "", "원거리 무기 없으면 빈 문자열")

func test_melee_weapon() -> void:
	assert_eq(ItemTypes.melee_weapon(["longsword", "bow"]), "longsword", "목록 중 근접 무기(사거리<2)")
	assert_eq(ItemTypes.melee_weapon(["bow"]), "", "순수 원거리면 빈 문자열")
	assert_eq(ItemTypes.melee_weapon([]), "", "맨손 목록 없음 → 빈 문자열")

func test_max_range() -> void:
	assert_eq(ItemTypes.max_range(["sword", "bow"]), 3, "보유 무기 중 최대 공격거리")
	assert_eq(ItemTypes.max_range(["sword"]), 0, "근접만이면 0")
	assert_eq(ItemTypes.max_range([]), 0, "맨손은 근접 0")

func test_active_weapon() -> void:
	assert_eq(ItemTypes.active_weapon(["sword", "bow"], false), "sword", "근접 전투 → 주무기")
	assert_eq(ItemTypes.active_weapon(["sword", "bow"], true), "bow", "원거리 전투 → 활")
	assert_eq(ItemTypes.active_weapon(["sword"], true), "", "원거리 무기 없으면 공격 불가(빈 문자열)")
	assert_eq(ItemTypes.active_weapon([], false), "", "맨손 근접")

func test_weights() -> void:
	assert_eq(ItemTypes.weapon_weight("sword"), 3, "검 무게 3")
	assert_eq(ItemTypes.armor_weight("chain_mail"), 8, "사슬 갑옷 무게 8")
	assert_eq(ItemTypes.shield_weight("tower_shield"), 8, "타워 실드 무게 8")
	assert_eq(ItemTypes.weapon_weight(""), 0, "빈 무기 무게 0")
	assert_eq(ItemTypes.armor_weight("없음"), 0, "없는 방어구 무게 0")

func test_total_defense_sums() -> void:
	var set := ["leather_helm", "leather_armor", "leather_gloves", "leather_greaves"]  # 4+8+2+3
	assert_eq(ItemTypes.total_defense(set), 17, "가죽 세트 방어력 합 17")
	assert_eq(ItemTypes.total_defense([]), 0, "맨몸 방어력 0")

func test_armor_class_of_uses_max_defense_piece() -> void:
	# 방어력 최대 조각(가죽 갑옷 8)의 분류가 대표.
	var set := ["leather_helm", "leather_armor", "leather_gloves"]
	assert_eq(ItemTypes.armor_class_of(set), "가죽", "최대 방어 조각 분류 = 가죽")
	assert_eq(ItemTypes.armor_class_of([]), "", "맨몸 대표 분류 빈 문자열")

func test_affinity_table() -> void:
	assert_almost_eq(ItemTypes.affinity("판금", "마법"), 1.3, 0.001, "판금은 마법에 취약")
	assert_almost_eq(ItemTypes.affinity("사슬", "참격"), 0.7, 0.001, "사슬은 참격에 강함")
	assert_almost_eq(ItemTypes.affinity("천", "마법"), 0.6, 0.001, "천은 마법 경감")

func test_affinity_unknown_defaults_one() -> void:
	assert_almost_eq(ItemTypes.affinity("", "참격"), 1.0, 0.001, "분류 없으면 1.0")
	assert_almost_eq(ItemTypes.affinity("판금", ""), 1.0, 0.001, "타입 없으면 1.0")

func test_item_name_unified_lookup() -> void:
	# 무기·방어구·방패 카탈로그를 통합 조회한다(노획 장비 목록 표시용).
	assert_eq(ItemTypes.item_name("sword"), "검", "무기 이름")
	assert_eq(ItemTypes.item_name("chain_mail"), "사슬 갑옷", "방어구 이름")
	assert_eq(ItemTypes.item_name("buckler"), "버클러", "방패 이름")
	assert_eq(ItemTypes.item_name("grapple_ladder"), "고리 사다리", "도구 이름")
	assert_eq(ItemTypes.item_name(""), "", "빈 id는 빈 문자열")
	assert_eq(ItemTypes.item_name("없음"), "", "없는 id는 빈 문자열")

func test_item_slot_classifies_by_catalog() -> void:
	# 장비 관리에서 노획 장비를 알맞은 슬롯에 넣기 위한 분류.
	assert_eq(ItemTypes.item_slot("sword"), ItemTypes.SLOT_WEAPON, "무기 슬롯(상수 단일 출처)")
	assert_eq(ItemTypes.item_slot("chain_mail"), ItemTypes.SLOT_ARMOR, "방어구 슬롯(상수 단일 출처)")
	assert_eq(ItemTypes.item_slot("buckler"), ItemTypes.SLOT_SHIELD, "방패 슬롯(상수 단일 출처)")
	assert_eq(ItemTypes.item_slot("grapple_ladder"), "", "도구는 장착 슬롯 없음")
	assert_eq(ItemTypes.item_slot(""), "", "빈 id는 빈 문자열")
	assert_eq(ItemTypes.item_slot("없음"), "", "없는 id는 빈 문자열")

func test_item_value_sell_price() -> void:
	# 판매가: 무기=공격력, 방어구·방패=방어력×2.
	assert_eq(ItemTypes.item_value("sword"), 14, "검 가치 14(공격력)")
	assert_eq(ItemTypes.item_value("chain_mail"), 28, "사슬 갑옷 가치 28(방어력×2)")
	assert_eq(ItemTypes.item_value("tower_shield"), 24, "타워 실드 가치 24(방어력×2)")
	assert_eq(ItemTypes.item_value("grapple_ladder"), 12, "고리 사다리 가치 12(도구)")
	assert_eq(ItemTypes.item_value(""), 0, "빈 id 0")
	assert_eq(ItemTypes.item_value("없음"), 0, "없는 id 0")
