class_name Territory extends RefCounted
## 세력이 보유하는 영지(예: "창천성"). 중심 캠프 + 그 안의 건물들을 가지며 모든 자원(인구 포함)을 보유한다.
## 구조: 세력(Faction) → 영지(Territory) → 건물(Building).
## 시각 요소가 없는 순수 데이터 엔티티라 씬 없이 스크립트만 둔다.

var name: String
var resources: Dictionary   # 모든 자원(인구·밀·빵·나무·목재·철·철괴). 삽입 순서 = 메뉴 표시 순서.
var faction: Faction = null
var buildings: Array = []

func _init(p_name := "", p_resources := {}) -> void:
	name = p_name
	resources = p_resources

## 건물을 이 영지에 편입한다. buildings에 추가하고 building.territory를 자신으로 설정(양방향).
## building은 Building 노드지만, Territory↔Building 순환 타입 참조를 피하려 untyped로 둔다.
func add_building(building) -> void:
	if building in buildings:
		return
	buildings.append(building)
	building.territory = self

## 건물을 이 영지에서 뗀다. buildings에서 제거하고, 그 건물의 소속이 이 영지면 null로 되돌린다(양방향 해제).
## 보유하지 않은 건물이면 no-op. 캠프 점령(파괴) 시 영지에서 캠프를 떼어낼 때 쓴다.
func remove_building(building) -> void:
	buildings.erase(building)
	if building.territory == self:
		building.territory = null

## 턴 종료 시 호출. 소속 건물들의 생산량(production)을 자원에 합산한다.
## 영지에 없던 자원 키는 새로 만들어 더한다. 생산이 없는 건물(캠프 등)·건설 중 건물(생산 0)은 자원을 바꾸지 않는다.
func collect_income() -> void:
	for building in buildings:
		var prod: Dictionary = building.production()
		for res_name in prod:
			resources[res_name] = resources.get(res_name, 0) + prod[res_name]

## 이 비용을 지불할 자원이 충분한지. cost의 모든 자원에 대해 보유량 >= 요구량이면 참. 빈 비용은 참.
func can_afford(cost: Dictionary) -> bool:
	for res_name in cost:
		if resources.get(res_name, 0) < cost[res_name]:
			return false
	return true

## 비용만큼 자원을 차감한다. 음수 방지는 하지 않으므로 호출 전 can_afford로 확인한다.
func spend(cost: Dictionary) -> void:
	for res_name in cost:
		resources[res_name] = resources.get(res_name, 0) - cost[res_name]

## 턴 종료 시 호출. 소속 건물들의 건설을 1턴씩 진행한다(건설 중 건물만 영향).
func advance_construction() -> void:
	for building in buildings:
		building.advance_construction()

## 영지 인구 상한 = 소속 완성 건물들의 pop_cap 합(캠프 10, 집 +2). 건설 중 건물은 0으로 기여 안 함.
func population_cap() -> int:
	var cap := 0
	for building in buildings:
		cap += building.pop_cap()
	return cap

## 턴 종료 시 호출. 현재 인구가 상한 미만이면 +1(상한에서 멈춤). 상한 이상이면 그대로 둔다(초과분 감소 없음).
func grow_population() -> void:
	var cur: int = resources.get("인구", 0)
	if cur < population_cap():
		resources["인구"] = cur + 1
