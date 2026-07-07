class_name HexGrid
extends RefCounted
## 헥스 그리드 BFS 유틸. 이동/공격 범위와 시야 계산이 공유한다.
## 헥스 인접은 엔진(TileMapLayer.get_surrounding_cells)에 위임하므로,
## 실제 헥스 타일셋을 가진 TileMapLayer를 넘겨야 한다.

## start에서 BFS로 각 셀까지의 헥스 거리를 구한다.
## - 반환: { cell: distance } (start는 거리 0 포함).
## - max_dist 거리의 셀까지 포함하되, 그 셀에서 더 확장하지는 않는다.
## - 맵 범위 [0, map_w) x [0, map_h) 밖은 제외한다.
## - blocked: 진입 불가 지형의 타일 source id 목록(예: 산). 그런 셀은 도달·통과 대상에서 제외한다.
##   시야는 지형에 막히지 않으므로 기본값 []로 두고, 이동 계산에서만 넘긴다.
static func bfs_distances(terrain: TileMapLayer, start: Vector2i, max_dist: int, map_w: int, map_h: int, blocked: Array = []) -> Dictionary:
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
			if not blocked.is_empty() and terrain.get_cell_source_id(n) in blocked:
				continue
			dist[n] = d + 1
			frontier.append(n)
	return dist

## start에서 radius(헥스 거리) 이내로 도달 가능한 셀 목록.
static func cells_within(terrain: TileMapLayer, start: Vector2i, radius: int, map_w: int, map_h: int, blocked: Array = []) -> Array:
	return bfs_distances(terrain, start, radius, map_w, map_h, blocked).keys()

## 이동력 기준 이동/공격 범위를 분할해 돌려준다(지형 반영).
## - 산(Terrain.IMPASSABLE)은 진입·통과 불가라 dist에서 아예 제외된다.
## - move: 각 셀의 지형 이동 상한(Terrain.move_cap) 이내로 도달 가능한 칸(시작칸 거리 0 제외).
##   숲 칸은 ceil(이동력/2), 습지 칸은 floor(이동력/2)까지만 이동 목적지가 된다.
## - attack: **이동 가능 영역(+시작칸) 바로 바깥 한 칸**. 숲/습지로 이동이 짧아진 방향에서도
##   공격 링이 실제 이동 프런티어에 붙는다(평지에선 거리 move_range+1 링과 같다). 산 칸은 제외.
## - dist: 시작칸 포함 거리 맵 (산 제외). max_dist = move_range.
static func movement_ranges(terrain: TileMapLayer, start: Vector2i, move_range: int, map_w: int, map_h: int) -> Dictionary:
	var dist := bfs_distances(terrain, start, move_range, map_w, map_h, Terrain.IMPASSABLE)
	var move_set := {}
	var move_cells: Array[Vector2i] = []
	for cell in dist:
		var d: int = dist[cell]
		if d == 0:
			continue  # 주인공이 선 칸은 제외
		if d <= Terrain.move_cap(terrain.get_cell_source_id(cell), move_range):
			move_set[cell] = true
			move_cells.append(cell)

	# 공격 = 이동 가능 칸 및 시작칸의 이웃 중, 이동칸/시작칸이 아니고 통과 가능한 칸.
	var attack_set := {}
	var seeds := move_cells.duplicate()
	seeds.append(start)
	for src in seeds:
		for n in terrain.get_surrounding_cells(src):
			if not _in_bounds(n, map_w, map_h) or n == start:
				continue
			if move_set.has(n) or attack_set.has(n):
				continue
			if terrain.get_cell_source_id(n) in Terrain.IMPASSABLE:
				continue
			attack_set[n] = true
	var attack_cells: Array[Vector2i] = []
	for cell in attack_set:
		attack_cells.append(cell)
	return {"move": move_cells, "attack": attack_cells, "dist": dist}

static func _in_bounds(cell: Vector2i, map_w: int, map_h: int) -> bool:
	return cell.x >= 0 and cell.x < map_w and cell.y >= 0 and cell.y < map_h

## 셀의 헥스 6꼭짓점(뾰족한 위/아래, 타일셋 tile_size 기준). 월드 좌표.
## 오버레이(RangeOverlay·BuildPreview)가 그리는 헥스와 동일한 모양이라, 인접 셀끼리 변이 정확히 맞닿는다.
static func hex_polygon(terrain: TileMapLayer, cell: Vector2i) -> PackedVector2Array:
	var c := terrain.map_to_local(cell)
	var ts := Vector2(terrain.tile_set.tile_size)
	var hw := ts.x * 0.5
	var hh := ts.y * 0.5
	return PackedVector2Array([
		c + Vector2(0.0, -hh),
		c + Vector2(hw, -hh * 0.5),
		c + Vector2(hw, hh * 0.5),
		c + Vector2(0.0, hh),
		c + Vector2(-hw, hh * 0.5),
		c + Vector2(-hw, -hh * 0.5),
	])

## 영역(cells: {cell: true} 또는 셀 배열)의 바깥 윤곽선을 이루는 변 목록.
## 각 셀의 6변 중 이웃과 공유하지 않는 변만 남긴다(내부 변은 두 번 나와 상쇄).
## 반환: 각 항목이 [시작점, 끝점]인 PackedVector2Array 배열(월드 좌표).
static func region_outline(terrain: TileMapLayer, cells) -> Array:
	var counts := {}   # 변 키 → 등장 횟수
	var segs := {}     # 변 키 → PackedVector2Array([a, b])
	for cell in cells:
		var poly := hex_polygon(terrain, cell)
		for i in 6:
			var a := poly[i]
			var b := poly[(i + 1) % 6]
			var key := _edge_key(a, b)
			counts[key] = counts.get(key, 0) + 1
			if not segs.has(key):
				segs[key] = PackedVector2Array([a, b])
	var outline: Array = []
	for key in counts:
		if counts[key] == 1:
			outline.append(segs[key])
	return outline

## 두 꼭짓점으로 만든 변의 정규 키. 순서 무관하게 같은 변이 같은 키를 갖도록 정렬하고,
## 인접 헥스의 공유 변이 부동소수 오차로 어긋나지 않게 정수로 반올림해 비교한다.
static func _edge_key(a: Vector2, b: Vector2) -> String:
	var pa := Vector2i(roundi(a.x), roundi(a.y))
	var pb := Vector2i(roundi(b.x), roundi(b.y))
	if pb.x < pa.x or (pb.x == pa.x and pb.y < pa.y):
		var t := pa
		pa = pb
		pb = t
	return "%d,%d|%d,%d" % [pa.x, pa.y, pb.x, pb.y]
