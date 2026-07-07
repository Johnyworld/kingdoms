extends GutTest
## 건물(Building) 점유 영역·종류 스펙·맵 라벨 테스트.

const MAP := 41
const BLUE := Color(0.2, 0.3, 0.8)

var terrain: TileMapLayer
var building: Node2D

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/grass_tileset.tres")
	add_child_autofree(terrain)
	building = load("res://scenes/building/building.gd").new()
	add_child_autofree(building)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func _camp() -> void:
	building.setup(terrain, _center(), "camp")

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

func test_camp_resources_from_catalog() -> void:
	_camp()
	var expected := {"밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}
	assert_eq(building.resources.size(), expected.size(), "자원 6종")
	for key in expected:
		assert_eq(building.resources.get(key), expected[key], "%s 초기값" % key)

func test_camp_vision_and_label() -> void:
	_camp()
	assert_eq(building.building_type, "camp", "종류 id 저장")
	assert_eq(building.vision, 5, "캠프 시야 5")
	assert_eq(building.label(), "캠프", "종류 라벨 = 캠프")

func test_unknown_type_defaults() -> void:
	building.setup(terrain, _center(), "없는id")
	assert_eq(building.vision, 0, "미지 종류 시야 0")
	assert_eq(building.resources.size(), 0, "미지 종류 자원 없음")
	assert_eq(building.label(), "", "미지 종류 라벨 빈 문자열")

func test_resources_is_copy_not_catalog() -> void:
	_camp()
	building.resources["밀"] = 999
	var types = load("res://scenes/building/building_types.gd")
	assert_eq(types.get_type("camp")["resources"]["밀"], 50, "인스턴스 수정이 카탈로그를 바꾸지 않음")

# --- 정체성 / 맵 라벨 ---

func test_default_identity() -> void:
	assert_eq(building.building_name, "", "기본 이름은 빈 문자열")
	assert_null(building.faction, "기본 세력 없음")

func test_map_labels_name_and_faction() -> void:
	_camp()
	building.building_name = "파리"
	load("res://scenes/faction/faction.gd").new("프랑스", BLUE).add_building(building)
	var lines: Array = building.map_label_lines()
	assert_eq(lines.size(), 2, "이름 + 세력 = 2줄")
	assert_eq(lines[0]["text"], "파리", "첫 줄은 건물 이름")
	assert_eq(lines[1]["text"], "프랑스", "둘째 줄은 세력명")
	assert_eq(lines[1]["color"], BLUE, "세력 줄 색상 = 세력 색상")

func test_map_labels_name_only() -> void:
	building.building_name = "파리"
	var lines: Array = building.map_label_lines()
	assert_eq(lines.size(), 1, "세력 없으면 이름 1줄")
	assert_eq(lines[0]["text"], "파리", "이름 줄 텍스트")

func test_map_labels_empty() -> void:
	assert_eq(building.map_label_lines().size(), 0, "이름·세력 없으면 빈 배열")
