class_name SiegeUnit extends RefCounted
## 부대에 실리는 공성 유닛 인스턴스(투석기 등). 종류 id 하나를 들고 스펙은 카탈로그(SiegeTypes)에서 읽는다.
## 일반 병사(Human)와 달리 인구를 차지하지 않는 재사용 장비 유닛. → docs/spec/features/siege-engines.md

var type_id := SiegeTypes.CATAPULT   # 종류 id(기본 투석기).
var hit_points := 0   # 현재 내구도. 생성 시 max_hp()로 채운다. 깎는 공격원은 후속(방어 요격 5d).

func _init(p_type_id := SiegeTypes.CATAPULT) -> void:
	type_id = p_type_id
	hit_points = max_hp()   # 생성 시 풀 내구도

## 종류 이름(예: "투석기").
func unit_name() -> String:
	return SiegeTypes.type_name(type_id)

## 견인 이동력(부대 이동력 상한, 투석기 2).
func movement() -> int:
	return SiegeTypes.movement(type_id)

## 투석 사거리(헥스, 투석기 5).
func fire_range() -> int:
	return SiegeTypes.fire_range(type_id)

## 공격력(투석 데미지 기준값, 투석기 50).
func attack() -> int:
	return SiegeTypes.attack(type_id)

## 최대 내구도(투석기 60).
func max_hp() -> int:
	return SiegeTypes.max_hp(type_id)
