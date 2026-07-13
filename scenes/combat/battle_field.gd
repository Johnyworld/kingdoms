class_name BattleField
extends RefCounted
## 전투씬의 공간 판정을 노드 없이 계산하는 순수 함수(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 유닛은 `{team, alive, pos, human, ...}` 형태의 Dictionary로 다룬다(테스트 용이).

## unit과 다른 팀의 살아있는 유닛 중 pos 거리가 가장 가까운 것. 없으면 빈 Dictionary.
## 공성 전투원(siege)은 표적에서 제외한다(투석기 피격은 5d-3). → docs/spec/features/siege-engines.md
static func nearest_enemy(unit: Dictionary, units: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for u in units:
		if u["team"] == unit["team"] or not u["alive"] or u.get("siege", false):
			continue
		var d: float = unit["pos"].distance_squared_to(u["pos"])
		if d < best_d:
			best_d = d
			best = u
	return best

## unit과 다른 팀의 살아있는 유닛을 거리순(가까운 순)으로 최대 n명. 없으면 빈 배열. 공성 전투원 제외.
## 투석기 광역 공격(한 발 최대 5명)이 쓴다. → docs/spec/features/siege-engines.md
static func nearest_enemies(unit: Dictionary, units: Array, n: int) -> Array:
	var enemies: Array = []
	for u in units:
		if u["team"] == unit["team"] or not u["alive"] or u.get("siege", false):
			continue
		enemies.append(u)
	enemies.sort_custom(func(a, b): return unit["pos"].distance_squared_to(a["pos"]) < unit["pos"].distance_squared_to(b["pos"]))
	return enemies.slice(0, n)

## 그 팀에 살아있는 (비공성) 유닛이 하나도 없으면 true. 승패는 Human 기준 — 공성 전투원은 무시.
static func team_wiped(units: Array, team: String) -> bool:
	for u in units:
		if u["team"] == team and u["alive"] and not u.get("siege", false):
			return false
	return true

## 그 팀의 살아있는 유닛들의 human 목록. 공성 전투원(human 없음)은 제외.
static func survivors(units: Array, team: String) -> Array:
	var out: Array = []
	for u in units:
		if u["team"] == team and u["alive"] and not u.get("siege", false):
			out.append(u["human"])
	return out

## 사거리 ≥ 2 유닛이 최근접 적과의 거리 dist가 threshold 이하이면 근접 전환(true). 근접 유닛은 항상 false.
static func archer_should_charge(unit_range: int, dist: float, threshold: float) -> bool:
	return unit_range >= 2 and dist <= threshold
