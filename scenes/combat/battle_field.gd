class_name BattleField
extends RefCounted
## 전투씬의 공간 판정을 노드 없이 계산하는 순수 함수(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 유닛은 `{team, alive, pos, human, ...}` 형태의 Dictionary로 다룬다(테스트 용이).

## unit과 다른 팀의 살아있는 유닛 중 pos 거리가 가장 가까운 것. 없으면 빈 Dictionary.
static func nearest_enemy(unit: Dictionary, units: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for u in units:
		if u["team"] == unit["team"] or not u["alive"]:
			continue
		var d: float = unit["pos"].distance_squared_to(u["pos"])
		if d < best_d:
			best_d = d
			best = u
	return best

## 그 팀에 살아있는 유닛이 하나도 없으면 true.
static func team_wiped(units: Array, team: String) -> bool:
	for u in units:
		if u["team"] == team and u["alive"]:
			return false
	return true

## 그 팀의 살아있는 유닛들의 human 목록.
static func survivors(units: Array, team: String) -> Array:
	var out: Array = []
	for u in units:
		if u["team"] == team and u["alive"]:
			out.append(u["human"])
	return out

## 사거리 ≥ 2 유닛이 최근접 적과의 거리 dist가 threshold 이하이면 근접 전환(true). 근접 유닛은 항상 false.
static func archer_should_charge(unit_range: int, dist: float, threshold: float) -> bool:
	return unit_range >= 2 and dist <= threshold
