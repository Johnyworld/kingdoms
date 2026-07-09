class_name NpcAi
extends RefCounted
## NPC 부대 이동 결정. 가장 가까운 적(targets)에게 접근하고, 향할 적이 없으면 무작위로 배회하는 단순 AI.
## 노드에 의존하지 않는 순수 로직이라(ClickRouter·HexGrid 패턴) 시드 RNG로 결정적 테스트가 가능하다.

## NPC 이동 목적지를 고른다.
## - targets가 있으면: 이동 칸 중 가장 가까운 적(targets)과의 월드 거리가 최소인 칸으로 접근한다.
##   시작 칸보다 가까워지는 칸이 없으면 제자리(적에게서 멀어지지 않는다).
## - targets가 없으면: 도달 가능한 가장 먼 칸 중 하나로 무작위 이동(배회).
## 지형 규칙(산 불가·숲/습지 반감)·맵 경계·점유 칸(blocked_cells)은 HexGrid.movement_ranges가 반영한다.
## 도달 가능한 이동 칸이 없으면(이동력 0, 사방이 산/점유/맵 밖 등) start를 그대로 반환한다(제자리).
static func choose_destination(terrain: TileMapLayer, start: Vector2i, move_range: int, map_w: int, map_h: int, rng: RandomNumberGenerator, blocked_cells: Dictionary = {}, targets: Array = []) -> Vector2i:
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, map_w, map_h, blocked_cells)
	var move_cells: Array = ranges["move"]
	if move_cells.is_empty():
		return start

	if targets.is_empty():
		return _wander(move_cells, rng)
	return _approach(terrain, start, move_cells, targets, rng)

## 배회: 도달 가능한 이동 칸 중 하나를 무작위(거리 무관 — 반드시 최대 이동력만큼 가지 않는다).
static func _wander(move_cells: Array, rng: RandomNumberGenerator) -> Vector2i:
	return move_cells[rng.randi_range(0, move_cells.size() - 1)]

## 접근: 가장 가까운 타깃과의 월드 거리가 최소인 이동 칸. 시작보다 가까운 칸이 없으면 start.
static func _approach(terrain: TileMapLayer, start: Vector2i, move_cells: Array, targets: Array, rng: RandomNumberGenerator) -> Vector2i:
	const EPS := 0.01
	var start_d := _nearest_dist(terrain, start, targets)
	var best: Array = []
	var best_d := INF
	for c in move_cells:
		var d := _nearest_dist(terrain, c, targets)
		if d < best_d - EPS:
			best_d = d
			best = [c]
		elif absf(d - best_d) <= EPS:
			best.append(c)
	if best.is_empty() or best_d >= start_d - EPS:
		return start   # 더 가까워지는 칸 없음 → 제자리
	return best[rng.randi_range(0, best.size() - 1)]

## cell에서 가장 가까운 타깃까지의 월드 좌표 거리.
static func _nearest_dist(terrain: TileMapLayer, cell: Vector2i, targets: Array) -> float:
	var cw := terrain.map_to_local(cell)
	var best := INF
	for t in targets:
		best = minf(best, cw.distance_to(terrain.map_to_local(t)))
	return best
