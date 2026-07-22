class_name TypeAdvantage
extends RefCounted
## 병종 상성 테이블 로더 — 스펙 §2.3.
## kind 가위바위보(기병>보병>창병>기병, 그리고 기/보/창 > 궁병)를 데이터로 정의한다.
## 랑그릿사 ROM 참조 없이 직접 밸런스를 조정하는 튜닝 지점.
## → res://data/type_advantage.csv (importer="keep" — Godot 번역 자동임포트 방지).

const _CSV := "res://data/type_advantage.csv"

# "attacker>defender" -> Vector2i(at, df) 보너스. 없으면 우위 아님(ZERO).
static var _table: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_CSV, FileAccess.READ)
	assert(f != null, "type_advantage.csv 를 열 수 없음")
	f.get_csv_line()  # 헤더 스킵: attacker,defender,at,df
	while not f.eof_reached():
		var c := f.get_csv_line()   # 따옴표·구분자 처리(스프레드시트 저장 대응)
		if c.size() < 4:
			continue
		_table["%s>%s" % [c[0], c[1]]] = Vector2i(int(c[2]), int(c[3]))

## attacker_kind 가 opp_kind 에게 갖는 상성 보너스(at, df). 우위 조합이 아니면 ZERO.
## hero·빈 kind 는 테이블에 없어 자연히 중립(ZERO).
static func bonus(attacker_kind: String, opp_kind: String) -> Vector2i:
	_ensure_loaded()
	return _table.get("%s>%s" % [attacker_kind, opp_kind], Vector2i.ZERO)
