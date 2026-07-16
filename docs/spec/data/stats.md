# Data: Stats (능력치 정의)

[Human](../entities/Human.md)이 보유하는 능력치와 자원의 정의.

## 능력치

| 능력치 | 변수 | 주인공 초기값 | 게임 내 효과 |
| --- | --- | --- | --- |
| 힘 | `strength` | 8 | (미사용) |
| 지혜 | `wisdom` | 5 | (미사용) |
| 민첩 | `agility` | 6 | (미사용) |
| 매력 | `charm` | 10 | (미사용) |
| 행운 | `luck` | 8 | (미사용) |
| 이동력 | `movement` | 3 | **이동/공격 범위 계산** — [부대](../entities/Party.md) `movement()`가 멤버 중 **최소값**으로 집계 |
| 시야 | `vision` | 5 | **전장의 안개 밝힘 반경** — [부대](../entities/Party.md) `vision()`이 멤버 중 **최대값**으로 집계 |
| 지휘력 | `leadership` | 7 | **영웅부대 지휘 범위** — [지휘 범위 버프](../features/command-range.md) `command_range() = 2 + floor(leadership/30)`. 범위 안 소속 하위부대는 전투 공격·방어 ×1.2 |
| 화술 | `eloquence` | 9 | (미사용) |
| 성실함 | `diligence` | 5 | (미사용) |
| 예민함 | `sensitivity` | 8 | (미사용) |

> (미사용) = 값은 정의되어 있으나 아직 게임 로직에 반영되지 않음.

## 자원형 능력치 (Human)

| 능력치 | 변수 | 초기값 | 비고 |
| --- | --- | --- | --- |
| 히트포인트(현재) | `hit_points` | 20 | 현재 생명점. 전투 후에도 지속([Battle](../features/battle.md)). 생성 시 `max_hp()`로 채움 |
| 전투 레벨 | `level` | 1 | `max_hp()` 배수. 성장은 `미구현`(1 고정) |
| 스태미나(현재) | `stamina` | 20 | 생성 시 `max_stamina`로 채움. 소모 시스템 `미구현`(휴식/경계 회복만) |
| 최대 스태미나 | `max_stamina` | 20 | 상한 |
| 사기 | `morale` | 20 | |

- **최대 생명점(계산)**: `Human.max_hp() = floor(힘/2) × level`. 힘에 비례(고정 바탕 없음) — 힘 낮은 보병은 얇고, 힘 높은 영웅은 두껍다. 상세는 [Human](../entities/Human.md).

## 건물 능력치 (종류: 캠프)

건물의 능력치는 [건물 종류 카탈로그](buildings.md)에서 정의된다.

| 능력치 | 변수 | 캠프 값 | 농장 값 | 효과 |
| --- | --- | --- | --- | --- |
| 시야 | `vision` | 5 | 2 | 건물 중심 기준 안개 밝힘 반경 |
