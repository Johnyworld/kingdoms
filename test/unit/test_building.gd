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
	building.defender_count = 4   # game.gd가 중심 타일 주둔 부대 인원으로 채운다
	assert_eq(building.defender_count, 4, "수비 인원 표시값 설정 가능")

# --- 성벽 (wall_level / is_walled) ---

func test_wall_level_default_zero() -> void:
	_camp()
	assert_eq(building.wall_level, 0, "생성 직후 성벽 없음")
	assert_false(building.is_walled(), "wall_level 0이면 is_walled 거짓")
	assert_eq(building.wall_hp, 0, "생성 직후 성벽 내구도 0")

func test_is_walled_when_level_set() -> void:
	_camp()
	building.wall_level = 1
	assert_true(building.is_walled(), "wall_level 1이면 is_walled 참")

func test_wall_hp_settable() -> void:
	_camp()
	building.wall_hp = 180
	assert_eq(building.wall_hp, 180, "성벽 내구도 설정 가능")

# --- 성문 (gate_cell / gate_hp / gate_broken) ---

func test_gate_cell_is_ring_cell_and_stable() -> void:
	_camp()   # footprint 7 (중심 + ring 6)
	var gc: Vector2i = building.gate_cell()
	assert_ne(gc, building.center_cell(), "성문은 중심이 아닌 ring 셀")
	assert_true(gc in building.cells, "성문 셀은 footprint 안")
	assert_eq(building.gate_cell(), gc, "반복 호출에 동일(결정론적)")

func test_gate_hp_default_and_not_broken() -> void:
	_camp()
	assert_eq(building.gate_hp, 0, "생성 직후 성문 내구도 0")
	assert_false(building.gate_broken(), "성벽 없으면 성문 파괴 아님")

func test_gate_broken_requires_wall_and_zero_hp() -> void:
	_camp()
	building.wall_level = 1
	building.gate_hp = 0
	assert_true(building.gate_broken(), "성벽 있고 성문 0 → 파괴(통로 개방)")
	building.gate_hp = 120
	assert_false(building.gate_broken(), "성문 내구도 남으면 파괴 아님")
	building.wall_level = 0
	building.gate_hp = 0
	assert_false(building.gate_broken(), "성벽 없으면 성문 무의미")

# --- 1차 생산 (생산포인트) → docs/spec/features/production.md ---

func _lumberjack() -> void:
	building.setup(terrain, _center(), "lumberjack")

func test_production_defaults() -> void:
	_lumberjack()
	assert_eq(building.production_points, 0, "PP 기본 0")
	assert_eq(building.workers, 0, "인원 기본 0")
	assert_true(building.is_primary_production(), "벌목소는 1차 생산")
	assert_eq(building.produces(), "나무", "산출 나무")
	assert_eq(building.buildable_terrains(), [Terrain.FOREST], "숲에만")

func test_tick_production_accrues() -> void:
	_lumberjack()
	building.workers = 3
	var out: Array = []
	for i in 5:
		out.append(building.tick_production(5))
	assert_eq(out, [0, 1, 0, 1, 1], "3명·거리5 5턴 산출 [0,1,0,1,1]")
	assert_eq(building.production_points, 0, "5턴 후 PP 0")

func test_tick_production_multi_per_turn() -> void:
	_lumberjack()
	building.workers = 5
	assert_eq(building.tick_production(2), 2, "5명·거리2 → 한 턴 2 산출")
	assert_eq(building.production_points, 1, "PP 5→1")

func test_tick_production_guards() -> void:
	_lumberjack()
	assert_eq(building.tick_production(5), 0, "인원 0 → 산출 0")
	assert_eq(building.production_points, 0, "PP 불변")
	building.workers = 3
	assert_eq(building.tick_production(0), 0, "거리 0 → 0(방어)")

func test_production_rate() -> void:
	_lumberjack()
	building.workers = 3
	assert_almost_eq(building.production_rate(5), 0.6, 0.001, "인원3÷거리5 = 0.6")
	assert_eq(building.production_rate(0), 0.0, "거리 0 → 0")

func test_non_production_building() -> void:
	_camp()
	assert_false(building.is_primary_production(), "캠프는 1차 생산 아님")
	assert_eq(building.produces(), "", "산출 없음")
	assert_eq(building.buildable_terrains(), [], "지형 제한 없음")
	assert_eq(building.tick_production(5), 0, "생산 없음 → tick 0")

# --- 2차 생산(가공) → docs/spec/features/processing.md ---

func _sawmill() -> void:
	building.setup(terrain, _center(), "sawmill")

func test_work_speed_by_workers() -> void:
	_sawmill()
	building.workers = 0
	assert_eq(building.work_speed(), 0, "인원 0 → 0")
	building.workers = 1
	assert_eq(building.work_speed(), 8, "인원 1 → 8(0.8)")
	building.workers = 2
	assert_eq(building.work_speed(), 15, "인원 2 → 15(1.5)")
	building.workers = 3
	assert_eq(building.work_speed(), 20, "인원 3 → 20(2.0)")
	building.workers = 5
	assert_eq(building.work_speed(), 20, "클램프 상한 3 → 20")

func test_advance_work_batches() -> void:
	_sawmill()
	building.workers = 2   # 15/턴
	assert_eq(building.advance_work(99), 1, "턴1: wp 15 → 1배치")
	assert_eq(building.work_points, 5, "wp 15→5")
	assert_eq(building.advance_work(99), 2, "턴2: wp 20 → 2배치")
	assert_eq(building.work_points, 0, "wp 0")

func test_advance_work_pauses_on_no_input() -> void:
	_sawmill()
	building.workers = 2
	assert_eq(building.advance_work(0), 0, "입력 0 → 변환 0(일시정지)")
	assert_eq(building.work_points, 15, "포인트는 쌓임(15)")
	assert_eq(building.advance_work(99), 3, "입력 채워짐 → wp 30 → 3배치")

func test_advance_work_non_secondary() -> void:
	_camp()
	assert_eq(building.advance_work(99), 0, "가공 건물 아니면 0")

func test_recipe_input_output() -> void:
	_sawmill()
	assert_true(building.is_secondary_production(), "제재소는 2차 생산")
	assert_eq(building.active_recipe_input(), {"나무": 1}, "입력 나무1")
	assert_eq(building.active_recipe_output(), {"목재": 1}, "출력 목재1")

func test_byproduct_multi_output() -> void:
	building.setup(terrain, _center(), "stable")
	assert_eq(building.active_recipe_input(), {"밀": 2}, "축사 입력 밀2")
	assert_eq(building.active_recipe_output(), {"고기": 1, "가죽": 1}, "축사 산출 고기1+가죽1(부산물)")
	var ranch = load("res://scenes/building/building.gd").new()
	add_child_autofree(ranch)
	ranch.setup(terrain, Vector2i(10, 10), "ranch")
	assert_true(ranch.is_secondary_production(), "목장은 2차 생산")
	assert_eq(ranch.active_recipe_output(), {"고기": 1, "천": 1}, "목장 산출 고기1+천1(부산물)")

func test_smelter_recipe_selection() -> void:
	building.setup(terrain, _center(), "smelter")
	assert_eq(building.recipes().size(), 3, "제련소 레시피 3개")
	assert_eq(building.active_recipe_input(), {"철": 1}, "기본 레시피 철")
	building.active_recipe = 1
	assert_eq(building.active_recipe_input(), {"은": 1}, "레시피1 은")
	assert_eq(building.active_recipe_output(), {"은괴": 1}, "은→은괴")

func test_mode_batch_cap() -> void:
	_sawmill()
	building.work_mode = building.WORK_CONTINUOUS
	assert_gt(building.mode_batch_cap(999), 1000000, "계속 모드 상한 매우 큼(입력만 제한)")
	building.work_mode = building.WORK_KEEP
	building.work_target = 10
	assert_eq(building.mode_batch_cap(3), 7, "N유지: 목표10·출력3 → 7배치")
	assert_eq(building.mode_batch_cap(10), 0, "출력이 목표면 정지")
	assert_eq(building.mode_batch_cap(12), 0, "출력이 목표 초과여도 0(하한)")
	building.work_mode = building.WORK_TURNS
	building.work_target = 3
	assert_gt(building.mode_batch_cap(0), 1000000, "N턴(target>0) 상한 큼")
	building.work_target = 0
	assert_eq(building.mode_batch_cap(0), 0, "N턴(target 0) 정지")

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
	building.setup(terrain, _center(), "quarry", true)   # build_turns 4
	assert_false(building.advance_construction(), "1턴: 아직 미완성")
	assert_false(building.advance_construction(), "2턴: 아직 미완성")
	assert_false(building.advance_construction(), "3턴: 아직 미완성")
	assert_true(building.advance_construction(), "4턴: 완성되는 호출만 true")
	assert_true(building.is_complete(), "완성됨")

func test_refund_on_demolish_complete_uses_salvage() -> void:
	building.setup(terrain, _center(), "farm")   # 완성
	assert_eq(building.refund_on_demolish(), building.demolish_refund(), "완성은 demolish_refund(카탈로그 salvage)")

func test_refund_on_demolish_under_construction_full_at_start() -> void:
	building.setup(terrain, _center(), "farm", true)   # remaining 3 / build_turns 3
	assert_eq(building.refund_on_demolish(), {"목재": 5, "밀": 5}, "갓 시작(진행 0) → build_cost 전액")

func test_refund_on_demolish_under_construction_partial() -> void:
	building.setup(terrain, _center(), "farm", true)
	building.advance_construction()   # remaining 2 / 3
	assert_eq(building.refund_on_demolish(), {"목재": 3, "밀": 3}, "1턴 진행 → floor(5×2/3)=3씩")

func test_advance_construction_on_complete_is_noop() -> void:
	_camp()
	assert_false(building.advance_construction(), "완성 건물은 no-op false")
	assert_true(building.is_complete(), "상태 불변")

# flat 생산(production/planned_production/collect_income)은 폐지됨 — 채석장도 1차 생산(생산포인트)으로 전환.
# 모든 생산은 tick_production(1차)·advance_work(2차)로 검증한다. → production.md · processing.md

func test_quarry_is_primary_production() -> void:
	building.setup(terrain, _center(), "quarry")
	assert_true(building.is_primary_production(), "채석장은 1차 생산으로 전환")
	assert_eq(building.produces(), "석재", "산출 석재")
	assert_eq(building.buildable_terrains(), [Terrain.STONE], "돌에만")

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
	building.wall_level = 1   # 성벽은 업그레이드 후에도 유지되어야 한다
	building.wall_hp = 180
	building.upgrade_to("town_hall")
	assert_eq(building.building_type, "town_hall", "종류가 마을회관으로")
	assert_eq(building.vision, 6, "시야 6으로 교체")
	assert_eq(building.pop_cap(), 10, "인구 상한 10")
	assert_true(building.is_complete(), "업그레이드 후 완성 상태")
	assert_eq(building.cells.size(), 7, "footprint 7 유지")
	assert_eq(building.center_cell(), _center(), "위치 유지")
	assert_eq(building.wall_level, 1, "성벽(wall_level) 유지")
	assert_eq(building.wall_hp, 180, "성벽 내구도(wall_hp) 유지")

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

# --- 필요인원 (required_pop) ---

func test_required_pop_by_type() -> void:
	building.setup(terrain, _center(), "siege_workshop")
	assert_eq(building.required_pop(), 2, "공성 작업장 필요인원 2(고정 노동력)")
	var lumber = load("res://scenes/building/building.gd").new()
	add_child_autofree(lumber)
	lumber.setup(terrain, Vector2i(30, 30), "quarry")
	assert_eq(lumber.required_pop(), 0, "채석장 필요인원 0(1차 생산 전환)")
	var house = load("res://scenes/building/building.gd").new()
	add_child_autofree(house)
	house.setup(terrain, Vector2i(10, 10), "house")
	assert_eq(house.required_pop(), 0, "집 필요인원 0")
