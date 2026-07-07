class_name Faction extends RefCounted
## 영지를 보유하는 세력(예: "프랑스"). 하나의 세력은 여러 영지를 거느린다.
## 구조: 세력(Faction) → 영지(Territory) → 건물(Building).
## 시각 요소가 없는 순수 데이터 엔티티라 씬 없이 스크립트만 둔다.

var name: String
var color: Color
var territories: Array = []

func _init(p_name := "", p_color := Color.WHITE) -> void:
	name = p_name
	color = p_color

## 영지를 이 세력에 편입한다. territories에 추가하고 territory.faction을 자신으로 설정(양방향).
func add_territory(territory: Territory) -> void:
	if territory in territories:
		return
	territories.append(territory)
	territory.faction = self
