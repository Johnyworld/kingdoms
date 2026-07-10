class_name Faction extends RefCounted
## 영지를 보유하는 세력(예: "푸른 왕국"). 하나의 세력은 여러 영지를 거느린다.
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

## 영지를 이 세력에서 뗀다. territories에서 제거하고, 그 영지의 소속이 이 세력이면 null로 되돌린다(양방향 해제).
## 보유하지 않은 영지면 no-op. 캠프 점령(흡수) 시 이전 세력에서 영지를 떼어낼 때 쓴다.
func remove_territory(territory: Territory) -> void:
	territories.erase(territory)
	if territory.faction == self:
		territory.faction = null
