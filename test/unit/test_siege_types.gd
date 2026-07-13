extends GutTest
## 공성 유닛 카탈로그(SiegeTypes) 순수 테스트. → docs/spec/data/siege-units.md

var types = load("res://scenes/siege/siege_types.gd")

func test_constants() -> void:
	assert_eq(types.CATAPULT, "catapult", "투석기 id")
	assert_eq(types.CREW_MIN, 4, "견인 최소 인력 4")

func test_catapult_values() -> void:
	assert_eq(types.type_name("catapult"), "투석기", "이름")
	assert_eq(types.movement("catapult"), 2, "견인 이동력 2")
	assert_eq(types.produce_gold("catapult"), 40, "생산 금 40")
	assert_eq(types.produce_cost("catapult"), {"목재": 30, "석재": 20}, "생산 자재")

func test_produce_full_cost() -> void:
	assert_eq(types.produce_full_cost("catapult"), {"금": 40, "목재": 30, "석재": 20}, "생산 총비용(금+자재)")

func test_missing_id_defaults() -> void:
	assert_eq(types.type_name("nope"), "", "없는 id 이름 빈 문자열")
	assert_eq(types.movement("nope"), 0, "없는 id 이동력 0")
	assert_eq(types.produce_gold("nope"), 0, "없는 id 생산 금 0")
	assert_eq(types.produce_cost("nope"), {}, "없는 id 생산 자재 빈 Dictionary")
	assert_eq(types.produce_full_cost("nope"), {}, "없는 id 생산 총비용 빈 Dictionary")
	assert_eq(types.get_type("nope"), {}, "없는 id 스펙 빈 Dictionary")
