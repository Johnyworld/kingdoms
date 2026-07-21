extends GutTest
## 건물(Building) 점유 영역·종류 스펙·맵 라벨 테스트.
## 자원·이름·세력은 영지(Territory)가 보유하므로, 맵 라벨은 영지에서 온다.

const MAP := 41
const BLUE := Color(0.2, 0.3, 0.8)

var terrain: TileMapLayer
var building: Node2D

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	building = load("res://scenes/building/building.gd").new()
	add_child_autofree(building)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func _camp() -> void:
	building.setup(terrain, _center(), "camp")

## 이름·세력을 가진 영지에 이 건물을 편입한다.
func _join_territory() -> void:
	var f = load("res://scenes/faction/faction.gd").new("프랑스", BLUE)
	var t = load("res://scenes/territory/territory.gd").new("파리", {})
	f.add_territory(t)
	t.add_building(building)

# --- 수비 배지 (defender_count, 표시 전용) ---

func test_defender_count_default_zero() -> void:
	assert_eq(building.defender_count, 0, "생성 직후 수비 인원 0")

func test_defender_count_settable() -> void:
	building.defender_count = 4   # game.gd가 중심 타일 점거 방어 부대 인원으로 채운다
	assert_eq(building.defender_count, 4, "수비 인원 표시값 설정 가능")

# --- 1차 생산 (생산포인트) → docs/spec/features/production.md ---

func _lumberjack() -> void:
	building.setup(terrain, _center(), "lumberjack")

func test_production_defaults() -> void:
	_lumberjack()
	assert_eq(building.production_points, 0, "PP 기본 0")
	assert_true(building.is_primary_production(), "벌목소는 1차 생산")
	assert_eq(building.produces(), "목재", "산출 목재")
	assert_eq(building.buildable_terrains(), [Terrain.FOREST], "숲에만")

func test_tick_production_accrues_by_distance() -> void:
	# 거리 기반: 매 턴 PP += 1, PP ≥ 거리면 자원 1 산출.
	_lumberjack()
	var out: Array = []
	for i in 6:
		out.append(building.tick_production(3))
	assert_eq(out, [0, 0, 1, 0, 0, 1], "거리3 → 3턴마다 자원 1")
	assert_eq(building.production_points, 0, "6턴 후 PP 0")

func test_tick_production_distance_one() -> void:
	_lumberjack()
	assert_eq(building.tick_production(1), 1, "거리1 → 매 턴 1 산출")
	assert_eq(building.production_points, 0, "PP 항상 0")

func test_tick_production_guards() -> void:
	_lumberjack()
	assert_eq(building.tick_production(0), 0, "거리 0 → 0(방어)")
	assert_eq(building.production_points, 0, "PP 불변")

func test_production_rate() -> void:
	_lumberjack()
	assert_almost_eq(building.production_rate(3), 0.333, 0.001, "1÷거리3 ≈ 0.333")
	assert_eq(building.production_rate(1), 1.0, "거리1 → 1.0")
	assert_eq(building.production_rate(0), 0.0, "거리 0 → 0")

func test_non_production_building() -> void:
	_camp()
	assert_false(building.is_primary_production(), "캠프는 1차 생산 아님")
	assert_eq(building.produces(), "", "산출 없음")
	assert_eq(building.buildable_terrains(), [], "지형 제한 없음")
	assert_eq(building.tick_production(5), 0, "생산 없음(produces \"\") → tick 0")

# --- 점유 영역 ---

func test_occupies_seven_hexes() -> void:
	_camp()
	assert_eq(building.cells.size(), 7, "건물은 중심 + 이웃 6 = 7헥스")

func test_small_building_occupies_one_hex() -> void:
	building.setup(terrain, _center(), "house")  # footprint 1
	assert_eq(building.cells.size(), 1, "소형 건물(집)은 중심 1헥스만 차지")
	assert_eq(building.cells[0], _center(), "그 1칸은 중심")

func test_center_cell_is_setup_cell() -> void:
	_camp()
	assert_eq(building.center_cell(), _center(), "center_cell은 setup에 넘긴 중심")

func test_contains_center_and_neighbors() -> void:
	_camp()
	assert_true(building.contains_cell(_center()), "중심 셀 포함")
	for n in terrain.get_surrounding_cells(_center()):
		assert_true(building.contains_cell(n), "이웃 6칸 포함: %s" % n)

func test_does_not_contain_far_cell() -> void:
	_camp()
	assert_false(building.contains_cell(_center() + Vector2i(5, 5)), "먼 셀은 미포함")

# --- 종류 스펙 ---

func test_camp_type_vision_and_label() -> void:
	_camp()
	assert_eq(building.building_type, "camp", "종류 id 저장")
	assert_eq(building.vision, 5, "캠프 시야 5")
	assert_eq(building.label(), "캠프", "종류 라벨 = 캠프")

func test_unknown_type_defaults() -> void:
	building.setup(terrain, _center(), "없는id")
	assert_eq(building.vision, 0, "미지 종류 시야 0")
	assert_eq(building.label(), "", "미지 종류 라벨 빈 문자열")

# --- 세력 위임 (faction / faction_name) ---

func test_faction_delegates_via_territory() -> void:
	_camp()
	_join_territory()
	assert_eq(building.faction_name(), "프랑스", "영지 경유 세력 이름")
	assert_eq(building.faction().name, "프랑스", "faction()은 영지의 세력 객체")

func test_faction_empty_without_territory() -> void:
	_camp()
	assert_null(building.faction(), "영지 없으면 세력 null")
	assert_eq(building.faction_name(), "", "영지 없으면 세력 이름 빈 문자열")

func test_faction_empty_when_territory_unowned() -> void:
	_camp()
	var t = load("res://scenes/territory/territory.gd").new("무주지", {})
	t.add_building(building)
	assert_null(building.faction(), "무소속 영지면 세력 null")
	assert_eq(building.faction_name(), "", "무소속 영지면 빈 문자열")

# --- 영지 / 맵 라벨 ---

func test_default_no_territory() -> void:
	assert_null(building.territory, "기본 소속 영지 없음")

func test_map_labels_from_territory() -> void:
	_camp()
	_join_territory()
	var lines: Array = building.map_label_lines()
	assert_eq(lines.size(), 2, "영지명 + 세력 = 2줄")
	assert_eq(lines[0]["text"], "파리", "첫 줄은 영지 이름")
	assert_eq(lines[1]["text"], "프랑스", "둘째 줄은 세력명")
	assert_eq(lines[1]["color"], BLUE, "세력 줄 색상 = 세력 색상")

func test_map_labels_empty_without_territory() -> void:
	_camp()
	assert_eq(building.map_label_lines().size(), 0, "영지 없으면 빈 배열")

# --- 건설 중 상태 (건축) ---

func test_complete_by_default() -> void:
	_camp()
	assert_true(building.is_complete(), "기본 setup은 즉시 완성")

func test_farm_under_construction() -> void:
	building.setup(terrain, _center(), "farm", true)
	assert_false(building.is_complete(), "건설 중 상태")
	assert_eq(building.remaining_turns, 3, "농장 build_turns = 3")

func test_advance_construction_completes_on_last_turn() -> void:
	building.setup(terrain, _center(), "iron_mine", true)   # build_turns 5
	for i in 4:
		assert_false(building.advance_construction(), "%d턴: 아직 미완성" % (i + 1))
	assert_true(building.advance_construction(), "5턴: 완성되는 호출만 true")
	assert_true(building.is_complete(), "완성됨")

func test_refund_on_demolish_complete_uses_salvage() -> void:
	building.setup(terrain, _center(), "farm")   # 완성
	assert_eq(building.refund_on_demolish(), building.demolish_refund(), "완성은 demolish_refund(카탈로그 salvage)")

func test_refund_on_demolish_under_construction_full_at_start() -> void:
	building.setup(terrain, _center(), "iron_mine", true)   # remaining 5 / build_turns 5, build_cost 목재15
	assert_eq(building.refund_on_demolish(), {"목재": 15}, "갓 시작(진행 0) → build_cost 전액")

func test_refund_on_demolish_under_construction_partial() -> void:
	building.setup(terrain, _center(), "iron_mine", true)
	building.advance_construction()   # remaining 4 / 5
	building.advance_construction()   # remaining 3 / 5
	assert_eq(building.refund_on_demolish(), {"목재": 9}, "2턴 진행 → floor(15×3/5)=9")

func test_advance_construction_on_complete_is_noop() -> void:
	_camp()
	assert_false(building.advance_construction(), "완성 건물은 no-op false")
	assert_true(building.is_complete(), "상태 불변")

# flat 생산·2차 가공은 폐지됨 — 모든 생산은 tick_production(1차, 거리 기반)로 검증한다. → production.md

# --- 인구 상한 기여 (pop_cap) ---

func _typed(center: Vector2i, type_id: String) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, center, type_id)
	return b

func test_pop_cap_complete_buildings() -> void:
	assert_eq(_typed(Vector2i(20, 20), "camp").pop_cap(), 0, "캠프 티어 상한 0")
	assert_eq(_typed(Vector2i(28, 28), "town_hall").pop_cap(), 10, "마을회관 티어 상한 10")
	assert_eq(_typed(Vector2i(10, 10), "castle").pop_cap(), 20, "성 티어 상한 20")
	assert_eq(_typed(Vector2i(14, 14), "house").pop_cap(), 2, "완성 집 상한 기여 2")
	assert_eq(_typed(Vector2i(4, 4), "farm").pop_cap(), 0, "농장은 상한 기여 없음")

# --- 거점 업그레이드 (upgrade_to) ---

func test_upgrade_to_next_tier() -> void:
	_camp()
	building.upgrade_to("town_hall")
	assert_eq(building.building_type, "town_hall", "종류가 마을회관으로")
	assert_eq(building.vision, 6, "시야 6으로 교체")
	assert_eq(building.pop_cap(), 10, "인구 상한 10")
	assert_true(building.is_complete(), "업그레이드 후 완성 상태")
	assert_eq(building.cells.size(), 7, "footprint 7 유지")
	assert_eq(building.center_cell(), _center(), "위치 유지")

func test_pop_cap_zero_under_construction() -> void:
	building.setup(terrain, _center(), "house", true)  # 건설 중
	assert_eq(building.pop_cap(), 0, "건설 중 집은 상한 기여 0")
	for i in range(4):
		building.advance_construction()
	assert_eq(building.pop_cap(), 2, "완성 후 집 상한 기여 2")

# --- 철거 환급 (demolish_refund) ---

func test_demolish_refund_by_type() -> void:
	building.setup(terrain, _center(), "farm")
	assert_eq(building.demolish_refund(), {"목재": 1}, "농장 철거 환급(자재만)")
	var house = load("res://scenes/building/building.gd").new()
	add_child_autofree(house)
	house.setup(terrain, Vector2i(30, 30), "house")
	assert_eq(house.demolish_refund(), {"목재": 2}, "집 철거 환급")

func test_demolish_refund_same_under_construction() -> void:
	building.setup(terrain, _center(), "farm", true)  # 건설 중
	assert_eq(building.demolish_refund(), {"목재": 1}, "건설 중에도 같은 환급")

# --- 필요인원 (required_pop) — 폐지, 모든 건물 0 ---

func test_required_pop_abolished() -> void:
	for id in ["lumberjack", "iron_mine", "farm", "house", "camp"]:
		var b: Node2D = load("res://scenes/building/building.gd").new()
		add_child_autofree(b)
		b.setup(terrain, Vector2i(30, 30), id)
		assert_eq(b.required_pop(), 0, "%s 필요인원 0(폐지)" % id)
