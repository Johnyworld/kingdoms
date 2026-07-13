class_name SiegeUnit extends RefCounted
## 부대에 실리는 공성 유닛 인스턴스(투석기 등). 종류 id 하나를 들고 스펙은 카탈로그(SiegeTypes)에서 읽는다.
## 일반 병사(Human)와 달리 인구를 차지하지 않는 재사용 장비 유닛. → docs/spec/features/siege-engines.md

var type_id := SiegeTypes.CATAPULT   # 종류 id(기본 투석기).

func _init(p_type_id := SiegeTypes.CATAPULT) -> void:
	type_id = p_type_id

## 종류 이름(예: "투석기").
func unit_name() -> String:
	return SiegeTypes.type_name(type_id)

## 견인 이동력(부대 이동력 상한, 투석기 2).
func movement() -> int:
	return SiegeTypes.movement(type_id)
