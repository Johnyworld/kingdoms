class_name LangData
extends RefCounted
## 클래스 스탯 / 병종 상성 데이터 로더 — 스펙 §1.1, §2.3.
## 동봉 CSV(class_stats.csv / matchup.csv)를 그대로 읽는다. 원본 스프라이트가 아니라
## 수치 데이터이므로 사용 가능(스펙 §8: "그대로 사용 가능").

# 게임 튜닝 CSV는 res://data/ 에 모은다(편집 동선 통일). Godot 가 .csv 를 "CSV 번역"으로
# 자동 임포트하지 않도록 각 .csv 에 importer="keep" .import 를 둔다(번역 아티팩트 없이 원본 그대로 export).
const _CLASS_STATS_CSV := "res://data/class_stats.csv"
const _MATCHUP_CSV := "res://data/matchup.csv"

## classId -> ClassStat 딕셔너리
## {
##   magic_tier, hp, magic_flags, at, df, mv,
##   cmd_range, cmd_at, cmd_df, magic_resist, max_soldiers,
##   matchup: [ [atk,df], x5 ]   # 상대 tier 0..4 별 상성 보정
## }
static var _classes: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_classes()
	_load_matchups()

static func _load_classes() -> void:
	var f := FileAccess.open(_CLASS_STATS_CSV, FileAccess.READ)
	assert(f != null, "class_stats.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵
	# 헤더: idx,offset,magicTier,hp,magicFlags,at,df,mv,cmdRange,cmdAT,cmdDF,f76,maxSoldiers
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 13:
			continue
		var idx := int(c[0])
		_classes[idx] = {
			"magic_tier": int(c[2]),
			"hp": int(c[3]),
			"magic_flags": int(c[4]),
			"at": int(c[5]),
			"df": int(c[6]),
			"mv": int(c[7]),
			"cmd_range": int(c[8]),
			"cmd_at": int(c[9]),
			"cmd_df": int(c[10]),
			"magic_resist": int(c[11]),
			"max_soldiers": int(c[12]),
			"matchup": [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0]],
		}

static func _load_matchups() -> void:
	var f := FileAccess.open(_MATCHUP_CSV, FileAccess.READ)
	assert(f != null, "matchup.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵
	# 헤더: classIdx,selfTier,at,df,vsT0_atk,vsT0_df,...,vsT4_atk,vsT4_df
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 14:
			continue
		var idx := int(c[0])
		if not _classes.has(idx):
			continue
		var mu: Array = []
		for t in range(5):
			var atk := int(c[4 + t * 2])
			var df := int(c[5 + t * 2])
			mu.append([atk, df])
		_classes[idx]["matchup"] = mu

## 클래스 스탯 조회 (스펙 §부록B 0xB61E get_class_stats).
static func get_class_stat(class_id: int) -> Dictionary:
	_ensure_loaded()
	return _classes.get(class_id, {})

static func class_count() -> int:
	_ensure_loaded()
	return _classes.size()
