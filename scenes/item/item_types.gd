class_name ItemTypes
## 무기·방어구 카탈로그 + 상성표. BuildingTypes·Terrain·UnitTypes와 같은 GDScript 카탈로그 패턴.
## 기획 원본(docs/table/아이템/무기.md·방어구.md)에서 전투에 쓰는 필드만 옮긴 부분집합이다.
## 무게·공격거리·근접거리·생산비용·가치·부위 등은 미수록(관련 기능 도입 시 추가).

# 무기: id → {name, attack, damage_type(참격|자돌|타격|원거리|마법)}.
const WEAPONS := {
	"sword": {"name": "검", "attack": 14, "damage_type": "참격"},
	"longsword": {"name": "장검", "attack": 18, "damage_type": "참격"},
	"scimitar": {"name": "곡도", "attack": 15, "damage_type": "참격"},
	"battleaxe": {"name": "전투도끼", "attack": 16, "damage_type": "참격"},
	"spear": {"name": "장창", "attack": 15, "damage_type": "자돌"},
	"mace": {"name": "모닝스타", "attack": 19, "damage_type": "타격"},
	"bow": {"name": "단궁", "attack": 12, "damage_type": "원거리"},
	"wand": {"name": "완드", "attack": 8, "damage_type": "마법"},
}

# 방어구: id → {name, defense, armor_class(천|가죽|사슬|판금)}.
const ARMORS := {
	"cloth_hood": {"name": "두건", "defense": 2, "armor_class": "천"},
	"robe": {"name": "로브", "defense": 4, "armor_class": "천"},
	"leather_helm": {"name": "가죽 투구", "defense": 4, "armor_class": "가죽"},
	"leather_armor": {"name": "가죽 갑옷", "defense": 8, "armor_class": "가죽"},
	"leather_gloves": {"name": "가죽 장갑", "defense": 2, "armor_class": "가죽"},
	"leather_greaves": {"name": "가죽 각반", "defense": 3, "armor_class": "가죽"},
	"chain_coif": {"name": "사슬 코이프", "defense": 6, "armor_class": "사슬"},
	"chain_mail": {"name": "사슬 갑옷", "defense": 14, "armor_class": "사슬"},
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

## 방어구 방어력(없는 id면 0).
static func armor_defense(id: String) -> int:
	return ARMORS.get(id, {}).get("defense", 0)

## 방어구 분류(없는 id면 "").
static func armor_class(id: String) -> String:
	return ARMORS.get(id, {}).get("armor_class", "")

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
