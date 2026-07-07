extends GutTest
## 세력(Faction) 엔티티 테스트 — 속성과 영지 양방향 연결.

const BLUE := Color(0.2, 0.3, 0.8)

var territory: Object

func before_each() -> void:
	territory = load("res://scenes/territory/territory.gd").new("파리", {})

func _faction(name := "프랑스", color := BLUE) -> Object:
	return load("res://scenes/faction/faction.gd").new(name, color)

func test_init_sets_name_and_color() -> void:
	var f := _faction("프랑스", BLUE)
	assert_eq(f.name, "프랑스", "생성 시 이름 설정")
	assert_eq(f.color, BLUE, "생성 시 색상 설정")

func test_territories_empty_on_create() -> void:
	var f := _faction()
	assert_eq(f.territories.size(), 0, "생성 직후 소속 영지는 없음")

func test_add_territory_links_both_ways() -> void:
	var f := _faction()
	f.add_territory(territory)
	assert_true(territory in f.territories, "territories에 영지가 추가된다")
	assert_eq(territory.faction, f, "territory.faction이 이 세력을 가리킨다(양방향)")

func test_add_territory_no_duplicate() -> void:
	var f := _faction()
	f.add_territory(territory)
	f.add_territory(territory)
	assert_eq(f.territories.size(), 1, "같은 영지 중복 추가 방지")
