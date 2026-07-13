class_name Siege
## 공성 순수 로직 — 사다리 상수·밀기 판정 + 성벽 내구도·투석 데미지. 씬 비의존(테스트 용이). → docs/spec/features/wall.md

const LADDER_TURNS := 3            # 사다리 설치 후 준비까지 턴 종료 횟수(설치 턴 종료 포함 3회 → 3턴 뒤 통로 열림)
const LADDER_PUSH_CHANCE := 0.15   # [사다리 밀기] 1회당 사다리 파괴 확률
const HOOKED_PUSH_REDUCTION := 0.05   # 「고리 사다리」로 세운 사다리(hooked)의 밀기 성공 확률 감소분 → items.md

const WALL_MAX_HP := 180          # 성벽 건설 시 내구도(만피). 투석기 공격력 50 기준 평균 3~5발에 붕괴. → siege-engines.md
const DAMAGE_VARIANCE := 0.2      # 투석 데미지 랜덤폭 ±20%(고정값 아님, 다른 공격처럼 랜덤성)

## 사다리 밀기 성공 판정 — roll(0~1)이 임계(LADDER_PUSH_CHANCE − markup) 미만이면 파괴 성공.
## markup: 공격자 「고리 사다리」 등 방어자 성공 확률 감소분(이번 슬라이스는 0, 슬라이스 4에서 사용). → wall.md
static func push_succeeds(roll: float, markup := 0.0) -> bool:
	return roll < LADDER_PUSH_CHANCE - markup

## 투석 1발 실제 데미지 — 기준 공격력(base_attack)에 ±DAMAGE_VARIANCE 랜덤(roll 0~1)을 준다.
## roll 0 → base×0.8(하한), roll 1 → base×1.2(상한), roll 0.5 → base. 투석기 50 → 40~60. → wall.md · siege-units.md
static func rolled_damage(base_attack: int, roll: float) -> int:
	return int(round(base_attack * (1.0 - DAMAGE_VARIANCE + roll * 2.0 * DAMAGE_VARIANCE)))

## 성벽이 dmg 피해를 받은 뒤 내구도(하한 0). → wall.md
static func wall_after_hit(hp: int, dmg: int) -> int:
	return maxi(0, hp - dmg)

## 성벽이 무너졌는지(내구도 0 이하). → wall.md
static func wall_broken(hp: int) -> bool:
	return hp <= 0
