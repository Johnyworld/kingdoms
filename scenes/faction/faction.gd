class_name Faction extends RefCounted
## 캠프가 소속되는 세력(예: "프랑스"). 하나의 세력은 여러 캠프를 거느린다.
## 시각 요소가 없는 순수 데이터 엔티티라 씬 없이 스크립트만 둔다.

var name: String
var color: Color
var camps: Array = []

func _init(p_name := "", p_color := Color.WHITE) -> void:
	name = p_name
	color = p_color

## 캠프를 이 세력에 편입한다. camps에 추가하고 camp.faction을 자신으로 설정(양방향).
## camp은 Camp 노드지만, Faction↔Camp 순환 타입 참조를 피하려 untyped로 둔다.
func add_camp(camp) -> void:
	if camp in camps:
		return
	camps.append(camp)
	camp.faction = self
