extends GutTest
## 세력(Faction) 엔티티 테스트 — 속성과 영지 양방향 연결.

const BLUE := Color(0.2, 0.3, 0.8)

var territory: Object

func before_each() -> void:
	territory = load("res://scenes/territory/territory.gd").new("창천성", {})

func _faction(name := "푸른 왕국", color := BLUE) -> Object:
	return load("res://scenes/faction/faction.gd").new(name, color)

func test_init_sets_name_and_color() -> void:
	var f := _faction("푸른 왕국", BLUE)
	assert_eq(f.name, "푸른 왕국", "생성 시 이름 설정")
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

# --- 영지 제거·이전 (캠프 점령 흡수) ---

func test_remove_territory_unlinks_both_ways() -> void:
	var f := _faction()
	f.add_territory(territory)
	f.remove_territory(territory)
	assert_false(territory in f.territories, "territories에서 제거된다")
	assert_null(territory.faction, "territory.faction이 null로 되돌아간다")

func test_transfer_territory_between_factions() -> void:
	var old_f := _faction("사막 술탄국")
	var new_f := _faction("푸른 왕국")
	old_f.add_territory(territory)
	old_f.remove_territory(territory)
	new_f.add_territory(territory)
	assert_eq(territory.faction, new_f, "이전 후 소속은 새 세력")
	assert_true(territory in new_f.territories, "새 세력에 포함")
	assert_false(territory in old_f.territories, "이전 세력에서 제외")

func test_remove_territory_not_owned_is_noop() -> void:
	var f := _faction()
	f.remove_territory(territory)   # 보유한 적 없음
	assert_eq(f.territories.size(), 0, "보유하지 않은 영지 제거는 no-op")
