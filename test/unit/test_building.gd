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

# --- 점유 영역 ---

func test_occupies_seven_hexes() -> void:
	_camp()
	assert_eq(building.cells.size(), 7, "건물은 중심 + 이웃 6 = 7헥스")

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
	assert_eq(building.production(), {}, "건설 중엔 생산 없음")

func test_advance_construction_completes_on_last_turn() -> void:
	building.setup(terrain, _center(), "farm", true)
	assert_false(building.advance_construction(), "1턴: 아직 미완성")
	assert_false(building.advance_construction(), "2턴: 아직 미완성")
	assert_true(building.advance_construction(), "3턴: 완성되는 호출만 true")
	assert_true(building.is_complete(), "완성됨")
	assert_eq(building.production(), {"밀": 1}, "완성 후 생산 시작")

func test_advance_construction_on_complete_is_noop() -> void:
	_camp()
	assert_false(building.advance_construction(), "완성 건물은 no-op false")
	assert_true(building.is_complete(), "상태 불변")

# --- 완성 시 생산량 (planned_production) — 건설 여부와 무관 ---

func test_planned_production_farm_complete() -> void:
	building.setup(terrain, _center(), "farm")
	assert_eq(building.planned_production(), {"밀": 1}, "완성 농장 완성 시 생산 = 밀 1")

func test_planned_production_camp_empty() -> void:
	_camp()
	assert_eq(building.planned_production(), {}, "캠프는 생산 없음")

func test_planned_production_ignores_construction() -> void:
	building.setup(terrain, _center(), "farm", true)
	assert_eq(building.production(), {}, "건설 중 production은 빈 Dictionary")
	assert_eq(building.planned_production(), {"밀": 1}, "건설 중에도 완성 시 생산은 밀 1")
