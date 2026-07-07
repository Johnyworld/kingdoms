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
	terrain.tile_set = load("res://tiles/grass_tileset.tres")
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
	assert_eq((r["attack"] as Array).size(), 18, "이동력 2: 공격 = 거리3 링 18셀")
	assert_eq((r["dist"] as Dictionary).size(), 37, "dist는 거리3까지 전체 맵 (누적 37셀)")

func test_start_cell_excluded_from_ranges() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_does_not_have(r["move"], _center(), "시작칸은 이동 범위에서 제외")
	assert_does_not_have(r["attack"], _center(), "시작칸은 공격 범위에서 제외")

func test_range_dist_includes_start() -> void:
	var r := HexGrid.movement_ranges(terrain, _center(), 2, MAP, MAP)
	assert_true((r["dist"] as Dictionary).has(_center()), "dist 맵에는 시작칸 포함")

# --- hex_polygon / region_outline (건설 가능 영역 윤곽선) ---

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
