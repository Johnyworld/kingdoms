class_name UnitSpawns
extends RefCounted
## 초기 유닛 배치 카탈로그 — 게임 시작 시 맵에 놓이는 유닛을 개별 행으로 정의한다.
## 데이터는 res://data/unit_spawns.csv 에서 lazy-load 한다([UnitTypes]·[FactionCatalog] 동일 패턴).
## 병종 정의(스탯·표시명)는 [UnitTypes](unit_types.gd, unit_types.csv), 세력/영웅은 [FactionCatalog].
## 여기서 나온 entry 를 game.gd 가 소비해 [Party] 를 생성·배치한다(초기 유닛 이후 생산 유닛은 런타임 변수).
## → docs/spec/data/unit-spawns.md · docs/spec/features/parties.md
##
## CSV 헤더: id,faction,type,leader,x,y
##   id      = 스폰 인스턴스 식별자(파일 내 유일). leader 참조 대상.
##   faction = factions.csv 세력 id(FK).
##   type    = 병종 아키타입 id(unit_types.csv: hero/light_infantry/light_archer).
##   leader  = 소속 영웅부대의 id(같은 파일). 영웅 행은 빈 값, 부하 행은 type=="hero" 인 id.
##   x,y     = 절대 셀 좌표(맵 셀). 배치 시 통과불가·중복이면 game.gd 가 인접 빈 칸으로 보정.

const _SPAWNS_CSV := "res://data/unit_spawns.csv"

# 행 순서를 유지한 entry 배열. 각 원소: {id, faction, type, leader, cell: Vector2i}
static var _entries: Array = []
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_spawns()

static func _load_spawns() -> void:
	_entries.clear()   # 재로드 방어(정적 var 는 씬 리로드에도 살아남음)
	var f := FileAccess.open(_SPAWNS_CSV, FileAccess.READ)
	assert(f != null, "unit_spawns.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵
	var ids := {}          # id 유일성 검증
	var hero_ids := {}     # type=="hero" 인 id 집합(leader 무결성 검증용)
	var rows: Array = []   # (entry, leader) — leader 검증은 전 행 로드 후(선언 순서 무관)
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 6:
			continue
		var id := c[0]
		var faction := c[1]
		var type := c[2]
		var leader := c[3]
		# 참조 무결성(오타 조기 발견).
		if ids.has(id):
			push_error("unit_spawns.csv: id '%s' 중복" % id)
		ids[id] = true
		if FactionCatalog.get_faction(faction).is_empty():
			push_error("unit_spawns.csv: '%s' 의 faction '%s' 가 factions.csv 에 없음" % [id, faction])
		if UnitTypes.spec(type).is_empty():
			push_error("unit_spawns.csv: '%s' 의 type '%s' 가 unit_types.csv 에 없음" % [id, type])
		if type == "hero":
			hero_ids[id] = true
		var entry := {
			"id": id,
			"faction": faction,
			"type": type,
			"leader": leader,
			"cell": Vector2i(int(c[4]), int(c[5])),
		}
		_entries.append(entry)
		rows.append(leader)
	# leader 무결성: 비었거나(영웅·독립) 같은 파일 내 hero id 여야 한다.
	for i in _entries.size():
		var leader: String = rows[i]
		if leader != "" and not hero_ids.has(leader):
			push_error("unit_spawns.csv: '%s' 의 leader '%s' 가 영웅 스폰 id 가 아님" % [_entries[i]["id"], leader])

## 스폰 entry 배열(행 순서 유지). 각 원소: {id, faction, type, leader, cell: Vector2i}.
static func entries() -> Array:
	_ensure_loaded()
	return _entries
