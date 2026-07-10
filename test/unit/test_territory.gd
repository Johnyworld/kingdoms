extends GutTest
## 영지(Territory) 엔티티 테스트 — 자원·세력·건물 연결.

var building: Node2D

func before_each() -> void:
	building = load("res://scenes/building/building.gd").new()
	add_child_autofree(building)

func _territory(name := "파리", res := {}) -> Object:
	return load("res://scenes/territory/territory.gd").new(name, res)

func test_init_sets_name_and_resources() -> void:
	var t := _territory("파리", {"인구": 10, "밀": 50})
	assert_eq(t.name, "파리", "생성 시 이름 설정")
	assert_eq(t.resources.get("인구"), 10, "인구 자원")
	assert_eq(t.resources.get("밀"), 50, "밀 자원")

func test_empty_on_create() -> void:
	var t := _territory()
	assert_eq(t.buildings.size(), 0, "생성 직후 건물 없음")
	assert_null(t.faction, "생성 직후 세력 없음")

func test_add_building_links_both_ways() -> void:
	var t := _territory()
	t.add_building(building)
	assert_true(building in t.buildings, "buildings에 건물 추가")
	assert_eq(building.territory, t, "building.territory가 이 영지를 가리킴(양방향)")

func test_add_building_no_duplicate() -> void:
	var t := _territory()
	t.add_building(building)
	t.add_building(building)
	assert_eq(t.buildings.size(), 1, "같은 건물 중복 추가 방지")

# --- 건물 제거 (캠프 점령 파괴) ---

func test_remove_building_unlinks_both_ways() -> void:
	var t := _territory()
	t.add_building(building)
	t.remove_building(building)
	assert_false(building in t.buildings, "buildings에서 제거된다")
	assert_null(building.territory, "building.territory가 null로 되돌아간다")

func test_remove_building_not_owned_is_noop() -> void:
	var t := _territory()
	t.remove_building(building)   # 편입한 적 없음
	assert_eq(t.buildings.size(), 0, "보유하지 않은 건물 제거는 no-op")

# --- 자원 검사·차감 (건축) ---

func test_can_afford_true_when_enough() -> void:
	var t := _territory("파리", {"목재": 10, "밀": 10})
	assert_true(t.can_afford({"목재": 5, "밀": 5}), "자원이 충분하면 참")

func test_can_afford_false_when_short() -> void:
	var t := _territory("파리", {"목재": 3})
	assert_false(t.can_afford({"목재": 5}), "자원이 부족하면 거짓")

func test_can_afford_empty_cost_always_true() -> void:
	var t := _territory("파리", {})
	assert_true(t.can_afford({}), "빈 비용은 항상 참")

func test_can_afford_missing_resource_false() -> void:
	var t := _territory("파리", {})  # 철 보유 없음
	assert_false(t.can_afford({"철": 1}), "보유 없는 자원 요구는 거짓")

func test_spend_deducts_resources() -> void:
	var t := _territory("파리", {"목재": 10, "밀": 10})
	t.spend({"목재": 5, "밀": 5})
	assert_eq(t.resources["목재"], 5, "목재 5 차감")
	assert_eq(t.resources["밀"], 5, "밀 5 차감")
