class_name UnitTypes
extends RefCounted
## 게임 유닛 아키타입 카탈로그 (순수 랑그릿사식 유닛 모델).
## Human 스탯/장비 RPG 계층을 대체한다 — 부대는 "아키타입 + 병력(HP)"를 가진 유닛이다.
## 전투 스탯(at/df·이동력 mv·지휘범위 cmd_range·지휘보정 cmd_at/cmd_df)·병종 kind·HP·시야·
## 원거리 여부·표시명이 모두 이 카탈로그(res://data/unit_types.csv) 한 곳에서 나온다(단일 출처).
## 병종 상성(kind 가위바위보)은 res://data/type_advantage.csv([TypeAdvantage]).
## → docs/spec/features/lang-battle.md 게임 통합 · docs/spec/data/unit-types.md
##
## 데이터는 res://data/unit_types.csv 에서 lazy-load 한다. CSV 헤더:
##   id,name,kind,hp,vision,ranged,range,at,df,mv,cmd_range,cmd_at,cmd_df
##   name  = 병종 표시명(경보병/경궁병). 영웅(hero)은 표시명 없음(hero_name 사용).
##   kind  = 병종 상성 분류(infantry/archer/cavalry/spear/hero). hero 는 상성 중립.
##   hp·vision·전투 스탯 선택은 밸런스 튜닝 지점(현재 병력 10 균일). ROM 참조 없이 직접 조정.
##   range = 월드맵 공격거리(헥스). 근접 0, 원거리(경궁병) 3.

const _UNITS_CSV := "res://data/unit_types.csv"

# 알려진 병종 kind (참조 무결성 검증용). type_advantage.csv 와 규약 일치.
const _KNOWN_KINDS := ["infantry", "archer", "cavalry", "spear", "hero"]

# 아키타입 id → {name, kind, hp, vision, ranged, range, at, df, mv, cmd_range, cmd_at, cmd_df}
static var _archetypes: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_units()

static func _load_units() -> void:
	var f := FileAccess.open(_UNITS_CSV, FileAccess.READ)
	assert(f != null, "unit_types.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 13:
			continue
		var id := c[0]
		var kind := c[2]
		# 참조 무결성: kind 는 알려진 병종이어야 한다(오타 조기 발견).
		if not _KNOWN_KINDS.has(kind):
			push_error("unit_types.csv: '%s' 의 kind '%s' 가 알려지지 않음" % [id, kind])
		_archetypes[id] = {
			"name": c[1],
			"kind": kind,
			"hp": int(c[3]),
			"vision": int(c[4]),
			"ranged": c[5] == "true",
			"range": int(c[6]),
			"at": int(c[7]),
			"df": int(c[8]),
			"mv": int(c[9]),
			"cmd_range": int(c[10]),
			"cmd_at": int(c[11]),
			"cmd_df": int(c[12]),
		}

## 아키타입 스펙(없는 id면 빈 Dictionary).
static func spec(arche: String) -> Dictionary:
	_ensure_loaded()
	return _archetypes.get(arche, {})

## 병종 표시명(경보병/경궁병). 영웅·미지 아키타입이면 빈 문자열.
static func display_name(arche: String) -> String:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("name", "")

## 병종 상성 kind(infantry/archer/cavalry/spear/hero). 없으면 빈 문자열.
static func kind(arche: String) -> String:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("kind", "")

## 최대 병력(HP) — 부대 생성 시 soldiers 시작값. 없으면 0.
static func max_hp(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("hp", 0)

## fog 시야 반경(헥스). 랑그릿사엔 없어 게임 카탈로그가 보유. 없으면 0.
static func vision(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("vision", 0)

## 원거리 병종인지(경궁병). 월드맵 사격·공격거리 판정. 없으면 false.
static func is_ranged(arche: String) -> bool:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("ranged", false)

## 월드맵 공격거리(헥스). 근접 0, 원거리 3. 없으면 0.
static func attack_range(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("range", 0)

## 이동력(mv). 없으면 0.
static func movement(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("mv", 0)

## 지휘범위(cmd_range). 없으면 0.
static func command_range(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("cmd_range", 0)

## 표시용 기본 공격력(상성·지휘보정 전). 없으면 0.
static func base_at(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("at", 0)

## 표시용 기본 방어력. 없으면 0.
static func base_df(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("df", 0)

## LangResolver 주입용 전투 스탯 번들. 없는 아키타입이면 0/빈 kind.
## → LangResolver.make_unit 의 stats 인자로 그대로 넘긴다.
static func combat_stats(arche: String) -> Dictionary:
	_ensure_loaded()
	var a: Dictionary = _archetypes.get(arche, {})
	return {
		"at": int(a.get("at", 0)),
		"df": int(a.get("df", 0)),
		"cmd_range": int(a.get("cmd_range", 0)),
		"cmd_at": int(a.get("cmd_at", 0)),
		"cmd_df": int(a.get("cmd_df", 0)),
		"kind": String(a.get("kind", "")),
	}
