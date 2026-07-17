class_name BattleField
extends RefCounted
## 전투씬의 공간 판정을 노드 없이 계산하는 순수 함수(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 유닛은 `{team, alive, pos, human, ...}` 형태의 Dictionary로 다룬다(테스트 용이).

## unit과 다른 팀의 살아있는 유닛 중 pos 거리가 가장 가까운 것. 없으면 빈 Dictionary.
## 공성 전투원(siege)·성벽 구조물(structure)은 표적에서 제외한다(이들은 투석 볼리만 노림). → docs/spec/features/siege-engines.md
static func nearest_enemy(unit: Dictionary, units: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for u in units:
		if u["team"] == unit["team"] or not u["alive"] or u.get("siege", false) or u.get("structure", false):
			continue
		var d: float = unit["pos"].distance_squared_to(u["pos"])
		if d < best_d:
			best_d = d
			best = u
	return best

## 투석기 광역 공격 표적(한 발 최대 n명). 다른 팀 살아있는 유닛 중 적 공성 전투원(siege)을 우선,
## 그다음 일반 유닛, 각 그룹 내 거리순으로 최대 n명. nearest_enemy와 달리 공성 전투원을 포함(대포병 결투). → siege-engines.md
static func bombard_targets(unit: Dictionary, units: Array, n: int) -> Array:
	var siege_e: Array = []
	var human_e: Array = []
	for u in units:
		if u["team"] == unit["team"] or not u["alive"]:
			continue
		if u.get("siege", false):
			siege_e.append(u)
		else:
			human_e.append(u)
	var by_dist := func(a, b): return unit["pos"].distance_squared_to(a["pos"]) < unit["pos"].distance_squared_to(b["pos"])
	siege_e.sort_custom(by_dist)
	human_e.sort_custom(by_dist)
	return (siege_e + human_e).slice(0, n)

## 그 팀에 살아있는 (비공성) 유닛이 하나도 없으면 true. 승패는 Human 기준 — 공성 전투원은 무시.
static func team_wiped(units: Array, team: String) -> bool:
	for u in units:
		if u["team"] == team and u["alive"] and not u.get("siege", false):
			return false
	return true

## 그 팀의 살아있는 유닛들의 human 목록. 공성 전투원·성벽 구조물(human 없음)은 제외.
static func survivors(units: Array, team: String) -> Array:
	var out: Array = []
	for u in units:
		if u["team"] == team and u["alive"] and not u.get("siege", false) and not u.get("structure", false):
			out.append(u["human"])
	return out

## 사거리 ≥ 2 유닛이 최근접 적과의 거리 dist가 threshold 이하이면 근접 전환(true). 근접 유닛은 항상 false.
static func archer_should_charge(unit_range: int, dist: float, threshold: float) -> bool:
	return unit_range >= 2 and dist <= threshold

## 그 team의 살아있는 공성 전투원(siege) 중 밴드(min_range ≤ distance ≤ range) 안 유닛 목록.
## 오버레이 투석 순차 연출이 한 진영의 발사 대상·반격 가능 여부(빈 배열이면 반격 없음)에 쓴다.
## 구조물(structure)·일반 유닛은 제외. → docs/spec/features/battle.md 투석 순차 연출
static func firing_siege(units: Array, team: String, distance: int) -> Array:
	var out: Array = []
	for u in units:
		if u["team"] == team and u["alive"] and u.get("siege", false) \
				and distance >= u["min_range"] and distance <= u["range"]:
			out.append(u)
	return out

## 발 겹침 분리(separation)용 순수 계산 — 서로 radius보다 가까운 점 쌍을 겹침량 비례로 밀어내는 유닛별 오프셋.
## 유효거리는 세로 성분을 y_scale배로 부풀려 잰다(다리 footprint만 판정 — 가로 근접은 강하게, 세로 깊이는 약하게).
## 밀림 방향은 실제 방향(주로 가로), 쌍마다 절반씩 대칭. 유닛별 총 오프셋은 max_push로 클램프. 겹침 없으면 영벡터.
## 같은 위치(유효거리 0)는 크래시 없이 건너뛴다. RNG·상태 없이 결정적. → docs/spec/features/battle.md 발 겹침 분리
static func separation_offsets(points: Array, radius: float, max_push: float, y_scale: float) -> Array:
	var n := points.size()
	var offs: Array = []
	offs.resize(n)
	for i in n:
		offs[i] = Vector2.ZERO
	for i in n:
		for j in range(i + 1, n):
			var delta: Vector2 = points[i] - points[j]
			var d: float = Vector2(delta.x, delta.y * y_scale).length()   # 세로 부풀린 유효거리
			if d <= 0.0 or d >= radius:
				continue
			var push: Vector2 = delta.normalized() * ((radius - d) * 0.5)   # 겹침량 절반씩 양쪽에
			offs[i] += push
			offs[j] -= push
	for i in n:
		if offs[i].length() > max_push:
			offs[i] = offs[i].normalized() * max_push
	return offs
