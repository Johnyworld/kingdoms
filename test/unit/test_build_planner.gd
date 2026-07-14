extends GutTest
## BuildPlanner 배치 유효성 테스트 — footprint · 영지 시야(완성 건물만) · 겹침 · 맵 범위.
## 헥스 인접·반경은 엔진에 의존하므로 실제 헥스 타일셋을 가진 TileMapLayer로 검증한다.

const MAP := 41  # 중앙 기준 반경 5까지 경계에 안 닿을 만큼 넉넉한 정사각 맵.

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func _building(center: Vector2i, type_id: String, under_construction := false) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, center, type_id, under_construction)
	return b

func _territory_with(b) -> Object:
	var t = load("res://scenes/territory/territory.gd").new("파리", {})
	t.add_building(b)
	return t

# --- footprint ---

func test_footprint_is_seven() -> void:
	assert_eq(BuildPlanner.footprint(terrain, _center()).size(), 7, "footprint 기본 = 중심 + 이웃 6")

func test_footprint_hexes_seven_matches_default() -> void:
	assert_eq(BuildPlanner.footprint(terrain, _center(), 7).size(), 7, "hexes=7은 기본과 동일")

func test_footprint_hexes_one_is_center_only() -> void:
	var fp := BuildPlanner.footprint(terrain, _center(), 1)
	assert_eq(fp.size(), 1, "hexes=1이면 중심 1칸만")
	assert_eq(fp[0], _center(), "그 1칸은 중심")

# --- territory_vision ---

func test_territory_vision_from_complete_building() -> void:
	var camp := _building(_center(), "camp")  # 시야 5, 완성
	var t := _territory_with(camp)
	var vis := BuildPlanner.territory_vision(terrain, t, MAP, MAP)
	# 반경 5 누적 = 1 + 3*5*6 = 91
	assert_eq(vis.size(), 91, "완성 캠프 시야(5) 반경 셀 합집합")
	assert_true(vis.has(_center()), "중심 포함")

func test_under_construction_gives_no_vision() -> void:
	var farm := _building(_center(), "farm", true)  # 건설 중
	var t := _territory_with(farm)
	var vis := BuildPlanner.territory_vision(terrain, t, MAP, MAP)
	assert_eq(vis.size(), 0, "건설 중 건물은 시야에 기여 안 함")

# --- buildings_vision (맵의 모든 건물 시야 합집합, fog 계산이 사용) ---

func test_buildings_vision_from_complete_building() -> void:
	var camp := _building(_center(), "camp")  # 시야 5, 완성
	var vis := BuildPlanner.buildings_vision(terrain, [camp], MAP, MAP)
	# 반경 5 누적 = 1 + 3*5*6 = 91 (territory_vision과 같은 규칙)
	assert_eq(vis.size(), 91, "완성 건물 시야(5) 반경 셀 합집합")
	assert_true(vis.has(_center()), "중심 포함")

func test_buildings_vision_completed_farm_contributes() -> void:
	var farm := _building(_center(), "farm")  # 시야 4, 완성
	var vis := BuildPlanner.buildings_vision(terrain, [farm], MAP, MAP)
	# 반경 4 누적 = 1 + 3*4*5 = 61
	assert_eq(vis.size(), 61, "완성 농장 시야(4) 반경 셀 합집합")

func test_buildings_vision_skips_under_construction() -> void:
	var camp := _building(_center(), "camp")                       # 완성, 시야 5
	var farm := _building(_center() + Vector2i(20, 0), "farm", true)  # 건설 중, 기여 X
	var vis := BuildPlanner.buildings_vision(terrain, [camp, farm], MAP, MAP)
	assert_eq(vis.size(), 91, "건설 중 농장은 시야에 기여 안 함(완성 캠프만)")

func test_buildings_vision_empty() -> void:
	assert_eq(BuildPlanner.buildings_vision(terrain, [], MAP, MAP).size(), 0, "건물 없으면 빈 시야")

# --- occupied_cells ---

func test_occupied_cells_one_building() -> void:
	var b := _building(_center(), "camp")
	assert_eq(BuildPlanner.occupied_cells([b]).size(), 7, "건물 1개 = 7셀")

func test_occupied_cells_two_disjoint_buildings() -> void:
	var a := _building(_center(), "camp")
	var b := _building(_center() + Vector2i(10, 0), "town_hall")  # 충분히 떨어져 안 겹침(둘 다 footprint 7)
	assert_eq(BuildPlanner.occupied_cells([a, b]).size(), 14, "안 겹치는 거점 2개 = 14셀")

func test_occupied_cells_empty() -> void:
	assert_eq(BuildPlanner.occupied_cells([]).size(), 0, "건물 없으면 빈 집합")

# --- can_place ---

func _camp_vision() -> Dictionary:
	var camp := _building(_center(), "camp")
	var t := _territory_with(camp)
	return BuildPlanner.territory_vision(terrain, t, MAP, MAP)

func test_can_place_in_vision_on_empty_land() -> void:
	var vis := _camp_vision()
	var spot := _center() + Vector2i(3, 0)  # 시야(5) 안, 캠프와 안 겹침
	assert_true(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}), "시야 안 빈 땅은 배치 가능")

func test_cannot_place_outside_vision() -> void:
	var vis := _camp_vision()
	var far := _center() + Vector2i(20, 0)  # 시야 밖
	assert_false(BuildPlanner.can_place(terrain, far, MAP, MAP, vis, {}), "시야 밖은 배치 불가")

func test_cannot_place_overlapping_building() -> void:
	var vis := _camp_vision()
	var occupied := {}
	for c in BuildPlanner.footprint(terrain, _center()):
		occupied[c] = true  # 캠프가 점유한 셀
	var spot := _center() + Vector2i(1, 0)  # 캠프 footprint와 겹치는 곳
	assert_false(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, occupied), "기존 건물과 겹치면 불가")

func test_can_place_one_hex_ignores_neighbors() -> void:
	# 1헥스 건물은 중심만 판정 — 이웃이 시야 밖·점유여도 중심이 유효하면 배치 가능.
	var spot := _center() + Vector2i(3, 0)
	var vis := {spot: true}   # 중심 1칸만 시야 안(이웃은 시야 밖)
	assert_true(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}, 1), "1헥스는 중심만 유효하면 배치 가능")
	assert_false(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}, 7), "같은 자리라도 7헥스면 이웃 시야 밖이라 불가")

# --- prerequisite_met (거점 티어 기준) ---

func test_prerequisite_camp_tier() -> void:
	# 캠프 거점(tier 0): 1차 생산(채석장·농장·벌목소, 선행 camp)은 참, 집(선행 town_hall)은 거짓.
	var t := _territory_with(_building(_center(), "camp"))
	assert_true(BuildPlanner.prerequisite_met(t, "quarry"), "채석장(선행 camp tier0) 충족")
	assert_true(BuildPlanner.prerequisite_met(t, "farm"), "농장(선행 camp) 충족")
	assert_true(BuildPlanner.prerequisite_met(t, "lumberjack"), "벌목소(선행 camp) 충족")
	assert_false(BuildPlanner.prerequisite_met(t, "house"), "집(선행 town_hall tier1) 미충족")

func test_prerequisite_town_hall_tier() -> void:
	# 마을회관 거점(tier 1): 농장/집/벌목소 충족.
	var t := _territory_with(_building(_center(), "town_hall"))
	assert_true(BuildPlanner.prerequisite_met(t, "farm"), "마을회관 tier1 → 농장 충족")
	assert_true(BuildPlanner.prerequisite_met(t, "house"), "→ 집 충족")
	assert_true(BuildPlanner.prerequisite_met(t, "quarry"), "→ 채석장(하위 티어)도 충족")

func test_prerequisite_castle_tier_keeps_lower() -> void:
	# 성 거점(tier 2)이어도 하위 티어 선행(town_hall) 유지 — 건물 존재가 아니라 티어 비교.
	var t := _territory_with(_building(_center(), "castle"))
	assert_true(BuildPlanner.prerequisite_met(t, "farm"), "성 tier2 → 농장(선행 town_hall) 계속 충족")

func test_prerequisite_under_construction_not_met() -> void:
	# 건설 중 거점은 미완성이라 티어에 안 잡힘.
	var t := _territory_with(_building(_center(), "town_hall", true))  # 건설 중
	assert_false(BuildPlanner.prerequisite_met(t, "farm"), "건설 중 마을회관은 아직 미충족")

# --- can_build (선행 + 자재 + 필요인원 종합) ---

func _territory_with_res(camp, res: Dictionary) -> Object:
	var t = load("res://scenes/territory/territory.gd").new("파리", res)
	t.add_building(camp)
	return t

func test_can_build_true_when_all_met() -> void:
	var camp := _building(_center(), "camp")
	var t := _territory_with_res(camp, {"인구": 10, "목재": 20})
	assert_true(BuildPlanner.can_build(t, "quarry"), "선행 camp·목재10·인원1 모두 충족")

func test_can_build_false_short_population() -> void:
	# 채석장은 1차 생산 전환으로 required_pop 0 → 고정 노동력 게이트는 공성 작업장(2)으로 검증.
	var th := _building(_center(), "town_hall")
	var t := _territory_with_res(th, {"인구": 0, "목재": 30, "석재": 30})  # 인구 0 < 2
	assert_false(BuildPlanner.can_build(t, "siege_workshop"), "인구가 필요인원(2) 미만이면 거짓")

func test_can_build_false_short_materials() -> void:
	var camp := _building(_center(), "camp")
	var t := _territory_with_res(camp, {"인구": 10, "목재": 0})  # 목재 부족
	assert_false(BuildPlanner.can_build(t, "quarry"), "자재 부족이면 거짓")

func test_can_build_false_prerequisite() -> void:
	var camp := _building(_center(), "camp")
	var t := _territory_with_res(camp, {"인구": 10, "목재": 20, "밀": 50})
	assert_false(BuildPlanner.can_build(t, "house"), "캠프 티어(마을회관 미만)면 집 불가(선행)")

# --- can_upgrade (거점 티어 업그레이드) ---

func test_can_upgrade_camp_with_funds() -> void:
	var camp := _building(_center(), "camp")
	# 마을회관 비용 목재10·석재10·밀20 충분.
	var t := _territory_with_res(camp, {"목재": 20, "석재": 20, "밀": 50})
	assert_true(BuildPlanner.can_upgrade(t, camp), "캠프 + 마을회관 비용 충분 → 업그레이드 가능")

func test_can_upgrade_false_short_funds() -> void:
	var camp := _building(_center(), "camp")
	var t := _territory_with_res(camp, {"목재": 0, "석재": 0, "밀": 0})
	assert_false(BuildPlanner.can_upgrade(t, camp), "비용 부족이면 불가")

func test_can_upgrade_false_at_castle() -> void:
	var castle := _building(_center(), "castle")
	var t := _territory_with_res(castle, {"석재": 999, "밀": 999})
	assert_false(BuildPlanner.can_upgrade(t, castle), "성은 최종 티어라 업그레이드 없음")

func test_cannot_place_at_map_edge() -> void:
	# 모서리(0,0)는 이웃이 맵 밖 → footprint 일부가 범위 밖.
	# 시야는 footprint 전부를 포함시켜, 오직 '범위 밖' 조건만으로 걸리는지 확인한다.
	var edge := Vector2i(0, 0)
	var vis := {}
	for c in BuildPlanner.footprint(terrain, edge):
		vis[c] = true
	assert_false(BuildPlanner.can_place(terrain, edge, MAP, MAP, vis, {}), "맵 가장자리는 이웃이 범위 밖 → 불가")

# --- 지형 제한 배치 (1차 생산) → docs/spec/features/production.md ---

func test_can_place_terrain_restricted() -> void:
	var spot := Vector2i(10, 10)
	var vis := {spot: true}
	terrain.set_cell(spot, Terrain.FOREST, Terrain.ATLAS)
	assert_true(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}, 1, [Terrain.FOREST]), "숲이면 벌목소 배치 가능")
	terrain.set_cell(spot, Terrain.GRASS, Terrain.ATLAS)
	assert_false(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}, 1, [Terrain.FOREST]), "초원이면 벌목소 불가")

func test_can_place_no_terrain_restriction() -> void:
	var spot := Vector2i(10, 10)
	var vis := {spot: true}
	terrain.set_cell(spot, Terrain.GRASS, Terrain.ATLAS)
	assert_true(BuildPlanner.can_place(terrain, spot, MAP, MAP, vis, {}, 1, []), "제한 없으면 지형 무관")

# --- 마을회관 인접 셀 (비-생산 건물 배치) ---

func test_town_hall_adjacent_cells() -> void:
	var th := _building(_center(), "town_hall")   # footprint 7
	var cells: Dictionary = BuildPlanner.town_hall_adjacent_cells(terrain, [th], MAP, MAP)
	assert_gt(cells.size(), 0, "마을회관 인접 셀 존재")
	assert_false(cells.has(Vector2i(0, 0)), "먼 셀은 인접 아님")
	for c in th.cells:
		assert_false(cells.has(c), "footprint 셀 자체는 인접 집합에서 제외")

func test_town_hall_adjacent_empty_for_camp_only() -> void:
	var camp := _building(_center(), "camp")   # tier 0 < 마을회관
	var cells: Dictionary = BuildPlanner.town_hall_adjacent_cells(terrain, [camp], MAP, MAP)
	assert_eq(cells.size(), 0, "캠프만 있으면 마을회관 인접 없음")

# --- 거점 인접 셀 (2차 생산 배치) → docs/spec/features/processing.md ---

func test_center_adjacent_includes_camp() -> void:
	var camp := _building(_center(), "camp")   # tier 0
	var all_tier: Dictionary = BuildPlanner.center_adjacent_cells(terrain, [camp], MAP, MAP, 0)
	var th_tier: Dictionary = BuildPlanner.center_adjacent_cells(terrain, [camp], MAP, MAP, 1)
	assert_gt(all_tier.size(), 0, "min_tier 0 → 캠프 인접 셀 포함(2차 생산)")
	assert_eq(th_tier.size(), 0, "min_tier 1(마을회관) → 캠프는 제외")
