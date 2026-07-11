class_name ItemTypes
## 무기·방어구 카탈로그 + 상성표. BuildingTypes·Terrain·UnitTypes와 같은 GDScript 카탈로그 패턴.
## 기획 원본(docs/table/아이템/무기.md·방어구.md)에서 전투에 쓰는 필드만 옮긴 부분집합이다.
## 무게·공격거리·근접거리·생산비용·가치·부위 등은 미수록(관련 기능 도입 시 추가).

# 무기: id → {name, attack, damage_type(참격|자돌|타격|원거리|마법), weight, range, reach, attack_speed, throw_range?}.
# reach(근접거리)=전투씬 근접 공격 개시 거리(원본 무기.md), 클수록 리치 김=선제. attack_speed=1회 공격 초(민첩 0 기준).
const WEAPONS := {
	"sword": {"name": "검", "attack": 14, "damage_type": "참격", "weight": 3, "range": 0, "reach": 1.2, "attack_speed": 2.0},
	"longsword": {"name": "장검", "attack": 18, "damage_type": "참격", "weight": 4, "range": 0, "reach": 1.4, "attack_speed": 2.2},
	"scimitar": {"name": "곡도", "attack": 15, "damage_type": "참격", "weight": 3, "range": 0, "reach": 1.1, "attack_speed": 1.8},
	"battleaxe": {"name": "전투도끼", "attack": 16, "damage_type": "참격", "weight": 4, "range": 0, "reach": 1.1, "attack_speed": 2.6},
	"spear": {"name": "장창", "attack": 15, "damage_type": "자돌", "weight": 3, "range": 0, "reach": 2.0, "attack_speed": 2.4},
	"mace": {"name": "모닝스타", "attack": 19, "damage_type": "타격", "weight": 5, "range": 0, "reach": 1.1, "attack_speed": 2.8},
	"javelin": {"name": "투창", "attack": 10, "damage_type": "원거리", "weight": 2, "range": 0, "reach": 1.3, "attack_speed": 2.0, "throw_range": 2},
	"bow": {"name": "단궁", "attack": 12, "damage_type": "원거리", "weight": 2, "range": 3, "reach": 0.7, "attack_speed": 3.3},
	"wand": {"name": "완드", "attack": 8, "damage_type": "마법", "weight": 1, "range": 2, "reach": 0.5, "attack_speed": 2.6},
}

# 방어구: id → {name, defense, armor_class(천|가죽|사슬|판금)}.
const ARMORS := {
	"cloth_hood": {"name": "두건", "defense": 2, "armor_class": "천", "weight": 1},
	"robe": {"name": "로브", "defense": 4, "armor_class": "천", "weight": 2},
	"leather_helm": {"name": "가죽 투구", "defense": 4, "armor_class": "가죽", "weight": 2},
	"leather_armor": {"name": "가죽 갑옷", "defense": 8, "armor_class": "가죽", "weight": 4},
	"leather_gloves": {"name": "가죽 장갑", "defense": 2, "armor_class": "가죽", "weight": 1},
	"leather_greaves": {"name": "가죽 각반", "defense": 3, "armor_class": "가죽", "weight": 2},
	"chain_coif": {"name": "사슬 코이프", "defense": 6, "armor_class": "사슬", "weight": 3},
	"chain_mail": {"name": "사슬 갑옷", "defense": 14, "armor_class": "사슬", "weight": 8},
}

# 방패: id → {name, defense(DF에 합산), block(막기 확률 %)}.
const SHIELDS := {
	"buckler": {"name": "버클러", "defense": 2, "block": 15, "weight": 1},
	"round_shield": {"name": "라운드 실드", "defense": 5, "block": 25, "weight": 3},
	"kite_shield": {"name": "카이트 실드", "defense": 8, "block": 30, "weight": 5},
	"tower_shield": {"name": "타워 실드", "defense": 12, "block": 40, "weight": 8},
}

# 상성표: 방어구 분류 → { 데미지 타입 → 배율 }. 기획 원본과 동일.
const AFFINITY := {
	"천": {"참격": 1.2, "자돌": 1.2, "타격": 1.0, "원거리": 1.2, "마법": 0.6},
	"가죽": {"참격": 0.9, "자돌": 1.0, "타격": 1.1, "원거리": 0.9, "마법": 1.0},
	"사슬": {"참격": 0.7, "자돌": 0.8, "타격": 1.1, "원거리": 0.8, "마법": 1.1},
	"판금": {"참격": 0.5, "자돌": 0.6, "타격": 0.9, "원거리": 0.6, "마법": 1.3},
}

## 무기 공격력(없는 id면 0).
static func weapon_attack(id: String) -> int:
	return WEAPONS.get(id, {}).get("attack", 0)

## 무기 데미지 타입(없는 id면 "").
static func weapon_damage_type(id: String) -> String:
	return WEAPONS.get(id, {}).get("damage_type", "")

## 무기 이름(없는 id면 "").
static func weapon_name(id: String) -> String:
	return WEAPONS.get(id, {}).get("name", "")

## 무기 무게(없는 id면 0).
static func weapon_weight(id: String) -> int:
	return WEAPONS.get(id, {}).get("weight", 0)

## 무기 월드맵 공격거리(헥스 거리). 근접 0, 활 3, 완드 2. 없는(빈) id는 0(맨손 근접).
static func weapon_range(id: String) -> int:
	return WEAPONS.get(id, {}).get("range", 0)

## 사거리 표기. 0 → "근접", 그 외 "사거리 N". 부대 정보·행동 판단에 쓴다.
static func range_label(r: int) -> String:
	return "근접" if r <= 0 else "사거리 %d" % r

## 투척 사거리(던지는 무기). 없거나 투척 불가면 0.
static func weapon_throw_range(id: String) -> int:
	return WEAPONS.get(id, {}).get("throw_range", 0)

## 근접거리(리치). 전투씬 근접 공격 개시 거리 — 클수록 먼저 사거리에 들어와 선제. 맨손/없으면 1.0.
static func weapon_reach(id: String) -> float:
	return WEAPONS.get(id, {}).get("reach", 1.0)

## 기본 공격속도(1회 공격 초, 민첩 0 기준). 맨손/없으면 2.0.
static func weapon_attack_speed(id: String) -> float:
	return WEAPONS.get(id, {}).get("attack_speed", 2.0)

## --- 다중 무기(유닛은 무기 2~3개 소지, 첫 원소=주무기) ---

## 주무기(목록 첫 원소). 비면 ""(맨손).
static func primary_weapon(weapons: Array) -> String:
	return weapons[0] if not weapons.is_empty() else ""

## 목록 중 공격거리 ≥ 2인 첫 무기(활·완드 등). 없으면 "".
static func ranged_weapon(weapons: Array) -> String:
	for w in weapons:
		if weapon_range(w) >= 2:
			return w
	return ""

## 목록 중 throw_range > 0인 첫 무기(투창 등). 없으면 "".
static func throwing_weapon(weapons: Array) -> String:
	for w in weapons:
		if weapon_throw_range(w) > 0:
			return w
	return ""

## 목록 중 공격거리 < 2인 첫 무기(근접). 없으면 ""(순수 원거리).
static func melee_weapon(weapons: Array) -> String:
	for w in weapons:
		if weapon_range(w) < 2:
			return w
	return ""

## 목록 무기 공격거리의 최대값(부대 월드맵 사거리). 비면 0(맨손 근접). 근접만이면 0, 활 소지면 3.
static func max_range(weapons: Array) -> int:
	var r := 0
	for w in weapons:
		r = maxi(r, weapon_range(w))
	return r

## 전투에서 실제 쓸 무기. ranged_mode면 원거리 무기(없으면 "" → 공격 불가), 아니면 주무기.
static func active_weapon(weapons: Array, ranged_mode: bool) -> String:
	return ranged_weapon(weapons) if ranged_mode else primary_weapon(weapons)

## 방어구 방어력(없는 id면 0).
static func armor_defense(id: String) -> int:
	return ARMORS.get(id, {}).get("defense", 0)

## 방어구 분류(없는 id면 "").
static func armor_class(id: String) -> String:
	return ARMORS.get(id, {}).get("armor_class", "")

## 방어구 이름(없는 id면 "").
static func armor_name(id: String) -> String:
	return ARMORS.get(id, {}).get("name", "")

## 방어구 무게(없는 id면 0).
static func armor_weight(id: String) -> int:
	return ARMORS.get(id, {}).get("weight", 0)

## 방패 방어력(없는 id면 0).
static func shield_defense(id: String) -> int:
	return SHIELDS.get(id, {}).get("defense", 0)

## 방패 막기 확률 %(없는 id면 0).
static func shield_block(id: String) -> int:
	return SHIELDS.get(id, {}).get("block", 0)

## 방패 이름(없는 id면 "").
static func shield_name(id: String) -> String:
	return SHIELDS.get(id, {}).get("name", "")

## 무기·방어구·방패를 통합 조회한 이름(무기→방어구→방패 순). 세 곳 어디에도 없으면 "".
## 노획 장비([Raid](raid.md)) 목록 표시 등, id가 어느 분류인지 모를 때 쓴다.
static func item_name(id: String) -> String:
	if WEAPONS.has(id):
		return WEAPONS[id]["name"]
	if ARMORS.has(id):
		return ARMORS[id]["name"]
	if SHIELDS.has(id):
		return SHIELDS[id]["name"]
	return ""

## 그 아이템이 들어가는 장비 슬롯 분류: 무기="weapon", 방어구="armor", 방패="shield", 없으면 "".
## 장비 관리([Equipment](equipment.md))에서 노획 장비를 알맞은 슬롯에 장착할 때 쓴다.
static func item_slot(id: String) -> String:
	if WEAPONS.has(id):
		return "weapon"
	if ARMORS.has(id):
		return "armor"
	if SHIELDS.has(id):
		return "shield"
	return ""

## 방패 무게(없는 id면 0).
static func shield_weight(id: String) -> int:
	return SHIELDS.get(id, {}).get("weight", 0)

## 방어구 id 목록의 방어력 합.
static func total_defense(ids: Array) -> int:
	var sum := 0
	for id in ids:
		sum += armor_defense(id)
	return sum

## 방어력이 가장 큰 조각의 분류(상성 판정 대표 분류). 비면 "".
static func armor_class_of(ids: Array) -> String:
	var best := ""
	var best_def := -1
	for id in ids:
		var d := armor_defense(id)
		if d > best_def:
			best_def = d
			best = armor_class(id)
	return best

## 상성 배율. 분류/타입이 표에 없으면 1.0.
static func affinity(a_class: String, damage_type: String) -> float:
	return AFFINITY.get(a_class, {}).get(damage_type, 1.0)
