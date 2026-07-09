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

func test_unknown_armor_defaults() -> void:
	assert_eq(ItemTypes.armor_defense("없음"), 0, "없는 방어구 방어력 0")
	assert_eq(ItemTypes.armor_class(""), "", "빈 방어구 분류 빈 문자열")

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
