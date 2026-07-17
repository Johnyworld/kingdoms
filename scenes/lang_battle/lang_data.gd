class_name LangData
extends RefCounted
## 클래스 스탯 / 병종 상성 데이터 로더 — 스펙 §1.1, §2.3.
## 동봉 CSV(class_stats.csv / matchup.csv)를 그대로 읽는다. 원본 스프라이트가 아니라
## 수치 데이터이므로 사용 가능(스펙 §8: "그대로 사용 가능").

# .txt 확장자를 쓴다: Godot 는 .csv 를 자동으로 "CSV 번역"으로 임포트해
# 불필요한 .translation 아티팩트와 로케일 키를 만든다. .txt 는 순수 파일로 남는다.
const _CLASS_STATS_CSV := "res://scenes/lang_battle/data/class_stats.txt"
const _MATCHUP_CSV := "res://scenes/lang_battle/data/matchup.txt"

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
	f.get_line()  # 헤더 스킵
	# 헤더: idx,offset,magicTier,hp,magicFlags,at,df,mv,cmdRange,cmdAT,cmdDF,f76,maxSoldiers
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var c := line.split(",")
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
	f.get_line()  # 헤더 스킵
	# 헤더: classIdx,selfTier,at,df,vsT0_atk,vsT0_df,...,vsT4_atk,vsT4_df
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var c := line.split(",")
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
