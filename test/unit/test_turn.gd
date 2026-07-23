extends GutTest
## 턴(Turn) 시스템 테스트 — 턴 번호 · 유닛 1턴 1이동 · 영지 자원 수입.
## TurnManager.end_turn = 번호+1 → 유닛 reset_turn → 영지 collect_income.

const MAP := 41

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _turn_manager() -> Object:
	return load("res://scenes/turn/turn_manager.gd").new()

func _party() -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	return p

func _building(type_id: String) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, Vector2i(MAP / 2, MAP / 2), type_id)
	return b

func _building_at(type_id: String, cell: Vector2i) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, cell, type_id)
	return b

func _building_uc(type_id: String) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, Vector2i(MAP / 2, MAP / 2), type_id, true)  # 건설 중
	return b

func _territory(res := {}) -> Object:
	return load("res://scenes/territory/territory.gd").new("파리", res)

# --- 턴 번호 ---

func test_starts_at_turn_one() -> void:
	assert_eq(_turn_manager().number, 1, "생성 직후 턴 번호 1")

func test_end_turn_increments_number() -> void:
	var tm := _turn_manager()
	tm.end_turn([], [])
	assert_eq(tm.number, 2, "턴 종료 1회 → 2")
	tm.end_turn([], [])
	assert_eq(tm.number, 3, "턴 종료 2회 → 3")

# --- 부대 이동력 풀 리셋 (부대 상태 상세는 test_party.gd) ---

func test_end_turn_refills_move_points() -> void:
	var tm := _turn_manager()
	var p := _party()
	p.troop_type = "light_infantry"   # 이동력 있는 병종
	p.mark_moved()   # 이동력 소진(0)
	assert_eq(p.move_points, 0, "선행: 이동력 0")
	tm.end_turn([p], [])
	assert_eq(p.move_points, p.movement(), "턴 종료 시 부대 이동력이 movement()로 리셋")

# flat 생산·2차 가공은 폐지됨 — 모든 생산이 game.gd의 1차 생산포인트(거리 기반)로 이관. → production.md

# --- 건설 진행 (건축) ---

func test_end_turn_advances_construction() -> void:
	var tm := _turn_manager()
	var t := _territory({"목재": 50})
	var farm := _building_uc("farm")  # build_turns 3
	t.add_building(farm)
	tm.end_turn([], [t])
	assert_eq(farm.remaining_turns, 2, "턴 종료 시 건설 1턴 진행")

func test_construction_completes_on_schedule() -> void:
	var tm := _turn_manager()
	var t := _territory({"목재": 50})
	var farm := _building_uc("farm")  # build_turns 3
	t.add_building(farm)
	for i in 3:
		tm.end_turn([], [t])
	assert_true(farm.is_complete(), "3턴 후 완성")

# --- 인구 자연 증가 ---

func test_end_turn_grows_population_up_to_cap() -> void:
	var tm := _turn_manager()
	var t := _territory({"인구": 10})
	t.add_building(_building_at("town_hall", Vector2i(MAP / 2, MAP / 2)))  # 상한 10
	t.add_building(_building_at("house", Vector2i(5, 5)))                   # +2 → 12
	tm.end_turn([], [t])
	assert_eq(t.resources["인구"], 11, "턴 종료 시 인구 10 → 11(상한 12)")
	tm.end_turn([], [t])
	assert_eq(t.resources["인구"], 12, "다음 턴 → 12(상한 도달)")
	tm.end_turn([], [t])
	assert_eq(t.resources["인구"], 12, "상한 도달 후 유지")

func test_end_turn_no_growth_at_cap() -> void:
	var tm := _turn_manager()
	var t := _territory({"인구": 10})
	t.add_building(_building_at("town_hall", Vector2i(MAP / 2, MAP / 2)))  # 상한 10
	tm.end_turn([], [t])
	assert_eq(t.resources["인구"], 10, "인구가 상한(10)과 같으면 증가 없음")
