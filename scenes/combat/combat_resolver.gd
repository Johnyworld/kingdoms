class_name CombatResolver
extends RefCounted
## 두 부대 멤버(Human)의 교전을 능력치로 판정하는 순수 로직. 씬·시각 요소 없이 데이터만 다룬다.
## 확률은 넘겨받은 RandomNumberGenerator로 굴려 시드 고정 시 결정적이다(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 기획 원본(docs/table/시스템/전투.md) 중 현재 능력치로 가능한 부분만 구현했다.
## 무기·방어구·방패·상성·마법·상태이상·지형·원거리·리치 선제권은 미구현.

const BASE_HIT := 90.0    # 기본 명중률(%). 대상 회피율을 뺀다.
const CRIT_MULT := 1.5    # 치명타 피해 배율.
const AGI_SPEED_K := 0.005       # 민첩 1당 공격속도 단축 비율.
const MIN_ATTACK_INTERVAL := 0.4 # 최소 공격 간격(초) — 민첩이 아무리 높아도 이보다 못 빨라짐.

## 공격력 AT = 무기 공격력 + floor(힘/5). weapon 생략 시 주무기(weapons 첫 원소).
static func attack_power(h, weapon := "") -> int:
	var w: String = weapon if weapon != "" else ItemTypes.primary_weapon(h.weapons)
	return ItemTypes.weapon_attack(w) + int(h.strength) / 5   # 정수 나눗셈(내림)

## 방어력 DF = 착용 방어구 방어력 합 + 방패 방어력.
static func defense(h) -> int:
	return ItemTypes.total_defense(h.armor) + ItemTypes.shield_defense(h.shield)

## 막기 확률(%) = 방패 막기 확률. 방패 없으면 0.
static func block_chance(h) -> int:
	return ItemTypes.shield_block(h.shield)

## 착용 장비 총무게 = 보유 무기 전부 + 방어구 합 + 방패 무게.
static func equip_weight(h) -> int:
	var w: int = ItemTypes.shield_weight(h.shield)
	for wp in h.weapons:
		w += ItemTypes.weapon_weight(wp)
	for a in h.armor:
		w += ItemTypes.armor_weight(a)
	return w

## 회피율(%) = 민첩 × 0.5 − 총장비무게 × 0.3. 지형 보정은 미구현.
static func evasion(h) -> float:
	return h.agility * 0.5 - equip_weight(h) * 0.3

## 명중(%) = 90 − 대상 회피율. 상한 clamp 없음(0 이하면 무조건 빗나감).
static func hit_chance(attacker, defender) -> float:
	return BASE_HIT - evasion(defender)

## 치명타(%) = 행운 × 0.5.
static func crit_chance(h) -> float:
	return h.luck * 0.5

## 최종 공격 간격(초) = max(하한, 기본 공격속도 × (1 − 민첩 × 계수)). 민첩 높을수록 빠르다.
## weapon 생략 시 주무기. 전투씬은 이 간격마다 1회 공격(resolve_hit)한다.
static func attack_interval(h, weapon := "") -> float:
	var w: String = weapon if weapon != "" else ItemTypes.primary_weapon(h.weapons)
	return maxf(MIN_ATTACK_INTERVAL, ItemTypes.weapon_attack_speed(w) * (1.0 - h.agility * AGI_SPEED_K))

## 한 번의 타격 피해 = floor(max(1, AT − DF) × 상성배율 × 치명배율).
## 상성 = 방어자 방어구분류 × 공격자 무기 데미지타입(ItemTypes). atk_weapon 생략 시 주무기.
static func hit_damage(attacker, defender, crit: bool, atk_weapon := "") -> int:
	var w: String = atk_weapon if atk_weapon != "" else ItemTypes.primary_weapon(attacker.weapons)
	var base: int = maxi(1, attack_power(attacker, w) - defense(defender))
	var aff := ItemTypes.affinity(ItemTypes.armor_class_of(defender.armor), ItemTypes.weapon_damage_type(w))
	var mult := (CRIT_MULT if crit else 1.0) * aff
	return int(floor(base * mult))

## 1회 공방 판정. defender_hp에서 피해를 뺀 결과를 반환한다. atk_weapon 생략 시 주무기.
## 반환: {hit, crit, damage, hp(차감 후), dead}.
static func resolve_hit(attacker, defender, defender_hp: int, rng: RandomNumberGenerator, atk_weapon := "") -> Dictionary:
	# 명중 = 굴린 값(0~100) < 명중률. 명중률이 0 이하면 무조건 빗나간다.
	var hit := rng.randf() * 100.0 < hit_chance(attacker, defender)
	if not hit:
		return {"hit": false, "blocked": false, "crit": false, "damage": 0, "hp": defender_hp, "dead": defender_hp <= 0}
	# 방패 막기: 성공하면 피해 완전 무효(치명·피해 계산 생략).
	if rng.randf() * 100.0 < block_chance(defender):
		return {"hit": true, "blocked": true, "crit": false, "damage": 0, "hp": defender_hp, "dead": defender_hp <= 0}
	var crit := rng.randf() * 100.0 < crit_chance(attacker)
	var dmg := hit_damage(attacker, defender, crit, atk_weapon)
	var hp := defender_hp - dmg
	return {"hit": true, "blocked": false, "crit": crit, "damage": dmg, "hp": hp, "dead": hp <= 0}
