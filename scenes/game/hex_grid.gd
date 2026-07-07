class_name HexGrid
extends RefCounted
## 헥스 그리드 BFS 유틸. 이동/공격 범위와 시야 계산이 공유한다.
## 헥스 인접은 엔진(TileMapLayer.get_surrounding_cells)에 위임하므로,
## 실제 헥스 타일셋을 가진 TileMapLayer를 넘겨야 한다.

## start에서 BFS로 각 셀까지의 헥스 거리를 구한다.
## - 반환: { cell: distance } (start는 거리 0 포함).
## - max_dist 거리의 셀까지 포함하되, 그 셀에서 더 확장하지는 않는다.
## - 맵 범위 [0, map_w) x [0, map_h) 밖은 제외한다.
static func bfs_distances(terrain: TileMapLayer, start: Vector2i, max_dist: int, map_w: int, map_h: int) -> Dictionary:
	var dist := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= max_dist:
			continue
		for n in terrain.get_surrounding_cells(cur):
			if not _in_bounds(n, map_w, map_h) or dist.has(n):
				continue
			dist[n] = d + 1
			frontier.append(n)
	return dist

## start에서 radius(헥스 거리) 이내로 도달 가능한 셀 목록.
static func cells_within(terrain: TileMapLayer, start: Vector2i, radius: int, map_w: int, map_h: int) -> Array:
	return bfs_distances(terrain, start, radius, map_w, map_h).keys()

## 이동력 기준 이동/공격 범위를 분할해 돌려준다.
## - move: 헥스 거리 1 ~ move_range (시작칸 거리 0은 제외)
## - attack: 헥스 거리 move_range + 1 (마지막 링)
## - dist: 시작칸 포함 전체 거리 맵 (이동 판정에 사용)
static func movement_ranges(terrain: TileMapLayer, start: Vector2i, move_range: int, map_w: int, map_h: int) -> Dictionary:
	var dist := bfs_distances(terrain, start, move_range + 1, map_w, map_h)
	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []
	for cell in dist:
		var d: int = dist[cell]
		if d == 0:
			continue  # 주인공이 선 칸은 제외
		elif d <= move_range:
			move_cells.append(cell)
		else:
			attack_cells.append(cell)
	return {"move": move_cells, "attack": attack_cells, "dist": dist}

static func _in_bounds(cell: Vector2i, map_w: int, map_h: int) -> bool:
	return cell.x >= 0 and cell.x < map_w and cell.y >= 0 and cell.y < map_h
