class_name CombatResolver
extends RefCounted
## 두 부대 멤버(Human)의 교전을 능력치로 판정하는 순수 로직. 씬·시각 요소 없이 데이터만 다룬다.
## 확률은 넘겨받은 RandomNumberGenerator로 굴려 시드 고정 시 결정적이다(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 기획 원본(docs/table/시스템/전투.md) 중 현재 능력치로 가능한 부분만 구현했다.
## 무기·방어구·방패·상성·마법·상태이상·지형·원거리·리치 선제권은 미구현.

const BASE_HIT := 90.0    # 기본 명중률(%). 대상 회피율을 뺀다.
const CRIT_MULT := 1.5    # 치명타 피해 배율.
const EXCHANGES := 3      # 교전 시 각자 최대 타격 횟수.

## 공격력 AT = 무기 공격력 + floor(힘/5).
static func attack_power(h) -> int:
	return ItemTypes.weapon_attack(h.weapon) + int(h.strength) / 5   # 정수 나눗셈(내림)

## 방어력 DF = 착용 방어구 방어력 합. 방패는 미구현.
static func defense(h) -> int:
	return ItemTypes.total_defense(h.armor)

## 회피율(%) = 민첩 × 0.5. 지형·장비무게 보정은 미구현.
static func evasion(h) -> float:
	return h.agility * 0.5

## 명중(%) = 90 − 대상 회피율. 상한 clamp 없음(0 이하면 무조건 빗나감).
static func hit_chance(attacker, defender) -> float:
	return BASE_HIT - evasion(defender)

## 치명타(%) = 행운 × 0.5.
static func crit_chance(h) -> float:
	return h.luck * 0.5

## 한 번의 타격 피해 = floor(max(1, AT − DF) × 상성배율 × 치명배율).
## 상성 = 방어자 방어구분류 × 공격자 무기 데미지타입(ItemTypes).
static func hit_damage(attacker, defender, crit: bool) -> int:
	var base: int = maxi(1, attack_power(attacker) - defense(defender))
	var aff := ItemTypes.affinity(ItemTypes.armor_class_of(defender.armor), ItemTypes.weapon_damage_type(attacker.weapon))
	var mult := (CRIT_MULT if crit else 1.0) * aff
	return int(floor(base * mult))

## 1회 공방 판정. defender_hp에서 피해를 뺀 결과를 반환한다.
## 반환: {hit, crit, damage, hp(차감 후), dead}.
static func resolve_hit(attacker, defender, defender_hp: int, rng: RandomNumberGenerator) -> Dictionary:
	# 명중 = 굴린 값(0~100) < 명중률. 명중률이 0 이하면 무조건 빗나간다.
	var hit := rng.randf() * 100.0 < hit_chance(attacker, defender)
	if not hit:
		return {"hit": false, "crit": false, "damage": 0, "hp": defender_hp, "dead": defender_hp <= 0}
	var crit := rng.randf() * 100.0 < crit_chance(attacker)
	var dmg := hit_damage(attacker, defender, crit)
	var hp := defender_hp - dmg
	return {"hit": true, "crit": crit, "damage": dmg, "hp": hp, "dead": hp <= 0}

## 근접 교전. 개시자 a가 선공하고 a→b, b→a를 최대 EXCHANGES 라운드 반복한다.
## 도중 한쪽 생명점이 0 이하가 되면 즉시 종료한다(선공 이점 — 남은 반격 없음).
## 반환: {a_hp, b_hp, a_dead, b_dead}.
static func resolve_engagement(a, b, a_hp: int, b_hp: int, rng: RandomNumberGenerator) -> Dictionary:
	for _i in EXCHANGES:
		b_hp = resolve_hit(a, b, b_hp, rng)["hp"]
		if b_hp <= 0:
			break
		a_hp = resolve_hit(b, a, a_hp, rng)["hp"]
		if a_hp <= 0:
			break
	return {"a_hp": a_hp, "b_hp": b_hp, "a_dead": a_hp <= 0, "b_dead": b_hp <= 0}
