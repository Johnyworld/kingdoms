class_name NpcAi
extends RefCounted
## NPC 부대 이동 결정. 가장 가까운 적(targets)에게 접근하고, 향할 적이 없으면 무작위로 배회하는 단순 AI.
## 노드에 의존하지 않는 순수 로직이라(ClickRouter·HexGrid 패턴) 시드 RNG로 결정적 테스트가 가능하다.

# 자기 전력이 적 전력의 이 비율 미만이면 교전을 피한다(신중한 교전·후퇴 판단).
const CAUTION_RATIO := 0.7

# NPC 수비대 투석기 주기 생산(경제 미사용이라 자원 대신 턴 주기·상한). → docs/spec/features/siege-engines.md
const NPC_SIEGE_INTERVAL := 5   # 생산 주기(턴)
const NPC_SIEGE_CAP := 2        # 수비대 투석기 상한

## NPC 수비대가 이번 턴에 투석기를 보충 생산할지 — 주기(INTERVAL) 도달 + 상한(CAP) 미만. turn 0은 생산 안 함.
static func should_produce_siege(turn: int, siege_count: int) -> bool:
	return turn > 0 and turn % NPC_SIEGE_INTERVAL == 0 and siege_count < NPC_SIEGE_CAP

## 부대 전력 = 멤버 hit_points 합. 부상당하면 낮아진다(교전/후퇴 판단에 쓴다).
static func party_power(members: Array) -> int:
	var p := 0
	for m in members:
		p += m.hit_points
	return p

## 자기 전력이 적 전력의 CAUTION_RATIO 이상이면 교전할 만하다(아니면 회피/후퇴).
static func should_engage(my_power: int, enemy_power: int) -> bool:
	return float(my_power) >= float(enemy_power) * CAUTION_RATIO

## 원거리 파워가 근접 파워보다 크면 원거리 교전 선호(동률·근접 우위·무장 없음은 근접). 교전 포지셔닝에 쓴다. → npc-movement.md
static func prefers_ranged(melee_power: int, ranged_power: int) -> bool:
	return ranged_power > melee_power

## entries({cell, faction}) 중 소속이 self_faction과 다른 항목의 cell만 모은다(적 셀 목록).
## 부대·캠프를 같은 형식으로 넘겨 세력으로 적/아군을 가른다. game.gd가 타깃 조립에 쓴다.
static func enemy_cells(self_faction: String, entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		if e["faction"] != self_faction:
			out.append(e["cell"])
	return out

## 타깃 우선순위: 방어 대상(defend)이 있으면 그것만(자기 캠프 곁 위협 요격), 없으면 진격 타깃(advance).
static func select_targets(advance: Array, defend: Array) -> Array:
	return defend if not defend.is_empty() else advance

## 티어 목록에서 처음으로 비어 있지 않은 티어를 고른다(표적 우선순위). 전부 비면 빈 배열.
static func prioritize(tiers: Array) -> Array:
	for t in tiers:
		if not (t as Array).is_empty():
			return t
	return []

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
