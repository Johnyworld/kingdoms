class_name Siege
## 공성 순수 로직 — 사다리 상수·밀기 판정 + 성벽 내구도·투석 데미지. 씬 비의존(테스트 용이). → docs/spec/features/wall.md

const LADDER_TURNS := 3            # 사다리 설치 후 준비까지 턴 종료 횟수(설치 턴 종료 포함 3회 → 3턴 뒤 통로 열림)
const LADDER_PUSH_CHANCE := 0.15   # [사다리 밀기] 1회당 사다리 파괴 확률
const HOOKED_PUSH_REDUCTION := 0.05   # 「고리 사다리」로 세운 사다리(hooked)의 밀기 성공 확률 감소분 → items.md

const WALL_MAX_HP := 180          # 성벽 건설 시 내구도(만피). 투석기 공격력 50 기준 평균 3~6발에 붕괴. → siege-engines.md
const DAMAGE_VARIANCE := 0.4      # 투석 데미지 랜덤폭 ±40%(고정값 아님, 다른 공격처럼 랜덤성) → 50 기준 30~70

const MAX_BOMBARD_TARGETS := 5    # 유닛 투석 1발이 노리는 최대 유닛 수(초과 부대는 랜덤 5명) → siege-engines.md
const CATAPULT_HIT_CHANCE := 0.1  # 유닛 투석 유닛별 명중 확률(낮음). 명중 시 rolled_damage(큰 피해)

const RAM_COUNTER_BASE := 15      # 충차(근접)가 방어 거점을 타격할 때 수비 반격 기준 피해. 충차 HP 40 → 취약. → siege-engines.md

## 사다리 밀기 성공 판정 — roll(0~1)이 임계(LADDER_PUSH_CHANCE − markup) 미만이면 파괴 성공.
## markup: 공격자 「고리 사다리」 등 방어자 성공 확률 감소분(이번 슬라이스는 0, 슬라이스 4에서 사용). → wall.md
static func push_succeeds(roll: float, markup := 0.0) -> bool:
	return roll < LADDER_PUSH_CHANCE - markup

## 사다리 준비 카운트 진행 — 부대가 설치 위치를 지킬(manned) 때만 −1(하한 0), 아니면 정지(리셋 아님). → wall.md
static func advance_ladder_countdown(countdown: int, manned: bool) -> int:
	return maxi(0, countdown - 1) if manned else countdown

## 투석 1발 실제 데미지 — 기준 공격력(base_attack)에 ±DAMAGE_VARIANCE(0.4) 랜덤(roll 0~1)을 준다.
## roll 0 → base×0.6(하한), roll 1 → base×1.4(상한), roll 0.5 → base. 투석기 50 → 30~70. → wall.md · siege-units.md
static func rolled_damage(base_attack: int, roll: float) -> int:
	return int(round(base_attack * (1.0 - DAMAGE_VARIANCE + roll * 2.0 * DAMAGE_VARIANCE)))

## 성벽이 dmg 피해를 받은 뒤 내구도(하한 0). → wall.md
static func wall_after_hit(hp: int, dmg: int) -> int:
	return maxi(0, hp - dmg)

## 성벽이 무너졌는지(내구도 0 이하). → wall.md
static func wall_broken(hp: int) -> bool:
	return hp <= 0

## 유닛 투석 명중 판정 — roll(0~1)이 명중 확률(chance) 미만이면 명중. → siege-engines.md
static func hit_succeeds(roll: float, chance: float) -> bool:
	return roll < chance

## 충차 반격 1회 피해 — 방어 거점 수비대가 근접한 충차에 주는 피해. RAM_COUNTER_BASE에 ±40% 랜덤. → siege-engines.md
static func ram_counter_damage(roll: float) -> int:
	return rolled_damage(RAM_COUNTER_BASE, roll)

## 거리 dist가 투석 사거리 밴드(min_r ~ fire_r) 안인지 — 밴드보다 가깝거나 멀면 거짓.
## 로빙 NPC positioning 공성(5f)이 밴드 셀을 고르는 필터. → siege-engines.md
static func in_fire_band(dist: int, min_r: int, fire_r: int) -> bool:
	return dist >= min_r and dist <= fire_r

## 헤드리스 성벽 투석(NPC↔NPC, 5g)의 피해 총량 — 공성 유닛별 rolled_damage(attack, roll)의 합.
## attacks·rolls는 유닛별 병렬 배열(둘 중 짧은 길이만큼 정산). 성벽은 항상 명중이라 명중 판정 없음. → siege-engines.md
static func total_bombard_damage(attacks: Array, rolls: Array) -> int:
	var total := 0
	for i in mini(attacks.size(), rolls.size()):
		total += rolled_damage(int(attacks[i]), float(rolls[i]))
	return total
