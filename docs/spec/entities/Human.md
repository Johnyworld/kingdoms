# Entity: Human (사람)

> 스크립트: `scenes/human/human.gd` (`class_name Human extends RefCounted`)

능력치와 자원을 보유하는 **순수 데이터** 사람. [부대(Party)](Party.md)의 멤버로 존재한다.
**주인공은 이 Human의 객체**이자 주인공 부대의 멤버다 (`human_name = "테스트맨"`).

시각 요소가 없는 데이터 엔티티라 씬(`.tscn`) 없이 스크립트만 둔다([Faction](Faction.md)·[Territory](Territory.md)와 동일 패턴).
맵 위 표시·선택·이동은 개별 Human이 아니라 이들을 거느린 [부대(Party)](Party.md)가 담당한다.

## Properties

### 정체 (Identity)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 이름 | `human_name` | `""` | 사람의 이름. `_init(p_name)`로 설정 가능. 주인공은 `"테스트맨"` |

### 능력치 (Stats)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 힘 | `strength` | 8 | |
| 지혜 | `wisdom` | 5 | |
| 민첩 | `agility` | 6 | |
| 매력 | `charm` | 10 | |
| 행운 | `luck` | 8 | |
| 이동력 | `movement` | 3 | 부대 이동력 계산에 쓰인다 — [부대](Party.md) `movement()`는 멤버 중 **최소값** |
| 시야 | `vision` | 5 | 부대 시야 계산에 쓰인다 — [부대](Party.md) `vision()`은 멤버 중 **최대값** |
| 지휘력 | `leadership` | 7 | |
| 화술 | `eloquence` | 9 | |
| 성실함 | `diligence` | 5 | |
| 예민함 | `sensitivity` | 8 | |

### 자원 (Resources)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 히트포인트 | `hit_points` | 20 | |
| 스태미나 | `stamina` | 20 | |
| 사기 | `morale` | 20 | |

## 동작

- `_init(p_name := "")` — 이름을 받아 생성한다. 능력치·자원은 위 초기값으로 시작.

## 관련

- 맵 표시·선택·턴당 1회 이동·마커 그리기는 [부대(Party)](Party.md)가 담당한다.
- 이동력·시야는 부대의 유도 능력치([Party](Party.md) `movement()`/`vision()`) 계산에 쓰이고, 최종적으로 [Selection & Movement](../features/selection-and-movement.md)·[Fog of War](../features/fog-of-war.md)에서 사용된다.
- 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
