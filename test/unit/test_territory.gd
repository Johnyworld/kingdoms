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
