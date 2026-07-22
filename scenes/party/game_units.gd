class_name GameUnits
extends RefCounted
## 게임 유닛 아키타입 → 랑그릿사 클래스 매핑 카탈로그 (순수 랑그릿사 유닛 모델).
## Human 스탯/장비 RPG 계층을 대체한다 — 부대는 이제 "클래스 + 병력(HP)"를 가진 유닛이다.
##   · 전투 AT/DF·상성·이동력(mv)·지휘범위(cmd_range) → lang 클래스 스탯(LangData/class_stats.csv)
##   · HP(병력=시작 병력수)·시야·원거리 여부·표시명 → 이 카탈로그(res://data/units.csv)
## → docs/spec/features/lang-battle.md 게임 통합 · docs/spec/data/units.md
##
## 데이터는 res://data/units.csv 에서 lazy-load 한다(LangData 와 동일 패턴). CSV 헤더:
##   id,name,class_id,hp,vision,ranged,range
##   name  = 병종 표시명(경보병/경궁병). 영웅(hero)은 표시명 없음(hero_name 사용).
##   class_id 1 = 경보병·경궁병 공통 base(at23/df21). 4 = 지휘관(영웅, at27/df24, cmd_range 4).
##   hp·vision·class 선택은 밸런스 튜닝 지점(현재 병력 10 균일).
##   range = 월드맵 공격거리(헥스). 근접 0, 원거리(경궁병) 3.

const _UNITS_CSV := "res://data/units.csv"

# 아키타입 id → {name, class_id, hp, vision, ranged, range}
static var _archetypes: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_units()

static func _load_units() -> void:
	var f := FileAccess.open(_UNITS_CSV, FileAccess.READ)
	assert(f != null, "units.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 7:
			continue
		var id := c[0]
		var cid := int(c[2])
		# 참조 무결성: class_id 는 LangData 클래스여야 한다(오타·미정의 조기 발견).
		# 행은 남긴다(heroes FK 는 스킵) — 아키타입은 id 로 직접 참조되므로 없애면 부대 생성이 깨진다.
		# 잘못된 class_id 면 lang 스탯이 0이 되지만 push_error 로 시끄럽게 경고한다.
		if LangData.get_class_stat(cid).is_empty():
			push_error("units.csv: '%s' 의 class_id %d 가 LangData 에 없음" % [id, cid])
		_archetypes[id] = {
			"name": c[1],
			"class_id": cid,
			"hp": int(c[3]),
			"vision": int(c[4]),
			"ranged": c[5] == "true",
			"range": int(c[6]),
		}

## 아키타입 스펙(없는 id면 빈 Dictionary).
static func spec(arche: String) -> Dictionary:
	_ensure_loaded()
	return _archetypes.get(arche, {})

## 병종 표시명(경보병/경궁병). 영웅·미지 아키타입이면 빈 문자열.
static func display_name(arche: String) -> String:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("name", "")

## lang 클래스 id(없는 아키타입이면 0 = 더미 클래스).
static func class_id(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("class_id", 0)

## 최대 병력(HP) — 부대 생성 시 soldiers 시작값. 없으면 0.
static func max_hp(arche: String) -> int:
	_ensure_loaded()
	return _archetypes.get(arche, {}).get("hp", 0)

## fog 시야 반경(헥스). lang 클래스엔 없어 게임 카탈로그가 보유. 없으면 0.
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

## 이동력 = lang 클래스 mv. 아키타입/클래스 없으면 0.
static func movement(arche: String) -> int:
	return LangData.get_class_stat(class_id(arche)).get("mv", 0)

## 지휘범위 = lang 클래스 cmd_range. 없으면 0.
static func command_range(arche: String) -> int:
	return LangData.get_class_stat(class_id(arche)).get("cmd_range", 0)

## 표시용 기본 공격력 = lang 클래스 at(상성·지휘보정 전). 없으면 0.
static func base_at(arche: String) -> int:
	return LangData.get_class_stat(class_id(arche)).get("at", 0)

## 표시용 기본 방어력 = lang 클래스 df. 없으면 0.
static func base_df(arche: String) -> int:
	return LangData.get_class_stat(class_id(arche)).get("df", 0)

## LangResolver 병종 kind 문자열(상성용). 원거리=archer, 영웅=중립(""), 그 외 infantry.
static func lang_kind(arche: String) -> String:
	if arche == "hero":
		return ""
	return "archer" if is_ranged(arche) else "infantry"
