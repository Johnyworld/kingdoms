class_name GameUnits
extends RefCounted
## 게임 유닛 아키타입 → 랑그릿사 클래스 매핑 카탈로그 (순수 랑그릿사 유닛 모델).
## Human 스탯/장비 RPG 계층을 대체한다 — 부대는 이제 "클래스 + 병력(HP)"를 가진 유닛이다.
##   · 전투 AT/DF·상성·이동력(mv)·지휘범위(cmd_range) → lang 클래스 스탯(LangData/class_stats.txt)
##   · HP(병력=시작 병력수)·시야·원거리 여부 → 이 카탈로그(랑그릿사엔 fog 시야 개념이 없어 게임이 보유)
## → docs/spec/features/lang-battle.md 게임 통합 · docs/spec/data/units.md

# 아키타입 id → {class_id(lang 클래스), hp(병력 = 시작 병력수/최대 HP), vision(fog 시야), ranged(원거리 병종)}
# class_id 1 = 경보병·경궁병 공통 base(at23/df21). 경궁병은 ranged=true + 근접 병종 상성 페널티(LangResolver).
# class_id 4 = 지휘관(영웅, at27/df24, cmd_range 4).
# hp·vision·class 선택은 밸런스 튜닝 지점(현재 병력 10 균일).
# range = 월드맵 공격거리(헥스). 근접 0, 원거리(경궁병) 3. 사격·NPC 원거리 포지셔닝 판정에 쓴다.
const ARCHETYPES := {
	"hero":           {"class_id": 4, "hp": 10, "vision": 6, "ranged": false, "range": 0},
	"light_infantry": {"class_id": 1, "hp": 10, "vision": 5, "ranged": false, "range": 0},
	"light_archer":   {"class_id": 1, "hp": 10, "vision": 5, "ranged": true,  "range": 3},
}

## 아키타입 스펙(없는 id면 빈 Dictionary).
static func spec(arche: String) -> Dictionary:
	return ARCHETYPES.get(arche, {})

## lang 클래스 id(없는 아키타입이면 0 = 더미 클래스).
static func class_id(arche: String) -> int:
	return ARCHETYPES.get(arche, {}).get("class_id", 0)

## 최대 병력(HP) — 부대 생성 시 soldiers 시작값. 없으면 0.
static func max_hp(arche: String) -> int:
	return ARCHETYPES.get(arche, {}).get("hp", 0)

## fog 시야 반경(헥스). lang 클래스엔 없어 게임 카탈로그가 보유. 없으면 0.
static func vision(arche: String) -> int:
	return ARCHETYPES.get(arche, {}).get("vision", 0)

## 원거리 병종인지(경궁병). 월드맵 사격·공격거리 판정. 없으면 false.
static func is_ranged(arche: String) -> bool:
	return ARCHETYPES.get(arche, {}).get("ranged", false)

## 월드맵 공격거리(헥스). 근접 0, 원거리 3. 없으면 0.
static func attack_range(arche: String) -> int:
	return ARCHETYPES.get(arche, {}).get("range", 0)

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
