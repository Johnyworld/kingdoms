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

func test_wander_varies_distance() -> void:
	# 배회는 거리 무관 무작위 — 여러 시드 중 최대 거리(3)보다 짧은 칸을 고르는 경우가 있어야 한다.
	var start := _center()
	var dist: Dictionary = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["dist"]
	var saw_shorter := false
	for s in range(1, 30):
		var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(s))
		if dist[dest] < 3:
			saw_shorter = true
			break
	assert_true(saw_shorter, "배회는 최대 거리보다 짧은 칸도 고른다(항상 최대 이동력 아님)")

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

# --- 목표지향(targets) ---

func _world_dist(a: Vector2i, b: Vector2i) -> float:
	return terrain.map_to_local(a).distance_to(terrain.map_to_local(b))

func test_moves_closer_to_target() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)   # 동쪽 멀리
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [target])
	assert_true(_world_dist(dest, target) < _world_dist(start, target), "타깃에 더 가까워지는 칸으로 이동")

func test_destination_minimizes_distance_to_target() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [target])
	# 이동 칸 전체에서 타깃과의 최소 거리를 직접 구해 비교.
	var move_cells: Array = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["move"]
	var best := INF
	for c in move_cells:
		best = minf(best, _world_dist(c, target))
	assert_almost_eq(_world_dist(dest, target), best, 0.01, "목적지는 타깃과의 거리가 최소인 칸")

func test_nearest_of_multiple_targets() -> void:
	var start := _center()
	var far := start + Vector2i(6, 0)
	var near := start + Vector2i(-2, 0)   # 서쪽 가까이
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [far, near])
	# 가장 가까운 타깃(near) 쪽으로 접근 → near에 더 가까워진다.
	assert_true(_world_dist(dest, near) < _world_dist(start, near), "가장 가까운 타깃에 접근")

func test_stays_when_cannot_get_closer() -> void:
	var start := _center()
	# 타깃이 시작 칸이면 어떤 이동칸도 더 가까워질 수 없다 → 제자리.
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [start])
	assert_eq(dest, start, "더 가까워지는 칸 없으면 제자리")

func test_target_seeking_deterministic() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)
	var a: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(9), {}, [target])
	var b: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(9), {}, [target])
	assert_eq(a, b, "같은 시드 → 같은 목적지")

# --- 타깃 선정: 세력 필터·방어 우선 (순수, 노드 비의존) ---

func test_enemy_cells_filters_by_faction() -> void:
	var entries := [
		{"cell": Vector2i(1, 0), "faction": "푸른 왕국"},
		{"cell": Vector2i(2, 0), "faction": "사막 술탄국"},
		{"cell": Vector2i(3, 0), "faction": "암흑 제국"},
	]
	var out: Array = NpcAi.enemy_cells("사막 술탄국", entries)
	assert_eq(out, [Vector2i(1, 0), Vector2i(3, 0)], "같은 세력 제외, 적의 cell만")

func test_enemy_cells_all_allies_empty() -> void:
	var entries := [
		{"cell": Vector2i(1, 0), "faction": "사막 술탄국"},
		{"cell": Vector2i(2, 0), "faction": "사막 술탄국"},
	]
	assert_eq(NpcAi.enemy_cells("사막 술탄국", entries), [], "전부 같은 세력이면 빈 배열")

func test_select_targets_prefers_defend() -> void:
	var advance := [Vector2i(5, 5), Vector2i(6, 6)]
	var defend := [Vector2i(1, 1)]
	assert_eq(NpcAi.select_targets(advance, defend), defend, "방어 대상 있으면 방어 우선")

func test_select_targets_falls_back_to_advance() -> void:
	var advance := [Vector2i(5, 5)]
	assert_eq(NpcAi.select_targets(advance, []), advance, "방어 대상 없으면 진격 타깃")

# --- 전력 인식: party_power / should_engage (순수) ---

func _soldier(hp: int) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new("병사")
	h.hit_points = hp
	return h

func test_party_power_sums_hp() -> void:
	assert_eq(NpcAi.party_power([_soldier(40), _soldier(30)]), 70, "멤버 hit_points 합")

func test_party_power_empty_zero() -> void:
	assert_eq(NpcAi.party_power([]), 0, "빈 부대 전력 0")

func test_should_engage_equal() -> void:
	assert_true(NpcAi.should_engage(100, 100), "대등하면 교전")

func test_should_engage_boundary() -> void:
	assert_true(NpcAi.should_engage(70, 100), "70%면 교전(경계)")

func test_should_engage_outmatched() -> void:
	assert_false(NpcAi.should_engage(60, 100), "60%면 불리 → 회피")

func test_should_engage_enemy_zero() -> void:
	assert_true(NpcAi.should_engage(10, 0), "적 전력 0이면 교전")

# --- 표적 우선순위: prioritize (순수) ---

func test_prioritize_first_nonempty() -> void:
	assert_eq(NpcAi.prioritize([[], [Vector2i(1,0)], [Vector2i(2,0)]]), [Vector2i(1,0)], "첫 비지 않은 티어")

func test_prioritize_top_tier() -> void:
	assert_eq(NpcAi.prioritize([[Vector2i(1,0)], [Vector2i(2,0)]]), [Vector2i(1,0)], "상위 티어 우선")

func test_prioritize_all_empty() -> void:
	assert_eq(NpcAi.prioritize([[], []]), [], "전부 비면 빈 배열")
