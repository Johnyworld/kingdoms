class_name Faction extends RefCounted
## 건물이 소속되는 세력(예: "프랑스"). 하나의 세력은 여러 건물을 거느린다.
## 시각 요소가 없는 순수 데이터 엔티티라 씬 없이 스크립트만 둔다.

var name: String
var color: Color
var buildings: Array = []

func _init(p_name := "", p_color := Color.WHITE) -> void:
	name = p_name
	color = p_color

## 건물을 이 세력에 편입한다. buildings에 추가하고 building.faction을 자신으로 설정(양방향).
## building은 Building 노드지만, Faction↔Building 순환 타입 참조를 피하려 untyped로 둔다.
func add_building(building) -> void:
	if building in buildings:
		return
	buildings.append(building)
	building.faction = self
