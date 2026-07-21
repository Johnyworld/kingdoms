class_name LangBridge
extends RefCounted
## 게임 부대(Party: Human 멤버 + troop_type) ↔ lang 전투 유닛(LangResolver) 브릿지.
## 완전 교체(랑그릿사식 전투) 배선의 단일 매핑 출처 — 헤드리스(NPC↔NPC)·오버레이(플레이어) 공용.
## troop_type/kind → class_id·kind, 멤버 수 → soldiers; 결과 최종 병력수 → 생존 Human 목록.
## 매핑 상수·acc_mod는 lang_battle.gd의 커스텀 유닛 생성(_mk_custom_unit)과 일치시킨다.
## → docs/spec/features/lang-battle.md 게임 통합

# 병종 → lang 클래스. 경보병·경궁병 동일 base(classId 1), 영웅=지휘관(classId 4). lang_battle.gd와 일치.
const INFANTRY_CLASS := 1
const ARCHER_CLASS := 1
const HERO_CLASS := 4
const TROOP_ACC := 5   # 경보병·경궁병 개활지 회피 보정(acc_mod). lang_battle.gd와 일치.
const HERO_ACC := 0
const LEVEL := 3       # 유닛 레벨. 현재 고정(Human 스탯 완전 교체로 미사용) — 밸런스 튜닝 지점.
# 영웅 부대(Human 1인)의 lang 전투 비중(soldiers=HP 몫). 현재 고정 플레이스홀더 — 밸런스 튜닝 지점.
const HERO_SOLDIERS := 10

## Party → lang 유닛(Dictionary). side 0=공격/아군, 1=방어/적. kind(hero)·troop_type로 병종 결정.
## 영웅 부대는 지휘관 클래스 단독(27/24, self_cmd=false), 일반부대는 멤버 수 = soldiers.
static func unit_from_party(party, side: int) -> Dictionary:
	if party.kind == Party.KIND_HERO:
		var h := LangResolver.make_unit(HERO_CLASS, side, HERO_SOLDIERS, 0, 0, 0, LEVEL, HERO_ACC)
		h["kind"] = ""          # 병종 상성 중립
		h["self_cmd"] = false   # 단독 영웅 — 자기 지휘보정 없음(base 27/24 유지)
		return h
	var count: int = party.members.size()
	if party.troop_type == "light_archer":
		var a := LangResolver.make_unit(ARCHER_CLASS, side, count, 0, 0, 0, LEVEL, TROOP_ACC)
		a["kind"] = "archer"
		return a
	var u := LangResolver.make_unit(INFANTRY_CLASS, side, count, 0, 0, 0, LEVEL, TROOP_ACC)
	u["kind"] = "infantry"
	return u

## lang 결과 최종 병력수(final_soldiers) → 생존 Human 목록. 멤버 앞에서부터 그 수만큼 유지.
## 영웅 부대는 Human 1인이라 병력수>0이면 생존(멤버 유지), 0이면 전멸([]). game.gd _apply_survivors 입력.
static func survivors(party, final_soldiers: int) -> Array:
	if party.kind == Party.KIND_HERO:
		return party.members.duplicate() if final_soldiers > 0 else []
	return party.members.slice(0, maxi(0, final_soldiers))
