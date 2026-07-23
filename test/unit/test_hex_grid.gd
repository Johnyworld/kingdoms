extends GutTest
## HexGrid BFS 로직 테스트: 이동/공격 범위와 시야 반경 계산의 핵심 규칙.
## 헥스 인접은 엔진에 의존하므로 실제 헥스 타일셋을 가진 TileMapLayer로 검증한다.
##
## 헥스 그리드 성질(경계에 닿지 않는 내부 기준):
## - 거리 r 링의 셀 수 = 6r (r>=1)
## - 거리 r 이내 누적 셀 수 = 1 + 3r(r+1)  →  r=1:7, r=2:19, r=3:37

const MAP := 41  # 중앙 기준 반경 3까지 경계에 안 닿을 만큼 넉넉한 정사각 맵.

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

# --- bfs_distances ---

func test_start_has_distance_zero() -> void:
	var dist := HexGrid.bfs_distances(terrain, _center(), 3, MAP, MAP)
	assert_eq(dist[_center()], 0, "시작 셀의 거리는 0")

func test_radius_zero_returns_only_start() -> void:
	var dist := HexGrid.bfs_distances(terrain, _center(), 0, MAP, MAP)
	assert_eq(dist.size(), 1, "반경 0이면 시작 셀만")

func test_radius_one_covers_seven_cells() -> void:
	var dist := HexGrid.bfs_distances(terrain, _center(), 1, MAP, MAP)
	assert_eq(dist.size(), 7, "반경 1 = 중심 + 이웃 6")

func test_radius_two_covers_nineteen_cells() -> void:
	var dist := HexGrid.bfs_distances(terrain, _center(), 2, MAP, MAP)
	assert_eq(dist.size(), 19, "반경 2 누적 = 1 + 3*2*3")

func test_reaches_full_disk_within_max() -> void:
	# max_dist를 넘는 거리는 없고, 거리 3까지 전부(누적 37셀) 도달해야 한다.
	# (덜 확장하는 구현이 통과하지 않도록 셀 수와 최대 거리를 함께 검증)
	var dist := HexGrid.bfs_distances(terrain, _center(), 3, MAP, MAP)
	assert_eq(dist.size(), 37, "반경 3 누적 = 1 + 3*3*4")
	var max_d := 0
	for cell in dist:
		assert_lte(dist[cell] as int, 3, "max_dist를 넘는 거리는 없어야 한다")
		max_d = maxi(max_d, dist[cell])
	assert_eq(max_d, 3, "거리 3 링까지 실제로 도달해야 한다")

func test_stays_within_bounds_at_corner() -> void:
	# 모서리(0,0)에서 확장 시: 맵 안 이웃은 도달, 맵 밖(음수) 이웃은 제외되어야 한다.
	var dist := HexGrid.bfs_distances(terrain, Vector2i(0, 0), 5, MAP, MAP)
	assert_gt(dist.size(), 1, "모서리에서도 확장이 일어나야 한다")
	for cell_key in dist:
		var cell: Vector2i = cell_key
		assert_between(cell.x, 0, MAP - 1, "x가 맵 범위 안")
		assert_between(cell.y, 0, MAP - 1, "y가 맵 범위 안")
	# 모서리의 직접 이웃 중 맵 안은 반드시 포함, 맵 밖은 반드시 제외.
	for n in terrain.get_surrounding_cells(Vector2i(0, 0)):
		if n.x >= 0 and n.x < MAP and n.y >= 0 and n.y < MAP:
			assert_true(dist.has(n), "맵 안 이웃은 도달: %s" % n)
		else:
			assert_false(dist.has(n), "맵 밖 이웃은 제외: %s" % n)

# --- cells_within ---

func test_cells_within_matches_bfs_keys() -> void:
	var cells := HexGrid.cells_within(terrain, _center(), 2, MAP, MAP)
	assert_eq(cells.size(), 19, "cells_within(2)도 누적 19셀")

# --- movement_ranges ---

func test_movement_range_one_partition() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 1, MAP, MAP)
	assert_eq((r["move"] as Array).size(), 6, "이동력 1: 이동 = 거리1 링 6셀")
	assert_eq((r["attack"] as Array).size(), 12, "이동력 1: 공격 = 거리2 링 12셀")

func test_movement_range_two_partition() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_eq((r["move"] as Array).size(), 18, "이동력 2: 이동 = 거리1+2 링 (6+12)")
	assert_eq((r["attack"] as Array).size(), 18, "이동력 2: 공격 = 이동영역 바로 바깥(평지=거리3 링) 18셀")
	assert_eq((r["dist"] as Dictionary).size(), 19, "dist는 거리2까지 (누적 19셀)")

func test_start_cell_excluded_from_ranges() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_does_not_have(r["move"], _center(), "시작칸은 이동 범위에서 제외")
	assert_does_not_have(r["attack"], _center(), "시작칸은 공격 범위에서 제외")

func test_range_dist_includes_start() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_true((r["dist"] as Dictionary).has(_center()), "dist 맵에는 시작칸 포함")

# --- movement_ranges: 지형 반영 ---

func test_mountain_neighbor_excluded_from_ranges() -> void:
	# 인접 칸을 산으로 칠하면 진입·통과 불가 → dist/move/attack 모두에서 제외된다.
	var mountain: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(mountain, Terrain.MOUNTAIN, Terrain.ATLAS)
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_false((r["dist"] as Dictionary).has(mountain), "산은 dist에서 제외(통과 불가)")
	assert_does_not_have(r["move"], mountain, "산은 이동 범위 제외")
	assert_does_not_have(r["attack"], mountain, "산은 공격 범위 제외")

func test_swamp_neighbor_excluded_when_movement_one() -> void:
	# 이동력 1 + 습지 이웃: 습지 진입비용 3 > 1 → 그 칸엔 못 들어간다.
	var swamp: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(swamp, Terrain.SWAMP, Terrain.ATLAS)
	var r := HexGrid.movement_ranges(terrain, _center(), 1, MAP, MAP)
	assert_does_not_have(r["move"], swamp, "이동력 1이면 습지 이웃 진입 불가(비용 3)")
	assert_eq((r["move"] as Array).size(), 5, "이동력 1: 이웃 6 중 습지 1칸 빠져 5칸")

func test_forest_reachable_where_swamp_is_not() -> void:
	# 이동력 2: 숲(비용 2) 이웃은 도달, 습지(비용 3) 이웃은 제외 — 진입비용 차이.
	var neighbors := terrain.get_surrounding_cells(_center())
	terrain.set_cell(neighbors[0], Terrain.FOREST, Terrain.ATLAS)
	terrain.set_cell(neighbors[1], Terrain.SWAMP, Terrain.ATLAS)
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_has(r["move"], neighbors[0], "이동력 2: 숲 이웃 도달(비용 2)")
	assert_does_not_have(r["move"], neighbors[1], "이동력 2: 습지 이웃 제외(비용 3)")

func test_attack_hugs_move_frontier_on_slow_terrain() -> void:
	# 이동력 1 + 습지 이웃: 그 칸은 진입 불가(비용 3)지만 시작칸에 인접하므로 공격 범위에 붙는다.
	# (고정 거리 move_range+1 링이 아니라 실제 이동 프런티어 바깥 한 칸.)
	var swamp: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(swamp, Terrain.SWAMP, Terrain.ATLAS)
	var r := HexGrid.movement_ranges(terrain, _center(), 1, MAP, MAP)
	assert_does_not_have(r["move"], swamp, "습지 이웃은 진입 불가(비용 3 > 1)")
	assert_has(r["attack"], swamp, "진입 못 하는 습지 이웃도 인접하므로 공격 범위에 포함")

# --- 칸당 진입비용 누적(가중 BFS) ---

func test_cost_accumulates_per_step() -> void:
	# 이동력 3 + 첫 이웃이 숲(비용 2): 그 칸까지 2 소모, 그 너머 한 칸(총 2+1=3) 도달, 그 다음(4)은 불가.
	var n0: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(n0, Terrain.FOREST, Terrain.ATLAS)
	var cost := HexGrid.cost_distances(terrain, _center(), 3, MAP, MAP)
	assert_eq(int(cost[n0]), 2, "숲 이웃 진입 누적비용 2")
	assert_true(cost.has(n0), "이동력 3이면 숲(2) 도달")

func test_movement_penalty_shrinks_reach() -> void:
	# 시작칸을 습지로 둘러싸면(비용 3), 이동력 2로는 아무 데도 못 감(모든 이웃 3 > 2).
	for n in terrain.get_surrounding_cells(_center()):
		terrain.set_cell(n, Terrain.SWAMP, Terrain.ATLAS)
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_eq((r["move"] as Array).size(), 0, "사방 습지(3) + 이동력 2 → 이동 가능 칸 0")

func test_cell_costs_building_penalty_and_block() -> void:
	# cell_costs override: 한 이웃은 도시(비용 2), 한 이웃은 불가(BLOCKED).
	var ns := terrain.get_surrounding_cells(_center())
	var city: Vector2i = ns[0]
	var wall: Vector2i = ns[1]
	var costs := {city: 2, wall: Terrain.BLOCKED}
	var r := HexGrid.movement_ranges(terrain, _center(), 1, MAP, MAP, {}, costs)
	assert_does_not_have(r["move"], city, "이동력 1: 도시 칸(비용 2) 진입 불가")
	assert_does_not_have(r["move"], wall, "불가 건물 칸은 진입 불가")
	var r2 := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP, {}, costs)
	assert_has(r2["move"], city, "이동력 2: 도시 칸(비용 2) 도달")
	assert_does_not_have(r2["move"], wall, "이동력 2라도 불가 건물 칸은 진입 불가")

func test_reconstruct_path_respects_entry_cost_budget() -> void:
	# 습지 이웃(비용 3): 이동력 3이면 직행 경로 [start, swamp], 이동력 2면 도달 불가(빈 경로).
	var swamp: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(swamp, Terrain.SWAMP, Terrain.ATLAS)
	var ok := HexGrid.reconstruct_path(terrain, _center(), swamp, 3, MAP, MAP)
	assert_eq(ok, [_center(), swamp] as Array[Vector2i], "이동력 3: 습지(3)로 직행 경로")
	var no := HexGrid.reconstruct_path(terrain, _center(), swamp, 2, MAP, MAP)
	assert_eq(no.size(), 0, "이동력 2: 습지(3) 도달 불가 → 빈 경로")

# --- 경계(edge) 차단(강·벽) ---

func test_edge_key_symmetric() -> void:
	var a := Vector2i(3, 4)
	var b := Vector2i(5, 6)
	assert_eq(HexGrid.edge_key(a, b), HexGrid.edge_key(b, a), "경계 키는 두 칸 순서와 무관")

func test_blocked_edge_forces_detour() -> void:
	# 시작칸↔이웃 경계를 막으면(강/벽) 직접 못 건너고 우회해야 한다(칸 자체는 열려 있음).
	var c := _center()
	var n0: Vector2i = terrain.get_surrounding_cells(c)[0]
	var be := {HexGrid.edge_key(c, n0): true}
	var r1 := HexGrid.movement_ranges(terrain, c, 1, MAP, MAP, {}, {}, be)
	assert_does_not_have(r1["move"], n0, "경계 차단: 이동력 1로는 직접 못 건넘")
	var r3 := HexGrid.movement_ranges(terrain, c, 3, MAP, MAP, {}, {}, be)
	assert_has(r3["move"], n0, "이동력 3: 이웃 경유 우회로 도달(칸은 통행 가능)")

func test_reconstruct_path_avoids_blocked_edge() -> void:
	# 차단 경계로 직행이 막히면 경로가 우회하고, 경로의 어떤 연속 두 칸도 차단 경계가 아니다.
	var c := _center()
	var n0: Vector2i = terrain.get_surrounding_cells(c)[0]
	var be := {HexGrid.edge_key(c, n0): true}
	var path := HexGrid.reconstruct_path(terrain, c, n0, 4, MAP, MAP, {}, {}, be)
	assert_gt(path.size(), 2, "직행(길이 2)이 막혀 우회 경로(길이 > 2)")
	for i in range(path.size() - 1):
		assert_false(be.has(HexGrid.edge_key(path[i], path[i + 1])), "경로가 차단 경계를 건너지 않음")

func test_edge_segment_shared_between_hexes() -> void:
	# 공유 변 선분의 두 끝점은 양쪽 헥스 폴리곤 모두의 꼭짓점이어야 한다(경계 렌더/편집용).
	var c := _center()
	var n0: Vector2i = terrain.get_surrounding_cells(c)[0]
	var seg := HexGrid.edge_segment(terrain, c, n0)
	assert_eq(seg.size(), 2, "공유 변 = 꼭짓점 2개")
	var pc := HexGrid.hex_polygon(terrain, c)
	var pn := HexGrid.hex_polygon(terrain, n0)
	for p in seg:
		var in_c := false
		for v in pc:
			if v.distance_to(p) < 1.0:
				in_c = true
		var in_n := false
		for v in pn:
			if v.distance_to(p) < 1.0:
				in_n = true
		assert_true(in_c and in_n, "경계 끝점은 두 헥스 공통 꼭짓점")

func test_vision_ignores_mountains() -> void:
	# 시야(cells_within 기본 blocked=[])는 지형에 막히지 않는다 — 산 이웃도 포함.
	var mountain: Vector2i = terrain.get_surrounding_cells(_center())[0]
	terrain.set_cell(mountain, Terrain.MOUNTAIN, Terrain.ATLAS)
	var cells := HexGrid.cells_within(terrain, _center(), 1, MAP, MAP)
	assert_has(cells, mountain, "시야는 산에 막히지 않아 산 칸도 보임")

# --- hex_polygon / region_outline (건설 가능 영역 윤곽선) ---

func _to_set(a: Array) -> Dictionary:
	var d := {}
	for c in a:
		d[c] = true
	return d

func test_cells_within_any_single_source_equals_cells_within() -> void:
	var c := _center()
	var multi := _to_set(HexGrid.cells_within_any(terrain, [c], 2, MAP, MAP))
	var single := _to_set(HexGrid.cells_within(terrain, c, 2, MAP, MAP))
	assert_eq(multi, single, "시작점 하나면 cells_within과 동일")

func test_cells_within_any_is_union() -> void:
	var c := _center()
	var n: Vector2i = terrain.get_surrounding_cells(c)[3]
	var cells := _to_set(HexGrid.cells_within_any(terrain, [c, n], 1, MAP, MAP))
	# 두 시작점 각각의 반경 1을 모두 포함(합집합).
	for x in HexGrid.cells_within(terrain, c, 1, MAP, MAP):
		assert_true(cells.has(x), "c의 반경 포함")
	for x in HexGrid.cells_within(terrain, n, 1, MAP, MAP):
		assert_true(cells.has(x), "n의 반경 포함")

func test_hex_polygon_has_six_vertices() -> void:
	assert_eq(HexGrid.hex_polygon(terrain, _center()).size(), 6, "헥스 꼭짓점 6개")

func test_region_outline_single_cell_has_six_edges() -> void:
	var outline := HexGrid.region_outline(terrain, [_center()])
	assert_eq(outline.size(), 6, "셀 하나의 윤곽선 = 변 6개")

func test_region_outline_two_adjacent_shares_one_edge() -> void:
	# 인접한 두 셀: 총 12변 중 공유 변 1개가 상쇄돼 경계 변 10개.
	var pair: Array[Vector2i] = [_center()]
	pair.append(terrain.get_surrounding_cells(_center())[0])
	var outline := HexGrid.region_outline(terrain, pair)
	assert_eq(outline.size(), 10, "인접 두 셀 = 12변 - 공유 변 2(=변 1개) = 10")

func test_region_outline_radius_one_disk() -> void:
	# 반경 1 디스크(7셀)의 바깥 링: 6셀 × 바깥 변 3 = 18.
	var cells := HexGrid.cells_within(terrain, _center(), 1, MAP, MAP)
	var outline := HexGrid.region_outline(terrain, cells)
	assert_eq(outline.size(), 18, "반경 1 디스크 윤곽선 = 18변")

# --- 경로 재구성 (reconstruct_path) — NPC 이동 애니메이션에 사용 ---

func test_path_plains_length_and_endpoints() -> void:
	var start := _center()
	var dist := HexGrid.bfs_distances(terrain, start, 3, MAP, MAP, Terrain.IMPASSABLE)
	# 거리 3인 아무 칸을 목적지로 고른다(초원이라 거리 3 링이 존재).
	var dest := start
	for c in dist:
		if dist[c] == 3:
			dest = c
			break
	var path := HexGrid.reconstruct_path(terrain, start, dest, 3, MAP, MAP)
	assert_eq(path.size(), 4, "거리 3 경로는 칸 4개(start 포함)")
	assert_eq(path[0], start, "경로 첫 칸은 start")
	assert_eq(path[path.size() - 1], dest, "경로 끝 칸은 dest")
	# 이웃끼리 인접하고 거리가 1씩 증가.
	for i in range(1, path.size()):
		assert_true(path[i] in terrain.get_surrounding_cells(path[i - 1]), "연속 칸은 헥스 이웃")
		assert_eq(dist[path[i]], dist[path[i - 1]] + 1, "경로를 따라 거리 단조 증가")

func test_path_start_equals_dest() -> void:
	var start := _center()
	var path := HexGrid.reconstruct_path(terrain, start, start, 3, MAP, MAP)
	assert_eq(path, [start] as Array[Vector2i], "start == dest면 경로는 [start]")

func test_path_adjacent_length_two() -> void:
	var start := _center()
	var dest: Vector2i = terrain.get_surrounding_cells(start)[0]
	var path := HexGrid.reconstruct_path(terrain, start, dest, 1, MAP, MAP)
	assert_eq(path.size(), 2, "인접 칸 경로는 [start, dest]")

func test_path_unreachable_returns_empty() -> void:
	# start를 산으로 둘러싸면 어떤 목적지에도 도달 못 한다.
	var start := _center()
	for n in terrain.get_surrounding_cells(start):
		terrain.set_cell(n, Terrain.MOUNTAIN, Terrain.ATLAS)
	var far: Vector2i = start + Vector2i(3, 0)
	var path := HexGrid.reconstruct_path(terrain, start, far, 3, MAP, MAP)
	assert_eq(path.size(), 0, "도달 불가한 목적지면 빈 경로")

func test_path_avoids_mountains() -> void:
	# 직선 방향에 산을 놓아도 경로는 산 칸을 통과하지 않는다.
	var start := _center()
	var dist := HexGrid.bfs_distances(terrain, start, 3, MAP, MAP, Terrain.IMPASSABLE)
	var dest := start
	for c in dist:
		if dist[c] == 3:
			dest = c
			break
	var path := HexGrid.reconstruct_path(terrain, start, dest, 3, MAP, MAP)
	for cell in path:
		assert_false(terrain.get_cell_source_id(cell) == Terrain.MOUNTAIN, "경로에 산 칸 없음")

# --- 유닛 점유(blocked_cells) — 다른 부대가 있는 칸을 장애물로 취급 ---

func test_bfs_excludes_blocked_cell() -> void:
	var start := _center()
	var blocked: Vector2i = terrain.get_surrounding_cells(start)[0]
	var dist := HexGrid.bfs_distances(terrain, start, 3, MAP, MAP, [], {blocked: true})
	assert_false(dist.has(blocked), "점유 칸은 거리 맵에 없다(진입 불가)")

func test_movement_ranges_excludes_occupied() -> void:
	var start := _center()
	var occ: Vector2i = terrain.get_surrounding_cells(start)[0]
	var r := HexGrid.movement_ranges(terrain, start, 2, MAP, MAP, {occ: true})
	assert_false(occ in r["move"], "점유된 이웃 칸은 이동 목적지에서 제외")

func test_path_avoids_blocked_cell() -> void:
	# 시작 이웃 하나를 점유로 막으면, 그 칸으로 향하는 목적지 경로는 우회한다.
	var start := _center()
	var dist := HexGrid.bfs_distances(terrain, start, 3, MAP, MAP, Terrain.IMPASSABLE)
	var dest := start
	for c in dist:
		if dist[c] == 3:
			dest = c
			break
	# dest로 가는 최단 경로의 첫 칸을 점유로 막는다. 우회로 거리가 늘 수 있어 이동력은 넉넉히(4).
	var open_path := HexGrid.reconstruct_path(terrain, start, dest, 4, MAP, MAP)
	var blocked: Vector2i = open_path[1]
	var path := HexGrid.reconstruct_path(terrain, start, dest, 4, MAP, MAP, {blocked: true})
	assert_false(blocked in path, "경로가 점유 칸을 우회")
	assert_eq(path[path.size() - 1], dest, "우회해도 목적지에는 도달")

func test_path_blocked_dest_returns_empty() -> void:
	var start := _center()
	var dest: Vector2i = terrain.get_surrounding_cells(start)[0]
	var path := HexGrid.reconstruct_path(terrain, start, dest, 2, MAP, MAP, {dest: true})
	assert_eq(path.size(), 0, "목적지가 점유 칸이면 도달 불가(빈 경로)")

# --- 아군 통과(no_stop_cells) — 아군은 벽이 아니다(통과 O·정지 X) → selection-and-movement.md ---

## gate 하나만 남기고 start 이웃을 산으로 막아 유일 출구를 만든다. gate 너머 칸(beyond) 반환.
func _chokepoint_beyond(start: Vector2i, gate: Vector2i, neighbors: Array) -> Vector2i:
	for i in range(neighbors.size()):
		if neighbors[i] != gate:
			terrain.set_cell(neighbors[i], Terrain.MOUNTAIN, Terrain.ATLAS)
	for c in terrain.get_surrounding_cells(gate):
		if c != start and not (c in neighbors) and Terrain.enter_cost(terrain.get_cell_source_id(c)) >= 0:
			return c
	return start

func test_no_stop_cell_excluded_from_move() -> void:
	var start := _center()
	var nb: Vector2i = terrain.get_surrounding_cells(start)[0]
	var r := HexGrid.movement_ranges(terrain, start, 3, MAP, MAP, {}, {}, {}, {nb: true})
	assert_does_not_have(r["move"], nb, "no_stop(아군) 칸은 이동 목적지에서 제외(겹칠 수 없음)")

func test_no_stop_does_not_shrink_reach() -> void:
	# no_stop은 통과를 막지 않으므로, 도달 범위(dist)는 아무것도 없을 때와 같다(이동력 손해 없음).
	var start := _center()
	var nb: Vector2i = terrain.get_surrounding_cells(start)[0]
	var open := HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)
	var r := HexGrid.movement_ranges(terrain, start, 3, MAP, MAP, {}, {}, {}, {nb: true})
	assert_eq((r["dist"] as Dictionary).size(), (open["dist"] as Dictionary).size(),
		"no_stop는 BFS 확장을 막지 않아 도달 범위(dist) 동일")
	assert_eq((r["move"] as Array).size(), (open["move"] as Array).size() - 1,
		"move에서는 no_stop 칸 하나만 빠진다")

func test_no_stop_vs_blocked_through_chokepoint() -> void:
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var gate: Vector2i = neighbors[0]
	var beyond := _chokepoint_beyond(start, gate, neighbors)
	assert_ne(beyond, start, "선행: gate 너머 칸을 찾음")
	# 아군(no_stop) gate는 통과 가능 → 너머 도달, 단 gate 자체엔 정지 불가.
	var pass_r := HexGrid.movement_ranges(terrain, start, 3, MAP, MAP, {}, {}, {}, {gate: true})
	assert_has(pass_r["move"], beyond, "아군(no_stop) gate 통과 → 너머 도달")
	assert_does_not_have(pass_r["move"], gate, "단 gate 자체엔 정지 불가")
	# 적(blocked) gate는 통과 불가 → 갇혀 너머 도달 불가(대비).
	var block_r := HexGrid.movement_ranges(terrain, start, 3, MAP, MAP, {gate: true})
	assert_does_not_have(block_r["move"], beyond, "적(blocked) gate는 통과 불가 → 너머 도달 불가")

func test_reconstruct_path_no_stop_dest_empty() -> void:
	var start := _center()
	var nb: Vector2i = terrain.get_surrounding_cells(start)[0]
	var path := HexGrid.reconstruct_path(terrain, start, nb, 2, MAP, MAP, {}, {}, {}, {nb: true})
	assert_eq(path.size(), 0, "목적지가 no_stop 칸이면 빈 경로(겹칠 수 없음)")

func test_reconstruct_path_through_no_stop_chokepoint() -> void:
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var gate: Vector2i = neighbors[0]
	var beyond := _chokepoint_beyond(start, gate, neighbors)
	assert_ne(beyond, start, "선행: gate 너머 칸")
	var path := HexGrid.reconstruct_path(terrain, start, beyond, 3, MAP, MAP, {}, {}, {}, {gate: true})
	assert_eq(path[path.size() - 1], beyond, "no_stop gate를 지나 너머 목적지 도달")
	assert_true(gate in path, "경로가 no_stop gate를 지난다(유일 통로)")

# --- 경로 도달 구간 (path_reachable_prefix) — 파랑/빨강 분할·최대 전진 → selection-and-movement.md ---
# (_straight_path(len)은 아래 attack_move 테스트와 공용 — 중앙에서 +x로 len칸 평지 사슬)

func test_path_prefix_plains_budget() -> void:
	var path := _straight_path(4)   # 4칸 [c0..c3], 칸당 비용 1(누적 c3=3)
	assert_eq(HexGrid.path_reachable_prefix(terrain, path, 2), 2, "budget 2 → 인덱스 2")

func test_path_prefix_budget_zero() -> void:
	var path := _straight_path(4)
	assert_eq(HexGrid.path_reachable_prefix(terrain, path, 0), 0, "budget 0 → 시작칸만(인덱스 0)")

func test_path_prefix_budget_exceeds() -> void:
	var path := _straight_path(3)
	assert_eq(HexGrid.path_reachable_prefix(terrain, path, 99), path.size() - 1, "budget 충분 → 마지막 인덱스(전부 파랑)")

func test_path_prefix_forest_cost() -> void:
	# 첫 이웃을 숲(비용 2)으로: 경로 [start, 숲]. budget 2 → 숲까지(인덱스 1), budget 1 → 인덱스 0.
	var start := _center()
	var n0: Vector2i = terrain.get_surrounding_cells(start)[0]
	terrain.set_cell(n0, Terrain.FOREST, Terrain.ATLAS)
	var path := HexGrid.reconstruct_path(terrain, start, n0, 2, MAP, MAP)
	assert_eq(HexGrid.path_reachable_prefix(terrain, path, 2), 1, "숲(비용 2) 도달 → 인덱스 1")
	assert_eq(HexGrid.path_reachable_prefix(terrain, path, 1), 0, "budget 1 < 숲비용 2 → 인덱스 0")

# --- 사격 위치 (best_fire_cell) — 원거리 카이팅(사거리 내 가장 먼 칸) → selection-and-movement.md ---

func test_best_fire_cell_farthest_in_range() -> void:
	var enemy := _center()
	var d := HexGrid.bfs_distances(terrain, enemy, 3, MAP, MAP)
	var c1 := enemy
	var c2 := enemy
	var c3 := enemy
	for c in d:
		if d[c] == 1: c1 = c
		elif d[c] == 2: c2 = c
		elif d[c] == 3: c3 = c
	var best := HexGrid.best_fire_cell(terrain, [c1, c2, c3], enemy, 2, MAP, MAP)
	assert_eq(int(d[best]), 2, "사거리 내(≤2) 후보 중 가장 먼 칸 = 거리 2(카이팅)")

func test_best_fire_cell_none_in_range() -> void:
	var enemy := _center()
	var d := HexGrid.bfs_distances(terrain, enemy, 4, MAP, MAP)
	var far := enemy
	for c in d:
		if d[c] == 4:
			far = c
			break
	assert_eq(HexGrid.best_fire_cell(terrain, [far], enemy, 2, MAP, MAP), Vector2i(-1, -1), "사거리 밖 후보뿐 → (-1,-1)")

func test_best_fire_cell_includes_start_in_range() -> void:
	var enemy := _center()
	var d := HexGrid.bfs_distances(terrain, enemy, 2, MAP, MAP)
	var adj := enemy
	for c in d:
		if d[c] == 1:
			adj = c
			break
	# 후보가 적 인접(거리 1)뿐이면 그 칸이 최선(사거리 2 이내).
	var best := HexGrid.best_fire_cell(terrain, [adj], enemy, 2, MAP, MAP)
	assert_eq(best, adj, "사거리 내 후보가 하나면 그 칸")

# --- follow_destination (하위부대 작전 추종 목적지) ---

## 영웅으로부터의 지형 거리 맵(산만 제외, 유닛 무관) — 후보 근접 비교용.
func _hero_dist(hero: Vector2i) -> Dictionary:
	return HexGrid.bfs_distances(terrain, hero, MAP + MAP, MAP, MAP, Terrain.IMPASSABLE)

## 영웅 인접 링 중 월드 x가 가장 큰(동쪽) 칸 — 서→동 이동의 전방 타일.
func _east_ring(hero: Vector2i) -> Vector2i:
	var best: Vector2i = terrain.get_surrounding_cells(hero)[0]
	for n in terrain.get_surrounding_cells(hero):
		if terrain.map_to_local(n).x > terrain.map_to_local(best).x:
			best = n
	return best

func test_follow_lands_adjacent_when_reachable() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(3, 0)   # 3칸 떨어짐(방향 없음)
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP)
	assert_true(dest in terrain.get_surrounding_cells(hero), "이동력 충분 → 영웅 인접 링 칸에 배치")

func test_follow_never_targets_hero_cell() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(2, 0)
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 5, MAP, MAP)
	assert_ne(dest, hero, "영웅 칸 자체는 목적지가 아니다")

func test_follow_avoids_no_stop_ring_cell() -> void:
	# 아군(no_stop)이 낀 링 칸엔 못 멈추고 다른 도달 가능 링 칸을 고른다(통과는 가능·정지 불가).
	# 하위부대끼리 서로를 벽으로 막지 않게 하는 핵심(가끔 안따라오던 문제). → squad-stance.md
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(3, 0)
	var open := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP)
	assert_true(open in terrain.get_surrounding_cells(hero), "선행: 막지 않으면 링 칸에 배치")
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP, {}, {}, {}, {open: true})
	assert_ne(dest, open, "no_stop로 막은 링 칸은 목적지로 고르지 않는다")

func test_follow_stays_when_already_adjacent() -> void:
	var hero := _center()
	var follower: Vector2i = terrain.get_surrounding_cells(hero)[0]   # 이미 인접(방향 없음)
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP)
	assert_eq(dest, follower, "방향 없고 이미 인접이면 제자리")

func test_follow_prefers_forward_tile() -> void:
	# 서→동 이동(from=영웅 서쪽), 북쪽 하위부대가 링 전체 도달 가능 → 전방(동쪽) 링 칸 선택.
	var hero := _center()
	var from: Vector2i = hero + Vector2i(-1, 0)
	var follower: Vector2i = hero + Vector2i(0, -2)
	var dest := HexGrid.follow_destination(terrain, hero, from, follower, 5, MAP, MAP)
	assert_true(dest in terrain.get_surrounding_cells(hero), "링 칸에 배치")
	assert_gt(terrain.map_to_local(dest).x, terrain.map_to_local(hero).x, "진행 방향(동)쪽 전방 링 칸 선호")

func test_follow_on_forwardmost_ring_stays() -> void:
	# 이미 최전방(동쪽) 링 칸에 있으면 제자리.
	var hero := _center()
	var from: Vector2i = hero + Vector2i(-1, 0)
	var follower: Vector2i = _east_ring(hero)
	var dest := HexGrid.follow_destination(terrain, hero, from, follower, 3, MAP, MAP)
	assert_eq(dest, follower, "이미 최전방 링 칸이면 제자리")

func test_follow_forward_blocked_takes_other_ring() -> void:
	# 최전방 링 칸이 막히면 다른 도달 가능 링 칸으로(영웅 칸·막힌 칸 아님).
	var hero := _center()
	var from: Vector2i = hero + Vector2i(-1, 0)
	var follower: Vector2i = hero + Vector2i(0, -2)
	var east: Vector2i = _east_ring(hero)
	var dest := HexGrid.follow_destination(terrain, hero, from, follower, 5, MAP, MAP, {east: true})
	assert_true(dest in terrain.get_surrounding_cells(hero), "남은 링 칸에 배치")
	assert_ne(dest, east, "막힌 최전방 칸은 안 고름")

func test_follow_partial_approach_when_movement_short() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(4, 0)   # 4칸 떨어짐
	var d := _hero_dist(hero)
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 1, MAP, MAP)   # 이동력 1
	assert_lt(int(d[dest]), int(d[follower]), "링 못 닿아도 영웅에 더 가까워진다")
	assert_false(dest in terrain.get_surrounding_cells(hero), "인접까지는 못 온다")

func test_follow_avoids_blocked_adjacent() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(2, 0)
	var blocked := {hero + Vector2i(1, 0): true}   # 팔로워 쪽 인접 칸 하나 점유
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP, blocked)
	assert_true(dest in terrain.get_surrounding_cells(hero), "남은 인접 빈 링 칸으로 배치")
	assert_false(blocked.has(dest), "막힌 칸은 고르지 않는다")

func test_follow_all_adjacent_blocked_approaches() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(4, 0)
	var blocked := {}
	for n in terrain.get_surrounding_cells(hero):
		blocked[n] = true   # 영웅 인접 6칸 전부 점유
	var d := _hero_dist(hero)
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 5, MAP, MAP, blocked)
	assert_false(dest in terrain.get_surrounding_cells(hero), "인접 전부 막힘 → 인접 아님")
	assert_lt(int(d[dest]), int(d[follower]), "그래도 최대한 접근")

func test_follow_trapped_stays() -> void:
	var hero := _center()
	var follower: Vector2i = hero + Vector2i(3, 0)
	var blocked := {}
	for n in terrain.get_surrounding_cells(follower):
		blocked[n] = true   # 팔로워 사방 점유 → 이동 불가
	var dest := HexGrid.follow_destination(terrain, hero, hero, follower, 3, MAP, MAP, blocked)
	assert_eq(dest, follower, "완전히 갇히면 제자리")

# --- 직선 경로 헬퍼 (path_reachable_prefix 테스트 등 공용) ---

## 중심에서 동쪽으로 뻗는 직선 경로(같은 행 가로 이웃은 헥스 인접). 좌표계가 바뀌면
## 이 가정이 깨지므로, 경로가 실제로 헥스 인접 사슬인지 여기서 검증해 조용히 틀리지 않게 한다.
func _straight_path(len: int) -> Array:
	var c := _center()
	var path: Array = []
	for i in len:
		var cell: Vector2i = c + Vector2i(i, 0)
		if i > 0:
			assert_true(cell in terrain.get_surrounding_cells(path[i - 1]), "직선 경로 %s가 헥스 인접(좌표계 가정)" % cell)
		path.append(cell)
	return path
