extends GutTest
## 영지(Territory) 엔티티 테스트 — 자원·세력·건물 연결.

var building: Node2D
var terrain: TileMapLayer

func before_each() -> void:
	building = load("res://scenes/building/building.gd").new()
	add_child_autofree(building)
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _territory(name := "파리", res := {}) -> Object:
	return load("res://scenes/territory/territory.gd").new(name, res)

## 지정 종류의 건물을 만들어 반환한다(pop_cap 테스트용). 겹치지 않게 center를 달리 넘긴다.
func _typed_building(center: Vector2i, type_id: String, under_construction := false) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, center, type_id, under_construction)
	return b

func test_init_sets_name_and_resources() -> void:
	var t := _territory("파리", {"인구": 10, "식량": 50})
	assert_eq(t.name, "파리", "생성 시 이름 설정")
	assert_eq(t.resources.get("인구"), 10, "인구 자원")
	assert_eq(t.resources.get("식량"), 50, "식량 자원")

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
	var t := _territory("파리", {"목재": 10, "식량": 10})
	assert_true(t.can_afford({"목재": 5, "식량": 5}), "자원이 충분하면 참")

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
	var t := _territory("파리", {"목재": 10, "식량": 10})
	t.spend({"목재": 5, "식량": 5})
	assert_eq(t.resources["목재"], 5, "목재 5 차감")
	assert_eq(t.resources["식량"], 5, "식량 5 차감")

# --- 인구 상한 (population_cap) + 자연 증가 (grow_population) ---

func test_population_cap_camp_zero_town_hall_ten() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(20, 20), "camp"))
	assert_eq(t.population_cap(), 0, "캠프 티어 → 상한 0")
	# 마을회관 거점은 상한 10.
	var t2 := _territory()
	t2.add_building(_typed_building(Vector2i(20, 20), "town_hall"))
	assert_eq(t2.population_cap(), 10, "마을회관 티어 → 상한 10")

func test_population_cap_with_houses() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(20, 20), "town_hall"))  # 10
	t.add_building(_typed_building(Vector2i(30, 30), "house"))
	assert_eq(t.population_cap(), 12, "마을회관 + 집 1채 → 12")
	t.add_building(_typed_building(Vector2i(32, 30), "house"))
	assert_eq(t.population_cap(), 14, "마을회관 + 집 2채 → 14")

func test_population_cap_ignores_under_construction() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(20, 20), "town_hall"))  # 10
	t.add_building(_typed_building(Vector2i(30, 30), "house", true))  # 건설 중
	assert_eq(t.population_cap(), 10, "건설 중 집은 상한에 기여 안 함")

func test_grow_population_up_to_cap() -> void:
	var t := _territory("파리", {"인구": 10})
	t.add_building(_typed_building(Vector2i(20, 20), "town_hall"))  # 10
	t.add_building(_typed_building(Vector2i(30, 30), "house"))      # 상한 12
	t.grow_population()
	assert_eq(t.resources["인구"], 11, "인구 10 → 11")
	t.grow_population()
	assert_eq(t.resources["인구"], 12, "11 → 12(상한)")
	t.grow_population()
	assert_eq(t.resources["인구"], 12, "상한 도달 후 유지(넘지 않음)")

func test_grow_population_no_change_at_cap() -> void:
	var t := _territory("파리", {"인구": 10})
	t.add_building(_typed_building(Vector2i(20, 20), "town_hall"))  # 상한 10
	t.grow_population()
	assert_eq(t.resources["인구"], 10, "인구가 상한과 같으면 변화 없음")

# --- 철거 (demolish) ---

func test_demolish_removes_and_refunds() -> void:
	var t := _territory("파리", {"인구": 5, "목재": 0})
	var farm := _typed_building(Vector2i(20, 20), "farm")
	t.add_building(farm)
	t.demolish(farm)
	assert_false(farm in t.buildings, "철거된 건물은 buildings에서 빠짐")
	assert_null(farm.territory, "farm.territory == null")
	assert_eq(t.resources["인구"], 5, "농장(1차 생산)은 required_pop 0 — 노동력 반환 없음")
	assert_eq(t.resources["목재"], 1, "자재 환급 +1(demolish_refund)")

func test_demolish_under_construction_refunds_partial_build_cost() -> void:
	# 건설 중 철광(build_turns 5, build_cost 목재15) 2턴 진행(remaining 3) 철거 → floor(15×3/5)=9 환급.
	var t := _territory("파리", {"인구": 5, "목재": 0})
	var mine := _typed_building(Vector2i(20, 20), "iron_mine", true)
	mine.advance_construction()   # remaining 4 / 5
	mine.advance_construction()   # remaining 3 / 5
	t.add_building(mine)
	t.demolish(mine)
	assert_eq(t.resources["목재"], 9, "건설 중 부분 환급 목재 9(build_cost 비례)")
	assert_eq(t.resources["인구"], 5, "required_pop 폐지 — 노동력 반환 없음")

func test_demolish_creates_missing_resource_key() -> void:
	var t := _territory("파리", {})  # 목재·인구 키 없음
	var house := _typed_building(Vector2i(20, 20), "house")
	t.add_building(house)
	t.demolish(house)
	assert_eq(t.resources.get("목재"), 2, "없던 자원 키도 환급으로 생성")

func test_demolish_not_owned_is_noop() -> void:
	var t := _territory("파리", {"목재": 5})
	var farm := _typed_building(Vector2i(20, 20), "farm")  # 편입 안 함
	t.demolish(farm)
	assert_eq(t.resources["목재"], 5, "보유하지 않은 건물 철거는 환급 없음")

# --- 건설 지불 (build_pay) — 자재만(required_pop 폐지) ---

func test_build_pay_farm_deducts_materials_only() -> void:
	var t := _territory("파리", {"인구": 10, "목재": 20, "식량": 50})
	t.build_pay("farm")
	assert_eq(t.resources["목재"], 15, "목재 5 차감")
	assert_eq(t.resources["인구"], 10, "required_pop 폐지 — 인구 차감 없음")

func test_build_pay_iron_mine_no_labor() -> void:
	var t := _territory("파리", {"인구": 10, "목재": 20})
	t.build_pay("iron_mine")
	assert_eq(t.resources["목재"], 5, "목재 15 차감")
	assert_eq(t.resources["인구"], 10, "인구 차감 없음")

func test_build_pay_siege_workshop_no_labor() -> void:
	var t := _territory("파리", {"인구": 10, "목재": 30, "철": 30})
	t.build_pay("siege_workshop")
	assert_eq(t.resources["목재"], 10, "목재 20 차감")
	assert_eq(t.resources["철"], 20, "철 10 차감")
	assert_eq(t.resources["인구"], 10, "required_pop 폐지 — 인구 차감 없음")

# --- 완성 건물 판정 (공성 작업장 생산 게이트) → docs/spec/features/siege-engines.md ---

func test_has_completed_building_true() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(30, 30), "siege_workshop"))   # 완성
	assert_true(t.has_completed_building("siege_workshop"), "완성 작업장 있으면 참")

func test_has_completed_building_under_construction() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(31, 31), "siege_workshop", true))   # 건설 중
	assert_false(t.has_completed_building("siege_workshop"), "건설 중 작업장만 있으면 거짓")

func test_has_completed_building_absent() -> void:
	var t := _territory()
	t.add_building(_typed_building(Vector2i(32, 32), "farm"))
	assert_false(t.has_completed_building("siege_workshop"), "작업장 없으면 거짓")

# --- changed 시그널 (event-driven UI 갱신의 근거) → docs/spec/entities/Territory.md ---

func test_changed_on_resource_mutations() -> void:
	var t := _territory("파리", {"목재": 10})
	watch_signals(t)
	t.spend({"목재": 3})
	assert_signal_emit_count(t, "changed", 1, "spend → changed 1회(자원별 아님)")
	t.add_resource("목재", 2)
	assert_signal_emit_count(t, "changed", 2, "add_resource → changed")
	assert_eq(t.resources["목재"], 9, "10 - 3 + 2")

func test_changed_on_building_mutations() -> void:
	var t := _territory()
	watch_signals(t)
	t.add_building(building)
	assert_signal_emit_count(t, "changed", 1, "add_building → changed")
	t.add_building(building)
	assert_signal_emit_count(t, "changed", 1, "중복 추가는 no-op(방출 없음)")
	t.remove_building(building)
	assert_signal_emit_count(t, "changed", 2, "remove_building → changed")
	t.remove_building(building)
	assert_signal_emit_count(t, "changed", 2, "미보유 제거는 no-op(방출 없음)")

func test_changed_on_faction_change() -> void:
	var t := _territory()
	var f = load("res://scenes/faction/faction.gd").new("A", Color.RED)
	watch_signals(t)
	f.add_territory(t)
	assert_signal_emit_count(t, "changed", 1, "세력 편입 → changed(faction setter)")
	f.add_territory(t)
	assert_signal_emit_count(t, "changed", 1, "같은 세력 재편입은 no-op")

func test_changed_on_grow_population() -> void:
	var t := _territory("파리", {"인구": 0})
	t.add_building(_typed_building(Vector2i(20, 20), "house"))   # 상한 2
	watch_signals(t)
	t.grow_population()
	assert_signal_emit_count(t, "changed", 1, "인구 성장 → changed")
	t.resources["인구"] = 2
	t.grow_population()
	assert_signal_emit_count(t, "changed", 1, "상한이면 변화 없음 → 방출 없음")

# --- 소유권 이전 (transfer_to) → docs/spec/features/camp-capture.md ---

func test_transfer_to_moves_between_factions() -> void:
	var t := _territory()
	var a = load("res://scenes/faction/faction.gd").new("A", Color.RED)
	var b = load("res://scenes/faction/faction.gd").new("B", Color.BLUE)
	a.add_territory(t)
	t.transfer_to(b)
	assert_false(t in a.territories, "이전 세력에서 분리")
	assert_true(t in b.territories, "새 세력에 편입")
	assert_eq(t.faction, b, "faction 갱신")

func test_transfer_to_null_detaches() -> void:
	var t := _territory()
	var a = load("res://scenes/faction/faction.gd").new("A", Color.RED)
	a.add_territory(t)
	t.transfer_to(null)
	assert_false(t in a.territories, "세력에서 분리")
	assert_null(t.faction, "무소속")

# --- Faction.center_count (세력 유지·캠프 철거 게이트) → docs/spec/entities/Faction.md ---

func test_faction_center_count() -> void:
	var f = load("res://scenes/faction/faction.gd").new("A", Color.RED)
	assert_eq(f.center_count(), 0, "영지 없으면 0")
	var t1 := _territory("영지1")
	f.add_territory(t1)
	t1.add_building(_typed_building(Vector2i(10, 10), "camp"))
	t1.add_building(_typed_building(Vector2i(20, 20), "farm"))   # 비거점 — 안 셈
	var t2 := _territory("영지2")
	f.add_territory(t2)
	t2.add_building(_typed_building(Vector2i(30, 30), "town_hall"))
	assert_eq(f.center_count(), 2, "캠프 + 마을회관 = 2(농장 제외)")

func test_transfer_to_same_faction_noop() -> void:
	var t := _territory()
	var a = load("res://scenes/faction/faction.gd").new("A", Color.RED)
	a.add_territory(t)
	watch_signals(t)
	t.transfer_to(a)
	assert_signal_emit_count(t, "changed", 0, "같은 세력 재이전은 no-op(스퓨리어스 방출 없음)")
	assert_true(t in a.territories, "목록 유지")
