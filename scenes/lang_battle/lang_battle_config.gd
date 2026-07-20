class_name LangBattleConfig
extends RefCounted
## 전투 설정 화면(lang_setup) → 전투 씬(lang_battle) 파라미터 전달용.
## static 이라 씬 전환 후에도 유지된다. take() 로 1회 소비(비어 있으면 기본 시나리오 진입).
##
## 저장 형태: { "a": {kind,count}, "b": {kind,count}, "mode": "melee"|"ranged" }
##  - side 설정: { "kind": "hero"|"infantry"|"archer", "count": 1..10 }
##  - mode: 교전 방식(양 진영 공용). 원거리는 최소 한쪽이 경궁병일 때만.

static var _pending: Dictionary = {}   # 전투 씬으로 넘길 값(take 로 1회 소비)
static var _last: Dictionary = {}      # 마지막으로 고른 값(설정 화면 복원용 — 소비 안 함)

## 설정 저장(설정 화면 [전투 시작]). a=side0(아군/청), b=side1(적군/적), mode=공용 교전 방식.
## 전투 씬 전달용(_pending)과 설정 화면 복원용(_last)에 모두 기록.
static func set_config(a: Dictionary, b: Dictionary, mode: String = "melee") -> void:
	var cfg := {"a": a.duplicate(), "b": b.duplicate(), "mode": mode}
	_pending = cfg.duplicate(true)
	_last = cfg.duplicate(true)

## 전투 씬으로 넘길 설정을 1회 꺼내 소비. 없으면 빈 Dictionary → 기본 시나리오로 진입.
static func take() -> Dictionary:
	var c := _pending
	_pending = {}
	return c

## 마지막으로 고른 설정(설정 화면이 이전 선택을 복원할 때 사용). 없으면 빈 Dictionary.
static func last() -> Dictionary:
	return _last.duplicate(true)
