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
## - blocked_cells: 진입 불가 개별 셀 집합({cell: true}). 유닛 점유 칸 등 지형과 무관한 장애물.
static func bfs_distances(terrain: TileMapLayer, start: Vector2i, max_dist: int, map_w: int, map_h: int, blocked: Array = [], blocked_cells: Dictionary = {}) -> Dictionary:
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
			if blocked_cells.has(n):
				continue
			dist[n] = d + 1
			frontier.append(n)
	return dist

## start에서 radius(헥스 거리) 이내로 도달 가능한 셀 목록.
static func cells_within(terrain: TileMapLayer, start: Vector2i, radius: int, map_w: int, map_h: int, blocked: Array = []) -> Array:
	return bfs_distances(terrain, start, radius, map_w, map_h, blocked).keys()

## sources 중 어느 하나에서든 radius 이내인 셀 목록(다중 시작점 BFS). 맵 밖 제외, 지형 무관.
## 공격 범위(이동 프런티어에서 공격거리 이내)를 구하는 데 쓴다.
static func cells_within_any(terrain: TileMapLayer, sources: Array, radius: int, map_w: int, map_h: int) -> Array:
	var dist := {}
	var frontier: Array[Vector2i] = []
	for s in sources:
		if not dist.has(s):
			dist[s] = 0
			frontier.append(s)
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= radius:
			continue
		for n in terrain.get_surrounding_cells(cur):
			if _in_bounds(n, map_w, map_h) and not dist.has(n):
				dist[n] = d + 1
				frontier.append(n)
	return dist.keys()

## 한 칸의 진입비용. 건물 override(cell_costs)가 있으면 그 값을, 없으면 지형(Terrain.enter_cost)을 쓴다.
## 반환 < 0(Terrain.BLOCKED)이면 진입 불가.
static func _cell_enter_cost(terrain: TileMapLayer, cell: Vector2i, cell_costs: Dictionary) -> int:
	if cell_costs.has(cell):
		return cell_costs[cell]
	return Terrain.enter_cost(terrain.get_cell_source_id(cell))

## 두 인접 칸 사이 경계의 정규 키(순서 무관). blocked_edges 집합({key: true})의 키로 쓴다.
## 강·벽처럼 칸 사이 경계에 걸친 이동 차단을 표현한다(칸 자체는 통행 가능, 그 경계만 못 건넘). → 강/벽
static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		var t := a
		a = b
		b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]

## start에서 이동력(budget) 이내로 도달 가능한 각 칸까지의 누적 진입비용 { cell: cost }(start=0).
## - 칸마다 진입비용(지형 Terrain.enter_cost, 또는 cell_costs의 건물비용)을 더한다(가중 BFS = Dijkstra).
## - 진입 불가 칸(비용<0)·blocked_cells(점유 칸)·맵 밖·budget 초과는 제외한다.
## - cell_costs: { cell: 진입비용 } 건물 발자국 override(도시=2 등, 음수면 불가). → build_planner.movement_costs
## - blocked_edges: { edge_key: true } 칸 사이 경계 차단(강·벽). 그 경계로는 못 건넌다(칸은 통행 가능).
static func cost_distances(terrain: TileMapLayer, start: Vector2i, budget: int, map_w: int, map_h: int, blocked_cells: Dictionary = {}, cell_costs: Dictionary = {}, blocked_edges: Dictionary = {}) -> Dictionary:
	var cost := {start: 0}
	var frontier: Array = [[0, start]]   # [누적비용, 셀]. 규모가 작아 매번 최소비용 원소를 선형 탐색해 꺼낸다.
	while not frontier.is_empty():
		var bi := 0
		for i in range(1, frontier.size()):
			if frontier[i][0] < frontier[bi][0]:
				bi = i
		var top: Array = frontier.pop_at(bi)
		var cd: int = top[0]
		var cur: Vector2i = top[1]
		if cd > int(cost[cur]):
			continue   # 이미 더 싼 경로로 확정된 낡은 항목
		for n in terrain.get_surrounding_cells(cur):
			if not _in_bounds(n, map_w, map_h) or blocked_cells.has(n):
				continue
			if not blocked_edges.is_empty() and blocked_edges.has(edge_key(cur, n)):
				continue   # 강·벽 경계 — 이 방향으로 못 건넘(칸 자체는 열려 있음)
			var ec := _cell_enter_cost(terrain, n, cell_costs)
			if ec < 0:
				continue   # 진입 불가(산·물·불가 건물)
			var nc := cd + ec
			if nc <= budget and nc < int(cost.get(n, nc + 1)):
				cost[n] = nc
				frontier.append([nc, n])
	return cost

## 이동력 기준 이동/공격 범위를 분할해 돌려준다(칸당 진입비용 반영).
## - move: 이동력(budget) 이내 누적비용으로 도달 가능한 칸(시작칸 비용 0 제외). 숲(2)·습지(3)·도시(2)가 더 비싸다.
## - attack: **이동 가능 영역(+시작칸) 바로 바깥 한 칸**. 진입 불가 칸(산·물·불가 건물)은 제외.
## - dist: 시작칸(0) 포함 누적비용 맵 (진입 불가 제외).
## no_stop_cells: 통과는 가능하되 목적지로는 못 삼는 칸(아군 점유). BFS 확장은 막지 않고 move 목적지에서만 제외한다. → selection-and-movement.md
static func movement_ranges(terrain: TileMapLayer, start: Vector2i, move_range: int, map_w: int, map_h: int, blocked_cells: Dictionary = {}, cell_costs: Dictionary = {}, blocked_edges: Dictionary = {}, no_stop_cells: Dictionary = {}) -> Dictionary:
	var cost := cost_distances(terrain, start, move_range, map_w, map_h, blocked_cells, cell_costs, blocked_edges)
	var move_set := {}
	var move_cells: Array[Vector2i] = []
	for cell in cost:
		if int(cost[cell]) == 0:
			continue  # 주인공이 선 칸은 제외
		if no_stop_cells.has(cell):
			continue  # 아군 점유 — 통과는 가능(cost엔 있음)하나 목적지로는 못 삼음
		move_set[cell] = true
		move_cells.append(cell)

	# 공격 = 이동 가능 칸 및 시작칸의 이웃 중, 이동칸/시작칸이 아니고 진입 가능한 칸.
	var attack_set := {}
	var seeds := move_cells.duplicate()
	seeds.append(start)
	for src in seeds:
		for n in terrain.get_surrounding_cells(src):
			if not _in_bounds(n, map_w, map_h) or n == start:
				continue
			if move_set.has(n) or attack_set.has(n):
				continue
			if _cell_enter_cost(terrain, n, cell_costs) < 0:
				continue
			attack_set[n] = true
	var attack_cells: Array[Vector2i] = []
	for cell in attack_set:
		attack_cells.append(cell)
	return {"move": move_cells, "attack": attack_cells, "dist": cost}

## start에서 dest까지 최소비용 경로(칸 목록, start·dest 포함)를 누적비용 맵에서 역추적한다.
## - 진입 불가(산·물·불가 건물)·맵 밖·blocked_cells(점유 칸)는 제외한다(이동 계산과 같은 규칙).
## - dest에 도달 불가하면 빈 배열, start == dest면 [start].
## - NPC·플레이어 이동 애니메이션이 토큰을 칸 단위로 걸어가게 하는 데 쓴다.
## no_stop_cells: 아군 점유 칸. 경로가 지나갈 수는 있으나 dest로는 못 삼는다(dest면 빈 경로). → selection-and-movement.md
static func reconstruct_path(terrain: TileMapLayer, start: Vector2i, dest: Vector2i, move_range: int, map_w: int, map_h: int, blocked_cells: Dictionary = {}, cell_costs: Dictionary = {}, blocked_edges: Dictionary = {}, no_stop_cells: Dictionary = {}) -> Array[Vector2i]:
	if start == dest:
		return [start]
	if no_stop_cells.has(dest):
		return []   # 아군 점유 칸엔 멈출 수 없다(겹칠 수 없음)
	var cost := cost_distances(terrain, start, move_range, map_w, map_h, blocked_cells, cell_costs, blocked_edges)
	if not cost.has(dest):
		return []
	# dest에서 "누적비용 - 그 칸 진입비용" == 이웃 누적비용인 선행 칸을 따라 start까지 거꾸로 짚어간다.
	# 차단된 경계(blocked_edges)는 실제 경로가 지날 수 없으므로 선행 후보에서 제외한다(다른 경로로 같은 비용인 칸 오선택 방지).
	var path: Array[Vector2i] = [dest]
	var cur := dest
	while cur != start:
		var need: int = int(cost[cur]) - _cell_enter_cost(terrain, cur, cell_costs)
		var stepped := false
		for n in terrain.get_surrounding_cells(cur):
			if not blocked_edges.is_empty() and blocked_edges.has(edge_key(cur, n)):
				continue
			if int(cost.get(n, -1)) == need:
				cur = n
				path.append(cur)
				stepped = true
				break
		if not stepped:
			return []   # 안전장치: 역추적 실패(정상 경로에선 발생하지 않음)
	path.reverse()
	return path

## 하위부대(follower_cell)가 영웅(hero_cell)을 따라갈 목적지 칸을 고른다(작전 추종). → docs/spec/features/squad-stance.md
## from_cell = 영웅의 이번 턴 출발 칸(진행 방향 기준). 지휘관을 한 줄로 뒤쫓지 않고 주변 링에 대형 짓게 한다.
## - 후보 = 제자리 + 도달 가능 칸(movement_ranges의 move). 산·blocked_cells·hero_cell 제외.
## - 링 우선: 도달 가능한 영웅 인접 칸(get_surrounding_cells)이 있으면 그중 진행 방향으로 가장 앞선 칸(월드 내적 최대),
##   동률이면 하위부대에서 가까운 칸. from_cell==hero_cell(방향 없음)이면 전방 점수 0 → 가까운 링 칸(분산).
## - 접근 폴백: 도달 가능한 링 칸이 없으면 영웅 지형 거리(bfs) 최소 칸(동률 시 근접). 더 못 가까워지면 제자리.
## - no_stop_cells(아군·예약 칸)는 통과는 되나 목적지로는 못 삼는다 — 하위부대가 서로를 벽으로 막지 않게(뚫고 지나감). → selection-and-movement.md
static func follow_destination(terrain: TileMapLayer, hero_cell: Vector2i, from_cell: Vector2i, follower_cell: Vector2i, move_range: int, map_w: int, map_h: int, blocked_cells: Dictionary = {}, cell_costs: Dictionary = {}, blocked_edges: Dictionary = {}, no_stop_cells: Dictionary = {}) -> Vector2i:
	var ranges := movement_ranges(terrain, follower_cell, move_range, map_w, map_h, blocked_cells, cell_costs, blocked_edges, no_stop_cells)
	var self_dist: Dictionary = ranges["dist"]   # 하위부대로부터의 거리(제자리 0)
	var big := map_w * map_h + 1
	var reachable := {follower_cell: true}
	for c in ranges["move"]:
		reachable[c] = true
	reachable.erase(hero_cell)   # 영웅이 설 칸은 목적지 아님

	# 진행 방향(월드 벡터). from_cell==hero_cell이면 0 → 전방 점수 모두 0.
	var hw := terrain.map_to_local(hero_cell)
	var fdir := hw - terrain.map_to_local(from_cell)

	# 링 우선: 도달 가능한 영웅 인접 칸 중 전방 점수(내적) 최대, 동률이면 하위부대 근접.
	var best_ring := Vector2i(-1, -1)
	var best_score := -INF
	for n in terrain.get_surrounding_cells(hero_cell):
		if not reachable.has(n):
			continue
		var s: float = (terrain.map_to_local(n) - hw).dot(fdir)
		if s > best_score or (is_equal_approx(s, best_score) and self_dist.get(n, big) < self_dist.get(best_ring, big)):
			best_score = s
			best_ring = n
	if best_ring != Vector2i(-1, -1):
		return best_ring

	# 접근 폴백: 링에 못 닿음 → 영웅 지형 거리 최소 칸(동률 시 근접).
	var hero_dist := bfs_distances(terrain, hero_cell, map_w + map_h, map_w, map_h, Terrain.IMPASSABLE)
	var best := follower_cell
	var best_h: int = hero_dist.get(follower_cell, big)
	for c in reachable:
		var h: int = hero_dist.get(c, big)
		if h < best_h or (h == best_h and self_dist.get(c, big) < self_dist.get(best, big)):
			best_h = h
			best = c
	return best

## 경로(path)를 훑어 시작(path[0])부터의 누적 진입비용이 budget 이하인 마지막 인덱스를 반환한다.
## 호버 미리보기 파랑/빨강 분할, 범위 밖 최대 전진 목적지의 단일 출처. path[0]은 항상 포함(0 반환 가능).
## cell_costs = 건물 진입비용 override(도시 2 등). 노드 비의존 순수 함수. → selection-and-movement.md
static func path_reachable_prefix(terrain: TileMapLayer, path: Array, budget: int, cell_costs: Dictionary = {}) -> int:
	var idx := 0
	var acc := 0
	for i in range(1, path.size()):
		acc += _cell_enter_cost(terrain, path[i], cell_costs)
		if acc <= budget:
			idx = i
		else:
			break
	return idx

## candidates(도달 가능 정지 칸 ∪ 시작칸) 중 적까지 헥스 거리 reach 이내이면서 가장 먼 칸을 고른다(원거리 카이팅).
## 동점이면 candidates 순서상 먼저 것. 사거리 내 후보가 없으면 (-1,-1). 노드 비의존 순수 함수. → selection-and-movement.md
static func best_fire_cell(terrain: TileMapLayer, candidates: Array, enemy_cell: Vector2i, reach: int, map_w: int, map_h: int) -> Vector2i:
	var d := bfs_distances(terrain, enemy_cell, reach, map_w, map_h)   # 적으로부터 헥스 거리(≤reach인 칸만)
	var best := Vector2i(-1, -1)
	var best_d := -1
	for c in candidates:
		if d.has(c) and int(d[c]) > best_d:
			best_d = int(d[c])
			best = c
	return best

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

## 인접한 두 칸 a,b의 **공유 변(경계) 선분** [p0, p1](월드 좌표). 강·벽 렌더·경계 편집 툴이 쓴다.
## 두 헥스 폴리곤에 공통으로 있는 꼭짓점 2개를 찾는다. 못 찾으면(비인접 등) 중점 기준 짧은 수직선으로 폴백.
static func edge_segment(terrain: TileMapLayer, a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var pa := hex_polygon(terrain, a)
	var pb := hex_polygon(terrain, b)
	var shared := PackedVector2Array()
	for va in pa:
		for vb in pb:
			if va.distance_to(vb) < 1.0:
				shared.append(va)
				break
	if shared.size() >= 2:
		return PackedVector2Array([shared[0], shared[1]])
	var ca := terrain.map_to_local(a)
	var cb := terrain.map_to_local(b)
	var mid := (ca + cb) * 0.5
	var d := (cb - ca).orthogonal().normalized() * (Vector2(terrain.tile_set.tile_size).y * 0.25)
	return PackedVector2Array([mid - d, mid + d])

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
