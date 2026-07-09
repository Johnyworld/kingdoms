extends GutTest
## NpcAi.choose_destination — 도달 가능한 가장 먼 칸 중 무작위 선택.
## 결정적 검증을 위해 시드 고정 RandomNumberGenerator를 넘긴다.
## 헥스 인접·지형은 엔진 의존이라 실제 헥스 타일셋 TileMapLayer로 검증한다.
## (무도색 셀 source_id = -1 은 초원 취급 → 이동 상한 = 이동력 그대로.)

const MAP := 41  # 중앙 기준 반경 몇 칸은 경계에 안 닿을 만큼 넉넉한 정사각 맵.

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func _rng(seed_val := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# --- 목적지 유효성 ---

func test_destination_in_move_set() -> void:
	var start := _center()
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng())
	var move_cells: Array = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["move"]
	assert_true(dest in move_cells, "목적지는 이동 가능 집합에 속한다")

func test_destination_is_farthest() -> void:
	# 초원에서는 이동 상한이 이동력 그대로라, 가장 먼 칸의 거리는 정확히 이동력이다.
	var start := _center()
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng())
	var dist: Dictionary = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["dist"]
	assert_eq(dist[dest], 3, "목적지는 도달 가능한 최대 거리(=이동력) 칸")

func test_zero_movement_stays() -> void:
	var start := _center()
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 0, MAP, MAP, _rng())
	assert_eq(dest, start, "이동력 0이면 제자리")

# --- 결정성 ---

func test_deterministic_same_seed() -> void:
	var start := _center()
	var a: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(42))
	var b: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(42))
	assert_eq(a, b, "같은 시드 → 같은 목적지")

# --- 지형(산 배제) ---

func test_avoids_mountains() -> void:
	# 이웃 6칸 중 5칸을 산으로 막으면, 이동력 1 목적지는 남은 초원 이웃 1칸뿐이어야 한다.
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var open_cell: Vector2i = neighbors[0]
	for i in range(1, neighbors.size()):
		terrain.set_cell(neighbors[i], Terrain.MOUNTAIN, Terrain.ATLAS)
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng())
	assert_eq(dest, open_cell, "산으로 막히면 유일한 초원 이웃으로 이동(산 칸은 목적지 아님)")
	assert_false(terrain.get_cell_source_id(dest) == Terrain.MOUNTAIN, "목적지는 산이 아니다")

# --- 유닛 점유(blocked_cells) 회피 ---

func test_does_not_choose_occupied_cell() -> void:
	# 이웃 6칸 중 5칸을 점유로 막으면 이동력 1 목적지는 남은 한 칸뿐.
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var open_cell: Vector2i = neighbors[0]
	var occ := {}
	for i in range(1, neighbors.size()):
		occ[neighbors[i]] = true
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng(), occ)
	assert_eq(dest, open_cell, "점유되지 않은 유일한 이웃으로 이동")
	assert_false(occ.has(dest), "점유 칸은 목적지가 아니다")

func test_all_neighbors_occupied_stays() -> void:
	var start := _center()
	var occ := {}
	for n in terrain.get_surrounding_cells(start):
		occ[n] = true
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng(), occ)
	assert_eq(dest, start, "이동력 1 + 이웃 전부 점유 → 제자리")
