class_name LangBridge
extends RefCounted
## 게임 부대(Party: Human 멤버 + troop_type) ↔ lang 전투 유닛(LangResolver) 브릿지.
## 완전 교체(랑그릿사식 전투) 배선의 단일 매핑 출처 — 헤드리스(NPC↔NPC)·오버레이(플레이어) 공용.
## troop_type/kind → class_id·kind, 멤버 수 → soldiers; 결과 최종 병력수 → 생존 Human 목록.
## 매핑 상수·acc_mod는 lang_battle.gd의 커스텀 유닛 생성(_mk_custom_unit)과 일치시킨다.
## → docs/spec/features/lang-battle.md 게임 통합

# lang 유닛 생성 파라미터(GameUnits 카탈로그엔 없는 lang-전투 세부값).
const TROOP_ACC := 5   # 경보병·경궁병 개활지 회피 보정(acc_mod). lang_battle.gd와 일치.
const HERO_ACC := 0
const LEVEL := 3       # 유닛 레벨. 현재 고정 — 밸런스 튜닝 지점.

## Party → lang 유닛(Dictionary). side 0=공격/아군, 1=방어/적.
## 클래스·병종·HP는 GameUnits 카탈로그(단일 출처). 영웅=지휘관 클래스 단독(self_cmd=false, HP 고정),
## 일반부대 병력=멤버 수(M2 임시 — M3에서 party.soldiers 필드로 대체).
static func unit_from_party(party, side: int) -> Dictionary:
	var arche: String = party.archetype()
	var is_hero := arche == "hero"
	var soldiers: int = GameUnits.max_hp(arche) if is_hero else party.members.size()
	var acc := HERO_ACC if is_hero else TROOP_ACC
	var u := LangResolver.make_unit(GameUnits.class_id(arche), side, soldiers, 0, 0, 0, LEVEL, acc)
	u["kind"] = GameUnits.lang_kind(arche)
	if is_hero:
		u["self_cmd"] = false   # 단독 영웅 — 자기 지휘보정 없음(base 27/24 유지)
	return u

## lang 결과 최종 병력수(final_soldiers) → 생존 Human 목록. 멤버 앞에서부터 그 수만큼 유지.
## 영웅 부대는 Human 1인이라 병력수>0이면 생존(멤버 유지), 0이면 전멸([]). game.gd _apply_survivors 입력.
static func survivors(party, final_soldiers: int) -> Array:
	if party.kind == Party.KIND_HERO:
		return party.members.duplicate() if final_soldiers > 0 else []
	return party.members.slice(0, maxi(0, final_soldiers))
