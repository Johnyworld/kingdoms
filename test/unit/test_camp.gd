extends GutTest
## 캠프 점유 영역과 보유 자원 초기값 테스트.

const MAP := 41

var terrain: TileMapLayer
var camp: Node2D

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/grass_tileset.tres")
	add_child_autofree(terrain)
	camp = load("res://scenes/camp/camp.gd").new()
	add_child_autofree(camp)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func test_occupies_seven_hexes() -> void:
	camp.setup(terrain, _center())
	assert_eq(camp.cells.size(), 7, "캠프는 중심 + 이웃 6 = 7헥스")

func test_center_cell_is_setup_cell() -> void:
	camp.setup(terrain, _center())
	assert_eq(camp.center_cell(), _center(), "center_cell은 setup에 넘긴 중심")

func test_contains_center() -> void:
	camp.setup(terrain, _center())
	assert_true(camp.contains_cell(_center()), "중심 셀을 포함한다")

func test_contains_neighbors() -> void:
	camp.setup(terrain, _center())
	for n in terrain.get_surrounding_cells(_center()):
		assert_true(camp.contains_cell(n), "이웃 6칸을 포함한다: %s" % n)

func test_does_not_contain_far_cell() -> void:
	camp.setup(terrain, _center())
	assert_false(camp.contains_cell(_center() + Vector2i(5, 5)), "먼 셀은 포함하지 않는다")

func test_initial_resources() -> void:
	# 삽입 순서 = 메뉴 표시 순서. 값은 data/resources.md 스펙과 일치해야 한다.
	var expected := {"밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}
	assert_eq(camp.resources.size(), expected.size(), "자원은 6종")
	for key in expected:
		assert_eq(camp.resources.get(key), expected[key], "%s 초기값" % key)

func test_default_vision() -> void:
	assert_eq(camp.vision, 5, "캠프 기본 시야 5")

func test_default_identity() -> void:
	assert_eq(camp.camp_name, "", "기본 캠프 이름은 빈 문자열")
	assert_null(camp.faction, "기본 소속 세력은 없음")

const BLUE := Color(0.2, 0.3, 0.8)

func test_map_labels_name_and_faction() -> void:
	camp.camp_name = "파리"
	load("res://scenes/faction/faction.gd").new("프랑스", BLUE).add_camp(camp)
	var lines: Array = camp.map_label_lines()
	assert_eq(lines.size(), 2, "이름 + 세력 = 2줄")
	assert_eq(lines[0]["text"], "파리", "첫 줄은 캠프 이름")
	assert_eq(lines[1]["text"], "프랑스", "둘째 줄은 세력명")

func test_map_labels_faction_color() -> void:
	camp.camp_name = "파리"
	load("res://scenes/faction/faction.gd").new("프랑스", BLUE).add_camp(camp)
	assert_eq(camp.map_label_lines()[1]["color"], BLUE, "세력 줄 색상 = 세력 색상")

func test_map_labels_name_only() -> void:
	camp.camp_name = "파리"
	var lines: Array = camp.map_label_lines()
	assert_eq(lines.size(), 1, "세력 없으면 이름 1줄")
	assert_eq(lines[0]["text"], "파리", "이름 줄")

func test_map_labels_empty() -> void:
	assert_eq(camp.map_label_lines().size(), 0, "이름·세력 없으면 빈 배열")
