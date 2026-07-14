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

func _human() -> Object:
	return load("res://scenes/human/human.gd").new()

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

# --- 사람(Human) 이름 ---

func test_human_name_defaults_empty() -> void:
	assert_eq(_human().human_name, "", "기본 이름은 빈 문자열")

func test_human_name_settable() -> void:
	var c := _human()
	c.human_name = "테스트맨"
	assert_eq(c.human_name, "테스트맨", "이름을 설정할 수 있다")

# --- 부대 1턴 1이동 (부대 상태 상세는 test_party.gd) ---

func test_end_turn_resets_units() -> void:
	var tm := _turn_manager()
	var p := _party()
	p.mark_moved()
	tm.end_turn([p], [])
	assert_false(p.moved_this_turn, "턴 종료 시 부대 이동 상태 리셋")

# --- 건물 생산량 ---

func test_camp_production_empty() -> void:
	assert_eq(_building("camp").production(), {}, "캠프는 생산 없음(빈 Dictionary)")

func test_quarry_production_stone() -> void:
	# 농장·벌목소는 1차 생산(생산포인트)로 전환돼 flat production 없음. flat 수입은 채석장이 대표. → production.md
	assert_eq(_building("quarry").production(), {"석재": 2}, "채석장은 석재 2 생산(flat)")
	assert_eq(_building("farm").production(), {}, "농장은 flat 생산 없음(1차 생산)")

# --- 영지 자원 수입 ---

func test_collect_income_adds_quarry_production() -> void:
	var t := _territory({"석재": 50})
	t.add_building(_building("quarry"))
	t.collect_income()
	assert_eq(t.resources["석재"], 52, "채석장 생산으로 석재 +2")

func test_collect_income_camp_only_no_change() -> void:
	var t := _territory({"밀": 50, "목재": 20})
	t.add_building(_building("camp"))
	t.collect_income()
	assert_eq(t.resources["밀"], 50, "캠프만 있으면 자원 변화 없음")
	assert_eq(t.resources["목재"], 20, "캠프만 있으면 자원 변화 없음")

func test_collect_income_creates_missing_key() -> void:
	var t := _territory({})  # 석재 키 없음
	t.add_building(_building("quarry"))
	t.collect_income()
	assert_eq(t.resources.get("석재"), 2, "없던 자원 키도 생산되면 새로 생겨 더해짐")

func test_end_turn_collects_income() -> void:
	var tm := _turn_manager()
	var t := _territory({"석재": 50})
	t.add_building(_building("quarry"))
	tm.end_turn([], [t])
	assert_eq(t.resources["석재"], 52, "턴 종료 시 영지 수입 적용")

# --- 건설 진행 (건축) ---

func test_end_turn_advances_construction() -> void:
	var tm := _turn_manager()
	var t := _territory({"석재": 50})
	var quarry := _building_uc("quarry")  # build_turns 4
	t.add_building(quarry)
	tm.end_turn([], [t])
	assert_eq(quarry.remaining_turns, 3, "턴 종료 시 건설 1턴 진행")
	assert_eq(t.resources["석재"], 50, "완성 전엔 석재 수입 없음")

func test_construction_completes_then_produces_next_turn() -> void:
	var tm := _turn_manager()
	var t := _territory({"석재": 50})
	var quarry := _building_uc("quarry")  # build_turns 4
	t.add_building(quarry)
	for i in 4:
		tm.end_turn([], [t])  # 4→3→2→1→0 완성(수입 정산이 먼저라 완성 턴엔 미생산)
	assert_true(quarry.is_complete(), "4턴 후 완성")
	assert_eq(t.resources["석재"], 50, "완성되는 턴엔 아직 생산 안 함")
	tm.end_turn([], [t])  # 완성 상태 → 생산
	assert_eq(t.resources["석재"], 52, "다음 턴부터 석재 수입 발생")

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
