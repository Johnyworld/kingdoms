extends GutTest
## 턴(Turn) 시스템 테스트 — 턴 번호 · 유닛 1턴 1이동 · 영지 자원 수입.
## TurnManager.end_turn = 번호+1 → 유닛 reset_turn → 영지 collect_income.

const MAP := 41

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/grass_tileset.tres")
	add_child_autofree(terrain)

func _turn_manager() -> Object:
	return load("res://scenes/turn/turn_manager.gd").new()

func _character() -> Node2D:
	var c: Node2D = load("res://scenes/character/character.gd").new()
	add_child_autofree(c)
	return c

func _building(type_id: String) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, Vector2i(MAP / 2, MAP / 2), type_id)
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

# --- 유닛 1턴 1이동 ---

func test_character_can_move_by_default() -> void:
	var c := _character()
	assert_false(c.moved_this_turn, "생성 직후 이동 안 함")
	assert_true(c.can_move(), "생성 직후 이동 가능")

func test_mark_moved_blocks_move() -> void:
	var c := _character()
	c.mark_moved()
	assert_true(c.moved_this_turn, "mark_moved 후 이동함 표시")
	assert_false(c.can_move(), "이동한 유닛은 이동 불가")

func test_reset_turn_restores_move() -> void:
	var c := _character()
	c.mark_moved()
	c.reset_turn()
	assert_false(c.moved_this_turn, "reset_turn 후 이동 안 함으로 리셋")
	assert_true(c.can_move(), "reset_turn 후 다시 이동 가능")

func test_end_turn_resets_units() -> void:
	var tm := _turn_manager()
	var c := _character()
	c.mark_moved()
	tm.end_turn([c], [])
	assert_false(c.moved_this_turn, "턴 종료 시 유닛 이동 상태 리셋")

# --- 건물 생산량 ---

func test_camp_production_empty() -> void:
	assert_eq(_building("camp").production(), {}, "캠프는 생산 없음(빈 Dictionary)")

func test_farm_production_wheat() -> void:
	assert_eq(_building("farm").production(), {"밀": 1}, "농장은 밀 1 생산")

# --- 영지 자원 수입 ---

func test_collect_income_adds_farm_production() -> void:
	var t := _territory({"밀": 50})
	t.add_building(_building("farm"))
	t.collect_income()
	assert_eq(t.resources["밀"], 51, "농장 생산으로 밀 +1")

func test_collect_income_camp_only_no_change() -> void:
	var t := _territory({"밀": 50, "목재": 20})
	t.add_building(_building("camp"))
	t.collect_income()
	assert_eq(t.resources["밀"], 50, "캠프만 있으면 자원 변화 없음")
	assert_eq(t.resources["목재"], 20, "캠프만 있으면 자원 변화 없음")

func test_collect_income_creates_missing_key() -> void:
	var t := _territory({})  # 밀 키 없음
	t.add_building(_building("farm"))
	t.collect_income()
	assert_eq(t.resources.get("밀"), 1, "없던 자원 키도 생산되면 새로 생겨 더해짐")

func test_end_turn_collects_income() -> void:
	var tm := _turn_manager()
	var t := _territory({"밀": 50})
	t.add_building(_building("farm"))
	tm.end_turn([], [t])
	assert_eq(t.resources["밀"], 51, "턴 종료 시 영지 수입 적용")
