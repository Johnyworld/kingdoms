class_name Siege
## 공성 순수 로직 — 사다리 상수·밀기 성공 판정. 씬 비의존(테스트 용이). → docs/spec/features/wall.md

const LADDER_TURNS := 3            # 사다리 설치 후 준비까지 턴 종료 횟수(설치 턴 종료 포함 3회 → 3턴 뒤 통로 열림)
const LADDER_PUSH_CHANCE := 0.15   # [사다리 밀기] 1회당 사다리 파괴 확률
const HOOKED_PUSH_REDUCTION := 0.05   # 「고리 사다리」로 세운 사다리(hooked)의 밀기 성공 확률 감소분 → items.md

## 사다리 밀기 성공 판정 — roll(0~1)이 임계(LADDER_PUSH_CHANCE − markup) 미만이면 파괴 성공.
## markup: 공격자 「고리 사다리」 등 방어자 성공 확률 감소분(이번 슬라이스는 0, 슬라이스 4에서 사용). → wall.md
static func push_succeeds(roll: float, markup := 0.0) -> bool:
	return roll < LADDER_PUSH_CHANCE - markup
