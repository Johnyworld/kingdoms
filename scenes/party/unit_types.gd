class_name UnitTypes
## 유닛·부대 카탈로그. 세력별 부대(이름·색·지휘관·멤버)를 데이터로 정의한다.
## BuildingTypes·Terrain과 동일한 "GDScript 카탈로그" 패턴.
## game.gd가 여기서 부대를 생성해 맵에 배치한다.
## 멤버 능력치는 기획 원본 docs/table/세력/유닛.md에서 옮긴 값이다.

# 플레이어 부대 id.
const PLAYER_ID := "azel"
# NPC 부대 id 목록(표시 순서).
const NPC_IDS := ["qasim", "balthazar", "batur"]

# 이동력·시야는 유닛.md에 개별값이 없어 종족(인간) 기본값을 모든 멤버에 적용한다.
const HUMAN_MOVEMENT := 4
const HUMAN_VISION := 7

# 멤버 dict → Human 필드로 복사할 능력치 키(= Human 변수명).
const _STAT_KEYS := [
	"strength", "wisdom", "agility", "charm", "luck",
	"leadership", "diligence", "sensitivity",
	"hit_points", "stamina", "morale",
]

# 부대 id → 스펙. 멤버 첫 항목이 지휘관.
# 능력치 키 매핑: strength=힘, wisdom=지혜, agility=민첩, charm=매력, luck=행운,
#               leadership=지휘력, diligence=성실함, sensitivity=예민함,
#               hit_points=생명점, stamina=스태미나, morale=사기.
const CATALOG := {
	"azel": {
		"party_name": "아젤 하르윈 부대",
		"faction": "푸른 왕국",
		"color": Color(0.2, 0.3, 0.8),
		"territory": "창천성",
		"commander": "아젤 하르윈",
		"members": [
			{"name": "아젤 하르윈", "strength": 78, "wisdom": 72, "agility": 65, "charm": 80, "luck": 55, "leadership": 88, "diligence": 82, "sensitivity": 45, "hit_points": 40, "stamina": 40, "morale": 90},
			{"name": "로엔 카스터", "strength": 70, "wisdom": 55, "agility": 68, "charm": 50, "luck": 48, "leadership": 42, "diligence": 65, "sensitivity": 50, "hit_points": 40, "stamina": 40, "morale": 75},
			{"name": "미라 벨포드", "strength": 58, "wisdom": 62, "agility": 74, "charm": 66, "luck": 60, "leadership": 35, "diligence": 70, "sensitivity": 58, "hit_points": 40, "stamina": 40, "morale": 72},
			{"name": "가레스 던", "strength": 82, "wisdom": 44, "agility": 60, "charm": 40, "luck": 52, "leadership": 30, "diligence": 60, "sensitivity": 38, "hit_points": 40, "stamina": 40, "morale": 68},
		],
	},
	"qasim": {
		"party_name": "카심 이븐 라시드 부대",
		"faction": "사막 술탄국",
		"color": Color(0.78, 0.28, 0.22),
		"territory": "",
		"commander": "카심 이븐 라시드",
		"members": [
			{"name": "카심 이븐 라시드", "strength": 75, "wisdom": 80, "agility": 62, "charm": 78, "luck": 58, "leadership": 85, "diligence": 78, "sensitivity": 52, "hit_points": 40, "stamina": 40, "morale": 88},
			{"name": "자밀라", "strength": 55, "wisdom": 66, "agility": 72, "charm": 70, "luck": 64, "leadership": 38, "diligence": 68, "sensitivity": 60, "hit_points": 40, "stamina": 40, "morale": 74},
			{"name": "하산 알와히드", "strength": 76, "wisdom": 52, "agility": 64, "charm": 48, "luck": 50, "leadership": 33, "diligence": 62, "sensitivity": 42, "hit_points": 40, "stamina": 40, "morale": 70},
			{"name": "유수프", "strength": 80, "wisdom": 46, "agility": 58, "charm": 44, "luck": 54, "leadership": 28, "diligence": 58, "sensitivity": 40, "hit_points": 40, "stamina": 40, "morale": 66},
		],
	},
	"balthazar": {
		"party_name": "발타자르 부대",
		"faction": "암흑 제국",
		"color": Color(0.5, 0.24, 0.6),
		"territory": "",
		"commander": "발타자르",
		"members": [
			{"name": "발타자르", "strength": 72, "wisdom": 84, "agility": 60, "charm": 66, "luck": 50, "leadership": 82, "diligence": 60, "sensitivity": 70, "hit_points": 40, "stamina": 40, "morale": 80},
			{"name": "모르가나", "strength": 48, "wisdom": 78, "agility": 64, "charm": 74, "luck": 58, "leadership": 36, "diligence": 58, "sensitivity": 82, "hit_points": 40, "stamina": 40, "morale": 68},
			{"name": "드레이븐", "strength": 78, "wisdom": 50, "agility": 66, "charm": 44, "luck": 52, "leadership": 34, "diligence": 55, "sensitivity": 60, "hit_points": 40, "stamina": 40, "morale": 66},
			{"name": "카산드라", "strength": 60, "wisdom": 58, "agility": 70, "charm": 62, "luck": 54, "leadership": 30, "diligence": 62, "sensitivity": 68, "hit_points": 40, "stamina": 40, "morale": 64},
		],
	},
	"batur": {
		"party_name": "바트르 칸 부대",
		"faction": "초원 칸국",
		"color": Color(0.27, 0.55, 0.32),
		"territory": "",
		"commander": "바트르 칸",
		"members": [
			{"name": "바트르 칸", "strength": 84, "wisdom": 68, "agility": 72, "charm": 64, "luck": 60, "leadership": 86, "diligence": 70, "sensitivity": 48, "hit_points": 40, "stamina": 40, "morale": 85},
			{"name": "테무르", "strength": 80, "wisdom": 50, "agility": 74, "charm": 48, "luck": 54, "leadership": 35, "diligence": 64, "sensitivity": 44, "hit_points": 40, "stamina": 40, "morale": 72},
			{"name": "알탄", "strength": 76, "wisdom": 52, "agility": 70, "charm": 46, "luck": 56, "leadership": 32, "diligence": 62, "sensitivity": 42, "hit_points": 40, "stamina": 40, "morale": 70},
			{"name": "초로스", "strength": 78, "wisdom": 48, "agility": 72, "charm": 44, "luck": 58, "leadership": 30, "diligence": 60, "sensitivity": 40, "hit_points": 40, "stamina": 40, "morale": 68},
		],
	},
}

## 부대 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_party(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## 스펙의 지휘관 이름. 없으면 빈 문자열.
static func commander_name(id: String) -> String:
	return get_party(id).get("commander", "")

## 스펙의 멤버들을 Human 객체로 생성한다. 능력치를 반영하고 이동력·시야는 인간 기본값.
## 없는 id면 빈 배열. Human(RefCounted)만 생성하므로 씬 트리 없이 동작한다.
static func make_members(id: String) -> Array:
	var result: Array = []
	for m in get_party(id).get("members", []):
		var h := Human.new(m["name"])
		for key in _STAT_KEYS:
			h.set(key, m[key])
		h.movement = HUMAN_MOVEMENT
		h.vision = HUMAN_VISION
		result.append(h)
	return result
