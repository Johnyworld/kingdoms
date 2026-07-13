extends GutTest
## 공성 유닛 인스턴스(SiegeUnit) 순수 테스트. → docs/spec/features/siege-engines.md

var SiegeUnit = load("res://scenes/siege/siege_unit.gd")

func test_default_is_catapult() -> void:
	var u = SiegeUnit.new()
	assert_eq(u.type_id, "catapult", "기본 종류 투석기")
	assert_eq(u.unit_name(), "투석기", "이름 = 카탈로그 이름")
	assert_eq(u.movement(), 2, "견인 이동력 2")
	assert_eq(u.fire_range(), 5, "투석 사거리 5")
	assert_eq(u.attack(), 50, "공격력 50")
	assert_eq(u.max_hp(), 60, "최대 내구도 60")

func test_starts_at_full_hp() -> void:
	var u = SiegeUnit.new()
	assert_eq(u.hit_points, u.max_hp(), "생성 직후 풀 내구도")
	assert_eq(u.hit_points, 60, "현재 HP 60")

func test_explicit_type_id() -> void:
	var u = SiegeUnit.new("catapult")
	assert_eq(u.type_id, "catapult", "명시한 종류 유지")
	assert_eq(u.unit_name(), "투석기", "이름")
