class_name SiegeTypes
## 공성 유닛 카탈로그 — 투석기 등 부대에 실리는 재사용 공성 유닛의 스펙을 데이터로 정의한다.
## BuildingTypes·UnitTypes·ItemTypes와 같은 "GDScript 카탈로그" 패턴. → docs/spec/data/siege-units.md
## 이번 슬라이스(5a-1)는 유닛 모델·획득·이동에 쓰는 필드만 수록(투석 사거리·데미지는 후속).

const CATAPULT := "catapult"
const CREW_MIN := 4   # 공성 유닛을 실은 부대가 이동하려면 필요한 최소 사람(멤버) 수. 미만이면 이동력 0(견인 불가).

# 종류 id → 스펙. name=이름, movement=견인 이동력(부대 이동력 상한), fire_range=투석 사거리,
# attack=공격력(무기보다 큰 공성 화력, 투석 데미지 기준값), hit_points=내구도, produce_*=생산 비용(인구 비소모).
const CATALOG := {
	"catapult": {
		"name": "투석기",
		"movement": 2,
		"fire_range": 5,
		"attack": 50,
		"hit_points": 60,
		"produce_gold": 40,
		"produce_cost": {"목재": 30, "석재": 20},
	},
}

## 종류 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_type(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## 종류 이름(없는 id면 "").
static func type_name(id: String) -> String:
	return CATALOG.get(id, {}).get("name", "")

## 견인 이동력(없는 id면 0).
static func movement(id: String) -> int:
	return CATALOG.get(id, {}).get("movement", 0)

## 투석 사거리(헥스, 없는 id면 0).
static func fire_range(id: String) -> int:
	return CATALOG.get(id, {}).get("fire_range", 0)

## 공격력(투석 데미지 기준값, 없는 id면 0).
static func attack(id: String) -> int:
	return CATALOG.get(id, {}).get("attack", 0)

## 최대 내구도(카탈로그 hit_points, 없는 id면 0).
static func max_hp(id: String) -> int:
	return CATALOG.get(id, {}).get("hit_points", 0)

## 생산 금 비용(없는 id면 0).
static func produce_gold(id: String) -> int:
	return CATALOG.get(id, {}).get("produce_gold", 0)

## 생산 자재 비용(자원명→수량, 없는 id면 빈 Dictionary).
static func produce_cost(id: String) -> Dictionary:
	return CATALOG.get(id, {}).get("produce_cost", {})

## 생산 총비용(금 + 자재)을 한 Dictionary로. 금을 앞에 둔다(표시 순서). 없는 id면 빈 Dictionary.
## 캠프 [투석기 생산] 버튼 표시·활성 판정과 game.gd 지불이 공유하는 단일 출처. → siege-engines.md
static func produce_full_cost(id: String) -> Dictionary:
	if not CATALOG.has(id):
		return {}
	var cost := {"금": produce_gold(id)}
	for res_name in produce_cost(id):
		cost[res_name] = produce_cost(id)[res_name]
	return cost
