extends GutTest
## 공성 유닛 카탈로그(SiegeTypes) 순수 테스트. → docs/spec/data/siege-units.md

var types = load("res://scenes/siege/siege_types.gd")

func test_constants() -> void:
	assert_eq(types.CATAPULT, "catapult", "투석기 id")
	assert_eq(types.CREW_MIN, 4, "견인 최소 인력 4")

func test_catapult_values() -> void:
	assert_eq(types.type_name("catapult"), "투석기", "이름")
	assert_eq(types.movement("catapult"), 2, "견인 이동력 2")
	assert_eq(types.min_range("catapult"), 4, "최소 투석 사거리 4")
	assert_eq(types.fire_range("catapult"), 5, "최대 투석 사거리 5")
	assert_eq(types.attack("catapult"), 50, "공격력 50")
	assert_eq(types.max_hp("catapult"), 60, "내구도 60")
	assert_eq(types.produce_gold("catapult"), 40, "생산 금 40")
	assert_eq(types.produce_cost("catapult"), {"목재": 30, "철": 20}, "생산 자재")

func test_produce_full_cost() -> void:
	assert_eq(types.produce_full_cost("catapult"), {"금": 40, "목재": 30, "철": 20}, "생산 총비용(금+자재)")

func test_battering_ram_values() -> void:
	assert_eq(types.BATTERING_RAM, "battering_ram", "충차 id")
	assert_eq(types.type_name("battering_ram"), "충차", "이름")
	assert_eq(types.movement("battering_ram"), 1, "견인 이동력 1")
	assert_eq(types.min_range("battering_ram"), 1, "최소 사거리 1(근접)")
	assert_eq(types.fire_range("battering_ram"), 1, "최대 사거리 1(근접)")
	assert_eq(types.attack("battering_ram"), 90, "공격력 90")
	assert_eq(types.max_hp("battering_ram"), 40, "내구도 40")
	assert_eq(types.produce_full_cost("battering_ram"), {"금": 50, "목재": 40, "철": 10}, "생산 총비용")

func test_targets() -> void:
	assert_eq(types.targets("catapult"), ["unit", "wall", "gate"], "투석기 표적 전부")
	assert_eq(types.targets("battering_ram"), ["gate"], "충차 성문 전용")
	assert_eq(types.targets("nope"), [], "없는 id 빈 배열")

func test_can_target() -> void:
	assert_true(types.can_target("battering_ram", "gate"), "충차 성문 가능")
	assert_false(types.can_target("battering_ram", "wall"), "충차 성벽 불가")
	assert_false(types.can_target("battering_ram", "unit"), "충차 유닛 불가")
	assert_true(types.can_target("catapult", "wall"), "투석기 성벽 가능")
	assert_true(types.can_target("catapult", "unit"), "투석기 유닛 가능")
	assert_false(types.can_target("nope", "gate"), "없는 id false")

func test_missing_id_defaults() -> void:
	assert_eq(types.type_name("nope"), "", "없는 id 이름 빈 문자열")
	assert_eq(types.movement("nope"), 0, "없는 id 이동력 0")
	assert_eq(types.min_range("nope"), 0, "없는 id 최소 사거리 0")
	assert_eq(types.fire_range("nope"), 0, "없는 id 사거리 0")
	assert_eq(types.attack("nope"), 0, "없는 id 공격력 0")
	assert_eq(types.max_hp("nope"), 0, "없는 id 내구도 0")
	assert_eq(types.produce_gold("nope"), 0, "없는 id 생산 금 0")
	assert_eq(types.produce_cost("nope"), {}, "없는 id 생산 자재 빈 Dictionary")
	assert_eq(types.produce_full_cost("nope"), {}, "없는 id 생산 총비용 빈 Dictionary")
	assert_eq(types.get_type("nope"), {}, "없는 id 스펙 빈 Dictionary")
