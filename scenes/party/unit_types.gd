class_name UnitTypes
## 유닛·부대 카탈로그. 랑그릿사식 이분화 — 세력별 영웅 4명(영웅부대·단독)과
## 병종 아키타입(경보병·경궁병, 일반부대 10명)을 데이터로 정의한다.
## 세력·영웅 데이터는 res://data/factions.csv(부모) + res://data/heroes.csv(영웅, faction FK)에서
## lazy-load 한다(GameUnits 와 동일 패턴). 병종 표시명·전투 스탯은 GameUnits(units.csv)가 결정.
## game.gd 가 여기서 부대를 생성해 배치한다. 순수 class+count 모델(M4-C) — 부대는 "아키타입 + 병력수"다.

const _FACTIONS_CSV := "res://data/factions.csv"
const _HEROES_CSV := "res://data/heroes.csv"

# 플레이어 세력 id (게임 규칙 — 코드 상수).
const PLAYER_ID := "azel"
# 일반부대 1개의 병사 수(병력).
const TROOP_SIZE := 10
# 세력당 영웅 수.
const HEROES_PER_FACTION := 4

# factions.csv 행 순서에서 파생. FACTION_IDS = 전 세력(표시 순서), NPC_IDS = 플레이어 제외.
static var FACTION_IDS: Array = []
static var NPC_IDS: Array = []

# 세력 id → 스펙. 키: faction(세력명)·color(토큰 색)·territory(수도 영지)·start_corner(시작 모서리)·
# heroes(영웅 이름 배열, 첫 항목 = 세력 지휘관).
static var _factions: Dictionary = {}
static var _loaded := false

# 클래스 로드 시 즉시 채운다 — FACTION_IDS/NPC_IDS 를 프로퍼티로 읽는 호출부가 있어서다.
static func _static_init() -> void:
	_ensure_loaded()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_factions()
	_load_heroes()

static func _load_factions() -> void:
	var f := FileAccess.open(_FACTIONS_CSV, FileAccess.READ)
	assert(f != null, "factions.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵: id,name,color,territory,start_corner
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 시 따옴표가 붙어도 안전)
		if c.size() < 5:
			continue
		var id := c[0]
		_factions[id] = {
			"faction": c[1],
			"color": Color.html(c[2]),
			"territory": c[3],
			"start_corner": c[4],
			"heroes": [],   # heroes.csv 로 채운다(FK join).
		}
		FACTION_IDS.append(id)
		if id != PLAYER_ID:
			NPC_IDS.append(id)

static func _load_heroes() -> void:
	var f := FileAccess.open(_HEROES_CSV, FileAccess.READ)
	assert(f != null, "heroes.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵: id,name,faction
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 3:
			continue
		var faction_id := c[2]
		# 참조 무결성: 영웅의 faction 은 factions.csv 에 있어야 한다(오타 조기 발견).
		if not _factions.has(faction_id):
			push_error("heroes.csv: '%s' 의 faction '%s' 가 factions.csv 에 없음" % [c[0], faction_id])
			continue
		# 행 순서 = 세력별 영웅 순서(첫 행 = 지휘관).
		(_factions[faction_id]["heroes"] as Array).append(c[1])

## 세력 스펙을 반환한다. 없는 id면 빈 Dictionary.
static func get_faction(id: String) -> Dictionary:
	_ensure_loaded()
	return _factions.get(id, {})

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

## 병종 표시 이름(경보병/경궁병). units.csv(GameUnits)에 위임. 없으면 빈 문자열.
static func troop_name(archetype: String) -> String:
	return GameUnits.display_name(archetype)
