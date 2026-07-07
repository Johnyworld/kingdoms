class_name Territory extends RefCounted
## 세력이 보유하는 영지(예: "파리"). 중심 캠프 + 그 안의 건물들을 가지며 모든 자원(인구 포함)을 보유한다.
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

## 턴 종료 시 호출. 소속 건물들의 생산량(production)을 자원에 합산한다.
## 영지에 없던 자원 키는 새로 만들어 더한다. 생산이 없는 건물(캠프 등)은 자원을 바꾸지 않는다.
func collect_income() -> void:
	for building in buildings:
		var prod: Dictionary = building.production()
		for res_name in prod:
			resources[res_name] = resources.get(res_name, 0) + prod[res_name]
