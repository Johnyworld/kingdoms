class_name LangBridge
extends RefCounted
## 게임 부대(Party: archetype + soldiers) ↔ lang 전투 유닛(LangResolver) 브릿지.
## 완전 교체(랑그릿사식 전투) 배선의 단일 매핑 출처 — 헤드리스(NPC↔NPC)·오버레이(플레이어) 공용.
## archetype → 전투 스탯(UnitTypes.combat_stats)·kind, party.soldiers → 병력(soldiers). 결과 최종 병력수는 game.gd가 party.soldiers에 직접 반영.
## 매핑 상수·acc_mod는 lang_battle.gd의 커스텀 유닛 생성(_mk_custom_unit)과 일치시킨다.
## → docs/spec/features/lang-battle.md 게임 통합

# lang 유닛 생성 파라미터(UnitTypes 카탈로그엔 없는 lang-전투 세부값).
const TROOP_ACC := 5   # 경보병·경궁병 개활지 회피 보정(acc_mod). lang_battle.gd와 일치.
const HERO_ACC := 0
const LEVEL := 3       # 유닛 레벨. 현재 고정 — 밸런스 튜닝 지점.

## Party → lang 유닛(Dictionary). side 0=공격/아군, 1=방어/적.
## 클래스·병종은 UnitTypes 카탈로그(단일 출처). 병력은 party.soldiers(영웅부대는 생성 시 클래스 HP로 세팅됨).
static func unit_from_party(party, side: int) -> Dictionary:
	var arche: String = party.archetype()
	var is_hero := UnitTypes.kind(arche) == "hero"   # dark_hero 등 오크 영웅 포함(kind 기준)
	var acc := HERO_ACC if is_hero else TROOP_ACC
	# 클래스·병종·전투 스탯은 UnitTypes 카탈로그(단일 출처). kind 는 combat_stats 에 포함.
	var u := LangResolver.make_unit(UnitTypes.combat_stats(arche), side, party.soldiers, 0, 0, 0, LEVEL, acc)
	if is_hero:
		u["self_cmd"] = false   # 단독 영웅 — 자기 지휘보정 없음(base 27/24 유지)
	return u

## 부대 쌍 → lang presenter 오버레이 설정({a:{kind,count,sprite}, b:{...}, mode}). 설정 화면 cfg와 같은 형식.
## kind는 presenter 라벨(hero/archer/infantry), count는 병력, sprite는 전투씬 캐릭터 세트, mode는 거리로(≥2 원거리).
static func battle_config(attacker, defender, distance: int) -> Dictionary:
	return {
		"a": _cfg_side(attacker),
		"b": _cfg_side(defender),
		"mode": "ranged" if distance >= 2 else "melee",
	}

## 부대 한 쪽의 오버레이 cfg 항목. kind=병종 상성(hero/archer/infantry), count=party.soldiers,
## sprite=캐릭터 세트(UnitTypes.sprite — 외형은 side가 아닌 병종으로 결정, 세력 정체성 유지).
## faction/party/color는 전투 HUD 세력·부대 표기용(color는 표시명 역조회한 세력 색). → lang-battle.md HUD 세력·부대 표기
static func _cfg_side(party) -> Dictionary:
	return {
		"kind": UnitTypes.kind(party.archetype()),
		"count": party.soldiers,
		"sprite": UnitTypes.sprite(party.archetype()),
		"faction": party.faction_name,
		"party": party.party_name,
		"color": FactionCatalog.color_of(party.faction_name),
	}
