class_name UnitTypes
## 유닛·부대 카탈로그. 랑그릿사식 이분화 — 세력별 영웅 4명(영웅부대·1인)과
## 병종 아키타입(경보병·경궁병, 일반부대 10인)을 데이터로 정의한다.
## BuildingTypes·Terrain과 동일한 "GDScript 카탈로그" 패턴. game.gd가 여기서 부대를 생성해 배치한다.
## 능력치는 기획 원본 docs/table/세력/유닛.md에서 옮긴 값이다. (장비/전리품 계층은 M4-B에서 삭제 — 전투는 lang 클래스.)

# 플레이어 세력 id.
const PLAYER_ID := "azel"
# NPC 세력 id 목록(표시 순서).
const NPC_IDS := ["qasim", "balthazar", "batur"]
# 전 세력 id(플레이어 + NPC).
const FACTION_IDS := ["azel", "qasim", "balthazar", "batur"]

# 일반부대 1개의 병사 수.
const TROOP_SIZE := 10
# 세력당 영웅 수.
const HEROES_PER_FACTION := 4

# 영웅 전투 배율(회피형 반신). 생성 시 능력치에만 적용 — 비전투 스탯(지휘력 등)은 불변. → units.md
# 세부 수치는 추후 튜닝. 힘 = HP↑(max_hp). (구 전투 수학의 민첩=회피·행운=치명 효과는 폐기, 배율은 잔존값 — M4-C에서 정리.)
const HERO_STR_MULT := 3.0
const HERO_LUCK_MULT := 3.0
const HERO_AGI_MULT := 1.6

# 이동력·시야는 유닛.md에 개별값이 없어 종족(인간) 기본값을 모든 유닛에 적용한다.
const HUMAN_MOVEMENT := 4
const HUMAN_VISION := 7

# 멤버 dict → Human 필드로 복사할 능력치 키(= Human 변수명).
const _STAT_KEYS := [
	"strength", "wisdom", "agility", "charm", "luck",
	"leadership", "diligence", "sensitivity",
	"stamina", "morale",
]

# 세력 id → 스펙. heroes 첫 항목이 세력 지휘관.
# 능력치 키 매핑: strength=힘, wisdom=지혜, agility=민첩, charm=매력, luck=행운,
#               leadership=지휘력, diligence=성실함, sensitivity=예민함,
#               stamina=스태미나, morale=사기. (생명점은 max_hp()로 계산해 채움)
const CATALOG := {
	"azel": {
		"faction": "푸른 왕국",
		"color": Color(0.2, 0.3, 0.8),
		"territory": "창천성",
		"heroes": [
			{"name": "아젤 하르윈", "strength": 78, "wisdom": 72, "agility": 65, "charm": 80, "luck": 55, "leadership": 88, "diligence": 82, "sensitivity": 45, "stamina": 40, "morale": 90},
			{"name": "로엔 카스터", "strength": 70, "wisdom": 55, "agility": 68, "charm": 50, "luck": 48, "leadership": 42, "diligence": 65, "sensitivity": 50, "stamina": 40, "morale": 75},
			{"name": "미라 벨포드", "strength": 58, "wisdom": 62, "agility": 74, "charm": 66, "luck": 60, "leadership": 35, "diligence": 70, "sensitivity": 58, "stamina": 40, "morale": 72},
			{"name": "가레스 던", "strength": 82, "wisdom": 44, "agility": 60, "charm": 40, "luck": 52, "leadership": 30, "diligence": 60, "sensitivity": 38, "stamina": 40, "morale": 68},
		],
	},
	"qasim": {
		"faction": "사막 술탄국",
		"color": Color(0.78, 0.28, 0.22),
		"territory": "알사바흐",
		"heroes": [
			{"name": "카심 이븐 라시드", "strength": 75, "wisdom": 80, "agility": 62, "charm": 78, "luck": 58, "leadership": 85, "diligence": 78, "sensitivity": 52, "stamina": 40, "morale": 88},
			{"name": "자밀라", "strength": 55, "wisdom": 66, "agility": 72, "charm": 70, "luck": 64, "leadership": 38, "diligence": 68, "sensitivity": 60, "stamina": 40, "morale": 74},
			{"name": "하산 알와히드", "strength": 76, "wisdom": 52, "agility": 64, "charm": 48, "luck": 50, "leadership": 33, "diligence": 62, "sensitivity": 42, "stamina": 40, "morale": 70},
			{"name": "유수프", "strength": 80, "wisdom": 46, "agility": 58, "charm": 44, "luck": 54, "leadership": 28, "diligence": 58, "sensitivity": 40, "stamina": 40, "morale": 66},
		],
	},
	"balthazar": {
		"faction": "암흑 제국",
		"color": Color(0.5, 0.24, 0.6),
		"territory": "흑요요새",
		"heroes": [
			{"name": "발타자르", "strength": 72, "wisdom": 84, "agility": 60, "charm": 66, "luck": 50, "leadership": 82, "diligence": 60, "sensitivity": 70, "stamina": 40, "morale": 80},
			{"name": "모르가나", "strength": 48, "wisdom": 78, "agility": 64, "charm": 74, "luck": 58, "leadership": 36, "diligence": 58, "sensitivity": 82, "stamina": 40, "morale": 68},
			{"name": "드레이븐", "strength": 78, "wisdom": 50, "agility": 66, "charm": 44, "luck": 52, "leadership": 34, "diligence": 55, "sensitivity": 60, "stamina": 40, "morale": 66},
			{"name": "카산드라", "strength": 60, "wisdom": 58, "agility": 70, "charm": 62, "luck": 54, "leadership": 30, "diligence": 62, "sensitivity": 68, "stamina": 40, "morale": 64},
		],
	},
	"batur": {
		"faction": "초원 칸국",
		"color": Color(0.27, 0.55, 0.32),
		"territory": "텡그리 언덕",
		"heroes": [
			{"name": "바트르 칸", "strength": 84, "wisdom": 68, "agility": 72, "charm": 64, "luck": 60, "leadership": 86, "diligence": 70, "sensitivity": 48, "stamina": 40, "morale": 85},
			{"name": "테무르", "strength": 80, "wisdom": 50, "agility": 74, "charm": 48, "luck": 54, "leadership": 35, "diligence": 64, "sensitivity": 44, "stamina": 40, "morale": 72},
			{"name": "알탄", "strength": 76, "wisdom": 52, "agility": 70, "charm": 46, "luck": 56, "leadership": 32, "diligence": 62, "sensitivity": 42, "stamina": 40, "morale": 70},
			{"name": "초로스", "strength": 78, "wisdom": 48, "agility": 72, "charm": 44, "luck": 58, "leadership": 30, "diligence": 60, "sensitivity": 40, "stamina": 40, "morale": 68},
		],
	},
}

# 병종 아키타입(세력 공용). 한 부대는 이 스펙으로 TROOP_SIZE명 동일 생성된다. → units.md 병종 아키타입
# 경보병·경궁병은 lang 클래스(GameUnits 아키타입)로 전투·사거리가 결정된다. 영웅보다 약한 보통 병사.
const TROOPS := {
	"light_infantry": {
		"name": "경보병",
		"stats": {"strength": 46, "wisdom": 40, "agility": 55, "charm": 40, "luck": 48, "leadership": 20, "diligence": 55, "sensitivity": 40, "stamina": 40, "morale": 58},
	},
	"light_archer": {
		"name": "경궁병",
		"stats": {"strength": 46, "wisdom": 40, "agility": 62, "charm": 40, "luck": 52, "leadership": 20, "diligence": 55, "sensitivity": 45, "stamina": 40, "morale": 55},
	},
}

## 세력 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_faction(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## 세력의 index번째 영웅을 Human으로 생성한다(능력치 반영). 범위 밖이면 null.
static func make_hero(faction: String, index: int):
	var spec := get_faction(faction)
	var heroes: Array = spec.get("heroes", [])
	if index < 0 or index >= heroes.size():
		return null
	return _apply_hero_boost(_build_human(heroes[index]))

## 세력 영웅 4명 전부를 Human 배열로 생성한다. 없는 세력이면 빈 배열.
static func make_heroes(faction: String) -> Array:
	var spec := get_faction(faction)
	var result: Array = []
	for h in spec.get("heroes", []):
		result.append(_apply_hero_boost(_build_human(h)))
	return result

## 영웅 스탯 배율 적용 — 힘·행운 ×3, 민첩 ×1.6(내림). 비전투 스탯 불변.
## 배율 후 힘이 바뀌므로 max_hp() 재계산해 풀피로 채운다. 병종(make_troop)에는 적용 안 함. → units.md
static func _apply_hero_boost(h: Human) -> Human:
	h.strength = int(h.strength * HERO_STR_MULT)
	h.luck = int(h.luck * HERO_LUCK_MULT)
	h.agility = int(h.agility * HERO_AGI_MULT)
	h.hit_points = h.max_hp()   # 강화된 힘 기준 최대 생명점으로 풀피
	return h

## "{영웅 이름} 부대". 범위 밖이면 빈 문자열.
static func hero_party_name(faction: String, index: int) -> String:
	var heroes: Array = get_faction(faction).get("heroes", [])
	if index < 0 or index >= heroes.size():
		return ""
	return "%s 부대" % heroes[index]["name"]

## 병종 아키타입으로 TROOP_SIZE명 동일 병사를 Human 배열로 생성한다. 없는 병종이면 빈 배열.
static func make_troop(archetype: String) -> Array:
	var spec: Dictionary = TROOPS.get(archetype, {})
	if spec.is_empty():
		return []
	var result: Array = []
	for i in TROOP_SIZE:
		var m := {"name": spec["name"]}
		for key in _STAT_KEYS:
			m[key] = spec["stats"][key]
		result.append(_build_human(m))
	return result

## 병종 표시 이름(경보병/경궁병). 없으면 빈 문자열.
static func troop_name(archetype: String) -> String:
	return TROOPS.get(archetype, {}).get("name", "")

## 멤버 dict로 Human 하나를 만든다. 능력치·이동력·시야를 반영하고 풀피·풀 스태미나로 채운다.
static func _build_human(m: Dictionary) -> Human:
	var h := Human.new(m["name"])
	for key in _STAT_KEYS:
		h.set(key, m[key])
	h.movement = HUMAN_MOVEMENT
	h.vision = HUMAN_VISION
	h.hit_points = h.max_hp()   # 생성 시 시작 풀피(힘·레벨로 계산한 최대)
	h.max_stamina = h.stamina   # 시작 풀 스태미나(현재=최대)
	return h
