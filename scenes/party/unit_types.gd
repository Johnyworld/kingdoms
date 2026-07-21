class_name UnitTypes
## 유닛·부대 카탈로그. 랑그릿사식 이분화 — 세력별 영웅 4명(영웅부대·단독)과
## 병종 아키타입(경보병·경궁병, 일반부대 10명)을 데이터로 정의한다.
## BuildingTypes·Terrain과 동일한 "GDScript 카탈로그" 패턴. game.gd가 여기서 부대를 생성해 배치한다.
## 순수 class+count 모델(M4-C) — 부대는 "아키타입 + 병력수"다. 개별 병사 스탯·Human 객체는 없다.
## 전투·이동·사거리는 병종 lang 클래스([GameUnits](game_units.gd))가 결정한다.

# 플레이어 세력 id.
const PLAYER_ID := "azel"
# NPC 세력 id 목록(표시 순서).
const NPC_IDS := ["qasim", "balthazar", "batur"]
# 전 세력 id(플레이어 + NPC).
const FACTION_IDS := ["azel", "qasim", "balthazar", "batur"]

# 일반부대 1개의 병사 수(병력).
const TROOP_SIZE := 10
# 세력당 영웅 수.
const HEROES_PER_FACTION := 4

# 세력 id → 스펙. 스펙 키: faction(세력명)·color(토큰 색)·territory(수도 영지)·heroes(영웅 이름 배열, 첫 항목 = 세력 지휘관).
const CATALOG := {
	"azel": {
		"faction": "푸른 왕국",
		"color": Color(0.2, 0.3, 0.8),
		"territory": "창천성",
		"heroes": ["아젤 하르윈", "로엔 카스터", "미라 벨포드", "가레스 던"],
	},
	"qasim": {
		"faction": "사막 술탄국",
		"color": Color(0.78, 0.28, 0.22),
		"territory": "알사바흐",
		"heroes": ["카심 이븐 라시드", "자밀라", "하산 알와히드", "유수프"],
	},
	"balthazar": {
		"faction": "암흑 제국",
		"color": Color(0.5, 0.24, 0.6),
		"territory": "흑요요새",
		"heroes": ["발타자르", "모르가나", "드레이븐", "카산드라"],
	},
	"batur": {
		"faction": "초원 칸국",
		"color": Color(0.27, 0.55, 0.32),
		"territory": "텡그리 언덕",
		"heroes": ["바트르 칸", "테무르", "알탄", "초로스"],
	},
}

# 병종 아키타입(세력 공용). id → {name}. 전투·사거리는 lang 클래스(GameUnits 아키타입)로 결정. → units.md
const TROOPS := {
	"light_infantry": {"name": "경보병"},
	"light_archer": {"name": "경궁병"},
}

## 세력 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_faction(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## 세력의 index번째 영웅 이름. 범위 밖이면 빈 문자열.
static func hero_name(faction: String, index: int) -> String:
	var heroes: Array = get_faction(faction).get("heroes", [])
	if index < 0 or index >= heroes.size():
		return ""
	return heroes[index]

## "{영웅 이름} 부대". 범위 밖이면 빈 문자열.
static func hero_party_name(faction: String, index: int) -> String:
	var n := hero_name(faction, index)
	return "%s 부대" % n if n != "" else ""

## 병종 표시 이름(경보병/경궁병). 없으면 빈 문자열.
static func troop_name(archetype: String) -> String:
	return TROOPS.get(archetype, {}).get("name", "")
