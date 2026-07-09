class_name NpcAi
extends RefCounted
## NPC 부대 이동 결정. 목표 지향 판단 없이 도달 가능한 가장 먼 칸으로 무작위 이동하는 단순 AI.
## 노드에 의존하지 않는 순수 로직이라(ClickRouter·HexGrid 패턴) 시드 RNG로 결정적 테스트가 가능하다.

## 이동력만큼 도달 가능한 칸 중 **가장 먼 거리**의 칸 하나를 rng로 골라 반환한다.
## 지형 규칙(산 불가·숲/습지 반감)·맵 경계·점유 칸(blocked_cells)은 HexGrid.movement_ranges가 반영한다.
## 도달 가능한 이동 칸이 없으면(이동력 0, 사방이 산/점유/맵 밖 등) start를 그대로 반환한다(제자리).
static func choose_destination(terrain: TileMapLayer, start: Vector2i, move_range: int, map_w: int, map_h: int, rng: RandomNumberGenerator, blocked_cells: Dictionary = {}) -> Vector2i:
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, map_w, map_h, blocked_cells)
	var move_cells: Array = ranges["move"]
	if move_cells.is_empty():
		return start

	# 도달 가능한 최대 거리의 칸들만 후보로 추린다.
	var dist: Dictionary = ranges["dist"]
	var max_d := 0
	for c in move_cells:
		max_d = maxi(max_d, dist[c])
	var farthest: Array = []
	for c in move_cells:
		if dist[c] == max_d:
			farthest.append(c)

	return farthest[rng.randi_range(0, farthest.size() - 1)]
